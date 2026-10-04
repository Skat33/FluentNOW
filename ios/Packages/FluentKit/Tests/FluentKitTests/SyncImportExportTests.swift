import XCTest
@testable import FluentKit

final class SyncImportExportTests: XCTestCase {
    // MARK: Fixture / migration

    func testV31ExportDecodesAndMigratesAdditively() throws {
        let data = try TestData.fixtureData()
        let state = try StateImporter.importJSON(data)
        XCTAssertEqual(state.words.count, 18)
        XCTAssertEqual(state.reviews.count, 69)
        XCTAssertNil(state.production)
        XCTAssertNil(state.combined)
        XCTAssertEqual(state.productionHistory, [])
        XCTAssertEqual(state.grammarSeen, [:])
        XCTAssertTrue(state.reviews.allSatisfy { $0.masteryVersion == nil && $0.weight == 1 && $0.source == .exercise })
        XCTAssertTrue(state.words.allSatisfy { $0.meanings.allSatisfy { $0.enrichment == nil } })
        XCTAssertEqual(state.settings.goal, 20)
        XCTAssertTrue(state.demo)

        // Words survive a migrate → export → import round trip unchanged.
        let raw = try JSONDecoder().decode(LearnerState.self, from: data)
        XCTAssertEqual(StateMigration.migrate(raw).words, raw.words)
        let exported = try StateExporter.exportJSON(state)
        let reimported = try StateImporter.importJSON(exported)
        XCTAssertEqual(reimported, state)
    }

