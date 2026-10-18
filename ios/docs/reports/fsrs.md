# Raport: fsrs — algorytm powtórek FSRS-6 (FEEDBACK-4 §I1)

Stan: kod i testy napisane na Windows **bez kompilatora**. Wzory zweryfikowano portem w Node, który odtwarza dokładnie wartości z oficjalnych testów ts-fsrs (§6).

## 0. Źródło i wersja

- **Wersja:** FSRS-6.0 (aktualna stabilna; ts-fsrs opisuje się jako „using FSRS-6.0”, py-fsrs ma 21 parametrów).
- **Źródła (pobrane 2026-10-18):**
  - `open-spaced-repetition/ts-fsrs`: `packages/fsrs/src/algorithm.ts` (wzory), `src/constant.ts` (`default_w`, `S_MIN = 0.001`, `S_MAX = 36500`, retencja 0.9, short-term włączony, fuzz domyślnie wyłączony), `__tests__/FSRS-6.test.ts` (wartości referencyjne);
  - `open-spaced-repetition/py-fsrs`: `fsrs/scheduler.py` (te same wagi, granice parametrów, kroki 1 m/10 m, ponowna nauka 10 m, `maximum_interval = 36500`);
  - wiki `awesome-fsrs/wiki/The-Algorithm` (sekcja FSRS-6: R(t,S), krzywa, SInc ≥ 1 dla G ≥ 2, wagi).
- **Domyślne wagi w0…w20:**
  `0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542`
- **Wzory (FSRS-6):** decay = −w20, factor = 0.9^(1/decay) − 1; R(t,S) = (1 + factor·t/S)^decay; I = S/factor·(r^(1/decay) − 1), zaokrąglone, min. 1; S0 = max(w[G−1], 0.1); D0 = w4 − e^(w5(G−1)) + 1; D′ = clamp(w7·D0(Easy) + (1−w7)·(D + ΔD·(10−D)/9), 1, 10), ΔD = −w6(G−3); S′r = S·(1 + e^w8·(11−D)·S^−w9·(e^((1−R)w10) − 1)·hard·easy) (hard = w15, easy = w16); S′f = min(w11·D^−w12·((S+1)^w13 − 1)·e^((1−R)w14), S/e^(w17·w18)); w tym samym dniu: S′ = S·e^(w17(G−3+w18))·S^−w19, a dla Hard/Good/Easy mnożnik ≥ 1. Czas, który upłynął, liczony w pełnych dniach (jak py-fsrs i ts-fsrs).

## 1. Co zrobiono (pliki)

| Plik | Zmiana |
|---|---|
| `FluentKit/Scheduling/FSRS.swift` (nowy) | Czysty model FSRS-6: `Rating`, `MemoryState`, wagi, retrievability, interval, S0/D0, aktualizacje D/S, `nextState`, walidacja/przycinanie |
| `FluentKit/Scheduling/Scheduler.swift` | `schedule` i `recordAnswer` liczą przez FSRS (sygnatury bez zmian); nowe: `rating(...)`, `review(...)`, `memory(of:)`, `legacyMemory(_:)`, stałe `maximumInterval = 365`, `relearningInterval = 10 min`, `easySpeedShare = 0.5` |
| `FluentKit/Scheduling/Mastery.swift` | tylko komentarz (opanowanie dalej z interwału, §3) |
| `FluentKit/Models/Score.swift` | opcjonalne `stability`, `difficulty`, `reps`, `lapses` (+ `memoryState`), ręczne `encode` z `encodeIfPresent`, `decodeIfPresent` z walidacją (stan połowiczny lub błędny → `nil`) |
| `FluentKit/Models/LearnerSettings.swift` | opcjonalne `desiredRetention: Double?` (+ `effectiveRetention`), wstecznie zgodne |
| `FluentKit/Sync/StateSync.swift` | `mergeScores`: cały stan FSRS jedzie z wynikiem (wg `last`); remis → kopia ze stanem FSRS |
| `FluentKit/ImportExport/StateMigration.swift` | interwał przycinany do 365 (a nie 90 — inaczej każdy odczyt ścinałby interwały FSRS); sanityzacja pól FSRS |
| `Tests/FluentKitTests/FSRSTests.swift` (nowy) | 19 testów (§6) |
| `Tests/FluentKitTests/SchedulingTests.swift` | 3 asercje zaktualizowane (§6) |
| `FluentNOW/Features/Settings/SettingsRetentionPicker.swift` (nowy) | wiersz „Docelowa skuteczność powtórek” (85 / 90 zalecane / 95%) |
| `FluentNOW/Features/Settings/SettingsSections.swift` | jedna linia: `SettingsRetentionPicker()` w sekcji „Twój rytm nauki” |

