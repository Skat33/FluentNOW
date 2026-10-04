import Foundation

/// Builds vocabulary sessions (learning.ts `makeSession`, `allowedTaskTypes`, `chooseType`).
public enum SessionBuilder {
    /// Session lengths offered in the UI (minutes).
    public static let durations = [5, 10, 15]

    /// Exercise types allowed by the progression of a meaning, or `nil` when every type is allowed:
    /// flashcard first, then meaning, recall, cloze and dictation as skills get practiced.
    public static func allowedTaskTypes(_ meaning: Meaning) -> [ExerciseType]? {
        let scores = meaning.scores
        if scores[.recognition] == nil { return [.flashcard] }
        if (scores[.recognition]?.correct ?? 0) < 2 { return [.meaning, .flashcard] }
        if scores[.recall] == nil { return [.recall, .meaning] }
        if scores[.usage] == nil { return [.cloze, .recall] }
        if scores[.listening] == nil { return [.dictation, .meaning] }
        return nil
    }

    /// `true` when the example at `index` contains the focus word (a cloze can be built).
    public static func canCloze(word: Word, meaning: Meaning, exampleIndex index: Int) -> Bool {
        guard let sentence = meaning.examples[safe: index] else { return false }
        let focus = nonEmpty(meaning.exampleFocusEn?[safe: index]) ?? word.en
        return Cloze.text(sentence, focus: focus) != nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// Picks an exercise type for a meaning (`chooseType`).
    static func chooseType<G: RandomNumberGenerator>(word: Word, meaning: Meaning, exampleIndex: Int, using rng: inout G) -> ExerciseType {
        var type: ExerciseType
        if let progression = allowedTaskTypes(meaning), !progression.isEmpty {
            type = progression[rng.nextIndex(below: progression.count)]
        } else {
            // Earliest-due skill first; ties broken randomly (valid ordering via pre-drawn keys).
            let candidates = ExerciseType.allCases.map { candidate -> (type: ExerciseType, due: Double, tie: Double) in
                (candidate, meaning.scores[candidate.skill]?.due ?? 0, rng.nextUnit())
            }
            let sorted = candidates.sorted { a, b in
                if a.due != b.due { return a.due < b.due }
                return a.tie < b.tie
            }
            type = sorted.first?.type ?? .flashcard
        }
        if type == .cloze && !canCloze(word: word, meaning: meaning, exampleIndex: exampleIndex) {
            type = .recall
        }
        return type
    }

    /// `makeSession`: reviews first (earliest due; in mistakes mode most errors first), then new
    /// meanings, until the time budget is used. Tasks are interleaved by type.
    ///
    /// - Parameters:
    ///   - minutes: planned length (5 / 10 / 15).
    ///   - mode: `.mixed`, `.mistakes` or `.pairs` (other modes behave like `.mixed`).
    ///   - collection: restricts the session to one collection.
    public static func makeSession<G: RandomNumberGenerator>(
        state: LearnerState,
        minutes: Int,
        mode: StudyMode = .mixed,
        collection: String? = nil,
        using rng: inout G
    ) -> VocabSession {
        let safeMinutes = max(1, minutes)
        var choices: [WordMeaning] = []
        for word in state.words where !word.archived && (collection == nil || word.collection == collection) {
            for meaning in word.meanings where ExamplePool.availableCount(meaning) > 0 {
                choices.append(WordMeaning(word: word, meaning: meaning))
            }
        }
        if mode == .mistakes {
            choices = choices.filter { item in
                item.word.hard || item.meaning.scores.values.contains { $0.wrong > 0 || $0.slow > 0 }
            }
        }
        if mode == .pairs {
            choices = ConfusableDetector.itemsWithPartners(choices)
        }
        if mode == .mistakes {
            let keyed = choices.map { item in
                (item: item, errors: item.meaning.scores.values.reduce(0) { $0 + $1.wrong + $1.slow })
            }
            choices = keyed.stableSorted { $0.errors > $1.errors }.map { $0.item }
        } else {
            let keyed = choices.map { (item: $0, due: Mastery.due($0.meaning)) }
            choices = keyed.stableSorted { $0.due < $1.due }.map { $0.item }
        }
        let ordered: [WordMeaning]
        if mode == .pairs {
            ordered = choices
        } else {
            ordered = choices.filter { !$0.meaning.scores.isEmpty } + choices.filter { $0.meaning.scores.isEmpty }
        }

        var seenCounts: [String: Int] = [:]
        for review in state.reviews {
            seenCounts[review.meaningId, default: 0] += 1
        }

        var tasks: [VocabTask] = []
        var budget = safeMinutes * 60
        for item in ordered {
            let seen = seenCounts[item.meaning.id] ?? 0
            let example = ExamplePool.nextUnusedExample(item.meaning, fallback: seen)
            var type: ExerciseType = mode == .pairs
                ? .cloze
                : chooseType(word: item.word, meaning: item.meaning, exampleIndex: example, using: &rng)
            if type == .cloze && !canCloze(word: item.word, meaning: item.meaning, exampleIndex: example) {
                if mode == .pairs { continue }
                type = .recall
            }
            if !tasks.isEmpty && budget - type.estimatedSeconds < 0 { continue }
            tasks.append(VocabTask(wordId: item.word.id, meaningId: item.meaning.id, type: type, example: example))
            budget -= type.estimatedSeconds
        }
        return VocabSession(
            tasks: TaskInterleaver.interleave(tasks),
            index: 0,
            correct: 0,
            minutes: safeMinutes,
            mode: (mode.isVocabulary ? mode : .mixed).rawValue
        )
    }

    /// `makeSession` with the system random number generator.
    public static func makeSession(state: LearnerState, minutes: Int, mode: StudyMode = .mixed, collection: String? = nil) -> VocabSession {
        var generator = SystemRandomNumberGenerator()
        return makeSession(state: state, minutes: minutes, mode: mode, collection: collection, using: &generator)
    }
}
