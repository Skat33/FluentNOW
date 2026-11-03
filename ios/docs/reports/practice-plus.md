# practice-plus — raport (FEEDBACK-10 P1, P2, P3)

Kod pisany na Windows bez kompilatora Swift. Każdą użytą sygnaturę sprawdziłem grepem, a wszystkie `switch`, których dotyczą nowe przypadki enumów, poprawiłem (`HistoryKind.mistake`, `StatsRoute.mistakes`; nowe enumy `MistakeKind` mają `switch` tylko w nowym kodzie, każdy wyczerpujący). Zmienione pliki przeszły kontrolę nawiasów z obsługą stringów i interpolacji (skrypt w scratchpadzie). Nie mają BOM ani CR. Nie uruchamiałem `build-index.mjs`. Nie zmieniałem plików JSON w `Resources/Content`.

Uwaga: w trakcie pracy przypadkiem uruchomiłem jedno polecenie git tylko do odczytu (`git status`, bez zmian w repozytorium).

## 1. Zmiany (plik → zmiana)

### FluentKit

| Plik | Zmiana |
|---|---|
| `Models/MistakeLog.swift` (nowy) | Dziennik błędów i typy pomocnicze (szczegóły pod tabelą). |
| `Grading/MistakeClassifier.swift` (nowy) | Klasyfikator błędów, czyste funkcje (szczegóły pod tabelą). |
| `Sessions/MistakePractice.swift` (nowy) | „Przećwicz”: sesja `mistakes` z dziennika (szczegóły pod tabelą). |
| `Grading/PronunciationScoring.swift` (nowy) | Wynik wymowy słowo po słowie (szczegóły pod tabelą). |
| `Models/LearnerState.swift` | `mistakes: [MistakeEntry]`. Nowy parametr `init` z wartością domyślną, na końcu listy. Dekodowanie przez `lossyArray`, więc brak klucza daje `[]`. Pole jest zawsze kodowane. |
| `Models/VocabSession.swift` | `decoyFocus: MistakeKind?`. Parametr `init` ma wartość domyślną `nil`. Dekodowanie łagodne: nieznana wartość daje `nil`. `nil` nie jest zapisywane (`encodeIfPresent`). |
| `Sync/StateSync.swift` | `mergeStates` scala dziennik przez `MistakeLog.merge`. |
| `ImportExport/StateMigration.swift` | `mistakes = MistakeLog.normalized(...)`, czyli usuwa duplikaty, ustala kolejność i przycina do limitu. |
| `Sessions/ScrambleDecoys.swift` | `choose(…, prefer:, using:)` przesuwa grupę preferowanego rodzaju na początek (`preferring`). Przetasowania RNG są bez zmian, więc bez `prefer` plansze są identyczne jak wcześniej. |
| `Sessions/SentenceScramble.swift` | `board(…, pool:, prefer: ScrambleDecoyKind? = nil)` i `decoys(…, prefer:)`. |
| `Grading/VocabularyGrader.swift` | Zmiany w `localGrade` (szczegóły pod tabelą). |
| `Sessions/MeaningOptions.swift` | P3: `MeaningOptionsIndex` i nowa przeciążona wersja `options` (szczegóły pod tabelą). |
| `Tests/MistakeLogTests.swift` (nowy) | 22 testy (§3). |

**`MistakeLog.swift`** zawiera:
- `MistakeKind` (String, Codable). Rodzaje błędów:
  - `verbForm`;
  - `preposition`;
  - `article`;
  - `typo`;
  - `otherWord`;
  - `wordOrder`;
  - `meaning`.

  Każdy rodzaj ma `namePl`, `explanationPl` (po polsku, z przykładem) i `decoyKind`.
- `MistakeEntry`. Pola: `id`, `at`, `exercise`, `kind`, `expected`, `given`, `expectedPart`, `givenPart`, `wordId`, `meaningId`, `example`, `context`. Dekodowanie łagodne:
  - nieznany rodzaj daje `.otherWord`;
  - wpis z nieznanym typem zadania albo bez `id` jest pomijany.
