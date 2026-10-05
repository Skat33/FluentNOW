# Raport: platform-services (fala 2)

Kod napisany na Windows **bez kompilatora**. Pierwsza kompilacja i testy (⌘U) nastąpią na Macu.

## 1. Co zrobiono (pliki)

```
FluentNOW/App/
  AppEnvironment.swift          AppEnvironment (live / preview / previewEmpty / makePreview), onAppear, onScenePhase,
                                refreshReminders, View.fluentEnvironment(_:), View.fluentPreviewEnvironment()
  FluentNOWApp.swift            (minimalne wpięcie) AppEnvironment.live(), wstrzyknięcie serwisów, motyw z preferencji,
                                deep link z powiadomienia, scenePhase → onScenePhase
FluentNOW/Services/
  Store/StoreTypes.swift        StoreLoadPhase, ChangeKind, ImportMode, ImportSummary
  Store/LearningStore.swift     jedyne źródło prawdy (update/compute/import/eksport/usuwanie, zapis szeregowany)
  Persistence/Records.swift     @Model: WordRecord, ReviewRecord, SettingsRecord, SessionRecord, HistoryRecord (+ SessionKind, HistoryKind)
  Persistence/LearningRepository.swift   @ModelActor: encje ↔ LearnerState, zapis przyrostowy, duplikaty, uszkodzone rekordy
  Persistence/LearningPersistence.swift  protokół (Actor) + InMemoryPersistence (podgląd/testy), PersistenceLoadResult, PersistenceError
  Persistence/SwiftDataPersistence.swift actor: szeregowanie operacji, ponowne wczytanie po zmianach z iCloud (świeży kontekst)
  Persistence/PersistenceController.swift ModelContainer: CloudKit → lokalny → kopia uszkodzonej bazy + nowy → pamięć
  Persistence/CloudKitAvailability.swift  bezpieczne wykrycie uprawnienia CloudKit (bez crasha CKContainer)
  Sync/SyncMonitor.swift        SyncStatus (+ titlePl/detailPl/systemImage), SyncMode, SyncMonitor (konto iCloud, zdarzenia CloudKit)
  Content/ContentLibrary.swift  actor: tematy, wpisy, ContentSearch (raz, w tle), lookup, warianty, PolishAnswerIndex,
                                practiceContent(level:), starter, rekomendacje, warmUp, validateAll
  Speech/SpeechService.swift    AVSpeechSynthesizer, VoiceOption, luki [[gap]]/____ jako pauzy, .playback + .duckOthers, przerwania
  Speech/PronunciationService.swift  SFSpeechRecognizer en-US (na urządzeniu), zgody, ≤ 6 s / cisza, PronunciationResult, PronunciationError
  Reminders/ReminderService.swift   UNUserNotificationCenter, plan na 14 dni (bez dzisiejszego, gdy cel osiągnięty), deep link po dotknięciu
  Assistant/AssistantTypes.swift    AssistantProvider, GeminiConnectionStatus, AssistantError, LanguageAssistant, GradeRequest
  Assistant/AssistantService.swift  wybór dostawcy z fallbackiem, limit 20 s, connect/disconnect Gemini, wybór modelu
  Assistant/OfflineAssistant.swift  wbudowana baza (zawsze działa)
  Assistant/AppleOnDeviceAssistant.swift  #if canImport(FoundationModels), @available(iOS 26), @Generable
  Assistant/GeminiAssistant.swift   REST v1beta, lista modeli + fallback jak lib/gemini.ts, ponowienia, schematy JSON
  Assistant/AssistantValidation.swift  walidacja treści AI (+ AssistantPrompts z tutor-prompts.ts strony)
  Keychain/KeychainStore.swift      kSecClassGenericPassword, AfterFirstUnlockThisDeviceOnly, bez synchronizacji
  ImportExport/ExportFileWriter.swift  pliki eksportu w tmp/Export (stare usuwane)
  Reports/ExerciseReportStore.swift    ExerciseReport, ExerciseReportStore (JSON w Application Support, lokalnie)
  Preferences/AppPreferences.swift     UserDefaults per urządzenie
  Preview/PreviewData.swift            30 słów z 5 tematów, 14 dni historii, przerwana sesja, zgłoszenie
FluentNOWTests/Services/
  ServicesTestSupport.swift, RepositoryTests.swift, LearningStoreTests.swift, ContentLibraryTests.swift, ServiceLogicTests.swift
```
Razem 31 plików Swift, ok. 5 500 linii. `FluentNOWTests/Shell/ShellTests.swift` (design-shell) bez zmian.
`project.yml`: **bez zmian** — potrzebne klucze już są (`UIBackgroundModes: remote-notification`, `aps-environment`, kontener iCloud, opisy prywatności mowy i mikrofonu). Powiadomienia lokalne nie wymagają klucza w Info.plist.

