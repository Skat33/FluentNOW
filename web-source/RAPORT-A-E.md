# Fluent — raport zmian A–E

Wersja źródłowa poprzedzająca zmiany: v31, commit `ac55b3455f5e9a6061b3a13808ce20d0a930ab1a`.
Zakres odpowiada plikowi „Wklejony kod markdown(4).md”. Bez refaktoryzacji ekranów `app/views`.

## Wykonanie

| Sekcja | Punkt | Status | Zmienione pliki |
|---|---|---|---|
| A | A2: losowanie z dopuszczalnych typów, zachowana pierwsza fiszka i ochrona luki | zrobione | `lib/learning.ts`, `tests/learning.test.mjs` |
| A | A1: deterministyczne przeplatanie, bez utraty zadań i z zachowaniem kolejności w obrębie typu | zrobione | `lib/learning.ts`, `tests/learning.test.mjs` |
| A | A3: powtórki, następnie nowe znaczenia do wykorzystania budżetu | zrobione | `lib/learning.ts`, `tests/learning.test.mjs` |
| A | A4: pięć sesji, deterministyczność, zachowanie zadań i wypełnienie budżetu | zrobione | `tests/learning.test.mjs`, `scripts/session-simulation.mjs` |
| A | Bezwzględny zakaz dwóch/trzech jednakowych typów we wszystkich sesjach | pominięte | `lib/learning.ts`, `tests/learning.test.mjs` |
| B | B1: pole polskiego znaczenia i przycisk „Pokaż warianty” | zrobione | `app/fluent.tsx` |
| B | B2: dotychczasowy `hint`, również po wpisaniu tekstu po odsłonięciu wariantów | zrobione | `app/fluent.tsx`, `tests/learning.test.mjs` |
| B | B3: wspólne ocenianie lokalne/AI, polskie warianty i literówki | zrobione | `lib/tutor-local.ts`, `app/api/tutor/route.ts`, `tests/learning.test.mjs` |
| B | B4: zachowane kafelki, kolejność i wybieranie opcji | zrobione | `app/fluent.tsx` |
| C | C1–C2: zdanie, bezokolicznik, schematy i akcja `production` z cache | zrobione | `lib/tutor-types.ts`, `lib/tutor-json.ts`, `lib/tutor-schema.ts`, `lib/tutor-prompts.ts`, `app/api/tutor/route.ts`, `tests/tutor-routes.test.mjs` |
| C | C3: normalizacja skrótów, rozpoznanie dystraktorów, literówek i błędu ogólnego | zrobione | `lib/production.ts`, `tests/tutor.test.mjs` |
| C | Sprawdzenie literówki przed znanym dystraktorem | pominięte | `lib/production.ts` |
| C | C4: konstrukcje według CEFR i dotychczasowe źródło poziomu | zrobione | `lib/production.ts`, `lib/tutor-prompts.ts`, `app/api/tutor/route.ts`, `app/production-practice.tsx` |
| C | C5: osobny kafelek, wynik, podsumowanie, zapis i wznowienie | zrobione | `app/production-practice.tsx`, `app/fluent.tsx`, `app/globals.css`, `lib/learning.ts`, `lib/state-schema.ts`, `lib/state-sync.ts`, `tests/learning.test.mjs`, `tests/fixtures/state-v31.json` |
| C | C6: po cztery zadania A2, B1, B2 bez AI | zrobione | `lib/production.ts`, `tests/tutor.test.mjs` |
| D | Rosnący licznik, zatrzymanie po odpowiedzi, sprzątanie interwału, dostępność | zrobione | `app/fluent.tsx`, `tests/ui-components.test.mjs` |
| E | Pięć umiejętności, progi i miejsca wykorzystania oceny | zrobione | `lib/learning.ts`, `lib/tutor-local.ts`, `lib/state-schema.ts`, `app/fluent.tsx`, `app/tutor-ui.tsx`, `tests/learning.test.mjs`, `tests/tutor.test.mjs` |

Nie wycofano żadnej sekcji.

**Dlaczego pominięto dwa dosłowne warunki:**

- Pierwsza sesja musi składać się wyłącznie z fiszek; przy przewadze jednego typu pełne przeplatanie również bywa matematycznie niemożliwe. Algorytm zachowuje wszystkie zadania i rozkłada nadwyżkę tak, aby najdłuższy blok był możliwie najkrótszy.
- Sprawdzanie odległości ≤2 przed znanym dystraktorem zaliczałoby np. `was flying` zamiast `is flying`. Kolejność jest więc: poprawna forma → znany błędny wariant → literówka → błąd ogólny.

## Testy

Po każdej sekcji uruchomiono `npx tsc --noEmit` i pełne `npm test`.

| Etap | TypeScript | Testy poprawne | Testy oblane |
|---|---|---:|---:|
| A | OK | 83 | 0 |
| B | OK | 84 | 0 |
| C | OK | 87 | 0 |
| D | OK | 88 | 0 |
| E | OK | 89 | 0 |

