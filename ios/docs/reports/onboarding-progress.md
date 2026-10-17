# Raport: onboarding-progress (FEEDBACK-2: G4, G5, G6)

Kod napisany na Windows **bez kompilatora**. Każdą użytą sygnaturę (FluentKit, Services, DesignSystem) sprawdziłem grepem w kodzie. Skrypt Node w scratchpadzie (nawiasy z interpolacją, łańcuchy, BOM/CR, `try!`/`as!`/`fatalError`/force-unwrap) przechodzi dla wszystkich zmienionych plików. Kontrola kolizji nazw typów: brak duplikatów. Gita nie uruchamiałem.

## 1. Co zrobiono (pliki)

**FluentKit — nowe**
- `Sources/FluentKit/Profile/LearnerProfile.swift`:
  - `LearningGoal` (7 celów), `LearningInterest` (14 kafelków), `LearningStyle` (6 sposobów), `LevelSource`. Każdy cel i zainteresowanie mapuje się na tematy bazy i grupy tematów; test sprawdza, że te tematy i grupy istnieją;
  - `LearnerProfile`: tolerancyjne kodowanie (nieznane wartości pomijane), `normalized()`, `newer(_:_:)` do scalania, wagi tematów i grup, tryby nauki, cel dzienny z minut;
  - `ProfileLevel.estimate`: poziom startowy z wywiadu, dopóki nie ma historii odpowiedzi.
- `Profile/PlacementTest.swift`: szybki test poziomu, czyste funkcje.
  - 9 pytań „Co znaczy …?” z `dictionary-index.json`, na poziomach A1, A2, A2, B1, B1, B2, B2, C1, C2;
  - 3 zdania z luką z `grammar/A2|B1|B2.json`;
  - każde pytanie ma opcję „Nie wiem”;
  - wynik jest deterministyczny dla danego ziarna.
- `Profile/OnboardingPlan.swift`: tematy na start (według celów i zainteresowań, A1 zawsze zaczyna od powitań), liczba słów według minut, wpisy z przedziału poziom ±1, podział słów na tematy.
- `Progression/XPRules.swift`: stałe balansu i krzywa poziomów.
- `Progression/Progression.swift`: XP liczone z historii, poziomy, rangi, XP sesji, podsumowanie.
  - typy: `XPLedger`, `XPDay`, `XPSource`, `XPRank`, `XPLevel`, `XPSessionGain`, `XPSourceTotal`, `ProgressionSummary`.
- `Analysis/OwnedVocabulary.swift` (G6): które wpisy użytkownik już ma. Dopasowanie po `contentRef` albo po haśle i tłumaczeniu (aktywne słowa), według tej samej reguły co `VocabularyMerger`.
- Testy: `Tests/FluentKitTests/ProgressionTests.swift` (12) i `LearnerProfileTests.swift` (15).

**FluentKit — zmienione (addytywnie)**
- `Models/LearnerSettings.swift`: `public var profile: LearnerProfile?`, ostatni parametr `init` (`= nil`), klucz `profile`, dekodowanie `lenientOptional`. Brak profilu → klucz pominięty w JSON, więc eksport bez zmian.
- `Sync/StateSync.swift` (`mergeStates`): `merged.settings.profile = LearnerProfile.newer(local, remote)`. Wygrywa nowszy `updatedAt`, a profil z drugiego urządzenia nie ginie.
- `ImportExport/StateMigration.swift`: `settings.profile?.normalized()`.
- `Analysis/UsefulWordRecommender.swift`:
  - `UsefulWordReason.interest(String)` („z tematu X, który pasuje do Twoich celów”);
  - `UsefulWordProfile.topicPreferences` / `groupPreferences` (domyślnie puste);
  - `make(_:estimate:usesLearnerProfile: Bool = true)`: domyślnie poziom z `ProfileLevel` oraz wagi z profilu;
  - ranking: premia za temat (maks. +14) i grupę (maks. +6); temat z celów dopuszcza rejestr specjalistyczny.
  - Stare wywołania i testy działają bez zmian: przy braku profilu wynik jest identyczny.

**Aplikacja**
- `Features/Today/Onboarding/` (nowe): kreator wywiadu.
  - `OnboardingModel.swift`: `@Observable`, kroki jako enum, test, podsumowanie;
  - `OnboardingWizardView.swift`: kontener z własnym `ScrollView`, przewijanie na górę przy zmianie kroku, „Pomiń”, `OnboardingFinisher`;
  - `OnboardingStepViews.swift`, `OnboardingChoiceViews.swift`, `OnboardingPlacementView.swift`, `OnboardingSummaryView.swift`;
  - `OnboardingContentLoader.swift`: słownik i gramatyka z bundla, w `Task.detached`.