## 2. Publiczne API (kontrakt fali 2 — zaimplementowany dokładnie wg `CONTRACTS.md`)

Wszystkie sygnatury z CONTRACTS.md §1–§5 istnieją bez zmian. Dodatki (addytywne, opcjonalne dla UI):

```swift
// AppEnvironment
static let previewEmpty: AppEnvironment
static func makePreview(state: LearnerState) -> AppEnvironment
let isPreview: Bool
func refreshReminders() async              // liczy wymagalne powtórki + cel dnia poza głównym wątkiem i planuje przypomnienia
extension View { func fluentEnvironment(_:) -> some View; func fluentPreviewEnvironment(_ env: AppEnvironment, router: AppRouter? = nil) -> some View }

// LearningStore
private(set) var loadNotice: String?               // np. „Pominięto N uszkodzonych rekordów…”
private(set) var corruptedStoreBackupURL: URL?     // kopia uszkodzonej bazy (do ShareLink w Ustawieniach)
var hasUnsavedChanges: Bool
func flush() async                                 // czeka na zapis wszystkich zmian
func exportJSONFileInBackground() async throws -> URL   // prośba ui-library: kodowanie poza głównym wątkiem
func exportAnkiCSVFileInBackground() async throws -> URL // (wersje synchroniczne z kontraktu zostają)
func load() async; func reloadRemoteChanges() async
var onDeleteAll: (@MainActor () async -> Void)?    // ustawia AppEnvironment
init(persistence: any LearningPersistence, syncMonitor: SyncMonitor, initialState: LearnerState? = nil, fixedNow: Timestamp? = nil)

// SyncStatus: titlePl, detailPl, systemImage; SyncMonitor: usesCloudKit, start(), reportError(_:), onRemoteImport
// ContentLibrary: init(bundle:), init(rootURL:), isAvailable, isSearchReady, readingBank(), starterEntries(), validateAll(), static isSafeFileName(_:)
// SpeechService: init(settingsProvider:audioEnabled:), reloadVoices(), static segments(for:)
// PronunciationService: init(enabled:), static evaluate(transcript:expected:), maxDuration 6 s, silenceTimeout 1,3 s
// ReminderService: init(enabled:), refreshAuthorization(), cancelAll(), onOpenURL, static plan/body/wordsForm
// AssistantService: isWorking, availableGeminiModels, geminiModel, appleOnDeviceUnavailableReason, refreshAvailability(), selectGeminiModel(_:)
// AssistantProvider.detailPl; AssistantError (LocalizedError, PL); ExerciseReport ma init z domyślnymi id/createdAt
// AppPreferences: init(defaults: UserDefaults?), resetToDefaults()
```

**Stabilne API poza kontraktem, z którego korzysta UI (nie zmieniać bez uzgodnienia):** `AppEnvironment.refreshReminders()`, `AppEnvironment.previewEmpty`, `SyncStatus.titlePl/detailPl/systemImage`, `AssistantProvider.detailPl`, `AssistantService.refreshAvailability()`, `AssistantService.appleOnDeviceUnavailableReason` (ui-library), `ExerciseReport` init z domyślnymi `id/createdAt`, `store.flush()` (ui-learning). Asynchroniczne warianty eksportu mają osobne nazwy (`…InBackground`) zamiast przeciążeń `async` o tej samej nazwie — przeciążenie zmieniłoby wybór funkcji w istniejących wywołaniach w kontekście `async` i zepsuło kompilację ekranów.

