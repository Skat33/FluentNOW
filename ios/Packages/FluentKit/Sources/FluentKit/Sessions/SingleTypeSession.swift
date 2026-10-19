import Foundation

/// Number of meanings each exercise type can be built for right now („Ćwicz wybrany typ”).
public struct SingleTypeAvailability: Sendable, Hashable {
    public var counts: [ExerciseType: Int]

    public init(counts: [ExerciseType: Int] = [:]) {
        self.counts = counts
    }

    /// Meanings available for `type` (for „Dopasuj pary”: meanings that can join a board; 0 when
    /// fewer than one board's minimum).
    public func count(for type: ExerciseType) -> Int {
        max(0, counts[type] ?? 0)
    }

    public static let empty = SingleTypeAvailability()
}

/// „Ćwicz wybrany typ” (FEEDBACK-5 J1): a short session (5 / 10 min) of one exercise type only,
/// for meanings for which that type can be built — due reviews first (by the due date of the
/// type's skill), then known meanings, then new ones; starred words win ties. The session is a
/// normal `VocabSession` (answers go through `Scheduler.recordAnswer` /
/// `MatchPairsExercise.record`, so progress, FSRS and statistics work as usual); its `mode` is
/// `exercise-<token>`, which older versions read as the daily mix (`VocabSession.studyMode`).
public enum SingleTypeSession {
    /// Types offered on the study screen, in display order. „Słowo i zdjęcie” is shown separately
    /// (locked while `PictureExercise.isEnabled == false`).
    public static let types: [ExerciseType] = [.meaning, .recall, .cloze, .scramble, .matchPairs, .listeningChoice, .dictation]
    /// Lengths offered for one-type sessions (minutes).
    public static let durations = [5, 10]
    /// Prefix of the session mode and of the launch token (`StudyLaunchRequest.modes`,
    /// `fluentnow://study/start?mode=exercise-scramble`).
    public static let modePrefix = "exercise-"
    /// Example sentences tried per meaning when the first one cannot carry the type.
    static let exampleScanLimit = 8

    // MARK: Mode tokens

    /// Short token of an offered type (lower-case letters and „-” — valid in deep links).
    public static func token(for type: ExerciseType) -> String? {
        switch type {
        case .meaning: return "meaning"
        case .recall: return "recall"
        case .cloze: return "cloze"
        case .scramble: return "scramble"
        case .matchPairs: return "match-pairs"
        case .listeningChoice: return "listening"
        case .dictation: return "dictation"
        case .flashcard, .picture: return nil
        }
    }

    /// Session mode / launch token of a type (`exercise-scramble`); `nil` for types not offered.
    public static func mode(for type: ExerciseType) -> String? {
        guard let token = token(for: type) else { return nil }
        return modePrefix + token
    }

    /// The type of a one-type session mode or launch token; `nil` for any other mode.
    public static func type(ofMode mode: String) -> ExerciseType? {
        guard mode.hasPrefix(modePrefix) else { return nil }
        let wanted = String(mode.dropFirst(modePrefix.count))
        return types.first { (candidate: ExerciseType) -> Bool in token(for: candidate) == wanted }
    }

    // MARK: Eligibility

    /// `true` when `type` can be shown for the meaning with the example at `exampleIndex`.
    /// `listeningReady`: the dictionary has enough translations for distractors
    /// (`ListeningChoice.hasDistractorPool`, checked once per build).
    public static func canBuild(_ type: ExerciseType, word: Word, meaning: Meaning, exampleIndex: Int, listeningReady: Bool) -> Bool {
        switch type {
        case .meaning, .recall, .dictation:
            return true
        case .cloze:
            return SessionBuilder.canCloze(word: word, meaning: meaning, exampleIndex: exampleIndex)
        case .scramble:
            return SentenceScramble.canBuild(meaning: meaning, exampleIndex: exampleIndex)
        case .listeningChoice:
            return listeningReady && ListeningChoice.canBuild(meaning: meaning, exampleIndex: exampleIndex)
        case .matchPairs:
            return MatchPairsExercise.canJoinBoard(WordMeaning(word: word, meaning: meaning))
        case .flashcard, .picture:
            return false
        }
    }

