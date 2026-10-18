# Raport: new-exercises (FEEDBACK-4 I2)

Kod pisany na Windows bez kompilatora. Każdą użytą sygnaturę z innych plików sprawdziłem grepem, a każdy nowy i zmieniony plik przeczytałem ponownie. Lekser Node ze scratchpada (`swiftcheck.mjs`: nawiasy z interpolacją `\(`, ciągi, komentarze, BOM/CR, `try!`/`as!`/`fatalError`) przeszedł dla 30 zmienionych i nowych plików bez błędów. Poleceń git nie uruchamiałem.

## 1. Co zrobiono

### FluentKit

**`Models/Enums.swift`** — trzy nowe przypadki `ExerciseType` (surowe wartości dalej Int):

| Typ | Nr | Nazwa | Umiejętność | Budżet | `slowSeconds` | Powtórka po błędzie |
|---|---|---|---|---|---|---|
| `.scramble` | 6 | „Ułóż zdanie” (rozsypanka) | usage | 36 s | 25 | `.cloze` |
| `.matchPairs` | 7 | „Dopasuj pary” | recognition (per znaczenie) | 50 s za planszę | 8 (na parę) | `.meaning` |
| `.listeningChoice` | 8 | „Zrozum ze słuchu” | listening (bez pisowni) | 28 s | 18 | `.dictation` |

Pozostałe zmiany w pliku:

- uzupełnione wszystkie `switch`: `namePl`, `shortNamePl`, `skill`, `estimatedSeconds`, `slowSeconds`, `retryType`, `promptAudioAllowed` (rozsypanka i pary: `false`);
- nowe `coversSeveralMeanings` i `hasTextHints`;
- `sessionTypes` zawiera rozsypankę i słuchanie. Pary nie trafiają tam, bo planszę buduje `SessionBuilder`.

**`Models/VocabSession.swift`**

- Nowe `VocabTaskRef { wordId, meaningId }` i `VocabTask.partners: [VocabTaskRef]?` (pozostałe pary planszy) oraz `allRefs`.
- Ręczne `encode(to:)` z `encodeIfPresent`: JSON starych typów jest bajt w bajt taki jak wcześniej, bez klucza `partners`.
- Dekodowanie tolerancyjne: brak klucza daje `nil`; uszkodzona lista gubi tylko partnerów, a plansza pokazuje się wtedy jako „Wybierz znaczenie”.
- Nieznany typ zadania (np. w starszej wersji aplikacji) dalej odrzuca tylko przerwaną sesję, nie import (polityka core-engine).

**Nowe pliki w `Sessions/`:**

- **`SentenceScramble.swift`** (`ScrambleTile`, `ScrambleBoard`):
  - `tokens`: podział na słowa, interpunkcja z brzegów usunięta, wewnętrzne `'` i `-` zostają;
  - `key`: wielkość liter, `’` i interpunkcja bez znaczenia;
  - `canBuild`: zdanie ma 4–14 słów (96 % z 21 380 przykładów w tematach);
  - `decoyCount`: 0 przed pierwszą odpowiedzią „usage”, potem A → 0, B → 1, C → 2 i co najmniej 1 po 3 poprawnych;
  - `board(word:meaning:exampleIndex:seed:)`:
    - kolejność stała dla zadania, nigdy od razu poprawna;
    - pierwsze słowo pisane małą literą tylko wtedy, gdy jest słowem funkcyjnym (imiona zostają);
    - pułapki to słowa treściowe z innych przykładów tego słowa: ≥ 4 litery, nigdy zaimek ani rodzajnik, bo ten mógłby dać inne poprawne zdanie;
  - `isCorrect`, `correctPrefixCount`.
- **`MatchPairs.swift`** (`MatchPairItem`, `MatchPairBoard`, `MatchPairResult`, `MatchPairsExercise`):
  - `isEligible`: ≥ 2 poprawne rozpoznania;
  - `areDistinct`: różne słowa, hasła i tłumaczenia, więc żadnej pary nie da się połączyć na dwa sposoby;
  - `groupIndices`, `items(for:state:)`, `board(_:seed:)` (kolumna PL tasowana osobno);
  - `reviewIDs(base:count:)`;
  - **`record(...)`** opisany w §2.