- `MistakePair`.
- `MistakePattern`. Właściwości: `headlinePl` („Mylisz in / on / at”), `countPl` („7 razy” / „1 raz”), `summaryPl`, `confusedWords`.
- `MistakeLog`:
  - `limit = 500`;
  - `normalized`: unikalność po `id`, sortowanie po (`at`, `id`), 500 najnowszych;
  - `merge(local:remote:)`;
  - `recording(_:in:)`;
  - `entry(…)`: przycina teksty do 240 znaków;
  - `decoyFocus`: spośród 100 najnowszych błędów rodzaju, dla którego istnieje dystraktor, rodzaj z co najmniej 2 wystąpieniami; przy remisie wygrywa kolejność enumu;
  - `withDecoyFocus(_:state:)`;
  - `patterns(_:exampleLimit:)`.

**`MistakeClassifier.swift`**:
- `classify(expected:given:focusIsVerb:)` dla odpowiedzi EN (słowo, fraza, zdanie). Najpierw różnica multizbiorów słów. Gdy wynik to „inne słowo”, sprawdza jeszcze, czy cała odpowiedź nie jest literówką.
- `classify(expectedTokens:givenTokens:)` dla rozsypanki:
  - te same słowa w innej kolejności dają `wordOrder`;
  - inaczej wybierany jest najbardziej wymowny rodzaj spośród podmienionych słów;
  - słowo dodane albo pominięte (np. „the”) daje przedimek lub przyimek.
- `classifyPolish`: literówka albo znaczenie; polskie znaki są ignorowane.
- `classifyWord`.
- `areVerbForms`: tabela `ScrambleDecoys.irregularVerbs`, do tego be/have/do/get i czasowniki z wariantami form, oraz regularne `-ed`/`-ing`. Samo „-s” liczy się tylko przy `focusIsVerb`, bo może to być liczba mnoga rzeczownika.
- `isTypo`: progi `FuzzyMatcher.maxDistance` i odległość OSA.
- `closest`.
- `feedbackPl`.

**`MistakePractice.swift`**:
- Do 4–12 zadań, najnowsze najpierw, jedno na znaczenie.
- Pomija słowa usunięte i zarchiwizowane.
- Typ zadania zależy od rodzaju błędu:

| Rodzaj błędu | Zadanie |
|---|---|
| forma czasownika, przyimek, przedimek, kolejność | „Ułóż zdanie” z tym samym zdaniem (gdy się nie da: luka, potem tłumaczenie) |
| literówka, inne słowo | to samo zadanie z wpisywaniem, z którego pochodzi błąd |
| znaczenie | „Wybierz znaczenie” |

- `decoyFocus` to rodzaj ćwiczony w sesji.
- Tryby uruchomienia `mistake-patterns[:<rodzaj>]`, odczyt przez `request(fromLaunchMode:)`.

**`PronunciationScoring.swift`**:
- Dopasowanie słów przez LCS kluczy, więc pominięte słowo nie przesuwa pozostałych.
- Rozwija skróty (`I'm` = „I am”).
- Dzieli słowa z łącznikiem.
- Liczby 0–20 porównuje ze słowami.
- `verdictPl`.

**`VocabularyGrader.localGrade`**:
- Literówka korzysta z `FuzzyMatcher`: 1 edycja dla 3–5 liter, 2 dla 6+, zamiana sąsiednich liter liczy się jako 1. Wcześniej było to 4–7 → 1, 8+ → 2, a długość 3 nie dopuszczała literówki.
- Inna forma czasownika (made ↔ make) nigdy nie jest literówką.
- Nowe komunikaty:
  - „Prawie — to literówka. Poprawna pisownia: …”;
  - podpowiedź dla formy czasownika, przyimka lub przedimka (`feedbackPl`).

**`MeaningOptions.swift` (P3)**:
- `MeaningOptionsIndex` (Sendable) przechowuje dla każdego kandydata klucze odpowiedzi, kolekcję, część mowy i poziom.
- `options(index:word:meaning:task:sessionIndex:answerIndex:)`.
- Dotychczasowe `options(state:…)` buduje indeks i woła nową wersję. Semantyka jest 1:1: najpierw słowa ucznia z wykluczeniem po id znaczenia, potem słowa startowe, ta sama kolejność sortowania i to samo ziarno.

### Aplikacja

