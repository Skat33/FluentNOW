import XCTest
@testable import FluentKit

/// FEEDBACK-4 I2: „Ułóż zdanie”, „Dopasuj pary”, „Zrozum ze słuchu” and the locked picture mode.
final class NewExercisesTests: XCTestCase {
    // MARK: Helpers

    private func word(_ id: String, _ en: String, _ pl: String, level: String = "A2", examples: [String], translations: [String]) -> Word {
        var word = TestData.freshWord(id, en, pl)
        word.level = level
        word.meanings[0].examples = examples
        word.meanings[0].exampleTranslations = translations
        return word
    }

    /// Recognition answered correctly `correct` times (past the first stage when ≥ 2).
    private func known(_ word: Word, correct: Int = 3, recall: Bool = false, usage: Score? = nil) -> Word {
        var copy = word
        copy.meanings[0].scores[.recognition] = Score(value: 20, interval: 2, due: testNow - day, correct: correct, last: testNow - 2 * day)
        if recall {
            copy.meanings[0].scores[.recall] = Score(value: 20, interval: 2, due: testNow - day, correct: 2, last: testNow - 2 * day)
        }
        if let usage {
            copy.meanings[0].scores[.usage] = usage
        }
        return copy
    }

    private let borrowSentence = "Can I borrow your pen for a minute, please?"

    // MARK: Enums and decoding

    func testNewTypesBasics() {
        XCTAssertEqual(ExerciseType.scramble.rawValue, 6)
        XCTAssertEqual(ExerciseType.matchPairs.rawValue, 7)
        XCTAssertEqual(ExerciseType.listeningChoice.rawValue, 8)
        XCTAssertEqual(ExerciseType.scramble.skill, .usage)
        XCTAssertEqual(ExerciseType.matchPairs.skill, .recognition)
        XCTAssertEqual(ExerciseType.listeningChoice.skill, .listening)
        XCTAssertFalse(ExerciseType.listeningChoice.scoresSpelling, "comprehension never scores spelling")
        XCTAssertFalse(ExerciseType.scramble.promptAudioAllowed, "the audio would give the order away")
        XCTAssertFalse(ExerciseType.sessionTypes.contains(.matchPairs), "the board is built from finished tasks")
        XCTAssertFalse(ExerciseType.sessionTypes.contains(.flashcard))
        for type in [ExerciseType.scramble, .matchPairs, .listeningChoice] {
            XCTAssertNotEqual(type.retryType, .flashcard)
            XCTAssertNotEqual(type.retryType, type)
            XCTAssertEqual(type.retryType.skill, type.skill, "a retry keeps the skill")
            XCTAssertTrue(HintBuilder.vocabularyHints(word: TestData.freshWord("a", "apple", "jabłko"), meaning: TestData.freshWord("a", "apple", "jabłko").meanings[0], type: type, exampleIndex: 0).levels.isEmpty)
        }
    }

    func testTaskPartnersRoundTripAndOldJSONIsUnchanged() throws {
        let board = VocabTask(wordId: "w", meaningId: "m", type: .matchPairs, example: 0, partners: [VocabTaskRef(wordId: "w2", meaningId: "m2")])
        let data = try JSONEncoder().encode(board)
        XCTAssertEqual(try JSONDecoder().decode(VocabTask.self, from: data), board)
        XCTAssertEqual(board.allRefs.map { $0.meaningId }, ["m", "m2"])

        let plain = VocabTask(wordId: "w", meaningId: "m", type: .recall, example: 2)
        let plainJSON = String(decoding: try JSONEncoder().encode(plain), as: UTF8.self)
        XCTAssertFalse(plainJSON.contains("partners"), "old types keep the web JSON shape")

        let old = #"{"wordId":"w","meaningId":"m","type":1,"example":0}"#
        XCTAssertNil(try JSONDecoder().decode(VocabTask.self, from: Data(old.utf8)).partners)
        let damaged = #"{"wordId":"w","meaningId":"m","type":7,"example":0,"partners":"oops"}"#
        let decoded = try JSONDecoder().decode(VocabTask.self, from: Data(damaged.utf8))
        XCTAssertEqual(decoded.type, .matchPairs)
        XCTAssertNil(decoded.partners, "a damaged list only loses the partners")
    }

