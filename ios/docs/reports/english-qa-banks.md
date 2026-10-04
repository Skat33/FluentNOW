# Raport english-qa — banki przeniesione ze strony

Zakres: `ios/FluentNOW/Resources/Content/` → `grammar/A1–C2.json`, `exercises.json`, `idioms.json`, `readings.json`, `starter-words.json`, `recommendations.json`, `answer-variants.json`. Katalogu `topics/` nie dotykałem.

## 1. Co zrobiono

- Przejrzałem **każdy** wpis w zakresie. Kompaktowe widoki generowałem skryptami Node i czytałem porcjami. Gramatykę czytałem regułami po 20 zadań, bo bank jest szablonowy: 15 konstrukcji × 20 scen na poziom, a w B2–C2 te same 20 scen i czasowników.
- Poprawki naniosłem bezpośrednio w plikach JSON. Serializacja jest identyczna jak w `export-web-content.mjs` (jego `stringify`), więc diff pokazuje tylko faktyczne zmiany. `bankId` się nie zmieniły, więc zgodność z `grammarSeen` jest zachowana.
- **Skrypt poprawek:** `ios/docs/reports/english-qa-banks-fix.mjs`. Jest idempotentny: po świeżym eksporcie dwa przebiegi dają punkt stały. Drugi przebieg dokłada tylko 12 wariantów w C2-14, liczonych od dodanego tam „to have + pp”. Skrypt opisuje dokładnie każdą zmianę z tabel poniżej (patrz §5, prośba do data-pipeline).
- Po zmianach uruchomiłem `node ios/tools/build-index.mjs`, bo zmieniły się `translation` w `starter.do` i `starter.do-2`. Wynik: 37 tematów, 3138 rekordów słownika.

Pliki zmienione: `grammar/A1.json` … `grammar/C2.json`, `exercises.json`, `idioms.json`, `readings.json`, `starter-words.json` (plus wygenerowane indeksy). Bez zmian: `recommendations.json` i `answer-variants.json`, bo nie znalazłem w nich błędów.

## 2. Tabela poprawek

Zmiany systematyczne (wiele zadań, jedna reguła) podaję wierszem zbiorczym z wzorcem `bankId`. Zapis `L-RR-KK` oznacza `grammar-36-<poziom>-<reguła>-<scena>`.

### 2.1 Gramatyka — `acceptedAnswers` (problem „analizować” → „review” i podobne)

Przyczyna: polska podpowiedź dopuszcza naturalny angielski synonim, a `acceptedAnswers` było puste. Uczeń, który wpisał poprawną formę innego czasownika, dostawał błąd. Wybrałem opcję bezpieczniejszą: **dodałem synonimy w tej samej formie gramatycznej**. Podpowiedzi zostały bez zmian. Synonimy dobrałem do konkretnego obiektu w scenie. Żaden wariant nie jest równy dystraktorowi (skrypt to sprawdza i przerywa, gdyby tak było).

