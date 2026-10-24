import Foundation

/// One graded answer handed over by the test screen.
public struct AssessmentResponse: Sendable, Hashable {
    /// Typed text, chosen option text, „4/5” for a board.
    public var value: String
    public var correct: Bool
    public var spellingCorrect: Bool
    /// Answer time (for FSRS).
    public var seconds: Double
    /// Time on screen (for the test clock; ≥ `seconds`, e.g. including the reading passage).
    public var elapsedSeconds: Double
    /// Type actually shown when the screen had to fall back (e.g. pairs → meaning); `nil` = the
    /// question's own type.
    public var shownType: ExerciseType?
    /// „Dopasuj pary”: result per meaning (empty for other questions).
    public var pairResults: [MatchPairResult]

    public init(value: String, correct: Bool, spellingCorrect: Bool = true, seconds: Double, elapsedSeconds: Double = 0, shownType: ExerciseType? = nil, pairResults: [MatchPairResult] = []) {
        self.value = value
        self.correct = correct
        self.spellingCorrect = spellingCorrect
        self.seconds = finiteNonNegative(seconds)
        self.elapsedSeconds = finiteNonNegative(elapsedSeconds)
        self.shownType = shownType
        self.pairResults = pairResults
    }
}

/// Running the level test: drawing the next question (adaptation), recording answers (own words
/// through `Scheduler.recordAnswer` / `MatchPairsExercise.record` like ordinary reviews — base
/// words are never written to the vocabulary), finishing, skipping and abandoning.
/// The running vocabulary session (`state.session`) is never touched.
public enum AssessmentEngine {
    /// Confidence used for test answers (no confidence picker in the test).
    public static let confidence = 2

    // MARK: Working state

    /// The learner state plus the base words of the test — what the exercise screens use to show
    /// a question (distractors, pairs, listening options). Never saved.
    public static func workingState(_ state: LearnerState, session: AssessmentSession) -> LearnerState {
        guard !session.bankWords.isEmpty else { return state }
        var next = state
        let existing = Set(state.words.map { (word: Word) -> String in word.id })
        for word in session.bankWords where !existing.contains(word.id) {
            next.words.append(word)
        }
        return next
    }

    /// `true` when the meaning is one of the learner's own words (still in the vocabulary).
    public static func isOwned(_ state: LearnerState, wordId: String, meaningId: String) -> Bool {
        guard !AssessmentBuilder.isBankID(wordId) else { return false }
        return state.word(id: wordId)?.meaning(id: meaningId) != nil
    }

    // MARK: Drawing questions

    /// Makes sure the current question is ready: draws it for its slot; a slot that cannot be
    /// filled any more (pool exhausted, words deleted) is removed.
    public static func prepareCurrent(_ session: AssessmentSession, state: LearnerState) -> AssessmentSession {
        var current = session
        guard current.completedAt == nil else { return current }
        let working = workingState(state, session: current)
        let listeningReady = ListeningChoice.hasDistractorPool(working)
        while current.index < current.slots.count && current.questions.count <= current.index {
            let block = current.slots[current.index]
            if let question = makeQuestion(block, session: current, working: working, listeningReady: listeningReady) {
                current.questions.append(question)
            } else {
                current.slots.remove(at: current.index)
            }
        }
        return current
    }

    static func makeQuestion(_ block: AssessmentBlock, session: AssessmentSession, working: LearnerState, listeningReady: Bool) -> AssessmentQuestion? {
        switch block {
        case .grammar:
            let asked = session.questions.filter { (question: AssessmentQuestion) -> Bool in question.block == .grammar }.count
            guard let question = session.grammar[safe: asked] else { return nil }
            return .text(AssessmentTextQuestion(block: .grammar, question: question, level: session.band.base))
        case .reading:
            let asked = session.questions.filter { (question: AssessmentQuestion) -> Bool in question.block == .reading }.count
            guard let reading = session.reading, let item = reading.questions[safe: asked] else { return nil }
            let question = PracticeQuestion(
                format: .choice,
                category: .grammar,
                prompt: item.question,
                context: "",
                options: item.options,
                answer: item.answer,
                explanation: item.explanation
            )
            let level = CEFR.isValid(reading.level) ? reading.level : session.band.base
            return .text(AssessmentTextQuestion(block: .reading, question: question, level: level, readingIndex: asked))
        case .matchPairs:
            return makeBoard(session: session, working: working)
        case .meaning, .recall, .cloze, .scramble, .listening, .dictation:
            return makeVocabulary(block, session: session, working: working, listeningReady: listeningReady)
        }
    }

