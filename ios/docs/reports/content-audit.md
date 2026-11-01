# Raport: content-audit — weryfikacja bazy słów (FEEDBACK-9 N4)

Zakres: `topics/*.json` (142 tematy), `core/core-c01…c08.json`, `starter-words.json`, banki (`grammar/`, `exercises.json`, `idioms.json`, `readings.json`) oraz `tools/data/reading-glossary.json`. Nowy plik `core/core-c09.json`.
Skrypty audytu: `C:\Users\HARDPC~1\AppData\Local\Temp\claude\C--Users-HARD-PC-Desktop-FluentNOW\df8a4d3f-88ca-4686-a14a-24fd1bd92a1b\scratchpad\audit\` (`checks.mjs`, `bre2.mjs`, `splice.mjs`, `sample.mjs`, `probe.mjs`, `probe2.mjs`, `apply.mjs`, `gen-ops1.mjs`, `gen-ops2.mjs`, `gen-c09.mjs` + dane `c09-data*.mjs`).
Nie uruchamiałem `build-index.mjs`, `build-core-master.mjs` ani gita; nie dotykałem plików Swift.

## 1. Wynik

| | przed | po |
|---|---|---|
| wpisy (pliki) | 14 677 (164) | **14 794 (165)** |
| przykłady | 35 520 | 35 907 |
| `validate-content.mjs` | 0 błędów, 0 ostrzeżeń | **0 błędów, 0 ostrzeżeń** (+ `--self-test` OK) |
| `apply-reading-glossary.mjs --check` | OK | OK |

- Zmienione istniejące wpisy: **333** w 70 plikach (497 zmian pól); `id` bez zmian.
- Nowe wpisy: **117** w `core/core-c09.json` (387 przykładów).
- Format zachowany: edycje na tekście pliku (lokalizacja bloku wpisu po `id`, dokładne dopasowanie `"pole": "stara wartość"`, 1 trafienie), a po każdym pliku weryfikacja, że `JSON.parse(nowy tekst)` jest identyczny z obiektem po semantycznym naniesieniu zmian. Liczba zmienionych linii = liczba zmienionych pól/przykładów (różnica tylko przy usunięciu pozycji z wielowierszowej tablicy `acceptedTranslations` w tematach: −1 linia).

## 2. Kontrole automatyczne (przed → po)

| kontrola | przed | po | uwagi |
|---|---|---|---|
| to samo hasło + ta sama część mowy, różne IPA | 2 | 2 | oba celowe: *offense* (sport /ˈɑːfens/ vs przestępstwo /əˈfens/), *tear up* (/ter/ podrzeć vs /tɪr/ wzruszyć się) |
| to samo hasło + to samo tłumaczenie, różne IPA | 3 | **0** | *excuse me*, *bless you*, *party animal* |
| mocna forma for/to/of/at/from w zwrotach | 40 | **4** | 36 poprawek (→ /fər/, /tə/, /ət/, /frəm/); zostają formy na końcu zdania: *not what I asked for*, *what have you been up to*, *where are you from*, *I'm from* |
| to samo hasło + tłumaczenie, różny CEFR | 35 | 30 | ujednolicone: *seat* A1, *goal* A1, *build* A2, *bug* (IT) B1, *server* B1; pozostałe 30 to różne znaczenia (wing, library, plate, branch, channel…) |
| `acceptedTranslations` = tłumaczenie innego znaczenia (ten sam plik) | 22 | **10** | usunięte pozycje innej części mowy/znaczenia (late-2 „późno”, know „znać”, after-2 „po”, before-2 „przed”, harm „szkodzić”, divorce „rozwieść się”, facade-2 „fasada”…); zostały synonimiczne (maintain-2 „utrzymywać”, critical-2 „krytyczny”, panel „panel”…) |
| j.w. między plikami | 344 | 341 | to w większości warianty tego samego znaczenia w różnych tematach; poprawione kolizje części mowy (gold „złoty”, numbers-time.late „późno”, early „wcześnie”) |
| `focusEn ∉ en`, `focusPl ∉ pl` | 0 | 0 | heurystyka „focus niezwiązany z hasłem” (386) = same formy nieregularne (went, teeth…) — OK |
| zdania EN powtórzone w bazie (po normalizacji) | 3 | **0** | |
| zdania PL powtórzone (szablony „to samo zdanie, inne hasło”) | 53 | **0** | 59 przykładów przepisanych (głównie core: horrible/dreadful, great/fantastic, close/shut, sure/positive, widely/greatly/enormously…) |
| BrE w przykładach i definicjach | — | — | baza czysta (flat, lorry, queue, holiday, mobile, rubbish, -our, -ise, at the weekend, in hospital: 0 realnych trafień w zdaniach); poprawione 2× *in the team* → *on the team* |
| cudzysłowy typograficzne w polach EN | 63 | **0** | EN: proste `"…"`, apostrof `'` |
| cudzysłowy proste w polach PL | 121 | **2** | PL: `„…”`; zostały oznaczenia cali (5'10") |
| comma splice (heurystyka ostrzejsza niż walidator) | — | — | 31 poprawek (`, ` → `; `), np. *He's really smart; he finished…*, *Don't freak out; it's just…* |
| podwójne spacje, brak kropki, puste pola obowiązkowe | 0 | 0 | |
| przykład dużo trudniejszy niż hasło A1–A2 | 33 | 30 | poprawione: *short* („sectional”), *bottle* („childproof”), *goal* („scrimmage”); reszta to słowa sceny (dispatcher, wooden) — akceptowalne |

Banki (`grammar/`, `exercises.json`, `idioms.json`, `readings.json`): skan BrE i formatowania pól angielskich — 0 trafień.
Słowniczki czytanek: IPA zgodne z wpisami `ref` (2 rozbieżności po zmianie słabych form — *next to*, *look forward to*) + słabe formy w 8 pozycjach bez `ref` (*belong to* ×2, *be about to*, *switch to*, *attribute to*, *responsible for*, *care for*, *mistake for*); `readings.json` przegenerowany `apply-reading-glossary.mjs`.

## 3. Próba ręczna (300 wpisów z tematów, proporcjonalnie, ziarno 20261102)

Pełna lista kontrolna english-qa (gramatyka, naturalność AmE, zgodność ze znaczeniem, focus, IPA/forms, CEFR, polski). Próba pobrana po poprawkach automatycznych.

- Wpisy z jakąkolwiek usterką: **14/300 = 4,7%** (< 5% — pełna korekta tematów nie jest wymagana).
- W tym błędy merytoryczne po stronie EN (znaczenie, logika, interpunkcja dialogu, comma splice): 8/300 = 2,7%.

| wpis | problem | poprawka |
|---|---|---|
| board-games-puzzles.hand ex1 | *Hold your hand up* = podnieś rękę (inne znaczenie) | *Hide your hand better; Grandpa can see all your cards.* |
| elderly-care.pension ex1 | nielogiczne (*Mom's pension … after Dad's death*) | *…if Mom would keep getting Dad's pension after his death.* |
| law-contracts.verdict ex1 | nienaturalne *The verdict gave me back the full deposit* | *Thanks to the verdict, I got my full deposit back.* |
| natural-disasters.flooded ex0 | *The rain afterwards left…* | *After the storm, our basement was completely flooded.* |
| garden-plants.late-bloomer ex1 | dialog bez cudzysłowu | `"Like these roses, I was a late bloomer too," said Grandma.` + PL „…” – powiedziała |
| family.black-sheep, personality.wet-blanket, small-talk.change-the-subject | comma splice | `;` |
| coworkers.keep-up-the-good-work ex1 | interpunkcja AmE (kropka w cudzysłowie) | `…by saying, "Keep up the good work."` |
| salary-benefits.eligible ex1 | `focus` tylko „prawa” | `aren't eligible` / `nie mają prawa` |
| apologies-politeness.sorry, clothes-fashion.business-casual, work-idioms.slacker | polskie zdanie niezręczne | przeredagowane |
| arguments-conflict.extend-an-olive-branch | brak akcentu pobocznego w IPA | `/ɪkˌstend ən ˈɑːlɪv ˌbræntʃ/` |

Poza próbą (znalezione przy przeglądzie): programming-it.server — oba przykłady brzmiały jak kelner w restauracji (*everyone ordered dinner*, *weekend rush*) → przykłady o serwerze i ruchu na stronie.

Rozkład usterek nie wskazuje tematu do pełnej korekty; najwięcej comma splice było w `personality` (10 przykładów, poprawione) i `small-talk`.

## 4. Sondy brakujących słów i nowy shard `core-c09`

Sondy (termin + `acceptedAnswers`, z pominięciem someone/something):
1. **515 słów/fraz** B1–C2: łączniki, czasowniki frazowe, kolokacje, słownictwo akademickie → brak 87; po odrzuceniu BrE (*get round to, weigh up, come round*), archaizmów prawniczych (*hereby, thereof, hitherto, henceforth, insofar as*), fraz pokrytych innym wpisem (*at first sight* → love at first sight, *as far as* → as far as I know/I'm concerned, *for the sake of* → core.sake) dopisano 76 wpisów.
2. **Słowa „tytułowe” tematów** (na prośbę koordynatora, nameEn + id tematu): brakowało m.in. **airport** (mimo tematu `airport`), *shopping, cooking, banking, fitness, photography, programming, learning, nutrition, politeness, workplace, dating, storytelling, cybersecurity, entrepreneurship* — dopisane. Złożenia opisowe (car rental, office work, remote work, personal finance, body parts…) pominięte jako przejrzyste.
3. **Podstawowe A1–A2** (~670 słów treściowych i funkcyjnych): brakowało *hungry, thirsty, wallet, sandwich, pencil, rainy, English* oraz słów z listy `drop:` w `tools/data/core/annotations-ngsl.txt` (słowa gramatyczne „obsługiwane przez gramatykę”). Z tej listy dopisałem tylko słowa, których uczeń realnie szuka w słowniku i które mają czytelny odpowiednik: *very, some, any, more (więcej / bardziej), much, but, than, should, could, every, everyone, everything, something, nothing, anyone, anything, up, there*. Nie dopisywałem przedimków, zaimków osobowych ani przyimków *in/on/at/of/to/for/with/from* (decyzja projektowa — do potwierdzenia, zob. §6).

**Plik `core/core-c09.json`** (`id` `core-c09`, format jak C01–C08, kategorie wg CEFR): 117 wpisów, 387 przykładów, A1 27 · A2 2 · B1 10 · B2 29 · C1 48 · C2 1. Każdy wpis: 3–5 przykładów (przy 4–5 co najmniej jedno pytanie lub przeczenie), IPA GA wg konwencji (słabe formy przyimków), `forms`, `acceptedAnswers` z hasłem, 1–6 `acceptedTranslations`, `notePl` tam, gdzie pomaga. Walidator `--file`: 0 błędów, 0 ostrzeżeń (w tym `core-in-base`, `duplicate-example` względem całej bazy).

Dopisane hasła: airport, hungry, thirsty, sandwich, pencil, rainy, English, very, some, any, more, more-2, much, but, than, should, could, every, everyone, everything, something, nothing, anyone, anything, up, there, shopping, wallet, cooking, banking, fitness, photography, programming, learning, no longer, at most, along with, catch up with, have an impact on, nutrition, politeness, workplace, dating, storytelling, when it comes to, given that, so as to, other than, in place of, account for (wyjaśnić), account for-2 (stanowić), come about, draw up, pull off, talk into, talk out of, spell out, come around, in the long term, a great deal, take into consideration, in the first place, it goes without saying, take the lead, lose track of, upside, downside, criterion, cybersecurity, entrepreneurship, in light of, conversely, by and large, in accordance with, with respect to, on account of, irrespective of, amid, come forward, factor in, mull over, pose a threat, at stake, come to terms with, on the verge of, shed light on, lay the groundwork, at all costs, come into effect, run the risk, catch sight of, give rise to, make headway, speculate, gist, whereabouts, foresight, rigorous, deduce, distort, underlie, warrant, inherently, nuanced, pertinent, rationale, premise, refute, corroborate, encompass, necessitate, convene, noteworthy, coherence, prerequisite, counterpart, supersede.

**Wykrywanie shardów — zmiana kodu niepotrzebna.** `ContentLibrary.coreFileIDs()` (`ios/FluentNOW/Services/Content/ContentLibrary.swift:194`) listuje katalog `core/` przez `FileManager.contentsOfDirectory` i filtruje `CoreVocabulary.fileIDs(fromFileNames:)` (prefiks `core-c`); `build-index.mjs` i `build-core-master.mjs` czytają `core/` przez `readdirSync`; `project.yml` dołącza `Resources/Content/**`.

**Do zrobienia przez koordynatora:** `node ios/tools/build-index.mjs` (wpisy C09 trafią do `dictionary-index.json`), potem `node ios/tools/build-core-master.mjs` i pełne `validate-content.mjs`.

## 5. Najważniejsze poprawki (poza tabelami)

- **Słabe formy** w 36 hasłach (tematy) + 8 w słowniczkach czytanek: *look forward to* /tə/, *listen to* /ˈlɪsən tə/, *have to* /ˈhæf tə/, *next to*, *used to*, *ask for advice* /fər/, *hear from* /frəm/, *take a look at* /ət/…
- **Szablonowe duplikaty** w core: przykłady różniące się tylko hasłem (*I feel horrible/dreadful about forgetting your birthday*, *Prices vary widely/greatly/enormously…*) — przepisane, żeby polskie zdanie jednoznacznie wskazywało jedno angielskie (ważne przy tłumaczeniu PL→EN, gdy oba hasła są w talii).
- **Cudzysłowy**: EN jednolicie `"…"`, PL jednolicie `„…”` (110 notatek core miało `"…"`).
- `opinions-agreeing.it-depends` ex1: *It depends, will it be hot?* → *It depends on whether it'll be hot.*

## 6. Wątpliwości

1. **Słowa funkcyjne.** `annotations-ngsl.txt` świadomie pomija słowa gramatyczne A1 (linia `drop:`). Dopisałem 19 „słownikowych” (very, some, much, should…), bo bez nich „Dodaj słowo”/wyszukiwanie zwraca pustkę. Jeśli projekt woli trzymać je wyłącznie w gramatyce — usunąć te wpisy z `core-c09` (kategoria A1). Przyimki i zaimki osobowe pozostają poza bazą.
2. `greetings-introductions.im-from` /aɪm ˈfrʌm/ — w użyciu *I'm from Poland* forma słaba; zostawione, bo hasło bywa samodzielną odpowiedzią.
3. Pole `synonyms` czasem podaje brytyjski odpowiednik bez etykiety (trousers, timetable, lorry, flatmate, return ticket) — zostawione; ewentualnie dopisać „(BrE)”, jeśli UI nie używa synonimów jako akceptowanych odpowiedzi.
4. 30 konfliktów CEFR „to samo hasło + tłumaczenie” dotyczy różnych znaczeń (np. *plate* talerz/obciążenie, *library* biblioteka/biblioteka kodu) — celowo różne poziomy.
5. Heurystyka `comma-splice` w walidatorze przepuszcza wzorzec „przymiotnik/rzeczownik, zaimek + czasownik” (*He's really smart, he finished…*) i podmioty typu *nobody/everyone*. Proponuję dodać ten wzorzec (mój `splice.mjs`) jako ostrzeżenie.

## 7. Rekomendacje

- Przebudować indeksy (§4) i włączyć `core-c09` do kolejnej fali english-qa (świeży tekst jednego autora).
- Dodać do walidatora: słabe formy przyimków w IPA zwrotów (lista wyjątków dla przyimka na końcu zdania), duplikaty polskich zdań w całej bazie (dziś tylko EN), cudzysłowy EN/PL.
- `export-web-content.mjs` nadal może nadpisać `starter-words.json` (ryzyko z `content-final.md`); w tym audycie zmieniłem tam 2 pola (cudzysłowy) — należy je przenieść do nadpisań eksportu razem z wcześniejszymi.