| plik | id | pole | było | jest (przykład) | kategoria |
|---|---|---|---|---|---|
| grammar/B2–C2 | `*-*-00` (analizować → review) | acceptedAnswers | `[]` | `had already analyzed`, `had already examined` (+ formy w każdej konstrukcji) | wieloznaczność podpowiedzi |
| grammar/B2–C2 | `*-*-03`, `*-*-15` (oceniać) | acceptedAnswers | `[]` | assess ↔ evaluate | j.w. |
| grammar/B2–C2 | `*-*-05` (badać → investigate) | acceptedAnswers | `[]` | examine, look into | j.w. |
| grammar/B2–C2 | `*-*-07` (weryfikować → verify) | acceptedAnswers | `[]` | check | j.w. |
| grammar/B2–C2 | `*-*-11` (przydzielić → allocate) | acceptedAnswers | `[]` | assign | j.w. |
| grammar/B2–C2 | `*-*-13` (dostosować → adapt) | acceptedAnswers | `[]` | adjust | j.w. |
| grammar/B2–C2 | `*-*-14` (sprawdzić → inspect) | acceptedAnswers | `[]` | check, examine | j.w. |
| grammar/B2–C2 | `*-*-16` (uzyskać → secure) | acceptedAnswers | `[]` | obtain, get (`got`/`gotten` zależnie od składni: „would rather we got”, „had gotten”) | j.w. |
| grammar/B2–C2 | `*-*-17` (zmienić → amend) | acceptedAnswers | `[]` | change, modify, revise | j.w. |
| grammar/B2–C2 | `*-*-18` (kontrolować → audit) | acceptedAnswers | `[]` | check, inspect | j.w. |
| grammar/B2–C2 | `*-*-19` (odtworzyć → reconstruct) | acceptedAnswers | `[]` | recreate | j.w. |
| grammar/A1–B1 | `*-*-10` (wybierać → choose) | acceptedAnswers | `[]` / `["to choose"]` | pick, select | j.w. |
| grammar/A1–B1 | `*-*-17` (zbierać → collect) | acceptedAnswers | `[]` | gather | j.w. |
| grammar/A1–B1 | `*-*-18` (naprawiać → fix) | acceptedAnswers | `[]` | repair | j.w. |
| grammar/B1 | `B1-00-*` (20) | acceptedAnswers | `[]` | `have packed` (bez „already”, którego w zdaniu nic nie sugeruje) | odpowiedź niejednoznaczna |
| grammar/B2 | `B2-00-*` (20) | acceptedAnswers | `[]` | `had reviewed` itd. | j.w. |
| grammar/C2 | `C2-14-*` (20) | acceptedAnswers | `[]` | `to have reviewed` (would have liked to have + pp — poprawne) | odpowiedź niejednoznaczna |
| exercises | legacy-grammar-600374084 | acceptedAnswers | `[]` | `having broken` (wyjaśnienie gramatyki B2 samo podaje tę formę) | j.w. |
| exercises | legacy-grammar-3423518032, -3194024353, -1510987045, -2478347154, -4044529832, -1084959712 | acceptedAnswers | `[]` | `should resign` / `should be` / `should be refunded` / `should be removed` / `should be disclosed` / `should receive` (C1-02 bank też akceptuje should) | j.w. |

### 2.2 Gramatyka — treść zdań i podpowiedzi

