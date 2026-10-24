import Foundation
import FluentKit

/// Ekran prezentowany jako pełny ekran sesji (`.fullScreenCover`).
enum StudyFlow: Identifiable, Hashable {
    /// Sesja słownictwa (`state.session`).
    case vocabulary
    /// Sesja łączona kilku trybów (`state.combined`).
    case combined
    /// Czytanie (`state.reading`); `autoStart` = od razu przygotuj tekst, jeśli żadnego nie ma.
    case reading(autoStart: Bool)
    /// Gramatyka / idiomy / miks (`state.practice`).
    case practice(PracticeKind, autoStart: Bool)
    /// Produkcja gramatyczna (`state.production`).
    case production(autoStart: Bool)
    /// Osobny tryb „Fiszki” (G3): talia w pamięci, każda odpowiedź zapisywana od razu.
    case flashcards(collection: String?)
    /// Przerwana talia fiszek (FEEDBACK-6 K1, „Kontynuuj, gdzie skończyłem”).
    case resumedFlashcards(FlashcardPausedDeck)

    var id: String {
        switch self {
        case .vocabulary: return "vocabulary"
        case .combined: return "combined"
        case .reading: return "reading"
        case .practice(let kind, _): return "practice-\(kind.rawValue)"
        case .production: return "production"
        case .flashcards, .resumedFlashcards: return "flashcards"
        }
    }

    var title: String {
        switch self {
        case .vocabulary: return "Sesja nauki"
        case .combined: return "Sesja łączona"
        case .reading: return "Czytanie"
        case .practice(let kind, _): return kind.studyTitle
        case .production: return "Produkcja gramatyczna"
        case .flashcards, .resumedFlashcards: return "Fiszki"
        }
    }
}

/// Zajęcie na ekranie Nauka, które można przerwać i wznowić (FEEDBACK-6 K1). Dotknięcie kafelka
/// z przerwaną sesją pokazuje wybór „Kontynuuj, gdzie skończyłem” / „Zacznij od nowa”.
enum StudyActivity: Hashable {
    /// „Ćwicz wybrany typ” (sesja jednego typu w `state.session`).
    case singleType(ExerciseType)
    /// Talia fiszek (przerwa zapisana na urządzeniu, `FlashcardPauseStore`).
    case flashcards
    case reading
    case practice(PracticeKind)
    case production

    var title: String {
        switch self {
        case .singleType(let type): return type.practiceTitle
        case .flashcards: return "Fiszki"
        case .reading: return "Czytanie"
        case .practice(let kind): return kind.studyTitle
        case .production: return "Produkcja gramatyczna"
        }
    }
}

/// Trasy wewnątrz karty Nauka (push na `router.studyPath`).
enum StudyRoute: Hashable {
    case history
}

extension PracticeKind {
    /// Krótka nazwa zestawu w nagłówkach.
    var studyTitle: String {
        switch self {
        case .grammar: return "Gramatyka"
        case .idioms: return "Idiomy"
        case .mixed: return "Miks językowy"
        }
    }
}

extension StudyMode {
    /// Opis kafelka na ekranie „Na co masz dziś ochotę?” (teksty strony).
    var studyDescription: String {
        switch self {
        case .mixed: return "Nowe i znane słowa. Powtórki dopasowane do Ciebie."
        case .mistakes: return "Spokojnie przećwicz słowa, które potrzebują trochę uwagi."
        case .pairs: return "Ćwicz automatycznie wykryte słowa o podobnych znaczeniach."
        case .reading: return "Tekst dopasowany do poziomu i pytania o sens oraz szczegóły."
        case .grammar: return "Reguły ćwiczone w naturalnych zdaniach i dialogach."
        case .idioms: return "Znaczenie, kontekst i ważne różnice w użyciu."
        case .production: return "Wpisz formę czasownika, odczytując wskazówki ze zdania."
        case .languageMix: return "Gramatyka i idiomy: pytania ABCD i samodzielne wpisywanie."
        case .flashcards: return "Talia fiszek: odwróć kartę i przesuń — pamiętam albo jeszcze nie."
        case .pictures: return "Angielskie słowo i cztery zdjęcia — wskaż właściwe."
        }
    }

    var studySystemImage: String {
        switch self {
        case .mixed: return "arrow.triangle.2.circlepath"
        case .mistakes: return "lightbulb"
        case .pairs: return "arrow.left.arrow.right"
        case .reading: return "book"
        case .grammar: return "pencil.line"
        case .idioms: return "text.bubble"
        case .production: return "character.cursor.ibeam"
        case .languageMix: return "sparkles"
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .pictures: return "photo.on.rectangle"
        }
    }

    /// Rodzaj zestawu dla trybów praktyki (gramatyka, idiomy, miks).
    var studyPracticeKind: PracticeKind? {
        switch self {
        case .grammar: return .grammar
        case .idioms: return .idioms
        case .languageMix: return .mixed
        default: return nil
        }
    }
}