- **`ListeningChoice.swift`**:
  - `translation`, `canBuild` (zdanie z tłumaczeniem, 3–25 słów);
  - `hasDistractorPool`: ≥ 4 różne tłumaczenia przykładów w słowniku, sprawdzane raz na budowę sesji;
  - `options(state:meaning:exampleIndex:seed:extra:)`: 3 dystraktory losowane z 10 tłumaczeń najbliższych długością. Skan jest ograniczony do 800 słów od losowego punktu, więc słownik 5 000 słów pozostaje szybki. Brane są też inne zdania tego samego słowa, przez co samo wyłapanie słówka nie wystarcza;
  - `correctIndex`, `maxPlays = 3`.

**`Sessions/SessionBuilder.swift`**

- Progresja `allowedTaskTypes`:
  1. `[.meaning]` przy pierwszym kontakcie i przy < 2 poprawnych rozpoznaniach;
  2. `[.recall, .meaning]`;
  3. `[.cloze, .scramble, .recall]`;
  4. `[.listeningChoice, .dictation, .meaning]`;
  5. `nil`, czyli wszystko (najwcześniej wymagalna umiejętność).
- `chooseType`:
  - nowy parametr `listeningReady`;
  - zastępstwa: rozsypanka bez zdania → luka → tłumaczenie; słuchanie bez tłumaczenia lub puli → dyktando;
  - zdjęcie tylko przy `PictureExercise.isEnabled`.
- `makeSession`:
  - liczy `ListeningChoice.hasDistractorPool` raz;
  - w trybach `.mixed` i `.mistakes` woła nowe `addPairsBoard`: pięć zadań „Wybierz znaczenie” z kwalifikującymi się znaczeniami zamienia na jedną planszę w środku sesji;
  - zwolniony czas (5 × 24 − 50 = 70 s) wypełniają zadania, które wcześniej nie zmieściły się w budżecie (do 60 zapamiętanych). Budżet nie jest przekraczany.
- `makeSession(mode: .pictures)` zwraca pustą sesję, gdy zdjęcia są wyłączone. `makePictureSession` zostaje bez zmian.

**`Sessions/CombinedSessionBuilder.swift`**

- `saveAnswer(..., matchResults: [MatchPairResult] = [])`: plansza zapisuje wszystkie znaczenia przez `MatchPairsExercise.record(advancesSession: false)`.
- Przerwana sesja słówek zostaje nietknięta.
- Istniejące wywołania kompilują się bez zmian.

**`Sessions/PictureExercise.swift`** — nowa flaga `public static let isEnabled = false`. To jedno miejsce powrotu trybu zdjęć.

**`Grading/`**:

- `HintBuilder`: strażnik `type.hasTextHints` i nowe przypadki w `primaryVocabularyAnswer`;
- `VocabularyGrader.vocabularyAnswers`: `.matchPairs` jak `.meaning`, pozostałe nowe typy jak `.cloze`.

### Aplikacja (`Features/Study/`)

- **`Session/VocabExerciseContent.swift`**:
  - `scramble`, `pairs` i `listeningOptions` liczone raz, z ziarnem `wordId:meaningId:example`, więc wznowione zadanie wygląda tak samo;
  - `displayFallback(...)`: rozsypanka bez planszy → luka lub tłumaczenie, < 3 pary → „Wybierz znaczenie”, < 2 opcje słuchania → dyktando;
  - `expectedAnswer` dla nowych typów.
