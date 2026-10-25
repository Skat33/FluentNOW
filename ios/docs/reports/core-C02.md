# Raport: core-content, shard C02

## 1. Co zrobiono

- Plik: `ios/FluentNOW/Resources/Content/core/core-c02.json` (id `core-c02`, ~790 KB).
- **525 wpisów, 447 haseł, 1937 przykładów** (164 wpisy po 3 przykłady, 360 po 4, 1 po 5).
- Walidator: `node ios/tools/validate-content.mjs --file …/core-c02.json` → **0 błędów, 0 ostrzeżeń**.
- Źródła robocze (format zwięzły + konwerter) w scratchpadzie sesji: `b01.txt`…`b21.txt`, `build.mjs` (konwerter → JSON, układ jak w core-c01: przykład w jednej linii), `look.mjs` (podgląd istniejących wpisów bazy z IPA). Nie trafiają do repozytorium.
- `build-index.mjs` i `build-core-master.mjs` (bez `--shard`) **nie były uruchamiane** — zostawiam koordynatorowi. Gita nie używałem.

### Rozkład CEFR (wpisy)

| A1 | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|
| 30 | 87 | 195 | 204 | 9 | 0 |

Części mowy: rzeczownik 226, czasownik 149, przymiotnik 98, przysłówek 41, przyimek 6, spójnik 2, zaimek 2, zwrot 1.

## 2. Pokrycie listy roboczej (842 hasła)

| Status | Hasła | Napisane | Pominięte |
|---|---|---|---|
| `new` | 292 | 292 | 0 |
| `partial` | 63 | 61 | 2 |
| `check` | 487 | 93 (dopisane ogólne/brakujące znaczenie) | 394 (ogólne znaczenie już w bazie) |

Dodatkowe hasło spoza listy: **on purpose** (celowo) — przy *purpose*, bo to najczęstsze użycie, którego baza nie miała.

### Pominięte `partial`
- **cross** (przym. „zły, rozgniewany”) — BrE; w AmE prawie nieużywane (zamiast tego *mad/angry*).
- **ought to** — znaczenie „powinien” już jest w bazie jako zwrot (`giving-advice.ought-to`); osobny wpis czasownikowy byłby duplikatem.

### `check` z dopisanym znaczeniem (93)
catch (dosłyszeć), simple (łatwy), management (zarządzanie), hit (dotknąć – o kryzysie), function (rola), fail (×2: ponieść porażkę, nie zdołać), environment (otoczenie), production, enter (wejść), series (seria), director (dyrektor), argue (argumentować), board (×2: tablica, zarząd), prove (okazać się), club, sorry (przykro), introduce (wprowadzić), unit (jednostka), card (karta), release (wypuścić), capital (kapitał), treat (×2: traktować, postawić), pressure (ciśnienie), treatment (traktowanie), organize, trip (podróż), match (zapałka), normal, positive (×2: pozytywny, pewny), refer, quarter (×2: ćwierć, ćwierćdolarówka), competition (konkurencja), propose (proponować), reference (nawiązanie), application (aplikacja), hot (ostry), anyway (i tak), science (nauka), basic, operate (×2), perform (wykonywać), memory (pamięć), credit (×2), dead (martwy), responsibility, fix (zrobić jedzenie, AmE), legal (prawny), agent, difficulty, count (liczyć się), scene (miejsce zdarzenia), content (zawartość), element, admit (przyznać), trial (próba), negative, sentence (wyrok), respond (reagować), suit (garnitur), decline (spadać), cool (fajny), labor (praca/siła robocza), select (wybrać), roll (toczyć się), spread (rozsmarować), scale (skala), introduction (wprowadzenie), funny (dziwny), failure (awaria), waste (marnowanie), duty (obowiązek), connect (łączyć), appreciate (być wdzięcznym), burn (palić się), earth (ziemia/gleba), promote (awansować), settle (×2), commit (×2), threat (groźba), totally (całkowicie), dear (drogi), objective (obiektywny), hurt (zranić), deny (zaprzeczać), familiar (zaznajomiony), acquire (zdobyć), tough (×2), capacity (pojemność), confidence (zaufanie), perspective (punkt widzenia), signal (sygnał), bright (bystry), root (źródło problemu).

Wszystkie pozostałe `check` sprawdzone w `dictionary-index` / plikach tematów — ogólne znaczenie już istnieje (np. *son, bed, skill, avoid, contract, mistake*), więc pominięte.

## 3. Zmiany CEFR / POS względem listy (szacunek redakcyjny)
- Znaczenia rozbite na osobne wpisy z własnym CEFR, np. *establish* B2 / C1 (ustalić), *occur* B2 / C1 (occur to), *fail* B1 / B2 (fail to), *appeal* (apel B2, urok B2), *desire* n B2 / v C1, *conduct* (n) C1, *extent* C1, *proceed* C1, *bind* C1, *commit-2* C1.
- *discussion* A2→B1, *depend* A2→B1, *director* (dyrektor) B1, *alone* jako przymiotnik („sam”) mimo użycia przysłówkowego, *anyway* „i tak” B1.
- *gain* (n) i *appeal-2* oznaczone `less_common`.

## 4. Wątpliwości i uwagi redakcyjne
- Kilka tłumaczeń z dopiskiem w nawiasie, żeby odróżnić znaczenie od wpisu tematu z tym samym słowem (walidator `core-in-base` porównuje term+translation): *simple* „prosty (łatwy)”, *function* „funkcja (rola)”, *original-2* „oryginalny (pomysłowy)”, *trial* „próba (test)”, *fair-2* „jasny (o skórze, włosach)”, *tough-2* „twardy (silny)”, *root* „źródło (problemu)”, *earth* „ziemia (gleba)”, *fix* „zrobić (jedzenie)”, *neither* „żaden (z dwóch)”. Jeśli aplikacja pokazuje `translation` dosłownie, nawias może wymagać decyzji UI.
- *wake* = „obudzić (kogoś)” — forma zwrotna *wake up* jest już w bazie.
- *series*: w temacie movies-tv IPA zapisano `/ˈsɪriz/`; w core użyłem `/ˈsɪriːz/` (Oxford US). Prośba do english-qa o ujednolicenie.
- Hasła z treściami „wrażliwymi”, ale częstymi w wiadomościach (*drug-2 narkotyk, murder, gun, bomb, violence, troop, military*), napisano neutralnie, bez szczegółów przemocy.
- *shoot* (strzelać z broni) — pominięte celowo; w bazie są znaczenia sportowe i filmowe.
- Przykłady 6–20 słów (kilkadziesiąt krótszych zdań wydłużono); przy 4–5 przykładach zawsze jest pytanie lub przeczenie.
- W kilku przykładach polski odpowiednik zmienia część mowy (np. *fun* → „bawić się”, *aware* → „zdawać sobie sprawę”, *difficulty* itd.); te formy dopisano do `acceptedTranslations`.

## 5. Prośby do innych ról
- Koordynator: uruchomić `build-index.mjs` i `build-core-master.mjs` (przeliczenie statusów C02), potem pełny `validate-content.mjs`.
- english-qa: ujednolicić IPA *series* w `topics/movies-tv.json`; ewentualnie przejrzeć tłumaczenia z nawiasami (pkt 4).

## 6. Hasła niedokończone
Brak — przeszedłem całą listę C02 (842 hasła).
