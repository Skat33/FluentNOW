import XCTest
@testable import FluentKit

/// Regression tests for bugs fixed during code-qa (instance A). One test per fixed logic bug.
final class CodeQARegressionTests: XCTestCase {

    // MARK: gradingWord uses the same (wrapped) example index as the screen

    func testGradingWordWrapsExampleIndexLikeTheScreen() {
        var word = TestData.freshWord("b", "borrow", "pożyczyć", example: "I borrowed your pen.")
        word.meanings[0].examples = ["I borrowed your pen.", "She borrows books every week."]
        let meaning = word.meanings[0]
        // Index past the end: the screen shows examples[3 % 2] = examples[1].
        let task = VocabTask(wordId: "b", meaningId: "m-b", type: .cloze, example: 3)
        XCTAssertEqual(VocabularyGrader.exampleIndex(3, in: meaning), 1)
        XCTAssertEqual(VocabularyGrader.exampleIndex(-1, in: meaning), 1)
        XCTAssertEqual(VocabularyGrader.gradingWord(word: word, meaning: meaning, task: task).en, "borrows")
        // In-range index is unchanged.
        let first = VocabTask(wordId: "b", meaningId: "m-b", type: .cloze, example: 0)
        XCTAssertEqual(VocabularyGrader.gradingWord(word: word, meaning: meaning, task: first).en, "borrowed")
        // No examples: the word is graded as is, no crash.
        var empty = meaning
        empty.examples = []
        XCTAssertEqual(VocabularyGrader.exampleIndex(5, in: empty), 0)
        XCTAssertEqual(VocabularyGrader.gradingWord(word: word, meaning: empty, task: task).en, "borrow")
    }

    // MARK: A word deleted while a session is paused

    func testDeletedWordInPausedSessionAdvancesWithoutRetry() {
        var state = TestData.seed()
        let missing = VocabTask(wordId: "deleted", meaningId: "deleted-m", type: .recall, example: 0)
        let next = VocabTask(wordId: "w0", meaningId: "m0", type: .flashcard, example: 0)
        state.session = VocabSession(tasks: [missing, next], minutes: 5, mode: "mixed")
        let answered = Scheduler.recordAnswer(state, task: missing, correct: false, seconds: 3, confidence: 2, hint: false, now: testNow, reviewID: "r")
        XCTAssertEqual(answered.session?.index, 1, "the session moves on instead of getting stuck")
        XCTAssertEqual(answered.session?.tasks, [missing, next], "no retry for a word that no longer exists")
        XCTAssertEqual(answered.reviews, state.reviews, "nothing is scored")
        XCTAssertEqual(answered.words, state.words)
        XCTAssertEqual(answered.session?.currentTask, next)
    }

    func testMissingWordOutsideTheCurrentTaskKeepsState() {
        var state = TestData.seed()
        let current = VocabTask(wordId: "w0", meaningId: "m0", type: .flashcard, example: 0)
        state.session = VocabSession(tasks: [current], minutes: 5, mode: "mixed")
        let other = VocabTask(wordId: "deleted", meaningId: "deleted-m", type: .recall, example: 0)
        XCTAssertEqual(Scheduler.recordAnswer(state, task: other, correct: true, seconds: 3, confidence: 3, hint: false, now: testNow), state)
    }

    func testMigrationKeepsPausedSessionWhenAnAnsweredWordWasDeleted() {
        var state = TestData.seed()
        let done = VocabTask(wordId: "w1", meaningId: "m1", type: .flashcard, example: 0)
        let pending = VocabTask(wordId: "w2", meaningId: "m2", type: .flashcard, example: 0)
        state.session = VocabSession(tasks: [done, pending], index: 1, correct: 1, minutes: 5, mode: "mixed")
        state.words.removeAll { $0.id == "w1" }
        let migrated = StateMigration.migrate(state)
        XCTAssertNotNil(migrated.session, "deleting an already answered word must not discard the paused session")
        XCTAssertEqual(migrated.session?.index, 1)
        XCTAssertEqual(migrated.session?.currentTask, pending)
        XCTAssertEqual(StateMigration.migrate(migrated), migrated, "idempotent")

        // Pending task of a deleted word is removed; with nothing left the finished session goes away.
        var onlyDeleted = state
        onlyDeleted.words.removeAll { $0.id == "w2" }
        XCTAssertNil(StateMigration.migrate(onlyDeleted).session)
    }

    func testCombinedSessionSavesAndAdvancesPastDeletedWord() {
        var state = TestData.seed()
        let deleted = CombinedTask.vocabulary(mode: .mixed, task: VocabTask(wordId: "deleted", meaningId: "deleted-m", type: .recall, example: 0))
        let question = CombinedTask.question(CombinedQuestionTask(
            mode: .grammar,
            question: PracticeQuestion(category: .grammar, prompt: "p", context: "c", options: ["a", "b", "c", "d"], answer: 0),
            level: "A2"
        ))
        state.combined = CombinedSession(id: "c", modes: [.mixed, .grammar], random: false, minutes: 5, tasks: [deleted, question], updatedAt: 1)
        let answer = CombinedAnswer(value: "", correct: false, seconds: 0.1, spellingCorrect: false, explanation: "Słowo nie jest już dostępne.")
        let saved = CombinedSessionBuilder.saveAnswer(state, answer: answer, now: testNow, reviewID: "r")
        XCTAssertEqual(saved.combined?.answers.first ?? nil, answer)
        XCTAssertEqual(saved.reviews, state.reviews, "a deleted word is not scored")
        let advanced = CombinedSessionBuilder.advance(saved, now: testNow)
        XCTAssertEqual(advanced.combined?.index, 1)
        XCTAssertEqual(advanced.combined?.currentTask, question)
    }

    // MARK: Practice / production cannot skip an unanswered item (double tap)

    func testPracticeAdvanceRequiresAnAnswer() {
        let content = TestData.syntheticContent()
        let started = PracticeFlow.startPractice(TestData.seed(), kind: .grammar, level: "B1", content: content, now: testNow)
        XCTAssertEqual(PracticeFlow.advancePractice(started, now: testNow), started, "unanswered item is not skipped")
        guard let item = started.practice?.set.items.first else { return XCTFail("no practice") }
        let answered = PracticeFlow.answerPractice(started, choice: item.answer)
        let advanced = PracticeFlow.advancePractice(answered, now: testNow)
        XCTAssertEqual(advanced.practice?.index, 1)
        XCTAssertEqual(PracticeFlow.advancePractice(advanced, now: testNow), advanced, "second tap does not skip the next item")
    }

    func testProductionAdvanceRequiresAGradedAnswer() {
        let content = TestData.syntheticContent()
        let started = PracticeFlow.startProduction(TestData.seed(), level: "B1", content: content, now: testNow, id: "p")
        XCTAssertEqual(PracticeFlow.advanceProduction(started, now: testNow), started)
        guard let item = started.production?.set.items.first else { return XCTFail("no production") }
        let answered = PracticeFlow.answerProduction(started, text: item.answer)
        let advanced = PracticeFlow.advanceProduction(answered, now: testNow)
        XCTAssertEqual(advanced.production?.index, 1)
        XCTAssertEqual(PracticeFlow.advanceProduction(advanced, now: testNow), advanced)
    }
}
