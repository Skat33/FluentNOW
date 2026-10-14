# Raport: topic-content, shard S12

Status: **shard ukończony**: 12 z 12 tematów, 865 wpisów, 73 kategorie. Walidator nie zgłasza błędów ani ostrzeżeń dla żadnego pliku S12, zarówno sprawdzanych osobno, jak i wszystkich 12 razem. Pełny przebieg `validate-content.mjs` na całej bazie: 156 plików, 10711 wpisów, 0 błędów, 0 ostrzeżeń (po przebudowie indeksu). `build-index.mjs`: 142 tematy, 10690 wpisów w tematach, 10711 rekordów słownika. Indeks objął też pliki S10 i S11, które były na dysku w chwili uruchomienia.

Pracę wznowiono po resecie limitu (koordynator). Przed kontynuacją sprawdziłem 6 gotowych już tematów, wszystkie przeszły walidację. Format plików tematów się nie zmienił, mimo że zmieniono sposób wyszukiwania tematów.

## 1. Co zrobiono (pliki)

Wszystkie pliki leżą w `ios/FluentNOW/Resources/Content/topics/`:

| id | wpisów | kategorii | A1 | A2 | B1 | B2 | C1 | C2 | symbol |
|---|---|---|---|---|---|---|---|---|---|
| fast-food-takeaway | 77 | 7 | 6 | 22 | 31 | 18 | 0 | 0 | takeoutbag.and.cup.and.straw |
| board-games-puzzles | 90 | 7 | 1 | 21 | 38 | 23 | 7 | 0 | dice |
| neighbors-community | 71 | 6 | 1 | 8 | 24 | 25 | 12 | 1 | person.3 |
| elderly-care | 77 | 6 | 0 | 2 | 22 | 31 | 22 | 0 | heart.circle |
| babies | 68 | 6 | 1 | 4 | 24 | 25 | 14 | 0 | face.smiling |
| shopping-mall | 62 | 6 | 1 | 12 | 20 | 17 | 12 | 0 | bag |
| emergencies-safety | 72 | 6 | 1 | 13 | 20 | 25 | 13 | 0 | exclamationmark.triangle |
| describing-places | 73 | 6 | 0 | 8 | 16 | 31 | 17 | 1 | map |
| feelings-reactions-phrases | 70 | 6 | 3 | 20 | 30 | 16 | 1 | 0 | exclamationmark.bubble |
| work-idioms | 74 | 6 | 0 | 1 | 5 | 33 | 34 | 1 | quote.bubble |
| everyday-phrasal-verbs | 62 | 5 | 1 | 17 | 29 | 15 | 0 | 0 | text.bubble |
| slang-informal | 69 | 6 | 0 | 8 | 17 | 32 | 12 | 0 | bubble.left |
| **razem** | **865** | **73** | 15 | 136 | 276 | 291 | 144 | 3 | |

Pliki generowane `topics/index.json` i `dictionary-index.json` przebudowałem skryptem `build-index.mjs`, nie edytowałem ich ręcznie. Tematów z „Pomysłów dodatkowych” nie brałem (zgodnie z poleceniem), więc plik `docs/topic-claims/S12.md` nie powstał. Gita nie uruchamiałem.

## 2. Kontrakty

Schemat się nie zmienił. Pliki trzymają się dokładnie formatu `CONTENT-SCHEMA.md` §1. Kilka konwencji:
- Każda kategoria ma konkretną scenę (`scenePl`). Oba przykłady wpisu dzieją się w tej scenie, w różnych momentach. Przykładowe sceny: „nocny alarm pożarowy w bloku”, „wizyta kontrolna u pediatry”, „narzekanie w akademiku na nudną imprezę”, „szukanie zaginionej paczki”.
- W tematach przekrojowych (frazale, idiomy, slang, reakcje) przykłady są osadzone w codziennych scenach, a nie podane jako luźne zdania.
- `focusEn` i `focusPl` są zawsze jednym ciągłym fragmentem zdania. Przy rozdzielnych phrasal verbs fokus obejmuje całość, np. `put the milk back`, `think it over`, `tell them apart`. Przy konstrukcji `not as ... as` fokus to `not as crowded as`.
- Hasła z wielkimi literami są celowe (skróty i nazwy własne): `911`, `ETA`, `EMT`, `AED`, `NICU`, `C-section`, `BOGO`, `Santa`, `Alzheimer's`, `Social Security`, `Medicare`, `Medicaid`, `Meals on Wheels`, `Heimlich maneuver`, `good Samaritan`, `GOAT`, `BFF`, `TMI`, `BRB`, `LOL`, `I see`, `I know, right`, `I had no idea`, `I'm so happy for you`, `I feel for you`, `I doubt it`.
- Symbole SF pochodzą z SF Symbols 1–2 (iOS 13–14), więc działają na iOS 17.

## 3. Odstępstwa od strony

