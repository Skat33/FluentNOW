# Raport: core-content, shard C08

## 1. Co zrobiono

Plik: `ios/FluentNOW/Resources/Content/core/core-c08.json` (nowy, format §6 CONTENT-SCHEMA). Kategorie `core-c08.c1` i `core-c08.c2`. W każdej kategorii wpisy idą w kolejności z listy roboczej. Innych plików bazy nie zmieniałem.

| | Liczba |
|---|---|
| Haseł na liście sharda | 252 (244 `new`, 8 `check`) |
| Napisane hasła `new` | 227 / 244 (17 pominiętych, zob. §3) |
| Hasła `check` z dopisanym ogólnym znaczeniem | 1 (*candid* „szczery”; w bazie było tylko „spontaniczny” z fotografii) |
| Pominięte hasła `check` (ogólne znaczenie już jest w bazie) | 7: *interruption, isolation, self-esteem, discrepancy, mitigate, rapport, feasibility* |
| **Wpisy (znaczenia)** | **241** (228 różnych `term`) |
| **Przykłady** | **729** (3 przykłady: 235 wpisów, 4: 6 wpisów) |

Rozkład CEFR: C1 66 · C2 175.
Części mowy: przymiotnik 109, rzeczownik 76, czasownik 47, przysłówek 4, czasownik frazowy 3, spójnik 1, przyimek 1.
Rozmiar pliku: ~382 KB.

Walidator: `node ios/tools/validate-content.mjs --file …/core/core-c08.json` → **OK: plików 1, wpisów 241, błędów 0, ostrzeżeń 0**. Sprawdzane są też `duplicate-example` i `duplicate-term-translation` względem C01–C07 w stanie z chwili walidacji. Nie uruchamiałem `build-index.mjs`, `build-core-master.mjs` bez `--shard` ani gita.

## 2. Decyzje redakcyjne

- **Liczba przykładów.** Shard to prawie wyłącznie słowa C1–C2, wąskie znaczeniowo. Zgodnie z instrukcją większość wpisów ma po 3 przykłady. Częstsze i bardziej potoczne hasła mają po 4, zawsze z pytaniem albo przeczeniem: *exhaustion, mindset, superstition, willpower, daunting, hunch*. Przykłady mają różne konstrukcje i różne sytuacje (praca, dom, zakupy, zdrowie, wiadomości, sport).
- **Wiele znaczeń jako osobne wpisy:**
  - *insecurity*: brak pewności siebie / niepewność bytowa,
  - *interference*: ingerencja / zakłócenia,
  - *irritation*: irytacja / podrażnienie,
  - *outlook*: perspektywy / podejście,
  - *vulnerability*: bezbronność / luka (w zabezpieczeniach),
  - *tentative*: wstępny / nieśmiały,
  - *volatile*: niestabilny / wybuchowy,
  - *discretion*: dyskrecja / uznanie (swoboda decyzji),
  - *contend*: twierdzić / zmagać się (contend with),
  - *facade*: fasada / pozory,
  - *flimsy*: lichy / naciągany,
  - *opaque*: nieprzezroczysty / nieprzejrzysty,
  - *stagnant*: stojący (woda) / w stagnacji.
- **Nawias w `translation`** tylko tam, gdzie rozdziela znaczenia: „luka (w zabezpieczeniach)”, „uznanie (swoboda decyzji)”. Wariant bez nawiasu jest zawsze w `acceptedTranslations`.
- **envisage → envision.** *Envisage* to słowo typowo brytyjskie. Napisałem wpis `core.envision` (AmE), a *envisage* dodałem do `acceptedAnswers`. W `notePl` jest uwaga BrE/AmE.
- **Znaczenie AmE zamiast BrE:** *redundant* dostało znaczenie „zbędny”. Brytyjskie „zwolniony z pracy” opisałem w `notePl` (w AmE: *laid off*).
- **Pisownia AmE:** *fulfillment, instill, meager, scrutinize, incentivize, jeopardize*.
- **`notePl`** obejmuje m.in.:
  - mylone pary: *discrete/discreet, infer/imply, elicit/illicit, sensory/sensual, solitude/loneliness*,
  - fałszywych przyjaciół: *facet* ≠ facet, *suspense* ≠ zawieszenie, *ignorance* ≠ ignorowanie,
  - konstrukcje: *albeit* + przymiotnik lub przysłówek, *conducive to*, *notwithstanding* po rzeczowniku,
  - rejestr: *commence, notwithstanding, incentivize*,
  - formy pokrewne: *constraint, jeopardy, allusion, coercion, zeal, tedious*.
- **Bez polityki:** *unrest* i *rebellion* mają przykłady neutralne (zamknięcie fabryki, bunt nastolatka, lekcja historii). *Quell* ma przykłady o obawach i plotkach, nie o tłumieniu protestów. *Appease* dotyczy klientów i dzieci.
- **Jednostki:** w polskich zdaniach jednostki metryczne (*five miles* → „osiem kilometrów”).
- **IPA:** wg konwencji Oxford US, m.in. `/ˈpærədaɪm/`, `/ˈpærəmaʊnt/` (/æ/ przed r), jawne `-ʃən`, `-bəl`, `-təl`. *candid* ma tę samą IPA co wpis tematu `photography.candid` (`/ˈkændɪd/`). Żadne inne hasło sharda nie miało wcześniej IPA w bazie.

## 3. Pominięte hasła i zmiany CEFR

