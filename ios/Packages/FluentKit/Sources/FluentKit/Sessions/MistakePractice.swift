import Foundation

/// „Przećwicz” in „Twoje typowe błędy” (FEEDBACK-10 P1): a short vocabulary session built from the
/// mistake log — the meanings with mistakes of one kind (or of any kind), newest first, each in an
/// exercise that trains that kind (wrong verb forms, prepositions and articles again in „Ułóż
/// zdanie” with the same sentence and decoys of that kind first; typos typed again; meanings
/// recognised again). Stored as a `mistakes` session — it resumes like any vocabulary session.
public enum MistakePractice {
    /// Launch mode of the study screen: `mistake-patterns` (all kinds) or
    /// `mistake-patterns:<kind>` (one kind).
    public static let launchPrefix = "mistake-patterns"

    /// Most tasks in one practice session.
    public static let maxTasks = 12
    /// Fewest tasks planned (short sessions still practise a handful of mistakes).
    public static let minTasks = 4

    /// Launch mode for one kind (`nil` = all kinds).
    public static func launchMode(for kind: MistakeKind?) -> String {
        guard let kind else { return launchPrefix }
        return launchPrefix + ":" + kind.rawValue
    }

    /// Parses a launch mode: `nil` when `raw` is not a mistake practice request; `.some(nil)`
    /// for all kinds. An unknown kind is treated as „all kinds”.
    public static func request(fromLaunchMode raw: String) -> MistakePracticeRequest? {
        guard raw == launchPrefix || raw.hasPrefix(launchPrefix + ":") else { return nil }
        let rawKind = String(raw.dropFirst(launchPrefix.count + 1))
        return MistakePracticeRequest(kind: MistakeKind(rawValue: rawKind))
    }

    /// The practice session (empty when no logged meaning is still in the learner's words).
    /// `minutes` sets the length (≈ 36 s per task, 4–12 tasks).
    public static func session(state: LearnerState, kind: MistakeKind?, minutes: Int) -> VocabSession {
        let safeMinutes = max(1, minutes)
        let planned = min(maxTasks, max(minTasks, safeMinutes * 60 / ExerciseType.scramble.estimatedSeconds))
        var tasks: [VocabTask] = []
        var usedMeanings = Set<String>()
        let newestFirst = state.mistakes.reversed().filter { (entry: MistakeEntry) -> Bool in
            kind == nil || entry.kind == kind
        }
        for entry in newestFirst where tasks.count < planned {
            guard !usedMeanings.contains(entry.meaningId),
                  let word = state.word(id: entry.wordId), !word.archived,
                  let meaning = word.meaning(id: entry.meaningId), !meaning.examples.isEmpty else { continue }
            usedMeanings.insert(entry.meaningId)
            let example = VocabularyGrader.exampleIndex(entry.example, in: meaning)
            let type = exerciseType(for: entry, word: word, meaning: meaning, example: example)
            tasks.append(VocabTask(wordId: word.id, meaningId: meaning.id, type: type, example: example))
        }
        let focus: MistakeKind? = kind?.decoyKind != nil ? kind : MistakeLog.decoyFocus(state.mistakes)
        return VocabSession(
            tasks: tasks,
            index: 0,
            correct: 0,
            minutes: safeMinutes,
            mode: StudyMode.mistakes.rawValue,
            decoyFocus: focus
        )
    }

    /// The exercise that trains a mistake: sentence mistakes (verb form, preposition, article,
    /// order) → „Ułóż zdanie” with the same sentence (cloze / recall when it cannot be built);
    /// typos and other words → the typed exercise they came from (recall otherwise); meanings →
    /// „Wybierz znaczenie”.
    static func exerciseType(for entry: MistakeEntry, word: Word, meaning: Meaning, example: Int) -> ExerciseType {
        switch entry.kind {
        case .verbForm, .preposition, .article, .wordOrder:
            if SentenceScramble.canBuild(meaning: meaning, exampleIndex: example) { return .scramble }
            return SessionBuilder.canCloze(word: word, meaning: meaning, exampleIndex: example) ? .cloze : .recall
        case .typo, .otherWord:
            switch entry.exercise {
            case .dictation:
                return .dictation
            case .cloze:
                return SessionBuilder.canCloze(word: word, meaning: meaning, exampleIndex: example) ? .cloze : .recall
            case .flashcard, .recall, .meaning, .picture, .scramble, .matchPairs, .listeningChoice:
                return .recall
            }
        case .meaning:
            return .meaning
        }
    }
}

/// A parsed „Przećwicz” request (`kind == nil` — all kinds).
public struct MistakePracticeRequest: Sendable, Hashable {
    public var kind: MistakeKind?

    public init(kind: MistakeKind?) {
        self.kind = kind
    }
}
