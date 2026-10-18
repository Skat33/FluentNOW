import XCTest
@testable import FluentKit

final class SchedulingTests: XCTestCase {
    func testMasteryFromInterval() {
        XCTAssertEqual(Mastery.fromInterval(90), 100)
        XCTAssertEqual(Mastery.fromInterval(0), 0)
        XCTAssertEqual(Mastery.fromInterval(3), 31)
        XCTAssertEqual(Mastery.fromInterval(-5), 0)
        XCTAssertEqual(Mastery.fromInterval(.nan), 0)
        XCTAssertEqual(Mastery.fromInterval(.infinity), 0)
        XCTAssertEqual(Mastery.fromInterval(10_000), 100)
    }

    func testExercisePromptAudio() {
        XCTAssertTrue(ExerciseType.flashcard.promptAudioAllowed)
        XCTAssertFalse(ExerciseType.recall.promptAudioAllowed)
        XCTAssertFalse(ExerciseType.cloze.promptAudioAllowed)
        XCTAssertTrue(ExerciseType.meaning.promptAudioAllowed)
        XCTAssertTrue(ExerciseType.dictation.promptAudioAllowed)
    }

    func testHintsAreSeparateFromErrorsAndGoodAnswersRepairDifficulty() {
        var score = Scheduler.schedule(nil, correct: false, seconds: 4, confidence: 2, hint: false, now: 1, type: .recall)
        score = Scheduler.schedule(score, correct: false, seconds: 4, confidence: 2, hint: false, now: 2, type: .recall)
        score = Scheduler.schedule(score, correct: false, seconds: 4, confidence: 2, hint: false, now: 3, type: .recall)
        let hinted = Scheduler.schedule(score, correct: true, seconds: 4, confidence: 2, hint: true, now: 4, type: .recall)
        XCTAssertEqual(hinted.wrong, 3)
        XCTAssertEqual(hinted.hinted, 1)
        // FSRS (I1): a hinted answer is Hard → at least one whole day (the web heuristic gave 12 h).
        XCTAssertEqual(hinted.interval, 1)
        let recovered = Scheduler.schedule(hinted, correct: true, seconds: 4, confidence: 3, hint: false, now: 5, type: .recall)
        XCTAssertEqual(recovered.wrong, 2)
        var word = TestData.freshWord("hard", "recover", "odzyskać")
        word.meanings[0].scores[.recall] = recovered
        XCTAssertNotEqual(word.status(now: testNow), .hard)
    }

    func testWrongAnswerReturnsInTenMinutes() {
        let score = Scheduler.schedule(nil, correct: false, seconds: 3, confidence: 3, hint: false, now: testNow, type: .flashcard)
        XCTAssertEqual(score.interval, 10.0 / 1440.0, accuracy: 1e-12)
        XCTAssertEqual(score.due, testNow + 10 * 60_000, accuracy: 1)
        XCTAssertEqual(score.wrong, 1)
    }

    func testIntervalIsBoundedAndGrows() {
        var score: Score? = nil
        var previous = 0.0
        for index in 0..<20 {
            let next = Scheduler.schedule(score, correct: true, seconds: 2, confidence: 3, hint: false, now: testNow + Double(index) * 30 * day, type: .recall)
            XCTAssertGreaterThanOrEqual(next.interval, previous)
            // FSRS (I1): the cap is 365 days (the web heuristic stopped at 90).
            XCTAssertLessThanOrEqual(next.interval, Scheduler.maximumInterval)
            XCTAssertGreaterThanOrEqual(next.interval, 1)
            previous = next.interval
            score = next
        }
        XCTAssertEqual(score?.interval, 365)
        XCTAssertEqual(score?.value, 100)
    }

    func testSlowThresholdsDependOnExerciseType() {
        let flashcard = Scheduler.schedule(nil, correct: true, seconds: 14, confidence: 3, hint: false, now: 1, type: .flashcard)
        let cloze = Scheduler.schedule(nil, correct: true, seconds: 14, confidence: 3, hint: false, now: 1, type: .cloze)
        XCTAssertEqual(flashcard.slow, 1)
        XCTAssertEqual(cloze.slow, 0)
    }