Zasady zapisu (`ChangeKind`): `.answer`, `.session`, `.bulk` → zapis natychmiast (w tle, szeregowany łańcuchem zadań — kolejność na dysku = kolejność zmian); `.edit` → debounce 250 ms (kolejne edycje łączone w jeden zapis). Repozytorium zapisuje tylko rekordy różne od ostatnio zapisanych (porównanie z cache), partiami po 400.

## 3. Architektura i odstępstwa od strony

- **Model danych w SwiftData/CloudKit.** Jeden rekord na słowo, na odpowiedź (`ReviewRecord`, tylko dopisywane → bez konfliktów między urządzeniami), na wpis historii czytania/praktyki/produkcji i na dzień podsumowania, jeden na rodzaj sesji (5), jeden dla ustawień+kolekcji, jeden dla `grammarSeen`. Wszystkie atrybuty z wartościami domyślnymi, bez `.unique` i relacji. Kolejność słów: `created` malejąco, potem `position` (pozycja przy pierwszym zapisie) — dzięki temu wstawienie słowa na początek nie przepisuje rekordów wszystkich innych słów.
- **Duplikaty** (ten sam `wordId` z dwóch urządzeń) scalane przy wczytaniu `StateSync.mergeDuplicateWords` (wyniki per umiejętność — postęp z obu urządzeń zostaje), nadmiarowe rekordy usuwane; duplikaty sesji/ustawień → nowszy `updatedAt` (kolekcje sumowane), historii → unia.
- **Uszkodzone rekordy** są pomijane i logowane (`os.Logger`), **nie są kasowane** (może je odczytać nowsza wersja); `loadNotice` informuje użytkownika. Uszkodzona baza (kontener się nie otwiera) → pliki do `Documents/Kopie/<data>/`, nowy magazyn, komunikat + `corruptedStoreBackupURL`; w ostateczności kontener w pamięci z ostrzeżeniem „wyeksportuj kopię”. Nigdzie crasha.
- **CloudKit bez crasha:** `CKContainer(identifier:)` bez uprawnienia rzuca wyjątek ObjC, a README pozwala budować bez iCloud (darmowe konto). `CloudKitAvailability` sprawdza uprawnienie: urządzenie → `embedded.mobileprovision`; symulator → sekcja `__TEXT,__entitlements`; brak profilu (App Store/TestFlight) → uprawnienie jest. Bez uprawnienia: magazyn lokalny i `SyncStatus.localOnly(...)`. Brak konta iCloud: kontener z CloudKit działa lokalnie i zsynchronizuje się po zalogowaniu (status `localOnly` z instrukcją).
- **Zmiany z innych urządzeń:** po udanym zdarzeniu `import` `NSPersistentCloudKitContainer` (oraz przy powrocie do aplikacji, nie częściej niż co 60 s) repozytorium jest tworzone od nowa (świeży `ModelContext`), stan wczytany i scalony z bieżącym `StateSync.mergeStates(local: bieżący, remote: z dysku)` — trwająca sesja nie ginie (mergeStates zachowuje lokalne sesje). Słowa, których rekordy zniknęły od ostatniego odczytu (usunięte na innym urządzeniu przez „Usuń wszystkie dane”), są usuwane także lokalnie — inaczej dane by „zmartwychwstawały”. Nie używam `NSPersistentStoreRemoteChange`, bo przychodzi też po własnych zapisach (pełne wczytanie po każdej odpowiedzi).
- **„Usuń wszystkie dane”:** usunięcie każdego rekordu pojedynczo (usunięcia wsadowe nie są pewnie odbijane w CloudKit) → stan pusty → zgłoszenia, klucz Gemini (Keychain), pliki eksportu, przypomnienia, preferencje. **Na prośbę ui-learning** `AppPreferences.resetToDefaults()` usuwa też wszystkie klucze UserDefaults z prefiksami `study.` (preferencje ekranów nauki) i `fluent.` (`AppPreferences.resettableKeyPrefixes`).
- **Zapis przy wejściu w tło** w `beginBackgroundTask` (zapis + odświeżenie przypomnień); `.inactive` też wymusza zapis.
- **Przypomnienia:** zamiast powtarzalnego wyzwalacza — pojedyncze powiadomienia na 14 kolejnych dni (pozwala pominąć dzisiejsze, gdy cel osiągnięty albo pora minęła; maks. 1 dziennie). Treść najbliższego z liczbą wymagalnych powtórek („Masz 7 słówek do powtórki”, poprawna odmiana), dalszych — ogólna. Plan odświeżany przy każdym przejściu w tło. Dotknięcie → `fluentnow://study/start?mode=mixed` (link buforowany przy zimnym starcie). Gdy aplikacja jest na pierwszym planie, baner nie jest pokazywany.
- **Mowa:** głos = identyfikator `AVSpeechSynthesisVoice` w `settings.voice`; nieznany identyfikator (np. nazwa głosu z przeglądarki po imporcie ze strony) → najlepszy głos dla `settings.accent`. Lista: tylko angielskie, bez głosów-zabawek i Personal Voice, premium → enhanced → default. Wolne tempo = 0,78 × domyślnego. **Gemini TTS pominięte** (opcjonalne w roli): głosy premium/enhanced iOS są dobre, a TTS przez sieć wymagałby obsługi PCM i limitów — do rozważenia później.
- **Wymowa:** `requiresOnDeviceRecognition`, gdy obsługiwane; bez `contextualStrings` (podpowiadanie oczekiwanego tekstu zawyżałoby wynik — ma być uczciwie). Podobieństwo = 1 − Levenshtein/długość na tekście bez interpunkcji; werdykt mówi, co *usłyszało urządzenie*. Nic nie trafia na dysk. Wymowa nie wpływa na stan (UI nie zapisuje jej w opanowaniu).
- **AI:** `uncertain` nigdy nie oblewa (`Grade.isFailure`); `grade` zwraca `nil` przy offline/błędzie/timeoucie. Treść AI zawsze walidowana: znaczenie bez tłumaczenia odrzucane, przykład tylko gdy `focusEn ⊂ en` i `focusPl ⊂ pl`, CEFR normalizowany, `(AmE)` usuwane, `contentRef = nil`, `source = .ai`. Gemini: lista modeli przez API (jednocześnie test klucza), kolejność jak `compatibleGeminiModels` strony, 404 → następny model, 408/5xx → ponowienie z opóźnieniem 1–2–4 s (maks. 3), 429 → jedno ponowienie, potem błąd po polsku z kodem HTTP. Klucz tylko w Keychain (`ThisDeviceOnly`, bez synchronizacji), nigdy w eksporcie/UserDefaults/logach.
- **Strona vs iOS (import/eksport):** eksport `StateExporter.exportJSON` (zgodny ze stroną), CSV Anki; import JSON ze strony działa (test na fixture v31). Podgląd importu nic nie zmienia. `importJSON(.merge)` = `mergeStates` (nic nie ginie), `.replace` = zastąpienie.

