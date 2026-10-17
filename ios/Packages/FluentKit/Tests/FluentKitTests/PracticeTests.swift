import XCTest
@testable import FluentKit

final class PracticeTests: XCTestCase {
    func testGrammarTaskIDMatchesWebHash() {
        XCTAssertEqual(GrammarSelector.taskID(bankId: "grammar-36-A1-00-00", context: "x"), "grammar-36-A1-00-00")
        // Value produced by the web `grammarTaskId` (see exercises.json, first A1 item).
        XCTAssertEqual(GrammarSelector.taskID(bankId: nil, context: "Right now, I ________ (być) a student at this school."), "legacy-grammar-773677652")
        XCTAssertEqual(FNV1a.hash32(""), 2_166_136_261)
    }

    func testSelectGrammarItemsUnseenFirstAndSpread() {
        let pool = TestData.syntheticContent().productionPool(level: "C1")
        var seen: [String: Double] = [:]
        let first = GrammarSelector.selectItems(pool, count: 6, seen: seen, variant: 7)
        XCTAssertEqual(first.count, 6)
        XCTAssertEqual(Set(first.map { $0.bankId ?? "" }).count, 6)
        XCTAssertGreaterThanOrEqual(Set(first.map { $0.rule }).count, 4)
        for item in first { seen[item.bankId ?? ""] = testNow }
        let second = GrammarSelector.selectItems(pool, count: 6, seen: seen, variant: 8)
        XCTAssertTrue(second.allSatisfy { seen[$0.bankId ?? ""] == nil })
        XCTAssertTrue(GrammarSelector.selectItems([], count: 6).isEmpty)
    }

    func testNeverRepeatsUntilLevelExhaustedThenOldestFirst() {
        let content = TestData.syntheticContent()
        let pool = content.productionPool(level: "B1")
        var seen: [String: Double] = [:]
        var clock = 1.0
        for session in 0..<(pool.count / 6) {
            let items: [String]
            if session % 2 == 0 {
                items = PracticeBuilder.starterProduction(level: "B1", variant: session, count: 6, seen: seen, content: content).items.compactMap { $0.bankId }
            } else {
                items = PracticeBuilder.starterPractice(kind: .grammar, level: "B1", variant: session, seen: seen, content: content).items.compactMap { $0.bankId }
            }
            XCTAssertEqual(items.count, 6)
            for id in items {
                XCTAssertNil(seen[id], "repeated \(id)")
                seen[id] = clock
                clock += 1
            }
        }
        XCTAssertEqual(seen.count, pool.count)
        let oldest = seen.values.min()
        let repeatSet = GrammarSelector.selectItems(pool, count: 6, seen: seen, variant: 999)
        XCTAssertEqual(seen[repeatSet[0].bankId ?? ""], oldest)
        XCTAssertEqual(Set(repeatSet.compactMap { $0.bankId }).count, 6)
    }

    func testStarterPracticeShapes() {
        let content = TestData.syntheticContent()
        for level in CEFR.levels {
            for kind in PracticeKind.allCases {
                let set = PracticeBuilder.starterPractice(kind: kind, level: level, content: content)
                XCTAssertEqual(set.items.count, 6, "\(kind) \(level)")
                XCTAssertTrue(set.items.allSatisfy { $0.options.count == 4 && Set($0.options).count == 4 && $0.answer >= 0 && $0.answer < 4 })
                if kind == .mixed {
                    XCTAssertEqual(Set(set.items.map { $0.category }), [.grammar, .idiom])
                    let inputs = set.items.filter { $0.format == .input }
                    XCTAssertEqual(inputs.count, 2)
                    XCTAssertTrue(inputs.allSatisfy { ($0.inputHint ?? "").isEmpty == false && $0.context.contains("__") })
                }
            }
        }
        let grammar = PracticeBuilder.starterPractice(kind: .grammar, level: "B1", variant: 0, content: content)
        XCTAssertFalse(grammar.items[0].context.contains("(robić)"), "hint removed from the multiple-choice context")
        XCTAssertEqual(grammar.items[0].inputHint, "robić")
        XCTAssertNotEqual(PracticeBuilder.starterPractice(kind: .grammar, level: "B1", variant: 1, content: content).items[0].context, grammar.items[0].context)
    }