## 2. Publiczne API / kontrakty

```swift
// bez zmian
Scheduler.schedule(_ old: Score?, correct:seconds:confidence:hint:now:type: = .recall, weight: = 1) -> Score
Scheduler.recordAnswer(_ state:, task:, correct:, seconds:, confidence:, hint:, spellingCorrect: = nil, weight: = 1, source: = .exercise, now:, reviewID: = UUID…) -> LearnerState
// nowe
public enum FSRS {
    enum Rating: Int { again = 1, hard, good, easy }
    struct MemoryState { var stability: Double; var difficulty: Double; init(stability:difficulty:) }
    static let defaultParameters: [Double]; defaultRetention = 0.9; retentionChoices = [0.85, 0.9, 0.95]
    static let retentionRange = 0.7...0.97; minimumStability; maximumStability; difficultyRange
    static func retrievability(elapsedDays:stability:) -> Double
    static func rawInterval(stability:retention:) -> Double
    static func interval(stability:retention:maximum: = 36_500) -> Double
    static func clampedRetention(_:) -> Double
    static func initialStability(_:) / initialDifficulty(_:) -> Double
    static func nextDifficulty(_:rating:) / nextRecallStability(difficulty:stability:retrievability:rating:)
    static func nextForgetStability(difficulty:stability:retrievability:) / nextShortTermStability(stability:rating:)
    static func nextState(_ memory: MemoryState?, elapsedDays: Double, rating: Rating) -> MemoryState
    static func validated(_:) -> MemoryState?
}
Scheduler.rating(correct:hint:typo: = false, seconds:confidence:type:) -> FSRS.Rating
Scheduler.review(_ old: Score?, rating:hint:slow:now:weight: = 1, retention: = 0.9) -> Score
Scheduler.memory(of: Score) -> FSRS.MemoryState?
Scheduler.legacyMemory(_: Score) -> FSRS.MemoryState?
Scheduler.maximumInterval (365), relearningInterval (10/1440), easySpeedShare (0.5)
Score: + stability: Double?, difficulty: Double?, reps: Int?, lapses: Int?, memoryState: FSRS.MemoryState?
       init(... slow:, stability: = nil, difficulty: = nil, reps: = nil, lapses: = nil)
LearnerSettings: + desiredRetention: Double?, effectiveRetention: Double, init(..., profile:, desiredRetention: = nil)
```

## 3. Decyzje i odstępstwa (od strony i od „czystego” FSRS)

