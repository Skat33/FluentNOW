import XCTest
@testable import FluentKit

/// FEEDBACK-2 G2 (word + four photos) and G3 (flashcards as a separate mode).
final class PracticeModesTests: XCTestCase {
    // MARK: Helpers

    private func noun(_ id: String, _ en: String, _ translation: String, collection: String = "Jedzenie", topic: String? = nil) -> Word {
        var word = TestData.freshWord(id, en, translation)
        word.pos = "rzeczownik"
        word.collection = collection
        word.meanings[0].topic = topic
        return word
    }

    private func practiced(_ word: Word, correct: Int, due: Timestamp, wrong: Int = 0) -> Word {
        var copy = word
        copy.meanings[0].scores[.recognition] = Score(value: 20, interval: 2, due: due, correct: correct, wrong: wrong, last: testNow - day)
        return copy
    }

    private func fruitState() -> LearnerState {
        var state = TestData.emptyState()
        state.words = [
            noun("apple", "apple", "jabłko", topic: "Owoce"),
            noun("pear", "pear", "gruszka", topic: "Owoce"),
            noun("banana", "banana", "banan", topic: "Owoce"),
            noun("chair", "chair", "krzesło", collection: "Dom"),
            noun("car", "car", "samochód", collection: "Miasto"),
            noun("idea", "idea", "pomysł", collection: "Myśli")
        ]
        return state
    }

    // MARK: G3 — flashcards leave sessions

    func testSessionsNeverDrawFlashcards() {
        var state = TestData.emptyState()
        state.words = (0..<30).map { TestData.freshWord("w\($0)", "term\($0)", "sens \($0)") }
        // Mix of progression stages, including fully practiced meanings (every type allowed).
        for index in 0..<30 {
            var meaning = state.words[index].meanings[0]
            if index % 3 != 0 {
                meaning.scores[.recognition] = Score(interval: 3, due: testNow - Double(index) * 1_000, correct: 3, last: testNow - day)
            }
            if index % 3 == 2 {
                meaning.scores[.recall] = Score(interval: 3, due: testNow - 5_000, correct: 2, last: testNow - day)
                meaning.scores[.usage] = Score(interval: 3, due: testNow - 4_000, correct: 2, last: testNow - day)
                meaning.scores[.listening] = Score(interval: 3, due: testNow - 3_000, correct: 2, last: testNow - day)
                meaning.scores[.spelling] = Score(interval: 3, due: testNow - 2_000, correct: 2, last: testNow - day)
            }
            state.words[index].meanings[0] = meaning
        }
        for seed in 0..<15 {
            var generator = SeededGenerator(seed: UInt64(seed))
            let session = SessionBuilder.makeSession(state: state, minutes: 15, using: &generator)
            XCTAssertFalse(session.tasks.isEmpty)
            XCTAssertFalse(session.tasks.contains { $0.type == .flashcard }, "seed \(seed)")
            XCTAssertFalse(session.tasks.contains { $0.type == .picture }, "no photos cached → no picture tasks")
        }
    }

    func testNewWordsStillFillTheBudgetWithTheMeaningExercise() {
        var state = TestData.emptyState()
        state.words = (0..<40).map { TestData.freshWord("w\($0)", "term\($0)", "sens \($0)") }
        var generator = SeededGenerator(seed: 2)
        for minutes in SessionBuilder.durations {
            let session = SessionBuilder.makeSession(state: state, minutes: minutes, using: &generator)
            XCTAssertEqual(session.tasks.count, min(40, minutes * 60 / ExerciseType.meaning.estimatedSeconds))
            XCTAssertTrue(session.tasks.allSatisfy { $0.type == .meaning })
        }
    }

    func testFailedFirstContactReturnsAsMeaningNotDictation() {
        var state = TestData.emptyState()
        state.words = [TestData.freshWord("w0", "borrow", "pożyczyć")]
        let task = VocabTask(wordId: "w0", meaningId: "m-w0", type: .meaning, example: 0)
        state.session = VocabSession(tasks: [task], minutes: 5, mode: "mixed")
        let next = Scheduler.recordAnswer(state, task: task, correct: false, seconds: 5, confidence: 2, hint: false, now: testNow, reviewID: "r")
        XCTAssertEqual(next.session?.tasks.count, 2)
        XCTAssertEqual(next.session?.tasks.last?.type, .meaning)
    }

