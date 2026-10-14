# Raport: topic-content, shard S10

Status: **shard ukończony**. Gotowe są wszystkie 12 tematów, razem 767 wpisów. Walidator nie zgłasza żadnych błędów ani ostrzeżeń dla żadnego z 12 plików. Pełny przebieg `validate-content.mjs --errors-only` na całej bazie: 150 plików, 10 291 wpisów, 0 błędów. Po zakończeniu uruchomiono `node ios/tools/build-index.mjs`: 136 tematów, 10 270 wpisów w tematach, 10 291 rekordów słownika.

## 1. Co zrobiono (pliki)

Wszystkie pliki są w `ios/FluentNOW/Resources/Content/topics/`:

| id | wpisów | kategorii | A1 | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|---|---|---|
| environment-climate | 71 | 5 | 0 | 9 | 26 | 26 | 10 | 0 |
| nature-landscape | 67 | 5 | 3 | 15 | 17 | 24 | 8 | 0 |
| natural-disasters | 63 | 5 | 0 | 6 | 17 | 27 | 13 | 0 |
| space-astronomy | 63 | 5 | 3 | 7 | 16 | 25 | 12 | 0 |
| farming-countryside | 62 | 5 | 1 | 6 | 19 | 25 | 10 | 1 |
| news-media | 63 | 5 | 2 | 6 | 18 | 25 | 12 | 0 |
| politics-elections | 63 | 5 | 0 | 7 | 16 | 28 | 12 | 0 |
| economy | 62 | 5 | 0 | 2 | 10 | 31 | 19 | 0 |
| history | 64 | 5 | 2 | 4 | 16 | 33 | 9 | 0 |
| city-life | 61 | 5 | 1 | 6 | 10 | 28 | 16 | 0 |
| volunteering-charity | 61 | 5 | 0 | 2 | 23 | 27 | 9 | 0 |
| religion-beliefs | 67 | 6 | 1 | 6 | 14 | 28 | 17 | 1 |
| **razem** | **767** | **61** | 13 | 76 | 202 | 327 | 147 | 2 |

Pliki generowane przez skrypt data-pipeline (nie edytowane ręcznie): `topics/index.json` i `dictionary-index.json`.

Brak tematów dodatkowych (zgodnie z poleceniem), więc nie powstał plik `docs/topic-claims/S10.md`.

## 2. Kontrakty

Bez zmian. Pliki są dokładnie w formacie `CONTENT-SCHEMA.md` §1.
- Symbole SF: `leaf.arrow.triangle.circlepath`, `mountain.2`, `tornado`, `moon.stars`, `tree`, `newspaper`, `checkmark.seal`, `chart.line.uptrend.xyaxis`, `building.columns`, `building.2`, `hands.sparkles`, `sparkles`. `mountain.2` i `hands.sparkles` pochodzą z SF Symbols 3/4 (iOS 15/16+), więc działają na iOS 17.
- Wielkie litery w hasłach są celowe, bo to nazwy własne lub skróty: Earth, Mars, the Milky Way, the Big Bang, Congress, Election Day, GDP, BC, AD, the Middle Ages, the Renaissance, the Stone Age, the Industrial Revolution, Earth Day, God, the Bible, the Quran, the Torah, Ramadan, Hanukkah, Diwali. Kilka haseł zawiera „the” (the sun, the moon, the past, the press, the news), bo tak się ich używa. Wariant bez „the” jest w `acceptedAnswers`.

## 3. Odstępstwa od strony

- Treść jest pisana ręcznie zamiast generowania przez Gemini. Każda kategoria ma konkretną scenę (`scenePl`), a oba przykłady dzieją się w tej scenie, w dwóch różnych momentach.
- Tematy drażliwe są pisane neutralnie:
  - **politics-elections**: bez partii i polityków z nazwy, bez ocen. Słowa liberal/conservative są opisane rzeczowo w scenie rodzinnego obiadu.
  - **religion-beliefs**: kilka religii jest traktowanych równorzędnie. Hasła atheist i agnostic są obok haseł religijnych. Ostatnie kategorie dotyczą szacunku (kosher, halal, accommodate, quiet room) i neutralnych zwrotów (thank God, a blessing in disguise).
  - **history**: wojny i podboje są opisane bez szczegółów przemocy.
