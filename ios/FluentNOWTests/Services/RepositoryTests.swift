import XCTest
import SwiftData
import FluentKit
@testable import FluentNOW

/// Repozytorium SwiftData na magazynie w pamięci: zapis/odczyt, przyrostowość,
/// scalanie duplikatów, uszkodzone rekordy, kompaktowanie, usuwanie.
final class RepositoryTests: XCTestCase {

    func testRoundTripOfPreviewState() async throws {
        let (repository, _) = try ServicesTestSupport.makeRepository()
        let state = StateMigration.migrate(PreviewData.state())
        try await repository.save(state)

        let loaded = try await repository.load(now: PreviewData.now)
        XCTAssertEqual(loaded.skippedRecords, 0)
        XCTAssertEqual(loaded.mergedDuplicates, 0)
        XCTAssertEqual(loaded.state.words.count, state.words.count)
        XCTAssertEqual(Set(loaded.state.words.map(\.id)), Set(state.words.map(\.id)))
        XCTAssertEqual(loaded.state.reviews.count, state.reviews.count)
        XCTAssertEqual(loaded.state.session, state.session)
        XCTAssertEqual(loaded.state.settings, state.settings)
        XCTAssertEqual(loaded.state.collections, state.collections)
        for word in state.words {
            XCTAssertEqual(loaded.state.word(id: word.id), word, "Słowo \(word.id) różni się po odczycie")
        }
        // Kolejność: najnowsze najpierw.
        XCTAssertEqual(loaded.state.words.map(\.id), state.words.map(\.id))
    }

    func testFreshRepositorySeesIncrementalChanges() async throws {
        let (repository, container) = try ServicesTestSupport.makeRepository()
        var state = StateMigration.migrate(PreviewData.state())
        try await repository.save(state)

        state.words[0].note = "Zmieniona notatka"
        state.words[0].updatedAt = PreviewData.now + 1
        state.settings.goal = 35
        state.session = nil
        try await repository.save(state)

        let other = LearningRepository(modelContainer: container)
        let loaded = try await other.load(now: PreviewData.now)
        XCTAssertEqual(loaded.state.word(id: state.words[0].id)?.note, "Zmieniona notatka")
        XCTAssertEqual(loaded.state.settings.goal, 35)
        XCTAssertNil(loaded.state.session)
    }