    /// The first example (starting at `preferred`, at most `exampleScanLimit` tried) that can carry
    /// `type`; `nil` when none can (or the meaning has no published example).
    public static func buildableExample(_ type: ExerciseType, word: Word, meaning: Meaning, preferred: Int, listeningReady: Bool) -> Int? {
        let count = ExamplePool.availableCount(meaning)
        guard count > 0 else { return nil }
        let start = ((preferred % count) + count) % count
        for step in 0..<min(count, exampleScanLimit) {
            let index = (start + step) % count
            if canBuild(type, word: word, meaning: meaning, exampleIndex: index, listeningReady: listeningReady) {
                return index
            }
        }
        return nil
    }

    /// How many meanings (active words, optional collection) each offered type can be built for.
    public static func availability(state: LearnerState, collection: String? = nil) -> SingleTypeAvailability {
        let listeningReady = ListeningChoice.hasDistractorPool(state)
        var counts: [ExerciseType: Int] = [:]
        for item in candidates(state: state, collection: collection) {
            let preferred = ExamplePool.nextUnusedExample(item.meaning, fallback: 0)
            for type in types where buildableExample(type, word: item.word, meaning: item.meaning, preferred: preferred, listeningReady: listeningReady) != nil {
                counts[type, default: 0] += 1
            }
        }
        if (counts[.matchPairs] ?? 0) < MatchPairsExercise.minimumPairs {
            counts[.matchPairs] = 0
        }
        return SingleTypeAvailability(counts: counts)
    }

    // MARK: Building

    /// Tasks (boards for „Dopasuj pary”) in a session of `minutes`.
    public static func taskLimit(for type: ExerciseType, minutes: Int) -> Int {
        max(1, max(1, minutes) * 60 / max(1, type.estimatedSeconds))
    }

    /// A one-type session; empty when the type is not offered or no meaning can carry it (the
    /// screen then explains why). Due → known → new; at most `taskLimit` tasks.
    public static func makeSession(state: LearnerState, type: ExerciseType, minutes: Int, collection: String? = nil, now: Timestamp) -> VocabSession {
        let safeMinutes = max(1, minutes)
        guard let sessionMode = SingleTypeSession.mode(for: type) else {
            return VocabSession(tasks: [], minutes: safeMinutes, mode: StudyMode.mixed.rawValue)
        }
        let ordered = prioritized(state: state, type: type, collection: collection, now: now)
        let limit = taskLimit(for: type, minutes: safeMinutes)
        let tasks: [VocabTask]
        if type == .matchPairs {
            tasks = boards(from: ordered, limit: limit)
        } else {
            tasks = ordered.prefix(limit).map { (entry: Entry) -> VocabTask in entry.task }
        }
        return VocabSession(tasks: tasks, index: 0, correct: 0, minutes: safeMinutes, mode: sessionMode)
    }

    /// Keeps retries of a one-type session in its type: `Scheduler.recordAnswer` appends a failed
    /// task at the end in the usual retry format (e.g. scramble → cloze); tasks from
    /// `previousCount` on are turned back into the session type when it can be built for the
    /// meaning (another sentence when needed). Missed „Dopasuj pary” meanings stay „Wybierz
    /// znaczenie” — a board needs several meanings. Other sessions are returned unchanged.
    public static func alignRetries(_ state: LearnerState, from previousCount: Int) -> LearnerState {
        guard var session = state.session, let sessionType = SingleTypeSession.type(ofMode: session.mode),
              sessionType != .matchPairs, previousCount >= 0, previousCount < session.tasks.count else { return state }
        let listeningReady = sessionType == .listeningChoice && ListeningChoice.hasDistractorPool(state)
        var changed = false
        for index in previousCount..<session.tasks.count {
            guard let task = session.tasks[safe: index], task.type != sessionType, !task.type.coversSeveralMeanings,
                  let word = state.word(id: task.wordId), let meaning = word.meaning(id: task.meaningId),
                  let example = buildableExample(sessionType, word: word, meaning: meaning, preferred: task.example, listeningReady: listeningReady)
            else { continue }
            session.tasks[index] = VocabTask(wordId: task.wordId, meaningId: task.meaningId, type: sessionType, example: example)
            changed = true
        }
        guard changed else { return state }
        var next = state
        next.session = session
        return next
    }