**Pominięte `new`.** Te słowa są rzadkie, niszowe albo specjalistyczne. Uczący się dorosły rzadko ich potrzebuje, a nie dało się ich dobrze zilustrować trzema naturalnymi zdaniami z różnych sytuacji:

| Hasło | Uzasadnienie |
|---|---|
| *aggregate* | statystyka i ekonomia (*in aggregate*); w mowie prawie nieużywane |
| *convergence* | wąsko naukowe; napisany jest czasownik *converge* |
| *differentiation* | biologia i marketing; dużo częstszy jest czasownik *differentiate* |
| *diffusion* | fizyka i socjologia, słowo specjalistyczne |
| *equivalence* | matematyka i logika; częstszy jest przymiotnik *equivalent* |
| *incidence* | epidemiologia; ogólne znaczenie pokrywa *prevalence* (napisane) |
| *incumbent* | głównie polityka (urzędujący polityk); pominięte, żeby unikać polityki |
| *lateral* | anatomia i techniczne; *lateral thinking* to idiom raczej brytyjski |
| *motif* | wąsko: sztuka, literatura, muzyka |
| *physiological* | język medyczny i naukowy |
| *rationality* | filozofia i ekonomia; w mowie częściej *reason* lub *rational* |
| *residual* | specjalistyczne; napisany jest rzeczownik *residue* |
| *utterance* | językoznawstwo |
| *variability* | statystyka i nauki ścisłe |
| *hereby* | formuła prawnicza (*I hereby declare*) |
| *incongruous* | rzadkie, literackie |
| *sanctimonious* | rzadkie, literackie |

**Pominięte `check`.** Ogólne znaczenie jest już w tematach z tym samym tłumaczeniem:

| Hasło | Wpis w bazie |
|---|---|
| *interruption* | przerwanie, remote-work |
| *isolation* | izolacja, elderly-care |
| *self-esteem* | poczucie własnej wartości, mental-health |
| *discrepancy* | rozbieżność, finance-accounting |
| *mitigate* | ograniczyć, project-management (to samo znaczenie ogólne) |
| *rapport* | dobry kontakt, small-talk |
| *feasibility* | wykonalność, project-management |

**CEFR inny niż w liście** (szacunek listy C2 zawyżony dla słów, które są dość częste w prasie i mowie):

| Hasło | Zmiana |
|---|---|
| *phenomenal, repertoire, slab, susceptible, trajectory, hunch, solitude, scrutinize, alleviate, eloquent, impeccable* | C2 → C1 |
| *discretion* „dyskrecja” | C1 (znaczenie „uznanie” zostaje C2) |

Pozostałe hasła mają CEFR zgodny z listą.

**Części mowy:** zgodne z listą. Wyjątek: *incumbent* (przymiotnik i rzeczownik) jest pominięte w całości.

## 4. Ryzyka i wątpliwości dla QA

- **Wspólne tłumaczenia z innymi hasłami.** Kilka wpisów C08 ma tłumaczenie takie samo jak inne hasło core lub tematu. Klucz term+tłumaczenie jest inny, więc walidator tego nie zgłasza. Przy zadaniach wyboru PL→EN warto, żeby silnik nie dawał ich jako dystraktorów dla siebie nawzajem:
  - *redundant / superfluous* — zbędny, zbyteczny,
  - *ubiquitous / pervasive* — wszechobecny,
  - *appease / placate* — udobruchać, ułagodzić,
  - *meager / paltry* — skromny, marny,
  - *ardent / staunch / fervent* — zagorzały, żarliwy,
  - *candid* „szczery” vs *sincere* „szczery” (core-c05).
- **`focusPl` szersze niż samo hasło.** Gdy polski odpowiednik zmienia konstrukcję, `focusPl` obejmuje całe wyrażenie, np.:
  - *adamant about not selling* → „stanowczo nie chce sprzedać”,
  - *food insecurity* → „nie mają zapewnionego dostępu do jedzenia”,
  - *conspicuous by its absence* → „rzucał się w oczy”.
- **Unikalność przykładów** sprawdzona względem C01–C07 w chwili walidacji. C06 i C07 są pisane równolegle, więc ewentualna kolizja dopisana później pokaże się po ich stronie albo w pełnym walidatorze po fali.

## 5. Prośby do innych ról

- **Koordynator:** po fali uruchomić kolejno `build-index.mjs` → `build-core-master.mjs` → pełny `validate-content.mjs`.
  - Status *candid* zmieni się dopiero po przeliczeniu.
  - 7 pominiętych haseł `check` i 17 pominiętych `new` z §3 można oznaczyć jako zamknięte (odrzucone).
  - *envisage* jest pokryte wpisem `core.envision`, ale `build-core-master.mjs` może nadal liczyć je jako `new`.

## 6. Narzędzia robocze (poza repozytorium)

Scratchpad, katalog `…/scratchpad/c08w/`:
- `b01.txt` … `b05.txt` — treść w zwięzłym formacie,
- `conv.mjs` — konwerter z C05 z podmienionym id i ścieżkami (kontroluje 6–20 słów, kropki, pytanie lub przeczenie przy 4–5 przykładach, `translation` w `t:`, kolejność z listy roboczej),
- `look.mjs` — wyszukiwanie hasła we wszystkich tematach, shardach core i starterze (także w C04–C07, których nie ma jeszcze w `dictionary-index.json`),
- `stats.mjs` — pokrycie listy i statystyki.
