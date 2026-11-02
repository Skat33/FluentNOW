# code-qa-9 — przegląd po FEEDBACK-8/9 (N5)

Przegląd na Windows bez kompilatora: każde nowe/zmienione API z raportów core-integration, feedback-8, learning-ux i smart-search sprawdzone grepem (sygnatury, etykiety, `switch`, inicjalizatory, izolacja aktorów), skrypt w Node sprawdził wszystkie użycia tokenów design systemu (`Palette`, `Spacing`, `Radius`, `HitTarget`, `FluentFont`, `Motion`, `FluentHaptic`, `Elevation`) w `FluentNOW/` — 0 brakujących. Nie uruchamiano git ani `build-index.mjs`; JSON w `Resources/Content` bez zmian.

Punkt odniesienia: aplikacja była budowana i uruchamiana na Macu do FEEDBACK-8 tura 2 (właściciel ocenił w symulatorze przełącznik grup i okna na środku), więc ryzyka z raportu feedback-8 dotyczące kodu aplikacji uznaję za rozstrzygnięte. Nowy, jeszcze niekompilowany kod: learning-ux (N1/N2), smart-search (N3), core-integration oraz **testy** (target testów nie buduje się przy zwykłym uruchomieniu aplikacji).

## 1. Naprawione błędy

| Plik:linia | Kategoria | Problem | Poprawka |
|---|---|---|---|
| `Packages/FluentKit/Sources/FluentKit/Progression/Progression.swift:290–311, 344–351, 376–449, 462–511` | logika (backlog R2) | XP „dziś”, premia celu dziennego i serii liczone w dniach UTC — nauka 0:00–2:00 czasu PL liczyła się do poprzedniego dnia, 23:00 i 0:30 to był „jeden dzień” | `dayNumber(_:timeZone:)` (przesunięcie strefy); parametr `timeZone: TimeZone? = nil` (nil = UTC, jak dotąd — testy bez zmian) w `ledger`, `totalXP`, `level`, `sessionGain`, `summary` |
| `Profile/ProfileAchievements.swift:101`, `Statistics/WeeklyReport.swift:269–273, 413` | logika | osiągnięcia (najdłuższa seria) i XP tygodnia w dniach UTC, a granice tygodnia raportu w strefie użytkownika | `input(from:timeZone:)`; raport liczy XP w strefie swojego kalendarza |
| `Features/Profile/ProfileScreen.swift:22–24`, `Stats/StatsSnapshot.swift:58`, `Today/TodaySnapshot.swift:52`, `Study/Summary/StudySummaryXP.swift:35` | logika | jw. | przekazują `TimeZone.current` |
| `App/DeepLink.swift`, `App/AppRouter.swift:open/openWeeklyReport`, `Services/Reminders/ReminderService.swift:123` | logika (backlog R4) | powiadomienie „Twój raport tygodniowy” otwierało tylko kartę Postępy | `DeepLink.weeklyReport(weekOffset:)` dla `fluentnow://progress/weekly[?week=N]` (0…11), router: Postępy od korzenia + `StatsRoute.weeklyReport`; nowy link w powiadomieniu |
| `App/AppEnvironment.swift:refreshReminders` | logika | już zaplanowane (powtarzalne) powiadomienia miały stary link do końca świata | przy włączonym raporcie `scheduleWeeklyReport(enabled: true)` przy odświeżaniu przypomnień podmienia je |
| `App/DeepLink.swift:StudyLaunchRequest`, `Study/Support/StudyStarter.swift:startVocabulary/scoped`, `Study/Home/StudyHomeView.swift:consumeLaunchIfReady/startWords`, `Stats/WeeklyReportScreen.swift:102` | logika (backlog R4) | „Powtórz je” w raporcie uruchamiało ogólny tryb pomyłek | `wordIDs` w prośbie; sesja `mixed` budowana na stanie zawężonym do tych słów (`nonisolated StudyStarter.scoped`, bo liczone w `store.compute` poza głównym aktorem); przy przerwanej sesji — dotychczasowe okno „Kontynuuj / Zacznij od nowa” (nie nadpisujemy) |
| `Features/AddWord/AddWordRootScreen.swift:277` | logika / wyścig | `select(term:)` po `await lookup` pokazywał znaczenia starego hasła, gdy w tym czasie zmieniło się pole (pisanie, dyktowanie); podwójne dotknięcie startowało dwa wczytania | `guard !isLoadingLookup`, porównanie `query` przed i po `await` |
| `Features/Today/UsefulWordsCatalog.swift:172` | kompilacja (ryzyko z raportu core-integration) | `withTaskGroup { (group: inout TaskGroup<…>) async -> … in` — jawny typ `inout` w zamknięciu przy nowej sygnaturze z `isolation:` (Xcode 26) | `{ group in … }` (typy wynikają z `of:`/`returning:`) |

