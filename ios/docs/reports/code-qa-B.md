# Raport: code-qa B (fala 3) — `ios/FluentNOW/Features/`

Zakres: 82 pliki Swift (Today, Words, AddWord, Topics, Collections, Stats, Settings, Study, Reading, Practice), ok. 13 tys. linii.
Metoda: przeczytanie każdego pliku w całości z listą kontrolną kompilacji SwiftUI; każdy symbol z FluentKit / Services /
App / DesignSystem sprawdzony grepem w **kodzie źródłowym** (nie tylko w raportach): nazwy, etykiety, typy zwracane,
`async`/`throws`, wartości domyślne, `Identifiable`/`Hashable` dla `ForEach`/`sheet(item:)`, rejestracje
`navigationDestination` per stos, wstrzykiwanie `@Environment(Type.self)`, API iOS 17+ vs nowsze.
Kompilatora nie ma — patrz §4 (miejsca do sprawdzenia na Macu w pierwszej kolejności).

## 1. Tabela poprawek

| plik:linia | kategoria | problem | poprawka |
|---|---|---|---|
| `Study/Session/VocabSessionModel.swift:92–111` (`commit`) | logika (blokada) | `Scheduler.recordAnswer` zwraca stan **bez zmian**, gdy słowa/znaczenia już nie ma (usunięte w Słowniku lub na innym urządzeniu między wyświetleniem a „Dalej”). `session.index` nie rośnie → ekran stoi na tym samym zadaniu, „Dalej” nic nie robi (backlog: usunięte słowo w przerwanej sesji). | W tym samym `update(.answer)`: jeśli indeks sesji się nie zmienił, przesuwamy go o 1 sami. |
| `Study/Session/VocabSessionModel.swift:57–64` (`sync`) | logika | Po usunięciu słowa w trakcie zadania (zmiana `revision`) model zadania zostawał (ten sam klucz) — użytkownik odpowiadał na nieistniejące słowo. | `sync` sprawdza istnienie słowa+znaczenia bieżącego zadania; brak → karta „To słowo nie jest już dostępne / Pomiń zadanie”. |
| `Study/Session/VocabSessionModel.swift:118–128` (`skipMissing`) | logika (podwójne tapnięcie) | Dwa szybkie dotknięcia „Pomiń zadanie” pomijały także **następne, poprawne** zadanie. | Pomija tylko, gdy słowo bieżącego zadania naprawdę nie istnieje. |
| `Practice/PracticeSetView.swift:249–262` (`advance`) | logika (podwójne tapnięcie) | `PracticeFlow.advancePractice` nie sprawdza, czy bieżące pytanie ma odpowiedź → podwójne dotknięcie „Następne pytanie” przeskakiwało pytanie (a na końcu kończyło zestaw z pustą odpowiedzią). | Strażnik w `update`: ten sam zestaw, ten sam indeks i odpowiedź ≥ 0. |
| `Practice/ProductionPracticeView.swift:186–199` (`advance`) | logika (podwójne tapnięcie) | To samo dla `advanceProduction`. | Strażnik: ta sama sesja, ten sam indeks, wynik ≠ nil. |
| `Today/TodayRootScreen.swift:14–19, 33` + `Today/TodayOnboardingView.swift:8` | logika/UX | Onboarding pokazywany przy `words.isEmpty`; po pierwszej partii dodanych słów warunek przestawał być spełniony → ekran z paskiem postępu znikał w połowie, dodawanie trwało „niewidocznie”. | Stan `isAdding` przeniesiony do `TodayRootScreen` (`@Binding`); onboarding widoczny, dopóki trwa dodawanie. **Zmiana inicjalizatora:** `TodayOnboardingView(isAdding:)`. |
| `Today/TodayRootScreen.swift:63–67` | logika/haptyka | Haptyka „cel osiągnięty” wyzwalana przy każdym starcie aplikacji (migawka `nil` → `true` liczona jak przejście false→true) i bez względu na „Wibracje”. | Wyzwalacz `Bool?`, warunek `old == false && new == true && preferences.hapticsEnabled`. |
| 12 miejsc `.sensoryFeedback(…, trigger:)` bez warunku: AddWordRootScreen, ReadingQuestionCard, SettingsImportScreen, SettingsSections, StudyReportButton, StudyModeCard, StudySetupCard, TodayOnboardingView, TodaySections, TopicDetailScreen, WordDetailScreen, WordEditorSheet | dostępność/ustawienia | Haptyka ignorowała przełącznik „Wibracje”. | `.fluentSensoryFeedback(…)` (nowe API code-qa A, czyta `\.fluentHapticsEnabled`). |
| `Study/Session/VocabSessionView.swift:20–22`, `Study/Combined/CombinedSessionView.swift:20–22` + `suspend()` w obu modelach | anulowanie Task | Zamknięcie sesji (X) w trakcie „Asystent sprawdza…” zostawiało działające zapytanie AI (do 20 s sieci). | `.onDisappear { model?.suspend() }` → `cancelPendingWork()`. Stan sesji bez zmian. |
| `Settings/SettingsExportScreen.swift:63–72` | wydajność | Eksport JSON/CSV kodowany synchronicznie na głównym wątku przy wejściu w ekran (duży słownik = przycięcie). | `exportJSONFileInBackground()` / `exportAnkiCSVFileInBackground()` (platform-services), `.task { await prepare() }`. |
| `Reading/ReadingPracticeView.swift:16–17, 29–31, 40–44` | wydajność | `LevelEstimator.estimatedLevel(store.state)` (przegląd całego słownika) w `body` przy każdym renderze (każde zaznaczenie odpowiedzi). | Liczone w `.task(id: store.revision)` przez `store.compute`, trzymane w `@State`. |
| `Study/Home/StudyModeCard.swift:50–51` | kompilacja (ryzyko) | `accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)` — ternarny literał tablicowy vs element `OptionSet` (zgłoszone przez ui-learning jako niepewne). | Dwa wywołania: `.isButton` + `isSelected ? .isSelected : []` (wzorzec używany w reszcie modułu). |
| `Study/Session/VocabSessionView.swift:98` | kompilacja (ryzyko) | Przekazanie metody `@MainActor` klasy (`model.skipMissing`) jako `() -> Void`. | Domknięcie `{ model.skipMissing() }`. |
| `Words/WordEditorSheet.swift:106`, `Reading/ReadingPracticeView.swift:106`, `Study/Combined/CombinedSessionModel.swift:88,108`, `VocabSessionModel.swift:92,119`, `Practice/*:254/191` | kompilacja (ryzyko) | Wieloinstrukcyjne domknięcia `store.update { state in … guard … return }` z generycznym `R` wnioskowanym z treści (SE-0326). | Jawny typ `(state: inout LearnerState) -> Void`. |
| `Settings/SettingsImportScreen.swift` (`preparePreview`, `apply`) | wydajność / podwójne tapnięcie | Dekodowanie kopii JSON (do 8 MB) na głównym wątku przy podglądzie i imporcie; „Importuj” można było dotknąć dwa razy. | `previewImportJSONInBackground` / `importJSONInBackground` (nowe API A) + strażnik `isWorking`. |
| `Settings/SettingsSections.swift:69` | język | „\(goal) zadań” — błędna odmiana dla celów 22–24, 32–34 itd. (cel spoza listy). | `LibraryText.count(goal, one:few:many:)`. |

