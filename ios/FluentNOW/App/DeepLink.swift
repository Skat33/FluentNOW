import Foundation

/// Prośba o rozpoczęcie sesji nauki (z deep linku, przypomnienia, Dzisiaj).
/// Tryby to surowe wartości `FluentKit.StudyMode` (`mixed`, `mistakes`, `pairs`, `reading`,
/// `grammar`, `idioms`, `production`, `language-mix`) — mapowanie: `StudyMode(rawValue:)`,
/// nieznane wartości ekran Nauki pomija.
struct StudyLaunchRequest: Hashable, Sendable {
    /// Pusta lista = codzienna mieszanka (`mixed`).
    var modes: [String]
    /// 5, 10 lub 15; `nil` = ostatni wybór użytkownika.
    var minutes: Int?
    /// `true` = wznów przerwaną sesję zamiast tworzyć nową.
    var resume: Bool
    /// Ograniczenie do kolekcji (np. „Ćwicz tę kolekcję”), `nil` = wszystkie słowa.
    var collection: String?

    init(modes: [String] = [], minutes: Int? = nil, resume: Bool = false, collection: String? = nil) {
        self.modes = modes
        self.minutes = minutes
        self.resume = resume
        self.collection = collection
    }

    /// Codzienna mieszanka jednym dotknięciem.
    static let daily = StudyLaunchRequest(modes: ["mixed"])
    /// Tryb pomyłek („Warto do nich wrócić”).
    static let mistakes = StudyLaunchRequest(modes: ["mistakes"])
    /// Wznowienie przerwanej sesji.
    static let resumeLast = StudyLaunchRequest(resume: true)

    static let allowedMinutes: Set<Int> = [5, 10, 15]
}

/// Miejsce w Słowniku, do którego prowadzi link (ui-library zamienia je na własne trasy `NavigationPath`).
enum LibraryDestination: Hashable, Sendable {
    case word(id: String)
    case collection(name: String)
    case topic(id: String)
}

/// Obsługiwane linki `fluentnow://…`:
///
/// | URL | Efekt |
/// |---|---|
/// | `fluentnow://today` | karta Dzisiaj |
/// | `fluentnow://words` · `fluentnow://words/<id>` | Słownik / szczegóły słowa |
/// | `fluentnow://collections` · `fluentnow://collections/<nazwa>` | Kolekcje / kolekcja |
/// | `fluentnow://topics` · `fluentnow://topics/<id>` · `fluentnow://topics?q=na%20lotnisku` | „Szukaj tematu” (arkusz „+”) |
/// | `fluentnow://study` | karta Nauka |
/// | `fluentnow://study/start?mode=mixed&mode=reading&minutes=10&collection=Lotnisko` | start sesji |
/// | `fluentnow://study/resume` | wznowienie sesji |
/// | `fluentnow://add?text=borrow` | szybkie dodawanie (z wypełnionym polem) |
/// | `fluentnow://progress` · `fluentnow://settings` | Postępy / Ustawienia |
enum DeepLink: Hashable, Sendable {
    case tab(AppTab)
    case library(LibrarySection, LibraryDestination?)
    case study(StudyLaunchRequest)
    case quickAdd(prefill: String?)
    /// Wyszukiwanie tematu (tematy nie są publicznym katalogiem — F1).
    case topicSearch(query: String?, topicID: String?)

    static let scheme = "fluentnow"
    /// Ochrona przed absurdalnie długimi parametrami z zewnątrz.
    static let maxParameterLength = 200

    /// Parsuje URL; nieznany lub niepoprawny link → `nil` (aplikacja go ignoruje).
    init?(url: URL) {
        guard url.scheme?.lowercased() == DeepLink.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host?.lowercased(), !host.isEmpty
        else { return nil }

        let segments = components.path
            .split(separator: "/")
            .map(String.init) // URLComponents.path jest już zdekodowane z %XX
            .filter { !$0.isEmpty }
        let items = components.queryItems ?? []
        let first = segments.first.flatMap(DeepLink.sanitized)

        switch host {
        case "today":
            self = .tab(.today)
        case "words":
            self = .library(.words, first.map { LibraryDestination.word(id: $0) })
        case "collections":
            self = .library(.collections, first.map { LibraryDestination.collection(name: $0) })
        case "topics":
            let query = items.first(where: { $0.name == "q" || $0.name == "text" })?.value.flatMap(DeepLink.sanitized)
            self = .topicSearch(query: query, topicID: first)
        case "progress", "stats":
            self = .tab(.progress)
        case "settings":
            self = .tab(.settings)
        case "add":
            let text = items.first(where: { $0.name == "text" })?.value.flatMap(DeepLink.sanitized)
            self = .quickAdd(prefill: text)
        case "study":
            guard let action = segments.first?.lowercased() else {
                self = .tab(.study)
                return
            }
            switch action {
            case "resume":
                self = .study(.resumeLast)
            case "start":
                self = .study(DeepLink.studyRequest(from: items))
            default:
                return nil
            }
        default:
            return nil
        }
    }

    private static func studyRequest(from items: [URLQueryItem]) -> StudyLaunchRequest {
        let modes = items
            .filter { $0.name == "mode" }
            .compactMap { $0.value?.lowercased() }
            .filter { DeepLink.isValidModeToken($0) }
        var unique: [String] = []
        for mode in modes where !unique.contains(mode) {
            unique.append(mode)
        }
        let minutes = items.first(where: { $0.name == "minutes" })?.value
            .flatMap { Int($0) }
            .flatMap { StudyLaunchRequest.allowedMinutes.contains($0) ? $0 : nil }
        let collection = items.first(where: { $0.name == "collection" })?.value.flatMap(DeepLink.sanitized)
        return StudyLaunchRequest(
            modes: unique.isEmpty ? ["mixed"] : unique,
            minutes: minutes,
            resume: false,
            collection: collection
        )
    }

    /// Tryb: tylko małe litery i myślnik, rozsądna długość.
    private static func isValidModeToken(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 32 else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            (97...122).contains(scalar.value) || scalar.value == 45 // a–z lub „-”
        }
    }

    /// Przycięty, niepusty parametr o ograniczonej długości.
    private static func sanitized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(maxParameterLength))
    }
}
