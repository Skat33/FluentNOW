import XCTest
@testable import FluentKit

/// FEEDBACK-6 K4: the level test („Test”) — band, adaptation, building, answering, scoring, sync.
final class AssessmentTests: XCTestCase {
    // MARK: Helpers

    private func bankEntry(_ id: String, level: String, frequency: SpokenFrequency? = .common, topic: String = "travel", mine: Bool = false) -> AssessmentBankEntry {
        let term = "word\(id)"
        let entry = TopicEntry(
            id: "\(topic).\(id)",
            term: term,
            pos: "rzeczownik",
            level: level,
            frequency: frequency,
            translation: "słowo \(id)",
            examples: [
                ExamplePair(en: "We often use \(term) on long trips together.", pl: "Często używamy słowa \(id) w długich podróżach.", focusEn: term, focusPl: "słowa \(id)"),
                ExamplePair(en: "My friend asked about \(term) yesterday evening.", pl: "Mój przyjaciel pytał wczoraj wieczorem o \(id).", focusEn: term, focusPl: "\(id)")
            ]
        )
        return AssessmentBankEntry(entry: entry, reference: "\(topic)/\(topic).\(id)", topicName: "Podróże", fromLearnerTopics: mine)
    }

    private func ownedWord(_ id: String, level: String, practiced: Bool = true) -> Word {
        var word = TestData.freshWord(id, "own\(id)", "własne \(id)", example: "I really need own\(id) for my work today.")
        word.level = level
        word.meanings[0].level = level
        word.meanings[0].exampleTranslations = ["Naprawdę potrzebuję tego \(id) dziś w pracy."]
        if practiced {
            word.meanings[0].scores[.recognition] = Score(value: 20, interval: 2, due: testNow + day, correct: 2, last: testNow - 3 * day)
        }
        return word
    }

    private func grammarItem(_ id: String) -> ProductionItem {
        ProductionItem(
            bankId: "g-\(id)",
            context: "Yesterday I ________ (pójść) to the store \(id).",
            hintPl: "pójść",
            answer: "went",
            acceptedAnswers: [],
            distractors: [
                ProductionDistractor(form: "go", diagnosis: .wrongTense, explanation: ""),
                ProductionDistractor(form: "gone", diagnosis: .wrongWord, explanation: ""),
                ProductionDistractor(form: "goes", diagnosis: .wrongAgreement, explanation: "")
            ],
            rule: "past simple",
            explanation: "Przeszłość zakończona.",
            translation: "Wczoraj poszedłem do sklepu."
        )
    }

    private func readingBank(level: String) -> ReadingBank {
        let questions = (0..<4).map { (index: Int) -> ReadingQuestion in
            ReadingQuestion(question: "Question \(index)?", options: ["a\(index)", "b\(index)", "c\(index)", "d\(index)"], answer: index % 4)
        }
        return ReadingBank(readings: [Reading(id: "r-\(level)", title: "Text", level: level, paragraphs: ["Paragraph."], questions: questions)])
    }

    private func content(base: String, lower: String, stretch: String?, mine: Bool = false) -> AssessmentContent {
        var entries: [AssessmentBankEntry] = []
        for index in 0..<20 {
            entries.append(bankEntry("u\(index)", level: base, mine: mine))
            entries.append(bankEntry("l\(index)", level: lower, mine: mine))
        }
        if let stretch {
            for index in 0..<8 {
                entries.append(bankEntry("s\(index)", level: stretch))
            }
        }
        entries.append(bankEntry("rare", level: base, frequency: .rare))
        entries.append(bankEntry("far", level: "C2"))
        return AssessmentContent(
            bankEntries: entries,
            grammarPool: (0..<6).map { (index: Int) -> ProductionItem in grammarItem("\(index)") },
            readings: readingBank(level: base)
        )
    }

    private func stateAt(_ level: String) -> LearnerState {
        var state = TestData.emptyState()
        state.settings.profile = LearnerProfile(startLevel: level, levelSource: .selfAssessment)
        return state
    }

    private func makeTest(_ state: LearnerState, content: AssessmentContent, seed: UInt64 = 7) -> AssessmentSession? {
        var rng = SeededGenerator(seed: seed)
        return AssessmentBuilder.make(state: state, content: content, now: testNow, id: "test-1", using: &rng)
    }

