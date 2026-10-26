import Foundation
import FluentKit

/// Kafelek w jednej siatce „Ćwiczenia” na ekranie Nauka (FEEDBACK-8 M2). Każdy kafelek to
/// **jedno** ćwiczenie — dotknięcie od razu je uruchamia (albo pokazuje „Kontynuuj / Zacznij od
/// nowa”, gdy czeka przerwana sesja). Łączenie wielu rodzajów zadań jest tylko w Teście.
enum StudyExerciseTile: Hashable, Identifiable {
    /// Zajęcie, które można przerwać i wznowić (typ ćwiczenia, tryb słownictwa, czytanie…).
    case activity(StudyActivity)
    /// „Słowo i zdjęcie” — wyszarzone „W budowie” (I2); po odblokowaniu tryb „Słowa i obrazki”.
    case pictures

    var id: StudyExerciseTile { self }

    var activity: StudyActivity? {
        switch self {
        case .activity(let activity): return activity
        case .pictures: return nil
        }
    }

    var title: String {
        switch self {
        case .activity(let activity):
            switch activity {
            case .production: return "Produkcja"
            case .singleType, .vocabulary, .flashcards, .reading, .practice: return activity.title
            }
        case .pictures:
            return ExerciseType.picture.practiceTitle
        }
    }

    var detail: String {
        switch self {
        case .activity(let activity):
            switch activity {
            case .singleType(let type): return type.practiceDescription
            case .vocabulary(let mode): return mode.studyDescription
            case .flashcards: return StudyMode.flashcards.studyDescription
            case .reading: return StudyMode.reading.studyDescription
            case .practice(let kind): return kind.studyMode.studyDescription
            case .production: return StudyMode.production.studyDescription
            }
        case .pictures:
            return ExerciseType.picture.practiceDescription
        }
    }

    var systemImage: String {
        switch self {
        case .activity(let activity):
            switch activity {
            case .singleType(let type): return type.practiceSystemImage
            case .vocabulary(let mode): return mode.studySystemImage
            case .flashcards: return StudyMode.flashcards.studySystemImage
            case .reading: return StudyMode.reading.studySystemImage
            case .practice(let kind): return kind.studyMode.studySystemImage
            case .production: return StudyMode.production.studySystemImage
            }
        case .pictures:
            return ExerciseType.picture.practiceSystemImage
        }
    }
}

/// Grupa kafelków „Ćwiczeń” — przełączana segmentem nad jedną siatką (FEEDBACK-8 M5).
struct StudyExerciseGroup: Identifiable, Hashable {
    let id: String
    /// Krótka nazwa segmentu.
    let title: String
    /// Jedno zdanie pod przełącznikiem.
    let detail: String
    let tiles: [StudyExerciseTile]
    /// Grupa ćwiczeń ze słówkami (pokazuje wybór 5 / 10 min).
    let usesWords: Bool

    static let types = StudyExerciseGroup(
        id: "types",
        title: "Słówka",
        detail: "Jeden rodzaj zadania ze słówkami: najpierw powtórki, potem znane, na końcu nowe.",
        tiles: SingleTypeSession.types.map { (type: ExerciseType) -> StudyExerciseTile in
            .activity(.singleType(type))
        } + [.pictures],
        usesWords: true
    )

    static let review = StudyExerciseGroup(
        id: "review",
        title: "Powtórki",
        detail: "Sesje z Twojego słownika: mieszanka zadań, słowa z pomyłkami albo słowa łatwe do pomylenia.",
        tiles: [
            .activity(.vocabulary(.mixed)),
            .activity(.vocabulary(.mistakes)),
            .activity(.vocabulary(.pairs))
        ],
        usesWords: true
    )

    static let bank = StudyExerciseGroup(
        id: "bank",
        title: "Czytanie i gramatyka",
        detail: "Teksty i zestawy z banku na Twoim poziomie — działają od razu, także bez słów i bez internetu.",
        tiles: [
            .activity(.reading),
            .activity(.practice(.grammar)),
            .activity(.practice(.idioms)),
            .activity(.practice(.mixed)),
            .activity(.production)
        ],
        usesWords: false
    )

    /// Kolejność segmentów jak w FEEDBACK-8 M5: Słówka / Powtórki / Czytanie i gramatyka.
    static let all: [StudyExerciseGroup] = [types, review, bank]

    /// Grupa o zapamiętanym `id`; nieznane — pierwsza.
    static func group(id: String) -> StudyExerciseGroup {
        all.first { (group: StudyExerciseGroup) -> Bool in group.id == id } ?? types
    }

    /// Grupa, w której jest kafelek zajęcia (np. by pokazać przerwane po prośbie z routera).
    static func group(containing activity: StudyActivity) -> StudyExerciseGroup? {
        all.first { (group: StudyExerciseGroup) -> Bool in
            group.tiles.contains(.activity(activity))
        }
    }

    var activities: [StudyActivity] {
        tiles.compactMap { (tile: StudyExerciseTile) -> StudyActivity? in tile.activity }
    }

    /// Wszystkie zajęcia z kafelków (do znaczników „Przerwane”).
    static var allActivities: [StudyActivity] {
        all.flatMap { (group: StudyExerciseGroup) -> [StudyActivity] in group.activities }
    }
}

/// Ile słów może zasilić każdy kafelek słownictwa — liczone poza głównym wątkiem
/// (`store.compute`). Kafelki czytania i gramatyki nie zależą od słów (`nil`).
struct StudyExerciseAvailability: Sendable, Hashable {
    var types: SingleTypeAvailability
    var modes: [StudyMode: Int]

    static let reviewModes: [StudyMode] = [.mixed, .mistakes, .pairs]

    static func make(state: LearnerState, collection: String?) -> StudyExerciseAvailability {
        StudyExerciseAvailability(
            types: SingleTypeSession.availability(state: state, collection: collection),
            modes: VocabularyModeAvailability.counts(state: state, modes: reviewModes, collection: collection)
        )
    }

    /// Liczba słów dla kafelka; `nil` — kafelek nie zależy od słów.
    func count(for tile: StudyExerciseTile) -> Int? {
        switch tile {
        case .activity(.singleType(let type)):
            return types.count(for: type)
        case .activity(.vocabulary(let mode)):
            return max(0, modes[mode] ?? 0)
        case .activity, .pictures:
            return nil
        }
    }
}

extension PracticeKind {
    /// Tryb nauki odpowiadający zestawowi (opis i ikona kafelka).
    var studyMode: StudyMode {
        switch self {
        case .grammar: return .grammar
        case .idioms: return .idioms
        case .mixed: return .languageMix
        }
    }
}
