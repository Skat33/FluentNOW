# Raport: topic-content, shard S11

## 1. Co zrobiono

Wszystkie 10 tematów sharda S11 z `TOPICS-MASTER.md` ukończone, zwalidowane (0 błędów) i ujęte w indeksach (`build-index.mjs`: 133 tematy, 10 080 wpisów w bazie).

| id | grupa | wpisy | kategorie | A1 | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|---|---|---|---|
| science | education | 99 | 7 | 0 | 12 | 40 | 34 | 13 | 0 |
| exams-tests | education | 74 | 6 | 0 | 11 | 36 | 17 | 10 | 0 |
| language-learning | education | 83 | 7 | 5 | 16 | 27 | 27 | 8 | 0 |
| math | education | 75 | 6 | 3 | 11 | 31 | 23 | 7 | 0 |
| countries-nationalities | basics | 88 | 6 | 28 | 27 | 20 | 11 | 2 | 0 |
| jobs-professions | work | 73 | 7 | 4 | 17 | 28 | 20 | 4 | 0 |
| materials-objects | basics | 66 | 6 | 6 | 10 | 21 | 25 | 4 | 0 |
| cycling | travel | 67 | 6 | 2 | 9 | 23 | 22 | 11 | 0 |
| cruise-ferry | travel | 64 | 6 | 1 | 8 | 13 | 26 | 16 | 0 |
| car-problems | travel | 67 | 6 | 0 | 6 | 14 | 34 | 13 | 0 |
| **razem** | | **756** | 63 | | | | | | |

Pliki: `ios/FluentNOW/Resources/Content/topics/{science,exams-tests,language-learning,math,countries-nationalities,jobs-professions,materials-objects,cycling,cruise-ferry,car-problems}.json`, a do tego wygenerowane na nowo `topics/index.json` i `dictionary-index.json`.

Metoda: zwięzłe źródło tekstowe w scratchpadzie (`S11/src/<topic>/*.txt`) zamieniane na JSON skryptem `gen.mjs` (kopia generatora z S9 z aliasami `phr`/`rare`). Każda kategoria ma `scenePl` i oba przykłady każdego wpisu dzieją się w tej scenie. Przed pisaniem każdego tematu sprawdzałem skryptem `ov.mjs` hasła, które już występują w innych tematach.

## 2. Kontrakty
Bez zmian. Format zgodny z CONTENT-SCHEMA §1.

## 3. Decyzje i odstępstwa
- **Pokrycie z innymi tematami.** Pominąłem hasła z `school`, `university`, `numbers-time`, `colors-shapes-sizes`, `driving`, `car-rental`, `job-search`, `office-work` w tym samym znaczeniu. Na przykład w `exams-tests` nie ma osobnych haseł exam/test/quiz/pass/fail/cram. Zamiast nich są `take an exam` (pułapka „zdawać” a „zdać”), `retake`, `flunk`, `ace`. W `car-problems` nie ma flat tire, break down, dead battery, tow truck, warning light ani hazard lights. Są za to `won't start`, `stall`, `jump-start`, `flashers` i inne. W `math` nie ma kształtów ani liczebników.
- **`jobs-professions`** zawiera rdzeniowe nazwy zawodów, które występują też w tematach sytuacyjnych w innym kontekście: doctor, nurse, teacher, lawyer, police officer, firefighter, waiter, chef, cashier, farmer, accountant, electrician, plumber. Bez nich temat „Zawody” byłby niekompletny. Przykłady są osadzone we własnych scenach tematu (dzień zawodów w szkole, plac budowy, hol biurowca, ulica handlowa). Peryferyjne zawody z innych tematów pominąłem (pilot, dentist, barista, tailor itp.). `mechanic` jest tylko w `car-problems`.
- **Ten sam wyraz w innym znaczeniu** zostawiłem z przykładami ze swojej sceny, np. `science.solution` (roztwór), `science.field` (dziedzina), `math.product` (iloczyn), `math.volume` (objętość), `cruise-ferry.bow` (dziób), `car-problems.radiator` (chłodnica), `cycling.coast`, `materials-objects.iron` (żelazo).
- **`countries-nationalities`**: nazwy własne wielką literą. Przymiotniki narodowości (np. Polish, German) obejmują też nazwę języka (`acceptedTranslations`: „po polsku” itd.). Narodowość jako rzeczownik jest osobnym hasłem tylko tam, gdzie ma inną formę (`Pole`).
- **Usunięty duplikat**: `exams-tests.butterflies-in-my-stomach` kolidował z przykładem w `emotions.json`, więc wpis usunąłem. Idiom jest już w `emotions`.

## 4. Ryzyka i rzeczy niesprawdzone
- Ostrzeżenia walidatora, które zostały, to fałszywe alarmy reguły BrE:
  - `science.chemist` (w AmE znaczy „chemik”; dopisałem notę),
  - `jobs-professions.real-estate-agent` (zawiera „estate agent”),
  - `cycling.get-a-flat` („a flat”),
  - `car-problems.jumper-cables` („jumper”).
- Symbole SF wybrałem tak, by istniały w iOS 17: `testtube.2`, `checklist`, `character.book.closed`, `function`, `globe.europe.africa`, `person.crop.rectangle.stack`, `cube.box`, `bicycle`, `ferry`, `wrench.and.screwdriver`. Nie sprawdzałem ich w Xcode.
- Rozkład CEFR w `cruise-ferry` i `car-problems` jest przesunięty ku B2/C1. To naturalne dla słownictwa specjalistycznego (części auta, terminologia żeglarska).

## 5. Prośby do innych ról
- english-qa: rozważyć wyjątki w walidatorze dla `chemist` (znaczenie naukowe), `jumper cables` i `real estate agent`, które dziś wywołują ostrzeżenie „british-vocab”.

## 6. Testy i wyniki
- `node ios/tools/validate-content.mjs --file <plik>` dla każdego z 10 plików: **0 błędów**, łącznie 14 ostrzeżeń, wszystkie z p. 4.
- `node ios/tools/build-index.mjs`: zapisano `topics/index.json` i `dictionary-index.json` (133 tematy, 10 080 wpisów, 10 101 rekordów słownika).
- Przeczytałem redakcyjnie losową próbkę wpisów i poprawiłem nienaturalne zdania polskie.

## Niedokończone
Brak. Wszystkie 10 tematów S11 jest gotowych. Zgodnie z poleceniem nie brałem tematów dodatkowych i nie uruchamiałem gita.