Wszystkie zmiany tylko w `Features/`. Skrypty po zmianach: bilans nawiasów/ciągów z interpolacją (lexer Node) 82/82 OK,
brak CR/BOM, brak `try!`/`as!`/`fatalError`/force-unwrap, brak duplikatów nazw typów w module aplikacji (269 deklaracji)
i brak typów zasłaniających publiczne typy FluentKit.

## 2. Backlog (pozycje dotyczące Features) — rozstrzygnięcia

- **Usunięte słowo w przerwanej sesji** — naprawione w UI (tabela, 3 pierwsze wiersze). Sesja łączona: `CombinedSessionBuilder.saveAnswer` pomija `recordAnswer` dla brakującego słowa i zapisuje odpowiedź → `advance` działa (sprawdzone w źródle); brak blokady. Prośba do A: poprawka w FluentKit (`recordAnswer` przesuwa sesję także dla brakującego słowa) + testy regresji (wysłane).
- **ui-learning ryzyka kompilacji**: (a) atrybuty `UnderlineStyleAttribute`/`ForegroundColorAttribute` — poprawna forma subskryptu po typie klucza (`AttributedString[K.self]`), zostawione; (b) wywołania `@MainActor` z domknięć gestów — przy SDK iOS 18+/26 `View`/`ViewModifier` są `@MainActor`, domknięcia dziedziczą izolację; jedno ryzykowne przekazanie metody zamienione na domknięcie; (c) `@FocusState private var` bez wartości początkowej — prywatne opakowania z domyślną inicjalizacją nie zawężają memberwise init (ten sam mechanizm co `@State private var x = …`), zostawione; (d) `accessibilityAddTraits` — poprawione.
- **ui-library ryzyka kompilacji**: `if case .failed(let m) = store.loadPhase` w `@ViewBuilder` — wspierane przez result buildery (zostawione); `.disabled` na przyciskach w `alert` — działa od iOS 16, akcje i tak sprawdzają warunek; `.searchable` w widokach pod segmentem — patrz §4.
- **Spójność kontraktu Services ↔ Features** — każde wywołanie sprawdzone grepem: `LearningStore` (update/compute/now/word/activeWords/settings/revision/loadPhase/lastSaveError/retryFailedSave/import*/export*/deleteAllData/syncMonitor), `ContentLibrary` (topicIndex/topic/search/lookup/answerVariants/polishAnswerIndex/starterWords/practiceContent/recommendations), `SpeechService`, `PronunciationService` (+ `Permission`), `ReminderService` (+ `Authorization`), `AssistantService`, `AppPreferences`, `ExerciseReportStore`/`ExerciseReport(init z domyślnymi id/createdAt)`, `AppRouter`, `StudyLaunchRequest`, `LibraryDestination`, `QuickAddButton`. Wszystko zgodne.
- **API spoza CONTRACTS.md używane przez ui-library** (`refreshReminders()`, `SyncStatus.titlePl/detailPl/systemImage`, `AssistantProvider.detailPl`, `refreshAvailability()`, `appleOnDeviceUnavailableReason`, `.previewEmpty`, `fluentPreviewEnvironment(_:router:)`) — istnieją z tymi sygnaturami.
- **Haptyka mimo wyłączenia** — po stronie Features naprawione (`fluentSensoryFeedback`); komponenty DesignSystem poprawił A.
- **Testy czystych funkcji ui-library/ui-learning** — katalog testów należy do A; lista funkcji + uwaga o `@MainActor` (statyczne funkcje typów `View` są izolowane na SDK iOS 18+) przekazane A.