    func testNaNAndNegativeTimesAreSafe() {
        let nanSeconds = Scheduler.schedule(nil, correct: true, seconds: .nan, confidence: 3, hint: false, now: testNow)
        XCTAssertEqual(nanSeconds.slow, 0)
        XCTAssertTrue(nanSeconds.interval.isFinite)
        let old = Score(value: 31, interval: 3, due: testNow, correct: 1, wrong: 0, hinted: 0, last: testNow + 10 * day, slow: 0)
        // Last answer in the future (clock moved back): elapsed time is 0, never negative.
        // FSRS (I1): legacy stability 3 → same-day Easy (fast, „Bardzo pewnie”) → S 5.0445 → 5 days
        // (Node reference port; the web heuristic gave 7.5).
        let next = Scheduler.schedule(old, correct: true, seconds: -4, confidence: 3, hint: false, now: testNow)
        XCTAssertEqual(next.interval, 5)
        XCTAssertEqual(next.stability ?? 0, 5.044505, accuracy: 1e-4)
    }

    func testReadingWeightNeverShortensInterval() {
        let base = Score(value: 50, interval: 20, due: testNow, correct: 3, wrong: 0, hinted: 0, last: testNow - day, slow: 0)
        let weighted = Scheduler.schedule(base, correct: true, seconds: 15, confidence: 2, hint: false, now: testNow, type: .meaning, weight: 0.35)
        XCTAssertGreaterThanOrEqual(weighted.interval, 20)
        let full = Scheduler.schedule(base, correct: true, seconds: 15, confidence: 2, hint: false, now: testNow, type: .meaning, weight: 1)
        XCTAssertLessThan(weighted.interval, full.interval)
    }

    func testAllFiveSkillsContributeAndPronunciationDoesNot() {
        var word = TestData.freshWord("mastery", "learn", "uczyć się")
        var score = Scheduler.schedule(nil, correct: true, seconds: 3, confidence: 3, hint: false, now: testNow)
        score.interval = 90
        score.due = testNow + day
        XCTAssertEqual(word.status(now: testNow), .new)
        var zero = score
        zero.interval = 0
        word.meanings[0].scores[.recognition] = zero
        XCTAssertEqual(word.status(now: testNow), .learning)
        word.meanings[0].scores[.recognition] = score
        XCTAssertEqual(word.meanings[0].mastery, 20)
        word.meanings[0].scores[.pronunciation] = score
        XCTAssertEqual(word.meanings[0].mastery, 20)
        for skill in Skill.masterySkills { word.meanings[0].scores[skill] = score }
        word.meanings[0].scores[.spelling] = nil
        XCTAssertEqual(word.meanings[0].mastery, 80)
        XCTAssertEqual(word.status(now: testNow), .learning)
        word.meanings[0].scores[.spelling] = score
        XCTAssertEqual(word.meanings[0].mastery, 100)
        XCTAssertEqual(word.status(now: testNow), .mastered)
        word.meanings[0].scores[.listening]?.due = 1
        XCTAssertEqual(word.status(now: testNow), .needsRefresh)
        var archived = word
        archived.archived = true
        XCTAssertEqual(archived.status(now: testNow), .archived)

        let state = LearnerState(words: [word])
        let reviewed = Scheduler.recordAnswer(state, task: VocabTask(wordId: word.id, meaningId: word.meanings[0].id, type: .recall, example: 0), correct: true, seconds: 3, confidence: 3, hint: false, now: testNow, reviewID: "r1")
        XCTAssertEqual(reviewed.reviews.last?.masteryVersion, 2)
    }

    func testWordMasteryWithoutMeaningsIsZero() {
        var word = TestData.freshWord("x", "x", "x")
        word.meanings = []
        XCTAssertEqual(word.mastery, 0)
        XCTAssertEqual(word.status(now: testNow), .new)
    }

    func testHardStatus() {
        var word = TestData.freshWord("h", "hard", "trudny")
        word.meanings[0].scores[.recall] = Score(value: 0, interval: 0.1, due: 0, correct: 0, wrong: 3, hinted: 0, last: 1, slow: 0)
        XCTAssertEqual(word.status(now: testNow), .hard)
        word.meanings[0].scores[.recall]?.wrong = 2
        XCTAssertEqual(word.status(now: testNow), .learning)
        word.hard = true
        XCTAssertEqual(word.status(now: testNow), .hard)
    }

    func testDue() {
        var meaning = Meaning(id: "m", translation: "t")
        XCTAssertEqual(meaning.due, 0)
        meaning.scores[.recall] = Score(due: 50)
        meaning.scores[.listening] = Score(due: 20)
        XCTAssertEqual(meaning.due, 20)
    }

