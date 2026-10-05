import XCTest
import FluentKit
@testable import FluentNOW

/// Logika serwisów bez usług systemowych: mowa, wymowa, przypomnienia, AI, uprawnienia, pliki.
final class ServiceLogicTests: XCTestCase {

    // MARK: Mowa

    func testSpeechSegmentsSplitOnGaps() {
        XCTAssertEqual(SpeechService.segments(for: "I need to [[gap]] some money."), ["I need to", "some money."])
        XCTAssertEqual(SpeechService.segments(for: "Please ________ your seatbelt."), ["Please", "your seatbelt."])
        XCTAssertEqual(SpeechService.segments(for: "snake_case stays"), ["snake_case stays"])
        XCTAssertEqual(SpeechService.segments(for: "[[gap]]"), [])
        XCTAssertEqual(SpeechService.segments(for: "  Hello there.  "), ["Hello there."])
    }

    // MARK: Wymowa

    func testPronunciationEvaluation() {
        let perfect = PronunciationService.evaluate(transcript: "Boarding pass.", expected: "boarding pass")
        XCTAssertEqual(perfect.similarity, 1, accuracy: 0.0001)
        XCTAssertTrue(perfect.verdictPl.hasPrefix("Świetnie"))

        let close = PronunciationService.evaluate(transcript: "boarding past", expected: "boarding pass")
        XCTAssertGreaterThanOrEqual(close.similarity, 0.7)
        XCTAssertLessThan(close.similarity, 1)

        let wrong = PronunciationService.evaluate(transcript: "hello", expected: "boarding pass")
        XCTAssertLessThan(wrong.similarity, 0.7)
        XCTAssertTrue(wrong.verdictPl.contains("hello"))

        let silent = PronunciationService.evaluate(transcript: "", expected: "gate")
        XCTAssertEqual(silent.similarity, 0)
        XCTAssertTrue(silent.verdictPl.contains("Nic nie usłyszałem"))
    }

    func testPronunciationComparableNormalization() {
        XCTAssertEqual(PronunciationService.comparable("  I'd LIKE, the check!  "), "i'd like the check")
    }

    // MARK: Przypomnienia

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    func testReminderPlanSkipsTodayWhenGoalReachedOrTimePassed() {
        let morning = Date(timeIntervalSince1970: 1_791_194_400) // 2026-10-05 10:00 UTC
        let planToday = ReminderService.plan(now: morning, hour: 19, minute: 0, goalReachedToday: false, days: 3, calendar: utcCalendar)
        XCTAssertEqual(planToday.count, 3)
        XCTAssertEqual(planToday.first?.day, 5)
        XCTAssertEqual(planToday.first?.hour, 19)

        let goalDone = ReminderService.plan(now: morning, hour: 19, minute: 0, goalReachedToday: true, days: 3, calendar: utcCalendar)
        XCTAssertEqual(goalDone.first?.day, 6)

        let evening = morning.addingTimeInterval(10 * 3600) // 20:00
        let late = ReminderService.plan(now: evening, hour: 19, minute: 0, goalReachedToday: false, days: 2, calendar: utcCalendar)
        XCTAssertEqual(late.map(\.day), [6, 7])

        XCTAssertTrue(ReminderService.plan(now: morning, hour: 19, minute: 0, goalReachedToday: false, days: 0).isEmpty)
    }

    func testReminderTextUsesPolishPlurals() {
        XCTAssertEqual(ReminderService.wordsForm(1), "słówko")
        XCTAssertEqual(ReminderService.wordsForm(3), "słówka")
        XCTAssertEqual(ReminderService.wordsForm(5), "słówek")
        XCTAssertEqual(ReminderService.wordsForm(12), "słówek")
        XCTAssertEqual(ReminderService.wordsForm(22), "słówka")
        XCTAssertTrue(ReminderService.body(dueCount: 7).contains("7 słówek"))
        XCTAssertFalse(ReminderService.body(dueCount: 0).contains("0"))
        XCTAssertFalse(ReminderService.body(dueCount: nil).isEmpty)
    }

    // MARK: Gemini

    func testGeminiModelOrderingMatchesWeb() {
        let available = [
            "gemini-2.5-flash", "gemini-3.8-flash", "gemini-3.8-flash-lite", "gemini-3.9-flash-preview",
            "gemini-3.8-flash-tts", "gemini-3.8-pro", "embedding-001", "gemini-3.8-flash-image"
        ]
        XCTAssertEqual(
            GeminiAssistant.compatibleModels(available),
            ["gemini-3.9-flash-preview", "gemini-3.8-flash", "gemini-3.8-flash-lite", "gemini-2.5-flash"]
        )
    }