    func testKeyStaysAlignedAfterRotation() {
        let content = TestData.syntheticContent()
        let pool = content.productionPool(level: "C1")
        for variant in 0..<5 {
            let set = PracticeBuilder.starterPractice(kind: .mixed, level: "C1", variant: variant, seen: [:], content: content)
            for item in set.items where item.category == .grammar {
                let original = pool.first { $0.bankId == item.bankId }
                XCTAssertEqual(item.options[item.answer], original?.answer)
            }
            for item in set.items where item.category == .idiom {
                XCTAssertTrue(item.options[item.answer].hasPrefix("Znaczenie"))
            }
        }
    }

    func testIdiomPoolRotatesDistractors() {
        let content = TestData.syntheticContent()
        let v0 = content.idiomPool(level: "B2", variant: 0)
        let v1 = content.idiomPool(level: "B2", variant: 1)
        XCTAssertEqual(v0.count, 18)
        XCTAssertNotEqual(v0[0].options, v1[0].options)
        XCTAssertTrue(v0.allSatisfy { $0.answer == 0 && !$0.options.dropFirst().contains($0.options[0]) })
        var seen = Set<String>()
        for variant in 0..<3 {
            for item in PracticeBuilder.starterPractice(kind: .idioms, level: "B2", variant: variant, content: content).items {
                XCTAssertFalse(seen.contains(item.context))
                seen.insert(item.context)
            }
        }
        XCTAssertEqual(seen.count, 18)
    }

    func testStarterProduction() {
        let content = TestData.syntheticContent()
        let set = PracticeBuilder.starterProduction(level: "C2", content: content)
        XCTAssertEqual(set.level, "C2")
        XCTAssertEqual(set.items.count, 4)
        XCTAssertNotEqual(PracticeBuilder.starterProduction(level: "B1", variant: 0, content: content).items[0].context, PracticeBuilder.starterProduction(level: "B1", variant: 1, content: content).items[0].context)
        XCTAssertEqual(PracticeBuilder.starterProduction(level: "XX", content: content).level, "A2")
        XCTAssertTrue(PracticeBuilder.starterProduction(level: "B1", content: .empty).items.isEmpty)
        XCTAssertTrue(PracticeBuilder.starterPractice(kind: .mixed, level: "B1", content: .empty).items.isEmpty)
    }

    func testPausedSessionsReserveUnshownTasks() {
        let content = TestData.syntheticContent()
        var state = TestData.seed()
        let first = PracticeBuilder.starterProduction(level: "B1", variant: 0, count: 6, seen: [:], content: content)
        state.production = ProductionSession(id: "paused", set: first)
        state = GrammarSelector.markSeen(state, bankId: first.items[0].bankId, context: first.items[0].context, at: 100)
        let reserved = GrammarSelector.selectionSeen(state, now: testNow)
        let next = PracticeBuilder.starterPractice(kind: .grammar, level: "B1", variant: 1, seen: reserved, content: content)
        XCTAssertTrue(next.items.allSatisfy { item in !first.items.contains { $0.bankId == item.bankId } })
        XCTAssertEqual(state.grammarSeen.count, 1)
        state.production = nil
        XCTAssertEqual(GrammarSelector.selectionSeen(state, now: testNow).count, 1)
    }

    // MARK: Readings and level

