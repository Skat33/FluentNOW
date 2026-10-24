# Raport: test-mode (runda 6, FEEDBACK-6 K4 — „Test”)

## 1. Co zrobiono (pliki)

**FluentKit — nowy moduł `Sources/FluentKit/Assessment/`** (czyste funkcje, RNG wstrzykiwany):
- `AssessmentTypes.swift` — `AssessmentBlock` (9 bloków w stałej kolejności, liczba pytań, typ ćwiczenia, umiejętność, czas), `AssessmentSkill`, `AssessmentTier` (lower / upper / stretch), `AssessmentBand` (pasmo `[poziom−1, poziom]` + `poziom+1`).
- `AssessmentSession.swift` — stan testu: `AssessmentCandidate`, `AssessmentVocabQuestion`, `AssessmentTextQuestion`, `AssessmentQuestion` (enum, ręczne Codable z `kind`), `AssessmentItemResult`, `AssessmentAnswer`, `AssessmentSession` (ręczne Codable, tolerancyjne, `repair()` przywraca niezmienniki).
- `AssessmentHistory.swift` — `AssessmentHistoryEntry` (data, poziom bazowy, szacowany poziom, %, punkty, liczba pytań, czas, id czytanki, % per umiejętność).
- `AssessmentAdaptation.swift` — adaptacja (3 dobre z rzędu → górna część pasma, 2 błędy → dolna, „stretch” maks. 15% i tylko po passie 4 dobrych, nigdy dwa z rzędu).
- `AssessmentBuilder.swift` — poziom bazowy, wybór tematów, filtr wpisów z bazy, budowa testu (słowa, gramatyka, czytanka, plan bloków).
- `AssessmentEngine.swift` — losowanie bieżącego pytania, zapis odpowiedzi (FSRS dla moich słów), pomijanie, kończenie (wpis historii), porzucanie, zamykanie wyniku, „oznacz błędne jako trudne”; `AssessmentText` (pytanie/odpowiedź wzorcowa do listy błędów).
- `AssessmentScoring.swift` — wynik %, per blok, per umiejętność, per część pasma, szacowany poziom z uczciwym opisem, lista błędów, referencje słów z bazy do dodania.

**FluentKit — zmiany w istniejących plikach:**
- `Models/LearnerState.swift` — pola `assessment: AssessmentSession?` i `assessmentHistory: [AssessmentHistoryEntry]` (ręczne Codable: `lenientOptional` / `lossyArray`; `assessment` kodowany jak `combined` — zawsze, `null` gdy brak), parametry init z wartościami domyślnymi na końcu.
- `Sync/StateSync.swift` — unia `assessmentHistory` po `id` (sort po `at`) + `mergeAssessment` (ten sam test: ukończony > więcej odpowiedzi > nowszy; różne: nowszy; nieukończona kopia testu, który jest już w historii, znika).
- `ImportExport/StateMigration.swift` — naprawa testu (`repair`, dolosowanie bieżącego pytania, odrzucenie pustego/niespójnego).
- `Tests/FluentKitTests/AssessmentTests.swift` — nowy (18 testów, §6).

**Aplikacja — nowe `Features/Study/Test/`:**
- `StudyTestCard.swift` — karta „Test” (init bez argumentów; study-layout wstawił ją w `StudyHomeView`). Stany: „Rozpocznij test” / „Kontynuuj test” + „Porzuć” (z potwierdzeniem) / „Zobacz wynik”; ostatni wynik z historii.
- `StudyTestScreen.swift` — pełny ekran (`fullScreenCover`), przebieg, „Dalej” / „Nie wiem”, zamknięcie z wyborem „Wyjdź — dokończę później” / „Porzuć test”.
- `TestRunViews.swift` — nagłówek postępu (pasek, „5 / 30”, zegar orientacyjny bez limitu), etap tekstu czytanki, pytanie gramatyki/czytanki.
- `TestSessionModel.swift`, `TestQuestionModel.swift` — modele (`@Observable`, `@MainActor`).
- `TestLoader.swift` — wczytanie treści z `ContentLibrary` i budowa testu w `Task.detached`; „Dodaj nowe słowa do nauki” (`VocabularyMerger.addTopicEntries`).
- `TestResultView.swift` — wynik: %, poziom z opisem, akcje na słowach, typy zadań, umiejętności, lista błędów.

