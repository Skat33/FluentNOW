# Raport: topic-content, shard S8

Status: **shard ukończony**. Gotowe są wszystkie 12 tematów (863 wpisy). Walidator na całej bazie: 120 plików, 0 błędów, 0 ostrzeżeń. Moje pliki też mają 0 ostrzeżeń. Na koniec uruchomiłem `node ios/tools/build-index.mjs`, a `--check` zwraca 0: 106 tematów, 8160 wpisów w tematach, 8181 rekordów słownika.

## 1. Co zrobiono (pliki)

Wszystkie pliki leżą w `ios/FluentNOW/Resources/Content/topics/`:

| id | wpisów | kat. | A1 | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|---|---|---|
| friendship | 71 | 6 | 3 | 14 | 22 | 21 | 11 | 0 |
| dating-relationships | 69 | 5 | 4 | 11 | 25 | 23 | 6 | 0 |
| wedding | 70 | 5 | 1 | 10 | 24 | 28 | 7 | 0 |
| parenting | 70 | 5 | 0 | 15 | 17 | 30 | 8 | 0 |
| arguments-conflict | 68 | 5 | 0 | 6 | 13 | 25 | 23 | 1 |
| giving-advice | 67 | 5 | 6 | 14 | 23 | 16 | 8 | 0 |
| storytelling | 69 | 5 | 7 | 16 | 24 | 19 | 3 | 0 |
| beauty-hairdresser | 78 | 6 | 1 | 16 | 25 | 27 | 9 | 0 |
| repairs-diy | 84 | 6 | 1 | 11 | 24 | 35 | 13 | 0 |
| utilities-bills | 72 | 6 | 1 | 17 | 15 | 24 | 15 | 0 |
| moving-house | 64 | 5 | 3 | 9 | 22 | 19 | 11 | 0 |
| garden-plants | 81 | 6 | 5 | 10 | 24 | 23 | 19 | 0 |
| **razem** | **863** | **65** | 32 | 149 | 258 | 290 | 133 | 1 |

Pliki generowane `topics/index.json` i `dictionary-index.json` zostały tylko przebudowane skryptem data-pipeline, nie edytowałem ich ręcznie. Nie brałem tematów z „Pomysłów dodatkowych”, zgodnie z poleceniem, więc plik `docs/topic-claims/S8.md` nie powstał.

## 2. Kontrakty

Schemat się nie zmienił. Pliki są dokładnie w formacie `CONTENT-SCHEMA.md` §1. Konwencje, które warto znać:
- Drugie znaczenie hasła w tym samym temacie dostaje sufiks `-2`. Przykłady: `friendship.get-together` (czasownik frazowy) i `friendship.get-together-2` („get-together”, rzeczownik); `garden-plants.rake` (czasownik) i `rake-2` (narzędzie).
- `focusEn` bywa formą odmienioną albo rozwiniętą, np. `asked me out`, `put myself out there`, `stood me up`. Zawsze jest dokładnym podciągiem zdania.
- Wielkie litery w hasłach są celowe, to skróty lub nazwy: `RSVP`, `DIY`, `DMV`, `LED bulb`, `I do`, `I'll think about it`, `Mr. Fix-It`.
- Symbole SF (wszystkie z SF Symbols ≤ 4, czyli dostępne od iOS 16): `person.2.wave.2`, `heart`, `heart.circle`, `figure.and.child.holdinghands`, `bubble.left.and.exclamationmark.bubble.right`, `lightbulb`, `text.bubble`, `scissors`, `hammer`, `bolt`, `shippingbox`, `camera.macro` (ikona tulipana, bo `leaf` zajmuje już diet-nutrition).

## 3. Odstępstwa od strony