## 4. Ryzyka / niesprawdzone (brak kompilatora)

1. **SwiftData + CloudKit:** zakładam, że `NSPersistentCloudKitContainer.eventChangedNotification` jest wysyłane także dla kontenerów SwiftData (tak działa w praktyce, ale nie jest to udokumentowane dla SwiftData). Jeśli nie — status zostanie „Synchronizacja…”/„Zsynchronizowano” tylko po sprawdzeniu konta, a zmiany z innych urządzeń wczytają się przy powrocie do aplikacji (zabezpieczenie co 60 s).
2. **Konflikt tego samego rekordu słowa** edytowanego offline na dwóch urządzeniach: CloudKit stosuje „ostatni zapis wygrywa” na poziomie rekordu — wyniki z jednego urządzenia dla tego słowa mogą przepaść (odpowiedzi w `ReviewRecord` zostają). Pełne rozwiązanie wymagałoby rekordów per znaczenie/umiejętność — zostawione na później.
3. `CloudKitAvailability` w symulatorze czyta `__TEXT,__entitlements` z obrazu 0 (`getsectiondata`). Przy `ENABLE_DEBUG_DYLIB` obraz 0 to plik wykonywalny-zaślepka — powinien mieć tę sekcję; jeśli nie, symulator przejdzie na tryb lokalny (bez crasha).
4. Foundation Models: `LanguageModelSession(instructions: String)`, `respond(to: String, generating:)`, `response.content`, `@Generable(description:)`, `@Guide(description:)`, `SystemLanguageModel.default.availability` z przypadkami `.deviceNotEligible/.appleIntelligenceNotEnabled/.modelNotReady` — sprawdzone w dokumentacji Apple (JSON developer.apple.com); dokumentacja pokazuje już nowsze przeciążenia (`Prompt`, `model:`), więc stringowe wersje z iOS 26.0 potraktowałem jako dostępne. Model Apple oficjalnie nie obsługuje polskiego — tłumaczenia mogą być słabsze (walidacja odrzuca niekompletne).
5. `deinit` w klasach `@MainActor` (`SyncMonitor`, `SpeechService`) odczytuje izolowane właściwości (obserwatory) — w trybie Swift 5 to najwyżej ostrzeżenie.
6. Zamknięcia przekazywane do Speech/AVAudioEngine tworzone w funkcjach `nonisolated static` — celowo, żeby nie dziedziczyły `@MainActor` (wątek audio).
7. `importJSON`/`previewImportJSON` są synchroniczne (tak w kontrakcie) — dekodują na głównym wątku (eksport ma już warianty `…InBackground`). Dla typowych kopii (< 2 MB) to kilkadziesiąt ms; przy bardzo dużych plikach UI może pokazać wskaźnik. Do rozważenia: wariant `async` w następnej wersji kontraktu.
8. `LearningStore.update` porównuje i zapisuje całe słowa — przy ~5 000 słów porównanie z cache w repozytorium to kilka ms w tle na zapis.
9. Testy zależne od plików repozytorium (`#filePath` → treść i fixture) robią `XCTSkip`, gdy plików brak.

