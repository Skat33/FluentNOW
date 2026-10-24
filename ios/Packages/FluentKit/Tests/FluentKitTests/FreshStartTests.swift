import XCTest
@testable import FluentKit

/// FEEDBACK-6 K1: „Zacznij od nowa” — a new session in place of a paused one, with other
/// sentences / tasks / text (`FreshStart`).
final class FreshStartTests: XCTestCase {
    // MARK: Helpers

    /// A fresh word with `count` example sentences (all with translations).
    private func word(_ id: String, examples count: Int = 3) -> Word {
        var word = TestData.freshWord(id, "term\(id)", "sens \(id)")
        word.meanings[0].examples = (0..<count).map { (index: Int) -> String in "We often use term\(id) in sentence number \(index)." }
        word.meanings[0].exampleTranslations = (0..<count).map { (index: Int) -> String in "Często używamy tego w zdaniu \(index) (\(id))." }
        return word
    }

    private func state(words count: Int, examples: Int = 3) -> LearnerState {
        var state = TestData.emptyState()
        state.words = (0..<count).map { (index: Int) -> Word in word("w\(index)", examples: examples) }
        return state
    }

    // MARK: Example choice

    func testPreferredExampleWithoutAvoidanceIsTheUsualChoice() {
        var meaning = word("a", examples: 4).meanings[0]
        meaning.usedExamples = [0]
        XCTAssertEqual(FreshStart.preferredExample(meaning, fallback: 2, avoiding: []), ExamplePool.nextUnusedExample(meaning, fallback: 2))
        XCTAssertEqual(FreshStart.preferredExample(meaning, fallback: 0, avoiding: [1]), 2, "unused and not avoided")
        meaning.usedExamples = [0, 1, 2, 3]
        XCTAssertEqual(FreshStart.preferredExample(meaning, fallback: 1, avoiding: [1]), 2, "all used — the next one not avoided")
        XCTAssertEqual(FreshStart.preferredExample(meaning, fallback: 1, avoiding: [0, 1, 2, 3]), ExamplePool.nextUnusedExample(meaning, fallback: 1), "everything avoided — usual choice")
        let empty = Meaning(id: "m-empty", translation: "nic", definition: "", examples: [], context: "", register: "")
        XCTAssertEqual(FreshStart.preferredExample(empty, fallback: 3, avoiding: [0]), 0)
    }

    func testExamplesOfASessionSkipMatchPairsBoards() {
        let session = VocabSession(tasks: [
            VocabTask(wordId: "a", meaningId: "m-a", type: .cloze, example: 2),
            VocabTask(wordId: "a", meaningId: "m-a", type: .recall, example: 0),
            VocabTask(wordId: "b", meaningId: "m-b", type: .matchPairs, example: 1, partners: [VocabTaskRef(wordId: "c", meaningId: "m-c")])
        ], minutes: 5, mode: "exercise-cloze")
        let avoided = FreshStart.examples(in: session)
        XCTAssertEqual(avoided["m-a"], [0, 2])
        XCTAssertNil(avoided["m-b"])
        XCTAssertTrue(FreshStart.examples(in: nil as VocabSession?).isEmpty)
    }

    // MARK: One-type sessions

    func testFreshSingleTypeSessionUsesOtherSentences() {
        var state = state(words: 6)
        for type in [ExerciseType.meaning, .recall, .dictation, .cloze] {
            let paused = SingleTypeSession.makeSession(state: state, type: type, minutes: 5, now: testNow)
            XCTAssertFalse(paused.tasks.isEmpty, "\(type)")
            state.session = paused
            let fresh = FreshStart.singleTypeSession(state: state, type: type, minutes: 5, now: testNow)
            XCTAssertEqual(fresh.mode, paused.mode)
            XCTAssertEqual(Set(fresh.tasks.map { $0.meaningId }), Set(paused.tasks.map { $0.meaningId }), "the same words, \(type)")
            let before = FreshStart.examples(in: paused)
            for task in fresh.tasks {
                XCTAssertFalse(before[task.meaningId]?.contains(task.example) ?? false, "\(type): \(task.meaningId) repeats sentence \(task.example)")
            }
        }
    }

    func testFreshSessionKeepsAMeaningWithASingleSentence() {
        var state = state(words: 3, examples: 1)
        let paused = SingleTypeSession.makeSession(state: state, type: .meaning, minutes: 5, now: testNow)
        state.session = paused
        let fresh = FreshStart.singleTypeSession(state: state, type: .meaning, minutes: 5, now: testNow)
        XCTAssertEqual(fresh.tasks.count, paused.tasks.count, "no other sentence — the word stays with the same one")
        XCTAssertEqual(fresh.tasks.map { $0.example }, paused.tasks.map { $0.example })
    }