| plik | id | pole | było | jest | kategoria |
|---|---|---|---|---|---|
| grammar/A1 | A1-03-12, A1-05-12 | context/hintPl/answer/distractors/translation | „We are **finding** shells…” (znajdować) | „We are **looking for** shells…” (szukać); dystraktory look for / looks for / to look for | naturalność (find w czasie ciągłym) |
| grammar/A1 | A1-04-12 | context, translation | „We are finding shells… so please wait” | „We are looking for shells…”; „Teraz szukamy muszli…” | j.w. |
| grammar/A1 | A1-10-12 | context/hint/answer/distr./translation | „**Do not find** shells… wait until tomorrow” | „Do not **look for** shells…” | logika (zakaz „znajdowania”) |
| grammar/A1 | A1-12-03 | context, translation | „sandwiches for lunch **before lunch**” | „…for lunch **before noon**” / „przed południem” | logika (tautologia) |
| grammar/A1 | A1-12-14 | context, translation | „rice for dinner before lunch” | „rice for dinner this afternoon” | logika |
| grammar/A2 | A2-03-12 | context/hint/answer/distr. | „we were finding shells” (tłum. „szukaliśmy”) | „we were looking for shells” | niezgodność EN↔PL |
| grammar/A2 | A2-04-12 | context | „We were finding shells… when the phone rang” | „…looking for shells…” | j.w. |
| grammar/A2 | A2-09-12 | context/hint/answer/distr./translation | „should find shells… more carefully” | „should look for shells… more carefully” | logika |
| grammar/A2 | A2-13-00 | context, translation | „…bags for the trip after the long **trip**” | „…after the long **day**” / „Po długim dniu…” | styl (powtórzenie) |
| grammar/B1 | B1-03-12 | context/hint/answer/distr. | „While we were finding shells” | „While we were looking for shells” | niezgodność EN↔PL |
| grammar/B1 | B1-04-03 | context, translation | „sandwiches for lunch before dinner” | „sandwiches for tomorrow's lunch before dinner” | logika |
| grammar/B1 | B1-04-14 | context, translation | „rice for dinner **before dinner**” | „rice for dinner before five” | logika (tautologia) |
| grammar/B2 | B2-11-14 | context, translation | „inspect … before the inspection” | „…before the official visit” / „przed oficjalną wizytą” | styl (powtórzenie) |
| grammar/B2–C2 | `*-*-19` (45 zadań) | context | „the sequence of events **before** the accident” (np. „…before the accident before the deadline expires”) | „the sequence of events **leading up to** the accident” | styl/naturalność |
| grammar/C1 | C1-08-* (20) | context, translation | „Having secured the permits…, we were finally able to **publish our findings**” (bez sensu dla 15 z 20 scen) | „…we were finally able to **move on to the next stage**” / „przejść do kolejnego etapu” | logika |
| grammar/C2 | C2-01-* (20) | context, translation | „No sooner had we restored the paintings than **the findings** were challenged” | „…than **our work** was challenged” / „naszą pracę zakwestionowano” | logika |
| grammar/C2 | C2-08-* (20) | context, translation | „…vouch for the reliability of **the conclusions**” | „…vouch for **the quality of the work**” / „ręczyć za jakość tej pracy” | logika |
| exercises | legacy-grammar-600374084 | context, hintPl | „(złamać) the window” | „(wybić)” — „złamać szybę” to kalka; tłumaczenie już miało „wybił” | podpowiedź PL |

### 2.3 Gramatyka — tłumaczenia polskie (konstrukcja nieoddana)

| plik | id | było | jest | kategoria |
|---|---|---|---|---|
| grammar/B1 | B1-00-04 | „Już czytaliśmy dzieciom opowiadania” | „Już przeczytaliśmy…” | aspekt |
| grammar/B1 | B1-05-* (20) | „częściej **moglibyśmy** pakować” (would ≠ could) | „częściej **pakowalibyśmy**…” | tryb |
| grammar/B1 | B1-10-* (20) | „Rozmawialiśmy o planie, żeby X podczas następnej wizyty” | „Rozmawialiśmy o tym, żeby podczas następnej wizyty X” | składnia PL |
| grammar/B2 | B2-03-* (20) | „udałoby nam się przeanalizować” | „przeanalizowalibyśmy” | tryb |
| grammar/C1 | C1-01-* (20) | „Nigdy wcześniej nie przeanalizowaliśmy” | „…nie analizowaliśmy” (doświadczenie) | aspekt |
| grammar/C1 | C1-02-* (20) | „zażądała, żebyśmy najpierw **zdołali** przeanalizować…” | „Komisja nalegała, żebyśmy przeanalizowali…, zanim wydamy jakiekolwiek publiczne oświadczenie.” | dodane znaczenie |
| grammar/C1 | C1-03-* (20) | „obecnie moglibyśmy przeanalizować” (would be -ing) | „teraz analizowalibyśmy” | tryb/aspekt |
| grammar/C1 | C1-04-*, C2-04-* (40) | „moglibyśmy przeanalizować” | „przeanalizowalibyśmy” | tryb |
| grammar/C1 | C1-09-* (20) | „Gdyby udało nam się wcześniej…” | „Gdybyśmy wcześniej przeanalizowali…” | wierność |
| grammar/C1 | C1-13-* (20) | „musieliśmy godzinami analizować” (czyta się jak obowiązek) | „Sądząc po tym, jak wszyscy byli wyczerpani, najwyraźniej godzinami analizowaliśmy…” | znaczenie must (wniosek) |
| grammar/C1 | C1-14-* (20) | „wolałby, żebyśmy… zdołali przeanalizować” | „wolałby, żebyśmy przeanalizowali… jutro, a nie dziś” | dodane znaczenie |
| grammar/C2 | C2-05-* (20) | „moglibyśmy teraz… przeanalizować” | „teraz… analizowalibyśmy” | tryb/aspekt |
| grammar/C2 | C2-12-* (20) | „żeby udało nam się przeanalizować” | „żebyśmy przeanalizowali” | wierność |
| grammar/C2 | C2-14-* (20) | „Choć bardzo chcielibyśmy byli…” | „Choć bardzo chcieliśmy…” | styl PL (archaizm) |