    func testRetryTypeNeverFallsBackToFlashcards() {
        var meaning = Meaning(id: "m", translation: "t")
        for skill in Skill.masterySkills {
            meaning.scores[skill] = Score(correct: 3)
        }
        for type in ExerciseType.allCases {
            XCTAssertNotEqual(SessionBuilder.retryType(after: type, meaning: meaning), .flashcard, "\(type)")
            XCTAssertNotEqual(type.retryType, .flashcard, "\(type)")
        }
        XCTAssertEqual(SessionBuilder.retryType(after: .dictation, meaning: meaning), .meaning)
        XCTAssertEqual(SessionBuilder.retryType(after: .picture, meaning: meaning), .meaning)
    }

    func testCombinedSessionIgnoresTheFlashcardMode() {
        let state = TestData.seed()
        var generator = SeededGenerator(seed: 1)
        let session = CombinedSessionBuilder.makeSession(state: state, modes: [.flashcards, .mixed], minutes: 5, random: false, content: TestData.syntheticContent(), now: testNow, id: "c", using: &generator)
        XCTAssertEqual(session.modes, [.mixed])
        XCTAssertFalse(session.tasks.isEmpty)
        XCTAssertTrue(session.tasks.allSatisfy { $0.mode == .mixed })
        var onlyDeck = SeededGenerator(seed: 1)
        XCTAssertTrue(CombinedSessionBuilder.makeSession(state: state, modes: [.flashcards], minutes: 5, random: false, content: .empty, now: testNow, using: &onlyDeck).tasks.isEmpty)
        XCTAssertFalse(StudyMode.combinableModes.contains(.flashcards))
        XCTAssertFalse(StudyMode.combinableModes.contains(.pictures))
        XCTAssertEqual(StudyMode.combinableModes.count, StudyMode.allCases.count - 2)
    }

    // MARK: G3 — the deck

    func testDeckOrderDueThenNewThenHard() {
        var state = TestData.emptyState()
        let dueLater = practiced(TestData.freshWord("due2", "later", "później"), correct: 2, due: testNow - 1_000)
        let dueFirst = practiced(TestData.freshWord("due1", "first", "pierwszy"), correct: 2, due: testNow - 50_000)
        let hard = practiced(TestData.freshWord("hard", "tricky", "podchwytliwy"), correct: 1, due: testNow + day, wrong: 3)
        let fine = practiced(TestData.freshWord("fine", "easy", "łatwy"), correct: 4, due: testNow + day)
        let fresh = TestData.freshWord("new", "brand", "marka")
        var archived = TestData.freshWord("old", "gone", "zniknął")
        archived.archived = true
        state.words = [dueLater, fresh, hard, fine, dueFirst, archived]
        let deck = FlashcardDeckBuilder.makeDeck(state: state, now: testNow)
        XCTAssertEqual(deck.map { $0.wordId }, ["due1", "due2", "new", "hard"])
        XCTAssertEqual(deck.map { $0.group }, [.due, .due, .new, .hard])
        XCTAssertTrue(deck.allSatisfy { $0.task.type == .flashcard })
        let counts = FlashcardDeckBuilder.counts(state: state, now: testNow)
        XCTAssertEqual(counts, FlashcardDeckCounts(due: 2, new: 1, hard: 1))
        XCTAssertEqual(counts.total, 4)
    }