    /// Tier for the next vocabulary question (adaptation over the answers so far).
    static func nextTier(_ session: AssessmentSession) -> AssessmentTier {
        let vocabularySlots = session.slots.filter { (block: AssessmentBlock) -> Bool in block.isVocabulary }.count
        let drawn = session.questions.compactMap { (question: AssessmentQuestion) -> AssessmentVocabQuestion? in question.vocabulary }
        let stretchUsed = drawn.filter { (question: AssessmentVocabQuestion) -> Bool in question.tier == .stretch }.count
        return AssessmentAdaptation.preferredTier(
            outcomes: session.outcomes,
            position: drawn.count,
            stretchUsed: stretchUsed,
            stretchCap: AssessmentAdaptation.stretchCap(vocabularyCount: vocabularySlots),
            hasStretchLevel: session.band.stretch != nil,
            lastWasStretch: drawn.last?.tier == .stretch
        )
    }

    /// Meanings and words already used by the test (one question per word).
    static func usedKeys(_ session: AssessmentSession) -> (meanings: Set<String>, words: Set<String>) {
        var meanings = Set<String>()
        var words = Set<String>()
        for question in session.questions {
            guard let vocabulary = question.vocabulary else { continue }
            for ref in vocabulary.task.allRefs {
                meanings.insert(ref.meaningId)
                words.insert(ref.wordId)
            }
        }
        return (meanings, words)
    }

    static func makeVocabulary(_ block: AssessmentBlock, session: AssessmentSession, working: LearnerState, listeningReady: Bool) -> AssessmentQuestion? {
        guard let type = block.exerciseType else { return nil }
        let used = usedKeys(session)
        for tier in AssessmentAdaptation.tierOrder(nextTier(session)) {
            for candidate in session.candidates where session.band.tier(of: candidate.level) == tier {
                guard !used.meanings.contains(candidate.meaningId), !used.words.contains(candidate.wordId),
                      let word = working.word(id: candidate.wordId), !word.archived,
                      let meaning = word.meaning(id: candidate.meaningId) else { continue }
                let preferred = ExamplePool.nextUnusedExample(meaning, fallback: 0)
                guard let example = SingleTypeSession.buildableExample(type, word: word, meaning: meaning, preferred: preferred, listeningReady: listeningReady) else { continue }
                let task = VocabTask(wordId: word.id, meaningId: meaning.id, type: type, example: example)
                return .vocabulary(AssessmentVocabQuestion(block: block, task: task, tier: tier, level: candidate.level))
            }
        }
        return nil
    }