- `Features/Today/TodayOnboardingView.swift`: **usunięty** (zastąpiony kreatorem).
- `Features/Today/TodayRootScreen.swift`: przy pierwszym uruchomieniu cały `ScrollView` zastępuje `OnboardingWizardView(isActive:)`; w `TodayContent` dochodzi `TodayXPCard`.
- `Features/Today/TodaySnapshot.swift`: pole `progression` (`Progression.summary`, liczone w `compute`).
- `Features/Today/TodayXPCard.swift` (nowy):
  - pasek XP: poziom, ranga, „+N XP dziś”, postęp do kolejnego poziomu; dotknięcie otwiera Postępy;
  - `XPLevelBadge`, `XPText`.
- `Features/Study/Summary/StudySummaryXP.swift` (nowy): „+N XP” w podsumowaniu.
  - liczone w tle przez `Progression.sessionGain`;
  - krótkie pojawienie się z `Motion.resolved`, przy „Ogranicz ruch” tylko przenikanie;
  - ogłoszenie VoiceOver;
  - przy awansie linia „Nowy poziom … i ranga …”.
- `Features/Study/Summary/StudySummaryData.swift`: pola `reviewIDs` i `historyIDPrefix` (z wartościami domyślnymi, więc wywołanie `StudySummaryData(...)` w `CombinedSessionModel` działa bez zmian). Prefiks `"<id sesji>:"` dla ukończonej sesji łączonej.
- `Features/Study/Summary/StudySummaryView.swift`: jedna linia, `StudySummaryXPBadge`.
- `Features/Study/Home/StudyHomeView.swift` (mała zmiana, na prośbę koordynatora — practice-modes nie wpiął profilu):
  - `@AppStorage("study.profileApplied")` zapamiętuje `updatedAt` profilu, który już zastosowano;
  - `.onChange(of: store.settings.profile?.updatedAt, initial: true)` → `applyProfileDefaults()` ustawia `study.minutes` = `profile.sessionMinutes` oraz `study.modes` = `profile.dailyMixModes(limit: 3)`;
  - dzieje się to tylko raz na każdą wersję profilu: po wywiadzie i po każdej edycji profilu w Ustawieniach. Między edycjami zostaje ręczny wybór użytkownika;
  - gdy „Fiszki” są wśród ulubionych sposobów nauki, karta talii (`StudyFlashcardsCard`, tryb `StudyMode.flashcards`) stoi nad wyborem trybów.
  - Mapowanie preferencji w `LearnerProfile`: „fiszki” → `StudyMode.flashcards` (`preferredStudyModes`) i `ExerciseType.flashcard`; „obrazki” → `ExerciseType.picture` („Słowo i zdjęcie”, część sesji słówek) w `preferredExerciseTypes()`.
- `Features/Stats/StatsProgressionSection.swift` (nowy): karta poziomu (ranga, opis, „Masz N opanowanych znaczeń i M dni nauki”, następna ranga), wykres XP z 14 dni, źródła XP i zasady.
- `Features/Stats/StatsSnapshot.swift`: pole `progression`.
- `Features/Stats/StatsRootScreen.swift`: `StatsContent` podzielony na dwie grupy (limit 10 widoków w `ViewBuilder`), do tego `StatsProgressionSection`.
- `Features/Settings/SettingsProfileScreen.swift` (nowy): „Twój profil nauki” z celami, poziomem startowym, zainteresowaniami, sposobem nauki i czasem dziennie (zmiana czasu ustawia też cel dzienny). Każda zmiana od razu przez `store.update(.edit)` z nowym `updatedAt`.
- `Features/Settings/SettingsRootScreen.swift`: `SettingsRoute.learningProfile`, sekcja-link na górze `Form`, przypadek w `SettingsDestination`.
- **G6** (oznaczanie słów, które użytkownik już ma):
  - `Features/AddWord/OwnedVocabularyBadge.swift` (nowy): `OwnedVocabularyBadge` („✓ Masz już”), `ownedVocabularyDimmed(_:)`;
  - `AddWord/AddWordModel.swift`: `knownSenseIndices` przez `OwnedVocabulary` (teraz też po `contentRef`);
  - `AddWord/AddWordSections.swift`: wyszarzone tłumaczenie, odznaka „Masz już”, cecha `.isSelected`;
  - `Topics/TopicSearchModel.swift`: `applyOwned(_:)`, `refreshAdded()` po wczytaniu sekcji. Posiadane wpisy wypadają z zaznaczenia, więc licznik „Dodaj N słów” ich nie liczy;
  - `Topics/TopicSearchView.swift`: `OwnedVocabulary` w `compute`;
  - `Topics/TopicEntryRow.swift`: wyszarzenie, ✓, „Masz już” zamiast poziomu, blokada.
  - `Today/UsefulWordsOwnership.swift` (nowy): słowo dodane z listy polecanych zostaje na swoim miejscu jako „Masz już”, a wolne miejsca wypełnia nowy ranking. Wpięte w `TodayRecommendedWordsSection.swift` (`UsefulWordRow` z `isOwned: Bool = false`) i `Stats/UsefulWordsScreen.swift` (wiersz zablokowany, nie liczy się do „Dodaj do nauki: N”, nie łapie się na „Zaznacz wszystkie”).
  - `Today/UsefulWordsCatalog.swift`: filtr rejestru uwzględnia też powód `.interest`.