    func testDeckLimitsNewCardsAndCollection() {
        var state = TestData.emptyState()
        state.words = (0..<25).map { index in
            var word = TestData.freshWord("w\(index)", "term\(index)", "sens \(index)")
            word.collection = index < 20 ? "A" : "B"
            return word
        }
        XCTAssertEqual(FlashcardDeckBuilder.makeDeck(state: state, now: testNow).count, FlashcardDeckBuilder.defaultNewLimit)
        XCTAssertEqual(FlashcardDeckBuilder.makeDeck(state: state, limit: 5, now: testNow).count, 5)
        let onlyB = FlashcardDeckBuilder.makeDeck(state: state, collection: "B", now: testNow)
        XCTAssertEqual(Set(onlyB.map { $0.wordId }), ["w20", "w21", "w22", "w23", "w24"])
        XCTAssertTrue(FlashcardDeckBuilder.makeDeck(state: state, limit: 0, now: testNow).isEmpty)
        XCTAssertTrue(FlashcardDeckBuilder.makeDeck(state: TestData.emptyState(), now: testNow).isEmpty)
    }

    func testDeckRecordScoresRecognitionAndKeepsPausedSession() {
        var state = TestData.seed()
        let paused = VocabSession(tasks: [VocabTask(wordId: "w0", meaningId: "m0", type: .recall, example: 0)], minutes: 5, mode: "mixed")
        state.session = paused
        guard let word = state.words.first, let meaning = word.meanings.first else { return XCTFail("seed") }
        let card = FlashcardCard(wordId: word.id, meaningId: meaning.id, example: 0, group: .due)
        let before = state.reviews.count
        let next = FlashcardDeckBuilder.record(state, card: card, remembered: true, seconds: 3, now: testNow, reviewID: "deck-1")
        XCTAssertEqual(next.session, paused, "the deck never touches the vocabulary session")
        XCTAssertEqual(next.reviews.count, before + 1)
        XCTAssertEqual(next.reviews.last?.skill, .recognition)
        XCTAssertEqual(next.reviews.last?.correct, true)
        XCTAssertEqual(next.word(id: word.id)?.meaning(id: meaning.id)?.scores[.recognition]?.last, testNow)
        let missing = FlashcardCard(wordId: "nope", meaningId: "nope", example: 0, group: .new)
        XCTAssertEqual(FlashcardDeckBuilder.record(state, card: missing, remembered: false, seconds: 2, now: testNow), state)
    }

    func testRunRequeuesForgottenCardsOnce() {
        let cards = [
            FlashcardCard(wordId: "a", meaningId: "ma", example: 0, group: .due),
            FlashcardCard(wordId: "b", meaningId: "mb", example: 0, group: .new)
        ]
        var run = FlashcardRun(cards: cards)
        XCTAssertEqual(run.remaining, 2)
        run.answer(remembered: false)
        XCTAssertEqual(run.cards.count, 3, "forgotten card returns at the end")
        XCTAssertEqual(run.cards.last?.attempt, 1)
        XCTAssertNotEqual(run.cards.last?.id, run.cards.first?.id)
        run.answer(remembered: true)
        run.answer(remembered: false)
        XCTAssertEqual(run.cards.count, 3, "a returning card does not come back again")
        XCTAssertTrue(run.isFinished)
        XCTAssertEqual(run.remembered, 1)
        XCTAssertEqual(run.forgotten, 2)
        XCTAssertEqual(run.forgottenMeaningIDs, ["ma"])
        XCTAssertEqual(run.rememberedMeaningIDs, ["mb"])
        run.answer(remembered: true)
        XCTAssertEqual(run.remembered, 1, "finished deck ignores answers")
    }

    func testRunDropsDeletedWords() {
        var state = TestData.emptyState()
        state.words = [TestData.freshWord("a", "alpha", "alfa")]
        var run = FlashcardRun(cards: [
            FlashcardCard(wordId: "a", meaningId: "m-a", example: 0, group: .new),
            FlashcardCard(wordId: "gone", meaningId: "m-gone", example: 0, group: .new)
        ])
        run.dropMissing(in: state)
        XCTAssertEqual(run.cards.map { $0.wordId }, ["a"])
    }

    // MARK: G2 — picture exercise