## 2. Sprawdzone ryzyka kompilacji z raportów (bez zmian — kod poprawny)

- core-integration: `UsefulWordsCatalog.swift:158` (`Task.detached` → prywatna statyczna metoda aktora — statyczne są nieizolowane), `:273` (`?.entry(id:) != nil`), `ContentLibrary.swift:94/108/135`, `MeaningOptions.swift:81/85` (referencja `TextNormalizer.answerKey` jako `(String) -> String`), `TestLoader.swift:60`.
- smart-search: `FuzzyMatcher` (pasmo OSA, bufor, `if let q1, let c1`, init z krotkami — konwersja krotek bez etykiet do etykietowanych dozwolona), `ContentSearch` (`SearchMatchKind.polishExact` — jedyny `switch` to `isPolish`, wyczerpujący; `HitCollector`, `ArraySlice` krotek, `stableSorted`), `VoiceSearchController` — ten sam wzór co skompilowany `PronunciationService` (`AVAudioApplication.requestRecordPermission()`, `tapBlock`/`resultHandler` `nonisolated static`, sink `@Sendable` z `[weak self]` + `Task { @MainActor in }`), `VoiceSearchControls` (`AppStorage(wrappedValue:_:)`, `alert(_:isPresented:presenting:actions:message:)`, `symbolEffect(.variableColor.iterative, isActive:)`), `WordSuggestionViews`, `WordSearchExtras` (`let` w ViewBuilder), `AddWordSections`, `TopicSearchView`.
- learning-ux: `ScrambleDecoys` (KeyPath do `let` w typie zagnieżdżonym, `static let` z `compactMap`), `SentenceScramble.board` (`self.decoys(...)` w metodzie statycznej, mapy do krotek), `VocabScrambleViews` (`case ..<1`, `ForEach` z krotką), `StudyExerciseTypesCard` (dwa `@Namespace` w `ViewThatFits`, `ScrollViewReader`, `onChange` iOS 17, `accessibilityAddTraits(cond ? [.isSelected] : [])`), wywołania `VocabExerciseContent(…, sessionSeed:)` w sesji, sesji mieszanej i teście.
- Spójność plików zmienianych równolegle: `AddWordModel`/`AddWordSections`/`AddWordRootScreen` (feedback-8 + smart-search) — `AddWordCandidate` zostaje tylko dla testów, `AddWordCandidateRow` usunięty bez odwołań; `ContentLibrary` (core-integration + smart-search) — spójny; `Meaning.mergedContentRefs` — jawny `init` z wartością domyślną na końcu, `Codable` łagodne, wszystkie `Meaning(`/`SenseSuggestion(` poprawne; nowe API `SentenceScramble.decoyCount(word:meaning:wordCount:)` / `board(…seed:pool:)` — wszystkie wywołania w aplikacji i testach zgodne, `decoyWords`, `scrambleHintShown`, `showScrambleHint`, `StudyMoreActivitiesCard`, `StudyExerciseGroup.bank` — brak odwołań.
- Liquid Glass: tylko style przycisków na iOS 26 (`ButtonStyles.swift`), brak `glassEffect` w treści/listach; nowe widoki N2/N3 bez szkła. Transformacja 3D tylko w fiszce (z ochroną kąta 90°).
- Haptyka: wszystkie nowe miejsca przez `fluentSensoryFeedback`; surowe `.sensoryFeedback` (FeedbackPanel, PracticeComponents, StudySummaryView, TodayGoalHaptic) mają warunek z ustawienia.

## 3. Pozostałe ryzyka kompilacji (gdzie patrzeć najpierw na Macu)