    func testWithoutAvoidanceTheSessionIsUnchanged() {
        let state = state(words: 5)
        let plain = SingleTypeSession.makeSession(state: state, type: .recall, minutes: 5, now: testNow)
        let explicit = SingleTypeSession.makeSession(state: state, type: .recall, minutes: 5, now: testNow, avoidingExamples: [:])
        XCTAssertEqual(plain, explicit)
    }

    // MARK: Flashcards

    func testFlashcardDeckAvoidsSentencesOfTheAbandonedDeck() {
        let state = state(words: 5)
        let first = FlashcardDeckBuilder.makeDeck(state: state, limit: 10, now: testNow, shuffled: false)
        XCTAssertFalse(first.isEmpty)
        let avoided = FreshStart.examples(in: first)
        let second = FlashcardDeckBuilder.makeDeck(state: state, limit: 10, now: testNow, shuffled: false, avoidingExamples: avoided)
        XCTAssertEqual(second.map { $0.meaningId }, first.map { $0.meaningId })
        for card in second {
            XCTAssertFalse(avoided[card.meaningId]?.contains(card.example) ?? false, "\(card.meaningId)")
        }
    }

    func testFlashcardRunRoundTripsThroughJSON() throws {
        var run = FlashcardRun(cards: [
            FlashcardCard(wordId: "a", meaningId: "m-a", example: 1, group: .due),
            FlashcardCard(wordId: "b", meaningId: "m-b", example: 0, group: .new)
        ])
        run.answer(remembered: false)
        let data = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(FlashcardRun.self, from: data)
        XCTAssertEqual(decoded, run)
        XCTAssertEqual(decoded.index, 1)
        XCTAssertEqual(decoded.cards.count, 3, "the forgotten card returns at the end")
    }

    // MARK: Grammar, production, reading

    func testRestartedPracticeHasOtherTasksAndItsOwnID() {
        let content = TestData.syntheticContent()
        for kind in [PracticeKind.grammar, .idioms, .mixed] {
            var state = PracticeFlow.startPractice(TestData.emptyState(), kind: kind, level: "B1", content: content, now: testNow)
            guard let paused = state.practice else { return XCTFail("no set, \(kind)") }
            state = PracticeFlow.answerPractice(state, choice: 0)
            let restarted = FreshStart.restartPractice(state, kind: kind, level: "B1", content: content, now: testNow + 1000, id: "r1")
            guard let fresh = restarted.practice else { return XCTFail("no new set, \(kind)") }
            XCTAssertNotEqual(fresh.set.id, paused.set.id, "\(kind)")
            XCTAssertEqual(fresh.index, 0)
            XCTAssertTrue(fresh.answers.allSatisfy { $0 < 0 }, "a clean set")
            let old = Set(paused.set.items.map { $0.context })
            XCTAssertTrue(fresh.set.items.allSatisfy { !old.contains($0.context) }, "\(kind): a task of the paused set repeats")
            XCTAssertEqual(restarted.practiceHistory.count, state.practiceHistory.count, "the paused set is not written to history")
        }
    }

    func testRestartedProductionHasOtherTasks() {
        let content = TestData.syntheticContent()
        let state = PracticeFlow.startProduction(TestData.emptyState(), level: "B1", content: content, now: testNow, id: "p1")
        guard let paused = state.production else { return XCTFail("no production set") }
        let restarted = FreshStart.restartProduction(state, level: "B1", content: content, now: testNow + 1000, id: "p2")
        guard let fresh = restarted.production else { return XCTFail("no new production set") }
        XCTAssertEqual(fresh.id, "p2")
        let old = Set(paused.set.items.compactMap { $0.bankId })
        XCTAssertFalse(fresh.set.items.isEmpty)
        XCTAssertTrue(fresh.set.items.allSatisfy { !old.contains($0.bankId ?? "") })
    }

    func testRestartedReadingIsAnotherText() {
        let content = TestData.syntheticContent()
        let state = PracticeFlow.startReading(TestData.emptyState(), bank: content.readings)
        guard let paused = state.reading else { return XCTFail("no reading") }
        let restarted = FreshStart.restartReading(state, bank: content.readings, now: testNow)
        guard let fresh = restarted.reading else { return XCTFail("no new reading") }
        XCTAssertNotEqual(fresh.reading.id, paused.reading.id)
        XCTAssertFalse(fresh.submitted)
        XCTAssertEqual(restarted.readingHistory, state.readingHistory, "the paused text is not written to history")
    }

    func testRestartWithoutBankTasksKeepsTheState() {
        let empty = PracticeContent.empty
        let state = TestData.emptyState()
        XCTAssertNil(FreshStart.restartPractice(state, kind: .grammar, level: "B1", content: empty, now: testNow).practice)
        XCTAssertNil(FreshStart.restartProduction(state, level: "B1", content: empty, now: testNow).production)
        XCTAssertNil(FreshStart.restartReading(state, bank: empty.readings, now: testNow).reading)
    }
}
