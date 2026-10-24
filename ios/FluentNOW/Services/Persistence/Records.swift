import Foundation
import SwiftData

// Encje SwiftData zgodne z regułami CloudKit: wszystkie atrybuty z wartością domyślną,
// brak `@Attribute(.unique)`, brak relacji. Treść to JSON struktur FluentKit (`payload`)
// + kilka pól skalarnych do zapytań/diagnostyki. Duplikaty (ten sam identyfikator z dwóch
// urządzeń) scala repozytorium przy wczytaniu.

/// Jedno słowo (`Word` FluentKit w `payload`).
@Model
final class WordRecord {
    var wordId: String = ""
    var en: String = ""
    var collection: String = ""
    var archived: Bool = false
    /// `Word.created` (ms) — kolejność listy: najnowsze najpierw.
    var created: Double = 0
    /// Pozycja w liście przy pierwszym zapisie (rozstrzyga kolejność słów z tym samym `created`).
    var position: Int = 0
    var updatedAt: Double = 0
    var payload: Data = Data()

    init(wordId: String, en: String, collection: String, archived: Bool, created: Double, position: Int, updatedAt: Double, payload: Data) {
        self.wordId = wordId
        self.en = en
        self.collection = collection
        self.archived = archived
        self.created = created
        self.position = position
        self.updatedAt = updatedAt
        self.payload = payload
    }
}

/// Pojedyncza odpowiedź (`Review`). Rekordy tylko dopisywane (brak konfliktów między urządzeniami);
/// starsze niż 90 dni są kompaktowane do podsumowań dziennych (`StateSync.compactReviews`).
@Model
final class ReviewRecord {
    var reviewId: String = ""
    var wordId: String = ""
    var meaningId: String = ""
    var at: Double = 0
    var payload: Data = Data()

    init(reviewId: String, wordId: String, meaningId: String, at: Double, payload: Data) {
        self.reviewId = reviewId
        self.wordId = wordId
        self.meaningId = meaningId
        self.at = at
        self.payload = payload
    }
}

/// Ustawienia ucznia + lista kolekcji (`SettingsPayload`).
@Model
final class SettingsRecord {
    var key: String = "settings"
    var updatedAt: Double = 0
    var payload: Data = Data()

    init(key: String = "settings", updatedAt: Double, payload: Data) {
        self.key = key
        self.updatedAt = updatedAt
        self.payload = payload
    }
}

/// Bieżąca sesja jednego rodzaju (`SessionKind`); `payload == nil` = brak sesji.
@Model
final class SessionRecord {
    var kind: String = ""
    var updatedAt: Double = 0
    var payload: Data? = nil

    init(kind: String, updatedAt: Double, payload: Data?) {
        self.kind = kind
        self.updatedAt = updatedAt
        self.payload = payload
    }
}

/// Wpis historii (`HistoryKind`): czytanie/praktyka/produkcja (po jednym rekordzie na wpis),
/// podsumowanie dnia (`summary`, klucz = dzień) albo `grammarSeen` (jeden rekord).
@Model
final class HistoryRecord {
    var kind: String = ""
    var entryId: String = ""
    var at: Double = 0
    var payload: Data = Data()

    init(kind: String, entryId: String, at: Double, payload: Data) {
        self.kind = kind
        self.entryId = entryId
        self.at = at
        self.payload = payload
    }
}

/// Rodzaje sesji w `SessionRecord.kind`.
enum SessionKind: String, CaseIterable {
    case vocabulary = "vocab"
    case combined
    case reading
    case practice
    case production
    /// Test poziomu (FEEDBACK-6 K4). Starsze wersje pomijają nieznany rodzaj sesji.
    case assessment
}

/// Rodzaje wpisów w `HistoryRecord.kind`.
enum HistoryKind: String, CaseIterable {
    case reading
    case practice
    case production
    case summary
    case grammarSeen
    /// Ukończony test poziomu (`AssessmentHistoryEntry`, K4). Starsze wersje liczą go jako pominięty rekord.
    case assessment
}