1. `FluentNOW/Services/Speech/VoiceSearchController.swift:270–271` — `request.taskHint = .search`, `request.addsPunctuation = false` (iOS 16+; w razie błędu usunąć — domyślne wartości są takie same).
2. `FluentNOWTests/Services/ContentLibraryTests.swift:158–160` — `async let single: TopicFile = library.topic(id:)` bez `try` (SE-0317 pozwala; jeśli kompilator zażąda — `= try await …`).
3. `FluentNOW/Features/Study/Home/StudyExerciseTypesCard.swift:100–101` — metoda struktury `select` przekazana jako `(StudyExerciseGroup) -> Void`.
4. `FluentNOW/Features/Words/WordListView.swift:29` — `ToolbarItem(.topBarLeading)` w widoku-dziecku obok pasków z `WordsRootScreen` (kompiluje się; sprawdzić tylko układ).
5. **Testy (target nigdy nieskompilowany po FEEDBACK-8)**: `FluentNOWTests/StudyLayout/StudyLayoutTests.swift:190` (subskrypt `FontAttribute` na `Run`), `SmartSearchTests`, `ScrambleDecoysTests`, `SenseGroupingTests`, `FreshStartTests` — sygnatury sprawdzone, ale uruchomić `swift test` w `Packages/FluentKit` i schemat testów aplikacji jako pierwsze.

## 4. Testy

- FluentKit `ProgressionTests.testDaysFollowTheUsersTimeZone` — odpowiedź 23:30 UTC to „dziś” w Warszawie, a nie w UTC; 23:00 i 0:30 czasu PL to dwa dni lokalne (premia serii) i jeden dzień UTC; `dayNumber(_:timeZone: nil)` = UTC.
- Aplikacja `ShellTests` (`DeepLinkTests.testWeeklyReportLink`, `testRouterOpensWeeklyReportOnProgressTab`) — parsowanie `progress/weekly`, `stats/Weekly?week=2`, przycięcie zakresu, link z `ReminderService`, router przełącza kartę, zamyka arkusz i dokłada trasę.
- Aplikacja `CodeQA/CodeQA9Tests` (nowy) — `StudyStarter.scoped` (pusty zbiór = bez zmian, nieistniejące ID pomijane), sesja z zawężonego stanu zawiera tylko wskazane słowa, `StudyLaunchRequest.wordIDs`.
- Przejrzane pod kątem zgodności z API: `SmartSearchTests`, `ScrambleDecoysTests` (każde oczekiwanie przeliczone ręcznie wg reguł `ScrambleDecoys`), `SenseGroupingTests`, `FreshStartTests`, `SmartSearchAppTests`, `ContentLibraryTests` (nowe testy core), `StudyLayoutTests` (grupy N2).
- Nic nie uruchomione (brak Swifta na Windows).

## 5. Zamknięte pozycje backlogu (`docs/CODE-QA-BACKLOG.md`, z notami)

- haptyka `ConfidencePicker`/`TagChip` (już przez `fluentSensoryFeedback`);
- `gradingWord` i indeks przykładu (FluentKit zawija);
- `ContentSearch` — krotki i lokalna `add` (przepisany w N3, sprawdzony);
- przerwana sesja ze słowem usuniętym (ścieżka `missingTask`/`skipMissing`/przesunięcie indeksu w `commit` sprawdzona);
- ryzyka kompilacji ui-learning, design-shell, ui-library, rundy 1–2 oraz API platform-services — rozstrzygnięte buildem na Macu;
- **XP/seria/cel w dniach kalendarza użytkownika**; **deep link raportu tygodniowego**; **`StudyLaunchRequest.wordIDs`**.

Otwarte zostają m.in.: etap „tylko tekst” czytanki w sesji łączonej, `verify-export.mjs`/`glossary`, filtr zdjęć, testy skanowania, nadpisania eksportu starter-words.

## 6. Do sprawdzenia ręcznie

- Prośba smart-search: na urządzeniu szybkie przełączanie nagrywanie (Dodaj słowo) → odsłuch wymowy → nagrywanie; muzyka w tle wraca po nagraniu.
- Raport tygodniowy: włączony przełącznik → przejście aplikacji w tło → w Ustawienia/Powiadomienia oczekujące powiadomienie ma link `progress/weekly`; dotknięcie otwiera raport. „Powtórz je” — sesja zawiera tylko słowa z listy.
- Po północy czasu PL: Dzisiaj pokazuje XP z nauki po 0:00 jako „dziś”.

## 7. Propozycje ulepszeń