- **`Session/VocabExerciseModel.swift`**:
  - style `.scramble`, `.pairs`, `.listening`;
  - rozsypanka: `placeTile`, `removeTile`, `clearTiles`, `showScrambleHint`, `checkScramble`. Pierwszy błąd daje drugą próbę: poprawny początek zostaje, reszta wraca do puli, tłumaczenie się odsłania. Drugi błąd albo „Pokaż odpowiedź” kończy zadanie;
  - pary: `tapEnglish`, `tapPolish`, `pairMistakes`, `pairFlash`, `clearPairFlash`, `pairResults`;
  - słuchanie: `registerPlay` (limit 3, po odpowiedzi bez limitu) i `canPlay`; `chooseOption` obsługuje też słuchanie z drugą próbą;
  - `retried`: druga próba w typach bez podpowiedzi tekstowych liczy się jako „z pomocą”, co daje ocenę Hard.
- **Nowe widoki:**
  - `Session/VocabScrambleViews.swift`: prompt, pole „Twoje zdanie”, pula, akcje, wspólny kafelek `StudyWordTile` i układ `StudyTileFlow: Layout` (zawijanie);
  - `Session/VocabPairsViews.swift`: prompt z licznikiem, plansza (dwie kolumny, przy rozmiarach dostępności jedna pod drugą), lista wyników;
  - `Session/VocabListeningViews.swift`: odtwarzanie normalne i wolne, licznik odsłuchów, autoodsłuch (nie przy VoiceOver), opcje 1–4.
- **Zmienione:**
  - `VocabExerciseView` (baner „Słuchanie”, `showsSentenceAudio`: w rozsypance dopiero po odpowiedzi, w słuchaniu i parach nigdy; przypadki `switch`);
  - `VocabPrompts` (przypadki `switch`);
  - `VocabFeedbackView` (pary: tytuł, pomyłki, lista; rozsypanka i słuchanie: zdanie z tłumaczeniem; bez wariantów i wymowy przy parach);
  - `VocabSessionModel` i `Combined/CombinedSessionModel` (zastępstwa; zapis planszy przez `MatchPairsExercise.record`; wszystkie ID recenzji w podsumowaniu).

### „Słowo i zdjęcie” — W budowie

- **FluentKit:** `PictureExercise.isEnabled = false`. Zadanie zdjęciowe nie jest losowane w żadnym etapie progresji, nawet gdy podano `pictureMeaningIDs`. Tryb `.pictures` buduje pustą sesję.
- **`Picture/StudyPicturesCard.swift`:** nowa `StudyPicturesLockedCard`:
  - karta wyszarzona, z chipem „W budowie”;
  - dotknięcie pokazuje komunikat na ekranie Nauka (`StudyNoticeCard`, ogłaszany przez VoiceOver);
  - etykieta VoiceOver „Słowa i obrazki, w budowie”.
- **`Home/StudyHomeView.swift`:**
  - zamiast zwykłej karty pokazuje kartę zablokowaną;
  - `prefersPictures` przy wyłączonej fladze daje `false`, więc preferencja „Obrazki” z profilu nie przesuwa karty;
  - router z `modes: ["pictures"]` pokazuje komunikat;
  - snapshot zdjęć nie jest liczony.
- **`Support/StudyStarter.swift`:** `cachedPictureIDs` zwraca pusty zbiór; pusty tryb zdjęć daje komunikat „w budowie”.
- **`Services/Images/WordImagePrefetcher.swift`:** `request()` przy wyłączonej fladze ustawia `status = .disabled` i nic nie pobiera. Obejmuje to `AppEnvironment.prefetchWordImages`, ekran Nauka i start sesji.
- **Stare przerwane zadania zdjęciowe** (w obu modelach sesji) idą jako „Wybierz znaczenie”, bez zdjęć i bez „Zdjęcie nie pasuje”, które w tle pobierałoby następnego kandydata.
- **Kod zdjęć zostaje.** Powrót: `isEnabled = true`.
- **`docs/FUTURE.md`:**
  - plan „ilustracje AI per słowo w bazie”: model danych we wpisie tematu, generowanie skryptem w `tools/`, przegląd redakcyjny, dostarczanie przez ODR/CDN z SHA-256, zmiany w ćwiczeniu, licencje;
  - sekcja do rozbudowy nowych ćwiczeń.