    func testExportIsWebCompatibleJSON() throws {
        let state = TestData.seed()
        let data = try StateExporter.exportJSON(state)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["version"] as? Int, 1)
        let inner = object?["state"] as? [String: Any]
        XCTAssertNotNil(inner?["words"] as? [Any])
        XCTAssertTrue(inner?["session"] is NSNull, "session is a required nullable key")
        let firstWord = (inner?["words"] as? [[String: Any]])?.first
        let scores = ((firstWord?["meanings"] as? [[String: Any]])?.first?["scores"]) as? [String: Any]
        XCTAssertNotNil(scores?["recognition"] as? [String: Any], "scores encode as an object keyed by skill")
        XCTAssertEqual(try StateImporter.importJSON(data), StateMigration.migrate(state))
    }

    func testMigrationNormalisesLegacyValues() {
        var state = TestData.seed()
        state.words[0].meanings[0].scores[.recall]?.value = 99
        state.words[0].meanings[0].scores[.recall]?.interval = 1
        state.words[0].meanings[0].translation = "rachunek (AmE)"
        state.words[0].meanings[0].topic = "  Lotnisko "
        state.words[0].meanings[0].scene = "   "
        state.words[0].meanings[0].enrichment = Enrichment(round: 9, phase: .ready, groups: [.affirmative, .affirmative], retryAt: -5)
        let migrated = StateMigration.migrate(state)
        let meaning = migrated.words[0].meanings[0]
        XCTAssertEqual(meaning.scores[.recall]?.value, Mastery.fromInterval(1))
        XCTAssertEqual(meaning.translation, "rachunek")
        XCTAssertEqual(meaning.topic, "Lotnisko")
        XCTAssertNil(meaning.scene)
        XCTAssertEqual(meaning.enrichment?.round, 5)
        XCTAssertEqual(meaning.enrichment?.groups, [.affirmative])
        XCTAssertEqual(meaning.enrichment?.retryAt, 0)
        XCTAssertEqual(StateMigration.migrate(migrated), migrated, "idempotent")
    }

    func testMigrationDropsUnpublishedPendingTasksButKeepsPrefix() {
        var state = TestData.seed()
        state.words = [state.words[0], state.words[1]]
        state.words[0].meanings[0].examples = (0..<15).map { "Sentence \($0)." }
        state.words[0].meanings[0].enrichment = Enrichment(phase: .examples, groups: [.affirmative])
        let pending = VocabTask(wordId: "w0", meaningId: "m0", type: .recall, example: 0)
        let done = VocabTask(wordId: "w1", meaningId: "m1", type: .flashcard, example: 0)
        state.session = VocabSession(tasks: [done, pending, done], index: 1, correct: 5, minutes: 5, mode: "mixed")
        let migrated = StateMigration.migrate(state)
        XCTAssertEqual(migrated.session?.tasks, [done, done])
        XCTAssertEqual(migrated.session?.index, 1)
        XCTAssertEqual(migrated.session?.correct, 1)
        var broken = state
        broken.session = VocabSession(tasks: [VocabTask(wordId: "absent", meaningId: "absent", type: .flashcard, example: 0)], index: 1, minutes: 5, mode: "mixed")
        XCTAssertNil(StateMigration.migrate(broken).session)
    }

    func testOldPracticeSessionsGetWrittenAnswers() {
        var state = TestData.seed()
        let set = PracticeSet(id: "s", title: "t", level: "B1", kind: .mixed, items: (0..<6).map { index in
            PracticeQuestion(bankId: "b\(index)", category: .grammar, prompt: "p", context: "c\(index)", options: ["a", "b", "c", "d"], answer: 0)
        })
        state.practice = PracticeSession(set: set, writtenAnswers: nil, answers: [0, -1], index: 1)
        state.practice?.writtenAnswers = nil
        let migrated = StateMigration.migrate(state)
        XCTAssertEqual(migrated.practice?.writtenAnswers, ["", "", "", "", "", ""])
        XCTAssertEqual(migrated.practice?.answers, [0, -1, -1, -1, -1, -1])
        XCTAssertEqual(migrated.grammarSeen["b0"], 1)
        XCTAssertEqual(migrated.grammarSeen["b1"], 1)
        XCTAssertNil(migrated.grammarSeen["b2"])
    }

    func testDuplicateWordIDsAreMergedAndDuplicateMeaningsRejected() throws {
        var state = TestData.seed()
        var copy = state.words[0]
        copy.updatedAt = testNow + day
        copy.en = "newer"
        state.words.append(copy)
        let migrated = StateMigration.migrate(state)
        XCTAssertEqual(migrated.words.count, 18)
        XCTAssertEqual(migrated.words[0].en, "newer")

        var duplicate = TestData.seed()
        duplicate.words[1].meanings[0].id = duplicate.words[0].meanings[0].id
        let data = try StateExporter.exportJSON(duplicate)
        XCTAssertThrowsError(try StateImporter.importJSON(data)) { error in
            XCTAssertEqual(error as? ImportError, .duplicateMeaningID("m0"))
        }
    }

    func testImportErrorsAreReadable() {
        XCTAssertThrowsError(try StateImporter.importJSON(Data())) { XCTAssertEqual($0 as? ImportError, .empty) }
        XCTAssertThrowsError(try StateImporter.importJSON(Data("not json".utf8))) { XCTAssertEqual($0 as? ImportError, .notJSON) }
        XCTAssertThrowsError(try StateImporter.importJSON(Data(#"{"hello": 1}"#.utf8))) { XCTAssertEqual($0 as? ImportError, .notFluentExport) }
        XCTAssertThrowsError(try StateImporter.importJSON(Data(#"{"version": 2, "state": {"words": []}}"#.utf8))) { XCTAssertEqual($0 as? ImportError, .unsupportedVersion(2)) }
        XCTAssertThrowsError(try StateImporter.importJSON(Data(#"{"version": 1, "state": {"words": [{"id": "a"}]}}"#.utf8))) { error in
            guard case .invalidData(let detail)? = error as? ImportError else { return XCTFail("\(error)") }
            XCTAssertTrue(detail.contains("words[0].en"), detail)
            XCTAssertNotNil((error as? ImportError)?.errorDescription)
        }
        XCTAssertThrowsError(try StateImporter.importJSON(Data(repeating: 32, count: 2_000), maxBytes: 1_000)) { error in
            XCTAssertEqual(error as? ImportError, .tooLarge(maxMegabytes: 1))
        }
        let minimal = try? StateImporter.importJSON(Data(#"{"version": 1, "state": {"words": [], "session": {"broken": true}, "reviews": [{"id": 5}]}}"#.utf8))
        XCTAssertNotNil(minimal, "malformed transient data is dropped, not fatal")
        XCTAssertNil(minimal?.session)
        XCTAssertEqual(minimal?.reviews, [])
        XCTAssertEqual(minimal?.settings, LearnerSettings())
    }

    // MARK: Sync

    func testCompactReviewsAggregatesOldRealReviews() {
        var state = TestData.seed()
        let old = testNow - 100 * day
        guard let template = state.reviews.first else { return XCTFail("no reviews") }
        var real = template
        real.id = "real-old"
        real.at = old
        real.demo = false
        real.correct = true
        var demo = template
        demo.id = "demo-old"
        demo.at = old
        demo.demo = true
        state.reviews = [real, demo]
        let compacted = StateSync.compactReviews(state, now: testNow)
        XCTAssertEqual(compacted.reviews.count, 0)
        XCTAssertEqual(compacted.reviewSummaries.count, 1)
        XCTAssertEqual(compacted.reviewSummaries.first?.count, 1)
        XCTAssertEqual(compacted.reviewSummaries.first?.correct, 1)
        XCTAssertEqual(compacted.reviewSummaries.first?.day, StateSync.utcDay(old))
        XCTAssertEqual(StateSync.utcDay(0), "1970-01-01")
    }

    func testMergeKeepsLatestWordEditAndUnitesReviews() {
        var local = TestData.seed()
        var remote = TestData.seed()
        local.words[0].en = "local-new"
        local.words[0].updatedAt = 20
        remote.words[0].en = "remote-old"
        remote.words[0].updatedAt = 10
        local.reviews = [local.reviews[0]]
        local.reviews[0].id = "local-review"
        remote.reviews = [remote.reviews[0]]
        remote.reviews[0].id = "remote-review"
        let merged = StateSync.mergeStates(local: local, remote: remote)
        XCTAssertEqual(merged.word(id: "w0")?.en, "local-new")
        XCTAssertEqual(Set(merged.reviews.map { $0.id }), ["local-review", "remote-review"])
    }

    func testMergeKeepsProgressFromBothDevices() {
        var local = TestData.seed()
        var remote = TestData.seed()
        local.words[5].updatedAt = testNow + 10
        local.words[5].meanings[0].scores[.recall] = Score(value: 31, interval: 3, due: testNow + 3 * day, correct: 1, last: testNow + 10)
        remote.words[5].updatedAt = testNow + 5
        remote.words[5].meanings[0].scores[.listening] = Score(value: 31, interval: 3, due: testNow + 3 * day, correct: 1, last: testNow + 5)
        let merged = StateSync.mergeStates(local: local, remote: remote)
        XCTAssertNotNil(merged.word(id: "w5")?.meanings[0].scores[.recall])
        XCTAssertNotNil(merged.word(id: "w5")?.meanings[0].scores[.listening])
    }

    func testMergePreservesExampleBankAndExposure() {
        var answered = TestData.seed()
        answered.words = [answered.words[0]]
        answered.words[0].meanings[0].examples = (0..<15).map { "Sentence \($0)" }
        answered.words[0].meanings[0].enrichment = Enrichment(phase: .ready, groups: [.affirmative, .negative, .question])
        answered.words[0].meanings[0].usedExamples = [0]
        answered.words[0].updatedAt = testNow
        var remote = answered
        remote.words[0].updatedAt = 1
        remote.words[0].meanings[0].examples += (0..<15).map { "New sentence \($0)" }
        remote.words[0].meanings[0].enrichment?.round = 1
        remote.words[0].meanings[0].usedExamples = [1, 2]
        let merged = StateSync.mergeStates(local: answered, remote: remote).words[0].meanings[0]
        XCTAssertEqual(merged.availableExampleCount, 30)
        XCTAssertEqual(Set(merged.usedExamples ?? []), [0, 1, 2])
    }

    func testMergeGrammarSeenHistoriesAndSummaries() {
        var a = TestData.seed()
        var b = a
        a.grammarSeen = ["grammar-36-A1-00-00": 100, "grammar-36-B1-04-02": 150]
        b.grammarSeen = ["grammar-36-A1-00-00": 300, "grammar-36-C2-03-12": 200]
        a.reviewSummaries = [ReviewSummary(day: "2026-01-01", count: 3, correct: 1)]
        b.reviewSummaries = [ReviewSummary(day: "2026-01-01", count: 2, correct: 2), ReviewSummary(day: "2025-12-31", count: 1, correct: 1)]
        a.readingHistory = [ReadingHistoryEntry(id: "r1", at: 5, level: "A2", correct: 1, total: 3)]
        b.readingHistory = [ReadingHistoryEntry(id: "r0", at: 1, level: "A2", correct: 2, total: 3)]
        a.collections = ["X", "Codzienne rozmowy"]
        let merged = StateSync.mergeStates(local: a, remote: b)
        XCTAssertEqual(merged.grammarSeen, ["grammar-36-A1-00-00": 300, "grammar-36-B1-04-02": 150, "grammar-36-C2-03-12": 200])
        XCTAssertEqual(merged.reviewSummaries, [ReviewSummary(day: "2025-12-31", count: 1, correct: 1), ReviewSummary(day: "2026-01-01", count: 3, correct: 2)])
        XCTAssertEqual(merged.readingHistory.map { $0.id }, ["r0", "r1"])
        XCTAssertEqual(merged.collections.first, "Codzienne rozmowy")
        XCTAssertTrue(merged.collections.contains("X"))
        XCTAssertEqual(Set(merged.collections).count, merged.collections.count)
    }

    func testMergeCombinedPrefersProgress() {
        var a = TestData.seed()
        var b = a
        let task = CombinedTask.vocabulary(mode: .mixed, task: VocabTask(wordId: "w0", meaningId: "m0", type: .flashcard, example: 0))
        let base = CombinedSession(id: "c", modes: [.mixed], random: false, minutes: 5, tasks: [task, task], updatedAt: 10)
        var ahead = base
        ahead.answers[0] = CombinedAnswer(value: "x", correct: true, seconds: 1)
        ahead.index = 1
        ahead.updatedAt = 5
        a.combined = base
        b.combined = ahead
        XCTAssertEqual(StateSync.mergeStates(local: a, remote: b).combined, ahead)
        b.combined = nil
        XCTAssertEqual(StateSync.mergeStates(local: a, remote: b).combined, base)
    }

    func testMergeDuplicateWords() {
        let seed = TestData.seed()
        var newer = seed.words[3]
        newer.updatedAt = testNow + day
        newer.note = "newer"
        let merged = StateSync.mergeDuplicateWords([seed.words[3], seed.words[4], newer])
        XCTAssertEqual(merged.map { $0.id }, ["w3", "w4"])
        XCTAssertEqual(merged[0].note, "newer")
    }

    // MARK: CSV / TSV

    func testParseDelimited() throws {
        XCTAssertEqual(try DelimitedImport.parse("a,b\r\nc,\"d, e\"\n"), [["a", "b"], ["c", "d, e"]])
        XCTAssertEqual(try DelimitedImport.parse("a;b\nc;d"), [["a", "b"], ["c", "d"]])
        XCTAssertEqual(try DelimitedImport.parse("a\tb,c"), [["a", "b,c"]])
        XCTAssertEqual(try DelimitedImport.parse("\"say \"\"hi\"\"\",x"), [["say \"hi\"", "x"]])
        XCTAssertThrowsError(try DelimitedImport.parse("\"open,x")) { XCTAssertEqual($0 as? ImportError, .unclosedQuote) }
    }

    func testImportRows() throws {
        let state = TestData.seed()
        let text = "English;Polish;Example;Collection;Tags;Level\nhire;zatrudnić;We hire new staff every spring.;Praca;job hr;B1\nhire;wynająć\nlend;pożyczyć komuś\n"
        let result = try DelimitedImport.importRows(text, into: state, now: testNow, makeID: IDGenerator().next)
        XCTAssertEqual(result.addedWords, 1)
        XCTAssertEqual(result.addedMeanings, 2)
        XCTAssertEqual(result.skippedExisting, 1, "lend / pożyczyć komuś already exists")
        let hire = result.state.word(en: "hire")
        XCTAssertEqual(hire?.meanings.count, 2)
        XCTAssertEqual(hire?.collection, "Praca")
        XCTAssertEqual(hire?.tags, ["job", "hr"])
        XCTAssertEqual(hire?.level, "B1")
        XCTAssertEqual(hire?.meanings[1].examples, ["hire"])
        XCTAssertEqual(result.state.words.first?.en, "hire")
        XCTAssertTrue(result.state.collections.contains("Praca"))
        XCTAssertThrowsError(try DelimitedImport.importRows("only-english", into: state, now: testNow)) { XCTAssertEqual($0 as? ImportError, .missingFields(row: 1)) }
        XCTAssertThrowsError(try DelimitedImport.importRows("  \n ", into: state, now: testNow)) { XCTAssertEqual($0 as? ImportError, .empty) }
        let many = (0..<501).map { "w\($0),t\($0)" }.joined(separator: "\n")
        XCTAssertThrowsError(try DelimitedImport.importRows(many, into: state, now: testNow)) { XCTAssertEqual($0 as? ImportError, .tooManyRows(max: 500)) }
    }

    func testImportWordList() throws {
        let result = try DelimitedImport.importRows("apple - jabłko\npear — gruszka", into: TestData.emptyState(), now: testNow, makeID: IDGenerator().next)
        XCTAssertEqual(result.state.words.map { $0.en }, ["apple", "pear"])
        XCTAssertEqual(result.state.words.map { $0.meanings[0].translation }, ["jabłko", "gruszka"])
        XCTAssertEqual(result.state.collections, ["Moje słowa"])
    }

    func testAnkiCSV() {
        var state = TestData.emptyState()
        state.words = [TestData.freshWord("a", "say \"hi\"", "przywitać się")]
        let csv = StateExporter.ankiCSV(state)
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}\"English\",\"Polish\""))
        XCTAssertTrue(csv.contains("\"say \"\"hi\"\"\",\"przywitać się\""))
        XCTAssertTrue(csv.contains("\r\n"))
        XCTAssertNoThrow(try StateExporter.exportReviewsJSON(TestData.seed()))
    }
}