## 2. Nowe API

```swift
// Profil (LearnerSettings.profile: LearnerProfile?)
public struct LearnerProfile: Codable, Sendable, Hashable {
    goals: [LearningGoal]; startLevel: String?; levelSource: LevelSource?; placementCorrect/placementTotal: Int?
    interests: [LearningInterest]; styles: [LearningStyle]; dailyMinutes: Int?; createdAt, updatedAt: Timestamp
    static let minuteOptions = [5, 10, 15, 20]
    func normalized() -> LearnerProfile; static func newer(_:_:) -> LearnerProfile?; var isEmpty: Bool
    func topicWeights() -> [String: Int]; func groupWeights() -> [String: Int]
    func preferredStudyModes() -> [StudyMode]     // .mixed zawsze pierwszy; style → production/reading/"flashcards"/grammar
    func dailyMixModes(limit: Int = 3) -> [StudyMode]   // tylko isCombinable — proporcje codziennej mieszanki
    func preferredExerciseTypes() -> [ExerciseType]     // pisanie → recall/cloze, słuchanie → dictation, obrazki → picture(5)…
    static func dailyGoal(minutes: Int) -> Int    // ≈ 2 zadania na minutę (5…100)
    var sessionMinutes: Int                       // 5…15, domyślnie 10
}
public enum ProfileLevel { static func estimate(_ state: LearnerState) -> LevelEstimate }
public enum PlacementTest { static func makeQuestions(dictionary:grammar:seed:) -> [PlacementQuestion]; static func result(questions:answers:) -> PlacementResult }
public enum OnboardingPlan { starterTopicIDs(for:available:limit:), starterWordCount(minutes:), starterEntries(_:level:limit:), wordsPerTopic(total:topics:) }
public struct OwnedVocabulary { init(_ state:), init(words:), contains(reference:term:translation:), containsTerm(_:), ownedReferences(_:) }

// XP
public enum Progression {
    static func ledger(_:) -> XPLedger; static func totalXP(_:) -> Int; static func level(forXP:) -> XPLevel; static func level(_ state:) -> XPLevel
    static func threshold(forLevel:) -> Int
    static func sessionGain(_:reviewIDs:historyIDPrefix:) -> XPSessionGain
    static func summary(_:now:) -> ProgressionSummary
    static func masteredMeanings(_:) -> Int; static func dayNumber(_:) / dayNumber(utcDay:)
}
```

**Ekran Nauka:**
- Wpięte już przeze mnie: `dailyMixModes()` i `sessionMinutes` jako domyślny wybór, a przy preferencji fiszek karta talii na górze.
- Do wykorzystania dalej:
  - `preferredStudyModes()` (pełna kolejność, z `.flashcards`);
  - `preferredExerciseTypes()` (wagi typów w `SessionBuilder` — nie ruszałem);
  - `ProfileLevel.estimate(state).targetLevel` zamiast `LevelEstimator.estimatedLevel` w `StudyStarter`, `PracticeComponents` i `ReadingPracticeView`.
- `nil` profilu oznacza zachowanie jak dotąd.

## 3. Jak działa (decyzje)

**G4 — wywiad** (8 kroków, pasek postępu „Krok X z 8”, „Pomiń” na każdym kroku):