### 2.4 Idiomy (`idioms.json`)

| id | pole | było | jest | kategoria |
|---|---|---|---|---|
| idiom-v1-A1-00…17 (4 pytania) | options | „Proszę, oto to” | „Proszę (podając coś)” | polski nienaturalny |
| idiom-v1-A1-08 | explanation | „…oznacza: proszę, oto to.” | „…oznacza: proszę (gdy coś komuś podajemy).” | j.w. |
| idiom-v1-B2-03 | translation | „Ucieczka tego autobusu wyszła mi na dobre” | „To, że spóźniłem się na autobus, wyszło mi na dobre” | tłumaczenie PL |
| idiom-v1-B2-14 | context, translation | „…failed, leaving us back to square one.” | „The experiment failed, so we were back to square one.” | kolokacja |
| idiom-v1-C1-12 | prompt, context, explanation | „A storm in a teacup” (BrE) | „A tempest in a teapot” | AmE |
| idiom-v1-C2-02 | prompt, context | „hoist with his own petard” | „hoisted by his own petard” | forma AmE |
| idiom-v1-C2-03 | prompt, context, translation, explanation; opcja w C2 | „Carry coals to Newcastle” / „Robić coś zbędnego tam, gdzie tego nie brakuje” | „Preach to the choir” — „Lecturing these volunteers about recycling is preaching to the choir; they already sort everything.” / „Przekonywać przekonanych” (podmienione też jako dystraktor w C2-00, C2-06, C2-12) | AmE |
| idiom-v1-C2-04 | prompt, context, explanation | „Set the cat among the pigeons” | „Stir up a hornet's nest” (opcja „Wywołać zamieszanie lub niepokój” bez zmian) | AmE |
| idiom-v1-C2-05 | prompt, context, explanation | „A curate's egg” | „A mixed bag” | AmE |
| idiom-v1-C2-11 | prompt, context, translation, explanation | „Grasp the nettle” (BrE, nie było w zgłoszeniu) | „Take the bull by the horns” / „wziął byka za rogi” | AmE |

### 2.5 Czytanki (`readings.json`)

| id | pole | było | jest | kategoria |
|---|---|---|---|---|
| reading-v39-waiting-list | paragraphs[3], questions[2].question, .explanation | „created a **queue** for patients…”, „that queue”, „the new queue”, „Kolejka wspierała” | „a separate **call-in list**…”, „that call-in list”, „the new call-in list”, „Nowa lista telefoniczna wspierała” | słownictwo BrE |
| reading-v39-night-trains | paragraphs[0–1], q1.options[1], q1.evidence | „carriages” (4×), „timetable” | „passenger cars” / „cars”, „schedule” | słownictwo BrE |
| reading-v39-perfect-minutes | paragraphs[2] | „endorsed the **scheme** as presented” | „…the plan…” (w AmE scheme ≈ machinacja) | słownictwo |
| reading-legacy-lunch-for-two | paragraphs[0] | „Ben orders it and gives Ana some of his **salad**.” (sałatki nie było) | „Ben orders it and shares it with Ana.” | spójność treści |
| reading-legacy-a-better-way-to-work | q1.options[3] | „cancelled” | „canceled” | pisownia BrE |
| reading-legacy-when-efficiency-becomes-a-habit | q1.question | „behaviour” | „behavior” | pisownia BrE |
| reading-legacy-the-value-of-an-unfinished-answer | q1.options[2] | „criticised” | „criticized” | pisownia BrE |
| 12 × reading-legacy-* | topic | `""` | słowa kluczowe PL/EN (np. „lekarz zdrowie doctor health”) | metadane |

