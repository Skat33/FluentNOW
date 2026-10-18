import XCTest
@testable import FluentKit

/// Starred words (`Word.important`) in sessions and flashcard decks, and the shuffled deck.
final class StarPriorityTests: XCTestCase {
    private func practiced(_ word: Word, due: Timestamp, wrong: Int = 0) -> Word {
        var copy = word
        copy.meanings[0].scores[.recognition] = Score(value: 20, interval: 2, due: due, correct: 2, wrong: wrong, last: testNow - day)
        return copy
    }

    private func starred(_ word: Word) -> Word {
        var copy = word
        copy.important = true
        return copy
    }

    private func freshWords(_ count: Int) -> [Word] {
        (0..<count).map { (index: Int) -> Word in
            TestData.freshWord("w\(index)", "term\(index)", "sens \(index)")
        }
    }

    func testStarredFirstPredicate() {
        let plain = TestData.freshWord("a", "a", "a")
        let star = starred(TestData.freshWord("b", "b", "b"))
        XCTAssertTrue(StudyPriority.starredFirst(star, plain))
        XCTAssertFalse(StudyPriority.starredFirst(plain, star))
        XCTAssertFalse(StudyPriority.starredFirst(star, star), "strict ordering")
        XCTAssertFalse(StudyPriority.starredFirst(plain, plain))
    }

    func testSessionPrefersStarredNewMeaningWithinBudget() {
        var state = TestData.emptyState()
        var words = freshWords(60)
        state.words = words
        var plainGenerator = SeededGenerator(seed: 3)
        let plain = SessionBuilder.makeSession(state: state, minutes: 5, using: &plainGenerator)
        XCTAssertFalse(plain.tasks.contains { $0.wordId == "w59" }, "budget ends long before the last new word")

        words[59] = starred(words[59])
        state.words = words
        var starGenerator = SeededGenerator(seed: 3)
        let session = SessionBuilder.makeSession(state: state, minutes: 5, using: &starGenerator)
        XCTAssertTrue(session.tasks.contains { $0.wordId == "w59" }, "a starred new word wins the tie among new meanings")
    }

    func testSessionKeepsDueReviewsAheadOfStarredNewWords() {
        var state = TestData.emptyState()
        var words = freshWords(60).map { (word: Word) -> Word in starred(word) }
        words.append(practiced(TestData.freshWord("due", "review", "powtórka"), due: testNow - day))
        state.words = words
        var generator = SeededGenerator(seed: 9)
        let session = SessionBuilder.makeSession(state: state, minutes: 5, using: &generator)
        XCTAssertTrue(session.tasks.contains { $0.wordId == "due" }, "practiced meanings still come before new ones")
    }

    func testDeckStarIsTieBreakOnlyForDueAndFirstForNew() {
        var state = TestData.emptyState()
        let dueFirst = practiced(TestData.freshWord("due1", "first", "pierwszy"), due: testNow - 50_000)
        let dueLaterStarred = starred(practiced(TestData.freshWord("due2", "later", "później"), due: testNow - 1_000))
        let tiePlain = practiced(TestData.freshWord("tie1", "tie", "remis"), due: testNow - 20_000)
        let tieStarred = starred(practiced(TestData.freshWord("tie2", "tied", "zremisowany"), due: testNow - 20_000))
        let newPlain = TestData.freshWord("new1", "plain", "zwykły")
        let newStarred = starred(TestData.freshWord("new2", "star", "gwiazda"))
        state.words = [dueLaterStarred, newPlain, tiePlain, dueFirst, newStarred, tieStarred]
        let deck = FlashcardDeckBuilder.makeDeck(state: state, now: testNow)
        XCTAssertEqual(deck.map { $0.wordId }, ["due1", "tie2", "tie1", "due2", "new2", "new1"])
        XCTAssertEqual(deck.map { $0.group }, [.due, .due, .due, .due, .new, .new])
    }

    func testDeckWithoutShuffleIsUnchanged() {
        var state = TestData.emptyState()
        state.words = freshWords(25)
        var generator = SeededGenerator(seed: 1)
        let plain = FlashcardDeckBuilder.makeDeck(state: state, now: testNow)
        let explicit = FlashcardDeckBuilder.makeDeck(state: state, now: testNow, shuffled: false, using: &generator)
        XCTAssertEqual(plain, explicit)
        XCTAssertEqual(plain.map { $0.wordId }, (0..<10).map { "w\($0)" })
    }

    func testShuffledDeckVariesButKeepsPoolsAndStarredNewCards() {
        var state = TestData.emptyState()
        var words = freshWords(25)
        words[24] = starred(words[24])
        words.append(practiced(TestData.freshWord("due", "review", "powtórka"), due: testNow - day))
        state.words = words

        var first = SeededGenerator(seed: 11)
        var second = SeededGenerator(seed: 12)
        let deckA = FlashcardDeckBuilder.makeDeck(state: state, now: testNow, shuffled: true, using: &first)
        let deckB = FlashcardDeckBuilder.makeDeck(state: state, now: testNow, shuffled: true, using: &second)
        for deck in [deckA, deckB] {
            XCTAssertEqual(deck.count, 1 + FlashcardDeckBuilder.defaultNewLimit)
            XCTAssertTrue(deck.contains { $0.wordId == "due" }, "due cards are always drawn")
            XCTAssertTrue(deck.contains { $0.wordId == "w24" }, "the starred new card is always drawn")
            XCTAssertEqual(deck.filter { $0.group == .new }.count, FlashcardDeckBuilder.defaultNewLimit)
            XCTAssertEqual(Set(deck.map { $0.id }).count, deck.count, "no duplicates")
        }
        XCTAssertNotEqual(deckA.map { $0.wordId }, deckB.map { $0.wordId }, "different generators → different order/selection")

        var again = SeededGenerator(seed: 11)
        XCTAssertEqual(FlashcardDeckBuilder.makeDeck(state: state, now: testNow, shuffled: true, using: &again), deckA, "deterministic for a seed")
    }

    func testShuffleIsPermutation() {
        var generator = SeededGenerator(seed: 4)
        let items = Array(0..<50)
        let result = StudyPriority.shuffled(items, using: &generator)
        XCTAssertEqual(result.sorted(), items)
        XCTAssertNotEqual(result, items)
        var empty = SeededGenerator(seed: 4)
        XCTAssertEqual(StudyPriority.shuffled([Int](), using: &empty), [])
        XCTAssertEqual(StudyPriority.shuffled([7], using: &empty), [7])
    }
}