| Plik | Zmiana |
|---|---|
| `Services/Persistence/Records.swift` | `HistoryKind.mistake`: jeden `HistoryRecord` na wpis. Starsze wersje aplikacji pomijają nieznany rodzaj i go nie kasują. |
| `Services/Persistence/LearningRepository.swift` | Wczytanie (`case .mistake`, potem `MistakeLog.normalized`) i zapis. Zapisany wpis nie jest ponownie kodowany, bo wpisy się nie zmieniają. Wpisy usunięte przez limit są kasowane z magazynu i iCloud jak inne historie. |
| `Services/Speech/AudioFocus.swift` (nowy) | Jedno źródło dźwięku naraz. `claim(by:)` wysyła powiadomienie. Obserwatorzy (`queue: nil` + `MainActor.assumeIsolated`) zatrzymują się **synchronicznie**, zanim nowe źródło aktywuje sesję `AVAudioSession`. |
| `Services/Speech/SpeechService.swift` | `claim` przed `.playback`; obserwator → `stop()`. |
| `Services/Speech/PronunciationService.swift` | `claim` przed nagraniem; obserwator → `stopIfListening()`; obsługa przerwań (połączenie); `isInputAvailable`; `listen(expected:maxDuration: = 6)`. |
| `Services/Speech/VoiceSearchController.swift` | `claim` przed nagraniem; w czasie nagrania obserwator → `cancel()`, usuwany w `teardown()`. |
| `Services/Preferences/AppPreferences.swift` | `pronunciationPracticeEnabled` (domyślnie wł., `fluent.pronunciationPracticeEnabled`, reset). |
| `Services/Content/ContentLibrary.swift` | `prepareSuggestions()` (P3). |
| `Features/Settings/SettingsSections.swift` | Sekcja „Wymowa”: przełącznik „Ćwicz wymowę w sesjach” i stopka z opisem. |
| `Features/Study/Session/VocabExerciseModel.swift` | Pierwsza błędna odpowiedź: `firstWrongAnswer`, `firstWrongWasChoice`, `firstWrongTiles`, `wrongPairs`. Zapisywana przy wpisywaniu, wyborze opcji, zdjęciu, rozsypance i parach. Gdy AI uzna pierwszą odpowiedź, zapis jest czyszczony. Test poziomu nic nie zapisuje. |
| `Features/Study/Support/StudyMistakeCapture.swift` (nowy) | Wpisy dziennika z modelu zadania, osobno dla każdego typu (9 przypadków `ExerciseType`). Pary dają jeden wpis na znaczenie. |
| `Features/Study/Support/StudyMeaningOptionsCache.swift` (nowy) | P3: indeks w `store.compute` (poza głównym wątkiem) dla każdej rewizji stanu. Dopóki indeksu nie ma, działa liczenie wprost. Cache opcji per (znaczenie, przykład, pozycja w sesji). `generation` odrzuca wyniki liczone na starych zasobach. |
| `Features/Study/Session/VocabSessionModel.swift` | Zmiany w modelu sesji słownictwa (szczegóły pod tabelą). |
| `Features/Study/Combined/CombinedSessionModel.swift` | Zapis błędów zadań słownikowych w `advance()`; opcje z cache. |
| `Features/Study/Session/VocabExerciseContent.swift` | `decoyFocus` (parametr `init` z wartością domyślną), przekazywane do `board(…prefer:)` i do zadań zastępczych. |
| `Features/Study/Support/StudyStarter.swift` | Nowe sesje (mieszanka, pomyłki, pary, „Zacznij od nowa”, jeden typ) dostają `MistakeLog.withDecoyFocus`. Nowe `startMistakePractice(kind:minutes:store:)`. Nie nadpisuje przerwanej sesji, tylko pokazuje komunikat. |
| `Features/Study/Home/StudyHomeView.swift` | Obsługa prośby `mistake-patterns[:<rodzaj>]` i nowe `startMistakePractice`. |
| `Features/Study/Session/VocabPronunciationStage.swift` (nowy) | P2: `VocabPronunciationSlot` i `VocabPronunciationStage` (szczegóły pod tabelą). |
| `Features/Study/Session/VocabExerciseView.swift` | Slot pod `VocabFeedbackView`. |
| `Features/Study/Session/VocabFeedbackView.swift` | Gdy etap jest widoczny, przycisk „Powiedz to” dla samego słowa jest ukryty, żeby na ekranie był jeden mikrofon. |
| `Features/Stats/MistakePatternsScreen.swift` (nowy) | `StatsMistakesCard` i `MistakePatternsScreen` (szczegóły pod tabelą). |
| `Features/Stats/StatsSnapshot.swift`, `StatsRootScreen.swift`, `WeeklyReportScreen.swift` | `mistakes: [MistakePattern]` w migawce, liczone poza głównym wątkiem; karta w Postępach; `StatsRoute.mistakes` z obsługą w jedynym `switch`. |
| `Features/AddWord/AddWordRootScreen.swift`, `AddWordSections.swift` | P3: `.task { warmSuggestions() }` przy otwarciu arkusza. Dopóki indeks się buduje, a pole nie jest puste, widać `AddWordSuggestionSkeleton` z `redacted(.placeholder)`, bez animacji; VoiceOver czyta „Wczytywanie podpowiedzi…”. |
| `FluentNOWTests/CodeQA/PracticePlusTests.swift` (nowy) | 4 testy (§3). |
| `docs/CONTRACTS.md` | `prepareSuggestions`, `listen(expected:maxDuration:)`, `isInputAvailable`. |