    /// Answers every question with `correct(position)` and returns the final state.
    private func answerAll(_ start: LearnerState, correct: (Int) -> Bool) -> LearnerState {
        var state = start
        var position = 0
        while let session = state.assessment, session.completedAt == nil, let question = session.currentQuestion, position < 60 {
            let right = correct(position)
            var pairs: [MatchPairResult] = []
            if let vocabulary = question.vocabulary, vocabulary.task.type == .matchPairs {
                pairs = vocabulary.task.allRefs.map { (ref: VocabTaskRef) -> MatchPairResult in
                    MatchPairResult(wordId: ref.wordId, meaningId: ref.meaningId, mistakes: right ? 0 : 1)
                }
            }
            let response = AssessmentResponse(value: right ? "ok" : "zle", correct: right, seconds: 10, elapsedSeconds: 12, pairResults: pairs)
            state = AssessmentEngine.answer(state, response: response, now: testNow + Double(position) * 1000, reviewID: "rev-\(position)")
            position += 1
        }
        return state
    }

    // MARK: Band and adaptation

    func testBandIsBaseAndOneLevelBelowWithStretchAbove() {
        let b1 = AssessmentBand(base: "B1")
        XCTAssertEqual(b1.lower, "A2")
        XCTAssertEqual(b1.upper, "B1")
        XCTAssertEqual(b1.stretch, "B2")
        XCTAssertEqual(b1.tier(of: "A2"), .lower)
        XCTAssertEqual(b1.tier(of: "B1"), .upper)
        XCTAssertEqual(b1.tier(of: "B2"), .stretch)
        XCTAssertNil(b1.tier(of: "A1"))
        XCTAssertNil(b1.tier(of: "C1"))
        XCTAssertEqual(b1.rangeText, "A2–B1")
        let a1 = AssessmentBand(base: "A1")
        XCTAssertEqual(a1.lower, "A1")
        XCTAssertEqual(a1.tier(of: "A1"), .upper)
        XCTAssertEqual(a1.rangeText, "A1")
        XCTAssertNil(AssessmentBand(base: "C2").stretch)
        XCTAssertEqual(AssessmentBand(base: "?").base, "A2")
    }

    func testStreaksMoveTheCursorAndStretchNeedsAGoodStreak() {
        XCTAssertEqual(AssessmentAdaptation.cursor(after: []).cursor, .neutral)
        XCTAssertEqual(AssessmentAdaptation.cursor(after: [true, true]).cursor, .neutral)
        XCTAssertEqual(AssessmentAdaptation.cursor(after: [true, true, true]).cursor, .upper)
        XCTAssertEqual(AssessmentAdaptation.cursor(after: [true, true, true, false]).cursor, .upper)
        XCTAssertEqual(AssessmentAdaptation.cursor(after: [true, true, true, false, false]).cursor, .lower)
        XCTAssertEqual(AssessmentAdaptation.cursor(after: [false, false, true, true, true]).cursor, .upper)
        // Before any streak: lower, upper, lower… (warm-up first).
        XCTAssertEqual(AssessmentAdaptation.preferredTier(outcomes: [], position: 0, stretchUsed: 0, stretchCap: 3, hasStretchLevel: true), .lower)
        XCTAssertEqual(AssessmentAdaptation.preferredTier(outcomes: [true], position: 1, stretchUsed: 0, stretchCap: 3, hasStretchLevel: true), .upper)
        XCTAssertEqual(AssessmentAdaptation.preferredTier(outcomes: [true, true, true], position: 3, stretchUsed: 0, stretchCap: 3, hasStretchLevel: true), .upper)
        XCTAssertEqual(AssessmentAdaptation.preferredTier(outcomes: [true, true, true, true], position: 4, stretchUsed: 0, stretchCap: 3, hasStretchLevel: true), .stretch)
        XCTAssertEqual(AssessmentAdaptation.preferredTier(outcomes: [true, true, true, true], position: 4, stretchUsed: 3, stretchCap: 3, hasStretchLevel: true), .upper)
        XCTAssertEqual(AssessmentAdaptation.preferredTier(outcomes: [true, true, true, true], position: 4, stretchUsed: 0, stretchCap: 3, hasStretchLevel: false), .upper)
        XCTAssertEqual(AssessmentAdaptation.preferredTier(outcomes: [false, false], position: 2, stretchUsed: 0, stretchCap: 3, hasStretchLevel: true), .lower)
        XCTAssertEqual(AssessmentAdaptation.stretchCap(vocabularyCount: 23), 3)
        XCTAssertEqual(AssessmentAdaptation.stretchCap(vocabularyCount: 5), 0)
        XCTAssertFalse(AssessmentAdaptation.tierOrder(.lower).contains(.stretch))
        XCTAssertFalse(AssessmentAdaptation.tierOrder(.upper).contains(.stretch))
    }