### 2.6 Słowa startowe (`starter-words.json`)

| id | pole | było | jest | kategoria |
|---|---|---|---|---|
| starter.do | translation, acceptedTranslations | „wykonywać czynność” (tylko ta jedna odpowiedź) | „robić, wykonywać”; [robić, wykonywać / robić / zrobić / wykonywać / wykonać] | opis zamiast odpowiednika |
| starter.do-2 | translation, acceptedTranslations, notePl | „czasownik pomocniczy w pytaniach” | „czy (w pytaniach)”; [„czy (w pytaniach)”, „czy”]; notePl z wyjaśnieniem | j.w. |
| starter.borrow, boarding-pass, it-depends, bank, bank-2, reservation, deadline, say (2), tell, make (2), do-2 (2), do-3, appointment, recommend (2), strength | examples | 19 przykładów krótszych niż 6 słów (np. „What did you say?”, „A small bag will do.”, „I want to make a cake.” ↔ „upiec”) | rozbudowane do 6–9 słów w scenie, np. „Sorry, what did you say about the meeting?”, „A small bag will do for a weekend trip.”, „I want to make dinner for my parents tonight.”; `focusEn`/`focusPl` są podciągami | standard §7 |

## 3. Statystyka

Liczba sprawdzonych wpisów: grammar 1800 · exercises 72 · idioms 108 · readings 42 (173 pytania) · starter 21 · recommendations 5 · answer-variants 41 grup + 62 pary + 6 aliasów. Zmieniono 1280 pól.

| plik | wpisów | zmienione wpisy (łącznie) | w tym błąd treści (bez samego dopisania acceptedAnswers) | odsetek z błędem treści |
|---|---|---|---|---|
| grammar/A1 | 300 | 45 | 6 | 2% |
| grammar/A2 | 300 | 40 | 4 | 1% |
| grammar/B1 | 300 | 96 | 44 | 15% |
| grammar/B2 | 300 | 196 | 35 | 12% |
| grammar/C1 | 300 | 244 | 167 | 56% |
| grammar/C2 | 300 | 228 | 129 | 43% |
| exercises | 72 | 7 | 1 | 1% |
| idioms | 108 | 14 | 14 | 13% |
| readings | 42 | 15 | 15 (w tym 12 tylko topic) | 7% bez topic |
| starter-words | 21 | 16 | 16 | 76% |
| recommendations / answer-variants | 5 / 109 | 0 | 0 | 0% |

Liczba poprawek wg kategorii (pola): acceptedAnswers (warianty) 709 · tłumaczenie PL (tryb/aspekt/wierność/styl) 287 · logika zdania 130 · styl (powtórzenia) 47 · naturalność czasownika 26 · AmE idiomy/forma 23 · przykłady < 6 słów 19 · metadane topic 12 · słownictwo/pisownia BrE 13 · tłumaczenie-opis 5 · polski nienaturalny 4 · podpowiedź-kalka 2 · kolokacja 2 · spójność treści 1.

Wysoki odsetek w C1/C2 wynika z błędów **szablonowych**: jedno złe tłumaczenie albo zdanie główne powtarza się w 20 zadaniach. Angielski w banku gramatyki był gramatycznie poprawny. Dystraktory sprawdziłem: wszystkie są jednoznacznie błędne. Wyjątek naprawiłem przez acceptedAnswers: brakowało w nich poprawnych alternatyw, których nie było wśród dystraktorów (should + bezokolicznik, having + pp, to have + pp, wariant bez „already”).

## 4. Wątpliwości nierozstrzygnięte / ryzyka

