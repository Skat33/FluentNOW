import Foundation

/// Faza wczytywania stanu przy starcie (`LearningStore.loadPhase`).
enum StoreLoadPhase: Equatable {
    case loading
    case ready
    case failed(String)
}

/// Rodzaj zmiany przekazywany do `LearningStore.update(_:_:)` — decyduje o sposobie zapisu.
///
/// - `.answer`, `.session` — zapis natychmiast (odpowiedź w ćwiczeniu nie może zginąć),
/// - `.edit` — zapis z opóźnieniem (debounce ≤ 300 ms, kolejne edycje łączone),
/// - `.bulk` — duże zmiany (import tematu, scalanie) zapisywane w tle w partiach.
enum ChangeKind {
    case edit
    case answer
    case session
    case bulk
}

/// Tryb importu kopii JSON.
enum ImportMode {
    /// Scalenie z obecnymi danymi (`StateSync.mergeStates`) — nic nie ginie.
    case merge
    /// Zastąpienie obecnych danych zawartością pliku.
    case replace
}

/// Podsumowanie importu (także podglądu przed zatwierdzeniem).
struct ImportSummary: Equatable {
    var newWords: Int
    var mergedWords: Int
    var skipped: Int
    var messages: [String]

    init(newWords: Int = 0, mergedWords: Int = 0, skipped: Int = 0, messages: [String] = []) {
        self.newWords = newWords
        self.mergedWords = mergedWords
        self.skipped = skipped
        self.messages = messages
    }
}
