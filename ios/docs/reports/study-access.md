# Raport: study-access (FEEDBACK-5 J1 + J2)

Kod pisałem na Windows bez kompilatora. Każdą użytą sygnaturę z innych plików sprawdziłem grepem, a każdy nowy i zmieniony plik przeczytałem ponownie. Lekser Node (`scratchpad/study-access/swiftcheck.mjs`: nawiasy z interpolacją `\(`, ciągi, komentarze, BOM/CR, `try!`/`as!`/`fatalError`) przechodzi dla wszystkich 19 zmienionych i nowych plików. Poleceń git nie uruchamiałem. Plików auth-profile (`App/`, `Features/Auth/`, `Features/Profile/`, `Services/Auth/`, nagłówek Dzisiaj, `project.yml`) nie dotykałem. W `TodayRootScreen.swift` zmieniłem jedną linię w `TodayContent` (plik czytałem tuż przed edycją).

## 1. Co zrobiono

### J1a. Nowe ćwiczenia wcześniej — FluentKit `Sessions/`

**`SessionBuilder.allowedTaskTypes`** — nowa progresja:

| Etap | Warunek | Typy |
|---|---|---|
| 1 | pierwszy kontakt albo jeszcze żadnego poprawnego rozpoznania | `[.meaning]` (`[.scramble, .meaning]`, gdy jest poprawne przypominanie) |
| 2 | **1** poprawne rozpoznanie, bez przypominania | `[.listeningChoice, .scramble, .meaning]` + plansza par |
| 3 | ≥ 2 poprawne rozpoznania, bez przypominania | `[.recall, .listeningChoice, .scramble, .meaning]` |
| 4 | przypominanie jest, „usage” jeszcze nie | `[.cloze, .scramble, .recall, .listeningChoice]` |
| 5 | „usage” jest, „listening” jeszcze nie | `[.listeningChoice, .dictation, .meaning]` (bez zmian) |
| 6 | wszystko | `nil` — najwcześniej wymagalna umiejętność (bez zmian) |

Przed J1 rozsypanka wymagała 2 poprawnych rozpoznań (przy FSRS w różne dni) i przypominania, a słuchanie jeszcze odpowiedzi „usage”.

Uzupełnienia:

- **`chooseType`**: typy, których nie da się zbudować dla wylosowanego zdania (rozsypanka 4–14 słów, słuchanie z tłumaczeniem i pulą), w ogóle nie są losowane. Inaczej słowo widziane raz mogłoby dostać dyktando zamiast „Zrozum ze słuchu”. Stare zastępstwa zostają jako zabezpieczenie.
- **`retryType(after:meaning:)`**: kolejność wyboru jest taka:
  1. zwykła rotacja, jeśli progresja na nią pozwala;
  2. inny dozwolony typ tej samej umiejętności;
  3. to samo ćwiczenie z innym zdaniem;
  4. dowolny dozwolony typ.

  Błąd rozpoznania w etapie 2 wraca więc jako „Wybierz znaczenie”, a nie jako słuchanie.
- **„Dopasuj pary” od pierwszego poprawnego rozpoznania**: `MatchPairsExercise.minimumRecognitionCorrect` zmienione z 2 na 1, plus nowe `canJoinBoard`. `groupIndices` bierze najpierw zadania „Wybierz znaczenie”, które plansza zastępuje. Gdy jest ich mniej niż 5, dobiera znaczenia ćwiczone w tej sesji w innej umiejętności. Ich zadania zostają, więc żadne znaczenie nie dostaje dwóch recenzji rozpoznania. Gdy plansza nie mieści się w budżecie, `makeRoom` usuwa zadania z końca listy (najniższy priorytet, spoza planszy).
- **Żadna sesja nie składa się z samego „Wybierz znaczenie”.** Sesja `.mixed` z samymi nowymi słowami kończy się **planszą wprowadzającą** (`introductionBoard`, `MatchPairsExercise.introductionIndices`). To „Dopasuj pary” z 3–5 znaczeń poznanych w tej sesji, dopisane **po** przeplecionych zadaniach, czyli zawsze po ich pierwszym kontakcie. Plansza wprowadzająca pojawia się tylko wtedy, gdy nie powstała zwykła plansza. Kosztuje 50 s: 10 min daje 22 nowe słowa + planszę zamiast 25 słów.
- Nowe `MatchPairsExercise.boardTask(_:)` jest wspólne dla obu plansz i sesji jednego typu.

### J1b. „Ćwicz wybrany typ”