    func testOnlyConcreteNounsArePicturable() {
        let state = fruitState()
        func picturable(_ id: String) -> Bool {
            guard let word = state.word(id: id) else { return false }
            return PictureExercise.isPicturable(word: word, meaning: word.meanings[0])
        }
        XCTAssertTrue(picturable("apple"))
        XCTAssertTrue(picturable("chair"))
        XCTAssertFalse(picturable("idea"), "abstract noun")
        var verb = TestData.freshWord("run", "run", "biegać")
        XCTAssertFalse(PictureExercise.isPicturable(word: verb, meaning: verb.meanings[0]), "verbs never")
        verb.pos = "rzeczownik"
        verb.en = "happiness"
        XCTAssertFalse(PictureExercise.isPicturable(word: verb, meaning: verb.meanings[0]), "abstract suffix")
        var apartment = noun("flat", "apartment", "mieszkanie")
        XCTAssertTrue(PictureExercise.isPicturable(word: apartment, meaning: apartment.meanings[0]), "suffix exception")
        apartment.meanings[0].contentRef = "emotions/emotions.anger"
        XCTAssertFalse(PictureExercise.isPicturable(word: apartment, meaning: apartment.meanings[0]), "abstract topic")
        apartment.meanings[0].contentRef = "house-rooms/house-rooms.apartment"
        XCTAssertTrue(PictureExercise.isPicturable(word: apartment, meaning: apartment.meanings[0]))
        let polishAbstract = noun("x", "goodwill", "życzliwość")
        XCTAssertFalse(PictureExercise.isPicturable(word: polishAbstract, meaning: polishAbstract.meanings[0]))
    }

    func testSearchQueryCleansLabelsAndArticles() {
        XCTAssertEqual(PictureExercise.searchQuery(term: "cell phone (AmE)"), "cell phone")
        XCTAssertEqual(PictureExercise.searchQuery(term: "a suitcase"), "suitcase")
        XCTAssertEqual(PictureExercise.searchQuery(term: "the moon"), "moon")
        XCTAssertEqual(PictureExercise.searchQuery(term: "bag (for groceries)"), "bag")
        XCTAssertEqual(PictureExercise.searchQuery(term: "a"), "a")
    }

    func testDistractorsAreClearlyDifferentAndPreferTheSameTopic() {
        var state = fruitState()
        state.words.append(noun("apples", "apple tree", "jabłoń", topic: "Owoce"))
        state.words.append(noun("pear2", "pearl", "perła", collection: "Biżuteria"))
        let items = state.words.flatMap { word in word.meanings.map { WordMeaning(word: word, meaning: $0) } }
        guard let apple = items.first(where: { $0.word.id == "apple" }) else { return XCTFail("apple") }
        for seed in 0..<20 {
            var generator = SeededGenerator(seed: UInt64(seed))
            let chosen = PictureExercise.distractors(for: apple, pool: items, using: &generator)
            XCTAssertEqual(chosen.count, 3)
            XCTAssertFalse(chosen.contains { $0.word.id == "apple" || $0.word.id == "apples" }, "the term inside another term is ambiguous")
            XCTAssertEqual(Set(chosen.map { $0.meaning.id }).count, 3)
            for (index, item) in chosen.enumerated() {
                for other in chosen[(index + 1)...] {
                    XCTAssertTrue(PictureExercise.isClearlyDifferent(item, other))
                }
            }
            XCTAssertGreaterThanOrEqual(chosen.filter { $0.meaning.topic == "Owoce" }.count, 2, "two plausible fruits first")
        }
        XCTAssertFalse(PictureExercise.isClearlyDifferent(items[1], WordMeaning(word: noun("p", "pearl", "perła"), meaning: noun("p", "pearl", "perła").meanings[0])), "pear / pearl share a stem")
    }

    func testReadyMeaningsNeedThreeCachedDistractors() {
        let state = fruitState()
        XCTAssertTrue(PictureExercise.readyMeaningIDs(state: state, cached: ["m-apple", "m-pear", "m-banana"]).isEmpty)
        let ready = PictureExercise.readyMeaningIDs(state: state, cached: ["m-apple", "m-pear", "m-banana", "m-idea"])
        XCTAssertEqual(ready, [], "the abstract noun does not count — only 3 picturable photos")
        let full = PictureExercise.readyMeaningIDs(state: state, cached: ["m-apple", "m-pear", "m-banana", "m-chair", "m-car"])
        XCTAssertEqual(full, ["m-apple", "m-pear", "m-banana", "m-chair", "m-car"])
    }