1. **Ocena odpowiedzi → FSRS:** błędna → Again; poprawna z podpowiedzią, z uznaną literówką (`spellingCorrect == false`), wolna (`> type.slowSeconds`) albo „Niepewnie” → Hard; poprawna, szybka (`≤ 0,5 × slowSeconds`) i „Bardzo pewnie” → Easy; reszta → Good. Domyślna pewność to „Całkiem dobrze” (2), więc Easy wymaga świadomego wyboru „Bardzo pewnie”. Umiejętność `spelling` przy literówce dalej dostaje Again (jak dotąd).
2. **Czytanie:** waga 0,35 jak dotąd. Stan FSRS (S i D) przesuwa się o 35% drogi w stronę pełnego wyniku, S nigdy nie maleje, a interwał nigdy się nie skraca (`max(poprzedni, nowy)`). Pytania z czytanki mają stałe 15 s i pewność 2, więc poprawna odpowiedź to **Good**, nie Hard. Przy 15 s > 12 s byłby to Hard, a wtedy każda czytanka podnosiłaby trudność słowa. Błędna odpowiedź z czytania liczy się w pełni (Again), jak dotąd.
3. **Kroki nauki:** bez kroków 1 m/10 m dla nowych kart, bo aplikacja ma już progresję typów ćwiczeń, a sesja sama wraca do błędów. Hard/Good/Easy od razu dają interwał FSRS (nowa karta: 1/2/8 dni). **Again = 10 minut** (krok ponownej nauki jak w py-fsrs i jak było). Nowa, niższa stabilność zostaje zapisana. Powtórka w tej samej sesji idzie przez formułę tego samego dnia (FSRS-6 w17–w19).
4. **Bez fuzz:** funkcja jest czysta i deterministyczna (`schedule` nie dostaje RNG). Rozrzut terminów daje i tak to, że słowa są dodawane w różnych dniach. Fuzz w ts-fsrs jest domyślnie wyłączony.
5. **Maks. interwał 365 dni** (strona: 90, FSRS: 36 500). Migracja przycina teraz do 365.
6. **Opanowanie zostaje z interwału** (`Mastery.fromInterval`, log, 90 dni = 100). Przy retencji 0,90 interwał FSRS ≈ stabilność, więc 85% ≈ stabilność ≥ ~45 dni, czyli FSRS przewiduje ≥ 90% przypomnienia po półtora miesiąca. Próg „Opanowane” zachowuje więc sens. Zostają też zgodne `Review.before/after` (wersja 2), statystyki „przekroczeń progu”, XP i status „Trudne”. Skutek uboczny: przy 95% interwały są ~2,6× krótsze, więc opanowanie rośnie wolniej, a przy 85% szybciej („chcę większej pewności” = dłuższa droga do „Opanowane”). Przy dobrych odpowiedziach umiejętność dochodzi do 85 po 3 powtórkach (2 → 11 → 46 dni); stary algorytm potrzebował ~5.
7. **Migracja starych wyników (leniwie, przy pierwszej odpowiedzi):** S = dawny interwał (0,212…90), bo stary harmonogram też celował w powtórkę „tuż przed zapomnieniem”. D = D0(Good) 2,118 + 1,2 × bieżące błędy (maks. 6) + 0,4 × (podpowiedzi + wolne) (maks. 5), w zakresie 1…10, więc słowa „Trudne” (≥ 3 błędy) startują od D ≥ 5,7. Do tego reps = correct + wrong, lapses = wrong. Wynik bez żadnej odpowiedzi to nowa karta. Stare JSON-y (strona, eksport, iCloud) dekodują się bez zmian. Eksport wyniku bez stanu FSRS nie zawiera nowych kluczy, więc strona dostaje ten sam format.
8. **Liczniki aplikacji bez zmian:** `wrong` (naprawiany przez samodzielne poprawne odpowiedzi), `hinted`, `slow`, `correct`, `last`, `due`, `interval`, `value`. Kolejki, statystyki i XP działają jak dotąd.
9. **Scalanie iCloud:** per umiejętność wygrywa wynik z późniejszym `last` razem z całym stanem FSRS (S/D/reps/lapses nie są mieszane między urządzeniami). Przy remisie `last` wygrywa kopia, która ma już stan FSRS.
10. **Retencja:** `settings.desiredRetention` (nil = 0,90). Przycinana do 0,70…0,97, a w Ustawieniach do wyboru 85/90/95%. Działa od następnej odpowiedzi i nie przelicza istniejących terminów. Scalanie stanów bierze ustawienia z `local` (jak pozostałe ustawienia).

