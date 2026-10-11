import XCTest
import SwiftUI
import FluentKit
@testable import FluentNOW

/// Testy regresji poprawek code-qa (instancja A) w serwisach, powłoce i design systemie.
@MainActor
final class CodeQAServiceTests: XCTestCase {

    // MARK: Zmiana przed zakończeniem wczytywania nie nadpisuje ustawień ani sesji

    func testEditBeforeLoadKeepsStoredSettingsAndPausedSession() async {
        var stored = PreviewData.state()
        stored.settings.goal = 42
        stored.settings.reminder = "07:15"
        let persistence = InMemoryPersistence(initial: stored)
        let store = ServicesTestSupport.makeStore(persistence: persistence)
        store.update(.edit) { state in
            state.words.append(ServicesTestSupport.word("early", en: "gate", pl: "bramka"))
        }
        await store.load()
        XCTAssertEqual(store.settings.goal, 42, "domyślne ustawienia stanu startowego nie mogą nadpisać zapisanych")
        XCTAssertEqual(store.settings.reminder, "07:15")
        XCTAssertNotNil(store.state.session, "przerwana sesja z dysku musi przetrwać")
        XCTAssertNotNil(store.word(id: "early"), "zmiana sprzed wczytania nie ginie")
        await store.flush()
        let saved = await persistence.storedState()
        XCTAssertEqual(saved.settings.goal, 42)
        XCTAssertNotNil(saved.session)
    }

    func testMergePreloadChangesPrefersLoadedDefaults() {
        var loaded = PreviewData.state()
        loaded.settings.goal = 42
        let preload = LearnerState(words: [ServicesTestSupport.word("early", en: "gate", pl: "bramka")])
        let merged = LearningStore.mergePreloadChanges(preload: preload, loaded: loaded)
        XCTAssertEqual(merged.settings.goal, 42)
        XCTAssertEqual(merged.session, StateMigration.migrate(loaded).session)
        XCTAssertNotNil(merged.word(id: "early"))
        XCTAssertEqual(merged.words.count, loaded.words.count + 1)
    }

    // MARK: Ustawienia zmienione na innym urządzeniu nie są cofane przy scaleniu z iCloud

    func testRemoteSettingsChangeIsAdoptedWhenUnchangedLocally() async throws {
        let persistence = InMemoryPersistence(initial: PreviewData.state())
        let store = ServicesTestSupport.makeStore(persistence: persistence)
        await store.load()
        await store.flush()

        // „Inne urządzenie” zmienia cel dzienny (zapis trafił na dysk przez iCloud).
        var remote = await persistence.storedState()
        remote.settings.goal = 55
        try await persistence.save(remote)

        await store.reloadRemoteChanges()
        XCTAssertEqual(store.settings.goal, 55)
        await store.flush()
        let saved = await persistence.storedState()
        XCTAssertEqual(saved.settings.goal, 55, "scalenie nie może zapisać z powrotem starych ustawień")
    }

    func testLocalSettingsChangeSurvivesRemoteReload() async {
        let persistence = InMemoryPersistence(initial: PreviewData.state())
        let store = ServicesTestSupport.makeStore(persistence: persistence)
        await store.load()
        await store.flush()
        store.update(.edit) { $0.settings.goal = 33 }
        await store.reloadRemoteChanges()
        XCTAssertEqual(store.settings.goal, 33)
    }

    // MARK: Import JSON poza głównym wątkiem

    func testBackgroundJSONImportMatchesSynchronousImport() async throws {
        let data = try ServicesTestSupport.webFixtureData()
        let reference = ServicesTestSupport.makeStore(initial: PreviewData.state())
        let store = ServicesTestSupport.makeStore(initial: PreviewData.state())
        let preview = try await store.previewImportJSONInBackground(data)
        XCTAssertEqual(preview, try reference.previewImportJSON(data))
        XCTAssertEqual(store.state, reference.state, "podgląd niczego nie zmienia")
        let summary = try await store.importJSONInBackground(data, mode: .merge)
        XCTAssertEqual(summary, try reference.importJSON(data, mode: .merge))
        XCTAssertEqual(store.state, reference.state)
        do {
            _ = try await store.importJSONInBackground(Data("nie json".utf8), mode: .replace)
            XCTFail("Oczekiwano błędu")
        } catch {
            XCTAssertEqual(error as? ImportError, .notJSON)
        }
    }

    // MARK: Router — trasy na ścieżce karty

    func testRouterPushAndPopUseTabPath() {
        let router = AppRouter()
        router.push("a", on: .settings)
        router.push("b", on: .settings)
        XCTAssertEqual(router.settingsPath.count, 2)
        XCTAssertEqual(router.path(for: .settings).count, 2)
        router.pop(on: .settings)
        XCTAssertEqual(router.settingsPath.count, 1)
        XCTAssertTrue(router.todayPath.isEmpty)
    }

    // MARK: Haptyka — globalny przełącznik

    func testHapticsEnvironmentDefaultsToEnabled() {
        var values = EnvironmentValues()
        XCTAssertTrue(values.fluentHapticsEnabled)
        values.fluentHapticsEnabled = false
        XCTAssertFalse(values.fluentHapticsEnabled)
    }

    // MARK: Walidacja AI

    func testAssistantValidationKeepsOnlyValidExamples() {
        let sense = SenseSuggestion(
            translation: "bramka",
            examples: [
                ExamplePair(en: "Go to gate 12.", pl: "Idź do bramki 12.", focusEn: "gate", focusPl: "bramki"),
                ExamplePair(en: "Go to gate 12.", pl: "Idź do bramki 12.", focusEn: "door", focusPl: "bramki")
            ]
        )
        let clean = AssistantValidation.sanitize(sense, term: "gate")
        XCTAssertEqual(clean?.examples.count, 1)
        XCTAssertEqual(clean?.examples.first?.focusEn, "gate")
    }
}