    func testBaseLevelFromProfileThenRecentTest() {
        var state = stateAt("B1")
        XCTAssertEqual(AssessmentBuilder.baseLevel(state, now: testNow), "B1")
        state.assessmentHistory = [AssessmentHistoryEntry(id: "old", at: testNow - 10 * day, baseLevel: "B1", level: "A2", percent: 40, points: 12, total: 30, seconds: 900)]
        XCTAssertEqual(AssessmentBuilder.baseLevel(state, now: testNow), "A2")
        state.assessmentHistory[0].at = testNow - 200 * day
        XCTAssertEqual(AssessmentBuilder.baseLevel(state, now: testNow), "B1")
    }

    // MARK: Building

    func testFullTestHasEveryBlockInOrderAndWordsOnlyFromTheBand() throws {
        let state = stateAt("B1")
        let session = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        let expected: [AssessmentBlock] = AssessmentBlock.allCases.flatMap { (block: AssessmentBlock) -> [AssessmentBlock] in
            Array(repeating: block, count: block.plannedCount)
        }
        XCTAssertEqual(session.slots, expected)
        XCTAssertEqual(session.slots.count, 30)
        XCTAssertEqual(session.band.base, "B1")
        XCTAssertEqual(session.questions.count, 1)
        XCTAssertEqual(session.currentQuestion?.block, .meaning)
        XCTAssertEqual(session.reading?.questions.count, 3)
        XCTAssertEqual(session.grammar.count, 4)
        // Rare words and words far outside the band never enter the pool.
        XCTAssertFalse(session.candidates.contains { $0.contentRef?.hasSuffix(".rare") ?? false })
        XCTAssertFalse(session.candidates.contains { $0.level == "C2" })
        XCTAssertTrue(session.candidates.allSatisfy { ["A2", "B1", "B2"].contains($0.level) })
        XCTAssertLessThanOrEqual(session.candidates.filter { $0.level == "B2" }.count, AssessmentBuilder.maxBankStretch)
        // Planned time is about 18–20 minutes.
        XCTAssertGreaterThanOrEqual(session.plannedSeconds, 15 * 60)
        XCTAssertLessThanOrEqual(session.plannedSeconds, 22 * 60)
    }

    func testGrammarQuestionsHideTheConstructionAndKeepTheKey() throws {
        let session = try XCTUnwrap(makeTest(stateAt("B1"), content: content(base: "B1", lower: "A2", stretch: "B2")))
        for question in session.grammar {
            XCTAssertFalse(question.prompt.contains("past simple"))
            XCTAssertEqual(question.correctOption, "went")
            XCTAssertEqual(question.format, .choice)
            XCTAssertEqual(Set(question.options), ["went", "go", "gone", "goes"])
        }
    }

    func testOwnWordsComeFirstAndBuildIsDeterministic() throws {
        var state = stateAt("B1")
        state.words = (0..<12).map { (index: Int) -> Word in ownedWord("o\(index)", level: index % 2 == 0 ? "B1" : "A2") }
        let first = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        let again = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        XCTAssertEqual(first, again)
        XCTAssertTrue(first.candidates.prefix(12).allSatisfy { $0.owned })
        let question = try XCTUnwrap(first.currentQuestion?.vocabulary)
        XCTAssertFalse(AssessmentBuilder.isBankID(question.task.wordId))
        XCTAssertEqual(question.tier, .lower)
    }

    func testOwnedEntriesAreNotOfferedAsBaseWords() throws {
        var state = stateAt("B1")
        var mine = ownedWord("x", level: "B1")
        mine.en = "wordu0"
        state.words = [mine]
        let session = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        XCTAssertFalse(session.bankWords.contains { $0.en == "wordu0" })
    }