**Aplikacja — rozszerzenia istniejących widoków zadań (tryb testu parametrem z wartością domyślną, uzgodnione ze study-layout):**
- `Session/VocabExerciseModel.swift` — `init(…, assessment: Bool = false)`, `isAssessment`, `assessmentReady`, `submitAssessment()`, `giveUpAssessment()`; w trybie testu: bez podpowiedzi, bez asystenta AI, jedna próba (bez drugiej szansy w polu, wyborze i rozsypance), wybór opcji zatwierdzany dopiero „Dalej”, „Wybierz znaczenie” zawsze jako wybór z 4 opcji (bez „Pokaż warianty”).
- `Session/VocabExerciseView.swift` — bez panelu wyniku i komunikatu VoiceOver w teście.
- `Session/VocabAnswerArea.swift` — bez „Sprawdź” (zastępuje je „Dalej” ekranu), opcje tylko z zaznaczeniem wyboru (bez poprawnej/błędnej).
- `Session/VocabListeningViews.swift` — jw. dla „Zrozum ze słuchu”.
- `Session/VocabScrambleViews.swift` — bez podpowiedzi (tłumaczenia) i bez „Sprawdź”.
- `Session/VocabPrompts.swift` — luka: „Uzupełnij zdanie brakującym słowem” (słowo może być z bazy).

**Postępy:** nowe `Features/Stats/StatsTestHistorySection.swift` (ostatnie 6 testów: data, poziom, %, pasek, liczba pytań, czas, poziom testu) + jedno wpięcie w `StatsRootScreen` (`topSection`, 7 widoków < 10).

**Trwałość (zgoda platform-services, lista kontrolna koordynatora):**
- `Services/Persistence/Records.swift` — `SessionKind.assessment`, `HistoryKind.assessment`.
- `Services/Persistence/LearningRepository.swift` — `fetchAll`: dekodowanie sesji i historii (nowy `case` w wyczerpującym `switch`), przekazanie do `LearnerState(...)`; `applyChanges`: `upsertHistory(kind: .assessment, …)` i `upsertSession(.assessment, …)`.
- `Services/Store/LearningStore.swift` — `mergePreloadChanges`: `merged.assessment = preload.assessment ?? loaded.assessment` (historie scala `mergeStates`).
- `FluentNOWTests/Services/RepositoryTests.swift` — 3 testy (§6).
- `docs/reports/platform-services.md` — notka w §3.
- Sprawdzone: `StateMigration` (naprawa testu), `StateExporter.exportJSON` (koduje `LearnerState` → zawiera test i historię, `assessment: null` jak `combined`), `StateImporter` (dekoduje `LearnerState` — stare eksporty bez kluczy dają `nil`/`[]`, uszkodzony test jest odrzucany, nie dokument), import `.merge` = `mergeStates` (unia historii).

## 2. Projekt (wdrożony)

**Skład (~30 pytań, plan ok. 20 min, bez twardego limitu):** Wybierz znaczenie 4 → Przypomnij sobie PL→EN 4 → Uzupełnij lukę 4 → Ułóż zdanie 3 → Dopasuj pary 1 plansza (5 par) → Zrozum ze słuchu 4 → Dyktando 3 → Gramatyka 4 → Czytanka (1 tekst, 3 pytania). „Słowo i zdjęcie” pominięte. Blok, którego nie da się zbudować (np. brak słów z tłumaczeniem zdania do słuchania), dostaje mniej pytań albo znika; test z mniej niż 8 pytaniami nie jest oferowany.

**Poziom bazowy:** `ProfileLevel.estimate` (LevelEstimator; bez historii — poziom z wywiadu / szybkiego testu). Jeśli szacunek nie jest pewny (`confidence != .high`), a ostatni test jest młodszy niż 90 dni — poziom z tego testu (najbardziej bezpośredni pomiar).

