# Kontrakt fali 2 (platform-services ↔ ui-learning ↔ ui-library)

Trzej agenci pracują **równolegle**. platform-services implementuje dokładnie poniższe sygnatury; UI piszą kod wyłącznie przeciwko nim i przeciwko FluentKit (pełne API: `ios/docs/reports/core-engine.md` §7, zalecenia użycia: §2 i §5). Jeśli czegoś brakuje — **nie wymyślaj nowego API w cudzym obszarze**: w UI policz to sam na migawce `store.state` funkcjami FluentKit (przez `store.compute`), a prośbę o wygodniejsze API wpisz do raportu.

Wszystkie typy poniżej żyją w `ios/FluentNOW/Services/` (moduł aplikacji, nie pakiet — bez `public`). Wszystko `@MainActor`, chyba że zaznaczono `actor`.

## 1. AppEnvironment — wstrzykiwanie

```swift
@MainActor @Observable final class AppEnvironment {
    let store: LearningStore
    let content: ContentLibrary          // actor
    let speech: SpeechService
    let pronunciation: PronunciationService
    let reminders: ReminderService
    let assistant: AssistantService
    let preferences: AppPreferences
    let reports: ExerciseReportStore

    static func live() -> AppEnvironment          // SwiftData + CloudKit z fallbackiem
    static let preview: AppEnvironment            // w pamięci, dane przykładowe (ok. 30 słów z kilku tematów, historia odpowiedzi z 14 dni, przerwana sesja), bez CloudKit/sieci
    func onAppear() async                         // wczytanie stanu, rozgrzanie treści — wołane raz z FluentNOWApp
    func onScenePhase(_ phase: ScenePhase)        // zapis przy .background, odświeżenie przypomnienia
}
```

Wstrzyknięcie w `FluentNOWApp` (robi platform-services): `.environment(env)`, `.environment(env.store)`, `.environment(env.preferences)`, `.environment(env.speech)`, `.environment(env.pronunciation)`, `.environment(env.reminders)`, `.environment(env.assistant)`, `.environment(env.reports)`. `ContentLibrary` to aktor — ekrany biorą go z `@Environment(AppEnvironment.self) var env` → `env.content`.

Odczyt w widoku: `@Environment(LearningStore.self) private var store`. Podglądy: `#Preview { X().fluentPreviewEnvironment() }` — modyfikator `View.fluentPreviewEnvironment()` (platform-services) wstrzykuje `AppEnvironment.preview` + `AppRouter()`.

## 2. LearningStore — jedyne źródło prawdy

```swift
enum StoreLoadPhase: Equatable { case loading, ready, failed(String) }
enum ChangeKind { case edit, answer, session, bulk }   // .answer i .session zapisują natychmiast, .edit z debounce ≤300 ms, .bulk w tle w partiach

@MainActor @Observable final class LearningStore {
    private(set) var state: LearnerState           // migawka; zawsze po StateMigration.migrate
    private(set) var loadPhase: StoreLoadPhase
    private(set) var lastSaveError: String?        // ostatni błąd zapisu (UI pokazuje ErrorBanner z „Eksportuj kopię”)
    private(set) var revision: Int                 // rośnie przy każdej zmianie (klucz cache dla UI)
    let syncMonitor: SyncMonitor

    // Odczyty pomocnicze (tanie)
    var settings: LearnerSettings { get }
    var activeWords: [Word] { get }                // bez archiwum, kolejność: najnowsze najpierw
    func word(id: String) -> Word?
    func now() -> Timestamp                        // FluentClock.now(); w preview stały zegar

    // Jedyny sposób mutacji: zsynchronizowana transformacja stanu funkcjami FluentKit.
    @discardableResult
    func update<R>(_ kind: ChangeKind = .edit, _ body: (inout LearnerState) -> R) -> R

    // Ciężkie obliczenia na migawce poza głównym wątkiem (statystyki, wyszukiwanie w słowniku użytkownika)
    func compute<T: Sendable>(_ work: @escaping @Sendable (LearnerState) -> T) async -> T

    // Operacje z efektami ubocznymi
    func importJSON(_ data: Data, mode: ImportMode) throws -> ImportSummary      // .merge (StateSync.mergeStates) / .replace
    func importDelimited(_ text: String) throws -> ImportSummary                // CSV/TSV/lista słów (DelimitedImport)
    func previewImportJSON(_ data: Data) throws -> ImportSummary                // bez zapisu
    func previewImportDelimited(_ text: String) throws -> ImportSummary
    func exportJSONFile() throws -> URL                                          // plik tymczasowy do ShareLink
    func exportAnkiCSVFile() throws -> URL
    func deleteAllData() async throws                                            // lokalnie + iCloud + raporty + Keychain AI
    func retryFailedSave() async
}

enum ImportMode { case merge, replace }
struct ImportSummary: Equatable { var newWords: Int; var mergedWords: Int; var skipped: Int; var messages: [String] }
```

