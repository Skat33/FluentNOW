import Foundation
import FluentKit

/// Proste zmiany słowa wykonywane wewnątrz `store.update { … }`.
/// Każda zmiana ustawia `updatedAt` (ważne dla scalania przy synchronizacji).
enum WordMutations {
    static func setArchived(_ state: inout LearnerState, id: String, archived: Bool, now: Timestamp) {
        guard let index = state.wordIndex(id: id) else { return }
        state.words[index].archived = archived
        state.words[index].updatedAt = now
    }

    static func setHard(_ state: inout LearnerState, id: String, hard: Bool, now: Timestamp) {
        guard let index = state.wordIndex(id: id) else { return }
        state.words[index].hard = hard
        state.words[index].updatedAt = now
    }

    static func setImportant(_ state: inout LearnerState, id: String, important: Bool, now: Timestamp) {
        guard let index = state.wordIndex(id: id) else { return }
        state.words[index].important = important
        state.words[index].updatedAt = now
    }

    /// Usuwa słowo. Historia odpowiedzi zostaje (statystyki i seria dni się nie zmieniają).
    static func delete(_ state: inout LearnerState, id: String) {
        state.words.removeAll { $0.id == id }
    }

    /// Zastępuje słowo wersją z edytora.
    static func replace(_ state: inout LearnerState, with word: Word) {
        if let index = state.wordIndex(id: word.id) {
            state.words[index] = word
        } else {
            state.words.insert(word, at: 0)
        }
        let collection = word.collection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !collection.isEmpty && !state.collections.contains(collection) {
            state.collections.append(collection)
        }
    }
}