## 2. Progresja i zapis

- **Kolejność:**
  - nowe słowo: „Wybierz znaczenie” (bez zmian);
  - po 2 poprawnych rozpoznaniach: tłumaczenie lub znaczenie;
  - po pierwszym tłumaczeniu: luka / **rozsypanka** / tłumaczenie;
  - po pierwszym „usage”: **słuchanie** / dyktando / znaczenie;
  - potem wszystko według najwcześniej wymagalnej umiejętności. Rozsypanka dzieli termin z luką (usage), a słuchanie z dyktandem (listening), więc remisy są losowe.
- **Pary:** znaczenie trafia na planszę dopiero po ≥ 2 poprawnych rozpoznaniach (`minimumRecognitionCorrect`). Jedna plansza na sesję w trybie mieszanym i pomyłek, nigdy w „Słowach w parach”.
- **Zapis wyłącznie przez `Scheduler.recordAnswer`:**
  - rozsypanka i słuchanie: zwykłe pojedyncze zadanie;
  - plansza: `MatchPairsExercise.record` woła `recordAnswer` raz na znaczenie. Typ `.matchPairs`, umiejętność recognition, czas planszy dzielony równo, bez podpowiedzi, `example: -1`, więc pula przykładów jest nietknięta. Sesja słówek jest wtedy odłączona;
  - potem sesja przesuwa się raz: `correct` +1 tylko przy planszy bez błędu, a każde znaczenie z pomyłką wraca na koniec (`SessionBuilder.retryType`, zwykle „Wybierz znaczenie”, limit `maxSessionTasks`). To ten sam mechanizm co w `recordAnswer` dla jednego zadania.
- **FSRS:** agent fsrs potwierdził, że jego kod nie ma `switch` po `ExerciseType`; ocena czyta tylko `type.slowSeconds`. Nowe typy działają bez zmian. Błędna para to Again dla obu znaczeń, druga próba (rozsypanka, słuchanie) to Hard.
- **Liczniki:** jedna plansza to 5 recenzji. Cel dzienny i XP rosną o 5, co odpowiada 5 ocenionym znaczeniom.

## 3. Odstępstwa i decyzje

1. **Plansza zastępuje 5 zadań „Wybierz znaczenie”, a nie dochodzi obok nich.** Inaczej jedno znaczenie dostałoby dwie recenzje rozpoznania w kilka minut, co w starym harmonogramie mnożyłoby interwał dwa razy. Zaoszczędzony czas wypełniają kolejne słowa.
2. **Rozsypanka:** „Sprawdź” jest aktywne dopiero, gdy ułożono tyle słów, ile ma zdanie. Przy pułapkach polecenie mówi, ile słów nie pasuje. Tłumaczenie PL jest podpowiedzią na żądanie (liczy się jako pomoc); po pierwszym błędzie odsłania się samo. Akceptowany jest tylko szyk zdania przykładowego (alternatywne szyki są w FUTURE).
3. **Słuchanie:** odsłuch automatyczny liczy się do limitu 3; tryb wolny też. Zła odpowiedź daje drugą próbę z zablokowaną opcją, jak przy „Wybierz znaczenie” (H1).
4. **Pary bez animacji ruchu:** błąd to 0,7 s czerwonego tła na obu kafelkach, sama zmiana koloru. „Ogranicz ruch” nie ma czego wyłączać, a przejścia stanu i tak idą przez `Motion.resolved(…, fallback: nil)`.
5. **Brak zmian w `LearnerProfile`** (obszar onboarding-progress). Mapowanie stylu „Obrazki” w `preferredStudyModes` jest neutralizowane w aplikacji. `dailyMixModes` i tak pomija tryb zdjęć, a `preferredExerciseTypes` nie ma wywołań.

## 4. Ryzyka kompilacji — gdzie patrzeć najpierw na Macu