- Usunięte wulgarne lub dosadne polskie odpowiedniki: „in the sticks” = „na końcu świata”, „till the cows come home” = „w nieskończoność”.
- Unikałem wpisów z tym samym znaczeniem, które już są w innych tematach. Każde hasło sprawdzałem własnym skryptem `overlap.mjs` (porównanie z hasłami we wszystkich plikach) i wymieniałem dublety tego samego znaczenia. Przykłady: off the grid i conserve (są w utilities-bills), hibernate i migrate (animals), in the middle of nowhere (camping-hiking), stock up (grocery-shopping), common ground (negotiations), around the corner (directions). Zostały hasła wspólne z innymi tematami, ale w innym znaczeniu (rock, stream, branch, trunk, crash, bill, pass, term, cover, coverage, landslide) oraz kilka haseł rdzenia tematu, które są też w science (climate change, planet, gravity, telescope) albo w personal-finance (inflation). Wszystkie mają inną scenę i inne przykłady.

## 4. Znane ryzyka i rzeczy niesprawdzone

- IPA jest pisana ręcznie (General American). Nie sprawdzałem jej w słowniku zewnętrznym, więc warto, żeby english-qa sprawdził ją wyrywkowo: epicenter, magnitude, archaeologist, reincarnation, Hanukkah, the Quran, bodega, gentrification.
- CEFR i `frequency` to moja ocena redakcyjna. Najmniej pewne są hasła z poziomów C1/C2 i potoczne: batten down the hatches, go to seed (C2), holier-than-thou (C2), spoiled for choice, in the sticks, hayride.
- **Ryzyko związane z równoległą pracą**: neighbors-community (S12) powstał w trakcie mojej pracy. Wspólne hasła: volunteer (u nich czasownik „zgłosić się na ochotnika”, u mnie rzeczownik „wolontariusz”) i streetlight. Celowo pominąłem z volunteering-charity hasła, które S12 już miał: fundraiser, bake sale, lend a hand, get involved, community center. Podobnie science (S11) ma climate change, planet, gravity, telescope, ecosystem i fossil.
- Kilka polskich tłumaczeń ma charakter opisowy, bo nie ma jednowyrazowego odpowiednika: off the record = „nieoficjalnie”, swing state = „stan wahający się”, outreach = „działania pomocowe w terenie”, food insecurity = „brak bezpieczeństwa żywnościowego”.
- Treść źródłowa (format kompaktowy plus skrypty `gen.mjs`, `rep.mjs` i `overlap.mjs`) leży tylko w scratchpadzie sesji (`scratchpad/S10/`). Źródłem prawdy są pliki JSON w repo.

## 5. Prośby do innych ról

- **english-qa**: wyrywkowa kontrola IPA i CEFR (patrz punkt 4). Dodatkowo warto przejrzeć tłumaczenia idiomów w history, farming-countryside i religion-beliefs.
- **data-pipeline**: wewnętrzny filtr brytyjskiej pisowni w moim generatorze traktuje „holiday” i „mummy” jako formy brytyjskie. Walidator repo słusznie przepuszcza „holiday”, ale zgłosił „mummy” (w znaczeniu: egipska mumia) jako BrE. Przeredagowałem to zdanie. Warto rozważyć wyjątek w regule `mummy → mommy`.
- **Koordynator / S12**: przy neighbors-community, emergencies-safety i describing-places proszę o sprawdzenie, czy nie powtarzają się hasła z city-life (nightlife, walkable, hustle and bustle, concrete jungle) i natural-disasters (evacuate, emergency kit, take shelter, first responders).

## 6. Testy i wynik skryptów

- `node ios/tools/validate-content.mjs --file <plik>` dla każdego z 12 plików: `OK`, 0 błędów, 0 ostrzeżeń.
- `node ios/tools/validate-content.mjs --errors-only` (cała baza): `OK: plików 150, wpisów 10291, błędów 0`.
- `node ios/tools/build-index.mjs`: `tematów: 136, wpisów w tematach: 10270, rekordów słownika: 10291`.
- Generator sprawdzał dodatkowo: dokładnie dwa przykłady na wpis, jeden znacznik fokusu w każdym zdaniu, liczbę słów w zdaniu EN (6–20), formy brytyjskie, długość definicji i `contextPl`, unikalność id i przykładów w temacie. Plik nie był zapisywany, jeśli wystąpił jakikolwiek błąd.