### Wydajność (oszacowanie i miejsca pomiaru)
- Start: `ModelContainer` tworzony raz w `AppEnvironment.live()` (otwarcie SQLite, kilka–kilkanaście ms); stan wczytuje się w `.task` w tle (`LearningRepository` na `ModelActor`), UI ma od razu `loadPhase = .loading` (szkielet). Wczytanie 1 000 słów + 5 000 odpowiedzi: szacuję 50–150 ms w tle (dekodowanie JSON). `ContentSearch` budowany w `Task.detached(.utility)` po pierwszej klatce (`warmUp`).
- Do zmierzenia w Instruments: *Time Profiler* na `LearningRepository.fetchAll` i `applyChanges` (duże konto), *SwiftData* instrument dla liczby zapisów na odpowiedź (oczekiwane 3 rekordy: słowo, odpowiedź, sesja), *Points of Interest* wokół `ContentLibrary.warmUp`.

## 5. Prośby do innych ról

- **ui-library (Ustawienia):** eksport może przejść na `exportJSONFileInBackground()` / `exportAnkiCSVFileInBackground()` (dodane na prośbę; wersje synchroniczne zostają). pokazać `store.loadNotice` i — gdy `store.corruptedStoreBackupURL != nil` — `ShareLink` do kopii; przy `store.lastSaveError` `ErrorBanner` z „Spróbuj ponownie” (`retryFailedSave`) i „Eksportuj kopię” (`exportJSONFile`). Po włączeniu przypomnień: `await reminders.requestAuthorization()` → `preferences.remindersEnabled = true` → `await env.refreshReminders()` (już tak robione w `SettingsSections`). Wybór modelu Gemini: `assistant.availableGeminiModels` + `selectGeminiModel(_:)` (opcjonalnie).
- **ui-learning:** `assistant.grade(...)` wołać tylko dla odpowiedzi ocenionych lokalnie jako niepoprawne bez `closestAnswer` (druga opinia); `nil` = zostaje ocena lokalna. Wymowa: `pronunciation.requestPermission()` dopiero po dotknięciu przycisku. Klucze UserDefaults trzymać z prefiksem `study.` (czyszczone przy usuwaniu danych).
- **design-shell (README):** dopisać, że w trybie bez iCloud aplikacja sama wykrywa brak uprawnienia (nie trzeba nic zmieniać w kodzie) i że kopia uszkodzonej bazy ląduje w `Documents/Kopie`.
- **core-engine:** brak próśb blokujących. Miło byłoby mieć `StateSync.mergeStates` z opcją usuwania słów skasowanych zdalnie (teraz robi to `LearningStore`).

