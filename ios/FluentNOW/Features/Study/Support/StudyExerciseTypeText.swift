import Foundation
import FluentKit

/// Nazwy, opisy i ikony typów ćwiczeń w sekcji „Ćwicz wybrany typ” (FEEDBACK-5 J1).
/// Nazwy jak w zaleceniu właściciela (krótsze niż `ExerciseType.namePl` w sesji).
extension ExerciseType {
    var practiceTitle: String {
        switch self {
        case .meaning: return "Wybierz znaczenie"
        case .recall: return "Przypomnij sobie"
        case .cloze: return "Uzupełnij lukę"
        case .scramble: return "Ułóż zdanie"
        case .matchPairs: return "Dopasuj pary"
        case .listeningChoice: return "Zrozum ze słuchu"
        case .dictation: return "Dyktando"
        case .picture: return "Słowo i zdjęcie"
        case .flashcard: return "Fiszki"
        }
    }

    var practiceDescription: String {
        switch self {
        case .meaning: return "Słowo w zdaniu — wybierz polskie znaczenie."
        case .recall: return "Polskie znaczenie — wpisz angielskie słowo."
        case .cloze: return "Wpisz brakujące słowo w zdaniu."
        case .scramble: return "Ułóż zdanie z rozsypanych słów."
        case .matchPairs: return "Połącz słowa z ich tłumaczeniami."
        case .listeningChoice: return "Posłuchaj zdania i wybierz tłumaczenie."
        case .dictation: return "Posłuchaj i zapisz, co słyszysz."
        case .picture: return "Angielskie słowo i cztery obrazki."
        case .flashcard: return "Odwróć kartę i oceń, czy pamiętasz."
        }
    }

    var practiceSystemImage: String {
        switch self {
        case .meaning: return "list.bullet.rectangle"
        case .recall: return "brain.head.profile"
        case .cloze: return "text.cursor"
        case .scramble: return "shuffle"
        case .matchPairs: return "link"
        case .listeningChoice: return "ear"
        case .dictation: return "square.and.pencil"
        case .picture: return "photo.on.rectangle"
        case .flashcard: return "rectangle.on.rectangle.angled"
        }
    }
}

/// Teksty sesji jednego typu.
enum StudySingleTypeText {
    /// Tytuł nagłówka sesji („Twój mały krok” w zwykłej sesji).
    static func sessionTitle(mode: String) -> String? {
        guard let type = SingleTypeSession.type(ofMode: mode) else { return nil }
        return type.practiceTitle
    }

    /// Spokojny komunikat, gdy dla wybranego typu nie ma słów.
    static func emptyMessage(type: ExerciseType, hasWords: Bool, collection: String?) -> String {
        if !hasWords {
            return "Dodaj kilka słów lub cały temat — wtedy przygotujemy ćwiczenie „\(type.practiceTitle)”."
        }
        if let collection, !collection.isEmpty {
            return "W kolekcji „\(collection)” nie ma słów, dla których da się zbudować ćwiczenie „\(type.practiceTitle)”. Usuń ograniczenie do kolekcji albo wybierz inny typ."
        }
        switch type {
        case .scramble:
            return "„Ułóż zdanie” potrzebuje zdań z przykładami od 4 do 14 słów — Twoje słowa ich jeszcze nie mają. Dodaj słowa z tematów albo wybierz inny typ."
        case .listeningChoice:
            return "„Zrozum ze słuchu” potrzebuje zdań z polskim tłumaczeniem i co najmniej 4 różnych tłumaczeń w słowniku. Dodaj słowa z tematów — mają gotowe tłumaczenia."
        case .cloze:
            return "„Uzupełnij lukę” potrzebuje zdań, w których występuje ćwiczone słowo. Dodaj słowa z tematów albo wybierz inny typ."
        case .matchPairs:
            return "„Dopasuj pary” potrzebuje co najmniej \(MatchPairsExercise.minimumPairs) słów o różnych tłumaczeniach. Dodaj kilka słów."
        case .meaning, .recall, .dictation, .picture, .flashcard:
            return "Dla tego ćwiczenia nie ma teraz słów. Dodaj nowe słowa albo wybierz inny typ."
        }
    }

    /// „12 słów” / „Brak słów” na kafelku.
    static func availability(_ count: Int) -> String {
        count > 0 ? StudyPicturesCard.words(count) : "Brak słów"
    }
}