    func testGeminiKeyPlausibility() {
        XCTAssertFalse(GeminiAssistant.isPlausibleKey("short"))
        XCTAssertFalse(GeminiAssistant.isPlausibleKey("AIza key with spaces inside"))
        XCTAssertTrue(GeminiAssistant.isPlausibleKey("  AIzaSyA1234567890abcdefghij  "))
    }

    func testGeminiPreferredModelGoesFirst() {
        let gemini = GeminiAssistant(apiKey: "AIzaSyA1234567890abcdefghij", preferredModel: "gemini-2.5-flash")
        XCTAssertEqual(gemini.models.first, "gemini-2.5-flash")
        XCTAssertEqual(Set(gemini.models), Set(GeminiAssistant.defaultModels))
    }

    // MARK: Walidacja AI

    func testLookupValidationDropsBrokenSensesAndExamples() throws {
        let good = SenseSuggestion(
            translation: " karta pokładowa (AmE) ",
            level: "a2",
            examples: [
                ExamplePair(en: "Show your boarding pass.", pl: "Pokaż kartę pokładową.", focusEn: "boarding pass", focusPl: "kartę pokładową"),
                ExamplePair(en: "Show your boarding pass.", pl: "Pokaż kartę.", focusEn: "boarding pass", focusPl: "kartę pokładową")
            ],
            acceptedAnswers: []
        )
        let empty = SenseSuggestion(translation: "   ")
        let lookup = Lookup(term: "boarding pass", meanings: [good, empty], source: .starter)
        let clean = try AssistantValidation.sanitize(lookup, term: "boarding pass")
        XCTAssertEqual(clean.source, .ai)
        XCTAssertEqual(clean.meanings.count, 1)
        XCTAssertEqual(clean.meanings[0].level, "A2")
        XCTAssertEqual(clean.meanings[0].examples.count, 1, "Przykład z fragmentem spoza zdania jest odrzucany")
        XCTAssertEqual(clean.meanings[0].acceptedAnswers.first, "boarding pass")
        XCTAssertFalse(clean.meanings[0].translation.contains("AmE"))
    }

    func testLookupValidationRejectsNonexistentWord() {
        let lookup = Lookup(exists: false, term: "boardng", alternatives: ["boarding"], meanings: [])
        XCTAssertThrowsError(try AssistantValidation.sanitize(lookup, term: "boardng")) { error in
            let message = (error as? LocalizedError)?.errorDescription ?? ""
            XCTAssertTrue(message.contains("boarding"))
        }
    }

    func testGradeValidationNeverFailsUncertain() {
        let uncertain = AssistantValidation.grade(verdict: "Uncertain", explanation: "Kontekst niejasny.", spellingCorrect: true)
        XCTAssertEqual(uncertain?.verdict, .uncertain)
        XCTAssertEqual(uncertain?.source, .ai)
        XCTAssertEqual(uncertain?.isFailure, false)
        XCTAssertNil(AssistantValidation.grade(verdict: "maybe", explanation: "", spellingCorrect: true))
    }

    func testTimeoutHelper() async {
        do {
            _ = try await AssistantService.withTimeout(0.05) { () -> Int in
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return 1
            }
            XCTFail("Oczekiwano przekroczenia czasu")
        } catch {
            XCTAssertEqual(error as? AssistantError, .timeout)
        }
        let value = try? await AssistantService.withTimeout(1) { () -> Int in 42 }
        XCTAssertEqual(value, 42)
    }

    @MainActor
    func testOfflineProviderIsDefaultAndGradeReturnsNil() async {
        let environment = AppEnvironment.makePreview(state: PreviewData.state())
        XCTAssertEqual(environment.assistant.activeProvider, .offline)
        environment.preferences.assistantProvider = .gemini
        XCTAssertEqual(environment.assistant.activeProvider, .offline, "Bez klucza Gemini zostaje tryb offline")
        let word = PreviewData.makeWords()[0]
        let grade = await environment.assistant.grade(answer: "x", word: word, meaning: word.meanings[0], exerciseType: .recall, context: "")
        XCTAssertNil(grade)
    }

    // MARK: Uprawnienia CloudKit