    func testReadingSelectionVariesThenCycles() {
        let bank = TestData.syntheticContent().readings
        var history: [ReadingHistoryEntry] = []
        for index in 0..<5 {
            guard let reading = ReadingSelector.selectBankReading(level: "A1", history: history, bank: bank) else { return XCTFail("no reading") }
            XCTAssertFalse(history.contains { $0.id == reading.id })
            XCTAssertNil(reading.topic)
            history.append(ReadingHistoryEntry(id: reading.id, at: Double(index + 1), level: "A1", correct: 0, total: 4))
        }
        XCTAssertEqual(ReadingSelector.selectBankReading(level: "A1", history: history, bank: bank)?.id, history[0].id)
        XCTAssertEqual(ReadingSelector.selectBankReading(level: "B1", topic: "Lotnisko", bank: bank)?.id, "reading-B1-2")
        XCTAssertNil(ReadingSelector.selectBankReading(level: "A1", bank: ReadingBank()))
        XCTAssertEqual(ReadingSelector.selectBankReading(level: "ZZ", bank: bank)?.level, "A2")
    }

    func testReadingAnswersRotateWithHistory() {
        let bank = TestData.syntheticContent().readings
        let history = [ReadingHistoryEntry(id: "other", at: 1, level: "A1", correct: 0, total: 4)]
        guard let reading = ReadingSelector.selectBankReading(level: "A1", history: history, bank: bank),
              let original = bank.readings.first(where: { $0.id == reading.id }) else { return XCTFail("missing") }
        for (rotated, source) in zip(reading.questions, original.questions) {
            XCTAssertEqual(rotated.options[rotated.answer], source.options[source.answer])
            XCTAssertNotEqual(rotated.options, source.options)
        }
    }

    func testRealReadingBankTopicSelection() throws {
        let bank = try ContentDecoder.readings(from: try TestData.contentData("readings.json"))
        let reading = ReadingSelector.selectBankReading(level: "B1", topic: "lotnisko", bank: bank)
        XCTAssertTrue(reading?.title.lowercased().contains("connection") ?? false, reading?.title ?? "nil")
    }

    func testEstimatedLevel() {
        var state = TestData.emptyState()
        XCTAssertEqual(LevelEstimator.estimatedLevel(state), LevelEstimate(level: "A1", targetLevel: "A2", count: 0, confidence: .low))
        var word = TestData.freshWord("known", "manage", "zarządzać")
        word.level = "B1"
        word.meanings[0].scores[.recognition] = Score(value: 50, interval: 14, due: testNow, correct: 1, last: 1)
        state.words = [word]
        let estimate = LevelEstimator.estimatedLevel(state)
        XCTAssertEqual(estimate.level, "B1")
        XCTAssertEqual(estimate.targetLevel, "B2")
        XCTAssertEqual(estimate.confidence, .low, "one practiced skill cannot establish broad confidence")
        for skill in Skill.masterySkills { state.words[0].meanings[0].scores[skill] = word.meanings[0].scores[.recognition] }
        XCTAssertEqual(LevelEstimator.estimatedLevel(state).confidence, .high)

        var fresh = TestData.freshWord("c1", "scrutinize", "dokładnie badać")
        fresh.level = "C1"
        state.words = [fresh]
        XCTAssertEqual(LevelEstimator.estimatedLevel(state), LevelEstimate(level: "C1", targetLevel: "C2", count: 1, confidence: .low))
        fresh.level = ""
        state.words = [fresh]
        XCTAssertEqual(LevelEstimator.estimatedLevel(state).count, 0)
    }

    func testSelectReadingMeaningsIncludesSecondSenses() {
        var state = TestData.seed()
        state.words[6].hard = true
        state.words[6].meanings[1].level = "A2"
        let selected = ReadingSelector.selectReadingMeanings(state, targetLevel: "A2", limit: 20, now: testNow)
        XCTAssertTrue(selected.contains { $0.meaningId == "m6b" && $0.translation == "brzeg rzeki" })
        XCTAssertTrue(selected.allSatisfy { !$0.meaningId.isEmpty && !$0.translation.isEmpty && !$0.level.isEmpty })
        XCTAssertLessThanOrEqual(selected.count, 20)
    }