    func testFailedTaskReturnsAtSessionEndInAnotherFormat() {
        var state = TestData.seed()
        let task = VocabTask(wordId: "w0", meaningId: "m0", type: .recall, example: 0)
        state.session = VocabSession(tasks: [task, VocabTask(wordId: "w1", meaningId: "m1", type: .flashcard, example: 0)], minutes: 5, mode: "mixed")
        let next = Scheduler.recordAnswer(state, task: task, correct: false, seconds: 5, confidence: 2, hint: false, now: testNow, reviewID: "r")
        XCTAssertEqual(next.session?.tasks.count, 3)
        XCTAssertEqual(next.session?.tasks.last?.wordId, "w0")
        XCTAssertNotEqual(next.session?.tasks.last?.type, .recall)
        XCTAssertEqual(next.session?.index, 1)
        XCTAssertEqual(next.session?.correct, 0)
    }

    func testPairsModeRetriesAsCloze() {
        var state = TestData.seed()
        let task = VocabTask(wordId: "w1", meaningId: "m1", type: .cloze, example: 0)
        state.session = VocabSession(tasks: [task], minutes: 5, mode: "pairs")
        let next = Scheduler.recordAnswer(state, task: task, correct: false, seconds: 5, confidence: 2, hint: false, now: testNow, reviewID: "r")
        XCTAssertEqual(next.session?.tasks.last?.type, .cloze)
    }

    func testTargetedAnswerChangesOnlyOneSense() {
        var state = TestData.seed()
        let bank = state.word(en: "bank")
        let untouched = bank?.meanings[1]
        let task = VocabTask(wordId: "w6", meaningId: "m6", type: .recall, example: 0)
        state.session = VocabSession(tasks: [task], minutes: 5, mode: "mixed")
        let next = Scheduler.recordAnswer(state, task: task, correct: true, seconds: 6, confidence: 3, hint: false, now: testNow, reviewID: "r")
        XCTAssertEqual(next.word(en: "bank")?.meanings[1], untouched)
        XCTAssertEqual(next.session?.index, 1)
        XCTAssertGreaterThan(next.word(en: "bank")?.meanings[0].mastery ?? 0, 0)
        XCTAssertEqual(next.word(en: "bank")?.updatedAt, testNow)
    }

    func testSpellingErrorDoesNotEraseMeaningRecall() {
        let state = TestData.seed()
        let before = state.word(en: "bank")?.meanings[0]
        let next = Scheduler.recordAnswer(state, task: VocabTask(wordId: "w6", meaningId: "m6", type: .recall, example: 0), correct: true, seconds: 4, confidence: 3, hint: false, spellingCorrect: false, now: testNow, reviewID: "r")
        let after = next.word(en: "bank")?.meanings[0]
        XCTAssertGreaterThan(after?.scores[.recall]?.value ?? 0, before?.scores[.recall]?.value ?? 0)
        XCTAssertLessThan(after?.scores[.spelling]?.value ?? 100, before?.scores[.spelling]?.value ?? 0)
        XCTAssertEqual(next.reviews.last?.error, "Pisownia")
    }

    func testHintedAnswerHasShorterInterval() {
        var state = TestData.emptyState()
        let word = TestData.freshWord("gate", "gate", "bramka; wyjście")
        state.words = [word]
        let task = VocabTask(wordId: "gate", meaningId: "m-gate", type: .meaning, example: 0)
        let plain = Scheduler.recordAnswer(state, task: task, correct: true, seconds: 3, confidence: 3, hint: false, now: testNow, reviewID: "a")
        let assisted = Scheduler.recordAnswer(state, task: task, correct: true, seconds: 3, confidence: 3, hint: true, now: testNow, reviewID: "b")
        XCTAssertEqual(assisted.reviews.last?.hint, true)
        XCTAssertEqual(assisted.words[0].meanings[0].scores[.recognition]?.hinted, 1)
        XCTAssertLessThan(assisted.words[0].meanings[0].scores[.recognition]?.interval ?? 99, plain.words[0].meanings[0].scores[.recognition]?.interval ?? 0)
        XCTAssertEqual(assisted.reviews.last?.error, "Odpowiedź po podpowiedzi")
    }

    func testRecordAnswerForMissingWordKeepsState() {
        let state = TestData.seed()
        let next = Scheduler.recordAnswer(state, task: VocabTask(wordId: "nope", meaningId: "nope", type: .recall, example: 0), correct: true, seconds: 3, confidence: 3, hint: false, now: testNow)
        XCTAssertEqual(next, state)
    }