**`VocabSessionModel.swift`**:
- `decoyFocus` z sesji trafia do treści zadania.
- Błędy są zapisywane w tym samym `update(.answer)` co odpowiedź.
- Opcje „Wybierz znaczenie” pochodzą z `StudyMeaningOptionsCache`. Wcześniejsze wczytanie następnego zadania liczy je z indeksem `index + 1`, więc trafia w cache.

**`VocabPronunciationStage.swift` (P2)**:
- `VocabPronunciationSlot` pokazuje jedną z trzech rzeczy:
  - etap;
  - **jednorazową** informację, gdy brak zgody albo rozpoznawania (`@AppStorage("study.pronunciationNoticeShown")` i `@State noticeLatched`, więc informacja zostaje do końca zadania);
  - nic.
- `applies(to:enabled:)`: ustawienie włączone, poprawna „Ułóż zdanie” albo „Uzupełnij zdanie”, nie test.
- `VocabPronunciationStage` zawiera:
  - zdanie, a po nagraniu słowa rozpoznane (zielone) i do powtórzenia (pomarańczowe, podkreślone i pogrubione);
  - werdykt i liczbę słów;
  - przyciski „Nagraj/Zakończ/Spróbuj ponownie”, „Posłuchaj” (TTS) i „Pomiń”.
- Zgoda jest pytana dopiero po dotknięciu „Nagraj”.
- Przed nagraniem: `speech.stop()` i sprawdzenie `isInputAvailable`.
- Nagranie trwa maksymalnie 12 s.
- Haptyka przez `fluentSensoryFeedback`.
- VoiceOver: komunikat z wynikiem i słowami do powtórzenia, etykiety i podpowiedzi przycisków.
- Bez szkła: karta `.solid`.

**`MistakePatternsScreen.swift`**:
- `StatsMistakesCard`: 3 najczęstsze grupy i link do pełnego ekranu.
- `MistakePatternsScreen` (`StatsRoute.mistakes`):
  - wstęp i „Przećwicz wszystkie” (jedyna `PrimaryButton`);
  - karty grup: nazwa, „Mylisz in / on / at — 7 razy”, wyjaśnienie po polsku, do 4 przykładów (poprawnie i Twoja odpowiedź: kolor, ikona i tekst, plus zdanie);
  - „Przećwicz” (`SecondaryButton`) wywołuje `router.startStudy(StudyLaunchRequest(modes: [MistakePractice.launchMode(for:)], minutes: 5))`;
  - stan pusty i ładowanie.
- Bez szkła.

## 2. Model danych i kompatybilność

- `LearnerState.mistakes`:
  - pole opcjonalne w JSON; stary stan, eksport strony i stare kopie dekodują się z `[]` (test);
  - eksport JSON zawiera błędy, bo pole jest kodowane zawsze;
  - import `.merge` przechodzi przez `mergeStates` (unia), import `.replace` zastępuje;
  - migracja normalizuje.