**Słowa:** tylko poziomy z pasma `[poziom−1, poziom]` + maks. 15% poziomu wyżej. Kolejność puli: moje słowa z pasma już ćwiczone (losowo) → moje nowe → słowa z bazy z moich tematów (tematy moich słów + tematy profilu) → reszta bazy (tematy z największą liczbą słów z pasma, łącznie 8 plików). Z bazy tylko `very_common`/`common`, z przykładem, których nie mam (ani tego hasła w innym znaczeniu); maks. 30 na część pasma i 6 „wyżej”, przykłady przycięte do 3 (rozmiar zapisanego testu). Jedno słowo = jedno pytanie w całym teście. Pytanie losowane dopiero przed pokazaniem (adaptacja), pierwsze — przy budowie.

**Adaptacja:** przed pierwszą passą części pasma na przemian (od dolnej — rozgrzewka); 3 dobre z rzędu → górna, 2 błędy → dolna (do przeciwnej passy). „Wyżej” tylko na górnej części po 4 dobrych z rzędu, nie dwa razy z rzędu, łącznie ≤ 15% pytań słownikowych (23 → 3). Plansza par nigdy z „wyżej”. Gramatyka (z `GrammarSelector`, najpierw niewidziane zadania; opcje przetasowane, **bez nazwy konstrukcji** w poleceniu — zdradzałaby odpowiedź) i czytanka (`ReadingSelector`, pomija teksty z poprzednich testów) — na poziomie bazowym.

**Zasady:** bez podpowiedzi i „Pokaż warianty”, bez informacji poprawne/błędne (tylko „Dalej”; zaznaczenie wyboru można zmienić do „Dalej”), „Nie wiem” = błąd, nie można wrócić (`answers` tylko rośnie, `index` tylko w przód, odpowiedź po zakończeniu nic nie zmienia). Pasek postępu + zegar „Czas: 6 min · zaplanowano ok. 20 min (bez limitu)”. Wyjście = test zapisany (każda odpowiedź od razu w `store.update(.answer)`), powrót od bieżącego pytania; „Porzuć” usuwa test (odpowiedzi na moje słowa zostają w historii powtórek). Czytanka: najpierw sam tekst (bez tłumaczeń słów), potem pytania z pamięci.

**Wpływ na naukę:** odpowiedzi na moje słowa → `Scheduler.recordAnswer` (pewność 2, bez podpowiedzi, sesja słownictwa odłączona — przerwana sesja nie jest ruszana), plansza → `MatchPairsExercise.record(advancesSession: false)` tylko dla moich par. Słowa z bazy nigdy nie trafiają do `state.words` (żyją w `session.bankWords`, ID `test:<ref>`), chyba że użytkownik je doda. Zadania gramatyki oznaczane jako widziane.

**Wynik:** % (plansza liczy udział dobrych par), per typ zadania, per umiejętność (rozpoznawanie, przypominanie i pisownia, użycie, słuchanie, gramatyka, czytanie), szacowany poziom: <10 odpowiedzi → bez wniosku; część bazowa (słowa z poziomu + gramatyka + czytanka) ≥ 80% → poziom pewny, a gdy ≥ 2 pytania „wyżej” i ≥ 66% z nich → poziom wyżej („above”); ≥ 60% → potwierdzony z lukami; inaczej dolny poziom pasma („podstawy pewne”) albo „A2 lub niżej”. Każdy opis kończy się zdaniem: „To szacunek z N pytań w paśmie X–Y — wskazówka do nauki, nie wynik egzaminu.” Lista błędów (pytanie, poprawnie, moja odpowiedź, „Twoje słowo”/„Z bazy”). Akcje: „Dodaj błędne słowa do powtórek (N)” = moje błędne słowa oznaczone jako trudne (tryb pomyłek, fiszki „Trudne”; FSRS i tak już ma ocenę Again); „Dodaj nowe słowa do nauki (N)” = błędnie odpowiedziane słowa z bazy dodane do słownika (kolekcja = temat). Historia w Postępach (data, wynik, poziom).

## 3. Przykładowy skład testu z symulacji (prawdziwa treść, bez własnych słów)