1. **Dopasowanie synonimów w trybie pisania** działa tylko dla tych, które dopisałem. Inne sensowne odpowiedzi (np. „study the cause” dla „badać”, „keep” dla „zachować”, „renovate” dla „odnawiać”) nadal zostaną odrzucone. Podpowiedzi „odnawiać” (obrazy → lepiej „odrestaurować”) i „zachować” nie zmieniałem.
2. **Logika semantyczna szablonów, nie poprawiana:** C1-12 „Although we had secured/allocated … *thoroughly*”, C2-09 „Only by restoring the paintings … could we rule out institutional bias” i C2-10 „withheld judgment lest we review…” brzmią sztucznie dla części scen, ale są gramatycznie poprawne. A1–A2 mają drobne dziwactwa („Do we pack the bags for the trip every week?”). Pełna poprawa wymagałaby przepisania scen w generatorze strony.
3. Reguła `B2-11 "passive infinitive"` testuje w praktyce „were required **to review**” (bezokolicznik czynny). Etykieta pochodzi ze strony; wyjaśnienie jest poprawne.
4. `C2-12`: polski nie ma odpowiednika „would rather we had + pp”. Tłumaczenie „wolałby, żebyśmy przeanalizowali… przed rozesłaniem” traci kontrfaktyczność przeszłą.
5. `idiom-v1-C2-05` „A mixed bag” to raczej poziom B2/C1. Na C2 nie znalazłem równie znanego amerykańskiego odpowiednika „curate's egg”, więc poziom jest lekko zaniżony.
6. `B1-00` (present perfect vs past simple): w AmE „We packed the bags, so that job is finished” też jest naturalne. Nie dopisałem past simple, bo zadanie ćwiczy present perfect (dystraktory go nie zawierają, więc tryb wyboru jest jednoznaczny).
7. `starter.do` po zmianie tłumaczenia na „robić, wykonywać” w kierunku PL→EN pokrywa się z `make` („robić”). Przy błędzie ocena może wymagać rozróżnienia — do sprawdzenia przez core-engine.
8. Nie uruchamiałem ponownego eksportu (zgodnie z poleceniem).

## 5. Prośby do innych ról

- **data-pipeline:** ponowny eksport (`export-web-content.mjs`) **nadpisze wszystkie powyższe poprawki**. Proszę albo przenieść je do tablic eksportu, albo po eksporcie uruchamiać `node ios/docs/reports/english-qa-banks-fix.mjs` dwa razy (idempotentny; korzysta z `stringify` eksportu). Proszę też zaktualizować `content-issues-web-banks.md`: pozycje „analizować”, queue, idiomy BrE, hoist, starter.do-2, przykłady < 6 słów, starter.make i topic czytanek legacy są zamknięte.
- **core-engine:** `ProductionGrader.grade` sprawdza najpierw `answer + acceptedAnswers`, potem dystraktory. Kolejność jest poprawna: synonimy nie kolidują z dystraktorami (skrypt to weryfikuje). Lista `acceptedAnswers` ma teraz do 9 elementów; nie zakładajcie małego limitu.
- **ui-learning:** w trybie wyboru `options = answer + 3 dystraktory`, więc acceptedAnswers nie wpływają na opcje. Bez zmian po stronie UI.

## 6. Testy i wyniki skryptów

- `node ios/tools/validate-content.mjs --file <plik>` dla wszystkich 12 plików zakresu: **0 błędów, 0 ostrzeżeń**. Przed poprawkami było 1 ostrzeżenie (queue w waiting-list).
- Skrypt poprawek: przebieg 1 — 1268 zmian pól, przebieg 2 — 12, przebieg 3 — 0 (punkt stały). Asercje: brak kolizji wariantu z dystraktorem; `focusEn` ⊂ `en` i `focusPl` ⊂ `pl` w nowych przykładach; wszystkie podmieniane fragmenty czytanek istnieją.
- Serializacja: `stringify(JSON.parse(plik)) + "\n" === plik` dla wszystkich plików banków (format eksportu zachowany).
- `node ios/tools/build-index.mjs`: zapisano `topics/index.json` i `dictionary-index.json` (37 tematów, 3138 rekordów).
