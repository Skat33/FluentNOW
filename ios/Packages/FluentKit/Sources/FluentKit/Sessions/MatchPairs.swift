import Foundation

/// One pair of the „Dopasuj pary” board.
public struct MatchPairItem: Sendable, Hashable, Identifiable {
    public var wordId: String
    public var meaningId: String
    /// English word or phrase.
    public var term: String
    /// Polish translation (without dialect labels).
    public var translation: String

    public init(wordId: String, meaningId: String, term: String, translation: String) {
        self.wordId = wordId
        self.meaningId = meaningId
        self.term = term
        self.translation = translation
    }

    public var id: String { meaningId }
}

/// The two columns of the board in their shuffled orders.
public struct MatchPairBoard: Sendable, Hashable {
    public var english: [MatchPairItem]
    public var polish: [MatchPairItem]

    public init(english: [MatchPairItem], polish: [MatchPairItem]) {
        self.english = english
        self.polish = polish
    }

    public var count: Int { english.count }
}

/// Result of one meaning on the board: number of wrong pairs it took part in.
public struct MatchPairResult: Sendable, Hashable {
    public var wordId: String
    public var meaningId: String
    public var mistakes: Int

    public init(wordId: String, meaningId: String, mistakes: Int) {
        self.wordId = wordId
        self.meaningId = meaningId
        self.mistakes = mistakes
    }

    /// Matched without any wrong pair.
    public var correct: Bool { mistakes == 0 }
}

/// „Dopasuj pary” (FEEDBACK-4 I2): five English words ↔ five Polish translations of meanings
/// from the current session. A wrong pair flashes and counts a mistake for both meanings; every
/// meaning is then scored for recognition with `Scheduler.recordAnswer` (one review each).
public enum MatchPairsExercise {
    /// Pairs on a board built by `SessionBuilder`.
    public static let pairCount = 5
    /// A board with fewer pairs (words deleted meanwhile) falls back to the meaning exercise.
    public static let minimumPairs = 3
    /// A meaning joins a regular board after this many correct recognition answers. FEEDBACK-5 J1:
    /// the board is a recognition task, so it starts right after the first correct recognition
    /// (it was two before — new users waited days for it). The first contact itself never joins a
    /// regular board; a session of new words ends with an introduction board instead
    /// (`SessionBuilder.introductionBoard`).
    public static let minimumRecognitionCorrect = 1

    // MARK: Building

    /// `true` for a meaning that may join a regular board.
    public static func isEligible(_ item: WordMeaning) -> Bool {
        guard (item.meaning.scores[.recognition]?.correct ?? 0) >= minimumRecognitionCorrect else { return false }
        return canJoinBoard(item)
    }

    /// `true` when the meaning can be shown on a board at all (a term and a Polish translation).
    public static func canJoinBoard(_ item: WordMeaning) -> Bool {
        !termKey(item.word.en).isEmpty && !translationKey(item.meaning.translation).isEmpty
    }

    /// Two meanings can share a board: different words, terms and Polish translations (no pair
    /// could be matched two ways).
    public static func areDistinct(_ a: WordMeaning, _ b: WordMeaning) -> Bool {
        guard a.word.id != b.word.id, a.meaning.id != b.meaning.id else { return false }
        guard termKey(a.word.en) != termKey(b.word.en) else { return false }
        let polishA = translationKey(a.meaning.translation)
        let polishB = translationKey(b.meaning.translation)
        guard polishA != polishB else { return false }
        // „bank” vs „bank — instytucja” style overlaps: the translation of one is not the term of
        // the other.
        return polishA != termKey(b.word.en) && polishB != termKey(a.word.en)
    }

    /// Indices (in `tasks`) of `pairCount` tasks whose meanings make a board; `nil` when fewer
    /// qualify. `items` maps meaning IDs to the meanings. „Wybierz znaczenie” tasks are taken
    /// first (the board replaces them — same skill); FEEDBACK-5 J1: when there are not enough of
    /// them, meanings practiced in this session in another skill (recall, usage, listening) fill
    /// the board — their own tasks stay, so no meaning gets two recognition reviews.
    static func groupIndices(tasks: [VocabTask], items: [String: WordMeaning]) -> [Int]? {
        var chosen: [Int] = []
        var members: [WordMeaning] = []
        for pass in 0..<2 {
            for (index, task) in tasks.enumerated() {
                let fits = pass == 0 ? task.type == .meaning : task.type.skill != .recognition
                guard fits, !chosen.contains(index), let item = items[task.meaningId], isEligible(item),
                      members.allSatisfy({ (other: WordMeaning) -> Bool in areDistinct(other, item) }) else { continue }
                chosen.append(index)
                members.append(item)
                if chosen.count == pairCount { return chosen }
            }
        }
        return nil
    }

    /// Indices of up to `pairCount` „Wybierz znaczenie” tasks of meanings met for the first time in
    /// this session (FEEDBACK-5 J1 introduction board); `nil` when fewer than `minimumPairs`.
    static func introductionIndices(tasks: [VocabTask], items: [String: WordMeaning]) -> [Int]? {
        var chosen: [Int] = []
        var members: [WordMeaning] = []
        for (index, task) in tasks.enumerated() where task.type == .meaning {
            guard let item = items[task.meaningId], SessionBuilder.isFirstContact(item.meaning), canJoinBoard(item),
                  members.allSatisfy({ (other: WordMeaning) -> Bool in areDistinct(other, item) }) else { continue }
            chosen.append(index)
            members.append(item)
            if chosen.count == pairCount { break }
        }
        return chosen.count >= minimumPairs ? chosen : nil
    }