1. **`StudyTileFlow: Layout`** (`VocabScrambleViews.swift`):
   - `sizeThatFits` / `placeSubviews` z `cache: inout ()`;
   - zwracana krotka `(frames: [CGRect], size: CGSize)`;
   - domknięcie `let limit: CGFloat = { guard let width, … }()`;
   - przy nieskończonej propozycji wszystko w jednym wierszu (bez NaN).
2. **`StudyWordTile`:**
   - memberwise init z `var fillsWidth: Bool = false` przed `let action` i trailing closure;
   - `.frame(minWidth:maxWidth:minHeight:)` z `fillsWidth ? CGFloat.infinity : nil`.
3. **`VocabExerciseContent.init?`:** przypisania `let` (`scramble`, `pairs`, `listeningOptions`) w `switch` (definite initialization).
4. **`ListeningChoice.options`:**
   - zagnieżdżona `func consider` mutuje przechwycone `seen`, `candidates` i `generator`;
   - sortowanie krotek z jawnymi typami.
5. **`SentenceScramble.board`:** `order.enumerated().map { (entry: (offset: Int, element: Int)) -> ScrambleTile in … }` oraz `[(text: String, isDecoy: Bool)]`.
6. **`VocabTask`:**
   - ręczne `encode(to:)` obok ręcznego `init(from:)`;
   - `partners = try? c.decodeIfPresent(...)` (SE-0230 spłaszcza opcjonal).
7. **`VocabPairsBoard`:**
   - dwa `.fluentSensoryFeedback`;
   - `.task(id: model.pairFlash?.id ?? 0)`;
   - `.onChange(of:) { (_: Int, _: Int) in }`;
   - `.contentTransition(.numericText())` (iOS 16+).
8. **`VocabFeedbackSummary.init`:** wywołanie `static` metod przed zainicjalizowaniem wszystkich `let` (są statyczne, więc bez `self`).
9. **Szkło + 3D:** `SpeakButton` jest użyty tylko w zwykłych stosach, bez `rotation3DEffect` i skali do 0. Kafelki nie używają szkła.

## 5. Co sprawdzić na symulatorze (iPhone 17 Pro / iOS 26.2)

1. **Postęp:**
   - świeży temat → pierwsze sesje to same „Wybierz znaczenie”;
   - po 2–3 sesjach z poprawnymi odpowiedziami pojawiają się „Rozsypanka” i „Rozumienie ze słuchu” (baner „Słuchanie”);
   - przy ≥ 5 dobrze znanych słowach pojawia się „Dopasuj pary”.
2. **Rozsypanka:**
   - dotknięcie przenosi kafelek, ponowne odkłada;
   - „Wyczyść”;
   - „Sprawdź” aktywne przy pełnym zdaniu;
   - błąd zostawia poprawny początek i odsłania tłumaczenie;
   - po odpowiedzi zdanie, tłumaczenie i „Posłuchaj poprawnego zdania”;
   - poziom B/C: polecenie „jedno słowo nie pasuje”;
   - zawijanie kafelków przy Dynamic Type xxxLarge i rozmiarach dostępności.
3. **Słuchanie:**
   - autoodsłuch;
   - licznik 3 → przyciski wyłączone;
   - żółw (wolniej);
   - tekst ukryty do odpowiedzi;
   - z VoiceOver brak autoodsłuchu i czytelne opcje.
4. **Pary:**
   - zaznaczenie EN → PL;
   - błędna para miga na czerwono z haptyką błędu (wyłączone „Wibracje” = bez haptyki);
   - poprawna zielenieje i blokuje się;
   - po 5 parach podsumowanie z listą pomyłek;
   - słowa z pomyłką wracają na końcu sesji;
   - VoiceOver ogłasza „Para: …” / „To nie jest para”.
