import XCTest
import FluentKit
@testable import FluentNOW

/// `LearningStore`: zapis (natychmiastowy i z opóźnieniem), błędy zapisu, wczytanie,
/// import strony, eksport → import, CSV, usuwanie danych, odczyty pomocnicze.
@MainActor
final class LearningStoreTests: XCTestCase {

    func testAnswerIsSavedImmediately() async throws {
        let persistence = InMemoryPersistence()
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state(), persistence: persistence)
        let before = store.revision
        let wordID = try XCTUnwrap(store.activeWords.first?.id)
        store.update(.answer) { state in
            state.words[0].note = "po odpowiedzi"
        }
        XCTAssertEqual(store.revision, before + 1)
        await store.flush()
        let stored = await persistence.storedState()
        XCTAssertEqual(stored.word(id: wordID)?.note, "po odpowiedzi")
        XCTAssertFalse(store.hasUnsavedChanges)
    }

    func testEditsAreDebouncedAndCoalesced() async throws {
        let persistence = InMemoryPersistence()
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state(), persistence: persistence)
        for goal in 21...25 {
            store.update { $0.settings.goal = goal }
        }
        try await Task.sleep(nanoseconds: 600_000_000)
        let saves = await persistence.saveCount
        XCTAssertEqual(saves, 1, "Pięć szybkich edycji = jeden zapis")
        let stored = await persistence.storedState()
        XCTAssertEqual(stored.settings.goal, 25)
    }

    func testUpdateReturnsBodyResult() {
        let store = ServicesTestSupport.makeStore(initial: LearnerState())
        let count = store.update(.bulk) { (state: inout LearnerState) -> Int in
            state.words.append(ServicesTestSupport.word("x", en: "gate", pl: "bramka"))
            return state.words.count
        }
        XCTAssertEqual(count, 1)
        XCTAssertEqual(store.word(id: "x")?.en, "gate")
    }

    func testSaveFailureIsReportedAndRetried() async {
        let persistence = InMemoryPersistence()
        await persistence.setFailSaves(true)
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state(), persistence: persistence)
        store.update(.answer) { $0.settings.goal = 30 }
        await store.flush()
        XCTAssertNotNil(store.lastSaveError)
        XCTAssertTrue(store.hasUnsavedChanges)

        await persistence.setFailSaves(false)
        await store.retryFailedSave()
        XCTAssertNil(store.lastSaveError)
        let stored = await persistence.storedState()
        XCTAssertEqual(stored.settings.goal, 30)
    }

    func testLoadMigratesAndBecomesReady() async {
        let persistence = InMemoryPersistence(initial: PreviewData.state())
        let store = ServicesTestSupport.makeStore(persistence: persistence)
        XCTAssertEqual(store.loadPhase, .loading)
        await store.load()
        XCTAssertEqual(store.loadPhase, .ready)
        XCTAssertEqual(store.state.words.count, PreviewData.makeWords().count)
        XCTAssertNotNil(store.state.session, "Przerwana sesja musi przetrwać wczytanie")
    }

    func testChangeDuringLoadIsMergedNotLost() async {
        let persistence = InMemoryPersistence(initial: LearnerState(words: [ServicesTestSupport.word("disk", en: "tip", pl: "napiwek")]))
        let store = ServicesTestSupport.makeStore(persistence: persistence)
        store.update(.edit) { state in
            state.words.append(ServicesTestSupport.word("early", en: "gate", pl: "bramka"))
        }
        await store.load()
        XCTAssertNotNil(store.word(id: "disk"))
        XCTAssertNotNil(store.word(id: "early"))
        await store.flush()
        let stored = await persistence.storedState()
        XCTAssertNotNil(stored.word(id: "early"))
    }

    func testActiveWordsExcludeArchivedAndKeepOrder() {
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state())
        let active = store.activeWords
        XCTAssertFalse(active.contains { $0.archived })
        XCTAssertEqual(active.count, store.state.words.count - 1)
        XCTAssertEqual(active.map(\.id), store.state.words.filter { !$0.archived }.map(\.id))
        XCTAssertEqual(store.now(), PreviewData.now)
    }

    func testImportWebFixtureMergeAndReplace() throws {
        let data = try ServicesTestSupport.webFixtureData()
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state())
        let preview = try store.previewImportJSON(data)
        XCTAssertEqual(preview.newWords + preview.mergedWords, 18)
        XCTAssertEqual(store.state.words.count, PreviewData.makeWords().count, "Podgląd nie zmienia danych")

        let merged = try store.importJSON(data, mode: .merge)
        XCTAssertEqual(merged.newWords, preview.newWords)
        XCTAssertEqual(store.state.words.count, PreviewData.makeWords().count + merged.newWords)

        let replaced = try store.importJSON(data, mode: .replace)
        XCTAssertEqual(replaced.newWords, 18)
        XCTAssertEqual(store.state.words.count, 18)
    }

    func testInvalidJSONThrowsReadableError() {
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state())
        XCTAssertThrowsError(try store.importJSON(Data("nie json".utf8), mode: .merge)) { error in
            XCTAssertFalse(LearningStore.message(for: error).isEmpty)
        }
        XCTAssertEqual(store.state.words.count, PreviewData.makeWords().count)
    }

    func testExportImportRoundTrip() throws {
        let source = ServicesTestSupport.makeStore(initial: PreviewData.state())
        let url = try source.exportJSONFile()
        XCTAssertEqual(url.pathExtension, "json")
        let data = try Data(contentsOf: url)

        let target = ServicesTestSupport.makeStore(initial: LearnerState())
        _ = try target.importJSON(data, mode: .replace)
        XCTAssertEqual(target.state.words, source.state.words)
        XCTAssertEqual(target.state.reviews.count, source.state.reviews.count)
        XCTAssertEqual(target.state.settings, source.state.settings)

        let csv = try source.exportAnkiCSVFile()
        XCTAssertEqual(csv.pathExtension, "csv")
        XCTAssertFalse(try String(contentsOf: csv, encoding: .utf8).isEmpty)
    }

    func testBackgroundExportMatchesSyncExport() async throws {
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state())
        let background = try await store.exportJSONFileInBackground()
        let backgroundData = try Data(contentsOf: background)
        let sync = try store.exportJSONFile()
        XCTAssertEqual(try Data(contentsOf: sync), backgroundData)
        let csv = try await store.exportAnkiCSVFileInBackground()
        XCTAssertEqual(csv.pathExtension, "csv")
    }

    func testDelimitedImportPreviewAndCommit() throws {
        let store = ServicesTestSupport.makeStore(initial: LearnerState())
        let text = "english,polish\ngate,bramka\ntip,napiwek\n"
        let preview = try store.previewImportDelimited(text)
        XCTAssertEqual(preview.newWords, 2)
        XCTAssertTrue(store.state.words.isEmpty)

        let summary = try store.importDelimited(text)
        XCTAssertEqual(summary.newWords, 2)
        XCTAssertEqual(store.state.words.count, 2)

        let again = try store.previewImportDelimited(text)
        XCTAssertEqual(again.newWords, 0)
        XCTAssertEqual(again.skipped, 2, "Słowa, które już są, są pomijane")
    }

    func testDeleteAllDataClearsStateAndRunsHook() async throws {
        let persistence = InMemoryPersistence(initial: PreviewData.state())
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state(), persistence: persistence)
        var hookCalled = false
        store.onDeleteAll = { hookCalled = true }
        try await store.deleteAllData()
        XCTAssertTrue(store.state.words.isEmpty)
        XCTAssertTrue(hookCalled)
        let stored = await persistence.storedState()
        XCTAssertTrue(stored.words.isEmpty)
    }

    func testComputeRunsOnSnapshot() async {
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state())
        let now = store.now()
        let overview = await store.compute { state in
            ProgressStatistics.overview(state, now: now)
        }
        XCTAssertEqual(overview.wordCount, store.state.words.filter { !$0.archived }.count)
        XCTAssertGreaterThan(overview.totalAnswers, 0)
    }

    func testRemoteReloadMergesWithoutLosingSession() async {
        let persistence = InMemoryPersistence(initial: PreviewData.state())
        let store = ServicesTestSupport.makeStore(persistence: persistence)
        await store.load()
        let session = store.state.session
        XCTAssertNotNil(session)
        await store.reloadRemoteChanges()
        XCTAssertEqual(store.state.session, session)
        XCTAssertEqual(store.loadPhase, .ready)
    }
}