    func testRecommendationsAfterMastery() {
        var state = TestData.seed()
        let candidates = [
            Recommendation(known: "do", term: "carry out", level: "B2", translation: "wykonać, przeprowadzić", difference: "d", example: "We will carry out the plan tomorrow.", examplePl: "Jutro zrealizujemy plan."),
            Recommendation(known: "figure out", term: "ascertain", level: "C1", translation: "ustalić, dowiedzieć się", difference: "d", example: "We need to ascertain the cause.", examplePl: "Musimy ustalić przyczynę.")
        ]
        for index in state.words.indices {
            for meaningIndex in state.words[index].meanings.indices {
                for (skill, _) in state.words[index].meanings[meaningIndex].scores.entries {
                    state.words[index].meanings[meaningIndex].scores[skill]?.interval = 0
                }
            }
        }
        XCTAssertTrue(LevelEstimator.recommendations(state, candidates: candidates).isEmpty)
        guard let doIndex = state.words.firstIndex(where: { $0.en == "do" }) else { return XCTFail("missing do") }
        for skill in Skill.masterySkills {
            state.words[doIndex].meanings[0].scores[skill] = Score(value: 100, interval: 90, due: testNow + day, correct: 5, last: testNow)
        }
        XCTAssertEqual(LevelEstimator.recommendations(state, candidates: candidates).map { $0.term }, ["carry out"])
        let lookup = LevelEstimator.lookup(for: candidates[1])
        XCTAssertEqual(lookup.meanings.first?.examples.first?.focusPl, "ustalić")
        XCTAssertEqual(LevelEstimator.lookup(for: candidates[0]).meanings.first?.examples.first?.focusPl, "")
    }

    // MARK: Practice flow

    func testPracticeFlowWritesHistory() {
        let content = TestData.syntheticContent()
        var state = PracticeFlow.startPractice(TestData.seed(), kind: .grammar, level: "B1", content: content, now: testNow)
        XCTAssertEqual(state.practice?.set.items.count, 6)
        for _ in 0..<6 {
            guard let practice = state.practice, let item = practice.set.items[safe: practice.index] else { return XCTFail("no item") }
            state = PracticeFlow.answerPractice(state, choice: item.answer)
            let again = PracticeFlow.answerPractice(state, choice: (item.answer + 1) % 4)
            XCTAssertEqual(again, state, "an answer is recorded once")
            state = PracticeFlow.advancePractice(state, now: testNow)
        }
        XCTAssertNotNil(state.practice?.completedAt)
        XCTAssertEqual(state.practiceHistory.last?.correct, 6)
        XCTAssertEqual(state.practiceHistory.last?.total, 6)
    }

    func testProductionAndReadingFlows() {
        let content = TestData.syntheticContent()
        var state = PracticeFlow.startProduction(TestData.seed(), level: "B1", content: content, now: testNow, id: "p1")
        guard let items = state.production?.set.items else { return XCTFail("no production") }
        for item in items {
            state = PracticeFlow.answerProduction(state, text: item.answer)
            state = PracticeFlow.advanceProduction(state, now: testNow)
        }
        XCTAssertEqual(state.productionHistory.last?.id, "p1")
        XCTAssertEqual(state.productionHistory.last?.correct, items.count)

        state = PracticeFlow.startReading(state, bank: content.readings)
        guard let reading = state.reading else { return XCTFail("no reading") }
        state.reading?.answers = reading.reading.questions.map { $0.answer }
        let submitted = PracticeFlow.submitReading(state, now: testNow)
        XCTAssertEqual(submitted.readingHistory.last?.correct, reading.reading.questions.count)
        XCTAssertEqual(PracticeFlow.submitReading(submitted, now: testNow), submitted)
    }

    // MARK: Combined sessions

