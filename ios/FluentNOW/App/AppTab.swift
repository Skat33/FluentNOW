import Foundation

/// Karty głównej nawigacji. Architektura informacji (uzasadnienie w docs/DESIGN.md):
/// Dzisiaj · Słownik (Słowa / Kolekcje) · Nauka · Postępy · Ustawienia.
enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case today
    case words
    case study
    case progress
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Dzisiaj"
        case .words: return "Słownik"
        case .study: return "Nauka"
        case .progress: return "Postępy"
        case .settings: return "Ustawienia"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .words: return "books.vertical"
        case .study: return "brain.head.profile"
        case .progress: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }
}

/// Segmenty karty „Słownik”.
///
/// `topics` nie jest już segmentem (F1: tematy nie są publicznym katalogiem) — zostaje tylko dla
/// zgodności wywołań `router.openLibrary(.topics)`, które `AppRouter` zamienia na wyszukiwanie
/// tematu w arkuszu „+”. Segmenty widoczne w Słowniku: `browsable`.
enum LibrarySection: String, CaseIterable, Identifiable, Hashable, Sendable {
    case words
    case collections
    case topics

    var id: String { rawValue }

    /// Segmenty pokazywane w przełączniku Słownika.
    static let browsable: [LibrarySection] = [.words, .collections]

    var title: String {
        switch self {
        case .words: return "Słowa"
        case .collections: return "Kolekcje"
        case .topics: return "Tematy"
        }
    }
}