- Treść napisałem ręcznie, zamiast generować ją przez Gemini (TOPIC_PROMPT + TOPIC_HYDRATE_PROMPT). Każda kategoria ma konkretną scenę (`scenePl`), a oba przykłady dzieją się w tej scenie, w dwóch różnych momentach.
- Realia są świadomie amerykańskie: bridal shower, registry, marriage license, daycare, DMV, budget billing, drywall, stud finder, trash pickup. Różnice AmE/BrE i pułapki opisuje `notePl`, np. diaper/nappy, stroller/pushchair, wrench/spanner, „eventually” ≠ „ewentualnie”, „advice” niepoliczalne, suit vs fit.
- Unikałem dublowania gotowych tematów z S1–S6. Pominąłem hasła, które już tam są: haircut, bangs, dyed (appearance); argue, blame, yell, calm down (family/emotions/coworkers); compromise, agree to disagree (opinions-agreeing); move in/out, forwarding address, handyman, leak, clogged, utilities (renting-apartment, complaints-problems); screwdriver, screw, Allen wrench (furniture-household); declutter, get rid of (cleaning-chores); bubble wrap, fragile (post-office). Ogólne słowa, które pojawiają się też w innych tematach (plant, water, shovel, trim, contract, cancel, meter), mają przykłady osadzone wyłącznie w scenach S8.

## 4. Znane ryzyka i rzeczy niesprawdzone

- IPA pisałem ręcznie (GA). Nie sprawdzałem jej ze słownikiem zewnętrznym, walidator nie zgłosił uwag. Warto wyrywkowo sprawdzić: `balayage`, `esthetician`, `officiant`, `kilowatt-hour`, `succulent`, `aphid`.
- CEFR i `frequency` to ocena redakcyjna. Najmniej pewne są idiomy i słownictwo potoczne/specjalistyczne: `extend an olive branch` (C2), `ride or die`, `frenemy`, `cowlick`, `trip a breaker`, `budget billing`, `root rot`.
- Tłumaczenia idiomów są ekwiwalentami, nie kalkami. Przykłady: `the grass is always greener` = „wszędzie dobrze, gdzie nas nie ma”, `bad blood` = „zła krew / zadawnione urazy”, `on the fritz` = „nawala”. Przy kilku zwrotach `translation` jest w formie użycia, np. `you should` = „powinieneś”, `how dare you` = „jak śmiesz”.
- Przy zaimkach płci w tłumaczeniach, np. „przyjaciółka/przyjaciel”, różne formy są w `acceptedTranslations`. Same przykłady używają różnych płci.
- Treść źródłowa (format kompaktowy + generator `gen2.mjs`) jest tylko w scratchpadzie sesji. Źródłem prawdy są pliki JSON w repo.

## 5. Prośby do innych ról

- **english-qa**: proszę o wyrywkową kontrolę IPA i CEFR (pkt 4), zwłaszcza w arguments-conflict (najwięcej C1) i garden-plants.
- **data-pipeline**: brak. Walidator i build-index działały bez problemów. Drobna uwaga: przy sprawdzaniu BrE walidator zgłosił „The underground” w definicji jako słownictwo brytyjskie. To trafny fałszywy alarm, definicję przeredagowałem.
- **ui-library**: brak.

## 6. Testy i wynik skryptów

- `node ios/tools/validate-content.mjs --file <plik>` dla każdego z 12 plików: `OK`, 0 błędów, 0 ostrzeżeń.
- `node ios/tools/validate-content.mjs --errors-only` na całej bazie (razem z plikami S7/S9 w toku): `OK: plików 120, wpisów 8181, błędów 0`. Unikalność przykładów w całej bazie jest zachowana.
- `node ios/tools/build-index.mjs` i `--check`: `tematów: 106, wpisów w tematach: 8160, rekordów słownika: 8181`, indeksy aktualne.
- Przegląd redakcyjny: przeczytałem losową próbkę 36 wpisów (po 3 z każdego tematu). Poprawiłem tłumaczenia hasłowe `spill`, `green thumb`, `late bloomer` i `babe`, a także „wardrobe” (BrE) w przykładzie storytelling i błąd „z ściany” → „ze ściany”.