    func testUsedExamplesTrackDistinctSentences() {
        var state = TestData.seed()
        state.words = [state.words[0]]
        state.words[0].meanings[0].examples = (0..<15).map { "Sentence \($0)." }
        state.words[0].meanings[0].enrichment = Enrichment(phase: .ready, groups: [.affirmative, .negative, .question])
        let task = VocabTask(wordId: "w0", meaningId: "m0", type: .recall, example: 0)
        var answered = Scheduler.recordAnswer(state, task: task, correct: true, seconds: 4, confidence: 3, hint: false, now: testNow, reviewID: "a")
        answered = Scheduler.recordAnswer(answered, task: task, correct: true, seconds: 4, confidence: 3, hint: false, now: testNow, reviewID: "b")
        XCTAssertEqual(answered.words[0].meanings[0].usedExamples, [0])
        var generator = SeededGenerator(seed: 1)
        XCTAssertEqual(SessionBuilder.makeSession(state: answered, minutes: 5, using: &generator).tasks.first?.example, 1)
        var readingTask = task
        readingTask.example = 3
        let reading = Scheduler.recordAnswer(answered, task: readingTask, correct: true, seconds: 4, confidence: 3, hint: false, source: .reading, now: testNow, reviewID: "c")
        XCTAssertEqual(reading.words[0].meanings[0].usedExamples, [0])
    }

    func testApplyReadingResults() {
        var state = TestData.seed()
        state.session = VocabSession(tasks: [VocabTask(wordId: "w0", meaningId: "m0", type: .flashcard, example: 0)], minutes: 5, mode: "mixed")
        let reading = Reading(id: "r", title: "T", level: "A2", paragraphs: ["P"], questions: [
            ReadingQuestion(question: "Q1", options: ["a", "b", "c", "d"], answer: 2, meaningId: "m6b"),
            ReadingQuestion(question: "Q2", options: ["a", "b", "c", "d"], answer: 0),
            ReadingQuestion(question: "Q3", options: ["a", "b", "c", "d"], answer: 1, meaningId: "missing")
        ])
        let session = ReadingSession(reading: reading, answers: [2, 0, 1], submitted: true)
        let ids = IDGenerator()
        let next = Scheduler.applyReadingResults(state, reading: session, now: testNow, makeID: ids.next)
        XCTAssertEqual(next.reviews.count, state.reviews.count + 1)
        XCTAssertEqual(next.reviews.last?.source, .reading)
        XCTAssertEqual(next.reviews.last?.weight ?? 0, 0.35, accuracy: 1e-9)
        XCTAssertNotNil(next.word(en: "bank")?.meanings[1].scores[.recognition])
        XCTAssertEqual(next.session, state.session)
    }

    func testExamplePoolPublishesWholeBatches() {
        var meaning = Meaning(id: "m", translation: "t", examples: (0..<14).map { "E\($0)" })
        XCTAssertEqual(meaning.availableExampleCount, 14, "legacy meanings use all examples")
        meaning.enrichment = Enrichment(phase: .examples, groups: [.affirmative, .negative])
        XCTAssertEqual(meaning.availableExampleCount, 0)
        meaning.examples = (0..<15).map { "E\($0)" }
        meaning.enrichment = Enrichment(phase: .ready, groups: [.affirmative, .negative, .question])
        XCTAssertEqual(meaning.availableExampleCount, 15)
        meaning.usedExamples = Array(0..<11)
        XCTAssertFalse(ExamplePool.needsExpansion(meaning))
        meaning.usedExamples = Array(0..<12)
        XCTAssertTrue(ExamplePool.needsExpansion(meaning))
        let expanded = ExamplePool.beginExpansion(meaning)
        XCTAssertEqual(expanded.enrichment?.round, 1)
        XCTAssertEqual(expanded.availableExampleCount, 15)
        XCTAssertFalse(ExamplePool.needsExpansion(expanded))
        XCTAssertEqual(ExamplePool.beginExpansion(expanded), expanded)
        XCTAssertEqual(ExamplePool.nextUnusedExample(meaning), 12)
        var all = meaning
        all.usedExamples = Array(0..<15)
        XCTAssertEqual(ExamplePool.nextUnusedExample(all, fallback: 17), 2)
        XCTAssertEqual(ExamplePool.nextUnusedExample(all, fallback: -1), 14)
    }
}