**FluentKit — nowy `Sessions/SingleTypeSession.swift`** (`SingleTypeSession`, `SingleTypeAvailability`):

- **Kolejność:** wymagalne (według terminu umiejętności typu) → znane → nowe; gwiazdka rozstrzyga remisy.
- **Długość:** limit `minutes × 60 / estimatedSeconds`. 5 min to 12 × „Wybierz znaczenie”, 8 rozsypanek albo 6 plansz.
- **Tylko słowa, dla których da się zbudować typ.** Gdy pierwsze zdanie się nie nadaje, sprawdzanych jest do 8 innych przykładów.
- **„Dopasuj pary”:** plansze po 5 różnych znaczeń; ostatnia może mieć co najmniej 3.
- **Tryb sesji:** `exercise-<token>` (np. `exercise-scramble`). Starsze wersje i strona czytają go jako codzienną mieszankę (`VocabSession.studyMode`).
- **`alignRetries`:** powtórka błędnego zadania zostaje w wybranym typie, bo `Scheduler.recordAnswer` dopisuje ją w zwykłej rotacji. Wyjątek: pominięte pary wracają jako „Wybierz znaczenie”.

**Aplikacja (`Features/Study/`):**

- **`Home/StudyExerciseTypesCard.swift`** (nowy), karta „Ćwicz wybrany typ” pod wyborem sesji:
  - segment 5/10 min (`@AppStorage("study.singleTypeMinutes")`);
  - 7 kafelków: Wybierz znaczenie, Przypomnij sobie, Uzupełnij lukę, Ułóż zdanie, Dopasuj pary, Zrozum ze słuchu, Dyktando. Każdy ma ikonę, opis i „N słów” / „Brak słów”; liczba liczona przez `store.compute`;
  - kafelek „Słowo i zdjęcie” jest wyszarzony z chipem „W budowie”;
  - komunikat (brak słów, zdjęcia w budowie) pojawia się **przy kafelkach**, nie na górze ekranu, i jest ogłaszany przez VoiceOver.
- **`Support/StudyExerciseTypeText.swift`** (nowy):
  - nazwy, opisy i ikony typów;
  - komunikaty „brak słów” z konkretnym powodem dla każdego typu (np. rozsypanka potrzebuje zdań 4–14 słów, słuchanie potrzebuje tłumaczeń).
- **`StudyStarter.startSingleType`**: sesja w `state.session`, więc wznowienie, zapis i podsumowanie działają jak w zwykłej sesji.
- **`StudyHomeView`**:
  - nowa karta;
  - `startSingleType` (osobny stan `startingType`, więc „Rozpocznij sesję” nie pokazuje ładowania);
  - obsługa prośby z routera z trybem `exercise-<typ>`.
- **`VocabSessionModel`**: `singleType`, `headerTitle` (nagłówek sesji pokazuje nazwę typu), `alignRetries` po każdej odpowiedzi; „Jeszcze 5 minut” startuje ten sam typ.
- **`VocabSessionView`**: tytuł nagłówka.
- **`StudyResumeCard`**: „Ułóż zdanie · ukończono 3 z 8” zamiast „Codzienna mieszanka”.

**Router:** zmiana w `App/` nie była potrzebna. `StudyLaunchRequest.modes` to tekst, a `DeepLink.isValidModeToken` przepuszcza `exercise-scramble`. Działa więc już `router.startStudy(StudyLaunchRequest(modes: ["exercise-scramble"], minutes: 5))` oraz `fluentnow://study/start?mode=exercise-listening&minutes=10`. Tokeny: `meaning`, `recall`, `cloze`, `scramble`, `match-pairs`, `listening`, `dictation`.

### J2. Polecane słówka

- **Dzisiaj:**
  - sekcja polecanych usunięta;
  - zamiast niej dyskretny wiersz-link „Polecane słówka” (✦ … ›, styl „Pełna analiza w Postępach”) → `router.openLibrary(.recommended)`;
  - plik `Features/Today/TodayRecommendedWordsSection.swift` zawiera teraz tylko `TodayRecommendedWordsLink`. Nie kasowałem pliku, żeby nie ruszać projektu;
  - `TodayRootScreen` → `TodayContent`: jedna linia.