## 3. Sprawdzone bez zmian (najważniejsze)

- `navigationDestination`: `WordRoute/CollectionRoute/TopicRoute` rejestrowane raz na stos (Dzisiaj, Słownik, Postępy — w podglądach osobno); `StudyRoute` w `StudyHomeView`; `SettingsRoute` w `SettingsRootScreen`. Brak zdublowanych rejestracji w jednym stosie; brak `NavigationLink(value:)` bez rejestracji w danym stosie (pełny ekran sesji nie ma linków wartości). Modyfikatory na kontenerach zewnętrznych (nie wewnątrz leniwych list).
- Przepływ sesji słownictwa: odpowiedź → `recordAnswer` w `update(.answer)` (natychmiastowy zapis) → `sync` → następne → podsumowanie → „Zakończ” czyści `state.session`; wznowienie po zabiciu z `state.session`. Sesja łączona: zapis + `advance` w jednym `update`. Czytanie/zestawy/produkcja przez `PracticeFlow`.
- Podwójne tapnięcia: „Dalej”/„Pamiętam” (strażnik `outcome`), „Następne zadanie” w sesji łączonej (`pendingAnswer` nowego zadania = nil), „Sprawdź odpowiedzi” w czytance (`submitReading` ignoruje drugi raz), „Dodaj” w szybkim dodawaniu (stan czyszczony synchronicznie), dodawanie tematu (`isAdding`).
- Bezpieczne indeksowanie (`studyItem(at:)`, `libraryItem(at:)`, `indices.contains`), dzielenie przez zero (`ProgressMath`, `max(1, …)`, `guard total > 0`), `Int(NaN)` w zegarze.
- Dostępność: etykiety przycisków-ikon, `accessibilityElement(children:)`, ogłoszenia wyniku, ukryty zegar dla VoiceOver, `AnyLayout` przy rozmiarach dostępności, `Motion.resolved` przy „Ogranicz ruch”.
- API nowsze niż iOS 17: brak w Features (wszystko iOS 16–17: `sensoryFeedback`, `onChange(initial:)`, `ViewThatFits`, `AnyLayout`, `ShareLink`, `presentationDetents(selection:)`, `AccessibilityNotification.Announcement`, Swift Charts). `#available` niepotrzebne.

## 4. Ryzyka do sprawdzenia na Macu (kolejność)

