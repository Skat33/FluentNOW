# Raport: code-qa A (FluentKit, Services, App, DesignSystem, FluentNOWTests, project.yml)

Przegląd „kompilatorem w głowie”, plik po pliku. Bez kompilatora — pierwsza kompilacja i testy dopiero na Macu.
Przejrzane: wszystkie źródła FluentKit (57 plików) i jego testy, `Services/` (24), `App/` (7), `DesignSystem/` (22), `FluentNOWTests/` (6 + 3 nowe), `project.yml`, `Info.plist`, entitlements. Weryfikacja API Apple: dokumentacja XcodeGen (`ProjectSpec.md`) i Foundation Models (JSON developer.apple.com). Pozostałe sygnatury (SwiftData, CloudKit, Speech, AVFoundation, UserNotifications, SwiftUI iOS 17/18/26) sprawdziłem z pamięci znanych SDK — zgodne.

## 1. Poprawki

| plik:linia | kategoria | problem | poprawka |
|---|---|---|---|
| `FluentKit/Grading/VocabularyGrader.swift` `gradingWord` (~l. 85) | logika | Luka oceniana na surowym `task.example`, a ekran pokazuje `examples[i % count]` (strona robi modulo). Gdy indeks wychodził poza zakres, oceniano formę bazową zamiast formy ze zdania. | Indeks zawijany jak na ekranie. Nowe publiczne `VocabularyGrader.exampleIndex(_:in:)` (addytywne). Test: `CodeQARegressionTests.testGradingWordWrapsExampleIndexLikeTheScreen`. |
| `FluentKit/Scheduling/Scheduler.swift` `recordAnswer` (~l. 99) | logika / blokada UI | Słowo usunięte w trakcie przerwanej sesji → stan wracał bez zmian, `session.index` nie rósł, ekran utykał na „Dalej” (zgłoszenie code-qa-B, backlog). | Gdy zadanie jest bieżącym zadaniem sesji, indeks się przesuwa, bez powtórki i bez recenzji. Łatka B w `VocabSessionModel.commit` jest zgodna (sprawdza `index == expectedIndex`), więc nie ma podwójnego przesunięcia. Testy: `testDeletedWordInPausedSessionAdvancesWithoutRetry`, `testMissingWordOutsideTheCurrentTaskKeepsState`, `testCombinedSessionSavesAndAdvancesPastDeletedWord`. |
| `FluentKit/ImportExport/StateMigration.swift` (~l. 53) | logika / utrata danych | Usunięcie słowa, na które już odpowiedziano w przerwanej sesji, kasowało przy następnym starcie całą sesję do wznowienia. | Sesja zostaje, dopóki ma zadania do zrobienia. Ukończona sesja z uszkodzonym prefiksem jest nadal odrzucana, więc istniejący test przechodzi. Test: `testMigrationKeepsPausedSessionWhenAnAnsweredWordWasDeleted`. |
| `FluentKit/Sessions/PracticeFlow.swift` `advancePractice` / `advanceProduction` | logika (podwójne tapnięcie) | Przejście dalej bez odpowiedzi na bieżące pytanie: podwójne tapnięcie pomijało pytanie. | Strażnik: brak odpowiedzi lub wyniku = bez zmian. Testy: `testPracticeAdvanceRequiresAnAnswer`, `testProductionAdvanceRequiresAGradedAnswer`. |
| `Services/Store/LearningStore.swift` `load()` | logika / utrata danych | Zmiana przed zakończeniem wczytywania (`mutatedDuringLoad`) była scalana `mergeStates(local: pusty+zmiana, …)`, a ten bierze ustawienia i sesje z `local`. Domyślne ustawienia nadpisywały zapisane (cel, pora, głos), a przerwane sesje znikały. | `LearningStore.mergePreloadChanges(preload:loaded:)`: ustawienia i sesje z dysku, chyba że zmienione przed wczytaniem. Testy: `CodeQAServiceTests.testEditBeforeLoadKeepsStoredSettingsAndPausedSession`, `testMergePreloadChangesPrefersLoadedDefaults`. |
| `Services/Store/LearningStore.swift` `reloadRemoteChanges()` | logika (sync) | Po imporcie z iCloud `mergeStates` brał ustawienia z bieżącego stanu, a następny zapis cofał zmianę ustawień zrobioną na innym urządzeniu. Ustawienia praktycznie się nie synchronizowały. | `lastSyncedSettings`: gdy lokalnie bez zmian od ostatniej synchronizacji, bierzemy ustawienia z dysku. Porównanie liczone po `await`. Testy: `testRemoteSettingsChangeIsAdoptedWhenUnchangedLocally`, `testLocalSettingsChangeSurvivesRemoteReload`. |
| `Services/Store/LearningStore.swift` | wydajność | `importJSON`/`previewImportJSON` dekodowały pliki do 50 MB na głównym wątku (ryzyko platform-services §4.7). | Addytywne `importJSONInBackground(_:mode:)` i `previewImportJSONInBackground(_:)` (dekodowanie w `Task.detached`). B przełączył już na nie `SettingsImportScreen`. Test: `testBackgroundJSONImportMatchesSynchronousImport`. |
| `Services/Persistence/PersistenceController.swift` l. 82 | crash/odporność | Magazyn awaryjny w pamięci tworzony z `cloudKitDatabase` domyślnym (`.automatic`). Przy uprawnieniu iCloud SwiftData próbuje podpiąć CloudKit także pod store w pamięci, więc ostatni fallback mógł się nie otworzyć. | Jawne `ModelConfiguration(schema:isStoredInMemoryOnly: true, cloudKitDatabase: .none)`. |
| `Services/Speech/PronunciationService.swift` `requestPermission` | crash (izolacja) | Blok `SFSpeechRecognizer.requestAuthorization` tworzony w kontekście `@MainActor` jest wołany przez Speech na obcej kolejce. W nowszych trybach Swift grozi to pułapką sprawdzania izolacji. | Przeniesione do `nonisolated static func requestSpeechAuthorization()`, tak jak było już z blokami audio i wyników. |
| `Services/Assistant/AssistantValidation.swift` l. 51 | kompilacja | `compactMap(sanitize)`: referencja do przeciążonej funkcji (3 przeciążenia `sanitize`) mogła dawać niejednoznaczność. | `compactMap { sanitize($0) }`. |
| `Services/Assistant/AppleOnDeviceAssistant.swift`, `AssistantService.swift` | kompilacja (ryzyko SDK) | API Foundation Models zmienia się między SDK (dokumentacja pokazuje już nowe przeciążenia `model:`/`Prompt`). | `#if canImport(FoundationModels) && !FLUENT_DISABLE_FOUNDATION_MODELS`: awaryjne wyłączenie jedną flagą kompilacji, bez edycji kodu. |
| `App/AppRouter.swift` l. 80, 91 | kompilacja | `var path = path(for: tab)`: lokalna zmienna przesłania metodę we własnym inicjalizatorze (ryzyko „variable used within its own initial value”). | `self.path(for:)`. |
| `App/RootView.swift` | zgodność z iOS 26 / podglądy | `tabBarMinimizeBehavior` był nakładany na `Group`, a nie na `TabView` (ryzyko design-shell §4.8). Podglądy `RootView` nie wstrzykiwały serwisów, przez co ekrany crashowały w canvasie. | Modyfikator przeniesiony na `TabView` w `ModernTabView`. Podglądy przez `.fluentPreviewEnvironment(.preview, router:)`. |
| `DesignSystem/Modifiers/Haptics.swift`, `Components/ConfidencePicker.swift`, `Badges.swift` (`TagChip`), `FeedbackPanel.swift`, `App/FluentNOWApp.swift` | logika (backlog) | `ConfidencePicker` i `TagChip` (oraz `FeedbackPanel`) wibrowały mimo wyłączenia haptyki w Ustawieniach. | Nowe `EnvironmentValues.fluentHapticsEnabled` (domyślnie `true`) i `View.fluentSensoryFeedback(_:trigger:)`. Korzeń aplikacji (`AppearanceRoot`) ustawia wartość z `preferences.hapticsEnabled`. B przełączył wszystkie gołe `.sensoryFeedback` w Features. Test: `testHapticsEnvironmentDefaultsToEnabled`. |
| `DesignSystem/Components/ProgressRing.swift` l. 137, 140, 154 (podgląd) | logika (UI) | Zgubione `\` w interpolacji: `Text("(done)")` pokazywał dosłownie „(done)”. | `"\(done)"`, `"z \(goal) zadań"`. Skan wszystkich 203 plików Swift skryptem nie znalazł innych przypadków. |
| `project.yml` (`configs.Debug`) | link testów | Testy aplikacji linkują symbole FluentKit z pliku wykonywalnego aplikacji (`BUNDLE_LOADER`). Przy `DEAD_CODE_STRIPPING: YES` API używane tylko w testach mogło zniknąć („Undefined symbols”). | `DEAD_CODE_STRIPPING: NO` tylko w Debug; Release bez zmian. Nie dodaję FluentKit do targetu testów, bo podwójna kopia typów psuje `catch … as ContentError`. |
| `docs/MANUAL-TEST-PLAN.md` | dokumentacja | — | Nowy plik: sekcje 0–5 (kompilacja, start, iOS 17/26, iCloud i dwa urządzenia, offline, dane, przypomnienia, dostępność). Sekcja 6 (ekrany) od code-qa-B dołączona; `MANUAL-TEST-PLAN-screens.md` usunięty, odnośnik w `code-qa-B.md` poprawiony. |

Nowe testy:
- `Packages/FluentKit/Tests/FluentKitTests/CodeQARegressionTests.swift`: 7 testów.
- `FluentNOWTests/CodeQA/CodeQAServiceTests.swift`: 8 testów (store, router, haptyka, walidacja AI, import w tle).
- `FluentNOWTests/CodeQA/FeaturePureFunctionTests.swift`: 12 testów czystych funkcji ekranów: odmiana, `StudyFormat`, `CollectionMutations`, `StudyHomeView.decodeModes`, `StudyResumeItem.items`, `AddWordCandidate.group`, `AddWordLogic`, `SettingsImportText`, `ReadingWordLink`.

## 2. Backlog: rozstrzygnięcia

| Punkt | Wynik |
|---|---|
| Haptyka `ConfidencePicker` / `TagChip` | Naprawione (§1). |
| `gradingWord` indeks surowy vs zawinięty | Naprawione w FluentKit + test; normalizacja w UI zostaje (jest zgodna). |
| `ContentSearch`: krotki w typie `Sendable`, lokalna funkcja `add` | Bez zmian, kompiluje się. Krotki z elementów `Sendable` są `Sendable`. Przekazanie lokalnej funkcji jako nie-ucieczkowego parametru jest dozwolone, także gdy mutuje przechwycone zmienne. |
| Testy `TaskInterleaver` vs `interleaveTasks` | Port porównany linia po linii z `learning.ts:482–522` (dominanta `ceil(n/2)`, `canFinish` floor/ceil, sortowanie puli). Wierny, zmian nie trzeba. |
| ui-learning: ryzyka kompilacji | Obszar Features, rozstrzyga code-qa-B (raport `code-qa-B.md`). |
| design-shell §4 | 1: klucz atrybutu `ForegroundColorAttribute` istnieje, OK. 2: typy `private` za `some View` są dozwolone. 3: wzorzec `@Bindable var x = x` z dokumentacji Apple, OK. 4: składnia `package: FluentKit/FluentKitTests` potwierdzona w `ProjectSpec.md`. 5–6: OK. 8: naprawione. 7, 9: bez zmian. |
| Spójność `Services` ↔ `Features` | Grep każdego członu `store./env./speech./pronunciation./reminders./assistant./preferences./reports./router./syncMonitor./content.` w Features: wszystkie istnieją z użytymi sygnaturami. |
| Usunięte słowo w przerwanej sesji | Naprawione w FluentKit (Scheduler, StateMigration) + 3 testy. UI ma „Pomiń” (B). Sesja łączona działała już wcześniej (`saveAnswer` zapisuje odpowiedź bez oceny), teraz pokrywa to test. |
| ui-library: ryzyka kompilacji | Features, rozstrzyga B. |
| API spoza `CONTRACTS.md` | `refreshReminders()`, `SyncStatus.titlePl/detailPl/systemImage`, `AssistantProvider.detailPl`, `refreshAvailability()`, `appleOnDeviceUnavailableReason`, `.previewEmpty`: wszystkie istnieją z tymi sygnaturami. |
| Testy czystych funkcji ui-library | Dopisane (`FeaturePureFunctionTests`, 12 testów). Niepokryte: `WordListBuilder.build`, `WordDraft`, `StudySummaryData.make`, `TodayOnboardingView.starterEntryIDs`. |
| Wspólny wiersz-checkbox, tokeny heatmapy (opcjonalne) | Pominięte, poza zakresem tej fali. |
| platform-services §4–§5 | (1) Powiadomienia sync SwiftData: bez zmian, zabezpieczenie „co 60 s przy powrocie” istnieje. (4) Foundation Models: flaga awaryjna (§1). (7) Import JSON: warianty w tle (§1). (5) `deinit` w klasach `@MainActor`: w trybie Swift 5 najwyżej ostrzeżenie. |

## 3. Ryzyka: gdzie patrzeć najpierw na Macu

Kolejność według prawdopodobieństwa błędu kompilacji:

1. **`Services/Assistant/AppleOnDeviceAssistant.swift`** (cały plik): `LanguageModelSession(instructions: String)`, `respond(to: String, generating:)`, `@Generable(description:)`, `@Guide`, przypadki `SystemLanguageModel.Availability.unavailable(.deviceNotEligible/.appleIntelligenceNotEnabled/.modelNotReady)`. Aktualna dokumentacja Apple pokazuje już przeciążenia z `model: some LanguageModel` i `Prompt`. Stringowe wersje z iOS 26.0 powinny istnieć, ale tego nie potwierdziłem. **Gdy się nie kompiluje:** dodać `FLUENT_DISABLE_FOUNDATION_MODELS` do `SWIFT_ACTIVE_COMPILATION_CONDITIONS` w `project.yml` (aplikacja działa bez modelu Apple) albo opakować argumenty w `Prompt(...)` / `Instructions(...)`.
2. **`Services/Persistence/CloudKitAvailability.swift:216`**: `getsectiondata(_:_:_:_:)` z `UnsafePointer<mach_header_64>` i `UInt` (tylko symulator). Przy błędzie typu rozmiaru: `var size: UInt = 0` → `UInt(0)`/`unsigned long`. Przy `ENABLE_DEBUG_DYLIB` obraz 0 to zaślepka; jeśli nie ma w niej sekcji `__entitlements`, symulator działa lokalnie, bez crasha.
3. **`Services/Assistant/GeminiAssistant.swift:316–353`**: duże zagnieżdżone literały `[String: Any]` w schematach JSON. Jeśli pojawi się „unable to type-check this expression in reasonable time”, rozbić na zmienne lokalne z jawnym typem `[String: Any]`.
4. **`Services/Persistence/LearningRepository.swift`** (`@ModelActor` z dodatkowymi polami z wartościami domyślnymi, zagnieżdżone funkcje `tick()`/`upsertHistory` przechwytujące `modelContext`). Wzorzec poprawny; sprawdzić ostrzeżenia `Sendable` przy `PersistenceLoadResult`.
5. **`Services/Sync/SyncMonitor.swift:92`, `Services/Speech/SpeechService.swift:66`**: `deinit` w klasie `@MainActor` czyta izolowane pole. W Swift 5 to ostrzeżenie; gdyby było błędem (Swift 6 / nowy Xcode), oznaczyć pola `nonisolated(unsafe)` albo usunąć `deinit` (obiekty żyją przez cały czas działania aplikacji).
6. **`DesignSystem/Components/HighlightedText.swift:176`**: `emphasized[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = highlight`. Alternatywa: `emphasized.swiftUI.foregroundColor = highlight`.
7. **`App/AppEnvironment.swift:199`**: `beginBackgroundTask(withName:expirationHandler:)` z domknięciem używającym klasy `@MainActor`. W SDK handler jest `@MainActor @Sendable`; w Swift 5 możliwe ostrzeżenie.
8. **`project.yml`**: `- package: FluentKit/FluentKitTests` w schemacie (XcodeGen ≥ 2.38, składnia potwierdzona). Jeśli generator protestuje, usunąć linię i uruchamiać `swift test` osobno.
9. **Linkowanie testów aplikacji**: gdyby mimo `DEAD_CODE_STRIPPING: NO` brakowało symboli FluentKit w `FluentNOWTests` (np. przy `ENABLE_DEBUG_DYLIB`), ustawić w targecie testów `ENABLE_TESTABILITY`/`BUNDLE_LOADER` zgodnie z szablonem Xcode. Nie dodawać produktu FluentKit do targetu testów (podwójne typy).

Ryzyka wykonania i logiki (nie da się ich rozstrzygnąć bez urządzenia):

- **Treść**: `topics/index.json` i `dictionary-index.json` są **nieaktualne**: 37 tematów w indeksie przy 62 plikach (`node ios/tools/build-index.mjs --check` → NIEAKTUALNY). Przed buildem uruchomić `node ios/tools/build-index.mjs` (obszar data-pipeline, prośba do koordynatora). `validate-content`: 0 błędów, 38 ostrzeżeń (m.in. „the tube” w `pharmacy.json`, do english-qa).
- **Sync (projekt modelu)**: lista kolekcji, historia odpowiedzi i ustawienia są scalane sumą lub z lokalnego stanu. „Usuń wszystkie dane” albo usunięcie kolekcji na urządzeniu A może zostać cofnięte przez urządzenie B, które ma stare dane w pamięci (słowa są obsłużone przez `removedWordIDs`). Scenariusze 3.8 i 3.9 w planie testów. Pełne rozwiązanie wymaga znaczników usunięcia (tombstone) w rekordach.
- **Konflikt jednego rekordu słowa** edytowanego offline na dwóch urządzeniach: CloudKit stosuje „ostatni zapis wygrywa” na poziomie rekordu (platform-services §4.2).
- `NSPersistentCloudKitContainer.eventChangedNotification` dla kontenera SwiftData: zachowanie nieudokumentowane, zabezpieczeniem jest odświeżenie przy powrocie do aplikacji.
- Testy wydajności w Debug: `testMakeSessionPerformanceOn5000Words` (tryb par < 3 s) i `testContentSearchPerformanceOn20000Records`. Na wolnym Macu w Debug mogą być na granicy; to nie są błędy logiki.
- `FeaturePureFunctionTests` zakłada obecne sygnatury funkcji Features (uzgodnione z B). Jeśli B coś zmienił po moim odczycie, poprawić wywołania w teście.

## 4. Odstępstwa od strony

- `recordAnswer` dla usuniętego słowa przesuwa sesję (strona się wysypywała).
- `advancePractice` / `advanceProduction` wymagają odpowiedzi na bieżące pytanie (strona blokowała to tylko w UI).
- `StateMigration` zachowuje sesję z usuniętym słowem w ukończonej części, dopóki jest coś do wznowienia (strona robi tak samo, iOS wcześniej odrzucał).

## 5. Prośby do innych ról

- **Koordynator / data-pipeline:** uruchomić `node ios/tools/build-index.mjs` po zakończeniu pracy agentów tematów (indeksy nieaktualne, patrz §3).
- **design-shell (README):** dopisać flagę `FLUENT_DISABLE_FOUNDATION_MODELS` jako awaryjne obejście błędu kompilacji Foundation Models oraz to, że w Debug `DEAD_CODE_STRIPPING` jest wyłączone celowo (testy).
- **english-qa:** ostrzeżenia BrE z `validate-content` (np. „the tube” w `pharmacy.json`).
- **platform-services (na przyszłość):** znaczniki usunięcia (tombstone) dla kolekcji i „Usuń wszystkie dane” w synchronizacji.

## 6. Uruchomione skrypty

- Skan interpolacji w łańcuchach (`\(`) we wszystkich 203 plikach Swift: znaleziono 3 zgubione `\` w `ProgressRing.swift` (naprawione).
- Kontrola nawiasów z uwzględnieniem łańcuchów, interpolacji i komentarzy oraz kontrola CR/BOM: 203 pliki, 0 problemów (po moich zmianach).
- Skan `try!` / `as!` / `fatalError` / force-unwrap: brak.
- `node ios/tools/validate-content.mjs`: OK, 76 plików, 0 błędów, 38 ostrzeżeń.
- `node ios/tools/build-index.mjs --check`: NIEAKTUALNY (patrz §3).
- Testy Swift: nieuruchomione (brak kompilatora na Windows).

Uwaga dla kolejnych agentów: w tym środowisku polecenie Bash zamienia `\\` na `\`. Skrypty z ukośnikami wsteczymi trzeba zapisywać narzędziem Write, a nie przez heredoc ani `node -e`. Prawdopodobnie stąd wzięły się zgubione `\(` w `ProgressRing`.
