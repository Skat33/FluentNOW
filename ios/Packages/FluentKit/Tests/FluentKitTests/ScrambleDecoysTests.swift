import XCTest
@testable import FluentKit

/// FEEDBACK-9 N1: „Ułóż zdanie” with the Polish sentence and 1–3 decoys that are unambiguously wrong.
final class ScrambleDecoysTests: XCTestCase {
    // MARK: Helpers

    private func word(_ id: String, _ en: String, level: String = "B1", examples: [String], focus: [String]? = nil) -> Word {
        var item = TestData.freshWord(id, en, "tłumaczenie")
        item.level = level
        item.meanings[0].examples = examples
        item.meanings[0].exampleTranslations = examples.map { (_: String) -> String in "Polskie zdanie." }
        item.meanings[0].exampleFocusEn = focus
        return item
    }

    private func keys(_ sentence: String) -> [String] {
        SentenceScramble.tokens(sentence).map { (token: String) -> String in SentenceScramble.key(token) }
    }

    // MARK: Verb forms

    func testVerbFormsAreOnlyUngrammaticReplacements() {
        // go / went / gone: every form gets one that cannot stand in its place.
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "went", previous: "she"), "gone")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "gone", previous: "has"), "went")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "go", previous: "to"), "gone")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "goes", previous: "she"), "gone")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "going", previous: "is"), "went")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "taking", previous: "i'm"), "took")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "swimming", previous: "like"), "swam")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "written", previous: "was"), "wrote")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "broken", previous: "is"), "break", "„broke” is also an adjective")

        // buy / bought / bought: only where the context rules the other form out.
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "buy", previous: "to"), "bought")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "buy", previous: "can"), "bought")
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "buy", previous: "i"), "„I bought” would be another correct sentence")
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "bought", previous: "we"), "„we buy” would be correct English")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "made", previous: "have"), "make")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "left", previous: "has"), "leave")
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "left", previous: "turn"), "„turn left” — a direction")
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "meeting", previous: "is"), "meet")
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "meeting", previous: "a"), "„a meet” is a noun")

        // come / came / come: the participle equals the base.
        XCTAssertEqual(ScrambleDecoys.verbFormDecoy(for: "come", previous: "have"), "came")
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "came", previous: "they"), "„they come” would be correct English")
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "ran", previous: "i"))

        // Left out on purpose.
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "drink", previous: "a"), "„a drunk” is a noun")
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "got", previous: "i"), "got / gotten are both American")
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "is", previous: "it"))
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "morning", previous: "the"))
        XCTAssertNil(ScrambleDecoys.verbFormDecoy(for: "thing", previous: "a"))
    }

    func testEveryStrictVerbHasThreeDifferentForms() {
        for verb in ScrambleDecoys.irregularVerbs where verb.hasStrictForms {
            XCTAssertNotEqual(verb.base, verb.past)
            XCTAssertNotEqual(verb.past, verb.participle)
        }
        let bases = ScrambleDecoys.irregularVerbs.map { (verb: ScrambleDecoys.IrregularVerb) -> String in verb.base }
        XCTAssertEqual(Set(bases).count, bases.count, "no duplicate verbs")
        XCTAssertFalse(bases.contains("be") || bases.contains("have") || bases.contains("do") || bases.contains("get"))
    }

    // MARK: Prepositions and articles

    func testPrepositionDecoysOnlyInFixedPhrases() {
        let depends = keys("It depends on the weather.")
        XCTAssertEqual(ScrambleDecoys.prepositionDecoy(keys: depends, at: 2), "from")
        let night = keys("We never go out at night.")
        XCTAssertEqual(ScrambleDecoys.prepositionDecoy(keys: night, at: 4), "on")
        let monday = keys("See you on Monday morning.")
        XCTAssertEqual(ScrambleDecoys.prepositionDecoy(keys: monday, at: 2), "in")
        let morning = keys("It was cold in the morning.")
        XCTAssertEqual(ScrambleDecoys.prepositionDecoy(keys: morning, at: 3), "at")
        let year = keys("She was born in 1990.")
        XCTAssertEqual(ScrambleDecoys.prepositionDecoy(keys: year, at: 3), "on")
        let forward = keys("I'm looking forward to the trip.")
        XCTAssertEqual(ScrambleDecoys.prepositionDecoy(keys: forward, at: 3), "for")
        let interested = keys("I am interested in modern art.")
        XCTAssertEqual(ScrambleDecoys.prepositionDecoy(keys: interested, at: 3), "on")

        // „in/on/at the box”, „at the station” — several prepositions could be right.
        let box = keys("Put the keys in the box.")
        XCTAssertNil(ScrambleDecoys.prepositionDecoy(keys: box, at: 3))
        let station = keys("I will wait at the station.")
        XCTAssertNil(ScrambleDecoys.prepositionDecoy(keys: station, at: 3))
    }

    func testArticleSwapOnlyWithoutOtherDeterminers() {
        XCTAssertEqual(ScrambleDecoys.articleDecoy(keys: keys("I need a new phone charger.")), "an")
        XCTAssertEqual(ScrambleDecoys.articleDecoy(keys: keys("She ate an apple after lunch.")), "a")
        XCTAssertNil(ScrambleDecoys.articleDecoy(keys: keys("I lost my umbrella and a hat.")), "„an umbrella” could replace „my umbrella”")
        XCTAssertNil(ScrambleDecoys.articleDecoy(keys: keys("We have a cat and a dog.")), "two articles — a swap could move")
        XCTAssertNil(ScrambleDecoys.articleDecoy(keys: keys("They live near the old park.")), "never an extra article")
    }

    // MARK: Boards

    /// Sentences with known decoys (the decoy and the word it replaces).
    private let cases: [(sentence: String, focus: String, expected: String)] = [
        ("She went to the station by bus yesterday.", "went", "gone"),
        ("Our plans depend on the weather this weekend.", "depend on", "from"),
        ("We usually stay at home at night.", "stay", "on"),
        ("I have written three emails to my boss today.", "written", "wrote"),
        ("They want to buy a bigger house next year.", "buy", "bought")
    ]

    func testBoardsContainTheSafeDecoysAndNeverASecondCorrectSentence() throws {
        for (offset, entry) in cases.enumerated() {
            let item = word("w\(offset)", entry.focus, level: "C1", examples: [entry.sentence], focus: [entry.focus])
            let board = try XCTUnwrap(SentenceScramble.board(word: item, meaning: item.meanings[0], exampleIndex: 0, seed: "s"))
            let decoys = board.tiles.filter { (tile: ScrambleTile) -> Bool in tile.isDecoy }.map { (tile: ScrambleTile) -> String in tile.text }
            XCTAssertTrue(decoys.contains(entry.expected), "\(entry.sentence): \(decoys)")
            XCTAssertTrue((1...SentenceScramble.maxDecoys).contains(decoys.count), entry.sentence)
            XCTAssertEqual(board.tiles.count, board.answer.count + decoys.count, "pool = sentence + decoys")

            let answerKeys = Set(board.answer.map { (text: String) -> String in SentenceScramble.key(text) })
            for decoy in decoys {
                XCTAssertFalse(answerKeys.contains(SentenceScramble.key(decoy)), "a decoy is never a word of the sentence")
                XCTAssertNotEqual(SentenceScramble.key(decoy), "the", "never an extra „the”")
                // Swapping any word for a decoy is never accepted (exactly the sentence's words).
                for index in board.answer.indices {
                    var attempt = board.answer
                    attempt[index] = decoy
                    XCTAssertFalse(SentenceScramble.isCorrect(attempt, board: board))
                }
            }
            XCTAssertTrue(SentenceScramble.isCorrect(board.answer, board: board), "decoys stay unused")
        }
    }

    func testBoardIsDeterministicForTheSessionSeed() throws {
        let item = word("w", "go", level: "B2", examples: [cases[0].sentence, "We go to the gym after work."], focus: ["went", "go"])
        let tasks = [VocabTask(wordId: "w", meaningId: "m-w", type: .scramble, example: 0)]
        let seed = SentenceScramble.sessionSeed(tasks: tasks, mode: "mixed")
        XCTAssertEqual(seed, SentenceScramble.sessionSeed(tasks: tasks + [VocabTask(wordId: "x", meaningId: "m-x", type: .recall, example: 0)], mode: "mixed"),
                       "a task added later (retry) keeps the seed")
        XCTAssertNotEqual(seed, SentenceScramble.sessionSeed(tasks: [VocabTask(wordId: "y", meaningId: "m-y", type: .cloze, example: 1)], mode: "mixed"))
        let first = SentenceScramble.board(word: item, meaning: item.meanings[0], exampleIndex: 0, seed: seed + "|task")
        let resumed = SentenceScramble.board(word: item, meaning: item.meanings[0], exampleIndex: 0, seed: seed + "|task")
        XCTAssertEqual(first, resumed, "resume shows the same tiles and decoys")
        var layouts = Set<[String]>()
        for index in 0..<12 {
            let board = SentenceScramble.board(word: item, meaning: item.meanings[0], exampleIndex: 0, seed: "session-\(index)|task")
            layouts.insert(board?.tiles.map { (tile: ScrambleTile) -> String in tile.text } ?? [])
        }
        XCTAssertGreaterThan(layouts.count, 1, "another session shuffles anew")
    }

    func testPoolGivesADecoyWhenTheSentenceHasNone() throws {
        var state = TestData.emptyState()
        let lonely = word("l", "borrow", level: "A2", examples: ["Can I borrow your pen for a minute, please?"])
        state.words = [lonely] + (0..<8).map { (index: Int) -> Word in
            word("o\(index)", "other", examples: ["Our neighbors planted colorful flowers number\(index) yesterday."])
        }
        let pool = SentenceScramble.poolSentences(state: state, excludingWordID: "l", seed: "k")
        XCTAssertFalse(pool.isEmpty)
        XCTAssertEqual(pool, SentenceScramble.poolSentences(state: state, excludingWordID: "l", seed: "k"), "deterministic")
        XCTAssertFalse(pool.contains("Can I borrow your pen for a minute, please?"), "never the word's own sentence")

        let board = try XCTUnwrap(SentenceScramble.board(word: lonely, meaning: lonely.meanings[0], exampleIndex: 0, seed: "k", pool: pool))
        XCTAssertEqual(board.decoyCount, 1, "A2 → one decoy, from another word's sentence")
        let decoy = try XCTUnwrap(board.tiles.first { (tile: ScrambleTile) -> Bool in tile.isDecoy })
        XCTAssertTrue(["neighbors", "planted", "colorful", "flowers", "yesterday"].contains(decoy.text), decoy.text)
    }

    func testDecoyKindsArePreferredInOrder() {
        var generator = SeededGenerator(seed: "k")
        let answer = SentenceScramble.tokens("She went to the station by bus yesterday")
        let decoys = ScrambleDecoys.choose(
            answer: answer,
            focusKeys: ["went"],
            entrySentences: ["They often travel together on weekends."],
            pool: [],
            count: 2,
            using: &generator
        )
        XCTAssertEqual(decoys.count, 2)
        XCTAssertEqual(decoys.first, ScrambleDecoy(text: "gone", kind: .verbForm), "the focus form first")
        XCTAssertEqual(decoys.last?.kind, .sameEntry, "then another kind")
    }
}
