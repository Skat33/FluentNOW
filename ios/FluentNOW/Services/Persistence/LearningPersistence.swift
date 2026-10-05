import Foundation
import FluentKit

/// Wynik wczytania stanu z magazynu (wartości `Sendable`, liczone poza głównym wątkiem).
struct PersistenceLoadResult: Sendable {
    /// Stan po `StateMigration.migrate`, scaleniu duplikatów i `compactReviews`.
    var state: LearnerState
    /// Rekordy pominięte, bo ich zawartości nie dało się odczytać (uszkodzone).
    var skippedRecords: Int
    /// Scalono duplikaty rekordów (np. z dwóch urządzeń przez iCloud).
    var mergedDuplicates: Int
    /// Słowa, których rekordy zniknęły od poprzedniego odczytu (usunięte na innym urządzeniu).
    var removedWordIDs: Set<String>

    init(state: LearnerState, skippedRecords: Int = 0, mergedDuplicates: Int = 0, removedWordIDs: Set<String> = []) {
        self.state = state
        self.skippedRecords = skippedRecords
        self.mergedDuplicates = mergedDuplicates
        self.removedWordIDs = removedWordIDs
    }
}

/// Błędy warstwy trwałości (polskie komunikaty).
enum PersistenceError: Error, LocalizedError, Equatable {
    case storeUnavailable(String)
    case saveFailed(String)
    case loadFailed(String)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .storeUnavailable(let detail):
            return "Magazyn danych jest niedostępny: \(detail)"
        case .saveFailed(let detail):
            return "Nie udało się zapisać zmian: \(detail)"
        case .loadFailed(let detail):
            return "Nie udało się wczytać danych: \(detail)"
        case .deleteFailed(let detail):
            return "Nie udało się usunąć danych: \(detail)"
        }
    }
}

/// Abstrakcja magazynu stanu ucznia. Implementacje: `SwiftDataPersistence` (aplikacja)
/// i `InMemoryPersistence` (podgląd, testy). Wszystkie metody działają poza głównym wątkiem.
protocol LearningPersistence: Actor {
    /// Pierwsze wczytanie (migracja, scalenie duplikatów, kompaktowanie recenzji).
    func load(now: Timestamp) async throws -> PersistenceLoadResult
    /// Ponowne wczytanie po zmianach z iCloud (świeży kontekst).
    func reloadAfterRemoteChange(now: Timestamp) async throws -> PersistenceLoadResult
    /// Zapis przyrostowy: zapisywane są tylko rekordy różniące się od ostatnio zapisanych.
    func save(_ state: LearnerState) async throws
    /// Usuwa wszystkie rekordy (także z iCloud — usunięcie synchronizuje się).
    func deleteAll() async throws
}

/// Magazyn w pamięci — podgląd SwiftUI i testy. Opcjonalnie z danymi startowymi.
actor InMemoryPersistence: LearningPersistence {
    private var stored: LearnerState
    private(set) var saveCount = 0
    /// Do testów: wymusza błąd zapisu.
    private var failSaves = false

    init(initial: LearnerState = .empty) {
        stored = initial
    }

    func setFailSaves(_ value: Bool) {
        failSaves = value
    }

    func storedState() -> LearnerState {
        stored
    }

    func load(now: Timestamp) async throws -> PersistenceLoadResult {
        PersistenceLoadResult(state: StateMigration.migrate(stored))
    }

    func reloadAfterRemoteChange(now: Timestamp) async throws -> PersistenceLoadResult {
        PersistenceLoadResult(state: stored)
    }

    func save(_ state: LearnerState) async throws {
        if failSaves {
            throw PersistenceError.saveFailed("Symulowany błąd zapisu.")
        }
        stored = state
        saveCount += 1
    }

    func deleteAll() async throws {
        stored = .empty
    }
}