    func testPictureTasksOnlyForReadyMeaningsPastFirstContact() {
        var state = fruitState()
        for index in 0..<4 {
            state.words[index] = practiced(state.words[index], correct: 1, due: testNow - 1_000)
        }
        let ready: Set<String> = ["m-apple", "m-pear", "m-banana", "m-car"]
        var sawPicture = false
        for seed in 0..<30 {
            var generator = SeededGenerator(seed: UInt64(seed))
            let session = SessionBuilder.makeSession(state: state, minutes: 10, pictureMeaningIDs: ready, using: &generator)
            for task in session.tasks where task.type == .picture {
                sawPicture = true
                XCTAssertTrue(ready.contains(task.meaningId))
                XCTAssertNotEqual(task.meaningId, "m-car", "car is new: its first contact is the meaning exercise")
            }
            XCTAssertFalse(session.tasks.contains { $0.type == .flashcard })
        }
        // FEEDBACK-4 I2: while „W budowie” no picture task is ever drawn.
        XCTAssertEqual(sawPicture, PictureExercise.isEnabled)
    }

    func testPrefetchOrderPracticedFirstThenNew() {
        var state = fruitState()
        state.words[2] = practiced(state.words[2], correct: 2, due: testNow - 9_000)
        state.words[1] = practiced(state.words[1], correct: 2, due: testNow - 1_000)
        let candidates = PictureExercise.prefetchCandidates(state: state, excluding: ["m-chair"], limit: 10)
        XCTAssertEqual(candidates.map { $0.meaningId }, ["m-banana", "m-pear", "m-apple", "m-car"])
        XCTAssertEqual(PictureExercise.prefetchCandidates(state: state, limit: 2).count, 2)
    }

    func testOptionOrderIsStablePerTask() {
        let first = PictureExercise.optionOrder(target: "t", distractors: ["a", "b", "c"], seed: "task-1")
        XCTAssertEqual(first, PictureExercise.optionOrder(target: "t", distractors: ["a", "b", "c"], seed: "task-1"))
        XCTAssertEqual(Set(first), ["t", "a", "b", "c"])
        let orders = Set((0..<12).map { PictureExercise.optionOrder(target: "t", distractors: ["a", "b", "c"], seed: "task-\($0)") })
        XCTAssertGreaterThan(orders.count, 1)
    }

    func testPictureTypeBasics() {
        XCTAssertEqual(ExerciseType.picture.skill, .recognition)
        XCTAssertFalse(ExerciseType.picture.scoresSpelling)
        XCTAssertTrue(HintBuilder.vocabularyHints(word: TestData.freshWord("a", "apple", "jabłko"), meaning: TestData.freshWord("a", "apple", "jabłko").meanings[0], type: .picture, exampleIndex: 0).levels.isEmpty)
        XCTAssertFalse(ExerciseType.sessionTypes.contains(.flashcard))
    }

    // MARK: Decoding (backward / forward compatible)

    func testNewEnumCasesRoundTripAndUnknownValuesDoNotBreakImport() throws {
        let task = VocabTask(wordId: "w", meaningId: "m", type: .picture, example: 1)
        let data = try JSONEncoder().encode(task)
        XCTAssertEqual(try JSONDecoder().decode(VocabTask.self, from: data), task)

        let json = """
        {"id":"c","modes":["mixed","flashcards","from-the-future"],"random":false,"minutes":5,"tasks":[],"answers":[],"index":0,"updatedAt":1}
        """
        let combined = try JSONDecoder().decode(CombinedSession.self, from: Data(json.utf8))
        XCTAssertEqual(combined.modes, [.mixed, .flashcards], "unknown modes are dropped, not fatal")

        let session = VocabSession(tasks: [], minutes: 5, mode: "from-the-future")
        XCTAssertEqual(session.studyMode, .mixed)
        XCTAssertEqual(StudyMode(rawValue: "flashcards"), .flashcards)
    }
}