    func testTooLittleContentGivesNoTest() {
        let empty = AssessmentContent()
        XCTAssertNil(makeTest(stateAt("B1"), content: empty))
    }

    // MARK: Core vocabulary (FEEDBACK-7)

    /// A core shard (`core-cNN`) with `perLevel` entries per CEFR band category, 3 examples each.
    private func coreShard(_ id: String, levels: [String], perLevel: Int, frequency: SpokenFrequency = .common) -> TopicFile {
        let tag = id.replacingOccurrences(of: "core-c", with: "s")
        let categories = levels.map { (level: String) -> TopicCategory in
            let entries = (0..<perLevel).map { (index: Int) -> TopicEntry in
                let term = "gen\(tag)\(level.lowercased())x\(index)"
                return TopicEntry(
                    id: "core.\(term)",
                    term: term,
                    pos: "czasownik",
                    level: level,
                    frequency: frequency,
                    translation: "ogólne \(tag) \(level) \(index)",
                    examples: [
                        ExamplePair(en: "People \(term) more often than you think.", pl: "Ludzie robią to częściej, niż myślisz.", focusEn: term, focusPl: "robią"),
                        ExamplePair(en: "Did you \(term) yesterday after work?", pl: "Czy zrobiłeś to wczoraj po pracy?", focusEn: term, focusPl: "zrobiłeś"),
                        ExamplePair(en: "We do not \(term) on Sundays at all.", pl: "W niedziele w ogóle tego nie robimy.", focusEn: term, focusPl: "robimy")
                    ]
                )
            }
            return TopicCategory(id: "\(id).\(level.lowercased())", namePl: "Słownictwo ogólne \(level)", scenePl: "", entries: entries)
        }
        return TopicFile(id: id, namePl: CoreVocabulary.collectionName, nameEn: "Core vocabulary", group: CoreVocabulary.group, symbol: "character.book.closed", categories: categories)
    }

    func testCoreShardGivesGeneralBankWordsWithoutCategory() {
        var shard = coreShard("core-c01", levels: ["A2", "B1", "C1"], perLevel: 3)
        shard.categories[0].entries[0].frequency = .lessCommon
        let entries = AssessmentBuilder.bankEntries(topic: shard, band: AssessmentBand(base: "B1"), fromLearnerTopics: false)
        XCTAssertEqual(entries.count, 5, "A2 (frequent) and B1 only — C1 is outside the band, less_common is skipped")
        XCTAssertTrue(entries.allSatisfy { ["A2", "B1"].contains($0.entry.level) })
        XCTAssertTrue(entries.allSatisfy { $0.categoryName == nil && $0.scene == nil && !$0.fromLearnerTopics })
        XCTAssertTrue(entries.allSatisfy { $0.topicName == CoreVocabulary.collectionName })
        XCTAssertTrue(entries.allSatisfy { ContentReference($0.reference)?.isCore == true })
        guard let first = entries.first else { return XCTFail("no core entries") }
        let word = AssessmentBuilder.bankWord(first)
        XCTAssertEqual(word.collection, CoreVocabulary.collectionName)
        XCTAssertNil(word.meanings.first?.topic, "a CEFR band is not a situation")
        XCTAssertEqual(word.meanings.first?.contentRef, first.reference)
    }