Symulacja: skrypt Node (port logiki budowy/adaptacji w uproszczeniu, scratchpad `simulate-test.mjs`) na `Resources/Content`, ziarno 7, wzór odpowiedzi 1101 (✓✓✗✓…). W aplikacji przy własnych słowach pula zaczyna się od nich; RNG w aplikacji jest systemowy, więc konkretne słowa będą inne.

**A2** (pasmo A1–A2, +B1 maks. 3; tematy: numbers-time, greetings-introductions, colors-shapes-sizes, restaurant, countries-nationalities…):
- Znaczenie: A1 red, A2 feed the cat, A1 tea, A2 Ukrainian · Przypomnij: A1 busy (oblegany), A2 for here or to go, A2 go out, A2 what's up · Luka: A2 corner, on time, water the plants, British · Rozsypanka: A2 broken, count, triangle · Pary: stranger, do the laundry, long time no see, p.m., how's your… · Słuchanie: A2 server, appetizer, until, wide · Dyktando: A2 settings, work from home, sliced · Gramatyka A2: „Last Saturday, we ___ (pakować)…” → packed, … → collect, cooking, to bring · Czytanka A2 „A different gate” (3 pytania).
- Po 3 dobrych z rzędu (pyt. 4–6) test zostaje w górnej części pasma (A2) do końca, bo nie było 2 błędów z rzędu.

**B1** (pasmo A2–B1, +B2; tematy: smartphones-apps, airport, doctor-visit, office-work, cafe-bakery…):
- Znaczenie: A2 get better, B1 hanger, A2 espresso, B1 crash · Przypomnij: A2 cappuccino, B1 rich (sycący), get home safe, back up · Luka: B1 dress up, warranty, photo ID, loyalty card · Rozsypanka: B1 brownie, confirmation number, distracted · Pary: avoid, trend, first impression, lounge, carousel · Słuchanie: B1 reunion, treatment, stale, fly out · Dyktando: B1 stapler, duty-free, meet a deadline · Gramatyka B1: present perfect (have already packed), collected, cooking (past continuous), 2nd conditional (bring) · Czytanka B1 „The connection nobody missed”.
- Ten sam test przy samych dobrych odpowiedziach: po 4 dobrych pojawia się B2 co drugie pytanie (B2 on behalf of, B1 rich, B2 sourdough, B1 …, B2 workstation) i limit 3 jest wyczerpany. Przy wzorze 100 (słaby uczeń): po 2 błędach z rzędu prawie wszystkie pytania z A2 (gate, battery, check your phone, name tag…).

**C1** (pasmo B2–C1; tematy: work-idioms, elderly-care, finance-accounting, project-management, law-contracts…; brak słów C2 `common` w tych tematach → bez pytań „wyżej”):
- Znaczenie: B2 Medicare, C1 legally binding, B2 grab bar, C1 violate · Przypomnij: B2 funding, C1 storm off, persistence, liability · Luka: C1 fiscal year, chase, bicker, legal action · Rozsypanka: return on investment, low-hanging fruit, terminate · Pary: cash flow, testify, verdict, rule, crowdfunding · Słuchanie: C1 earnings, dignity, business model, settlement · Dyktando: C1 align, bottleneck, enforce · Gramatyka C1: inwersja („Only after… did we review”, „Never before had we amended”), mixed conditional, pseudo-cleft (allocate) · Czytanka C1 „The voice in the recording”.

Obserwacje z symulacji (wprowadzone poprawki): przy limicie 16 słów z bazy na część pasma górna część kończyła się ok. 16. pytania i reszta testu spadała do dolnego poziomu — limit podniesiony do 30; „wyżej” przychodziło blokiem 3 pytań pod rząd — teraz nigdy dwa z rzędu.

## 4. Publiczne API (FluentKit)