- Synchronizacja:
  - jeden `HistoryRecord(kind: "mistake")` na wpis, więc CloudKit sumuje wpisy z urządzeń;
  - duplikaty rekordów usuwa wczytanie (jak przy innych historiach);
  - limit 500 działa deterministycznie po (`at`, `id`), więc oba urządzenia przycinają te same najstarsze wpisy i nie ma przepisywania tam i z powrotem;
  - `mergeStates` / `reloadRemoteChanges` / `mergePreloadChanges` korzystają z `MistakeLog.merge`; wynik nie zależy od kierunku scalenia (test).
- `VocabSession.decoyFocus`:
  - pole opcjonalne, `nil` nie jest zapisywane, więc JSON sesji dla strony jest bez zmian;
  - ustalane przy starcie sesji, więc wznowione zadanie ma te same kafelki, nawet gdy w międzyczasie przybyło błędów.
- Wpisy dziennika powstają z sesji słownictwa (wszystkie typy zadań oprócz fiszki) i z zadań słownikowych sesji łączonej. **Nie powstają** z testu poziomu, gramatyki, idiomów, produkcji ani z fiszek (brak podanej odpowiedzi).

## 3. Testy

FluentKit `MistakeLogTests` (22 testy):
- Klasyfikator na realnych przypadkach:
  - went/gone, made/make, is/are, worked/working, interested/interesting, goes/go, works/work (z `focusIsVerb` i bez: cars/car to literówka);
  - zdanie z rozsypanki „She has went home”;
  - at/on night, depend from, in/at, a/an apple, the/a, dodane „the”;
  - recieve, lnd, acomodation, lend/borrow, „lookforward to”, zła kolejność;
  - wielkość liter, interpunkcja i skróty nie są błędem; dwuliterowe słowa bez tolerancji literówki;
  - polskie odpowiedzi; `feedbackPl`; `closest`.
- „Przypomnij sobie”:
  - recieve → „literówka”;
  - cat/cst (3 litery → 1 edycja jak w wyszukiwaniu);
  - daleka odpowiedź bez podpowiedzi;
  - made przy make to nie literówka, tylko komunikat o formie.
- Dziennik:
  - `normalized`: duplikaty, kolejność, limit 500, idempotencja;
  - scalanie w obu kierunkach daje to samo, bez duplikatów, także przez `StateSync.mergeStates`;
  - 400 + 400 wpisów → 500 najnowszych, a ponowne scalenie niczego nie zmienia;
  - `recording`, przycinanie w migracji, przycinanie tekstów.
- Dekodowanie starych danych: stan bez `mistakes`, sesja bez `decoyFocus`.
- Dekodowanie łagodne: nieznany rodzaj, zły typ zadania, brak `id`, nieznane `decoyFocus`.
- Zapis i odczyt dają te same dane; `nil` nie jest zapisywane.
- Grupy: kolejność, pary, „Mylisz at / on / in — 3 razy”, „1 raz”, teksty.
- Adaptacyjne dystraktory:
  - `decoyFocus` wymaga co najmniej 2 błędów, typo nie ma dystraktora, przy remisie decyduje kolejność;
  - `choose`: domyślnie „went”, z preferencją przyimka „on”, preferencja bez możliwego dystraktora nic nie zmienia;
  - `board`: plansza deterministyczna przy wznowieniu, bez preferencji identyczna jak wcześniej.
- `MistakePractice`: kolejność, pomijanie zarchiwizowanych i brakujących słów, typy zadań, filtr rodzaju, `decoyFocus`, tryby uruchomienia.
- Wymowa: skróty, liczby, łącznik, pominięte słowo, cisza.
- `MeaningOptionsIndex`: liczba kandydatów, wyniki identyczne z `options(state:)`.

Aplikacja `PracticePlusTests` (4 testy):
- rozsypanka z „went” zamiast „gone” daje wpis `verbForm` gone/went z id `r1-m0`;
- „made” w „Przypomnij sobie” daje `verbForm`;
- poprawna pierwsza odpowiedź nie tworzy wpisu;
- `VocabPronunciationSlot.applies`;
- preferencja domyślnie włączona i reset;
- cache opcji daje wynik równy liczeniu wprost.

Istniejące testy, które dotyczą zmian i powinny przejść bez zmian:
- `GradingTests` (lnd → lend, bramk);
- `ScrambleDecoysTests` (`choose` bez `prefer`);
- `SessionTests` (`MeaningOptions`);
- `StudyPolishAppTests`.