    func testRemovedWordDeletesRecord() async throws {
        let (repository, container) = try ServicesTestSupport.makeRepository()
        let a = ServicesTestSupport.word("a", en: "gate", pl: "bramka")
        let b = ServicesTestSupport.word("b", en: "delay", pl: "opóźnienie")
        try await repository.save(LearnerState(words: [a, b]))
        try await repository.save(LearnerState(words: [a]))

        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<WordRecord>())
        XCTAssertEqual(records.map(\.wordId), ["a"])
    }

    func testDuplicateRecordsAreMergedOnLoad() async throws {
        let (repository, container) = try ServicesTestSupport.makeRepository()
        var local = ServicesTestSupport.word("dup", en: "borrow", pl: "pożyczyć")
        var remote = local
        local.meanings[0].scores = SkillScores([.recognition: Score(interval: 3, due: PreviewData.now, correct: 2, last: PreviewData.now - 1000)])
        remote.meanings[0].scores = SkillScores([.recall: Score(interval: 5, due: PreviewData.now, correct: 3, last: PreviewData.now - 500)])

        // Dwa rekordy z tym samym wordId (jak z dwóch urządzeń przez iCloud).
        let context = ModelContext(container)
        let encoder = JSONEncoder()
        for word in [local, remote] {
            context.insert(WordRecord(
                wordId: word.id, en: word.en, collection: word.collection, archived: false,
                created: word.created, position: 0, updatedAt: word.created,
                payload: try encoder.encode(word)
            ))
        }
        try context.save()

        let loaded = try await repository.load(now: PreviewData.now)
        XCTAssertEqual(loaded.mergedDuplicates, 1)
        XCTAssertEqual(loaded.state.words.count, 1)
        let skills = Set(loaded.state.words.first?.meanings.first?.scores.skills ?? [])
        XCTAssertEqual(skills, [.recognition, .recall], "Postęp z obu urządzeń musi przetrwać scalenie")

        // Nadmiarowy rekord usunięty; po zapisie zostaje jeden, ze scaloną treścią.
        try await repository.save(loaded.state)
        let records = try ModelContext(container).fetch(FetchDescriptor<WordRecord>())
        XCTAssertEqual(records.count, 1)
        let stored = try JSONDecoder().decode(Word.self, from: records[0].payload)
        XCTAssertEqual(Set(stored.meanings[0].scores.skills), [.recognition, .recall])
    }

    func testCorruptedPayloadIsSkippedNotFatal() async throws {
        let (repository, container) = try ServicesTestSupport.makeRepository()
        let good = ServicesTestSupport.word("good", en: "gate", pl: "bramka")
        try await repository.save(LearnerState(words: [good]))

        let context = ModelContext(container)
        context.insert(WordRecord(wordId: "broken", en: "x", collection: "", archived: false, created: 0, position: 0, updatedAt: 0, payload: Data("{not json".utf8)))
        context.insert(ReviewRecord(reviewId: "r-broken", wordId: "x", meaningId: "y", at: 0, payload: Data([0xFF, 0x00])))
        context.insert(SessionRecord(kind: SessionKind.vocabulary.rawValue, updatedAt: 1, payload: Data("[]".utf8)))
        try context.save()

        let fresh = LearningRepository(modelContainer: container)
        let loaded = try await fresh.load(now: PreviewData.now)
        XCTAssertEqual(loaded.state.words.map(\.id), ["good"])
        XCTAssertGreaterThanOrEqual(loaded.skippedRecords, 3)
        XCTAssertNil(loaded.state.session)

        // Nieczytelny rekord słowa nie jest kasowany (może go odczytać nowsza wersja aplikacji).
        try await fresh.save(loaded.state)
        let ids = try ModelContext(container).fetch(FetchDescriptor<WordRecord>()).map(\.wordId)
        XCTAssertTrue(ids.contains("broken"))
    }

    func testOldReviewsAreCompactedAndRecordsRemoved() async throws {
        let (repository, container) = try ServicesTestSupport.makeRepository()
        let word = ServicesTestSupport.word("w", en: "gate", pl: "bramka")
        let old = Review(id: "old", wordId: "w", meaningId: "w.m1", skill: .recall, correct: true,
                         at: PreviewData.now - 120 * TimeConstants.dayMs, seconds: 3, confidence: 3, hint: false, before: 0, after: 10)
        let recent = Review(id: "recent", wordId: "w", meaningId: "w.m1", skill: .recall, correct: false,
                            at: PreviewData.now - TimeConstants.dayMs, seconds: 3, confidence: 1, hint: false, before: 10, after: 5)
        try await repository.save(LearnerState(words: [word], reviews: [old, recent]))

        let loaded = try await repository.load(now: PreviewData.now)
        XCTAssertEqual(loaded.state.reviews.map(\.id), ["recent"])
        XCTAssertEqual(loaded.state.reviewSummaries.reduce(0) { $0 + $1.count }, 1)

        try await repository.save(loaded.state)
        let reviewIDs = try ModelContext(container).fetch(FetchDescriptor<ReviewRecord>()).map(\.reviewId)
        XCTAssertEqual(reviewIDs, ["recent"])
        let summaries = try ModelContext(container).fetch(FetchDescriptor<HistoryRecord>()).filter { $0.kind == HistoryKind.summary.rawValue }
        XCTAssertEqual(summaries.count, 1)
    }

    func testHistoriesAndGrammarSeenRoundTrip() async throws {
        let (repository, container) = try ServicesTestSupport.makeRepository()
        var state = LearnerState()
        state.readingHistory = [ReadingHistoryEntry(id: "r1", at: 10, level: "B1", correct: 3, total: 4, title: "Delay")]
        state.practiceHistory = [PracticeHistoryEntry(id: "p1", at: 20, kind: .grammar, level: "A2", correct: 5, total: 6, title: "Gramatyka")]
        state.productionHistory = [ProductionHistoryEntry(id: "x1", at: 30, level: "B1", correct: 2, total: 4, title: "Produkcja")]
        state.grammarSeen = ["task-1": 100, "task-2": 200]
        state.collections = ["Lotnisko", "Restauracja"]
        try await repository.save(state)

        let loaded = try await LearningRepository(modelContainer: container).load(now: PreviewData.now)
        XCTAssertEqual(loaded.state.readingHistory, state.readingHistory)
        XCTAssertEqual(loaded.state.practiceHistory, state.practiceHistory)
        XCTAssertEqual(loaded.state.productionHistory, state.productionHistory)
        XCTAssertEqual(loaded.state.grammarSeen, state.grammarSeen)
        XCTAssertEqual(loaded.state.collections, state.collections)
    }

    func testDeleteAllRemovesEverything() async throws {
        let (repository, container) = try ServicesTestSupport.makeRepository()
        try await repository.save(StateMigration.migrate(PreviewData.state()))
        try await repository.deleteAll()

        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WordRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ReviewRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SessionRecord>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SettingsRecord>()), 0)
        let loaded = try await repository.load(now: PreviewData.now)
        XCTAssertTrue(loaded.state.words.isEmpty)

        // Po usunięciu zapis działa od zera (cache wyczyszczony).
        try await repository.save(LearnerState(words: [ServicesTestSupport.word("n", en: "tip", pl: "napiwek")]))
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<WordRecord>()), 1)
    }

    func testRemoteReloadReportsRemovedWords() async throws {
        let container = try PersistenceController.makeInMemoryContainer()
        let persistence = SwiftDataPersistence(container: container)
        let a = ServicesTestSupport.word("a", en: "gate", pl: "bramka")
        let b = ServicesTestSupport.word("b", en: "tip", pl: "napiwek")
        _ = try await persistence.load(now: PreviewData.now)
        try await persistence.save(LearnerState(words: [a, b]))

        // „Inne urządzenie” usuwa słowo b.
        let context = ModelContext(container)
        for record in try context.fetch(FetchDescriptor<WordRecord>()) where record.wordId == "b" {
            context.delete(record)
        }
        try context.save()

        let result = try await persistence.reloadAfterRemoteChange(now: PreviewData.now)
        XCTAssertEqual(result.removedWordIDs, ["b"])
        XCTAssertEqual(result.state.words.map(\.id), ["a"])
    }
}