```swift
public struct AssessmentBand { init(base: String); base, lower, upper, stretch: String?; tier(of:) -> AssessmentTier?; level(of:); rangeText }
public enum AssessmentBuilder {
  static func baseLevel(_ state: LearnerState, now: Timestamp) -> String
  static func band(_ state: LearnerState, now: Timestamp) -> AssessmentBand
  static func topicIDs(state:index:band:limit:) -> [String]; static func learnerTopicIDs(_:) -> [String]
  static func bankEntries(topic: TopicFile, band:, fromLearnerTopics:) -> [AssessmentBankEntry]
  static func make<G: RandomNumberGenerator>(state:content:now:id:using:) -> AssessmentSession?
  static func bankWord(_:) -> Word; static func isBankID(_:) -> Bool
}
public enum AssessmentEngine {
  static func workingState(_ state: LearnerState, session: AssessmentSession) -> LearnerState
  static func prepareCurrent(_:state:) -> AssessmentSession
  static func answer(_ state: LearnerState, response: AssessmentResponse, now:, reviewID:) -> LearnerState
  static func skipCurrent(_:now:), abandon(_:), dismissResult(_:) -> LearnerState
  static func markWrongWordsHard(_:now:) -> (state: LearnerState, count: Int)
}
public enum AssessmentScoring { static func result(_:) -> AssessmentResult; historyEntry(_:result:at:); estimateLevel(band:overall:lower:upper:stretch:); wrongOwnedWordIDs(_:); wrongBankReferences(_:) }
public enum AssessmentAdaptation { cursor(after:), preferredTier(outcomes:position:stretchUsed:stretchCap:hasStretchLevel:lastWasStretch:), stretchCap(vocabularyCount:), tierOrder(_:) }
LearnerState.assessment: AssessmentSession?, LearnerState.assessmentHistory: [AssessmentHistoryEntry]
```
Aplikacja: `StudyTestCard()` (init bez argumentów), `StudyTestScreen()`, `StatsTestHistorySection()`; `VocabExerciseModel(…, assessment: Bool = false)`.

## 5. Odstępstwa i decyzje

- „Wybierz znaczenie” w teście zawsze z czterema opcjami (wpisywanie po polsku bez „Pokaż warianty” byłoby trudne do uczciwej oceny; produkcję mierzą „Przypomnij sobie” i dyktando).
- Literówka w wpisywanej odpowiedzi = błąd (brak „Uznaj moją odpowiedź” w teście); poprawna forma widoczna w liście błędów.
- „Dopasuj pary”: plansza z natury pokazuje połączenie i mignięcie błędnej pary (bez tego nie da się jej rozwiązać); pomyłki liczą się do wyniku, nie ma podpowiedzi. Po ostatniej parze test przechodzi dalej sam; „Nie wiem” liczy niepołączone pary jako błędne.
- Tekst czytanki w teście jest zwykłym tekstem (bez `ReadingPassageCard`, w którym dotknięcie słowa pokazuje tłumaczenie — to byłaby podpowiedź).
- Gramatyka bez nazwy konstrukcji w poleceniu (w zwykłej praktyce jest).
- Wynik „Dodaj nowe słowa do nauki” dotyczy słów z bazy z błędną odpowiedzią (dobrze znane nie są dokładane).
- Bez asystenta AI w teście (ocena tylko lokalna, bez oczekiwania).

## 6. Testy

FluentKit `AssessmentTests` (18): pasmo (B1, A1, C2, nieznany), kursor/passy/limit „wyżej”, poziom bazowy (profil vs świeży test, stary test ignorowany), pełny test 30 pytań w kolejności bloków, tylko poziomy z pasma, bez rzadkich i C2, czas 15–22 min, gramatyka bez konstrukcji z zachowanym kluczem, moje słowa pierwsze + determinizm z tym samym ziarnem, bez słów z bazy, które mam, brak testu bez treści, zapis odpowiedzi (recenzje tylko dla moich słów, przerwana `VocabSession` nietknięta, brak słów z bazy w słowniku, `grammarSeen`, historia, kompaktowanie), brak cofania, każde słowo raz i ≤15% „wyżej”, 3 dobre → górna / 2 błędy → dolna, pominięcie usuniętego słowa, porzucenie/zamknięcie, wynik per blok/umiejętność/błędy + „trudne” + referencje z bazy, szacowanie poziomu (solid/above/confirmed/below/belowBand/uncertain + uczciwa notka), Codable (round trip, `assessment: null`, stary JSON, uszkodzony test odrzucony), migracja (dolosowanie pytania, idempotencja, pusty test usunięty), scalanie (unia historii, więcej odpowiedzi wygrywa, ukończony na innym urządzeniu znika).
Aplikacja `RepositoryTests`: round trip testu i historii (+ zamknięcie testu), wpis historii „z innego urządzenia” przeżywa `reloadAfterRemoteChange` + `mergeStates` + `save` (rekord nie jest kasowany), `mergePreloadChanges` zachowuje zapisany test.
Uruchomione: tylko symulacja Node (§3) i sprawdzenie nawiasów/cudzysłowów nowych i zmienionych plików Swift (wszystkie zbilansowane). Kompilacji i XCTest nie dało się uruchomić na Windows.