| Krok | Co pytamy | Co zmienia w aplikacji |
|---|---|---|
| 1 | Cele | wagi tematów i grup, rejestr: temat z celu dopuszcza słownictwo specjalistyczne, np. praca → biuro |
| 2 | Poziom: 6 opisów samooceny albo szybki test | startowy CEFR |
| 3 | Zainteresowania | wagi tematów i grup |
| 4 | Sposób nauki | tryby i mieszanka |
| 5 | Czas: 5 / 10 / 15 / 20 min | `settings.goal` = 10 / 20 / 30 / 40, długość sesji, liczba słów na start (15 / 24 / 30 / 36) |
| 6 | Przypomnienie | prośba o zgodę dopiero po włączeniu przełącznika, potem pora w `settings.reminder` i `refreshReminders` |
| 7 | Akcent | zapis od razu, głos „automatycznie”, odsłuch próbki |
| 8 | Podsumowanie | „Na start proponujemy N słów z tematów …”: tematy do odznaczenia, skrót odpowiedzi, „Dodaj N słów i zacznij” |

- Test poziomu: 12 pytań, odpowiedź od razu przechodzi dalej, na końcu wynik i propozycja poziomu.
- Wpisy na start są w kolejności `TopicSearch.usefulnessOrder`, z poziomów start ±1 (A1/A2: do start+1). Gdy takich jest za mało, listę uzupełniają łatwiejsze.
- Dodawanie słów: `TopicAdder` z postępem, a potem `router.startStudy(.daily)`. Jeśli nic się nie dodało, kreator zostaje z komunikatem.
- „Pomiń” zapisuje profil tylko wtedy, gdy coś wybrano.

**Test poziomu (punktacja):**
- idziemy w górę od A1;
- poziom jest zaliczony, gdy co najmniej 50% jego pytań i co najmniej 60% wszystkich pytań do niego włącznie jest poprawnych;
- pierwszy niezaliczony poziom zatrzymuje wspinaczkę, z wyjątkiem A1 (jedna pomyłka na najłatwiejszym słowie nie zaniża wyniku), więc szczęśliwy strzał w C2 się nie liczy;
- „Nie wiem” i brak odpowiedzi liczą się jako błąd.
- Dystraktory pochodzą z tego samego poziomu: inny klucz tłumaczenia, inne pierwsze słowo, inne hasło.

**G5 — XP z historii (bez licznika).**
- Odpowiedź, punkty bazowe za poprawną:
  - rozpoznanie (wybór znaczenia, fiszka, zdjęcie): 4;
  - słuchanie (dyktando): 7;
  - przypominanie, użycie (luka), pisownia: 8;
  - wymowa: 2.
- Modyfikatory odpowiedzi:
  - z podpowiedzią 50%;
  - literówka (błąd „Pisownia”) 70%;
  - błędna odpowiedź 0.
- Kolejne odpowiedzi dla tego samego słowa w danym dniu dają 100 / 60 / 35 / 20%, a potem po 10%.
- Pytania z czytanki (`source == .reading`) i odpowiedzi demo nie dają XP za odpowiedź. Czytanka nagradzana jest osobno.
- Zestawy:
  - czytanka: 3 XP za poprawne pytanie + 10 za ukończenie;
  - gramatyka, idiomy, mieszanka: 3 XP za poprawne + 8 za zestaw od 5 pozycji;
  - produkcja: 5 XP za poprawne + 8 za zestaw od 4 pozycji;
  - nagradzanych jest najwyżej 6 zestawów każdego rodzaju dziennie.
- Premie dzienne:
  - osiągnięty cel: +20. Próg to `min(cel, 20)`, więc podniesienie celu nie zabiera XP z przeszłości;
  - seria: +3 za każdy kolejny dzień, najwyżej +15 dziennie.
- Dni są liczone w UTC, tak jak klucze `reviewSummaries`, więc każde urządzenie liczy to samo.
- Dni skompaktowane (starsze niż 90 dni, tylko podsumowania) dają 6 XP za poprawną odpowiedź.
- Krzywa: próg poziomu n = round(120 · (n−1)^1.75), maksymalnie poziom 100.
- Rangi:

| Poziomy | Ranga |
|---|---|
| 1–4 | Pierwsze kroki |
| 5–9 | Odkrywca |
| 10–14 | Podróżnik |
| 15–19 | Rozmówca |
| 20–24 | Znawca |
| 25–29 | Erudyta |
| 30–39 | Mistrz |
| 40+ | Legenda |