## 4. Ryzyka / niesprawdzone

- **Brak kompilacji.** Przejrzane ręcznie: nawiasy (skrypt), brak `!`/`try!`/`as!`/`fatalError`, jawne `public init`, `Codable` ręcznie (`Score.encode` teraz ręczny, te same klucze, eksport ma `.sortedKeys`). Mniejsza pewność:
  - zagnieżdżony ternary z wywołaniem funkcji w `recordAnswer` (`let primaryRating: FSRS.Rating = …`, typ podany jawnie);
  - parametr `rating:` w `Scheduler.review` przesłania statyczną funkcję `rating(...)`. W ciele `review` nie jest ona wołana, więc powinno być OK.
- Testy z wartościami dokładnymi (`XCTAssertEqual(intervals, [2, 11, 46, 163, 365])` itd.) zależą od zaokrąglenia `x.rounded()` (do najbliższej, .5 od zera = `Math.round` dla dodatnich). Wartości nie leżą blisko .5 (sprawdzone w Node).
- Wszystkie testy, które asertowały stary harmonogram, zaktualizowano (§6). Gdyby jakiś inny test (np. w `FluentNOWTests`) zakładał 12 h po podpowiedzi albo ≤ 90 dni, wymaga podobnej poprawki. Grep nie znalazł takich.
- Parametry są domyślne, bez optymalizacji pod użytkownika (optymalizator FSRS to osobny, duży temat; ewentualnie w przyszłości z historii `reviews`).
- Licznik `slow` dla pytań z czytania nadal rośnie (stałe 15 s > 12 s), jak przed zmianą. Wpływa tylko na sortowanie w trybie „Pomyłki”.

## 5. Prośby do innych ról

- **new-exercises:** nic do zmiany. Nowe typy (`.scramble`, `.matchPairs`, `.listeningChoice`) działają przez `slowSeconds` (bez `switch` po `ExerciseType` w moim kodzie). Wysłałem krótką informację przez SendMessage.
- **insights-scan / ui-library (opcjonalnie):** szczegóły słowa mogłyby pokazywać „Pamięć: X% teraz” = `FSRS.retrievability(elapsedDays:stability:)` z `Score.stability`. Raport tygodniowy może pokazywać średnią stabilność.
- **platform-services:** brak zmian. `desiredRetention` jest w `LearnerSettings` (payload ustawień).

## 6. Testy i wyniki skryptów

**Nowe `FSRSTests.swift` (19 testów):**
- wartości z oficjalnych testów ts-fsrs FSRS-6:
  - pierwsza ocena: S = [0.212, 1.2931, 2.3065, 8.2956], D = [6.4133, 5.11217071, 2.11810397, 1];
  - sekwencja Again, Good×5 przy Δt [0,0,1,3,8,21] → S 53.62691, D 6.3574867;
  - `ivl_history` [0,2,11,46,163,498,0,0,2,4,7,12,21];
  - R(8, 8.2956) = 0.9024733;
- interwał zależny od retencji (S=10 → 19/10/4 dni);
- naprawa stanów błędnych;
- mapowanie ocen (9 przypadków);
- `schedule` na poziomie aplikacji (wartości z portu Node):
  - Good przy terminie → 2, 11, 46, 163, 365 dni;
  - lapsus → 10 min, S 9.239, D 7.381, lapses 1, retry tego samego dnia → 9 dni;
  - pierwsza odpowiedź per ocena;
  - czytanie (21 vs 22 dni, nigdy krócej; Good zamiast Hard);
- migracja starych danych:
  - stary wynik → S 3, D 3.718 → Good: 13 dni / S 12.801 / D 3.710;
  - Again: S 0.710;
  - „Trudne” → D > 5.7;
  - stary JSON bez pól FSRS, eksport bez nowych kluczy, round-trip, stan połowiczny/ujemny;
  - `StateMigration` zachowuje 200 dni, przycina 900 → 365, usuwa NaN, idempotentna;