    // MARK: Progression

    func testNewTypesComeOnlyAfterSeveralCorrectContacts() {
        var meaning = Meaning(id: "m", translation: "t")
        XCTAssertFalse(SessionBuilder.allowedTaskTypes(meaning)?.contains(.scramble) ?? true)
        meaning.scores[.recognition] = Score(correct: 1)
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.meaning])
        meaning.scores[.recognition] = Score(correct: 2)
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.recall, .meaning])
        meaning.scores[.recall] = Score(correct: 1)
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.cloze, .scramble, .recall])
        meaning.scores[.usage] = Score(correct: 1)
        XCTAssertEqual(SessionBuilder.allowedTaskTypes(meaning), [.listeningChoice, .dictation, .meaning])
    }

    func testFreshWordsNeverGetTheNewTypes() {
        var state = TestData.emptyState()
        state.words = (0..<30).map { word("w\($0)", "term\($0)", "sens \($0)", examples: ["I use term\($0) at work every day."], translations: ["Używam tego codziennie w pracy \($0)."]) }
        for seed in 0..<10 {
            var generator = SeededGenerator(seed: UInt64(seed))
            let session = SessionBuilder.makeSession(state: state, minutes: 15, using: &generator)
            XCTAssertTrue(session.tasks.allSatisfy { $0.type == .meaning }, "seed \(seed)")
        }
    }

    func testScrambleAndListeningAreDrawnAndFallBackWhenImpossible() {
        var state = TestData.emptyState()
        var words: [Word] = []
        for index in 0..<20 {
            // Even words: a scramble-able translated sentence; odd: a two-word sentence, no translation.
            let good = index % 2 == 0
            var item = word(
                "w\(index)", "term\(index)", "sens \(index)",
                examples: [good ? "We always use term\(index) on busy days." : "Term\(index) now."],
                translations: [good ? "Zawsze używamy tego w pracowite dni \(index)." : ""]
            )
            item = known(item, recall: true)
            item.meanings[0].scores[.usage] = index < 10 ? nil : Score(correct: 1, last: testNow - day)
            words.append(item)
        }
        state.words = words
        var sawScramble = false
        var sawListening = false
        for seed in 0..<20 {
            var generator = SeededGenerator(seed: UInt64(seed))
            let session = SessionBuilder.makeSession(state: state, minutes: 15, using: &generator)
            for task in session.tasks {
                let index = Int(task.wordId.dropFirst()) ?? 0
                if task.type == .scramble {
                    sawScramble = true
                    XCTAssertEqual(index % 2, 0, "a two-word sentence is never scrambled")
                }
                if task.type == .listeningChoice {
                    sawListening = true
                    XCTAssertEqual(index % 2, 0, "no translation → dictation instead")
                }
            }
            XCTAssertLessThanOrEqual(session.tasks.reduce(0) { $0 + $1.type.estimatedSeconds }, 15 * 60)
        }
        XCTAssertTrue(sawScramble)
        XCTAssertTrue(sawListening)
    }

    func testPictureTasksAreNeverDrawnWhileLocked() throws {
        try XCTSkipIf(PictureExercise.isEnabled, "the picture mode is enabled again")
        var state = TestData.emptyState()
        state.words = (0..<12).map { (index: Int) -> Word in
            var item = known(TestData.freshWord("w\(index)", "object\(index)", "przedmiot \(index)"), recall: index % 2 == 0)
            item.pos = "rzeczownik"
            if index % 3 == 0 {
                for skill in Skill.masterySkills {
                    item.meanings[0].scores[skill] = Score(interval: 2, due: testNow - day, correct: 3, last: testNow - 2 * day)
                }
            }
            return item
        }
        let ready = Set(state.words.map { $0.meanings[0].id })
        for seed in 0..<20 {
            var generator = SeededGenerator(seed: UInt64(seed))
            let session = SessionBuilder.makeSession(state: state, minutes: 15, pictureMeaningIDs: ready, using: &generator)
            XCTAssertFalse(session.tasks.contains { $0.type == .picture }, "seed \(seed)")
        }
        var generator = SeededGenerator(seed: 1)
        XCTAssertTrue(SessionBuilder.makeSession(state: state, minutes: 10, mode: .pictures, pictureMeaningIDs: ready, using: &generator).tasks.isEmpty)
    }

    // MARK: Scramble

    func testScrambleTokensIgnoreEdgePunctuation() {
        XCTAssertEqual(SentenceScramble.tokens("Don't forget your boarding pass, please!"), ["Don't", "forget", "your", "boarding", "pass", "please"])
        XCTAssertEqual(SentenceScramble.tokens("“Check-in” closes at 6 — sorry."), ["Check-in", "closes", "at", "6", "sorry"])
        XCTAssertEqual(SentenceScramble.key("Don’t,"), "don't")
        XCTAssertEqual(SentenceScramble.key("PASS."), "pass")
    }

    func testScrambleBoardIsStableShuffledAndChecksLeniently() throws {
        let item = word("b", "borrow", "pożyczyć", examples: [borrowSentence], translations: ["Mogę pożyczyć twój długopis na minutę?"])
        let board = try XCTUnwrap(SentenceScramble.board(word: item, meaning: item.meanings[0], exampleIndex: 0, seed: "task-1"))
        XCTAssertEqual(board, SentenceScramble.board(word: item, meaning: item.meanings[0], exampleIndex: 0, seed: "task-1"), "resume shows the same tiles")
        XCTAssertEqual(board.answer, ["can", "I", "borrow", "your", "pen", "for", "a", "minute", "please"], "a function word at the start is lower-cased")
        XCTAssertEqual(board.decoyCount, 0, "no decoys before the first usage answer")
        XCTAssertEqual(board.tiles.map { $0.text }.sorted(), board.answer.sorted())
        XCTAssertNotEqual(board.tiles.map { $0.text }, board.answer, "never shown already in order")
        XCTAssertEqual(board.translation, "Mogę pożyczyć twój długopis na minutę?")
        XCTAssertTrue(SentenceScramble.isCorrect(["Can", "i", "BORROW", "your", "pen", "for", "a", "minute", "please."], board: board))
        XCTAssertFalse(SentenceScramble.isCorrect(["I", "can", "borrow", "your", "pen", "for", "a", "minute", "please"], board: board))
        XCTAssertEqual(SentenceScramble.correctPrefixCount(["can", "I", "your", "borrow"], board: board), 2)
        var orders = Set<[String]>()
        for seed in 0..<10 {
            orders.insert(SentenceScramble.board(word: item, meaning: item.meanings[0], exampleIndex: 0, seed: "task-\(seed)")?.tiles.map { $0.text } ?? [])
        }
        XCTAssertGreaterThan(orders.count, 1)
    }

    func testScrambleDecoysGrowWithLevelAndAreContentWords() throws {
        let examples = [borrowSentence, "She wanted to borrow money from her brother yesterday.", "Libraries borrow rare books from other cities."]
        var item = word("b", "borrow", "pożyczyć", level: "C1", examples: examples, translations: ["", "", ""])
        XCTAssertEqual(SentenceScramble.decoyCount(word: item, meaning: item.meanings[0]), 0)
        item.meanings[0].scores[.usage] = Score(correct: 1)
        XCTAssertEqual(SentenceScramble.decoyCount(word: item, meaning: item.meanings[0]), 2)
        item.level = "A2"
        XCTAssertEqual(SentenceScramble.decoyCount(word: item, meaning: item.meanings[0]), 0)
        item.meanings[0].scores[.usage] = Score(correct: 3)
        XCTAssertEqual(SentenceScramble.decoyCount(word: item, meaning: item.meanings[0]), 1, "practiced usage gets one decoy")
        item.level = "B2"
        let board = try XCTUnwrap(SentenceScramble.board(word: item, meaning: item.meanings[0], exampleIndex: 0, seed: "k"))
        let decoys = board.tiles.filter { $0.isDecoy }.map { $0.text }
        XCTAssertEqual(decoys.count, 1)
        let sentenceKeys = Set(board.answer.map { SentenceScramble.key($0) })
        for decoy in decoys {
            XCTAssertFalse(sentenceKeys.contains(SentenceScramble.key(decoy)))
            XCTAssertFalse(SentenceScramble.functionWords.contains(SentenceScramble.key(decoy)))
            XCTAssertGreaterThanOrEqual(decoy.count, 4)
        }
        XCTAssertEqual(board.tiles.count, board.answer.count + 1)
    }

    func testScrambleNeedsFourToFourteenWords() {
        let short = word("s", "go", "iść", examples: ["Go now."], translations: [""])
        XCTAssertFalse(SentenceScramble.canBuild(meaning: short.meanings[0], exampleIndex: 0))
        let long = word("l", "go", "iść", examples: [Array(repeating: "word", count: 15).joined(separator: " ")], translations: [""])
        XCTAssertFalse(SentenceScramble.canBuild(meaning: long.meanings[0], exampleIndex: 0))
        let fine = word("f", "borrow", "pożyczyć", examples: [borrowSentence], translations: [""])
        XCTAssertTrue(SentenceScramble.canBuild(meaning: fine.meanings[0], exampleIndex: 0))
        XCTAssertTrue(SentenceScramble.canBuild(meaning: fine.meanings[0], exampleIndex: 3), "the index wraps like the screen")
        XCTAssertNil(SentenceScramble.board(word: short, meaning: short.meanings[0], exampleIndex: 0, seed: "x"))
    }

    // MARK: Listening

    func testListeningOptionsAreStableDistinctAndContainTheTranslation() {
        var state = TestData.emptyState()
        state.words = (0..<12).map { (index: Int) -> Word in
            word("w\(index)", "term\(index)", "sens \(index)",
                 examples: ["We meet near the station number \(index).", "Second sentence \(index) here."],
                 translations: ["Spotykamy się przy stacji numer \(index).", "Drugie zdanie \(index) tutaj."])
        }
        let meaning = state.words[0].meanings[0]
        XCTAssertTrue(ListeningChoice.canBuild(meaning: meaning, exampleIndex: 0))
        XCTAssertTrue(ListeningChoice.hasDistractorPool(state))
        let options = ListeningChoice.options(state: state, meaning: meaning, exampleIndex: 0, seed: "task-1")
        XCTAssertEqual(options.count, ListeningChoice.optionCount)
        XCTAssertEqual(Set(options.map { TextNormalizer.normalize($0) }).count, options.count)
        XCTAssertTrue(options.contains("Spotykamy się przy stacji numer 0."))
        XCTAssertEqual(options, ListeningChoice.options(state: state, meaning: meaning, exampleIndex: 0, seed: "task-1"))
        let index = ListeningChoice.correctIndex(options: options, meaning: meaning, exampleIndex: 0)
        XCTAssertEqual(index.flatMap { options[safe: $0] }, "Spotykamy się przy stacji numer 0.")
    }

    func testListeningNeedsATranslationAndAPool() {
        var state = TestData.emptyState()
        let lonely = word("w", "term", "sens", examples: ["We meet near the old station."], translations: ["Spotykamy się przy starej stacji."])
        state.words = [lonely]
        XCTAssertFalse(ListeningChoice.hasDistractorPool(state), "one translation cannot make four options")
        XCTAssertEqual(ListeningChoice.options(state: state, meaning: lonely.meanings[0], exampleIndex: 0, seed: "k"), ["Spotykamy się przy starej stacji."])
        let untranslated = word("u", "term", "sens", examples: ["We meet near the old station."], translations: [])
        XCTAssertFalse(ListeningChoice.canBuild(meaning: untranslated.meanings[0], exampleIndex: 0))
        XCTAssertTrue(ListeningChoice.options(state: state, meaning: untranslated.meanings[0], exampleIndex: 0, seed: "k").isEmpty)
    }

    // MARK: Match pairs

    private func pairsState(count: Int = 20) -> LearnerState {
        var state = TestData.emptyState()
        state.words = (0..<count).map { known(TestData.freshWord("w\($0)", "term\($0)", "sens \($0)")) }
        return state
    }

    func testSessionBuildsOneBoardFromFiveMeaningTasks() throws {
        let state = pairsState()
        // `nextUnit` ≈ 1 → the second type of `[.recall, .meaning]`: every task is „Wybierz znaczenie”.
        var generator = ConstantGenerator(value: UInt64.max)
        let session = SessionBuilder.makeSession(state: state, minutes: 10, using: &generator)
        let boards = session.tasks.filter { $0.type == .matchPairs }
        XCTAssertEqual(boards.count, 1)
        let board = try XCTUnwrap(boards.first)
        XCTAssertEqual(board.partners?.count, MatchPairsExercise.pairCount - 1)
        let boardIDs = Set(board.allRefs.map { $0.meaningId })
        XCTAssertEqual(boardIDs.count, MatchPairsExercise.pairCount)
        let singles = session.tasks.filter { $0.type != .matchPairs }.map { $0.meaningId }
        XCTAssertTrue(boardIDs.isDisjoint(with: singles), "no meaning gets two recognition reviews in one session")
        XCTAssertEqual(Set(singles).count, singles.count)
        XCTAssertEqual(singles.count + boardIDs.count, 20, "the time freed by the board is refilled")
        XCTAssertLessThanOrEqual(session.tasks.reduce(0) { $0 + $1.type.estimatedSeconds }, 600)
    }

    func testNoBoardForNewWordsOrTheirFirstContacts() {
        var state = TestData.emptyState()
        state.words = (0..<20).map { known(TestData.freshWord("w\($0)", "term\($0)", "sens \($0)"), correct: 1) }
        var generator = ConstantGenerator(value: UInt64.max)
        let session = SessionBuilder.makeSession(state: state, minutes: 10, using: &generator)
        XCTAssertFalse(session.tasks.contains { $0.type == .matchPairs }, "one correct recognition is not enough")
        var pairsMode = SeededGenerator(seed: 1)
        XCTAssertFalse(SessionBuilder.makeSession(state: pairsState(), minutes: 10, mode: .pairs, using: &pairsMode).tasks.contains { $0.type == .matchPairs })
    }

    func testBoardMeaningsAreDistinct() {
        let a = WordMeaning(word: TestData.freshWord("a", "bank", "bank"), meaning: TestData.freshWord("a", "bank", "bank").meanings[0])
        let b = WordMeaning(word: TestData.freshWord("b", "Bank", "brzeg rzeki"), meaning: TestData.freshWord("b", "Bank", "brzeg rzeki").meanings[0])
        let c = WordMeaning(word: TestData.freshWord("c", "shore", "brzeg rzeki"), meaning: TestData.freshWord("c", "shore", "brzeg rzeki").meanings[0])
        let d = WordMeaning(word: TestData.freshWord("d", "river", "rzeka"), meaning: TestData.freshWord("d", "river", "rzeka").meanings[0])
        XCTAssertFalse(MatchPairsExercise.areDistinct(a, b), "same term")
        XCTAssertFalse(MatchPairsExercise.areDistinct(b, c), "same translation")
        XCTAssertTrue(MatchPairsExercise.areDistinct(c, d))
    }

    func testRecordScoresEveryMeaningAndAdvancesOnce() throws {
        var state = pairsState(count: 6)
        let refs = (1..<5).map { VocabTaskRef(wordId: "w\($0)", meaningId: "m-w\($0)") }
        let board = VocabTask(wordId: "w0", meaningId: "m-w0", type: .matchPairs, example: 0, partners: refs)
        let next = VocabTask(wordId: "w5", meaningId: "m-w5", type: .meaning, example: 0)
        state.session = VocabSession(tasks: [board, next], minutes: 5, mode: "mixed")
        let items = MatchPairsExercise.items(for: board, state: state)
        XCTAssertEqual(items.count, 5)
        let results = items.map { (item: MatchPairItem) -> MatchPairResult in
            MatchPairResult(wordId: item.wordId, meaningId: item.meaningId, mistakes: item.meaningId == "m-w1" || item.meaningId == "m-w3" ? 1 : 0)
        }
        let before = state.reviews.count
        let recorded = MatchPairsExercise.record(state, task: board, results: results, seconds: 25, confidence: 2, now: testNow, reviewID: "r")
        XCTAssertEqual(recorded.reviews.count, before + 5)
        XCTAssertEqual(Array(recorded.reviews.suffix(5)).map { $0.id }, ["r", "r-2", "r-3", "r-4", "r-5"])
        XCTAssertTrue(recorded.reviews.suffix(5).allSatisfy { $0.skill == .recognition && $0.seconds == 5 })
        XCTAssertEqual(recorded.reviews.suffix(5).filter { !$0.correct }.map { $0.meaningId }.sorted(), ["m-w1", "m-w3"])
        let session = try XCTUnwrap(recorded.session)
        XCTAssertEqual(session.index, 1, "the board moves the session on once")
        XCTAssertEqual(session.correct, 0, "a board with mistakes is not a clean answer")
        XCTAssertEqual(session.tasks.count, 4, "both missed meanings return at the end")
        XCTAssertEqual(session.tasks.suffix(2).map { $0.meaningId }, ["m-w1", "m-w3"])
        XCTAssertTrue(session.tasks.suffix(2).allSatisfy { $0.type == .meaning }, "a missed pair returns as „Wybierz znaczenie”")
        XCTAssertNil(recorded.word(id: "w0")?.meaning(id: "m-w0")?.usedExamples, "the board uses no example sentence")

        let clean = results.map { MatchPairResult(wordId: $0.wordId, meaningId: $0.meaningId, mistakes: 0) }
        let perfect = MatchPairsExercise.record(state, task: board, results: clean, seconds: 20, confidence: 3, now: testNow, reviewID: "p")
        XCTAssertEqual(perfect.session?.correct, 1)
        XCTAssertEqual(perfect.session?.tasks.count, 2)
    }

    func testCombinedSaveAnswerScoresTheWholeBoardAndKeepsThePausedSession() throws {
        var state = pairsState(count: 5)
        let paused = VocabSession(tasks: [VocabTask(wordId: "w0", meaningId: "m-w0", type: .recall, example: 0)], minutes: 5, mode: "mixed")
        state.session = paused
        let board = VocabTask(wordId: "w0", meaningId: "m-w0", type: .matchPairs, example: 0, partners: (1..<5).map { VocabTaskRef(wordId: "w\($0)", meaningId: "m-w\($0)") })
        state.combined = CombinedSession(id: "c", modes: [.mixed], random: false, minutes: 5, tasks: [.vocabulary(mode: .mixed, task: board)], updatedAt: testNow)
        let results = board.allRefs.map { MatchPairResult(wordId: $0.wordId, meaningId: $0.meaningId, mistakes: 0) }
        let before = state.reviews.count
        let saved = CombinedSessionBuilder.saveAnswer(state, answer: CombinedAnswer(value: "5/5", correct: true, seconds: 20), now: testNow, reviewID: "c-1", matchResults: results)
        XCTAssertEqual(saved.reviews.count, before + 5)
        XCTAssertEqual(saved.session, paused)
        XCTAssertNotNil(saved.combined?.currentAnswer)
    }
}