Nazwy testów pozostających oblanymi: brak. Kompilacja produkcyjna zakończona poprawnie. Po kompilacji ponownie uruchomiono TypeScript i pełny zestaw: 89 poprawnych, 0 oblanych.

W trakcie sprawdzania C poprawiono porównanie migracji w teście: istniejąca migracja dodaje pola `undefined` oraz domyślne `weight`/`source`; nie oznacza to utraty starych danych. W D poprawiono zależność efektu licznika: sesja nie ma pola `id`. Wszystkie poprawki ponownie przeszły pełny zestaw testów.

Testy obejmują: polskie odpowiedzi i literówki, obniżenie wartości odpowiedzi po podpowiedzi, każde z 12 startowych zadań produkcyjnych, błędny czas i zgodność osoby, skróty `they’d`/`I’d`/`she’s`/`didn’t`, walidację wejścia API, wspólną pamięć wyników, zgodność starszego eksportu i synchronizację odpowiedzi, licznik oraz nową skalę opanowania.

## Symulacja A4: przed i po

40 nowych znaczeń, bez historii; pięć sesji po 10 minut, wszystkie odpowiedzi poprawne, 3 sekundy, pewność 3, bez podpowiedzi. Stałe ziarno 17 i stały zegar. Skrypt porównuje dokładny kod v31 z obecną implementacją. Pełne odtworzenie: `node scripts/session-simulation.mjs` w repozytorium zawierającym historię v31.

Legenda: 0 = fiszka, 1 = przypomnienie, 2 = luka, 3 = znaczenie, 4 = dyktando. Czas jest oszacowaniem sesji według `taskSeconds`, nie rzeczywistym czasem odpowiedzi.

| Sesja | Liczby typów 0/1/2/3/4 przed | Po | Zadania przed → po | Czas przed → po |
|---|---|---|---|---|
| 1 | 5 / 0 / 0 / 0 / 0 | 33 / 0 / 0 / 0 / 0 | 5 → 33 | 90 s → 594 s |
| 2 | 5 / 0 / 0 / 5 / 0 | 12 / 0 / 0 / 16 / 0 | 10 → 28 | 210 s → 600 s |
| 3 | 5 / 5 / 0 / 5 / 0 | 4 / 10 / 0 / 8 / 0 | 15 → 22 | 370 s → 584 s |
| 4 | 5 / 5 / 5 / 5 / 0 | 0 / 13 / 3 / 2 / 0 | 20 → 18 | 580 s → 590 s |
| 5 | 0 / 0 / 5 / 5 / 5 | 0 / 7 / 6 / 3 / 1 | 15 → 17 | 570 s → 596 s |

Dokładna kolejność:

```text
PRZED
sesja 1: 0 0 0 0 0
sesja 2: 3 3 3 3 3 0 0 0 0 0
sesja 3: 3 3 3 3 3 1 1 1 1 1 0 0 0 0 0
sesja 4: 2 2 2 2 2 3 3 3 3 3 1 1 1 1 1 0 0 0 0 0
sesja 5: 4 4 4 4 4 2 2 2 2 2 3 3 3 3 3
PO
sesja 1: 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
sesja 2: 3 3 0 3 3 0 3 3 0 3 0 3 0 3 0 3 0 3 0 3 0 3 0 3 0 3 0 3
sesja 3: 0 3 0 1 0 1 0 1 3 1 3 1 3 1 3 1 3 1 3 1 3 1
sesja 4: 1 1 1 2 1 1 2 1 1 2 1 1 3 1 1 3 1 1
sesja 5: 3 4 3 1 2 1 2 1 2 1 2 1 2 1 2 1 3
```

Pierwsza sesja wykorzystuje 594 z 600 sekund, zamiast 90. Pozostałe 6 sekund nie wystarcza na następne pełne zadanie. W sesji 2 nadwyżka typu 3 jest rozłożona w pary; w sesji 4 przy 13 zadaniach typu 1 i tylko 5 innych co najmniej jeden blok trzech jest nieunikniony. Nie usuwano zadań ani nie łamano progresji, by ukryć tę sprzeczność.

## E: progi i zgodność historii