    /// One „Dopasuj pary” board of up to five distinct meanings, preferred tier first.
    static func makeBoard(session: AssessmentSession, working: LearnerState) -> AssessmentQuestion? {
        let used = usedKeys(session)
        // A board never uses the stretch part (it would not count towards the 15 % cap).
        let wanted = nextTier(session)
        let preferred: AssessmentTier = wanted == .stretch ? .upper : wanted
        var members: [WordMeaning] = []
        var tasks: [VocabTask] = []
        for tier in AssessmentAdaptation.tierOrder(preferred) {
            for candidate in session.candidates where session.band.tier(of: candidate.level) == tier {
                guard tasks.count < MatchPairsExercise.pairCount else { break }
                guard !used.meanings.contains(candidate.meaningId), !used.words.contains(candidate.wordId),
                      let word = working.word(id: candidate.wordId), !word.archived,
                      let meaning = word.meaning(id: candidate.meaningId) else { continue }
                let item = WordMeaning(word: word, meaning: meaning)
                guard MatchPairsExercise.canJoinBoard(item),
                      members.allSatisfy({ (other: WordMeaning) -> Bool in MatchPairsExercise.areDistinct(other, item) }) else { continue }
                members.append(item)
                tasks.append(VocabTask(wordId: word.id, meaningId: meaning.id, type: .matchPairs, example: 0))
            }
        }
        guard tasks.count >= MatchPairsExercise.minimumPairs, let board = MatchPairsExercise.boardTask(tasks) else { return nil }
        return .vocabulary(AssessmentVocabQuestion(block: .matchPairs, task: board, tier: preferred, level: session.band.level(of: preferred)))
    }

    // MARK: Answering

    /// Records the answer to the current question and moves on (no way back). Own words are
    /// scored like ordinary reviews; grammar tasks are marked as seen. The last answer finishes
    /// the test and appends the history entry.
    public static func answer(_ state: LearnerState, response: AssessmentResponse, now: Timestamp, reviewID: String = UUID().uuidString.lowercased()) -> LearnerState {
        guard var session = state.assessment, session.completedAt == nil, let question = session.currentQuestion else { return state }
        var next = state
        let answer: AssessmentAnswer
        switch question {
        case .vocabulary(let vocabulary):
            let working = workingState(state, session: session)
            let recorded = recordVocabulary(next, working: working, question: vocabulary, response: response, now: now, reviewID: reviewID)
            next = recorded.state
            answer = recorded.answer
        case .text(let text):
            answer = textAnswer(text, session: session, response: response)
            if text.block == .grammar {
                next = GrammarSelector.markSeen(next, bankId: text.question.bankId, context: text.question.context, at: now)
            }
        }
        session.answers.append(answer)
        session.index += 1
        session.activeSeconds += max(response.seconds, response.elapsedSeconds)
        session.updatedAt = now
        next.assessment = session
        return advance(next, now: now)
    }

    /// The current question cannot be shown (its word was deleted meanwhile): its slot is dropped.
    public static func skipCurrent(_ state: LearnerState, now: Timestamp) -> LearnerState {
        guard var session = state.assessment, session.completedAt == nil, session.index < session.slots.count else { return state }
        if session.questions.count > session.index {
            session.questions.remove(at: session.index)
        }
        session.slots.remove(at: session.index)
        session.updatedAt = now
        var next = state
        next.assessment = session
        return advance(next, now: now)
    }

    /// Prepares the next question, or finishes the test after the last one.
    static func advance(_ state: LearnerState, now: Timestamp) -> LearnerState {
        guard var session = state.assessment else { return state }
        var next = state
        if !session.isFinished {
            session = prepareCurrent(session, state: state)
        }
        guard session.isFinished else {
            next.assessment = session
            return next
        }
        guard !session.answers.isEmpty else {
            next.assessment = nil
            return next
        }
        session.completedAt = now
        session.updatedAt = now
        let result = AssessmentScoring.result(session)
        let entry = AssessmentScoring.historyEntry(session, result: result, at: now)
        if !next.assessmentHistory.contains(where: { (item: AssessmentHistoryEntry) -> Bool in item.id == entry.id }) {
            next.assessmentHistory.append(entry)
        }
        next.assessment = compacted(session)
        return next
    }

    /// A finished test keeps only what the result screen needs (base words that were asked).
    static func compacted(_ session: AssessmentSession) -> AssessmentSession {
        var copy = session
        var asked = Set<String>()
        for answer in session.answers {
            for item in answer.items where !item.owned {
                asked.insert(item.wordId)
            }
        }
        copy.bankWords = session.bankWords.filter { (word: Word) -> Bool in asked.contains(word.id) }
        copy.candidates = []
        return copy
    }

