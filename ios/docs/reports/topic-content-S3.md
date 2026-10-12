# Raport: topic-content S3

Shard S3 jest ukończony: 12 z 12 tematów, łącznie 1040 wpisów. Wszystkie pliki przechodzą `validate-content.mjs` bez błędów. Dodatkowych tematów z „Pomysłów” nie brałem (polecenie koordynatora).

## 1. Co zrobiono (pliki)

Wszystkie pliki leżą w `ios/FluentNOW/Resources/Content/topics/`:

| id | wpisów | kategorii | CEFR (A1/A2/B1/B2/C1/C2) |
|---|---|---|---|
| restaurant | 112 | 7 | 25/34/29/16/8/0 |
| cafe-bakery | 102 | 7 | 14/36/32/15/4/1 |
| cooking | 104 | 7 | 9/34/32/22/7/0 |
| grocery-shopping | 86 | 6 | 8/21/37/12/8/0 |
| fruits-vegetables | 85 | 6 | 11/22/26/17/9/0 |
| meat-fish-dairy | 88 | 6 | 9/22/30/19/8/0 |
| drinks-bar | 75 | 6 | 9/14/23/18/11/0 |
| diet-nutrition | 77 | 6 | 1/13/20/28/14/1 |
| house-rooms | 81 | 6 | 17/22/24/15/3/0 |
| furniture-household | 79 | 6 | 5/27/24/13/10/0 |
| cleaning-chores | 83 | 6 | 4/18/37/18/6/0 |
| renting-apartment | 68 | 6 | 0/12/11/28/17/0 |
| **razem** | **1040** | 75 | |

Po zakończeniu uruchomiłem `node ios/tools/build-index.mjs`. Indeks obejmuje teraz 66 tematów i 5250 wpisów w tematach.

## 2. Kontrakty

Format jest dokładnie taki jak w CONTENT-SCHEMA §1, bez zmian w schemacie. Każda kategoria ma `scenePl`, a oba przykłady każdego wpisu dzieją się w tej scenie. Gdy jedno hasło ma w temacie dwa znaczenia, drugie dostaje id z sufiksem `-2`, np.:
- `restaurant.order-2` (rzeczownik obok czasownika),
- `restaurant.tip-2`,
- `drinks-bar.drink-2` i `drinks-bar.drink-3`,
- `meat-fish-dairy`: brak duplikatów,
- `cleaning-chores.clean-2`, `vacuum-2`, `mop-2`,
- `cooking.cook-2`,
- `house-rooms.floor-2` (piętro obok podłogi),
- `renting-apartment.rent-2`,
- `grocery-shopping.bag-2`.

## 3. Odstępstwa od strony

- **Sposób tworzenia treści.** Treść pisałem w zwartym formacie źródłowym (pliki w scratchpadzie sesji). Własny skrypt budujący (`scratchpad/build-s3.mjs`) zamieniał go na JSON i walidował: sprawdzał zgodność `focusEn`/`focusPl` z treścią przykładów, pola wymagane, długości i pisownię brytyjską. Następnie uruchamiał oficjalny walidator. Do repozytorium trafiły tylko pliki JSON.
- **`acceptedAnswers` i `acceptedTranslations`.** Usunąłem warianty różniące się tylko diakrytykami (np. `entrée`/`entree`, `nie spiesz się`/`nie śpiesz się`). Walidator i tak normalizuje znaki diakrytyczne, więc te warianty byłyby zdublowane.
- **Hasła z wielką literą** to nazwy własne i skróty: `go Dutch`, `French press`, `Allen wrench`, `ID`, `TV stand`. Walidator je akceptuje.
- **Jednostki i ceny amerykańskie.** W przykładach zostawiłem uncje, funty, galony i stopnie Fahrenheita. W polskich tłumaczeniach przeliczam je tam, gdzie brzmi to naturalnie (np. 350°F → 175°C, „third floor” → „drugie piętro”). Wyjaśnienia są w `notePl`.

## 4. Znane ryzyka i rzeczy niesprawdzone

- **Fałszywy alarm walidatora: `cooking.mince`.** Walidator ostrzega 3 razy przed brytyjskim „mince”. W znaczeniu czasownika „drobno posiekać” (minced garlic) to jednak standardowy amerykański angielski. `notePl` wyjaśnia, że rzeczownik „mince” jest brytyjski. Proponuję, żeby walidator ostrzegał tylko o rzeczowniku.
- **Ikony SF Symbols nie są sprawdzone na Macu:** `fork.knife`, `cup.and.saucer`, `frying.pan`, `cart`, `carrot`, `fish`, `wineglass`, `leaf`, `house`, `sofa`, `sparkles`, `key`. Wszystkie powinny istnieć w SF Symbols 5 (iOS 17). Najmniej pewny jestem `frying.pan` — jeśli się nie wyświetli, wystarczy `flame`.
- **Częściowe nakładanie się z innymi tematami.** Niektóre pojęcia pojawiają się w kilku tematach, ale za każdym razem w innej scenie (zgodnie z zasadą w TOPICS-MASTER):
  - `fridge` (meat-fish-dairy) i lodówka w furniture-household — w drugim temacie celowo pominąłem lodówkę jako osobne hasło,
  - `receipt` (restaurant i grocery-shopping),
  - `ingredient` (restaurant i cooking).
- **Wyrównanie poziomu CEFR.** `renting-apartment` i `diet-nutrition` mają niewiele haseł na poziomie A1. Wynika to z natury dziedziny (słownictwo umów i żywienia); poziomów nie wyrównywałem sztucznie.

## 5. Prośby do innych ról

- **data-pipeline (`validate-content.mjs`):** reguła `british-vocab` dla „mince” powinna rozróżniać czasownik od rzeczownika. Reguła dla „wardrobe” może zostać — w furniture-household zastąpiłem to hasło przez `armoire`.
- **english-qa:** proszę o przegląd par znaczeniowych zbliżonych do siebie: `waiter`/`server`, `main course`/`entrée`, `deal`/`overpriced`, `essentials`/`staple`, `landlord`/`owner`.

## 6. Testy i wynik skryptów

- `node ios/tools/validate-content.mjs --file …` dla 12 plików S3 daje `OK: plików 12, wpisów 1040, błędów 0, ostrzeżeń 3`. Wszystkie 3 ostrzeżenia to opisany wyżej fałszywy alarm dla `mince`.
- `node ios/tools/validate-content.mjs --errors-only` dla całej bazy daje `OK: plików 80, wpisów 5271, błędów 0`.
- `node ios/tools/build-index.mjs` zapisał `topics/index.json` i `dictionary-index.json` (66 tematów, 5271 rekordów słownika).
- Redakcyjny przegląd wpisów robiłem na bieżąco przy pisaniu każdej kategorii. Poprawiałem naturalność zdań, odmianę w `focusPl` i pisownię amerykańską.