1. **`.searchable` w widokach osadzonych pod segmentem** — `Features/Words/WordListView.swift:21`, `Features/Topics/TopicsRootScreen.swift:33`. Powinno trafić do paska nawigacji karty Słownik; jeśli pole nie pojawi się na iOS 17 lub będzie migać przy zmianie segmentu — przenieść `.searchable` do `WordsRootScreen` (tekst przekazany w dół).
2. **Atrybuty linków w czytance** — `Features/Reading/ReadingPassageCard.swift:155–156`. W razie błędu typu: `piece.swiftUI.underlineStyle = .single`, `piece.swiftUI.foregroundColor = Palette.accent`.
3. **`VocabFeedbackSummary.init` oznaczony `@MainActor`** — `Features/Study/Session/VocabFeedbackView.swift:250`, wołany z `VocabExerciseView.announceResult()` (`VocabExerciseView.swift:68`). Bezpieczne przy SDK iOS 18+/26 (View = `@MainActor`); przy starszym Xcode dopisać `@MainActor` do `announceResult`.
4. **Gest fiszki w `ScrollView`** — `Features/Study/Session/VocabExerciseView.swift:161` (`simultaneousGesture(…, including:)`): sprawdzić na urządzeniu, że pionowe przewijanie działa, a poziomy ruch ≥ 110 pt zatwierdza.
5. **Ternarne literały `LocalizedStringKey`/`String`** w `Label`/`Text` z interpolacją (np. `Topics/TopicCard.swift:45`) — powinny się wybrać jako `LocalizedStringKey`; w razie niejednoznaczności owinąć w `String(…)`.
6. **Wielokrotne zamknięcia końcowe** `TopicHeaderCard(…) { … } onClear: { … }` — `Features/Topics/TopicEntriesList.swift:30–35` (składnia SE-0279, powinna działać).
7. **Onboarding** — `TodayOnboardingView` ma teraz `init(isAdding: Binding<Bool>)`; jeśli test A tworzy ten widok, dostosować.
8. Zachowanie (nie kompilacja): `StudyExplanationDisclosure` ustala rozwinięcie raz przy utworzeniu — po „Uznaj moją odpowiedź” zostaje rozwinięte (kosmetyka); `SettingsVoiceScreen` nie przesortowuje listy głosów po zmianie akcentu do ponownego wejścia; przełącznik „Nie trudne” zdejmuje tylko flagę `hard` — słowo trudne z wyników (`isHardByScores`) nadal ma status „Trudne”.

## 5. Prośby do innych ról (wysłane do code-qa-A)

**Stan:** A potwierdził realizację (1) i (2) w FluentKit z testami (`Packages/FluentKit/Tests/FluentKitTests/CodeQARegressionTests.swift`):
`recordAnswer` przesuwa sesję dla brakującego słowa bieżącego zadania (strażnik UI `current.index == expectedIndex` zapobiega
podwójnemu przesunięciu), `advancePractice/advanceProduction` nic nie robią bez odpowiedzi; dodatkowo `StateMigration` nie odrzuca
już wstrzymanej sesji, której ukończony prefiks wskazuje usunięte słowo. Testy czystych funkcji Features:
`FluentNOWTests/CodeQA/FeaturePureFunctionTests.swift` (`@MainActor`) — sygnatur z listy poniżej nie zmieniać bez uzgodnienia.

- FluentKit: `Scheduler.recordAnswer` — przesuwać `session.index` także dla brakującego słowa (+ test); test `CombinedSessionBuilder.saveAnswer/advance` z usuniętym słowem.
- FluentKit: `PracticeFlow.advancePractice/advanceProduction` — strażnik „bieżące zadanie ma odpowiedź” (+ test).
- Testy (FluentNOWTests): `WordListBuilder.build`, `WordDraft.issues/applied`, `CollectionMutations`, `AddWordLogic.*`, `AddWordCandidate.group`, `LibraryText.plural`, `StudyFormat.*`, `StudyHomeView.decodeModes`, `TodayOnboardingView.starterEntryIDs`, `SettingsImportText.looksLikeJSON`, `ReadingWordLink.url/wordID`, `StudyResumeItem.items(in:)`, `StudySummaryData.make` — klasy testów `@MainActor` (statyki typów `View`).

## 6. Plan testów ręcznych

Scenariusze ekranów: sekcja „## 6. Ekrany (code-qa-B)” w `ios/docs/MANUAL-TEST-PLAN.md` (dołączona przez code-qa-A; osobny plik `MANUAL-TEST-PLAN-screens.md` usunięty).
(11 sekcji, ok. 75 kroków: onboarding, Dzisiaj, Słownik, **usunięte słowo w przerwanej sesji**, szybkie dodawanie,
tematy/kolekcje, wszystkie typy zadań, sesja łączona, wznowienie po zabiciu, AI, wymowa, czytanie/gramatyka/produkcja,
Postępy, Ustawienia, VoiceOver, Dynamic Type AX5, iOS 17 vs 26). Do scalenia przez A.