    /// Wyjście z testu bez wyniku („Porzuć”). Answers already given stay in the review history.
    public static func abandon(_ state: LearnerState) -> LearnerState {
        guard state.assessment?.completedAt == nil else { return state }
        var next = state
        next.assessment = nil
        return next
    }

    /// Closes the result screen of a finished test (the history entry stays).
    public static func dismissResult(_ state: LearnerState) -> LearnerState {
        guard state.assessment?.completedAt != nil else { return state }
        var next = state
        next.assessment = nil
        return next
    }

    // MARK: Recording

    static func recordVocabulary(
        _ state: LearnerState,
        working: LearnerState,
        question: AssessmentVocabQuestion,
        response: AssessmentResponse,
        now: Timestamp,
        reviewID: String
    ) -> (state: LearnerState, answer: AssessmentAnswer) {
        if question.task.type == .matchPairs && !response.pairResults.isEmpty {
            return recordBoard(state, working: working, question: question, response: response, now: now, reviewID: reviewID)
        }
        let type = response.shownType ?? question.task.type
        let task = VocabTask(wordId: question.task.wordId, meaningId: question.task.meaningId, type: type, example: question.task.example)
        var next = state
        let owned = isOwned(state, wordId: task.wordId, meaningId: task.meaningId)
        if owned {
            let running = next.session
            next.session = nil
            next = Scheduler.recordAnswer(
                next,
                task: task,
                correct: response.correct,
                seconds: response.seconds,
                confidence: confidence,
                hint: false,
                spellingCorrect: response.spellingCorrect,
                now: now,
                reviewID: reviewID
            )
            next.session = running
        }
        var prompt = ""
        var expected = ""
        var contentRef: String?
        if let word = working.word(id: task.wordId), let meaning = word.meaning(id: task.meaningId) {
            prompt = AssessmentText.prompt(task: task, word: word, meaning: meaning)
            expected = AssessmentText.expected(task: task, word: word, meaning: meaning)
            contentRef = meaning.contentRef
        }
        let item = AssessmentItemResult(
            wordId: task.wordId,
            meaningId: task.meaningId,
            owned: owned,
            contentRef: contentRef,
            correct: response.correct,
            prompt: prompt,
            expected: expected
        )
        let answer = AssessmentAnswer(
            value: response.value,
            correct: response.correct,
            points: response.correct ? 1 : 0,
            seconds: response.seconds,
            prompt: prompt,
            expected: expected,
            items: [item]
        )
        return (next, answer)
    }

    static func recordBoard(
        _ state: LearnerState,
        working: LearnerState,
        question: AssessmentVocabQuestion,
        response: AssessmentResponse,
        now: Timestamp,
        reviewID: String
    ) -> (state: LearnerState, answer: AssessmentAnswer) {
        var items: [AssessmentItemResult] = []
        var ownedResults: [MatchPairResult] = []
        for result in response.pairResults {
            let owned = isOwned(state, wordId: result.wordId, meaningId: result.meaningId)
            if owned { ownedResults.append(result) }
            let found = working.word(id: result.wordId).flatMap { (word: Word) -> (Word, Meaning)? in
                word.meaning(id: result.meaningId).map { (meaning: Meaning) -> (Word, Meaning) in (word, meaning) }
            }
            items.append(AssessmentItemResult(
                wordId: result.wordId,
                meaningId: result.meaningId,
                owned: owned,
                contentRef: found?.1.contentRef,
                correct: result.correct,
                prompt: found?.0.en ?? "",
                expected: found.map { (pair: (Word, Meaning)) -> String in TextNormalizer.withoutDialectLabel(pair.1.translation) } ?? ""
            ))
        }
        var next = state
        if !ownedResults.isEmpty {
            next = MatchPairsExercise.record(
                next,
                task: question.task,
                results: ownedResults,
                seconds: response.seconds * Double(ownedResults.count) / Double(max(1, response.pairResults.count)),
                confidence: confidence,
                now: now,
                reviewID: reviewID,
                advancesSession: false
            )
        }
        let right = items.filter { (item: AssessmentItemResult) -> Bool in item.correct }.count
        let total = max(1, items.count)
        let answer = AssessmentAnswer(
            value: "\(right)/\(items.count)",
            correct: right == items.count && !items.isEmpty,
            points: Double(right) / Double(total),
            seconds: response.seconds,
            prompt: "Dopasuj pary",
            expected: items.map { (item: AssessmentItemResult) -> String in "\(item.prompt) — \(item.expected)" }.joined(separator: "; "),
            items: items
        )
        return (next, answer)
    }