Zasady dla UI:
- Każda zmiana danych = `store.update(...)` z funkcją FluentKit w środku, np. `store.update(.answer) { $0 = Scheduler.recordAnswer($0, ...) }`, `let r = store.update(.bulk) { s in let m = VocabularyMerger.addTopicEntries(s, topic: t, entryIDs: ids, now: store.now()); s = m.state; return m }` (sprawdź dokładne typy zwracane w raporcie core-engine §7).
- Nie trzymaj kopii `Word`/`LearnerState` w `@State` dłużej niż trwa edycja formularza; ekrany czytają `store.state` i reagują na `revision`.
- Sesje (słownictwo, combined, czytanie, praktyka, produkcja) żyją w `state` (`session`, `combined`, `reading`, `practice`, `production`) — dzięki temu wznowienie po zabiciu aplikacji działa automatycznie. Każdą odpowiedź zapisuj `update(.answer)`.

## 3. SyncMonitor

```swift
enum SyncStatus: Equatable { case synced(Date?), syncing, localOnly(String), error(String) }
@MainActor @Observable final class SyncMonitor { private(set) var status: SyncStatus; func refresh() async }
```

## 4. ContentLibrary (actor)

```swift
actor ContentLibrary {
    func topicIndex() async throws -> TopicIndex
    func topic(id: String) async throws -> TopicFile
    func entry(reference: String) async throws -> TopicEntry      // "airport/airport.boarding-pass" lub "starter/starter.do"
    func search(_ query: String, limit: Int) async -> [SearchHit]   // ContentSearch zbudowany raz; pusty wynik, jeśli indeks się jeszcze buduje
    func lookup(term: String) async -> Lookup?                      // wszystkie znaczenia hasła z bazy (VocabularyMerger.lookup), nil gdy brak
    func answerVariants() async -> AnswerVariants
    func polishAnswerIndex() async -> PolishAnswerIndex
    func practiceContent(level: String) async throws -> PracticeContent   // ładuje grammar/<poziom>.json leniwie
    func starterWords() async -> [Word]                             // pula dystraktorów
    func recommendations() async -> [Recommendation]
    func warmUp() async
}
```
Błędy: `ContentError` z FluentKit (polski opis).

## 5. Serwisy

```swift
@MainActor @Observable final class AppPreferences {      // UserDefaults, per urządzenie (nie synchronizowane)
    var appearance: AppAppearance        // typ z DesignSystem/Tokens/AppAppearance.swift (design-shell)
    var remindersEnabled: Bool
    var assistantProvider: AssistantProvider
    var hasCompletedOnboarding: Bool
    var hapticsEnabled: Bool
}

@MainActor @Observable final class SpeechService {
    private(set) var isSpeaking: Bool
    func speak(_ text: String, slow: Bool? = nil)          // slow nil → settings.slow; [[gap]] obsłużone
    func stop()
    func availableVoices() -> [VoiceOption]                 // tylko angielskie, najlepsza jakość na górze
    func preview(voice: VoiceOption)
}
struct VoiceOption: Identifiable, Hashable { let id: String; let name: String; let language: String; let qualityLabel: String }

@MainActor @Observable final class PronunciationService {
    enum Permission { case unknown, granted, denied, unavailable }
    private(set) var permission: Permission
    private(set) var isListening: Bool
    private(set) var liveTranscript: String
    func requestPermission() async -> Permission
    func listen(expected: String) async throws -> PronunciationResult   // kończy się sama po ciszy lub maks. 6 s
    func stop()
}
struct PronunciationResult: Equatable { let transcript: String; let expected: String; let similarity: Double; let verdictPl: String }

@MainActor @Observable final class ReminderService {
    enum Authorization { case notDetermined, authorized, denied }
    private(set) var authorization: Authorization
    func requestAuthorization() async -> Authorization
    func reschedule(settings: LearnerSettings, enabled: Bool, dueCount: Int, goalReachedToday: Bool) async
}

enum AssistantProvider: String, CaseIterable, Identifiable, Codable { case offline, appleOnDevice, gemini; var id: String { rawValue }; var namePl: String { get } }

@MainActor @Observable final class AssistantService {
    private(set) var isAppleOnDeviceAvailable: Bool
    private(set) var geminiStatus: GeminiConnectionStatus
    var activeProvider: AssistantProvider { get }           // z preferencji, z fallbackiem do .offline
    func lookup(term: String) async throws -> Lookup        // tylko gdy brak w bazie; wynik oznaczony source = .ai
    func grade(answer: String, word: Word, meaning: Meaning, exerciseType: ExerciseType, context: String) async -> Grade?  // nil = brak/timeout → zostaje ocena lokalna
    func connectGemini(apiKey: String) async throws         // test połączenia, zapis do Keychain
    func disconnectGemini()
}
enum GeminiConnectionStatus: Equatable { case notConfigured, connected(model: String), error(String) }

struct ExerciseReport: Codable, Identifiable, Hashable {
    var id: String; var createdAt: Timestamp; var mode: String; var question: String
    var answer: String; var expected: [String]; var wordId: String?; var meaningId: String?; var comment: String
}
@MainActor @Observable final class ExerciseReportStore {
    private(set) var reports: [ExerciseReport]
    func add(_ report: ExerciseReport)
    func exportFile() throws -> URL
    func removeAll()
}
```