    func testCoreFilesRichestInTheBandAreLoaded() {
        func record(_ shard: String, _ index: Int, level: String, frequency: String = "common") -> DictionaryIndex.Entry {
            DictionaryIndex.Entry(term: "t\(shard)\(level)\(index)", translation: "p", level: level, frequency: frequency, reference: "\(shard)/core.t\(shard)\(level)\(index)")
        }
        var entries: [DictionaryIndex.Entry] = []
        entries += (0..<40).map { record("core-c01", $0, level: "A1") }
        entries += (0..<10).map { record("core-c01", $0, level: "A2") }
        entries += (0..<30).map { record("core-c02", $0, level: "B1") }
        entries += (0..<20).map { record("core-c02", $0, level: "A2", frequency: "very_common") }
        entries += (0..<60).map { record("core-c03", $0, level: "B2") }
        entries += (0..<70).map { record("core-c04", $0, level: "B1", frequency: "less_common") }
        entries += (0..<90).map { record("travel", $0, level: "B1") }
        let available = ["core-c01", "core-c02", "core-c03", "core-c04"]
        let b1 = AssessmentBand(base: "B1")
        XCTAssertEqual(AssessmentBuilder.coreFileIDs(entries: entries, band: b1, available: available, limit: 3), ["core-c02", "core-c01"],
                       "stretch (B2) and less_common entries do not count; topic records are ignored")
        XCTAssertEqual(AssessmentBuilder.coreFileIDs(entries: entries, band: b1, available: available, limit: 1), ["core-c02"])
        XCTAssertEqual(AssessmentBuilder.coreFileIDs(entries: entries, band: AssessmentBand(base: "A1"), available: available), ["core-c01"])
        XCTAssertEqual(AssessmentBuilder.coreFileIDs(entries: entries, band: AssessmentBand(base: "C1"), available: available), ["core-c03"])
        XCTAssertEqual(AssessmentBuilder.coreFileIDs(entries: entries, band: b1, available: ["core-c01"]), ["core-c01"], "only shards that exist")
        XCTAssertEqual(AssessmentBuilder.coreFileIDs(entries: [], band: b1, available: ["core-c03", "core-c01", "notes"], limit: 1), ["core-c01"],
                       "without index records: the most frequent shards first")
        XCTAssertTrue(AssessmentBuilder.coreFileIDs(entries: entries, band: b1, available: [], limit: 3).isEmpty)
    }

    func testCoreVocabularyAloneGivesAFullTestInTheBand() throws {
        let state = stateAt("B1")
        let shard = coreShard("core-c02", levels: ["A1", "A2", "B1", "B2", "C1"], perLevel: 25)
        let bank = AssessmentBuilder.bankEntries(topic: shard, band: AssessmentBand(base: "B1"), fromLearnerTopics: false)
        let content = AssessmentContent(
            bankEntries: bank,
            grammarPool: (0..<6).map { (index: Int) -> ProductionItem in grammarItem("\(index)") },
            readings: readingBank(level: "B1")
        )
        let session = try XCTUnwrap(makeTest(state, content: content))
        let expected: [AssessmentBlock] = AssessmentBlock.allCases.flatMap { (block: AssessmentBlock) -> [AssessmentBlock] in
            Array(repeating: block, count: block.plannedCount)
        }
        XCTAssertEqual(session.slots, expected, "every task type, ~18 minutes")
        XCTAssertTrue(session.candidates.allSatisfy { ["A2", "B1", "B2"].contains($0.level) }, "no A1 or C1 — no jumps")
        XCTAssertLessThanOrEqual(session.candidates.filter { $0.level == "B2" }.count, AssessmentBuilder.maxBankStretch)
        XCTAssertTrue(session.bankWords.allSatisfy { $0.collection == CoreVocabulary.collectionName })
        XCTAssertTrue(session.bankWords.allSatisfy { ($0.meanings.first?.examples.count ?? 0) <= AssessmentBuilder.maxBankExamples })
        XCTAssertGreaterThanOrEqual(session.plannedSeconds, 15 * 60)
        XCTAssertLessThanOrEqual(session.plannedSeconds, 22 * 60)
    }

    /// The real core shards give a wide general pool on every level the test covers (A1–C1).
    func testRealCoreVocabularyFillsEveryBand() throws {
        let index = try ContentDecoder.dictionaryIndex(from: TestData.contentData("dictionary-index.json"))
        let names = (try? FileManager.default.contentsOfDirectory(atPath: TestData.contentDirectory.appendingPathComponent(CoreVocabulary.directory).path)) ?? []
        let available = CoreVocabulary.fileIDs(fromFileNames: names)
        guard !available.isEmpty else { throw XCTSkip("Brak katalogu core/") }
        var shards: [String: TopicFile] = [:]
        for base in ["A1", "A2", "B1", "B2", "C1"] {
            let band = AssessmentBand(base: base)
            let ids = AssessmentBuilder.coreFileIDs(entries: index.entries, band: band, available: available)
            XCTAssertEqual(ids.count, min(AssessmentBuilder.coreFileLimit, available.count), base)
            var bank: [AssessmentBankEntry] = []
            for id in ids {
                if shards[id] == nil {
                    shards[id] = try ContentDecoder.coreFile(from: TestData.contentData(CoreVocabulary.relativePath(file: id)))
                }
                if let shard = shards[id] {
                    bank += AssessmentBuilder.bankEntries(topic: shard, band: band, fromLearnerTopics: false)
                }
            }
            // On A1 the band is a single level (upper).
            let tiers: [AssessmentTier] = band.lower == band.base ? [.upper] : [.lower, .upper]
            for tier in tiers {
                let count = bank.filter { band.tier(of: $0.entry.level) == tier }.count
                XCTAssertGreaterThanOrEqual(count, AssessmentBuilder.maxBankPerTier, "\(base) \(tier)")
            }
            XCTAssertTrue(bank.allSatisfy { $0.entry.examples.count >= 3 }, base)
        }
    }