- Treść napisałem ręcznie, zamiast generować ją przez Gemini (TOPIC_PROMPT i TOPIC_HYDRATE_PROMPT).
- Przed pisaniem sprawdziłem skryptem, które hasła już istnieją w bazie. Wybierałem przede wszystkim hasła nowe. Powtórzone hasło występuje wyłącznie w innym znaczeniu albo w scenie mojego tematu. Przykłady innych znaczeń: `fire` jako pożar i jako slangowy „sztos”, `speaker` jako głośnik w drive-thru, `board`, `roll`, `deal`, `hand`, `suit` i `check` w znaczeniach z gier, `bucket` jako kubełek kurczaka, `dead` jako wymarły lokal, `wing` jako skrzydło galerii, `page` jako wywołanie przez głośniki, `sleepy` jako senna okolica, `greasy` w znaczeniu tłusty. Hasła, które istniały już w tym samym znaczeniu (np. `hold`, `total`, `calories`, `I owe you one`, `nest egg`, `heads-up`, `jump ship`), pominąłem.
- Treść jest świadomie amerykańska: 911, drive-thru, BOGO, doorbuster, strip mall, HOA, cul-de-sac, trash day, Social Security, Medicare/Medicaid, well-baby visit, NICU, pounds/ounces. W `notePl` są odpowiedniki polskie i różnice AmE/BrE: takeaway, draughts, homely/homey, upmarket, jeweller's, queue, touch wood, oświadczenie pro futuro, bilans zdrowia dziecka, ZUS.
- `slang-informal` zawiera wyłącznie powszechny, niewulgarny slang (rejestr `potoczny`/`slangowy`), bez obraźliwych określeń. W `notePl` ostrzegam przed słowami dwuznacznymi: `shut up`, `lit`, `dope`, `hook up`.

## 4. Znane ryzyka i rzeczy niesprawdzone

- IPA pisałem ręcznie (General American). Nikt jej nie porównał ze słownikiem zewnętrznym. Długie zwroty i idiomy mają celowo pustą IPA (`""`).
- CEFR i `frequency` to moja ocena redakcyjna. Temat `work-idioms` ma z natury dużo B2–C1. Najmniej pewne oceny: `pungent` (C2), `prowler` (C2), `golden handshake` (C2), `bet`, `no cap`, `slay`, `rando` (C1, slang młodzieżowy szybko się starzeje).
- Slang internetowy (`touch grass`, `rent-free`, `no cap`, `bet`, `slay`, `GOAT`, `fire`) jest aktualny na 2026 rok, ale może się szybko zestarzeć. Warto go przejrzeć przy kolejnych aktualizacjach.
- Shardy S10 i S11 pracowały równolegle. Hasła sprawdzałem tylko w plikach, które w danej chwili były na dysku. Walidator potwierdza, że id i zdania przykładowe są unikalne w całej bazie, ale to samo hasło może występować w innym temacie. W tym samym znaczeniu dotyczy to np. `colorful` (colors-shapes-sizes) i `dressing room` (synonim `fitting room` z shopping-clothes). TOPICS-MASTER dopuszcza takie powtórzenia, jeśli zdania są osadzone w innej scenie.
- Treść źródłowa (format kompaktowy), generator i skrypty pomocnicze (`S12/gen.mjs`, `terms.mjs`, `fix.mjs`) leżą tylko w scratchpadzie sesji. Źródłem prawdy są pliki JSON w repo.

## 5. Prośby do innych ról

- **english-qa**: proszę o wyrywkową kontrolę IPA i CEFR, zwłaszcza w `slang-informal`, `work-idioms` i `elderly-care`. Warto też sprawdzić polskie odpowiedniki potoczne, np. „sztos”, „zarąbisty”, „wymiatać”, „sypnąć plotkami”, „wyjdź do ludzi” (touch grass), „szczyt w porze lunchu”, „opieka wytchnieniowa”, „oświadczenie pro futuro”.
- **data-pipeline**: `build-index.mjs` trzeba uruchomić ponownie, gdy S10 i S11 skończą swoje pliki.
- **ui-library**: brak próśb.

## 6. Testy i wynik skryptów

- `node ios/tools/validate-content.mjs --file <plik>` dla każdego z 12 plików oraz dla wszystkich 12 naraz: `OK: plików 12, wpisów 865, błędów 0, ostrzeżeń 0`.
- `node ios/tools/validate-content.mjs` na całej bazie po przebudowie indeksu: `OK: plików 156, wpisów 10711, błędów 0, ostrzeżeń 0`.
- `node ios/tools/build-index.mjs`: `tematów: 142, wpisów w tematach: 10690, rekordów słownika: 10711`.
- Generator S12 dodatkowo sprawdzał:
  - dokładnie jeden znacznik fokusu w zdaniu EN i PL;
  - dokładnie dwa przykłady na wpis;
  - poprawne wartości enumów;
  - długość `definition` i `contextPl`;
  - liczbę 1–8 `acceptedTranslations`;
  - unikalność id i zdań w temacie;
  - przesunięte kolumny (polskie znaki w polach angielskich, kropka na końcu pola wariantów).
- Osobny skan potwierdził, że w każdym przykładzie fokus EN i PL występuje dokładnie raz (bez dwuznacznego podświetlenia) i że każde zdanie EN ma 6–20 słów.