    func testCombinedSessionOrderGradeOnceAndHistory() {
        let content = TestData.syntheticContent()
        var state = TestData.seed()
        let oldSession = VocabSession(tasks: [VocabTask(wordId: "w0", meaningId: "m0", type: .flashcard, example: 0)], minutes: 5, mode: "mixed")
        state.session = oldSession
        var generator = ConstantGenerator(value: UInt64.max / 4)
        state.combined = CombinedSessionBuilder.makeSession(state: state, modes: [.mixed, .reading, .grammar, .idioms, .production, .languageMix], minutes: 15, random: true, content: content, now: testNow, id: "combined", using: &generator)
        guard let combined = state.combined else { return XCTFail("no session") }
        XCTAssertGreaterThanOrEqual(combined.tasks.count, 20)
        XCTAssertEqual(combined.answers.count, combined.tasks.count)
        XCTAssertEqual(Set(combined.tasks.map { $0.mode }), Set(StudyMode.combinableModes.filter { $0 != .mistakes && $0 != .pairs }))
        let order = combined.tasks
        let answer = CombinedAnswer(value: "test", correct: true, seconds: 3, explanation: "Test")
        let before = state.reviews.count
        let isVocabulary = combined.tasks[0].vocabularyTask != nil
        var restored = CombinedSessionBuilder.saveAnswer(state, answer: answer, now: testNow, reviewID: "r-1")
        XCTAssertEqual(restored.session, oldSession)
        XCTAssertEqual(restored.reviews.count, before + (isVocabulary ? 1 : 0))
        XCTAssertEqual(CombinedSessionBuilder.saveAnswer(restored, answer: answer, now: testNow), restored, "double tap cannot grade twice")
        restored = CombinedSessionBuilder.advance(restored, now: testNow)
        XCTAssertEqual(restored.combined?.index, 1)
        XCTAssertEqual(restored.combined?.tasks, order)
        var guardCounter = 0
        while restored.combined?.completedAt == nil && guardCounter < 200 {
            restored = CombinedSessionBuilder.advance(CombinedSessionBuilder.saveAnswer(restored, answer: answer, now: testNow, reviewID: "r-\(guardCounter + 2)"), now: testNow)
            guardCounter += 1
        }
        XCTAssertEqual(restored.combined?.index, restored.combined?.tasks.count)
        XCTAssertEqual(CombinedSessionBuilder.advance(restored, now: testNow), restored)
        XCTAssertFalse(restored.practiceHistory.isEmpty)
        XCTAssertFalse(restored.readingHistory.isEmpty)
        XCTAssertEqual(StateSync.mergeStates(local: state, remote: restored).combined?.completedAt, restored.combined?.completedAt)
        // Round trip through JSON keeps the order.
        if let data = try? JSONEncoder().encode(restored), let decoded = try? JSONDecoder().decode(LearnerState.self, from: data) {
            XCTAssertEqual(decoded.combined, restored.combined)
        } else {
            XCTFail("encoding failed")
        }
    }

    func testOrderedCombinedKeepsGroupsAndRandomAlternates() {
        let content = TestData.syntheticContent()
        var generator = SeededGenerator(seed: 2)
        let ordered = CombinedSessionBuilder.makeSession(state: TestData.seed(), modes: [.grammar, .idioms], minutes: 10, random: false, content: content, now: testNow, using: &generator)
        XCTAssertEqual(ordered.tasks.prefix(8).map { $0.mode }, Array(repeating: .grammar, count: 8))
        var zero = ConstantGenerator(value: 0)
        let random = CombinedSessionBuilder.orderTasks(ordered.tasks, random: true, using: &zero)
        XCTAssertEqual(random.count, ordered.tasks.count)
        for index in 1..<random.count { XCTAssertNotEqual(random[index].mode, random[index - 1].mode) }

        var empty = TestData.seed()
        empty.words = []
        empty.reviews = []
        var generator2 = SeededGenerator(seed: 3)
        let available = CombinedSessionBuilder.makeSession(state: empty, modes: [.pairs, .grammar], minutes: 5, random: true, content: content, now: testNow, using: &generator2)
        XCTAssertFalse(available.tasks.isEmpty)
        XCTAssertTrue(available.tasks.allSatisfy { $0.mode == .grammar })
        var generator3 = SeededGenerator(seed: 3)
        XCTAssertTrue(CombinedSessionBuilder.makeSession(state: empty, modes: [], minutes: 5, random: true, content: content, now: testNow, using: &generator3).tasks.isEmpty)
    }
}
