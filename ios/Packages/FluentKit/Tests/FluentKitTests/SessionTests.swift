import XCTest
@testable import FluentKit

final class SessionTests: XCTestCase {
    private func task(_ type: ExerciseType, _ id: String) -> VocabTask {
        VocabTask(wordId: id, meaningId: id, type: type, example: 0)
    }

    func testNewMeaningsStartWithRecognition() {
        var state = TestData.emptyState()
        state.words = (0..<8).map { TestData.freshWord("w-\($0)", "verb\($0)", "znaczenie \($0)") }
        var generator = SeededGenerator(seed: 5)
        let session = SessionBuilder.makeSession(state: state, minutes: 10, mode: .mixed, using: &generator)
        XCTAssertGreaterThanOrEqual(session.tasks.count, 2)
        // G3: flashcards are not drawn into sessions — the first contact is „Wybierz znaczenie”.
        // FEEDBACK-5 J1: the session then ends with „Dopasuj pary” of the words it introduced
        // (a session is never only „Wybierz znaczenie”).
        XCTAssertEqual(Set(session.tasks.dropLast().map { $0.type }), [.meaning])
        XCTAssertEqual(session.tasks.last?.type, .matchPairs)
        XCTAssertEqual(session.mode, "mixed")
        XCTAssertEqual(session.minutes, 10)
    }