    // MARK: Answering

    func testAnsweringRecordsOwnWordsOnlyAndNeverTouchesTheVocabularySession() throws {
        var state = stateAt("B1")
        state.words = (0..<10).map { (index: Int) -> Word in ownedWord("o\(index)", level: "B1") }
        let paused = VocabSession(tasks: [VocabTask(wordId: "o0", meaningId: "m-o0", type: .recall, example: 0)], minutes: 5, mode: "mixed")
        state.session = paused
        state.assessment = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        let wordsBefore = state.words.count
        let final = answerAll(state) { (position: Int) -> Bool in position % 3 != 0 }
        let session = try XCTUnwrap(final.assessment)
        XCTAssertNotNil(session.completedAt)
        XCTAssertEqual(session.answers.count, session.slots.count)
        XCTAssertEqual(final.session, paused)
        XCTAssertEqual(final.words.count, wordsBefore)
        XCTAssertFalse(final.words.contains { AssessmentBuilder.isBankID($0.id) })
        XCTAssertTrue(final.reviews.allSatisfy { !AssessmentBuilder.isBankID($0.wordId) })
        let ownedItems = session.answers.flatMap { $0.items }.filter { $0.owned }
        XCTAssertFalse(ownedItems.isEmpty)
        XCTAssertEqual(final.reviews.count, ownedItems.count)
        XCTAssertEqual(final.assessmentHistory.count, 1)
        XCTAssertEqual(final.assessmentHistory.first?.id, session.id)
        XCTAssertEqual(final.assessmentHistory.first?.total, session.slots.count)
        // Grammar tasks shown in the test are marked as seen.
        XCTAssertFalse(final.grammarSeen.isEmpty)
        // A finished test keeps only base words that were asked.
        let askedBank = Set(session.answers.flatMap { $0.items }.filter { !$0.owned }.map { $0.wordId })
        XCTAssertEqual(Set(session.bankWords.map { $0.id }), askedBank)
        // No way back: further answers change nothing.
        let after = AssessmentEngine.answer(final, response: AssessmentResponse(value: "x", correct: true, seconds: 1), now: testNow + 1)
        XCTAssertEqual(after, final)
    }

    func testEveryWordIsAskedOnceAndLevelsStayInTheBand() throws {
        var state = stateAt("B1")
        state.assessment = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        let final = answerAll(state) { (_: Int) -> Bool in true }
        let session = try XCTUnwrap(final.assessment)
        let refs = session.questions.compactMap { $0.vocabulary }.flatMap { $0.task.allRefs }
        XCTAssertEqual(Set(refs.map { $0.wordId }).count, refs.count)
        let stretch = session.questions.compactMap { $0.vocabulary }.filter { $0.tier == .stretch }.count
        let vocabulary = session.slots.filter { $0.isVocabulary }.count
        XCTAssertLessThanOrEqual(Double(stretch), Double(vocabulary) * AssessmentAdaptation.stretchShare)
        XCTAssertGreaterThan(stretch, 0)
        for question in session.questions {
            XCTAssertTrue(["A2", "B1", "B2"].contains(question.level), question.level)
        }
    }

    func testThreeRightAnswersMoveToTheUpperPart() throws {
        var state = stateAt("B1")
        state.assessment = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        for position in 0..<3 {
            state = AssessmentEngine.answer(state, response: AssessmentResponse(value: "ok", correct: true, seconds: 5), now: testNow + Double(position))
        }
        XCTAssertEqual(state.assessment?.currentQuestion?.tier, .upper)
        for position in 3..<5 {
            state = AssessmentEngine.answer(state, response: AssessmentResponse(value: "x", correct: false, seconds: 5), now: testNow + Double(position))
        }
        XCTAssertEqual(state.assessment?.currentQuestion?.tier, .lower)
    }

