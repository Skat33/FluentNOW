import Foundation
import FluentKit

/// Podsumowanie jednej kolekcji (liczone poza głównym wątkiem).
struct CollectionSummary: Identifiable, Hashable, Sendable {
    let name: String
    let wordCount: Int
    let meaningCount: Int
    let averageMastery: Int
    let masteredMeanings: Int
    let newMeanings: Int
    let dueMeanings: Int

    var id: String { name }
}

struct CollectionsOverview: Hashable, Sendable {
    var collections: [CollectionSummary] = []
    /// Liczba znaczeń, które mają „parę” (podobne słowo, inna historia); -1 = nie liczono.
    var confusableCount: Int = 0
}

enum CollectionBuilder {
    static let confusableLimit = 2_500

    static func overview(state: LearnerState, now: Timestamp) -> CollectionsOverview {
        let names = WordListBuilder.allCollections(state)
        let summaries = names.map { summary(state: state, name: $0, now: now) }
        let items = state.words
            .filter { !$0.archived }
            .flatMap { word in word.meanings.map { WordMeaning(word: word, meaning: $0) } }
        // Wykrywanie par porównuje znaczenia parami — przy bardzo dużym słowniku pomijamy licznik.
        let pairs: Int
        if items.count < 2 {
            pairs = 0
        } else if items.count <= confusableLimit {
            pairs = ConfusableDetector.itemsWithPartners(items).count
        } else {
            pairs = -1
        }
        return CollectionsOverview(collections: summaries, confusableCount: pairs)
    }

    static func summary(state: LearnerState, name: String, now: Timestamp) -> CollectionSummary {
        let words = state.words.filter { !$0.archived && $0.collection == name }
        let meanings = words.flatMap { $0.meanings }
        let progress = ProgressStatistics.collectionProgress(state, collection: name)
        return CollectionSummary(
            name: name,
            wordCount: words.count,
            meaningCount: meanings.count,
            averageMastery: progress.average,
            masteredMeanings: meanings.filter { $0.mastery >= Mastery.masteredThreshold }.count,
            newMeanings: meanings.filter { $0.isNew }.count,
            dueMeanings: meanings.filter { !$0.isNew && $0.due <= now }.count
        )
    }

    /// Wiersze słów kolekcji (bez archiwum), najnowsze najpierw.
    static func rows(state: LearnerState, name: String, now: Timestamp) -> [WordListRow] {
        var filter = WordListFilter()
        filter.collection = name
        return WordListBuilder.build(state: state, query: "", filter: filter, now: now)
            .sections.flatMap { $0.rows }
    }
}

/// Zmiany kolekcji (wewnątrz `store.update`).
enum CollectionMutations {
    static let maxNameLength = 60

    /// Komunikat błędu dla nazwy albo `nil`, gdy poprawna.
    static func nameIssue(_ name: String, existing: [String], current: String? = nil) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Wpisz nazwę kolekcji." }
        if trimmed.count > maxNameLength { return "Nazwa może mieć najwyżej \(maxNameLength) znaków." }
        let key = TextNormalizer.normalize(trimmed)
        if existing.contains(where: { TextNormalizer.normalize($0) == key && $0 != current }) {
            return "Masz już kolekcję o tej nazwie."
        }
        return nil
    }

    static func create(_ state: inout LearnerState, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !state.collections.contains(trimmed) else { return }
        state.collections.append(trimmed)
    }

    /// Zmienia nazwę kolekcji i przenosi do niej słowa (także zarchiwizowane).
    static func rename(_ state: inout LearnerState, from old: String, to new: String, now: Timestamp) {
        let target = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty, target != old else { return }
        for index in state.words.indices where state.words[index].collection == old {
            state.words[index].collection = target
            state.words[index].updatedAt = now
        }
        if let position = state.collections.firstIndex(of: old) {
            if state.collections.contains(target) {
                state.collections.remove(at: position)
            } else {
                state.collections[position] = target
            }
        } else if !state.collections.contains(target) {
            state.collections.append(target)
        }
    }

    /// Usuwa kolekcję. Słowa zostają w słowniku — trafiają do kolekcji domyślnej.
    static func delete(_ state: inout LearnerState, name: String, now: Timestamp) {
        let fallback = fallbackName(forDeleting: name)
        var moved = false
        for index in state.words.indices where state.words[index].collection == name {
            state.words[index].collection = fallback
            state.words[index].updatedAt = now
            moved = true
        }
        state.collections.removeAll { $0 == name }
        if moved && !state.collections.contains(fallback) {
            state.collections.append(fallback)
        }
    }

    static func fallbackName(forDeleting name: String) -> String {
        name == VocabularyMerger.defaultCollection ? "Inne" : VocabularyMerger.defaultCollection
    }
}
