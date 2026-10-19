import Foundation

/// Builds vocabulary sessions (learning.ts `makeSession`, `allowedTaskTypes`, `chooseType`).
public enum SessionBuilder {
    /// Session lengths offered in the UI (minutes).
    public static let durations = [5, 10, 15]

    /// Exercise types allowed by the progression of a meaning, or `nil` when every session type is
    /// allowed. Stages:
    /// 1. first contact (no recognition answer yet) and until the first correct one → the meaning
    ///    exercise (G3: the first contact shows the four Polish options straight away);
    /// 2. FEEDBACK-5 J1 — right after the first correct recognition: the recognition-style new
    ///    exercises „Zrozum ze słuchu” and „Ułóż zdanie” (the sentence is built from tiles, with
    ///    the translation on demand) next to „Wybierz znaczenie”; „Dopasuj pary” joins through the
    ///    board built from the session (`MatchPairsExercise.minimumRecognitionCorrect == 1`);
    /// 3. from the second correct recognition until the first recall answer: recall joins;
    /// 4. recall answered, usage not yet: cloze, scramble, recall, listening;
    /// 5. usage answered, listening not yet: listening choice, dictation, meaning;
    /// 6. `nil` — every type, the earliest-due skill first.
    /// A correct recall (e.g. from imported progress) also unlocks the scramble before the first
    /// correct recognition. Before J1 the new types needed two correct recognitions (separate days
    /// with FSRS) and a recall answer, the listening choice even a usage answer. `.meaning` stays
    /// last in stages 2–3: a constant generator in tests picks it (boards are built from it).
    /// Types that cannot be built for the drawn sentence are filtered out by `chooseType`.
    public static func allowedTaskTypes(_ meaning: Meaning) -> [ExerciseType]? {
        let scores = meaning.scores
        guard let recognition = scores[.recognition] else { return [.meaning] }
        let recognized = recognition.correct >= MatchPairsExercise.minimumRecognitionCorrect
        if !recognized {
            let recalled = (scores[.recall]?.correct ?? 0) >= 1
            return recalled ? [.scramble, .meaning] : [.meaning]
        }
        if scores[.recall] == nil {
            if recognition.correct < 2 { return [.listeningChoice, .scramble, .meaning] }
            return [.recall, .listeningChoice, .scramble, .meaning]
        }
        if scores[.usage] == nil { return [.cloze, .scramble, .recall, .listeningChoice] }
        if scores[.listening] == nil { return [.listeningChoice, .dictation, .meaning] }
        return nil
    }

    /// `true` for the very first contact with a meaning (never practiced for recognition): the
    /// meaning exercise then shows its options at once and choosing one is not counted as a hint.
    public static func isFirstContact(_ meaning: Meaning) -> Bool {
        meaning.scores[.recognition] == nil
    }