    func testSkippingADeletedWordDropsItsSlot() throws {
        var state = stateAt("B1")
        state.words = [ownedWord("o0", level: "A2")]
        state.assessment = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        let before = try XCTUnwrap(state.assessment?.slots.count)
        state = AssessmentEngine.skipCurrent(state, now: testNow)
        XCTAssertEqual(state.assessment?.slots.count, before - 1)
        XCTAssertEqual(state.assessment?.index, 0)
        XCTAssertNotNil(state.assessment?.currentQuestion)
    }

    func testAbandonAndDismiss() throws {
        var state = stateAt("B1")
        state.assessment = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        XCTAssertNotNil(AssessmentEngine.dismissResult(state).assessment)
        XCTAssertNil(AssessmentEngine.abandon(state).assessment)
        let finished = answerAll(state) { (_: Int) -> Bool in true }
        XCTAssertNotNil(AssessmentEngine.abandon(finished).assessment)
        XCTAssertNil(AssessmentEngine.dismissResult(finished).assessment)
        XCTAssertEqual(AssessmentEngine.dismissResult(finished).assessmentHistory.count, 1)
    }

    // MARK: Result

    func testResultPerBlockSkillAndMistakes() throws {
        var state = stateAt("B1")
        state.words = (0..<10).map { (index: Int) -> Word in ownedWord("o\(index)", level: index % 2 == 0 ? "B1" : "A2") }
        state.assessment = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        let final = answerAll(state) { (position: Int) -> Bool in position % 2 == 0 }
        let session = try XCTUnwrap(final.assessment)
        let result = AssessmentScoring.result(session)
        XCTAssertEqual(result.overall.total, session.slots.count)
        XCTAssertEqual(result.blocks.map { $0.block }, AssessmentBlock.allCases)
        XCTAssertEqual(result.blocks.reduce(0) { $0 + $1.score.total }, result.overall.total)
        XCTAssertEqual(Set(result.skills.map { $0.skill }), Set(AssessmentSkill.allCases))
        XCTAssertFalse(result.mistakes.isEmpty)
        XCTAssertTrue(result.mistakes.allSatisfy { !$0.expected.isEmpty })
        XCTAssertEqual(final.assessmentHistory.first?.percent, result.overall.percent)
        // „Dodaj błędne słowa do powtórek” marks own wrong words as difficult.
        let marked = AssessmentEngine.markWrongWordsHard(final, now: testNow)
        XCTAssertEqual(marked.count, AssessmentScoring.wrongOwnedWordIDs(session).count)
        XCTAssertTrue(AssessmentScoring.wrongOwnedWordIDs(session).allSatisfy { marked.state.word(id: $0)?.hard == true })
        XCTAssertEqual(AssessmentEngine.markWrongWordsHard(marked.state, now: testNow).count, 0)
        // „Dodaj nowe słowa do nauki”: references of wrong base words.
        XCTAssertTrue(AssessmentScoring.wrongBankReferences(session).allSatisfy { $0.hasPrefix("travel/") })
    }

    func testLevelEstimateIsHonest() {
        let band = AssessmentBand(base: "B1")
        func score(_ points: Double, _ total: Int) -> AssessmentScore { AssessmentScore(points: points, total: total) }
        let solid = AssessmentScoring.estimateLevel(band: band, overall: score(26, 30), lower: score(10, 11), upper: score(14, 16), stretch: score(1, 3))
        XCTAssertEqual(solid.verdict, .solid)
        XCTAssertEqual(solid.level, "B1")
        let above = AssessmentScoring.estimateLevel(band: band, overall: score(28, 30), lower: score(10, 10), upper: score(15, 17), stretch: score(3, 3))
        XCTAssertEqual(above.level, "B2")
        XCTAssertEqual(above.verdict, .above)
        let confirmed = AssessmentScoring.estimateLevel(band: band, overall: score(20, 30), lower: score(9, 11), upper: score(11, 16), stretch: score(0, 3))
        XCTAssertEqual(confirmed.verdict, .confirmed)
        let below = AssessmentScoring.estimateLevel(band: band, overall: score(15, 30), lower: score(10, 13), upper: score(5, 17), stretch: score(0, 0))
        XCTAssertEqual(below.level, "A2")
        XCTAssertEqual(below.verdict, .below)
        let low = AssessmentScoring.estimateLevel(band: band, overall: score(6, 30), lower: score(3, 13), upper: score(3, 17), stretch: score(0, 0))
        XCTAssertEqual(low.verdict, .belowBand)
        XCTAssertEqual(low.levelText, "A2 lub niżej")
        let few = AssessmentScoring.estimateLevel(band: band, overall: score(5, 5), lower: score(2, 2), upper: score(3, 3), stretch: score(0, 0))
        XCTAssertEqual(few.verdict, .uncertain)
        XCTAssertTrue(solid.descriptionPl.contains("nie wynik egzaminu"))
    }

