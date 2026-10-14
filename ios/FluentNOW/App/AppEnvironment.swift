import SwiftUI
import Observation
import UIKit
import FluentKit

/// Składa wszystkie serwisy aplikacji i wstrzykuje je do środowiska SwiftUI.
///
/// - `live()` — SwiftData + CloudKit (z automatycznym fallbackiem do magazynu lokalnego),
/// - `preview` — dane w pamięci (`PreviewData`), bez CloudKit, sieci, mikrofonu i powiadomień.
///
/// Odczyt w widokach: `@Environment(LearningStore.self)`, `@Environment(AppEnvironment.self) var env` → `env.content`.
/// Podglądy: `#Preview { X().fluentPreviewEnvironment() }`.
@MainActor
@Observable
final class AppEnvironment {
    let store: LearningStore
    let content: ContentLibrary
    let speech: SpeechService
    let pronunciation: PronunciationService
    let reminders: ReminderService
    let assistant: AssistantService
    let preferences: AppPreferences
    let reports: ExerciseReportStore

    /// Tryb podglądu (bez usług systemowych).
    let isPreview: Bool

    @ObservationIgnored private var didAppear = false
    @ObservationIgnored private var lastRemoteRefresh: Date = .distantPast

    /// Minimalny odstęp między ponownym wczytaniem zmian z iCloud po powrocie do aplikacji.
    static let remoteRefreshInterval: TimeInterval = 60

    init(
        store: LearningStore,
        content: ContentLibrary,
        speech: SpeechService,
        pronunciation: PronunciationService,
        reminders: ReminderService,
        assistant: AssistantService,
        preferences: AppPreferences,
        reports: ExerciseReportStore,
        isPreview: Bool
    ) {
        self.store = store
        self.content = content
        self.speech = speech
        self.pronunciation = pronunciation
        self.reminders = reminders
        self.assistant = assistant
        self.preferences = preferences
        self.reports = reports
        self.isPreview = isPreview
        wireDeleteAll()
    }

    // MARK: - Fabryki

    /// Środowisko aplikacji: SwiftData + CloudKit z fallbackiem do lokalnego magazynu.
    /// Tworzy kontener danych raz; stan wczytuje się w tle w `onAppear()`.
    static func live() -> AppEnvironment {
        let setup = PersistenceController.makeLive()
        let syncMonitor = SyncMonitor(mode: setup.syncMode)
        let store = LearningStore(persistence: setup.persistence, syncMonitor: syncMonitor)
        let preferences = AppPreferences()
        // Tematy wygenerowane przez AI i zapamiętane zapytania — Application Support (F1).
        let localTopics = LocalTopicStore.defaultDirectory().map { LocalTopicStore(directory: $0) }
        let content = ContentLibrary(localTopics: localTopics)
        let speech = SpeechService(settingsProvider: { [weak store] in
            store?.settings ?? LearnerSettings()
        })
        let environment = AppEnvironment(
            store: store,
            content: content,
            speech: speech,
            pronunciation: PronunciationService(),
            reminders: ReminderService(),
            assistant: AssistantService(preferences: preferences, content: content),
            preferences: preferences,
            reports: ExerciseReportStore(fileURL: ExerciseReportStore.defaultFileURL()),
            isPreview: false
        )
        if let notice = setup.notice {
            store.setStartupNotice(notice, backupURL: setup.backupURL)
        }
        return environment
    }

    /// Podgląd: ok. 30 słów z pięciu tematów, historia z 14 dni, przerwana sesja; bez CloudKit/sieci.
    static let preview: AppEnvironment = makePreview(state: PreviewData.state())

    /// Podgląd pustej aplikacji (nowy użytkownik).
    static let previewEmpty: AppEnvironment = makePreview(state: PreviewData.emptyState())

    /// Podgląd z dowolnym stanem (np. w testach UI lub konkretnych przypadkach brzegowych).
    static func makePreview(state: LearnerState) -> AppEnvironment {
        let syncMonitor = SyncMonitor(mode: .fixed(.synced(Date(timestamp: PreviewData.now - 3 * 60_000))))
        let store = LearningStore(
            persistence: InMemoryPersistence(initial: state),
            syncMonitor: syncMonitor,
            initialState: state,
            fixedNow: PreviewData.now
        )
        let preferences = AppPreferences(defaults: nil)
        preferences.hasCompletedOnboarding = !state.words.isEmpty
        let content = ContentLibrary()
        let speech = SpeechService(settingsProvider: { [weak store] in
            store?.settings ?? LearnerSettings()
        }, audioEnabled: false)
        return AppEnvironment(
            store: store,
            content: content,
            speech: speech,
            pronunciation: PronunciationService(enabled: false),
            reminders: ReminderService(enabled: false),
            assistant: AssistantService(preferences: preferences, content: content, keychain: nil, defaults: nil, networkEnabled: false),
            preferences: preferences,
            reports: ExerciseReportStore(fileURL: nil, initial: PreviewData.reports),
            isPreview: true
        )
    }

