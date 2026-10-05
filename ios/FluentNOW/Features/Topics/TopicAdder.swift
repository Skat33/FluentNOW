import Foundation
import FluentKit

/// Wynik dodania wpisów tematu.
struct TopicAddOutcome: Equatable, Sendable {
    var addedMeanings: Int = 0
    var skippedExisting: Int = 0
    var collection: String = ""
}

/// Dodawanie wpisów tematu w tle, w partiach, z postępem i bez blokowania UI.
/// Każda partia jest liczona na migawce stanu poza głównym wątkiem (`store.compute`) i stosowana
/// przez `store.update(.bulk)`. Jeśli w międzyczasie stan się zmienił (np. synchronizacja),
/// partia jest przeliczana na bieżącym stanie, więc nic nie ginie.
@MainActor
enum TopicAdder {
    static let chunkSize = 25

    static func add(
        topic: TopicFile,
        entryIDs: [String],
        store: LearningStore,
        progress: (Double) -> Void
    ) async -> TopicAddOutcome {
        let wanted = Set(entryIDs)
        // Kolejność jak w temacie (od najczęstszych).
        let ordered = topic.allEntries.map { $0.id }.filter { wanted.contains($0) }
        let chunks = stride(from: 0, to: ordered.count, by: chunkSize).map {
            Array(ordered[$0..<min($0 + chunkSize, ordered.count)])
        }
        var outcome = TopicAddOutcome(collection: topic.namePl)
        guard !chunks.isEmpty else { return outcome }
        progress(0)
        // Od końca: pierwsza partia trafia na górę listy słów (najnowsze najpierw).
        for (done, chunk) in chunks.reversed().enumerated() {
            let merged = await merge(topic: topic, chunk: chunk, store: store)
            outcome.addedMeanings += merged.addedMeaningIDs.count
            outcome.skippedExisting += merged.skippedExisting
            progress(Double(done + 1) / Double(chunks.count))
        }
        return outcome
    }

    private static func merge(topic: TopicFile, chunk: [String], store: LearningStore) async -> MergeResult {
        let revision = store.revision
        let now = store.now()
        let computed = await store.compute { state in
            VocabularyMerger.addTopicEntries(state, topic: topic, entryIDs: chunk, now: now)
        }
        if store.revision == revision {
            store.update(.bulk) { (state: inout LearnerState) in
                state = computed.state
            }
            return computed
        }
        return store.update(.bulk) { (state: inout LearnerState) -> MergeResult in
            let result = VocabularyMerger.addTopicEntries(state, topic: topic, entryIDs: chunk, now: now)
            state = result.state
            return result
        }
    }
}