- `mastery()` uśrednia rozpoznawanie, przypominanie, użycie, słuchanie i pisownię. Niećwiczone umiejętności = 0; wymowa nie wpływa na tę średnią. Jeden wynik 100 daje 20%, pięć wyników 100 daje 100%.
- Próg **80 → 85%** zmieniono spójnie dla „Opanowane”/„Do odświeżenia”, licznika poznanych znaczeń, propozycji trudniejszych słów lokalnych i AI oraz raportu tygodniowego. Przy progu 80 cztery wyniki 100 i jedna brakująca umiejętność nadal dawałyby etykietę opanowania.
- „Nowe” oznacza teraz rzeczywisty brak wyników, a nie zaokrąglenie średniej do zera. Słowo po pierwszej nieudanej próbie pozostaje „Uczę się” (lub „Trudne”).
- Próg „Trudne” pozostaje: co najmniej 3 błędy i wynik konkretnej umiejętności poniżej 65, albo ręczne oznaczenie. Dotyczy pojedynczej umiejętności, więc zmiana mianownika go nie zniekształca.
- Próg 40 dla mocniejszej podstawy oszacowania CEFR pozostaje. Jedna sprawdzona umiejętność nie daje już wysokiej pewności; awaryjne oszacowanie z posiadanego słownictwa pozostaje dostępne. Cel nadal jest o jeden poziom wyżej, maksymalnie C2.
- Sortowanie słownika, postęp kolekcji i poziomów, wybór najtrudniejszych słów oraz dobór znaczeń do czytanek korzystają z nowej średniej. Priorytet zaległych i trudnych znaczeń pozostaje bez zmian. Dobór typów sesji zależy od historii umiejętności i terminów, nie od progu 85.
- Nowe pomiary historii mają opcjonalny znacznik `masteryVersion: 2`. Starszych wartości `before/after` nie przepisujemy ani nie traktujemy jako nowej skali. Raport tygodniowy liczy przekroczenia progu na nowej skali; informacja o tym jest widoczna przy raporcie.
- Migracja jest addytywna dla stanu JSON, bez migracji tabel SQL: brakujące `production` → `null`, `productionHistory` → `[]`; brak znacznika historii zachowuje dawną interpretację. Test na eksporcie demonstracyjnym wygenerowanym kodem v31 potwierdza zachowanie słów i pomiarów oraz odtworzenie/synchronizację nowych odpowiedzi. Nie używano prywatnego eksportu użytkownika.

## Pozostałe decyzje i ograniczenia

- Produkcja gramatyczna jest osobnym ćwiczeniem i nie zmienia zadań słownikowych. Domyślnie AI przygotowuje 6 zadań; API akceptuje 4–10. Offline dostępne są po 4 zadania A2/B1/B2. Dla A1 offline wyświetlany jest rzeczywisty poziom A2, a dla C1/C2 — rzeczywisty B2, bez udawania wygenerowanego poziomu.
- Wynik odpowiedzi jest zapisywany od razu; nazwa konstrukcji pojawia się po odpowiedzi. B nie dodaje pól stanu — pola `production` należą wyłącznie do C.
- Licznik nie ma progów, kolorów ani ostrzeżeń. Wykorzystuje istniejący moment startu; wartości `slowSeconds` i logika harmonogramu pozostały bez zmian. Zatrzymanie wyświetlania nie zmienia czasu używanego przez ocenianie kolejnej próby.
- Sprawdzono [oficjalną dokumentację Gemini 3.8 Flash](https://ai.google.dev/gemini-api/docs/models/gemini-3.8-flash): limit wyjścia to 65 536 tokenów. Akcja produkcyjna używa 32 768, krótkich wyjaśnień i niskiego poziomu myślenia. Reprezentatywny zestaw 10 zadań z dystraktorami ma 7 184 bajty JSON. To pomiar rozmiaru, nie dokładne liczenie tokenów; brak podstaw do dzielenia tego zestawu na dwie paczki. Ucięte odpowiedzi nie są akceptowane. Test API potwierdza wysyłany budżet i kształt odpowiedzi.
- Generator był testowany z zamockowanym Gemini. W tym przebiegu nie potwierdzono generowania na żywym kluczu ani aktualnego dostępnego limitu tego konta. Nie obiecujemy usunięcia przeciążeń dostawcy.
- Podgląd przeglądarkowy jest niedostępny w środowisku. Nie wykonano wizualnego testu mobilnego ani kliknięć w rzeczywistej przeglądarce; kompilacja i testy automatyczne nie zastępują tej kontroli.

## Do weryfikacji ręcznej

1. Ćwiczenia → Produkcja gramatyczna: zacznij zestaw, odpowiedz, odśwież i wróć do tego samego zadania/wyniku; zakończ zestaw.
2. Wpisz poprawny skrót, literówkę oraz błędny czas — sprawdź różne wyjaśnienia.
3. W zadaniu znaczenia wpisz polskie tłumaczenie, następnie w innym zadaniu odsłoń warianty i odpowiedz tekstem; wynik powinien być wspomagany.
4. Sprawdź licznik: start 00:00, zatrzymanie po odpowiedzi, reset przy następnym zadaniu, brak ciągłego odczytu przez czytnik ekranu.
5. Sprawdź nowy kafelek i pole odpowiedzi na telefonie i komputerze oraz poprawność kontekstu zdań wygenerowanych przez AI.
6. Porównaj słowo ćwiczone jednostronnie z ćwiczonym we wszystkich umiejętnościach; spadek procentu w pierwszym przypadku jest zamierzony.
