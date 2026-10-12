# Raport: topic-content, shard S1 (zakończony)

## 1. Co zrobiono

Wszystkie 12 tematów sharda S1 jest gotowych, w kolejności z `TOPICS-MASTER.md`. Pliki są w `ios/FluentNOW/Resources/Content/topics/`:

| id | wpisy | kategorie | A1 | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|---|---|---|
| greetings-introductions | 116 | 7 | 30 | 31 | 41 | 13 | 1 | 0 |
| numbers-time | 120 | 6 | 61 | 30 | 22 | 7 | 0 | 0 |
| colors-shapes-sizes | 113 | 6 | 32 | 29 | 33 | 16 | 3 | 0 |
| family | 94 | 6 | 19 | 10 | 32 | 27 | 6 | 0 |
| personality | 93 | 6 | 5 | 10 | 35 | 38 | 5 | 0 |
| appearance | 82 | 5 | 12 | 15 | 26 | 23 | 6 | 0 |
| emotions | 86 | 6 | 6 | 15 | 33 | 26 | 6 | 0 |
| daily-routine | 91 | 6 | 28 | 21 | 30 | 9 | 3 | 0 |
| weather | 89 | 6 | 12 | 12 | 33 | 21 | 11 | 0 |
| clothes-fashion | 100 | 6 | 17 | 26 | 35 | 13 | 9 | 0 |
| small-talk | 84 | 6 | 6 | 21 | 30 | 17 | 10 | 0 |
| opinions-agreeing | 94 | 6 | 6 | 18 | 41 | 16 | 13 | 0 |
| **Razem** | **1162** | 72 | | | | | | |

Każda kategoria ma `scenePl` z jedną konkretną sceną (np. „Kolejka po kawę w przerwie konferencji”, „Śnieżny zimowy poranek: odśnieżanie podjazdu”). Oba przykłady każdego wpisu dzieją się w tej scenie, w dwóch różnych momentach. Brak poziomu C2 jest celowy: słownictwo tych podstawowych tematów uczciwie nie sięga C2.

Tematy z „Pomysłów dodatkowych” nie zostały wzięte, zgodnie z poleceniem koordynatora. Plik `topic-claims/S1.md` nie powstał.

## 2. Kontrakty

Brak nowego API. Pliki są dokładnie zgodne z `CONTENT-SCHEMA.md` §1.

Zasady redakcyjne:
- Polskie tłumaczenia przykładów są naturalne, a nie dosłowne.
- Jednostki amerykańskie przeliczam w tłumaczeniu (np. „ninety-five degrees” → „trzydzieści pięć stopni”, „a foot of snow” → „trzydzieści centymetrów śniegu”). Wyjątkiem są zdania, które mówią o samej skali (Fahrenheit, inch, foot, pound).
- Godziny w przykładach PL są czasem w zapisie 24-godzinnym (np. 19:40), żeby tłumaczenie brzmiało naturalnie.

## 3. Odstępstwa od strony

- Strona generowała tematy przez Gemini. Tu cała treść jest napisana ręcznie, offline.
- `notePl` zawiera praktyczne wskazówki dla Polaków: fałszywi przyjaciele (eventually, actually, sensible, nervous, purple, miserable), różnice AmE/BrE (pants/trousers, purse, fall, closet, sneakers, trash), wymowa i typowe błędy („I am agree”, „How is the weather like”).

## 4. Ryzyka / rzeczy niesprawdzone

- Hasła z wielką literą (dni tygodnia, miesiące, „Fahrenheit”, „T-shirt”, „I think” itd.) są poprawne jako nazwy własne lub „I”. Walidator na razie ich nie zgłasza.
- Kilka haseł występuje też w innych tematach (np. hello/hi z S5, `make the bed` w `sleep`), w innej scenie. Gdy walidator zgłosił identyczne zdania przykładowe jak w `sleep.json` i `remote-work.json`, przepisałem swoje przykłady (daily-routine: make the bed, morning person, work from home).
- Celowo uniknąłem dublowania z S6 `shopping-clothes`: przymierzalnia, rozmiary, kasa i zwroty zostały tam. `clothes-fashion` obejmuje garderobę, dodatki, ubieranie się, tkaniny i pranie oraz modę.
- Temat `greetings-introductions` zawiera tylko część uprzejmości (welcome, excuse me jest w `small-talk`). Pełne „thank you / you're welcome / sorry” zostawiłem dla S5 `apologies-politeness`.

## 5. Prośby do innych ról

- **data-pipeline / walidator:** rozważyć whitelistę nazw własnych (dni, miesiące, Fahrenheit), jeśli heurystyka `term-case` zostanie przywrócona. Heurystyka „wardrobe → closet” jest za ostra, bo w AmE „wardrobe” jako „garderoba (zbiór ubrań)” jest poprawne. Hasło i tak zamieniłem na `closet`.
- **english-qa:** do przejrzenia w pierwszej kolejności idiomy C1 (rain cats and dogs, goody two-shoes, shoot the breeze) i ich polskie odpowiedniki.

## 6. Testy i wyniki skryptów

- `node ios/tools/validate-content.mjs --file <plik>` był uruchamiany po każdej kategorii. Każdy z 12 plików: 0 błędów, 0 ostrzeżeń.
- `node ios/tools/validate-content.mjs` (cała baza): `OK: plików 86, wpisów 5776, błędów 0, ostrzeżeń 0`.
- `node ios/tools/build-index.mjs`: 72 tematy, 5755 wpisów w tematach, 5776 rekordów słownika. `index.json` ma liczniki tematów S1, `dictionary-index.json` jest aktualny.
- Własny skrypt (w scratchpadzie, poza repo) dodatkowo sprawdzał: dokładne podciągi `focusEn`/`focusPl`, długość przykładów (5–22 słowa), brytyjską pisownię, duplikaty haseł i formaty pól. Wszystko jest czyste.