    func testEntitlementParsing() {
        XCTAssertTrue(CloudKitAvailability.containsCloudKit(["com.apple.developer.icloud-services": ["CloudKit"]]))
        XCTAssertTrue(CloudKitAvailability.containsCloudKit(["com.apple.developer.icloud-services": "*"]))
        XCTAssertFalse(CloudKitAvailability.containsCloudKit(["com.apple.developer.icloud-services": ["CloudDocuments"]]))
        XCTAssertFalse(CloudKitAvailability.containsCloudKit([:]))

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>Entitlements</key><dict>
        <key>com.apple.developer.icloud-services</key><array><string>CloudKit</string></array>
        </dict></dict></plist>
        """
        var data = Data([0x30, 0x82, 0x01, 0x02])   // „nagłówek CMS”
        data.append(Data(plist.utf8))
        data.append(Data([0x00, 0xA0]))
        let parsed = CloudKitAvailability.provisioningPlist(from: data)
        let entitlements = parsed?["Entitlements"] as? [String: Any]
        XCTAssertNotNil(entitlements)
        XCTAssertTrue(CloudKitAvailability.containsCloudKit(entitlements ?? [:]))
    }

    // MARK: Pliki, zgłoszenia, preferencje

    func testExportWriterReplacesPreviousExport() throws {
        let first = try ExportFileWriter.write(Data("a".utf8), baseName: "FluentNOW-test", fileExtension: "json", date: Date(timeIntervalSince1970: 0))
        let second = try ExportFileWriter.write(Data("b".utf8), baseName: "FluentNOW-test", fileExtension: "json", date: Date(timeIntervalSince1970: 3600))
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        XCTAssertEqual(try Data(contentsOf: second), Data("b".utf8))
        try? FileManager.default.removeItem(at: second)
    }

    @MainActor
    func testReportStorePersistsAndExports() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("reports-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = ExerciseReportStore(fileURL: url)
        store.add(ExerciseReport(mode: "Przypominanie", question: "q", answer: "a", expected: ["b"]))
        XCTAssertEqual(store.reports.count, 1)
        let exported = try store.exportFile()
        let decoded = try JSONDecoder().decode([ExerciseReport].self, from: Data(contentsOf: exported))
        XCTAssertEqual(decoded, store.reports)
        store.removeAll()
        XCTAssertTrue(store.reports.isEmpty)
    }

    @MainActor
    func testPreferencesPersistInUserDefaults() throws {
        let suite = "fluent.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = AppPreferences(defaults: defaults)
        XCTAssertEqual(preferences.appearance, .system)
        XCTAssertTrue(preferences.hapticsEnabled)
        preferences.appearance = .dark
        preferences.assistantProvider = .appleOnDevice
        preferences.remindersEnabled = true

        let reloaded = AppPreferences(defaults: defaults)
        XCTAssertEqual(reloaded.appearance, .dark)
        XCTAssertEqual(reloaded.assistantProvider, .appleOnDevice)
        XCTAssertTrue(reloaded.remindersEnabled)
        reloaded.resetToDefaults()
        XCTAssertEqual(AppPreferences(defaults: defaults).appearance, .system)
    }

    // MARK: Dane podglądu

    @MainActor
    func testPreviewEnvironmentIsConsistent() {
        let environment = AppEnvironment.preview
        let store = environment.store
        XCTAssertEqual(store.loadPhase, .ready)
        XCTAssertEqual(store.state.words.count, 30)
        XCTAssertNotNil(store.state.session, "Przerwana sesja musi przetrwać migrację")
        XCTAssertEqual(store.state.session?.index, 2)
        let days = Set(store.state.reviews.map { StateSync.utcDay($0.at) })
        XCTAssertEqual(days.count, 13, "14 dni z jedną przerwą")
        for word in store.state.words {
            for meaning in word.meanings {
                for (index, example) in meaning.examples.enumerated() {
                    let focusEn = meaning.exampleFocusEn?[index] ?? word.en
                    let pl = meaning.exampleTranslations?[index] ?? ""
                    let focusPl = meaning.exampleFocusPl?[index] ?? ""
                    XCTAssertTrue(example.contains(focusEn), "\(word.en): \(focusEn)")
                    XCTAssertTrue(pl.contains(focusPl), "\(word.en): \(focusPl)")
                }
            }
        }
        XCTAssertEqual(AppEnvironment.previewEmpty.store.state.words.count, 0)
    }
}
