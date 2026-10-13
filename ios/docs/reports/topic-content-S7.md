# Raport: topic-content, shard S7

## 1. Co zrobiono

Ukończone wszystkie 12 tematów sharda S7 z `TOPICS-MASTER.md`. Razem 935 wpisów, każdy temat ma 6 kategorii. Tematów dodatkowych nie brano (zgodnie z zakresem zadania).

Pliki (`ios/FluentNOW/Resources/Content/topics/`):

| id | namePl | grupa | kategorie | wpisy | A1 / A2 / B1 / B2 / C1 / C2 |
|---|---|---|---|---|---|
| movies-tv | Filmy i seriale | leisure | 6 | 99 | 11 / 23 / 33 / 29 / 3 / 0 |
| music | Muzyka | leisure | 6 | 93 | 13 / 21 / 31 / 22 / 6 / 0 |
| books-reading | Książki i czytanie | leisure | 6 | 84 | 7 / 18 / 28 / 21 / 10 / 0 |
| art-museum | Sztuka i muzea | leisure | 6 | 79 | 7 / 16 / 29 / 21 / 6 / 0 |
| hobbies-crafts | Hobby i rękodzieło | leisure | 6 | 78 | 2 / 25 / 25 / 20 / 6 / 0 |
| photography | Fotografia | leisure | 6 | 73 | 6 / 16 / 26 / 14 / 10 / 1 |
| video-games | Gry wideo | leisure | 6 | 72 | 3 / 14 / 26 / 25 / 4 / 0 |
| football | Piłka nożna | leisure | 6 | 78 | 9 / 16 / 23 / 29 / 1 / 0 |
| concerts-festivals | Koncerty i festiwale | leisure | 6 | 68 | 3 / 13 / 23 / 22 / 7 / 0 |
| theater | Teatr | leisure | 6 | 69 | 1 / 7 / 22 / 27 / 11 / 1 |
| parties-celebrations | Imprezy i uroczystości | people | 6 | 72 | 8 / 22 / 18 / 21 / 3 / 0 |
| holidays-traditions | Święta i tradycje | daily | 6 | 70 | 6 / 24 / 20 / 16 / 4 / 0 |

Zregenerowano też `topics/index.json` i `dictionary-index.json` (`build-index.mjs`: 110 tematów, 8472 wpisy w tematach, 8493 rekordy słownika).

Metoda: każda kategoria powstała najpierw w zwięzłym formacie tekstowym w scratchpadzie (`scratchpad/S7/src/<topic>/NN.txt`). Do JSON konwertował go skrypt `scratchpad/S7/gen.mjs`, skopiowany z S6. Pliki JSON w repo są źródłem prawdy.

## 2. Kontrakty

Bez zmian. Pliki są dokładnie w formacie `CONTENT-SCHEMA.md` §1. Symbole SF: `film`, `music.note`, `book`, `paintpalette`, `scissors`, `camera`, `gamecontroller`, `soccerball`, `music.mic`, `theatermasks`, `party.popper`, `gift`. `soccerball` i `party.popper` wymagają SF Symbols 4/5, czyli iOS 16/17, więc działają przy minimum iOS 17.

## 3. Decyzje redakcyjne i odstępstwa

- **football**: id tematu zostało jak w TOPICS-MASTER, ale `nameEn` to „Soccer”. Hasło główne to `soccer`, a `notePl` wyjaśnia, że w USA „football” to futbol amerykański. Cała terminologia jest amerykańska: field, cleats, tie, overtime, practice, stoppage time. Formy brytyjskie podano tylko w notach.
- **holidays-traditions**: „holiday” występuje w amerykańskim znaczeniu „święto” oraz „the holidays” = okres świąteczny. Unikałem połączeń typu „Christmas holidays” czy „on holiday”, które walidator słusznie oznacza jako BrE. Dodane są realia polskie (Wigilia, pasterka, opłatek, święconka, Wszystkich Świętych) i amerykańskie (Thanksgiving, Fourth of July, Halloween, potluck, Secret Santa).
- Hasła z nazwami własnymi (Christmas, Easter, Thanksgiving…) i skrótowce (TV show, PC, DJ, VIP, RSVP, BYOB, GG, R&B, DIY) mają wielkie litery. Walidator ich nie zgłasza.
- Niektóre podstawowe hasła powtarzają się między tematami (np. actor, stage, playlist, celebrate) w znaczeniu właściwym dla danej sceny. Mają różne id i przykłady.
- W `concerts-festivals` zamiast polskiego „toi toi” (nazwa marki) użyto tłumaczenia „przenośna toaleta”.

## 4. Znane ryzyka / niesprawdzone

- 5 tematów ma 68–73 wpisy, czyli dolną część zakresu 60–120: concerts-festivals, theater, holidays-traditions, video-games, parties-celebrations. Rdzeń każdego tematu jest pokryty.
- W football i video-games jest niewiele haseł C1–C2. Słownictwo tych domen jest w większości proste i nie zawyżałem poziomów.
- Tematy innych shardów zachodzą częściowo na moje: `repairs-diy` (część DIY w hobbies-crafts), `wedding` (część okazji w parties-celebrations), `garden-plants`. Walidator sprawdzał unikalność przykładów w całej bazie w chwili mojej walidacji. Jeśli inne shardy dopiszą później identyczne zdania, kolizję zgłosi ich walidacja.
- Ostrzeżenia „possible British form” z mojego skryptu `gen.mjs` (np. „holiday”, „realistic”) to fałszywe alarmy jego szerokiego regexu. Właściwy walidator ich nie zgłasza.

## 5. Prośby do innych ról

Brak.

## 6. Testy i wyniki

- Każdy temat przechodzi `node ios/tools/validate-content.mjs --file <plik>` z wynikiem „błędów 0, ostrzeżeń 0”. Po ukończeniu wszystkich 12 tematów walidacja została powtórzona.
- Kolizje przykładów z innymi tematami wykryte w trakcie (`small-talk.hobby`, `wedding.dance-floor`) zostały przepisane.
- Przegląd redakcyjny objął losowe wpisy z każdego tematu oraz wszystkie przykłady w trakcie pisania. Poprawione zostały nienaturalne polskie zdania, podwójne fokusy, zdania kończące się cudzysłowem i jedno błędne tłumaczenie (bookish).
- `node ios/tools/build-index.mjs` zakończył się sukcesem.