## 6. Testy

Nieuruchomione (brak Swift na Windows). `FluentNOWTests/Services/` — 50 testów XCTest:
- **RepositoryTests** (SwiftData w pamięci): pełny round-trip stanu podglądu (słowa 1:1, kolejność, recenzje, sesja, ustawienia, kolekcje); zmiany przyrostowe widoczne dla nowego repozytorium; usunięcie słowa kasuje rekord; **duplikaty z dwóch urządzeń scalone z postępem z obu** i jednym rekordem po zapisie; **uszkodzony payload** słowa/odpowiedzi/sesji pominięty bez crasha (rekord słowa zachowany); kompaktowanie odpowiedzi > 90 dni + usunięcie rekordów; historie i `grammarSeen`; usuwanie wszystkiego i ponowny zapis; wykrycie słów usuniętych zdalnie.
- **LearningStoreTests:** zapis odpowiedzi natychmiast; 5 edycji = 1 zapis (debounce); wynik `update`; błąd zapisu → `lastSaveError` → ponowienie; wczytanie z migracją i sesją; zmiana w trakcie wczytywania nie ginie; `activeWords`; **import fixture strony v31** (podgląd bez zmian, merge, replace); niepoprawny JSON → czytelny błąd bez zmian w stanie; **eksport → import (round-trip identyczny)** + CSV Anki; import CSV z pominięciem już posiadanych; usuwanie danych + hook; eksport w tle = eksport synchroniczny; `compute`; ponowne wczytanie z iCloud nie gubi sesji.
- **ContentLibraryTests:** **integralność treści** — każdy plik (`topics/*`, indeks, słownik, gramatyka A1–C2, banki) dekoduje się, z repozytorium i **z bundla aplikacji** (sprawdza referencję folderową `Content/`); tematy i wpisy po referencji; brakujący plik / `..` → `ContentError`; brak katalogu treści bez crasha; wyszukiwanie (EN i PL) i lookup po `warmUp`; treść praktyki dla poziomu i fallback; dodanie tematu przez `store.update(.bulk)`.
- **ServiceLogicTests:** podział mowy na luki; ocena wymowy (idealnie / prawie / źle / cisza) i normalizacja; plan przypomnień (dziś / cel osiągnięty / po porze) i polska odmiana; kolejność modeli Gemini zgodna ze stroną, format klucza, preferowany model; walidacja treści AI (zepsute przykłady, nieistniejące słowo z podpowiedzią), `uncertain` nie oblewa; limit czasu; offline domyślnie i bez klucza; parsowanie uprawnień i profilu; pliki eksportu; zgłoszenia (zapis/eksport); preferencje w UserDefaults; spójność danych podglądu (30 słów, sesja przetrwała migrację, 13 dni aktywności, `focusEn/focusPl` to podciągi).

Uruchomione skrypty (Node): kontrola składni wszystkich 31 plików (nawiasy z uwzględnieniem interpolacji, cudzysłowy, BOM, CR) — OK; skan `try!`/`as!`/`fatalError`/force-unwrap — brak; sprawdzenie, że API używane przez ekrany ui-learning/ui-library (`grep` w `Features/`) istnieje w serwisach — OK.