- retencja w ustawieniach (dekodowanie bez klucza, 0.95, 7 → 0.97; `recordAnswer` drugi interwał 11 / 21 / 4 dni);
- uznana literówka = Hard (10 dni), pisownia = 10 min;
- scalanie iCloud per umiejętność wg `last` z całym stanem FSRS (w obu kierunkach) i remis → stan FSRS.

**Zaktualizowane w `SchedulingTests.swift` (zmiana zachowania):**
- `testHintsAre…`: interwał po podpowiedzi 0,5 → **1** (Hard daje co najmniej 1 dzień);
- `testIntervalIsBoundedAndGrows`: limit 90 → **365**;
- `testNaNAndNegativeTimesAreSafe`: 7,5 → **5** dni (stary S=3, ten sam dzień, Easy → S 5.0445).

Pozostałe asercje (10 min po błędzie, krótszy interwał po podpowiedzi, czytanie nie skraca, pisownia nie kasuje przypominania, status „Trudne”) przechodzą bez zmian; sprawdzone w porcie Node.

**Skrypty Node** (scratchpad `fsrs/`: `fsrs.mjs` port wzorów, `app.mjs` port `Scheduler`, `check.mjs`, `refs.mjs`, `sim.mjs`, `lint.mjs`):
- `check.mjs`: wszystkie trzy zestawy wartości ts-fsrs odtworzone dokładnie (53.626903 / 6.357487; ivl_history identyczne);
- `lint.mjs`: 11 plików OK (nawiasy, CR/BOM, brak force-unwrap).

**Symulacja 30/90 dni** (`sim.mjs`):
- Założenia:
  - 10 nowych znaczeń dziennie, nauka raz dziennie, powtórka wszystkiego, co wymagalne do 21:00;
  - błąd powtarzany w tej samej sesji (maks. 3 próby);
  - „prawdziwa” pamięć ucznia symulowana modelem FSRS-6 z domyślnymi wagami (standard benchmarków FSRS; może faworyzować FSRS);
  - pierwszy kontakt poprawny w 60%, 10% poprawnych z podpowiedzią;
  - średnia z 5 ziaren.

| okres | algorytm | powtórek | na dzień | skuteczność przy powtórce | średnie przypomnienie na koniec | ≥ 85% opanowania |
|---|---|---|---|---|---|---|
| 30 dni | stary (strona) | 1 737 | 57,9 | 92,5% | 95,7% | 0% |
| 30 dni | FSRS 0,85 | 1 296 (−25%) | 43,2 | 89,5% | 93,2% | 5,6% |
| 30 dni | **FSRS 0,90** | **1 616 (−7%)** | 53,9 | 92,2% | 96,2% | 0,9% |
| 30 dni | FSRS 0,95 | 2 231 (+28%) | 74,4 | 95,5% | 98,4% | 0% |
| 90 dni | stary (strona) | 7 788 | 86,5 | 92,5% | 95,6% | 22,4% |
| 90 dni | FSRS 0,85 | 5 434 (−30%) | 60,4 | 88,5% | 93,1% | 49,0% |
| 90 dni | **FSRS 0,90** | **6 801 (−13%)** | 75,6 | 91,9% | 95,6% | 33,7% |
| 90 dni | FSRS 0,95 | 10 612 (+36%) | 117,9 | 95,4% | 98,0% | 12,9% |

Wniosek: przy domyślnej retencji 0,90 FSRS daje to samo przypomnienie co stary algorytm (95,6%) przy 7% mniej powtórek po miesiącu i 13% mniej po kwartale. Różnica rośnie z czasem, bo interwały dochodzą do 365 dni, a nie do 90. Opcja 0,95 kosztuje ~1/3 więcej powtórek, a 0,85 oszczędza ~30% kosztem ~2,5 pkt przypomnienia.