- **Wspólne widoki** (`UsefulWordsMoreLabel`, `UsefulWordAddButton`, `UsefulWordText`, `UsefulWordSummaryText`) przeniesione bez zmian do nowego `Features/Stats/UsefulWordsComponents.swift`. Używają ich `TodayAnalysisCard` i `StatsAnalysisSection`. Nieużywany już `UsefulWordRow` usunięty.
- **Słownik → Polecane** (`UsefulWordsScreen.swift`, przepisany) i nowy `UsefulWordsPaging.swift` (czyste funkcje):
  - **Zestaw:** najwyżej **3 strony po 6 słów**, bez nieskończonej listy.
  - **Własny pager:**
    - karta strony z przejściem w bok (przy „Ogranicz ruch” samo przenikanie);
    - przesunięcie palcem w lewo/prawo (`simultaneousGesture`, tylko wyraźnie poziome, żeby nie blokować przewijania);
    - strzałki ‹ › 44 × 44, kropki i „Strona 2 z 3”;
    - VoiceOver: jeden element z akcją „dostosuj”;
    - haptyka wyboru przy zmianie strony.
  - **„Odśwież propozycje”:**
    - losuje 18 słów spośród 36 najlepszych **niepokazanych w tym tygodniu**, z tej samej puli rankingu (`UsefulWordsCatalog`, limit 72, ziarno = tydzień), w kolejności rankingu;
    - pokazane słowa są pamiętane na urządzeniu (`@AppStorage` `usefulWords.week/.shown/.current`) i zerowane z nowym tygodniem;
    - gdy pula się wyczerpie, losowanie zaczyna się od nowa z informacją „Pokazaliśmy już wszystkie propozycje na ten tydzień”;
    - po powrocie na ekran widać ten sam zestaw.
  - **Zaznaczanie i dodawanie** działają jak dotąd:
    - dotknięcie zaznacza, „+” dodaje od razu;
    - dolny „Dodaj do nauki: N słów” dodaje zaznaczone ze wszystkich stron;
    - dodane zostają jako „Masz już”, a wolne miejsca uzupełniają kolejne niepokazane słowa.

    Jedyna zmiana: akcja nagłówka to teraz „Zaznacz stronę” / „Odznacz” (widoczna strona) zamiast „Zaznacz wszystkie”, żeby nie zaznaczać słów niewidocznych na innych stronach.

## 2. Publiczne API / kontrakty

```swift
// FluentKit
SessionBuilder.allowedTaskTypes(_:)                    // nowa progresja (tabela §1)
SessionBuilder.retryType(after:meaning:)               // + ta sama umiejętność → to samo ćwiczenie
MatchPairsExercise.minimumRecognitionCorrect == 1      // było 2
MatchPairsExercise.canJoinBoard(_ item: WordMeaning) -> Bool
public struct SingleTypeAvailability { var counts: [ExerciseType: Int]; func count(for:) -> Int; static let empty }
public enum SingleTypeSession {
    static let types: [ExerciseType]                   // 7 typów, kolejność kafelków
    static let durations = [5, 10]; static let modePrefix = "exercise-"
    static func token(for:) -> String?; static func mode(for:) -> String?; static func type(ofMode:) -> ExerciseType?
    static func canBuild(_:word:meaning:exampleIndex:listeningReady:) -> Bool
    static func buildableExample(_:word:meaning:preferred:listeningReady:) -> Int?
    static func availability(state:collection:) -> SingleTypeAvailability
    static func taskLimit(for:minutes:) -> Int
    static func makeSession(state:type:minutes:collection:now:) -> VocabSession
    static func alignRetries(_ state: LearnerState, from previousCount: Int) -> LearnerState
}
// Aplikacja
StudyStarter.startSingleType(_ type: ExerciseType, minutes: Int, collection: String?, store: LearningStore) async -> Outcome
StudyLaunchRequest(modes: ["exercise-<token>"], minutes: 5|10, collection:)   // obsługuje StudyHomeView
struct TodayRecommendedWordsLink: View                 // zamiast TodayRecommendedWordsSection
enum UsefulWordsPaging { pageSize 6, maxPages 3, setSize 18, poolLimit 72, refreshed(...), nextSet(...), pages(_:) }
```

## 3. Odstępstwa i decyzje