    // MARK: Coding, migration, sync

    func testStateRoundTripAndOldJSONWithoutTheTest() throws {
        var state = stateAt("B1")
        state.assessment = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        state = AssessmentEngine.answer(state, response: AssessmentResponse(value: "ok", correct: true, seconds: 3), now: testNow)
        state.assessmentHistory = [AssessmentHistoryEntry(id: "h1", at: testNow, baseLevel: "B1", level: "B1", percent: 70, points: 21, total: 30, seconds: 1000, readingId: "r", skills: ["grammar": 75])]
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(LearnerState.self, from: data)
        XCTAssertEqual(decoded.assessment, state.assessment)
        XCTAssertEqual(decoded.assessmentHistory, state.assessmentHistory)
        XCTAssertEqual(decoded.assessmentHistory.first?.score(for: .grammar), 75)

        var plain = TestData.emptyState()
        plain.assessment = nil
        let json = try XCTUnwrap(String(data: JSONEncoder().encode(plain), encoding: .utf8))
        XCTAssertTrue(json.contains("\"assessment\":null"))
        // Old exports (no keys) and a damaged test decode without failing the document.
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "assessmentHistory")
        object["assessment"] = ["id": 5, "questions": "broken"]
        let old = try JSONDecoder().decode(LearnerState.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(old.assessment)
        XCTAssertEqual(old.assessmentHistory, [])
    }

    func testMigrationKeepsAResumableTest() throws {
        var state = stateAt("B1")
        var session = try XCTUnwrap(makeTest(state, content: content(base: "B1", lower: "A2", stretch: "B2")))
        session.questions = []
        state.assessment = session
        let migrated = StateMigration.migrate(state)
        XCTAssertNotNil(migrated.assessment?.currentQuestion)
        XCTAssertEqual(StateMigration.migrate(migrated), migrated)
        var empty = state
        empty.assessment?.slots = []
        XCTAssertNil(StateMigration.migrate(empty).assessment)
    }

    func testMergeKeepsBothHistoriesAndTheMoreAdvancedTest() throws {
        var base = stateAt("B1")
        base.assessment = try XCTUnwrap(makeTest(base, content: content(base: "B1", lower: "A2", stretch: "B2")))
        var local = base
        var remote = AssessmentEngine.answer(base, response: AssessmentResponse(value: "ok", correct: true, seconds: 3), now: testNow + 1)
        local.assessmentHistory = [AssessmentHistoryEntry(id: "a", at: 2, baseLevel: "A2", level: "A2", percent: 50, points: 15, total: 30, seconds: 900)]
        remote.assessmentHistory = [AssessmentHistoryEntry(id: "b", at: 1, baseLevel: "B1", level: "B1", percent: 60, points: 18, total: 30, seconds: 900)]
        let merged = StateSync.mergeStates(local: local, remote: remote)
        XCTAssertEqual(merged.assessmentHistory.map { $0.id }, ["b", "a"])
        XCTAssertEqual(merged.assessment?.index, 1)
        // Finished on the other device: the unfinished local copy disappears.
        var finishedRemote = remote
        finishedRemote.assessment = nil
        finishedRemote.assessmentHistory.append(AssessmentHistoryEntry(id: base.assessment?.id ?? "", at: 3, baseLevel: "B1", level: "B1", percent: 60, points: 18, total: 30, seconds: 900))
        XCTAssertNil(StateSync.mergeStates(local: local, remote: finishedRemote).assessment)
    }
}