1. **Cel dzienny i seria z „przerwą” (streak freeze)** — 1 dzień zwolnienia na tydzień, liczony z historii (bez licznika do synchronizacji). Utrzymuje motywację po jednym opuszczonym dniu; to najczęstszy powód porzucenia aplikacji do nauki. **M**
2. **Dystraktory „Wybierz znaczenie” poza głównym wątkiem** — `MeaningOptions.options` przechodzi po wszystkich słowach i słowach startowych z kluczami `PolishAnswerIndex` + kluczami luźnymi przy każdym zadaniu (i `preloadNext`) na `@MainActor`; przy kilku tysiącach słów to kilkanaście ms na przejście. Liczyć w `store.compute` albo cache indeksu kluczy per `store.revision`. **S/M**
3. **Indeks podpowiedzi rozgrzany przy starcie arkusza „+”** — pierwsze `suggestions` czeka na budowę `ContentSearch` (~100 ms+ na starszym iPhonie); wywołać `content.warmUp()`/`readySearchIndex` już przy otwarciu arkusza i pokazać szkielet listy. **S**
4. **Powtórka zdań z błędów (error log)** — zapamiętywać konkretne błędne odpowiedzi (np. „went → gone” z rozsypanki, literówki w przypominaniu) i pokazywać je w trybie pomyłek jako „Twoje typowe błędy” z wyjaśnieniem. Lepsza informacja zwrotna niż sam licznik `wrong`. **M**
5. **Dystraktory rozsypanki zależne od historii ucznia** — jeśli uczeń mylił „in/on/at”, preferować dystraktor tego rodzaju (`ScrambleDecoyKind` + statystyka błędów), adaptacyjna trudność. **M**
6. **Widżet ekranu głównego i Live Activity** (WidgetKit, iOS 17): liczba powtórek na dziś, seria, „słowo dnia” z wymową; dotknięcie = deep link `study/start`. Silny bodziec powrotu do aplikacji. **M**
7. **Skróty Siri / App Intents** („Powtórz słówka”, „Dodaj słowo…” z dyktowaniem) — korzysta z istniejących deep linków; pojawia się w Spotlight i Akcjach. **S/M**
8. **Tryb „5 słów przed snem” z przypomnieniem wieczornym** — krótka sesja z najbardziej zaległych słów, osobna pora przypomnienia; FSRS korzysta ze snu (konsolidacja). **S**
9. **Wymowa z oceną w sesji (opcjonalny etap)** — `PronunciationService` już istnieje; dodać zadanie „Powiedz zdanie” po poprawnym „Ułóż zdanie”, wynik nie wlicza się do opanowania (jak na stronie). **M**
10. **Eksport/backup do pliku z harmonogramem** (Pliki/iCloud Drive, co tydzień) i import z wykrywaniem konfliktów — niezależne od CloudKit zabezpieczenie danych przy problemach z kontem iCloud. **M**
11. **Telemetria błędów lokalna (bez sieci)** — rejestr nieudanych dekodowań treści, błędów `ContentError` i stanów `missingTask` w Ustawienia → Diagnostyka, z przyciskiem „Wyślij zgłoszenie” (mail z załącznikiem). Szybsza diagnoza problemów z Maca/urządzenia. **S**
12. **Test UI (XCUITest) krytycznej ścieżki** — pierwsze uruchomienie → dodanie słowa → sesja → przerwanie → wznowienie → podsumowanie; uruchamiany w `run-mac.sh --test`. Złapie regresje, których nie widać bez kompilatora na Windows. **M**
13. **„Czy chodziło Ci o…?” w odpowiedziach przypominania** — `FuzzyMatcher` (już w FluentKit) do odróżnienia literówki od innego słowa w ocenie „Przypomnij sobie” (dziś `levenshtein` z progiem); spójne progi z wyszukiwaniem i lepsze komunikaty „prawie”. **S**
14. **Słownik osobisty z kolekcją „Z czytanek” i „Z wyszukiwania głosowego”** — automatyczne tagi źródła słowa (czytanka, skan, głos, raport) i filtr w Słowniku; ułatwia powtórkę słów z konkretnego kontekstu. **S**
15. **Dostępność: ogłaszanie wyniku zadania i postępu sesji** (`AccessibilityNotification.Announcement` po „Sprawdź”, „Zadanie 4 z 12”), rotor VoiceOver po kafelkach rozsypanki. **S**