**Nic nie zostało uruchomione** (Windows, brak Swifta). Oczekiwania testów policzyłem ręcznie według reguł z kodu.

## 4. Ryzyka kompilacji (gdzie patrzeć najpierw)

1. `FluentNOW/Services/Speech/AudioFocus.swift:27–37`:
   - blok `addObserver(…queue: nil)` przechwytuje `onLost` (`@MainActor () -> Void`), co w trybie Swift 5 da najwyżej ostrzeżenie Sendable;
   - `MainActor.assumeIsolated` wymaga iOS 17 / macOS 14, czyli zgodnie z platformami projektu.
2. `FluentNOW/Features/Study/Session/VocabPronunciationStage.swift:294`: `piece[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle.single`. W razie problemu usunąć linię; kolor i pogrubienie zostają.
3. `FluentNOW/Features/Study/Support/StudyMistakeCapture.swift:15` i `:67`: lokalna funkcja `make` z parametrami domyślnymi przekazana jako typ funkcyjny `(MistakeAnalysis, String, String, Int, String?, String?) -> MistakeEntry`.
4. `FluentNOW/Features/Study/Support/StudyMeaningOptionsCache.swift:20`: `nonisolated init() {}` w klasie `@MainActor`, żeby wartość domyślna właściwości `private let optionsCache = …` w modelach `@Observable @MainActor` nie wymagała izolacji.
5. `FluentNOW/Features/Study/Combined/CombinedSessionModel.swift:116`: `if let vocabulary, …` (skrót do właściwości).
6. `FluentNOW/Features/AddWord/AddWordSections.swift:435`: `ForEach(0..<…rows.count, id: \.self)` z tablicą krotek w `private static let`.
7. `FluentNOW/Services/Persistence/LearningRepository.swift:420`: `historyKeys.insert` w pętli obok zagnieżdżonej funkcji, która też modyfikuje `historyKeys`. Dostęp nie jest jednoczesny.
8. `Packages/FluentKit/Sources/FluentKit/Grading/MistakeClassifier.swift:202`: `private static let` z zamknięciem używającym `ScrambleDecoys.irregularVerbs` (wewnętrzne w module).
9. `FluentNOW/Services/Speech/PronunciationService.swift:94`: nowy `deinit` w klasie `@Observable @MainActor`. Używa tego samego wzoru co `SpeechService`.

## 5. Odstępstwa i decyzje

- **XP i statystyki za wymowę nie są zapisywane.** Recenzja z `skill: .pronunciation` weszłaby do celu dziennego, skuteczności, raportu tygodniowego i analizy, bo te liczą recenzje bez filtra umiejętności. Wynik pokazujemy i ogłaszamy, ale go nie zapisujemy. Opanowanie się nie zmienia. Propozycja na później: osobny licznik wymowy w `Progression`, bez `Review`.
- **„Tryb cichy”.** iOS nie ma publicznego API przełącznika wyciszenia. Etap pomijamy w tych przypadkach:
  - brak zgody;
  - brak rozpoznawania mowy;
  - zajęty mikrofon (`isInputAvailable`);
  - wyłączone ustawienie.

  Zawsze jest też „Pomiń”, a etap nie blokuje „Dalej”.
- **Zakres etapu.** Etap pojawia się po poprawnej rozsypance i po poprawnej luce, w sesji słownictwa i w sesji łączonej. Nie pojawia się w teście.
- **Dziennik błędów zapisuje pierwszą błędną odpowiedź.** Druga próba, także udana, nie usuwa wpisu, bo uczeń jednak pomylił się raz.
- **Literówka w „Przypomnij sobie”.** Progi są takie jak w wyszukiwaniu. Nowe zachowanie: 3-literowe słowa dopuszczają 1 literówkę (cat/cst), a słowa 6–7-literowe 2.
- **„Przećwicz” przy przerwanej sesji słówek** pokazuje komunikat zamiast ją nadpisać.
- **`MeaningOptions`.** Indeks z poprzedniej rewizji jest używany, dopóki nowy się liczy. Klucze celu zadania liczone są zawsze na świeżo, więc dystraktor nie może być drugą poprawną odpowiedzią.

## 6. Co sprawdzić w symulatorze