## 6. Nawigacja (design-shell, już istnieje — `ios/FluentNOW/App/`)

- Ekrany kart: `TodayRootScreen`, `WordsRootScreen` (segmenty Słowa/Kolekcje/Tematy przez `router.librarySection`), `StudyRootScreen`, `StatsRootScreen`, `SettingsRootScreen`, `AddWordRootScreen` (arkusz szybkiego dodawania), `TopicsRootScreen`, `CollectionsRootScreen`. Kontrakt: inicjalizator bez argumentów, **bez własnego `NavigationStack`** (stos daje `RootView`). Zastąp `body` i usuń odpowiadający `*Placeholder.swift`.
- Router: `@Environment(AppRouter.self)`: `push(_:on:)`, `startStudy(_:)` + `consumeStudyLaunch()`, `openLibrary(_:destination:)` + `consumeLibraryDestination()`, `presentQuickAdd(prefill:)`. Szczegóły i typy (`StudyLaunchRequest`, `LibrarySection`, `LibraryDestination`): `ios/docs/reports/design-shell.md` §2.
- Trasy: każdy obszar definiuje własne `enum XRoute: Hashable` + `.navigationDestination(for: XRoute.self)` w swoim korzeniu. Nazwy tras z prefiksem obszaru (`WordRoute`, `TopicRoute`, `StudyRoute`, `StatsRoute`, `SettingsRoute`), żeby nie było kolizji.
- Przejście z ui-library do nauki (np. „Ćwicz tę kolekcję”, „Warto do nich wrócić”): **tylko** przez `router.startStudy(...)` — ui-library nie importuje widoków ui-learning i odwrotnie.

## 7. Granice obszarów i nazewnictwo

- Każdy agent tworzy pliki tylko w swoich katalogach; typy pomocnicze nazywa z prefiksem obszaru lub trzyma jako `private`/`fileprivate`, żeby uniknąć kolizji nazw w jednym module (np. `StudySummaryView`, nie `SummaryView`).
- Komponenty wspólne: tylko z `DesignSystem/` (design-shell). Brakujący komponent wspólny → zrób lokalny `private` i opisz w raporcie.
- Raport końcowy: jeśli zapis pliku `.md` jest zablokowany, **nie obchodź blokady** — zwróć pełną treść raportu w odpowiedzi końcowej, koordynator go zapisze.
- Nie uruchamiaj poleceń git — commituje koordynator.

## 8. Wyszukiwanie tematu (F1, topic-search) — dodatki addytywne

Tematy nie są publicznym katalogiem: brak segmentu „Tematy” w Słowniku i trasy `TopicRoute`. Wejście: arkusz „+” z przełącznikiem „Dodaj słowo” / „Szukaj tematu”.

```swift
// AppRouter
func presentTopicSearch(query: String? = nil, topicID: String? = nil)   // AppSheet.topicSearch(query:topicID:)
// openLibrary(.topics) i cel .topic(id:) → presentTopicSearch (zgodność starych wywołań)
// DeepLink: fluentnow://topics[/<id>][?q=…] → .topicSearch(query:topicID:)

// ContentLibrary (actor)
init(bundle: Bundle = .main, localTopics: LocalTopicStore? = nil); init(rootURL: URL?, localTopics: LocalTopicStore? = nil)
func topicCatalog() async -> TopicSearchCatalog
func rankTopics(_ query: String, limit: Int = 8) async -> [TopicMatch]
func topicSuggestions(for matches: [TopicMatch]) async -> [TopicSuggestion]
func topicResultSections(primary: TopicMatch, matches: [TopicMatch]) async throws -> [TopicResultSection]
func knownTopicIDs() async -> Set<String>
func generatedTopic(id: String) async -> GeneratedTopicRecord?
func saveGeneratedTopic(_ record: GeneratedTopicRecord) async throws
func rememberQuery(_ query: String, topicID: String, categoryID: String?, now: Timestamp) async
func forgetQuery(_ query: String) async
func removeGeneratedTopics() async
// topic(id:), entry(reference:), search, lookup obejmują też tematy AI (id z prefiksem „ai-”).

// AssistantService
var canGenerateTopics: Bool
func generateTopicDraft(query: String) async throws -> TopicDraft
func generateTopicDetails(topicName: String, items: [TopicHydrationRequestItem]) async throws -> [TopicHydrationItem]
```
FluentKit: `TopicSearch`, `TopicSearchCatalog`, `TopicSearchDocument`, `TopicMatch`, `TopicResultSection`, `TopicGeneration`, `TopicEntryValidator`, `TopicAliasBook`, `GeneratedTopicRecord` — szczegóły w `docs/reports/topic-search.md`.
