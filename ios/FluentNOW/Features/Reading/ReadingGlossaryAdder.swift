import Foundation
import FluentKit

/// Wynik „Dodaj do nauki” z arkusza słowa w czytance.
enum ReadingAddOutcome: Equatable {
    /// Dodano `count` znaczeń.
    case added(Int)
    /// To znaczenie już jest w słowniku (postęp zachowany).
    case alreadyKnown
    /// Nie udało się wczytać wpisu bazy.
    case failed
}

/// Dodawanie słowa ze słowniczka czytanki przez odwołanie `ref` do wpisu bazy — pełny wpis
/// (przykłady, IPA, warianty) jak przy dodawaniu tematu; znane znaczenia zachowują postęp.
@MainActor
enum ReadingGlossaryAdder {
    static func add(_ entry: ReadingGlossaryEntry, store: LearningStore, content: ContentLibrary) async -> ReadingAddOutcome {
        guard let reference = entry.contentReference else { return .failed }
        let now: Timestamp = store.now()
        if reference.isStarter {
            guard let topicEntry = try? await content.entry(reference: reference.rawValue) else { return .failed }
            let suggestion = VocabularyMerger.suggestion(from: topicEntry, topicName: VocabularyMerger.defaultCollection, reference: reference.rawValue)
            let lookup = VocabularyMerger.lookup(term: topicEntry.term, entries: [(entry: topicEntry, suggestion: suggestion)])
            let added: Int = store.update(.edit) { (state: inout LearnerState) -> Int in
                let result = VocabularyMerger.mergeSuggestions(state, lookup: lookup, indices: [0], now: now)
                state = result.state
                return result.addedMeaningIDs.count
            }
            return added > 0 ? .added(added) : .alreadyKnown
        }
        guard let topic = try? await content.topic(id: reference.file) else { return .failed }
        let added: Int = store.update(.edit) { (state: inout LearnerState) -> Int in
            let result = VocabularyMerger.addTopicEntries(state, topic: topic, entryIDs: [reference.entryID], now: now)
            state = result.state
            return result.addedMeaningIDs.count
        }
        return added > 0 ? .added(added) : .alreadyKnown
    }

    /// Czy znaczenie z `ref` jest już w słowniku.
    static func isAdded(_ entry: ReadingGlossaryEntry, state: LearnerState) -> Bool {
        guard let ref = entry.ref else { return false }
        return VocabularyMerger.addedContentReferences(state).contains(ref)
    }
}