    /// Format of a failed task when it returns at the end of the session: the usual rotation
    /// (`ExerciseType.retryType`) while the meaning's progression allows it; otherwise another
    /// allowed type of the same skill, then the same exercise again (another sentence — a new word
    /// that failed its first meaning exercise gets the meaning exercise again, not a dictation;
    /// J1: a failed recognition in stage 2 is not retried as listening), then any allowed type.
    public static func retryType(after type: ExerciseType, meaning: Meaning) -> ExerciseType {
        let rotated = type.retryType
        guard let allowed = allowedTaskTypes(meaning), !allowed.isEmpty else { return rotated }
        if allowed.contains(rotated) { return rotated }
        if let sameSkill = allowed.first(where: { (candidate: ExerciseType) -> Bool in candidate != type && candidate.skill == type.skill }) {
            return sameSkill
        }
        if allowed.contains(type) { return type }
        return allowed.first(where: { $0 != type }) ?? allowed[0]
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

    /// Picks an exercise type for a meaning (`chooseType`). Never a flashcard; the picture
    /// exercise only when `pictureReady` (a photo of this meaning and enough distractors are
    /// cached), the feature is enabled and the meaning is past its first contact. The scramble
    /// needs a sentence of 4–14 words, the listening choice a translated sentence and
    /// `listeningReady` (enough other translations for distractors); otherwise cloze / recall and
    /// dictation take their place.
    static func chooseType<G: RandomNumberGenerator>(word: Word, meaning: Meaning, exampleIndex: Int, pictureReady: Bool = false, listeningReady: Bool = false, using rng: inout G) -> ExerciseType {
        let photos = pictureReady && PictureExercise.isEnabled
        var type: ExerciseType
        if let progression = allowedTaskTypes(meaning), !progression.isEmpty {
            // J1: types that cannot be built for this sentence are not drawn at all (otherwise a
            // word met once could get a dictation in place of the listening choice).
            var drawable = progression.filter { (candidate: ExerciseType) -> Bool in
                switch candidate {
                case .scramble: return SentenceScramble.canBuild(meaning: meaning, exampleIndex: exampleIndex)
                case .listeningChoice: return listeningReady && ListeningChoice.canBuild(meaning: meaning, exampleIndex: exampleIndex)
                default: return true
                }
            }
            if drawable.isEmpty { drawable = progression }
            if photos && !isFirstContact(meaning) && drawable.contains(.meaning) {
                drawable.append(.picture)
            }
            type = drawable[rng.nextIndex(below: drawable.count)]
        } else {
            // Earliest-due skill first; ties broken randomly (valid ordering via pre-drawn keys).
            let scrambleReady = SentenceScramble.canBuild(meaning: meaning, exampleIndex: exampleIndex)
            let listeningPossible = listeningReady && ListeningChoice.canBuild(meaning: meaning, exampleIndex: exampleIndex)
            let types = ExerciseType.sessionTypes.filter { (candidate: ExerciseType) -> Bool in
                switch candidate {
                case .picture: return photos
                case .scramble: return scrambleReady
                case .listeningChoice: return listeningPossible
                default: return true
                }
            }
            let candidates = types.map { candidate -> (type: ExerciseType, due: Double, tie: Double) in
                (candidate, meaning.scores[candidate.skill]?.due ?? 0, rng.nextUnit())
            }
            let sorted = candidates.sorted { a, b in
                if a.due != b.due { return a.due < b.due }
                return a.tie < b.tie
            }
            type = sorted.first?.type ?? .meaning
        }
        if type == .scramble && !SentenceScramble.canBuild(meaning: meaning, exampleIndex: exampleIndex) {
            type = .cloze
        }
        if type == .listeningChoice && !(listeningReady && ListeningChoice.canBuild(meaning: meaning, exampleIndex: exampleIndex)) {
            type = .dictation
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
    ///   - pictureMeaningIDs: meanings whose photo exercise can be shown right now (photo and
    ///     three distractor photos already cached — see `PictureExercise.readyMeaningIDs`).
    ///     Empty (offline, nothing cached) = no picture tasks.
    public static func makeSession<G: RandomNumberGenerator>(
        state: LearnerState,
        minutes: Int,
        mode: StudyMode = .mixed,
        collection: String? = nil,
        pictureMeaningIDs: Set<String> = [],
        using rng: inout G
    ) -> VocabSession {
        if mode == .pictures {
            // „W budowie” (I2): the mode stays in the code, but builds nothing while disabled.
            guard PictureExercise.isEnabled else {
                return VocabSession(tasks: [], minutes: max(1, minutes), mode: StudyMode.pictures.rawValue)
            }
            return makePictureSession(state: state, minutes: minutes, collection: collection, pictureMeaningIDs: pictureMeaningIDs, using: &rng)
        }
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
        // Starred words (`StudyPriority`): tie-break only — reviews keep their order by due date /
        // errors; new meanings (all due 0) get starred ones first.
        if mode == .mistakes {
            let keyed = choices.map { item in
                (item: item, errors: item.meaning.scores.values.reduce(0) { $0 + $1.wrong + $1.slow })
            }
            choices = keyed.stableSorted { (a: (item: WordMeaning, errors: Int), b: (item: WordMeaning, errors: Int)) -> Bool in
                if a.errors != b.errors { return a.errors > b.errors }
                return StudyPriority.starredFirst(a.item.word, b.item.word)
            }.map { $0.item }
        } else {
            let keyed = choices.map { (item: $0, due: Mastery.due($0.meaning)) }
            choices = keyed.stableSorted { (a: (item: WordMeaning, due: Timestamp), b: (item: WordMeaning, due: Timestamp)) -> Bool in
                if a.due != b.due { return a.due < b.due }
                return StudyPriority.starredFirst(a.item.word, b.item.word)
            }.map { $0.item }
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
        // Tasks that did not fit the budget — used to refill it when a pairs board frees time.
        var overflow: [VocabTask] = []
        var chosenItems: [String: WordMeaning] = [:]
        let listeningReady = mode != .pairs && ListeningChoice.hasDistractorPool(state)
        for item in ordered {
            let seen = seenCounts[item.meaning.id] ?? 0
            let example = ExamplePool.nextUnusedExample(item.meaning, fallback: seen)
            var type: ExerciseType = mode == .pairs
                ? .cloze
                : chooseType(
                    word: item.word,
                    meaning: item.meaning,
                    exampleIndex: example,
                    pictureReady: pictureMeaningIDs.contains(item.meaning.id),
                    listeningReady: listeningReady,
                    using: &rng
                )
            if type == .cloze && !canCloze(word: item.word, meaning: item.meaning, exampleIndex: example) {
                if mode == .pairs { continue }
                type = .recall
            }
            let task = VocabTask(wordId: item.word.id, meaningId: item.meaning.id, type: type, example: example)
            if !tasks.isEmpty && budget - type.estimatedSeconds < 0 {
                if overflow.count < 60 { overflow.append(task) }
                continue
            }
            tasks.append(task)
            chosenItems[item.meaning.id] = item
            budget -= type.estimatedSeconds
        }
        var boardAdded = false
        if mode == .mixed || mode == .mistakes {
            boardAdded = addPairsBoard(to: &tasks, budget: &budget, items: chosenItems, overflow: overflow)
        }
        // J1: a session of only new words would be nothing but „Wybierz znaczenie” — it ends with
        // „Dopasuj pary” of the meanings it has just introduced (after them, never interleaved).
        var introduction: VocabTask?
        if mode == .mixed && !boardAdded {
            introduction = introductionBoard(tasks: &tasks, budget: &budget, items: chosenItems)
        }
        var sessionTasks = TaskInterleaver.interleave(tasks)
        if let introduction {
            sessionTasks.append(introduction)
        }
        return VocabSession(
            tasks: sessionTasks,
            index: 0,
            correct: 0,
            minutes: safeMinutes,
            mode: (mode.isVocabulary ? mode : .mixed).rawValue
        )
    }

    /// „Dopasuj pary” (FEEDBACK-4 I2): five practiced meanings (at least one correct recognition
    /// since FEEDBACK-5 J1, different terms and translations — `MatchPairsExercise`) become one
    /// board in the middle of the session. Their „Wybierz znaczenie” tasks are replaced (recognition
    /// is scored once per meaning — no meaning gets two recognition reviews in one session); when
    /// there are fewer than five of them, meanings practiced here in another skill fill the board
    /// and keep their own tasks (J1 — the board shows up in most sessions with practiced words).
    /// When the board does not fit the budget, the lowest-priority tasks (end of the list, not on
    /// the board) make room; time freed is refilled with tasks that did not fit. `false` — no board.
    @discardableResult
    static func addPairsBoard(to tasks: inout [VocabTask], budget: inout Int, items: [String: WordMeaning], overflow: [VocabTask]) -> Bool {
        let current = tasks
        guard let indices = MatchPairsExercise.groupIndices(tasks: current, items: items) else { return false }
        let members = indices.compactMap { (index: Int) -> VocabTask? in current[safe: index] }
        guard members.count == MatchPairsExercise.pairCount, let board = MatchPairsExercise.boardTask(members) else { return false }
        let replaced = Set(indices.filter { (index: Int) -> Bool in current[safe: index]?.type.skill == .recognition })
        var kept: [VocabTask] = []
        var freed = 0
        for (index, task) in current.enumerated() {
            if replaced.contains(index) {
                freed += task.type.estimatedSeconds
            } else {
                kept.append(task)
            }
        }
        var left = budget + freed - ExerciseType.matchPairs.estimatedSeconds
        let memberIDs = Set(members.map { (task: VocabTask) -> String in task.meaningId })
        guard makeRoom(in: &kept, left: &left, keeping: memberIDs) else { return false }
        kept.insert(board, at: kept.count / 2)
        for task in overflow {
            let cost = task.type.estimatedSeconds
            if left - cost >= 0 {
                kept.append(task)
                left -= cost
            }
        }
        budget = left
        tasks = kept
        return true
    }

    /// J1 introduction board: up to five „Wybierz znaczenie” tasks of meanings met for the first
    /// time in this session (at least `MatchPairsExercise.minimumPairs`) — their tasks stay, the
    /// board comes after all of them as a quick consolidation. Room is made by dropping the
    /// lowest-priority tasks that are not on the board; `nil` when nothing qualifies or fits.
    static func introductionBoard(tasks: inout [VocabTask], budget: inout Int, items: [String: WordMeaning]) -> VocabTask? {
        let current = tasks
        guard let indices = MatchPairsExercise.introductionIndices(tasks: current, items: items) else { return nil }
        let members = indices.compactMap { (index: Int) -> VocabTask? in current[safe: index] }
        guard members.count >= MatchPairsExercise.minimumPairs, let board = MatchPairsExercise.boardTask(members) else { return nil }
        var kept = current
        var left = budget - ExerciseType.matchPairs.estimatedSeconds
        let memberIDs = Set(members.map { (task: VocabTask) -> String in task.meaningId })
        guard makeRoom(in: &kept, left: &left, keeping: memberIDs) else { return nil }
        budget = left
        tasks = kept
        return board
    }

    /// Drops tasks from the end of the list (lowest priority) that are not on a board until
    /// `left` is not negative. `false` (and nothing changed) when that is impossible.
    private static func makeRoom(in tasks: inout [VocabTask], left: inout Int, keeping memberIDs: Set<String>) -> Bool {
        var trimmed = tasks
        var remaining = left
        while remaining < 0 {
            guard let index = trimmed.lastIndex(where: { (task: VocabTask) -> Bool in !memberIDs.contains(task.meaningId) }) else {
                return false
            }
            remaining += trimmed[index].type.estimatedSeconds
            trimmed.remove(at: index)
        }
        tasks = trimmed
        left = remaining
        return true
    }

    /// „Słowa i obrazki” (FEEDBACK-3 H2): only „Słowo i zdjęcie” tasks, for meanings in
    /// `pictureMeaningIDs` (photo and three distractor photos already cached). The mode is chosen
    /// explicitly, so new meanings may take part too. Practiced meanings first (earliest due), then
    /// new ones; at most `minutes × 60 / 20 s` tasks, shown in random order. Empty when no photo is
    /// ready (the screen then explains that photos are still downloading).
    public static func makePictureSession<G: RandomNumberGenerator>(
        state: LearnerState,
        minutes: Int,
        collection: String? = nil,
        pictureMeaningIDs: Set<String>,
        using rng: inout G
    ) -> VocabSession {
        let safeMinutes = max(1, minutes)
        var practiced: [(item: WordMeaning, due: Timestamp)] = []
        var fresh: [WordMeaning] = []
        if !pictureMeaningIDs.isEmpty {
            for word in state.words where !word.archived && (collection == nil || word.collection == collection) {
                for meaning in word.meanings where pictureMeaningIDs.contains(meaning.id) {
                    let item = WordMeaning(word: word, meaning: meaning)
                    if meaning.scores.isEmpty {
                        fresh.append(item)
                    } else {
                        practiced.append((item: item, due: Mastery.due(meaning)))
                    }
                }
            }
        }
        let ordered = practiced.stableSorted { $0.due < $1.due }.map { $0.item } + fresh
        let limit = max(1, safeMinutes * 60 / ExerciseType.picture.estimatedSeconds)
        var seenCounts: [String: Int] = [:]
        for review in state.reviews {
            seenCounts[review.meaningId, default: 0] += 1
        }
        var tasks: [VocabTask] = ordered.prefix(limit).map { (item: WordMeaning) -> VocabTask in
            let example = ExamplePool.nextUnusedExample(item.meaning, fallback: seenCounts[item.meaning.id] ?? 0)
            return VocabTask(wordId: item.word.id, meaningId: item.meaning.id, type: .picture, example: example)
        }
        var index = tasks.count - 1
        while index > 0 {
            let other = rng.nextIndex(below: index + 1)
            tasks.swapAt(index, other)
            index -= 1
        }
        return VocabSession(
            tasks: tasks,
            index: 0,
            correct: 0,
            minutes: safeMinutes,
            mode: StudyMode.pictures.rawValue
        )
    }

    /// `makeSession` with the system random number generator.
    public static func makeSession(state: LearnerState, minutes: Int, mode: StudyMode = .mixed, collection: String? = nil, pictureMeaningIDs: Set<String> = []) -> VocabSession {
        var generator = SystemRandomNumberGenerator()
        return makeSession(state: state, minutes: minutes, mode: mode, collection: collection, pictureMeaningIDs: pictureMeaningIDs, using: &generator)
    }
}