- XP sesji = suma XP ze stanem minus suma XP bez odpowiedzi tej sesji (i bez wpisów historii z prefiksem sesji łączonej). Dzięki temu zniżki za powtórki i premia za cel są policzone dokładnie.

## 4. Wyniki symulacji XP

Scenariusz jest identyczny w teście Swift (`testBalanceSimulationThirtyAndNinetyDays`) i w porcie Node (`scratchpad/xpsim.mjs`). Arytmetyka jest całkowitoliczbowa, więc wartości są dokładne i test je asserts.

Typowy użytkownik:
- 26 odpowiedzi dziennie (ok. 12 min), 6 dni w tygodniu;
- około 18% błędów, trochę podpowiedzi i literówek;
- 16 słów dziennie (powtórki po błędzie);
- czytanka co 3. dzień, zestaw gramatyki co 4. dzień.

| okres | aktywne dni | XP | w tym słówka / czytanie+gramatyka / premie | śr. XP/dzień | poziom |
|---|---|---|---|---|---|
| 7 dni | 6 | 882 | 621 / 96 / 165 | 147 | 4 |
| 30 dni | 26 | 3 712 | 2 651 / 358 / 703 | 143 | **8** (Odkrywca) |
| 90 dni | 78 | 11 163 | 7 926 / 1 092 / 2 145 | 143 | **14** (Podróżnik) |

- Awanse (dzień od startu):
  - L2 – 1, L3 – 3, L4 – 6, L5 – 11, L6 – 17, L7 – 23;
  - L8 – 30, L9 – 37, L10 – 46, L11 – 55, L12 – 65, L13 – 76, L14 – 87.
  - Na początku poziom co kilka dni, potem mniej więcej co tydzień, a po dwóch miesiącach co około 10 dni.
- Odporność na „farmienie”: 200 odpowiedzi na tych samych 10 słowach w jeden dzień daje 170 XP (0,85 XP na odpowiedź). Typowy dzień z 26 odpowiedziami daje 147 XP (5,65 XP na odpowiedź).
- Premie stanowią około 19% XP, czyli są umiarkowane.

## 5. Odstępstwa i decyzje względem strony

- Strona nie miała ani wywiadu, ani XP — oba są nowe.
- Onboarding nie korzysta już z 12 skrótów sytuacji. Tematy na start wynikają z profilu, a ich nazwy pokazuje podsumowanie.
- XP i „dzień” liczę w UTC (spójnie z `reviewSummaries` i między urządzeniami). Przy sesji po północy czasu UTC (1:00–2:00 w Polsce) XP trafia do kolejnego dnia.
- Dzienny cel w kreatorze to około 2 zadania na minutę: 10 minut daje cel 20, czyli tyle, ile wynosiła dotychczasowa wartość domyślna.

## 6. Ryzyka kompilacji (gdzie patrzeć na Macu)

1. `OnboardingWizardView.swift`:
   - `.toolbar(.hidden, for: .navigationBar)` w stosie Dzisiaj, gdzie korzeń ma też `.toolbar { QuickAddButton }`. Jeśli pasek się nie schowa, to tylko kosmetyka;
   - `ScrollViewReader` + `.onChange(of: model.step)` w wersji iOS 17 z dwoma parametrami;
   - `.id(model.step)` z `.transition`.
2. `SettingsProfileScreen.swift`: właściwości typu `((inout LearnerProfile) -> Void) -> Void` (nazwa `edit`) inicjowane referencją metody `update`. Jeśli kompilator zaprotestuje (escaping / inout), zamienić na domknięcie `{ (change: (inout LearnerProfile) -> Void) in update(change) }`.
3. `StudySummaryXP.swift`: `.task` na `VStack`, który bywa pusty (przyjąłem, że `VStack` się pojawia — pusty `Group` by tego nie zrobił). `withAnimation(Animation?)`.
4. `StatsProgressionSection.swift`: `Chart(days) { (item: XPDay) in BarMark… }`, a `XPDay.date` to północ UTC. W strefach z ujemnym przesunięciem etykieta dnia może się przesunąć o jeden (dla Polski bez znaczenia).
5. FluentKit `Progression.swift`:
   - lokalne nazwy celowo nie przesłaniają metod (`book`, `goalThreshold`, `reached`);
   - `private struct DayTotals` używany w prywatnych metodach statycznych;
   - `Dictionary.filter` z `.sorted` z jawnie otypowanymi krotkami jest w `OnboardingPlan.starterTopicIDs`.