    static func textAnswer(_ question: AssessmentTextQuestion, session: AssessmentSession, response: AssessmentResponse) -> AssessmentAnswer {
        let prompt: String
        if question.block == .grammar {
            prompt = question.question.context.isEmpty ? question.question.prompt : question.question.context
        } else {
            prompt = question.question.prompt
        }
        return AssessmentAnswer(
            value: response.value,
            correct: response.correct,
            points: response.correct ? 1 : 0,
            seconds: response.seconds,
            prompt: prompt,
            expected: question.question.correctOption
        )
    }

    // MARK: After the test

    /// „Dodaj błędne słowa do powtórek”: own words answered wrong are marked as difficult
    /// („Trudne” — first in the mistakes mode and the flashcard deck). Returns the number of
    /// words changed.
    public static func markWrongWordsHard(_ state: LearnerState, now: Timestamp) -> (state: LearnerState, count: Int) {
        guard let session = state.assessment else { return (state, 0) }
        var next = state
        var changed = 0
        for wordID in AssessmentScoring.wrongOwnedWordIDs(session) {
            guard let index = next.wordIndex(id: wordID), !next.words[index].hard else { continue }
            next.words[index].hard = true
            next.words[index].updatedAt = now
            changed += 1
        }
        return (next, changed)
    }
}

/// Texts of the result list (what was asked and the right answer) — never shown during the test.
public enum AssessmentText {
    static func exampleIndex(_ task: VocabTask, meaning: Meaning) -> Int {
        VocabularyGrader.exampleIndex(task.example, in: meaning)
    }

    static func focus(word: Word, meaning: Meaning, index: Int) -> String {
        let saved = meaning.exampleFocusEn?[safe: index] ?? ""
        return saved.isEmpty ? word.en : saved
    }

    /// What the question asked about.
    public static func prompt(task: VocabTask, word: Word, meaning: Meaning) -> String {
        let index = exampleIndex(task, meaning: meaning)
        let sentence = meaning.examples[safe: index] ?? ""
        switch task.type {
        case .meaning, .flashcard, .picture, .matchPairs:
            return word.en
        case .recall, .dictation:
            return TextNormalizer.withoutDialectLabel(meaning.translation)
        case .cloze:
            return Cloze.text(sentence, focus: focus(word: word, meaning: meaning, index: index)) ?? sentence
        case .scramble:
            let translation = meaning.exampleTranslations?[safe: index] ?? ""
            return translation.isEmpty ? "Zdanie ze słowem „\(word.en)”" : translation
        case .listeningChoice:
            return sentence
        }
    }

    /// The right answer.
    public static func expected(task: VocabTask, word: Word, meaning: Meaning) -> String {
        let index = exampleIndex(task, meaning: meaning)
        switch task.type {
        case .meaning, .flashcard, .picture, .matchPairs:
            return TextNormalizer.withoutDialectLabel(meaning.translation)
        case .recall, .dictation:
            return word.en
        case .cloze:
            return VocabularyGrader.gradingWord(word: word, meaning: meaning, task: task).en
        case .scramble:
            return meaning.examples[safe: index] ?? word.en
        case .listeningChoice:
            return ListeningChoice.translation(meaning: meaning, exampleIndex: index) ?? meaning.translation
        }
    }
}
