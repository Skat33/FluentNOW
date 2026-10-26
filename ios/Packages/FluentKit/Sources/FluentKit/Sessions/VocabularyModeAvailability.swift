import Foundation

/// Meanings a vocabulary mode („Codzienna mieszanka”, „Tryb pomyłek”, „Słowa w parach”) can
/// practise right now — the candidate filters of `SessionBuilder.makeSession`, shared with the
/// tiles of the study screen (FEEDBACK-8 M2: a tile without words explains why instead of being
/// silently disabled).
public enum VocabularyModeAvailability {
    /// Non-archived meanings with at least one usable example (optionally from one collection);
    /// `.mistakes` keeps hard words and meanings with wrong / slow answers; `.pairs` keeps meanings
    /// that have a confusable partner. Other modes behave like `.mixed`. Order: as in the state.
    public static func candidates(state: LearnerState, mode: StudyMode, collection: String? = nil) -> [WordMeaning] {
        var choices: [WordMeaning] = []
        for word in state.words where !word.archived && (collection == nil || word.collection == collection) {
            for meaning in word.meanings where ExamplePool.availableCount(meaning) > 0 {
                choices.append(WordMeaning(word: word, meaning: meaning))
            }
        }
        switch mode {
        case .mistakes:
            choices = choices.filter { (item: WordMeaning) -> Bool in
                item.word.hard || item.meaning.scores.values.contains { (score: Score) -> Bool in
                    score.wrong > 0 || score.slow > 0
                }
            }
        case .pairs:
            choices = ConfusableDetector.itemsWithPartners(choices)
        case .mixed, .reading, .grammar, .idioms, .production, .languageMix, .flashcards, .pictures:
            break
        }
        return choices
    }

    /// Number of candidate meanings (0 — the mode cannot build a session now).
    public static func count(state: LearnerState, mode: StudyMode, collection: String? = nil) -> Int {
        candidates(state: state, mode: mode, collection: collection).count
    }

    /// Counts for several modes at once.
    public static func counts(state: LearnerState, modes: [StudyMode], collection: String? = nil) -> [StudyMode: Int] {
        var result: [StudyMode: Int] = [:]
        for mode in modes where result[mode] == nil {
            result[mode] = count(state: state, mode: mode, collection: collection)
        }
        return result
    }
}