1. **Rozsypanka z błędem.** Ułóż zdanie z dystraktorem (np. „went” zamiast „gone”), potem popraw, „Dalej”. W Postępach jest karta „Twoje typowe błędy”: „Mylisz formy czasowników (gone / went) — 1 raz”. Dotknij karty: wyjaśnienie, przykład (poprawnie i Twoja odpowiedź), „Przećwicz”.
2. **„Przećwicz”.** Przechodzi do Nauki i uruchamia krótką sesję „Tryb pomyłek” z tym samym zdaniem jako „Ułóż zdanie”. Przy przerwanej sesji słówek zamiast tego pojawia się komunikat na górze.
3. **Dystraktory adaptacyjne.** Po co najmniej 2 błędach przyimkowych nowa sesja w rozsypankach z przyimkiem częściej pokazuje dystraktor przyimkowy. Przerwij sesję i wznów: te same kafelki.
4. **„Przypomnij sobie”.** Wpisz „recieve”: tytuł „Prawie — to literówka?”, komunikat „Prawie — to literówka. Poprawna pisownia: receive.”, przycisk „Uznaj moją odpowiedź”. Wpisz „made” dla „make”: „Nie tym razem” i podpowiedź o formie czasownika.
5. **Etap wymowy.** Po poprawnej rozsypance pod wynikiem pojawia się „Powiedz to zdanie na głos”. Sprawdź:
   - „Nagraj” przy pierwszym dotknięciu prosi o zgody;
   - mówienie pokazuje tekst na żywo, a wynik koloruje słowa;
   - „Spróbuj ponownie” działa;
   - „Posłuchaj” w trakcie nagrania kończy nagranie i czyta zdanie;
   - „Pomiń” chowa etap;
   - „Dalej” jest dostępne cały czas;
   - przycisk „Powiedz to” dla samego słowa jest ukryty.
6. **Brak zgody.** Odmów zgody (Ustawienia → Prywatność). Przy następnej rozsypance pojawia się raz informacja „Pomijamy mówienie zdań…”, przy kolejnych już nic. Ustawienia → Wymowa → „Ćwicz wymowę w sesjach” wyłączone: etapu nie ma.
7. **Dźwięk (najlepiej na urządzeniu).**
   - muzyka w tle ścisza się na czas nagrania i wraca;
   - nagranie, potem „Posłuchaj”, potem nagranie działają bez błędów;
   - wyszukiwanie głosowe w Słowniku, otwarcie sesji i nagranie etapu: mikrofon wyszukiwania się zatrzymuje;
   - połączenie w trakcie nagrania kończy nagranie.
8. **VoiceOver.** Etap ma nagłówek, przyciski z podpowiedziami, ogłoszenie „… Do powtórzenia: at”, a zdanie jest czytane jako „Do powtórzenia: …”. Karta w Postępach czyta „Mylisz … — N razy”.
9. **Arkusz „+”.** Zaraz po starcie aplikacji otwórz „+” i szybko wpisz „ca”: przez chwilę widać szkielet „Propozycje”, potem lista. Przy „Ogranicz ruch” bez animacji.
10. **Wybierz znaczenie.** Przy dużym słowniku (import kilku tysięcy słów) przejście między zadaniami bez przycięć, a opcje się nie zmieniają przy ponownym wyświetleniu.
11. **Synchronizacja i dane.**
    - dwa urządzenia z tym samym kontem iCloud: błędy z obu pojawiają się na obu, bez duplikatów;
    - eksport JSON zawiera `"mistakes"`, a import ze scaleniem je zachowuje;
    - „Usuń wszystkie dane” czyści dziennik.

## 7. Prośby do innych ról

- **design-shell:** brak (użyte tylko istniejące tokeny i komponenty).
- **code-qa:** przy najbliższym buildzie uruchomić `swift test` (MistakeLogTests) i `PracticePlusTests`; ręcznie sprawdzić punkt 7 z §6 na urządzeniu (`AVAudioSession`).
- **Właściciel / kolejna runda:** decyzja w sprawie XP za wymowę (§5) oraz czy zapisywać błędy z gramatyki, idiomów i produkcji. Klasyfikator to obsługuje, ale grupy nie mają tam słów, więc „Przećwicz” wymagałby osobnej sesji z banku zadań.