6. `PlacementTest.swift`: metody generyczne z `inout G: RandomNumberGenerator` i prywatna statyczna `shuffle(_:using:)`, nazwana jak metoda `Array`, ale wołana statycznie.
7. Test `testBalanceSimulationThirtyAndNinetyDays` assertuje dokładne XP (882 / 3712 / 11163). Jeśli różnica wyniknie z `pow` (tylko poziomy), to sprawdzić wyniki z `print` w logu testu.
8. Eksport JSON zawiera teraz `settings.profile`, gdy profil istnieje. Jeśli strona waliduje ustawienia ściśle, import na stronie mógłby odrzucić klucz — niesprawdzone (strona tylko do odczytu).
9. `StudyHomeView.body` ma o jeden modyfikator więcej (`.onChange(of: Double?, initial: true)` z jawnie otypowanym domknięciem). Jeśli pojawi się „unable to type-check”, przenieść `.onChange` do małego `ViewModifier`.
10. Usunięty `TodayOnboardingView.swift` i nowe pliki wymagają `xcodegen` przed budowaniem.

## 7. Prośby do innych ról

- **practice-modes:** (opcjonalnie) wagi `preferredExerciseTypes()` w doborze typów zadań i `ProfileLevel.estimate` dla poziomu treści (§2). Domyślne tryby i czas na ekranie Nauka są już wpięte (`StudyHomeView.applyProfileDefaults`).
- **reading-redesign / ui-learning:** podsumowanie czytanki i zestawów gramatycznych może pokazać „+XP” przez `Progression.sessionGain(state, reviewIDs: [], historyIDPrefix: <id wpisu>)`; prefiks działa dla `practiceHistory` / `productionHistory`. Dla czytanki można liczyć różnicę `totalXP` przed i po `submitReading`.
- **recommendations / ui-library:** `TodayAnalysisCard` i `StatsAnalysisSection` używają `LearnerAnalyzer`, czyli `LevelEstimator`. Dla spójności z polecanymi słówkami poziom startowy z profilu (`ProfileLevel.estimate`) przydałby się też tam, dopóki pewność jest `insufficient`/`low`.
- **code-qa:** testy aplikacji dla `UsefulWordsOwnership.merged`, `OnboardingModel.starterEntryIDs` i `AddWordLogic.knownSenseIndices` (contentRef).
- **topic-search:** komentarz w `TopicSearchTests.swift:111` wspomina usunięty `TodayOnboardingView.situations`; sam test jest samodzielny.

## 8. Testy

Nieuruchomione (brak Swift na Windows).

**`ProgressionTests` (12):**
- XP za odpowiedź według umiejętności, podpowiedzi i literówki;
- zniżki za powtórki tego samego dnia i pełne XP następnego dnia;
- odpowiedzi demo i z czytanki;
- premie za cel i serię, przerwa w serii;
- limit progu celu;
- czytanki, zestawy i produkcja oraz skompaktowana historia (z datami UTC);
- niezależność od kolejności i od kierunku `mergeStates`;
- XP sesji z awansem i z prefiksem sesji łączonej;
- krzywa poziomów i rangi;
- podsumowanie (dziś, tydzień, liczba dni nauki, tekst);
- **symulacja 7/30/90 dni** z dokładnymi wartościami i tempem awansów;
- farmienie;
- wydajność: 90 dni × 120 odpowiedzi poniżej 2 s w debug.

**`LearnerProfileTests` (15):**
- round-trip w ustawieniach;
- stare ustawienia bez klucza;
- nieznane i uszkodzone wartości z migracją;
- normalizacja;
- scalanie w obie strony;
- wagi tematów i tryby nauki;
- wszystkie tematy i grupy profilu istnieją w treści;
- poziom startowy kontra historia;
- tematy i wpisy na start;
- test poziomu na danych syntetycznych (kształt, determinizm, punktacja: ideał, zero, do B1, szczęśliwy strzał, pomyłka na A1);
- test poziomu na prawdziwej treści (20 ziaren, `XCTSkip` bez plików);
- `OwnedVocabulary` (zgodnie z regułą scalania);
- polecane słówka z profilem (powód `.interest`, rejestr specjalistyczny).

**Uruchomione skrypty (Node):**
- port balansu XP (wyniki w §4);
- kontrola składni wszystkich zmienionych plików: OK;
- tematy i grupy profilu względem `topics/index.json`: OK;
- pule testu poziomu na prawdziwym słowniku (dla C2 tylko 10 haseł, nadal wystarcza);
- gramatyka A2/B1/B2: 300/300 zadań nadaje się do testu.