1. **Plansza wprowadzająca** w pierwszej sesji nowego użytkownika: drugi kontakt z tym samym znaczeniem tego samego dnia (pierwszy kontakt, potem pary). FSRS liczy to formułą tego samego dnia (w17–w19, mnożnik ≥ 1 dla G ≥ 2), więc interwał się nie mnoży. Licznik `correct` rośnie do 2, więc w następnej sesji odblokowuje się przypominanie. Kosztem są 3 nowe słowa w 10-minutowej sesji.
2. **Zwykła plansza może teraz stać obok zadań innej umiejętności** (np. słuchanie i pary tego samego słowa w jednej sesji). To różne umiejętności i osobne recenzje FSRS. Zasada „jedna recenzja rozpoznania na znaczenie w sesji” zostaje.
3. **Sesja jednego typu bierze nowe słowa ostatnie dla wszystkich typów**, zgodnie z zaleceniem, także dla „Przypomnij sobie” czy „Uzupełnij lukę”. Wybór jest świadomy, a podpowiedzi działają. Nie łamie to progresji: pierwszy kontakt w zwykłej sesji to dalej „Wybierz znaczenie”, bo `isFirstContact` patrzy tylko na rozpoznanie.
4. **Powtórki w sesji jednego typu** wyrównuje aplikacja (`alignRetries` w `VocabSessionModel.commit`), bo `Scheduler.recordAnswer` (obszar fsrs/core-engine) nie zna trybu. Pominięte pary wracają jako „Wybierz znaczenie”.
5. **„Zaznacz stronę”** zamiast „Zaznacz wszystkie” (§1 J2).

## 4. Ryzyka kompilacji / niesprawdzone

1. **`SingleTypeSession`**:
   - statyczna metoda `type(ofMode:)` obok parametrów o nazwie `type`. Wywołania są zawsze kwalifikowane (`SingleTypeSession.type(ofMode:)`, `SingleTypeSession.mode(for:)`), a zmienne lokalne mają inne nazwy (`sessionMode`, `sessionType`), co omija błąd „variable used within its own initial value”;
   - domknięcia sortujące `byDue` i `starred` są przekazywane do wewnętrznego `stableSorted(by:)`.
2. **`SessionBuilder.makeSession`**: lokalna `sessionTasks` (nazwa `ordered` była zajęta). `introductionBoard(tasks: &tasks, …)` wywołane w `if`, nie w operatorze `?:`.
3. **`UsefulWordsScreen`**:
   - `private var swipe: some Gesture` z `DragGesture.Value`;
   - `.accessibilityAdjustableAction` z `@unknown default`;
   - `AnyTransition.asymmetric(...)` w `ZStack` z `.id("\(setNumber)-\(current)")`;
   - `Dictionary.merge` z jawnymi typami;
   - `@AppStorage` zmieniane w funkcji `async` widoku.

   **Na symulatorze sprawdzić:**
   - przesunięcie w bok w `ScrollView` Słownika: czy pionowe przewijanie nie jest blokowane;
   - czy przejście nie skacze.

   Gdyby gest przeszkadzał, wystarczy usunąć `.simultaneousGesture(swipe)`; zostają strzałki i kropki.
4. **`StudyExerciseTypesCard`**: `LazyVGrid` z 8 kafelkami w `Card`. Ikony SF: `list.bullet.rectangle`, `brain.head.profile`, `text.cursor`, `shuffle`, `link`, `ear`, `square.and.pencil`, `photo.on.rectangle` (wszystkie z iOS ≤ 15). Kafelki nie używają szkła.
5. **`StudyHomeView.loadedContent`** ma 9 elementów w `@ViewBuilder` (limit 10).
6. **Wydajność `SingleTypeSession.availability`**: przelicza się w `store.compute` po każdej zmianie `revision`, jak liczniki fiszek. Dla 5 000 słów to 7 typów × sprawdzenie zdania (luka, tokenizacja). W tle, ale warto zmierzyć na Macu.

## 5. Prośby do innych ról

- **auth-profile / design-shell** (`App/DeepLink.swift`, tylko dokumentacja): w tabeli linków można dopisać `fluentnow://study/start?mode=exercise-scramble&minutes=5` (tokeny w §1). Kod nie wymaga zmian.
- **fsrs / core-engine** (`Scheduling/Scheduler.swift`, opcjonalnie): w `recordAnswer` przy `session.mode` z prefiksem `exercise-` powtórka mogłaby od razu dostawać typ sesji przez `SingleTypeSession.buildableExample`. Wtedy `alignRetries` w aplikacji byłoby zbędne, choć nieszkodliwe.
- **code-qa:** uruchomić testy z §6. W `MANUAL-TEST-PLAN.md` dopisać:
  1. Nowy użytkownik, pierwsza sesja: same „Wybierz znaczenie” + na końcu „Dopasuj pary”.
  2. „Jeszcze 5 minut” od razu po niej: „Zrozum ze słuchu”, „Ułóż zdanie” i plansza par.
  3. Nauka → „Ćwicz wybrany typ”:
     - każdy kafelek, 5 i 10 min;
     - nagłówek sesji z nazwą typu;
     - błąd wraca w tym samym typie;
     - „Jeszcze 5 minut” daje ten sam typ;
     - wznowienie z kafelka „Twoja sesja czeka”;
     - „Brak słów” z komunikatem przy kafelkach;
     - „Słowo i zdjęcie” daje informację „w budowie”.
  4. Dzisiaj: brak listy polecanych, link „Polecane słówka” otwiera Słownik → Polecane.
  5. Słownik → Polecane:
     - 3 strony po 6;
     - przesunięcie, strzałki, VoiceOver „dostosuj”;
     - zaznaczanie na różnych stronach i „Dodaj do nauki: N”;
     - „+”;
     - „Odśwież propozycje” daje inne słowa;
     - powrót na ekran pokazuje ten sam zestaw;
     - Dynamic Type xxxLarge.

