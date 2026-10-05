import Foundation
import SwiftData
import FluentKit

/// `LearningPersistence` na SwiftData. Wszystkie operacje są szeregowane (blokada asynchroniczna),
/// bo ponowne wczytanie po zmianach z iCloud podmienia repozytorium na nowe (świeży kontekst) —
/// zapis nie może w tym czasie trafić do starego kontekstu.
actor SwiftDataPersistence: LearningPersistence {
    private let container: ModelContainer
    private var repository: LearningRepository
    private var isBusy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(container: ModelContainer) {
        self.container = container
        self.repository = LearningRepository(modelContainer: container)
    }

    func load(now: Timestamp) async throws -> PersistenceLoadResult {
        await lock()
        defer { unlock() }
        do {
            return try await repository.load(now: now)
        } catch {
            throw PersistenceError.loadFailed(error.localizedDescription)
        }
    }

    func reloadAfterRemoteChange(now: Timestamp) async throws -> PersistenceLoadResult {
        await lock()
        defer { unlock() }
        let previous = await repository.knownWordIDs()
        let fresh = LearningRepository(modelContainer: container)
        do {
            var result = try await fresh.load(now: now)
            let current = await fresh.knownWordIDs()
            result.removedWordIDs = previous.subtracting(current)
            repository = fresh
            return result
        } catch {
            throw PersistenceError.loadFailed(error.localizedDescription)
        }
    }

    func save(_ state: LearnerState) async throws {
        await lock()
        defer { unlock() }
        try await repository.save(state)
    }

    func deleteAll() async throws {
        await lock()
        defer { unlock() }
        do {
            try await repository.deleteAll()
        } catch {
            throw PersistenceError.deleteFailed(error.localizedDescription)
        }
    }

    // MARK: - Blokada

    private func lock() async {
        if !isBusy {
            isBusy = true
            return
        }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiters.append(continuation)
        }
    }

    private func unlock() {
        if waiters.isEmpty {
            isBusy = false
        } else {
            // Przekazanie blokady następnemu oczekującemu (isBusy pozostaje true).
            waiters.removeFirst().resume()
        }
    }
}