    // MARK: Private

    /// One candidate task with its ordering keys.
    struct Entry {
        let item: WordMeaning
        let task: VocabTask
        let due: Timestamp
    }

    /// Active meanings with a published example (optionally one collection).
    static func candidates(state: LearnerState, collection: String?) -> [WordMeaning] {
        var result: [WordMeaning] = []
        for word in state.words where !word.archived && (collection == nil || word.collection == collection) {
            for meaning in word.meanings where ExamplePool.availableCount(meaning) > 0 {
                result.append(WordMeaning(word: word, meaning: meaning))
            }
        }
        return result
    }

    /// Buildable tasks: due reviews (earliest first), known meanings (soonest due first), new
    /// meanings — starred words first within each group.
    static func prioritized(state: LearnerState, type: ExerciseType, collection: String?, now: Timestamp) -> [Entry] {
        let listeningReady = type == .listeningChoice && ListeningChoice.hasDistractorPool(state)
        var seenCounts: [String: Int] = [:]
        for review in state.reviews {
            seenCounts[review.meaningId, default: 0] += 1
        }
        var due: [Entry] = []
        var known: [Entry] = []
        var fresh: [Entry] = []
        for item in candidates(state: state, collection: collection) {
            let preferred = ExamplePool.nextUnusedExample(item.meaning, fallback: seenCounts[item.meaning.id] ?? 0)
            guard let example = buildableExample(type, word: item.word, meaning: item.meaning, preferred: preferred, listeningReady: listeningReady) else { continue }
            let task = VocabTask(wordId: item.word.id, meaningId: item.meaning.id, type: type, example: example)
            if item.meaning.scores.isEmpty {
                fresh.append(Entry(item: item, task: task, due: 0))
                continue
            }
            let skillDue = item.meaning.scores[type.skill]?.due ?? Mastery.due(item.meaning)
            let entry = Entry(item: item, task: task, due: skillDue)
            if skillDue <= now {
                due.append(entry)
            } else {
                known.append(entry)
            }
        }
        let byDue = { (a: Entry, b: Entry) -> Bool in
            if a.due != b.due { return a.due < b.due }
            return StudyPriority.starredFirst(a.item.word, b.item.word)
        }
        let starred = { (a: Entry, b: Entry) -> Bool in
            StudyPriority.starredFirst(a.item.word, b.item.word)
        }
        return due.stableSorted(by: byDue) + known.stableSorted(by: byDue) + fresh.stableSorted(by: starred)
    }

    /// „Dopasuj pary” boards of `MatchPairsExercise.pairCount` distinct meanings in priority order
    /// (a meaning that clashes with a board waits for the next one); the last board may have
    /// fewer pairs, but at least `MatchPairsExercise.minimumPairs`.
    static func boards(from entries: [Entry], limit: Int) -> [VocabTask] {
        var remaining = entries
        var result: [VocabTask] = []
        while result.count < limit && remaining.count >= MatchPairsExercise.minimumPairs {
            var members: [Entry] = []
            var rest: [Entry] = []
            for entry in remaining {
                let fits = members.count < MatchPairsExercise.pairCount
                    && members.allSatisfy { (other: Entry) -> Bool in MatchPairsExercise.areDistinct(other.item, entry.item) }
                if fits {
                    members.append(entry)
                } else {
                    rest.append(entry)
                }
            }
            guard members.count >= MatchPairsExercise.minimumPairs,
                  let board = MatchPairsExercise.boardTask(members.map { (entry: Entry) -> VocabTask in entry.task }) else { break }
            result.append(board)
            remaining = rest
        }
        return result
    }
}