## 7. Ryzyka kompilacji / niesprawdzone (miejsca)

1. `AssessmentSession.init(from:)` — wywołanie `repair()` (metoda `mutating`) na końcu inicjalizatora po przypisaniu wszystkich pól; `AssessmentBand` z syntetyzowanym `Codable` obok własnego `init(base:)`.
2. `AssessmentBuilder.randomOrder` / `shuffledOptions` — generyczne `inout G`, wywoływane kwalifikowane (`AssessmentBuilder.…`), osobne `let` dla każdego wywołania z `&rng` (bez dwóch dostępów `inout` w jednym wyrażeniu).
3. `AssessmentEngine.recordBoard` — `flatMap`/`map` na krotce `(Word, Meaning)?` z jawnymi typami; `MatchPairsExercise.boardTask` jest `internal` (ten sam moduł).
4. `AssessmentScoring` — `blocks[key, default: …].add(…)` (mutujący dostęp przez subscript z domyślną), `String(format:)`.
5. `TestSessionModel.result` — getter zapisuje `@ObservationIgnored` cache (klasa); `cachedResult` jako opcjonalna krotka.
6. `TestLoader.makeSession` — `@MainActor static` + `Task.detached` przechwytujący `LearnerState`/`AssessmentContent` (Sendable) i `var SystemRandomNumberGenerator` w środku.
7. `VocabExerciseModel` — nowe `let isAssessment` w klasie `@Observable`; `self.assistant = assessment ? nil : assistant`.
8. `VocabScrambleViews.checkButton` — teraz `@ViewBuilder private func … -> some View` z `if` (w `ViewThatFits`).
9. `StudyTestCard.body` — `let info = …` przed wyrażeniem z modyfikatorami (deklaracja w result builderze); `TestCardInfo.Status` z wartościami powiązanymi i syntetyzowanym `Equatable`.
10. `RepositoryTests.testPreloadChangesKeepTheSavedTest` oznaczony `@MainActor` (`LearningStore` jest `@MainActor`).
11. Niesprawdzone w działaniu: wydajność budowy przy bardzo dużym słowniku (pula własnych ≤ 240, sprawdzanie budowalności typów — w `Task.detached`), rozmiar zapisanego testu (≤ 66 słów z bazy × ≤ 3 przykłady; zapisywany przy każdej odpowiedzi), zachowanie klawiatury przy Enter w polu (Enter kończy zadanie → `onChange(isFinished)` → zapis).

## 8. Prośby do innych ról

- **study-layout:** nic więcej — `StudyTestCard()` jest już wstawiona; pliki `Study/Session/*` rozszerzone wyłącznie parametrem `assessment` (domyślnie bez zmian zachowania).
- **english-qa / content:** w C1 brak słów C2 `very_common/common` w tematach z pasma — test C1 nie ma pytań „wyżej” (to poprawne, ale warto wiedzieć). Niektóre tłumaczenia z bazy brzmią w izolacji nieoczywiście w „Przypomnij sobie” (np. „busy” → „oblegany”, „rich” → „sycący”) — to treść tematów, nie testu.
- **code-qa:** sprawdzić na Macu punkty z §7 i uruchomić `swift test --filter AssessmentTests` oraz `RepositoryTests`.