    func testAllowedTaskTypesProgression() {
        var meaning = Meaning(id: "m", translation: "t")
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.meaning])
        XCTAssertTrue(SessionBuilder.isFirstContact(meaning))
        // Seen, never right yet: still the meaning exercise.
        meaning.scores[.recognition] = Score(wrong: 1)
        XCTAssertFalse(SessionBuilder.isFirstContact(meaning))
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.meaning])
        // FEEDBACK-5 J1 (owner: the new exercises did not show up for days): the recognition-style
        // „Zrozum ze słuchu” and „Ułóż zdanie” come right after the first correct recognition
        // (before: two correct recognitions and a recall answer).
        meaning.scores[.recognition] = Score(correct: 1)
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.listeningChoice, .scramble, .meaning])
        meaning.scores[.recognition] = Score(correct: 2)
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.recall, .listeningChoice, .scramble, .meaning])
        meaning.scores[.recall] = Score()
        // FEEDBACK-4 I2: the scramble joins cloze; J1: the listening choice stays in the mix.
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.cloze, .scramble, .recall, .listeningChoice])
        meaning.scores[.usage] = Score()
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.listeningChoice, .dictation, .meaning])
        meaning.scores[.listening] = Score()
        XCTAssertNil(SessionBuilder.allowedTaskTypes(meaning))
    }

    func testPairModeDetectsConfusableUserVocabulary() {
        var state = TestData.emptyState()
        state.words = [
            TestData.freshWord("custom-a", "hire", "zatrudnić pracownika"),
            TestData.freshWord("custom-b", "employ", "zatrudniać ludzi"),
            TestData.freshWord("unrelated", "swim", "pływać")
        ]
        var generator = SeededGenerator(seed: 1)
        let session = SessionBuilder.makeSession(state: state, minutes: 5, mode: .pairs, using: &generator)
        XCTAssertEqual(Set(session.tasks.map { $0.wordId }), ["custom-a", "custom-b"])
        XCTAssertTrue(session.tasks.allSatisfy { $0.type == .cloze })
    }

    func testConfusableByNoteAndStems() {
        let seed = TestData.seed()
        let borrow = WordMeaning(word: seed.words[1], meaning: seed.words[1].meanings[0])
        let lend = WordMeaning(word: seed.words[2], meaning: seed.words[2].meanings[0])
        let swim = WordMeaning(word: TestData.freshWord("s", "swim", "pływać"), meaning: TestData.freshWord("s", "swim", "pływać").meanings[0])
        XCTAssertTrue(ConfusableDetector.confusable(borrow, lend))
        XCTAssertTrue(ConfusableDetector.confusable(lend, borrow))
        XCTAssertFalse(ConfusableDetector.confusable(borrow, borrow))
        XCTAssertFalse(ConfusableDetector.confusable(borrow, swim))
        let items = [borrow, lend, swim]
        let brute = items.filter { item in items.contains { ConfusableDetector.confusable(item, $0) } }
        XCTAssertEqual(ConfusableDetector.itemsWithPartners(items), brute)
    }

    func testConfusableIndexMatchesBruteForceOnSeed() {
        let seed = TestData.seed()
        let items = seed.words.flatMap { word in word.meanings.map { WordMeaning(word: word, meaning: $0) } }
        let brute = items.filter { item in items.contains { ConfusableDetector.confusable(item, $0) } }
        XCTAssertEqual(ConfusableDetector.itemsWithPartners(items), brute)
        XCTAssertTrue(brute.contains { $0.word.en == "say" })
        XCTAssertTrue(brute.contains { $0.word.en == "tell" })
    }

    func testMakeDoOverlapIsConfusableButNotAnAmbiguousDistractor() {
        let make = TestData.freshWord("make", "make", "zrobić, stworzyć")
        let doWord = TestData.freshWord("do", "do", "robić, wykonywać")
        let question = TestData.freshWord("do-q", "do", "czy (w pytaniach)")
        let swim = TestData.freshWord("swim", "swim", "pływać")
        let items = [make, doWord, question, swim].map { WordMeaning(word: $0, meaning: $0.meanings[0]) }
        XCTAssertTrue(ConfusableDetector.confusable(items[0], items[1]))
        XCTAssertFalse(ConfusableDetector.confusable(items[0], items[3]))
        let brute = items.filter { item in items.contains { ConfusableDetector.confusable(item, $0) } }
        XCTAssertEqual(ConfusableDetector.itemsWithPartners(items), brute)
        XCTAssertEqual(brute.map { $0.word.id }, ["make", "do"])

        var state = TestData.seed()
        state.words += [make, doWord, question]
        let task = VocabTask(wordId: "make", meaningId: "m-make", type: .meaning, example: 0)
        let options = MeaningOptions.options(state: state, word: make, meaning: make.meanings[0], task: task)
        XCTAssertFalse(options.contains("robić, wykonywać"), "an accepted answer of make cannot be a wrong option")
        XCTAssertEqual(options.count, 4)
        // Polish grading: „robić” is a correct answer for both senses, „stworzyć” only for make.
        XCTAssertEqual(VocabularyGrader.localGrade(answer: "robić", word: doWord, meaning: doWord.meanings[0], type: .meaning).verdict, .correct)
        XCTAssertEqual(VocabularyGrader.localGrade(answer: "stworzyć", word: doWord, meaning: doWord.meanings[0], type: .meaning).verdict, .incorrect)
        XCTAssertEqual(VocabularyGrader.localGrade(answer: "robić", word: question, meaning: question.meanings[0], type: .meaning).verdict, .incorrect)
        XCTAssertEqual(VocabularyGrader.localGrade(answer: "wykonywać", word: make, meaning: make.meanings[0], type: .meaning).verdict, .incorrect)
    }

    func testClozeReplacesInflectedWordsAndRefusesSubstrings() {
        XCTAssertEqual(Cloze.text("I borrowed your pen.", focus: "borrow"), "I ________ your pen.")
        XCTAssertNil(Cloze.text("This essay is short.", focus: "say"))
        XCTAssertEqual(Cloze.span(in: "She BORROWS books.", focus: "borrow")?.match, "BORROWS")
        XCTAssertEqual(Cloze.text("Take your time, please.", focus: "take your time"), "________, please.")
        XCTAssertNil(Cloze.text("anything", focus: "  "))
        var state = TestData.emptyState()
        var word = TestData.freshWord("essay", "say", "powiedzieć", example: "This essay is short.")
        word.meanings[0].scores[.recognition] = Scheduler.schedule(nil, correct: true, seconds: 2, confidence: 3, hint: false, now: 1, type: .flashcard)
        word.meanings[0].scores[.recognition]?.correct = 2
        word.meanings[0].scores[.recall] = Scheduler.schedule(nil, correct: true, seconds: 2, confidence: 3, hint: false, now: 2, type: .recall)
        state.words = [word]
        for seed in 0..<20 {
            var generator = SeededGenerator(seed: UInt64(seed))
            XCTAssertNotEqual(SessionBuilder.makeSession(state: state, minutes: 5, using: &generator).tasks.first?.type, .cloze)
        }
    }

    func testSessionRespectsBudgetAndFillsWithFreshMeanings() {
        var state = TestData.emptyState()
        state.words = (0..<24).map { TestData.freshWord("w-\($0)", "term\($0)", "tłumaczenie \($0)") }
        for index in 0..<16 {
            state.words[index].meanings[0].scores[.recognition] = Scheduler.schedule(nil, correct: true, seconds: 3, confidence: 3, hint: false, now: 1, type: .flashcard)
        }
        // J1: `UInt64.max` (was `max / 2`) — the generator picks the last drawable type of the
        // reviews' stage, `[.scramble, .meaning]` → „Wybierz znaczenie”, as the budget below assumes.
        var generator = ConstantGenerator(value: UInt64.max)
        let session = SessionBuilder.makeSession(state: state, minutes: 10, using: &generator)
        let fresh = session.tasks.filter { task in state.words.first { $0.id == task.wordId }?.meanings[0].scores.isEmpty ?? false }
        // 16 reviews × 24 s („Wybierz znaczenie”) leave 216 s — room for all 8 new meanings.
        let perTask = ExerciseType.meaning.estimatedSeconds
        XCTAssertEqual(fresh.count, min(8, (600 - 16 * perTask) / perTask))
        XCTAssertEqual(fresh.count, 8)
        // FEEDBACK-5 J1: one correct recognition is enough for „Dopasuj pary” — five of the 16
        // reviews become one board (the freed time has nothing left to refill).
        let boards = session.tasks.filter { $0.type == .matchPairs }
        XCTAssertEqual(boards.count, 1)
        XCTAssertEqual(session.tasks.count, 24 - MatchPairsExercise.pairCount + 1)
        XCTAssertTrue(session.tasks.allSatisfy { $0.type == .meaning || $0.type == .matchPairs })
        XCTAssertLessThanOrEqual(session.tasks.reduce(0) { $0 + $1.type.estimatedSeconds }, 600)
    }

    func testFiveConsecutiveSessionsInterleaveAndFillBudget() {
        var state = TestData.emptyState()
        state.words = (0..<40).map { TestData.freshWord("w\($0)", "term\($0)", "sens \($0)") }
        var generator = SeededGenerator(seed: 17)
        var clock = testNow
        let ids = IDGenerator()
        for round in 0..<5 {
            let session = SessionBuilder.makeSession(state: state, minutes: 10, using: &generator)
            XCTAssertFalse(session.tasks.contains { $0.type == .flashcard }, "round \(round): flashcards never enter a session")
            // FEEDBACK-5 J1: an introduction board („Dopasuj pary” of meanings met for the first
            // time) is appended after the interleaved tasks on purpose — the checks of the
            // interleaving below skip it.
            let introduction = session.tasks.last.map { (task: VocabTask) -> Bool in
                task.type == .matchPairs && task.allRefs.allSatisfy { (ref: VocabTaskRef) -> Bool in
                    state.word(id: ref.wordId)?.meaning(id: ref.meaningId)?.scores[.recognition] == nil
                }
            } ?? false
            let types = (introduction ? Array(session.tasks.dropLast()) : session.tasks).map { $0.type }
            var counts: [ExerciseType: Int] = [:]
            for type in types { counts[type, default: 0] += 1 }
            if round == 0 {
                // 25 × 24 s would fill 600 s; the 50 s board takes the place of three new words.
                XCTAssertTrue(introduction)
                XCTAssertEqual(types.count, (600 - ExerciseType.matchPairs.estimatedSeconds) / ExerciseType.meaning.estimatedSeconds)
                XCTAssertEqual(Set(types), [.meaning])
            }
            let majority = counts.values.max() ?? 0
            if counts.count > 1 && majority <= (types.count + 1) / 2 {
                for index in 1..<types.count {
                    XCTAssertNotEqual(types[index], types[index - 1], "round \(round)")
                }
            }
            let bestPossibleRun = Int((Double(majority) / Double(types.count - majority + 1)).rounded(.up))
            var run = 0
            var longest = 0
            var previous: ExerciseType?
            for type in types {
                run = type == previous ? run + 1 : 1
                longest = max(longest, run)
                previous = type
            }
            XCTAssertLessThanOrEqual(longest, bestPossibleRun)
            XCTAssertLessThanOrEqual(session.tasks.reduce(0) { $0 + $1.type.estimatedSeconds }, 600)
            var a = SeededGenerator(seed: 99)
            var b = SeededGenerator(seed: 99)
            XCTAssertEqual(SessionBuilder.makeSession(state: state, minutes: 10, using: &a).tasks, SessionBuilder.makeSession(state: state, minutes: 10, using: &b).tasks)
            state.session = session
            for task in session.tasks {
                clock += 3_000
                state = Scheduler.recordAnswer(state, task: task, correct: true, seconds: 3, confidence: 3, hint: false, spellingCorrect: true, now: clock, reviewID: ids.next())
            }
            clock += day
        }
    }

    func testInterleaveKeepsAllTasksAndAlternates() {
        let tasks = [ExerciseType.flashcard, .flashcard, .flashcard, .recall, .recall, .cloze].enumerated().map { task($0.element, String($0.offset)) }
        let mixed = TaskInterleaver.interleave(tasks)
        XCTAssertEqual(mixed.map { $0.wordId }.sorted(), tasks.map { $0.wordId }.sorted())
        for index in 1..<mixed.count {
            XCTAssertNotEqual(mixed[index].type, mixed[index - 1].type)
        }
    }

    func testInterleaveSpreadsDominantType() {
        let tasks = (0..<9).map { task(.meaning, "m\($0)") } + [task(.flashcard, "f0"), task(.flashcard, "f1")]
        let mixed = TaskInterleaver.interleave(tasks)
        XCTAssertEqual(mixed.count, 11)
        XCTAssertEqual(mixed.map { $0.type }, [.meaning, .meaning, .meaning, .flashcard, .meaning, .meaning, .meaning, .flashcard, .meaning, .meaning, .meaning])
        let order = mixed.filter { $0.type == .meaning }.map { $0.wordId }
        XCTAssertEqual(order, (0..<9).map { "m\($0)" })
    }

    func testInterleaveEdgeCases() {
        XCTAssertEqual(TaskInterleaver.interleave([]), [])
        let one = [task(.recall, "a")]
        XCTAssertEqual(TaskInterleaver.interleave(one), one)
    }

    func testMistakesModePrioritisesErrors() {
        var state = TestData.emptyState()
        state.words = (0..<3).map { TestData.freshWord("w\($0)", "t\($0)", "s\($0)") }
        state.words[0].meanings[0].scores[.recall] = Score(wrong: 1, last: 1)
        state.words[1].meanings[0].scores[.recall] = Score(wrong: 3, last: 1)
        var generator = SeededGenerator(seed: 3)
        let session = SessionBuilder.makeSession(state: state, minutes: 5, mode: .mistakes, using: &generator)
        XCTAssertEqual(Set(session.tasks.map { $0.wordId }), ["w0", "w1"])
        XCTAssertEqual(session.mode, "mistakes")
    }

    func testCollectionFilterAndArchived() {
        var state = TestData.seed()
        state.words[0].archived = true
        var generator = SeededGenerator(seed: 4)
        let session = SessionBuilder.makeSession(state: state, minutes: 15, collection: "W pracy", using: &generator)
        let allowed = Set(state.words.filter { $0.collection == "W pracy" && !$0.archived }.map { $0.id })
        XCTAssertFalse(session.tasks.isEmpty)
        XCTAssertTrue(session.tasks.allSatisfy { allowed.contains($0.wordId) })
    }

    func testEmptyStateAndPendingExamplesGiveNoTasks() {
        var generator = SeededGenerator(seed: 4)
        XCTAssertTrue(SessionBuilder.makeSession(state: TestData.emptyState(), minutes: 10, using: &generator).tasks.isEmpty)
        var state = TestData.seed()
        state.words = [state.words[0]]
        state.words[0].meanings[0].examples = []
        state.words[0].meanings[0].enrichment = Enrichment(phase: .examples, detailsPending: true, attempts: 1, retryAt: 12345)
        XCTAssertTrue(SessionBuilder.makeSession(state: state, minutes: 5, using: &generator).tasks.isEmpty)
    }

    func testMeaningOptionsAreContextualDeterministicAndShuffled() {
        let state = TestData.seed()
        guard let word = state.word(en: "borrow") else { return XCTFail("missing borrow") }
        let meaning = word.meanings[0]
        var orders = Set<[String]>()
        for example in 0..<6 {
            let task = VocabTask(wordId: word.id, meaningId: meaning.id, type: .meaning, example: example)
            let options = MeaningOptions.options(state: state, word: word, meaning: meaning, task: task)
            XCTAssertEqual(options.count, 4)
            XCTAssertEqual(Set(options).count, 4)
            XCTAssertTrue(options.contains(meaning.translation))
            XCTAssertEqual(options, MeaningOptions.options(state: state, word: word, meaning: meaning, task: task), "same task → same order")
            orders.insert(options)
        }
        XCTAssertGreaterThan(orders.count, 1)
        XCTAssertTrue(orders.contains { $0 != $0.sorted() })
    }

    func testMeaningOptionsWithTinyVocabularyUseStarterPool() {
        var state = TestData.emptyState()
        let word = TestData.freshWord("only", "only", "jedyny")
        state.words = [word]
        let task = VocabTask(wordId: "only", meaningId: "m-only", type: .meaning, example: 0)
        XCTAssertEqual(MeaningOptions.options(state: state, word: word, meaning: word.meanings[0], task: task), ["jedyny"])
        let starter = TestData.seed().words
        XCTAssertEqual(MeaningOptions.options(state: state, word: word, meaning: word.meanings[0], task: task, starterWords: starter).count, 4)
    }

    func testMakeSessionPerformanceOn5000Words() {
        var state = TestData.emptyState()
        state.words = (0..<5_000).map { index in
            var word = TestData.freshWord("w\(index)", "term\(index)", "tłumaczenie numer \(index)")
            if index % 2 == 0 {
                word.meanings[0].scores[.recognition] = Score(value: 30, interval: 3, due: testNow - Double(index) * 1000, correct: 3, wrong: index % 5 == 0 ? 1 : 0, hinted: 0, last: testNow - day, slow: 0)
            }
            return word
        }
        state.reviews = (0..<20_000).map { index in
            Review(id: "r\(index)", wordId: "w\(index % 5_000)", meaningId: "m-w\(index % 5_000)", skill: .recognition, correct: true, at: testNow - Double(index) * 1000, seconds: 3, confidence: 3, hint: false, before: 0, after: 10)
        }
        var generator = SeededGenerator(seed: 8)
        let start = Date()
        let session = SessionBuilder.makeSession(state: state, minutes: 15, using: &generator)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertFalse(session.tasks.isEmpty)
        // Target < 50 ms in release builds; generous margin for unoptimised debug test builds.
        XCTAssertLessThan(elapsed, 1.0)
        var pairsGenerator = SeededGenerator(seed: 9)
        let pairsStart = Date()
        _ = SessionBuilder.makeSession(state: state, minutes: 15, mode: .pairs, using: &pairsGenerator)
        XCTAssertLessThan(Date().timeIntervalSince(pairsStart), 3.0)
    }
}