5. **Sesja łączona** (mieszanka + gramatyka): nowe typy działają tak samo; plansza zapisuje 5 recenzji. Sprawdzić Postępy → dzisiejsza liczba odpowiedzi.
6. **Wznowienie:** zamknij sesję w trakcie rozsypanki i planszy → po powrocie te same kafelki i ta sama kolejność.
7. **Zdjęcia:**
   - karta „Słowa i obrazki” jest szara z „W budowie”, a dotknięcie daje komunikat;
   - z profilem „Obrazki” karta nadal jest na dole;
   - Ustawienia → Dane: „Pobieranie zdjęć jest wyłączone”;
   - w konsoli i Network brak zapytań do `api.openverse.org`.

## 6. Testy

**Nowy plik `Packages/FluentKit/Tests/FluentKitTests/NewExercisesTests.swift`** (17 testów):

- podstawy typów: umiejętności, powtórka zachowuje umiejętność, brak podpowiedzi `HintBuilder`;
- JSON `partners`: round-trip, stary JSON, brak klucza dla starych typów, uszkodzona lista;
- progresja etapami; nowe słowa nigdy nie dostają nowych typów;
- rozsypanka i słuchanie są losowane, a przy złym zdaniu lub braku tłumaczenia zastępowane;
- zdjęcia nigdy nie są losowane przy wyłączonej fladze (`XCTSkipIf`, gdy flaga wróci);
- tokeny i klucze;
- plansza rozsypanki: stała, przetasowana, tolerancyjne sprawdzanie, prefiks; pułapki według poziomu i tylko słowa treściowe; zakres 4–14;
- opcje słuchania: 4, różne, stałe, z poprawną; brak puli i brak tłumaczenia;
- jedna plansza z 5 zadań: rozłączna z resztą, czas uzupełniony, budżet ≤ 600 s; brak planszy przy 1 poprawnym rozpoznaniu i w trybie par; `areDistinct`;
- `record`: 5 recenzji z ID `r…r-5`, czas po 5 s, sesja +1, `correct` tylko bez błędów, 2 powtórki jako „Wybierz znaczenie”, pula przykładów nietknięta;
- `saveAnswer` sesji łączonej z planszą: 5 recenzji, przerwana sesja nietknięta.

**Zaktualizowane:**

- `SessionTests.testAllowedTaskTypesProgression`: nowe etapy;
- `StudyPolishTests`: tryb `.pictures` przy wyłączonej fladze jest pusty, budowa sesji zdjęć testowana przez `makePictureSession`;
- `PracticeModesTests.testPictureTasksOnlyForReadyMeaningsPastFirstContact`: `sawPicture == PictureExercise.isEnabled`.

Pozostałe testy przejrzałem pod nowe zachowanie: budżety `SessionTests`, `StarPriorityTests`, `SchedulingTests.testUsedExamples…`, `PracticeTests` (sesja łączona), `testClozeReplacesInflected…` (rozsypanka ≠ luka). Nie wymagają zmian.

Testów Swift nie uruchamiałem, bo na Windows nie ma kompilatora. Skrypty Node: lekser 30/30 OK; rozkład długości przykładów w 21 380 zdaniach tematów (4–14 słów = 96 %).

## 7. Prośby do innych ról

- **onboarding-progress** (`Profile/LearnerProfile.swift`): przy `PictureExercise.isEnabled == false` styl `.pictures` w `preferredStudyModes` / `preferredExerciseTypes` warto mapować na `.mixed` / nic. Dziś neutralizuje to aplikacja, a `preferredExerciseTypes` nie ma wywołań.
- **fsrs / core-engine** (`Scheduling/Scheduler.swift`, `errorLabel`): opcjonalnie etykiety „Ułożenie zdania”, „Dopasowanie par” i „Rozumienie ze słuchu” zamiast `default` („Przypominanie lub pisownia”). Ewentualna rozbudowa `recordAnswer` powinna zachować warunek `task.example >= 0` przy `usedExamples`, bo plansza par przekazuje `-1`.
- **code-qa:** punkty z §4 i scenariusze z §5 do `MANUAL-TEST-PLAN.md`.