    // MARK: - Cykl życia

    /// Wczytanie stanu i rozgrzanie treści — wołane raz z `FluentNOWApp` (`.task`).
    func onAppear() async {
        guard !didAppear else { return }
        didAppear = true
        let sync = store.syncMonitor
        sync.onRemoteImport = { [weak self] in
            self?.scheduleRemoteReload()
        }
        sync.start()
        await store.load()
        lastRemoteRefresh = Date()
        // Treść w tle — po pierwszej klatce UI (`.task` startuje po pojawieniu się widoku).
        let content = content
        Task.detached(priority: .utility) {
            await content.warmUp()
        }
        guard !isPreview else { return }
        await sync.refresh()
        await reminders.refreshAuthorization()
        assistant.refreshAvailability()
    }

    /// Reakcja na zmianę fazy sceny: zapis przy przejściu w tło, odświeżenie przypomnień i iCloud.
    func onScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            saveInBackground()
        case .inactive:
            Task { await store.flush() }
        case .active:
            guard didAppear, !isPreview else { return }
            Task {
                await store.syncMonitor.refresh()
                await reminders.refreshAuthorization()
            }
            assistant.refreshAvailability()
            if Date().timeIntervalSince(lastRemoteRefresh) > Self.remoteRefreshInterval {
                scheduleRemoteReload()
            }
        @unknown default:
            break
        }
    }

    /// Przelicza i planuje przypomnienia (liczba wymagalnych powtórek, czy dziś cel osiągnięty).
    func refreshReminders() async {
        guard store.loadPhase == .ready else { return }
        let now = store.now()
        let summary = await store.compute { state -> ReminderSnapshot in
            let overview = ProgressStatistics.overview(state, now: now)
            let goal = ProgressStatistics.dailyGoal(state, now: now)
            return ReminderSnapshot(dueCount: overview.dueMeanings, goalReached: goal.isReached)
        }
        await reminders.reschedule(
            settings: store.settings,
            enabled: preferences.remindersEnabled,
            dueCount: summary.dueCount,
            goalReachedToday: summary.goalReached
        )
    }

    // MARK: - Implementacja

    private func scheduleRemoteReload() {
        guard !isPreview, store.syncMonitor.usesCloudKit else { return }
        lastRemoteRefresh = Date()
        Task { await store.reloadRemoteChanges() }
    }

    /// Zapis zmian i odświeżenie przypomnień z czasem od systemu na dokończenie pracy w tle.
    private func saveInBackground() {
        guard !isPreview else {
            Task { await store.flush() }
            return
        }
        let box = BackgroundTaskBox()
        box.id = UIApplication.shared.beginBackgroundTask(withName: "FluentNOW.save") {
            box.end()
        }
        Task {
            await store.flush()
            await refreshReminders()
            box.end()
        }
    }

    /// „Usuń wszystkie dane”: po usunięciu stanu czyścimy zgłoszenia, klucz AI, preferencje i przypomnienia.
    private func wireDeleteAll() {
        let reports = reports
        let assistant = assistant
        let preferences = preferences
        let reminders = reminders
        let content = content
        store.onDeleteAll = {
            reports.removeAll()
            assistant.disconnectGemini()
            preferences.resetToDefaults()
            await reminders.cancelAll()
            await content.removeGeneratedTopics()
        }
    }
}

/// Identyfikator zadania w tle (`beginBackgroundTask`) — kończony dokładnie raz.
@MainActor
private final class BackgroundTaskBox {
    var id: UIBackgroundTaskIdentifier = .invalid

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

/// Wynik obliczeń dla przypomnień (liczony poza głównym wątkiem).
struct ReminderSnapshot: Sendable {
    var dueCount: Int
    var goalReached: Bool
}

// MARK: - Wstrzykiwanie do środowiska

extension View {
    /// Wstrzykuje środowisko aplikacji (wszystkie serwisy) — używane przez `FluentNOWApp`.
    @MainActor
    func fluentEnvironment(_ environment: AppEnvironment) -> some View {
        self
            .environment(environment)
            .environment(environment.store)
            .environment(environment.preferences)
            .environment(environment.speech)
            .environment(environment.pronunciation)
            .environment(environment.reminders)
            .environment(environment.assistant)
            .environment(environment.reports)
    }

    /// Podgląd SwiftUI: `AppEnvironment.preview` (dane przykładowe w pamięci) + nowy `AppRouter`.
    /// Użycie: `#Preview { TodayRootScreen().fluentPreviewEnvironment() }`.
    @MainActor
    func fluentPreviewEnvironment() -> some View {
        fluentPreviewEnvironment(.preview)
    }

    /// Podgląd z wybranym środowiskiem (np. `.previewEmpty`) i opcjonalnie własnym routerem.
    @MainActor
    func fluentPreviewEnvironment(_ environment: AppEnvironment, router: AppRouter? = nil) -> some View {
        self
            .fluentEnvironment(environment)
            .environment(router ?? AppRouter())
    }
}