    /// One board task: the first member is the anchor, the others its partners.
    static func boardTask(_ members: [VocabTask]) -> VocabTask? {
        guard let anchor = members.first else { return nil }
        let partners = members.dropFirst().map { (task: VocabTask) -> VocabTaskRef in
            VocabTaskRef(wordId: task.wordId, meaningId: task.meaningId)
        }
        return VocabTask(
            wordId: anchor.wordId,
            meaningId: anchor.meaningId,
            type: .matchPairs,
            example: anchor.example,
            partners: Array(partners)
        )
    }

    /// The pairs of a task that still exist (deleted words are skipped; a later meaning that now
    /// clashes with an earlier one is dropped).
    public static func items(for task: VocabTask, state: LearnerState) -> [MatchPairItem] {
        var members: [WordMeaning] = []
        for ref in task.allRefs {
            guard let word = state.word(id: ref.wordId), let meaning = word.meaning(id: ref.meaningId) else { continue }
            let item = WordMeaning(word: word, meaning: meaning)
            guard members.allSatisfy({ (other: WordMeaning) -> Bool in areDistinct(other, item) }) else { continue }
            members.append(item)
        }
        return members.map { (member: WordMeaning) -> MatchPairItem in
            MatchPairItem(
                wordId: member.word.id,
                meaningId: member.meaning.id,
                term: member.word.en,
                translation: TextNormalizer.withoutDialectLabel(member.meaning.translation)
            )
        }
    }

    /// Both columns shuffled (stable for `seed`, the task key); the Polish column never lines up
    /// with the English one when it can be avoided.
    public static func board(_ items: [MatchPairItem], seed: String) -> MatchPairBoard {
        var generator = SeededGenerator(seed: "pairs:" + seed)
        let english = shuffled(items, using: &generator)
        var polish = shuffled(items, using: &generator)
        if polish.count > 1 {
            for index in polish.indices where polish[index].meaningId == english[index].meaningId {
                let other = (index + 1) % polish.count
                polish.swapAt(index, other)
            }
        }
        return MatchPairBoard(english: english, polish: polish)
    }

    private static func shuffled<G: RandomNumberGenerator>(_ items: [MatchPairItem], using rng: inout G) -> [MatchPairItem] {
        var result = items
        var index = result.count - 1
        while index > 0 {
            result.swapAt(index, rng.nextIndex(below: index + 1))
            index -= 1
        }
        return result
    }

    // MARK: Recording

    /// Review IDs of one board: `base` for the first pair, `base-2`, `base-3`… for the others.
    public static func reviewIDs(base: String, count: Int) -> [String] {
        (0..<max(0, count)).map { (index: Int) -> String in index == 0 ? base : "\(base)-\(index + 1)" }
    }

    /// Scores every meaning of the board for recognition through `Scheduler.recordAnswer` (board
    /// time split evenly, no hint, the example pool untouched) with the vocabulary session
    /// detached. With `advancesSession` and the board being the running session's current task,
    /// the session then moves on once: correct only when every pair was right; each missed
    /// meaning returns at the end in its own format (`SessionBuilder.retryType`), like
    /// `recordAnswer` does for single tasks. Missing words are skipped.
    public static func record(
        _ state: LearnerState,
        task: VocabTask,
        results: [MatchPairResult],
        seconds: Double,
        confidence: Int,
        now: Timestamp,
        reviewID: String = UUID().uuidString.lowercased(),
        advancesSession: Bool = true
    ) -> LearnerState {
        var next = state
        let running = next.session
        next.session = nil
        let ids = reviewIDs(base: reviewID, count: results.count)
        let perPair = seconds.isFinite ? max(0, seconds) / Double(max(1, results.count)) : 0
        var missed: [MatchPairResult] = []
        for (offset, result) in results.enumerated() {
            guard next.word(id: result.wordId)?.meaning(id: result.meaningId) != nil else { continue }
            let single = VocabTask(wordId: result.wordId, meaningId: result.meaningId, type: .matchPairs, example: -1)
            next = Scheduler.recordAnswer(
                next,
                task: single,
                correct: result.correct,
                seconds: perPair,
                confidence: confidence,
                hint: false,
                spellingCorrect: result.correct,
                now: now,
                reviewID: ids[safe: offset] ?? UUID().uuidString.lowercased()
            )
            if !result.correct { missed.append(result) }
        }
        next.session = running
        guard advancesSession, var session = next.session, let current = session.currentTask,
              current.type == .matchPairs, current.wordId == task.wordId, current.meaningId == task.meaningId else {
            return next
        }
        session.index += 1
        session.correct += missed.isEmpty && !results.isEmpty ? 1 : 0
        for result in missed where session.tasks.count < Scheduler.maxSessionTasks {
            guard let meaning = next.word(id: result.wordId)?.meaning(id: result.meaningId) else { continue }
            session.tasks.append(VocabTask(
                wordId: result.wordId,
                meaningId: result.meaningId,
                type: SessionBuilder.retryType(after: .matchPairs, meaning: meaning),
                example: ExamplePool.nextUnusedExample(meaning, fallback: 1)
            ))
        }
        next.session = session
        return next
    }

    // MARK: Keys

    static func termKey(_ term: String) -> String {
        TextNormalizer.normalize(TextNormalizer.withoutDialectLabel(term))
    }

    static func translationKey(_ translation: String) -> String {
        TextScanning.foldPolish(TextNormalizer.normalize(TextNormalizer.withoutDialectLabel(translation)))
    }
}
