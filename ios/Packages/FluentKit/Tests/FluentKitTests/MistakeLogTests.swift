import XCTest
@testable import FluentKit

/// FEEDBACK-10 P1–P3: mistake classifier, mistake log (merge, limit, old data), adaptive decoys,
/// mistake practice, pronunciation scoring and the meaning-options index.
final class MistakeLogTests: XCTestCase {
    // MARK: Helpers

    private func entry(_ id: String, at: Timestamp, kind: MistakeKind, expected: String = "on", given: String = "in", word: String = "w", meaning: String = "m-w", exercise: ExerciseType = .scramble, example: Int = 0) -> MistakeEntry {
        MistakeEntry(
            id: id,
            at: at,
            exercise: exercise,
            kind: kind,
            expected: expected,
            given: given,
            expectedPart: expected,
            givenPart: given,
            wordId: word,
            meaningId: meaning,
            example: example
        )
    }

    private func sentenceWord(_ id: String, _ en: String, _ sentence: String) -> Word {
        var item = TestData.freshWord(id, en, "tłumaczenie", example: sentence)
        item.meanings[0].exampleTranslations = ["Polskie zdanie."]
        return item
    }

    // MARK: Classifier — real cases

    func testVerbForms() {
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "gone", given: "went"), .verbForm)
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "went", given: "gone"), .verbForm)
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "made", given: "make"), .verbForm, "not a typo, although one letter apart")
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "is", given: "are"), .verbForm)
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "worked", given: "working"), .verbForm)
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "interested", given: "interesting"), .verbForm)
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "goes", given: "go"), .verbForm, "third person of an irregular verb")
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "works", given: "work", focusIsVerb: true), .verbForm)
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "cars", given: "car"), .typo, "a plain -s is not a verb form without the hint")

        let sentence = MistakeClassifier.classify(
            expectedTokens: SentenceScramble.tokens("She has gone home."),
            givenTokens: ["she", "has", "went", "home"]
        )
        XCTAssertEqual(sentence, MistakeAnalysis(kind: .verbForm, expectedPart: "gone", givenPart: "went"))
    }

    func testPrepositionsAndArticles() {
        XCTAssertEqual(MistakeClassifier.classify(expected: "at night", given: "on night")?.kind, .preposition)
        XCTAssertEqual(MistakeClassifier.classify(expected: "depend on", given: "depend from"), MistakeAnalysis(kind: .preposition, expectedPart: "on", givenPart: "from"))
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "in", given: "at"), .preposition)
        XCTAssertEqual(MistakeClassifier.classify(expected: "an apple", given: "a apple"), MistakeAnalysis(kind: .article, expectedPart: "an", givenPart: "a"))
        XCTAssertEqual(MistakeClassifier.classifyWord(expected: "the", given: "a"), .article)
        XCTAssertEqual(MistakeClassifier.classify(expected: "go to work", given: "go to the work")?.kind, .article, "an added article")
    }

    func testTyposOtherWordsAndOrder() {
        XCTAssertEqual(MistakeClassifier.classify(expected: "receive", given: "recieve")?.kind, .typo, "swapped letters = one edit")
        XCTAssertEqual(MistakeClassifier.classify(expected: "lend", given: "lnd")?.kind, .typo)
        XCTAssertEqual(MistakeClassifier.classify(expected: "accommodation", given: "acomodation")?.kind, .typo)
        XCTAssertEqual(MistakeClassifier.classify(expected: "lend", given: "borrow")?.kind, .otherWord)
        XCTAssertEqual(MistakeClassifier.classify(expected: "look forward to", given: "lookforward to")?.kind, .typo, "the whole answer is one slip away")
        let order = MistakeClassifier.classify(expectedTokens: ["I", "like", "green", "tea"], givenTokens: ["i", "green", "like", "tea"])
        XCTAssertEqual(order?.kind, .wordOrder)
        XCTAssertNil(MistakeClassifier.classify(expected: "Gone.", given: "gone"), "case and punctuation are not mistakes")
        XCTAssertNil(MistakeClassifier.classify(expected: "I'm late", given: "I am late"), "contractions")
        XCTAssertFalse(MistakeClassifier.isTypo(expected: "on", given: "in"), "two-letter words have no typo allowance (FuzzyMatcher)")
    }

    func testPolishAnswers() {
        XCTAssertNil(MistakeClassifier.classifyPolish(expected: "pożyczyć", given: "pozyczyc"), "diacritics are not mistakes")
        XCTAssertEqual(MistakeClassifier.classifyPolish(expected: "pożyczyć", given: "pożyczć")?.kind, .typo)
        XCTAssertEqual(MistakeClassifier.classifyPolish(expected: "pożyczyć", given: "zwrócić")?.kind, .meaning)
    }

    func testFeedbackAndClosest() {
        let hint = MistakeClassifier.feedbackPl(MistakeAnalysis(kind: .verbForm, expectedPart: "gone", givenPart: "went"))
        XCTAssertTrue(hint?.contains("„gone”") == true)
        XCTAssertNil(MistakeClassifier.feedbackPl(MistakeAnalysis(kind: .typo)))
        XCTAssertEqual(MistakeClassifier.closest(to: "lendd", among: ["borrow", "lend", "to lend"]), "lend")
    }

    // MARK: „Przypomnij sobie” — typo message with FuzzyMatcher thresholds

    func testRecallTypoUsesFuzzyThresholds() {
        let receive = TestData.freshWord("r", "receive", "otrzymać")
        let swapped = VocabularyGrader.localGrade(answer: "recieve", word: receive, meaning: receive.meanings[0], type: .recall)
        XCTAssertEqual(swapped.closestAnswer, "receive")
        XCTAssertTrue(swapped.explanation.contains("literówka"))
        let cat = TestData.freshWord("c", "cat", "kot")
        XCTAssertEqual(VocabularyGrader.localGrade(answer: "cst", word: cat, meaning: cat.meanings[0], type: .recall).closestAnswer, "cat", "3 letters → 1 edit, like search")
        let far = VocabularyGrader.localGrade(answer: "rcvee", word: receive, meaning: receive.meanings[0], type: .recall)
        XCTAssertNil(far.closestAnswer)
    }

    func testRecallVerbFormIsNotATypo() {
        let make = TestData.freshWord("mk", "make", "zrobić")
        let grade = VocabularyGrader.localGrade(answer: "made", word: make, meaning: make.meanings[0], type: .recall)
        XCTAssertEqual(grade.verdict, .incorrect)
        XCTAssertNil(grade.closestAnswer, "made ↔ make is another form, not a slip")
        XCTAssertTrue(grade.explanation.contains("forma"), grade.explanation)
    }

    // MARK: Log — order, limit, merge

    func testNormalizedDeduplicatesSortsAndLimits() {
        var entries: [MistakeEntry] = []
        for index in 0..<(MistakeLog.limit + 20) {
            entries.append(entry("e\(index)", at: Double(1_000 + index), kind: .typo))
        }
        entries.shuffle()
        entries.append(entry("e5", at: 1_005, kind: .typo))
        let normalized = MistakeLog.normalized(entries)
        XCTAssertEqual(normalized.count, MistakeLog.limit)
        XCTAssertEqual(normalized.first?.id, "e20", "the oldest are dropped")
        XCTAssertEqual(normalized.last?.id, "e\(MistakeLog.limit + 19)")
        XCTAssertEqual(Set(normalized.map { $0.id }).count, normalized.count, "no duplicates")
        XCTAssertEqual(MistakeLog.normalized(normalized), normalized, "idempotent")
    }

    func testMergeIsDeterministicAndWithoutDuplicates() {
        let shared = entry("s", at: 50, kind: .article)
        let local = [entry("a", at: 10, kind: .typo), shared, entry("c", at: 70, kind: .verbForm)]
        let remote = [entry("b", at: 30, kind: .meaning), shared, entry("d", at: 70, kind: .preposition)]
        let one = MistakeLog.merge(local: local, remote: remote)
        let other = MistakeLog.merge(local: remote, remote: local)
        XCTAssertEqual(one, other, "same entries, same order in both directions")
        XCTAssertEqual(one.map { $0.id }, ["a", "b", "s", "c", "d"], "time, then id")

        var a = TestData.emptyState()
        a.mistakes = local
        var b = TestData.emptyState()
        b.mistakes = remote
        XCTAssertEqual(StateSync.mergeStates(local: a, remote: b).mistakes, one)
        XCTAssertEqual(StateSync.mergeStates(local: b, remote: a).mistakes, one)
    }

    func testMergeKeepsTheNewestFiveHundred() {
        let local = (0..<400).map { (index: Int) -> MistakeEntry in entry("l\(index)", at: Double(index * 2), kind: .typo) }
        let remote = (0..<400).map { (index: Int) -> MistakeEntry in entry("r\(index)", at: Double(index * 2 + 1), kind: .typo) }
        let merged = MistakeLog.merge(local: local, remote: remote)
        XCTAssertEqual(merged.count, MistakeLog.limit)
        XCTAssertEqual(merged.first?.at, 300)
        XCTAssertEqual(MistakeLog.merge(local: merged, remote: remote), merged, "merging again changes nothing")
    }

    func testRecordingAppendsAndMigrationCaps() {
        var state = TestData.emptyState()
        state = MistakeLog.recording([entry("x", at: 5, kind: .typo)], in: state)
        state = MistakeLog.recording([entry("y", at: 3, kind: .typo)], in: state)
        XCTAssertEqual(state.mistakes.map { $0.id }, ["y", "x"])
        XCTAssertEqual(MistakeLog.recording([], in: state), state)
        state.mistakes = (0..<600).map { (index: Int) -> MistakeEntry in entry("m\(index)", at: Double(index), kind: .typo) }
        XCTAssertEqual(StateMigration.migrate(state).mistakes.count, MistakeLog.limit)
    }

    func testEntryClipsLongTexts() {
        let long = String(repeating: "a", count: 1_000)
        let made = MistakeLog.entry(id: "e", at: 1, exercise: .recall, analysis: MistakeAnalysis(kind: .otherWord), expected: long, given: long, wordId: "w", meaningId: "m", example: -3, context: long)
        XCTAssertEqual(made.given.count, MistakeLog.maxTextLength)
        XCTAssertEqual(made.example, 0)
    }

    // MARK: Coding — old data and round trip

    func testOldStateDecodesWithoutMistakes() throws {
        let old = try JSONDecoder().decode(LearnerState.self, from: Data(#"{"words": [], "session": {"tasks": [], "index": 0, "correct": 0, "minutes": 5, "mode": "mixed"}}"#.utf8))
        XCTAssertEqual(old.mistakes, [])
        XCTAssertNil(old.session?.decoyFocus)
    }

    func testMistakesRoundTripAndTolerantDecoding() throws {
        var state = TestData.emptyState()
        state.mistakes = [entry("a", at: 1, kind: .preposition), entry("b", at: 2, kind: .wordOrder, exercise: .recall)]
        state.session = VocabSession(tasks: [], minutes: 5, mode: "mixed", decoyFocus: .preposition)
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(LearnerState.self, from: data)
        XCTAssertEqual(decoded.mistakes, state.mistakes)
        XCTAssertEqual(decoded.session?.decoyFocus, .preposition)

        let json = #"""
        {"words": [], "mistakes": [
          {"id": "ok", "at": 5, "exercise": 6, "kind": "somethingNew", "expected": "on", "given": "in", "wordId": "w", "meaningId": "m"},
          {"id": "bad", "at": 6, "exercise": 99, "kind": "typo"},
          {"at": 7, "exercise": 1, "kind": "typo"}
        ]}
        """#
        let tolerant = try JSONDecoder().decode(LearnerState.self, from: Data(json.utf8))
        XCTAssertEqual(tolerant.mistakes.count, 1, "unknown exercise and missing id are skipped")
        XCTAssertEqual(tolerant.mistakes.first?.kind, .otherWord, "unknown kind → other word")
        XCTAssertEqual(tolerant.mistakes.first?.expectedPart, "")

        let session = try JSONDecoder().decode(VocabSession.self, from: Data(#"{"tasks": [], "decoyFocus": "unknown"}"#.utf8))
        XCTAssertNil(session.decoyFocus)
        let sessionJSON = String(decoding: try JSONEncoder().encode(VocabSession(tasks: [], minutes: 5, mode: "mixed")), as: UTF8.self)
        XCTAssertFalse(sessionJSON.contains("decoyFocus"), "nil is not written (web-compatible JSON)")
    }

    // MARK: Patterns

    func testPatternsGroupAndDescribe() {
        let entries = [
            entry("1", at: 1, kind: .preposition, expected: "at", given: "on"),
            entry("2", at: 2, kind: .preposition, expected: "on", given: "in"),
            entry("3", at: 3, kind: .preposition, expected: "at", given: "on"),
            entry("4", at: 4, kind: .typo, expected: "receive", given: "recieve"),
            entry("5", at: 5, kind: .wordOrder, expected: "", given: "")
        ]
        let patterns = MistakeLog.patterns(entries)
        XCTAssertEqual(patterns.map { $0.kind }, [.preposition, .wordOrder, .typo], "most frequent, then newest")
        let prepositions = patterns[0]
        XCTAssertEqual(prepositions.count, 3)
        XCTAssertEqual(prepositions.pairs.first, MistakePair(expected: "at", given: "on", count: 2))
        XCTAssertEqual(prepositions.summaryPl, "Mylisz at / on / in — 3 razy")
        XCTAssertEqual(prepositions.examples.first?.id, "3", "newest first")
        XCTAssertEqual(patterns[1].countPl, "1 raz")
        XCTAssertFalse(MistakeKind.allCases.contains { $0.explanationPl.isEmpty || $0.namePl.isEmpty })
    }

    // MARK: Adaptive decoys

    func testDecoyFocusNeedsRepeatedMistakes() {
        XCTAssertNil(MistakeLog.decoyFocus([entry("1", at: 1, kind: .preposition)]), "one mistake is not a pattern")
        XCTAssertNil(MistakeLog.decoyFocus([entry("1", at: 1, kind: .typo), entry("2", at: 2, kind: .typo)]), "typos have no decoy kind")
        let entries = [
            entry("1", at: 1, kind: .verbForm), entry("2", at: 2, kind: .preposition),
            entry("3", at: 3, kind: .preposition), entry("4", at: 4, kind: .verbForm),
            entry("5", at: 5, kind: .preposition)
        ]
        XCTAssertEqual(MistakeLog.decoyFocus(entries), .preposition)
        XCTAssertEqual(MistakeLog.decoyFocus(Array(entries.prefix(4))), .verbForm, "tie → MistakeKind order")
        var state = TestData.emptyState()
        state.mistakes = entries
        XCTAssertEqual(MistakeLog.withDecoyFocus(VocabSession(tasks: [], minutes: 5, mode: "mixed"), state: state).decoyFocus, .preposition)
    }

    func testPreferredDecoyKindComesFirst() {
        let answer = SentenceScramble.tokens("She has gone to bed at night.")
        func first(_ prefer: ScrambleDecoyKind?) -> ScrambleDecoy? {
            var generator = SeededGenerator(seed: "k")
            return ScrambleDecoys.choose(answer: answer, focusKeys: [], entrySentences: [], pool: [], count: 1, prefer: prefer, using: &generator).first
        }
        XCTAssertEqual(first(nil), ScrambleDecoy(text: "went", kind: .verbForm), "default priority")
        XCTAssertEqual(first(.preposition), ScrambleDecoy(text: "on", kind: .preposition), "the confused kind first")
        XCTAssertEqual(first(.article), ScrambleDecoy(text: "went", kind: .verbForm), "no article decoy possible — default order")
    }

    func testAdaptiveBoardIsDeterministic() throws {
        let word = sentenceWord("g", "go", "She has gone to bed at night.")
        let meaning = word.meanings[0]
        let plain = try XCTUnwrap(SentenceScramble.board(word: word, meaning: meaning, exampleIndex: 0, seed: "s"))
        let adaptive = try XCTUnwrap(SentenceScramble.board(word: word, meaning: meaning, exampleIndex: 0, seed: "s", prefer: .preposition))
        XCTAssertEqual(plain.tiles.filter { $0.isDecoy }.map { $0.text }, ["went"])
        XCTAssertEqual(adaptive.tiles.filter { $0.isDecoy }.map { $0.text }, ["on"])
        XCTAssertEqual(adaptive, SentenceScramble.board(word: word, meaning: meaning, exampleIndex: 0, seed: "s", prefer: .preposition), "resumed task → same tiles")
        XCTAssertEqual(plain, SentenceScramble.board(word: word, meaning: meaning, exampleIndex: 0, seed: "s", pool: [], prefer: nil), "no preference → unchanged board")
    }

    // MARK: Practice

    func testMistakePracticeSession() {
        var state = TestData.emptyState()
        let go = sentenceWord("g", "go", "She has gone to bed at night.")
        let receive = TestData.freshWord("r", "receive", "otrzymać")
        var archived = TestData.freshWord("x", "lend", "pożyczyć")
        archived.archived = true
        state.words = [go, receive, archived]
        state.mistakes = [
            entry("1", at: 1, kind: .preposition, word: "g", meaning: "m-g"),
            entry("2", at: 2, kind: .typo, expected: "receive", given: "recieve", word: "r", meaning: "m-r", exercise: .recall),
            entry("3", at: 3, kind: .preposition, word: "g", meaning: "m-g"),
            entry("4", at: 4, kind: .meaning, word: "x", meaning: "m-x", exercise: .meaning),
            entry("5", at: 5, kind: .verbForm, word: "gone-word", meaning: "missing")
        ]
        let all = MistakePractice.session(state: state, kind: nil, minutes: 5)
        XCTAssertEqual(all.mode, StudyMode.mistakes.rawValue)
        XCTAssertEqual(all.tasks.map { $0.meaningId }, ["m-g", "m-r"], "newest first, one task per meaning, no archived or missing words")
        XCTAssertEqual(all.tasks.first?.type, .scramble, "a preposition is practised in the same sentence")
        XCTAssertEqual(all.tasks.last?.type, .recall, "a typo is typed again")

        let prepositions = MistakePractice.session(state: state, kind: .preposition, minutes: 5)
        XCTAssertEqual(prepositions.tasks.map { $0.meaningId }, ["m-g"])
        XCTAssertEqual(prepositions.decoyFocus, .preposition, "decoys of the practised kind first")
        XCTAssertTrue(MistakePractice.session(state: state, kind: .wordOrder, minutes: 5).tasks.isEmpty)
    }

    func testPracticeLaunchModes() {
        XCTAssertEqual(MistakePractice.launchMode(for: nil), "mistake-patterns")
        XCTAssertEqual(MistakePractice.request(fromLaunchMode: "mistake-patterns:preposition"), MistakePracticeRequest(kind: .preposition))
        XCTAssertEqual(MistakePractice.request(fromLaunchMode: "mistake-patterns"), MistakePracticeRequest(kind: nil))
        XCTAssertEqual(MistakePractice.request(fromLaunchMode: MistakePractice.launchMode(for: .typo))?.kind, .typo)
        XCTAssertNil(MistakePractice.request(fromLaunchMode: "mistakes"))
    }

    // MARK: Pronunciation (P2)

    func testPronunciationWordByWord() {
        let all = PronunciationScoring.score(expected: "I'm going to the station.", heard: "I am going to the station")
        XCTAssertEqual(all.heardCount, 5)
        XCTAssertEqual(all.total, 5)
        XCTAssertTrue(all.verdictPl.hasPrefix("Świetnie"))

        let missed = PronunciationScoring.score(expected: "She bought seven apples at the market.", heard: "she bought 7 apples the market")
        XCTAssertEqual(missed.missedWords, ["at"], "numbers as digits count; a skipped word does not shift the rest")
        XCTAssertEqual(missed.words.map { $0.text }.first, "She")

        let check = PronunciationScoring.score(expected: "Where is the check-in desk?", heard: "where is the check in desk")
        XCTAssertEqual(check.missedWords, [])

        let silent = PronunciationScoring.score(expected: "Good morning.", heard: "")
        XCTAssertEqual(silent.heardCount, 0)
        XCTAssertTrue(silent.verdictPl.hasPrefix("Nic nie usłyszałem"))
    }

    // MARK: Meaning options index (P3)

    func testIndexedOptionsMatchTheDirectOnes() {
        let state = TestData.seed()
        let index = MeaningOptionsIndex(state: state)
        XCTAssertEqual(index.count, state.words.reduce(0) { $0 + $1.meanings.count })
        for word in state.words.prefix(8) {
            let meaning = word.meanings[0]
            let task = VocabTask(wordId: word.id, meaningId: meaning.id, type: .meaning, example: 1)
            XCTAssertEqual(
                MeaningOptions.options(index: index, word: word, meaning: meaning, task: task, sessionIndex: state.session?.index ?? -1),
                MeaningOptions.options(state: state, word: word, meaning: meaning, task: task),
                word.en
            )
        }
    }
}