## 6. Testy

Testów Swift nie uruchamiałem (brak kompilatora na Windows).

**Nowy `Tests/FluentKitTests/SingleTypeSessionTests.swift` (8 testów):**
- tokeny trybu: round-trip, tylko `a–z` i `-` (deep link), stara wersja widzi `.mixed`;
- tylko wybrany typ w kolejności wymagalne → znane → nowe (gwiazdka pierwsza wśród nowych);
- pomijanie słów, dla których typu nie da się zbudować (krótkie zdanie, brak tłumaczenia lub puli, luka bez słowa, typ nieoferowany);
- drugie zdanie, gdy pierwsze się nie nadaje;
- długość według minut;
- plansze par: rozłączne, po 5, za mało słów daje pustą sesję i dostępność 0;
- dostępność (archiwum, kolekcja);
- `alignRetries`: powtórka wraca do typu sesji, wcześniejsze zadania nietknięte, inne sesje bez zmian.

**`NewExercisesTests` — zaktualizowane z uzasadnieniem (J1 zastępuje progresję I2):**
- `testNewTypesComeAfterTheFirstCorrectContact` (było `…OnlyAfterSeveralCorrectContacts`): nowa tabela etapów i `minimumRecognitionCorrect == 1`;
- `testFreshWordsGetTheMeaningExerciseAndAnIntroductionBoard` (było `testFreshWordsNeverGetTheNewTypes`): nowe słowa nadal dostają tylko „Wybierz znaczenie”, a na końcu jest plansza z 5 znaczeń z tej sesji, w budżecie;
- `testNoBoardBeforeTheFirstCorrectRecognition` (było `…ForNewWordsOrTheirFirstContacts`): 0 poprawnych daje brak planszy, 1 poprawne daje planszę.

**`NewExercisesTests` — nowe:**
- `testStageTwoDrawsTheNewTypesButNeverDictation`: w etapie 2 pojawiają się znaczenie, rozsypanka, słuchanie i pary, nigdy dyktando, tłumaczenie ani luka;
- `testFailedRecognitionInStageTwoIsRetriedAsRecognition`.

**`SessionTests` (uzasadnienie w komentarzach):**
- `testAllowedTaskTypesProgression`: nowe etapy;
- `testNewMeaningsStartWithRecognition`: na końcu plansza wprowadzająca;
- `testSessionRespectsBudgetAndFillsWithFreshMeanings`: generator `UInt64.max` (wybiera „Wybierz znaczenie” z `[.scramble, .meaning]`); 5 z 16 powtórek tworzy planszę;
- `testFiveConsecutiveSessionsInterleaveAndFillBudget`: runda 0 to 22 × znaczenie + plansza; plansza wprowadzająca jest celowo poza przeplotem, więc kontrole przeplotu ją pomijają.

**`PracticeModesTests.testNewWordsStillFillTheBudgetWithTheMeaningExercise`:** `(minutes × 60 − 50) / 24` znaczeń + plansza na końcu.

**Przejrzane bez zmian:**
- `StarPriorityTests`: nowe słowo z gwiazdką jest pierwsze, więc nie wypada przy robieniu miejsca;
- `SchedulingTests` (powtórka w innym formacie, pary jako luka, przykład 1);
- `PracticeTests` i `CombinedReadingTests` (plansza na końcu nie rozdziela czytanek);
- `testScrambleAndListening…`;
- `testSessionBuildsOneBoardFromFiveMeaningTasks`: generator `max` wybiera ostatni typ, czyli `.meaning`.

**Skrypty:** `swiftcheck.mjs` przeszedł dla 19 plików, 0 problemów.
