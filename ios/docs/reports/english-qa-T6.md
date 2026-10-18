# Raport: english-qa, zakres QA-T6 (shardy S11 + S12, 22 tematy)

## 1. Co zrobiono

Przejrzałem ręcznie wszystkie **1621 wpisów** w 22 plikach `ios/FluentNOW/Resources/Content/topics/`:
science, exams-tests, language-learning, math, countries-nationalities, jobs-professions, materials-objects, cycling, cruise-ferry, car-problems (S11) oraz fast-food-takeaway, board-games-puzzles, neighbors-community, elderly-care, babies, shopping-mall, emergencies-safety, describing-places, feelings-reactions-phrases, work-idioms, everyday-phrasal-verbs, slang-informal (S12).

Metoda (jak w T1–T3):
- Kompaktowy widok każdego pliku skryptem Node (`term | IPA | pos | CEFR | translation | AT | AA | DEF | forms | NOTE | 2× EN/PL z fokusami`), czytany porcjami po 30–45 wpisów.
- Poprawki nanosiłem plikami łatek (`fix-<temat>.mjs`) i skryptem `apply.mjs`. Każda operacja sprawdza starą wartość, a po zmianach skrypt kontroluje, czy `focusEn`/`focusPl` są podciągami zdań. Plik zapisuje się tylko wtedy, gdy wszystko przejdzie. Format: `JSON.stringify(…, null, 2)` + LF, UTF-8. Wcześniej sprawdziłem, że ten format odtwarza każdy z 22 plików bajt w bajt.
- Każda zmiana trafia do dziennika. Pełna tabela (889 zmian pól: plik | id | pole | było | jest | kategoria) jest w `ios/docs/reports/english-qa-T6-changes.md`.
- Nie zmieniłem żadnego `id`. Nie uruchamiałem gita.
- Po każdym pliku `validate-content.mjs --file` dawał 0 błędów i 0 ostrzeżeń. Na koniec cała baza: **OK: plików 156, wpisów 10711, błędów 0, ostrzeżeń 0**. `build-index.mjs`: 142 tematy, 10690 wpisów w tematach, 10711 rekordów słownika.

## 2. Statystyka

Łącznie 889 zmian pól w 595 wpisach (36,7%), z czego 205 to zmiany mechaniczne. **441 wpisów (27,2%) miało usterkę redakcyjną.** 101 z nich dotyczyło wyłącznie interpunkcji (comma splice w EN i odpowiadająca mu poprawka w PL). Bez nich zostaje **340 wpisów (21,0%) z błędem merytorycznym** (słownictwo, gramatyka, znaczenie, tłumaczenie, listy odpowiedzi).

### Zmiany według kategorii

| kategoria | zmian pól | wpisów | opis |
|---|---|---|---|
| `pl`: polskie zdania i `focusPl` | 321 | 243 | kalki, rekcja, szyk, „Sorry” w polskim zdaniu, opisowe zdania; około 115 to poprawki interpunkcji równoległe do EN |
| `forms-mech` (mechaniczne) | 165 | 165 | S12: `hurries up – hurried up – …` → `hurry up – hurried up – …` (konwencja T1), także w zwrotach i idiomach |
| `grammar-en`: gramatyka i interpunkcja EN | 123 | 110 | ok. 95 comma splice (głównie w S11 i w S12 feelings/slang), dzielone cytaty, czasy, szyk |
| `accepted`: AT/AA mieszające znaczenia | 79 | 78 | patrz §4 |
| `ipa-conv` (mechaniczne) | 40 | 40 | ɝ → ɜːr, ɚ → ər (S11; S12 był już zgodny z konwencją) |
| `def`: synonimy, kolokacje, notatki, nieregularne `forms` | 39 | 37 | błędne synonimy, `forms` typu `graded – graded` → `graded; grading` (styl S11) |
| `ipa` (ręczne) | 27 | 27 | podwójny akcent główny, /ˈmerɪ-/ → /ˈmærɪ-/, nieakcentowane `for/to/as` → /fər tə əz/, akcent wykrzykników |
| `naturalness-en` | 20 | 19 | nienaturalne kolokacje i zdania |
| `british`: BrE w polach AmE | 17 | 16 | synonimy lub `natural`: sit an exam, mock exam, resit, full marks, carer, timber, gearbox, wing mirror, courtesy car, care home, shopfront, patience, meal deal, cycle lane… |
| `cefr-register` | 17 | 17 | „slangowy” → „potoczny” dla słów potocznych, ale nie slangowych |
| `pl-units` | 13 | 13 | mile, stopy, jardy i funty w zdaniach niedotyczących samej skali → km, m, kg, g |
| `pl-floor` | 8 | 8 | US first floor = parter (patrz §3) |
| `translation` | 6 | 6 | port of call, nightlight, filthy, no kidding, golden handshake, spill the tea |
| `cefr` | 6 | 3 | prowler, pungent, golden handshake: C2/rare → C1/less_common |
| `meaning`: przykład niezgodny z hasłem | 4 | 4 | |
| `safety` | 4 | 3 | wulgaryzm lub stereotyp |

### Odsetek wpisów z usterką (bez zmian mechanicznych)

| plik | wpisy | z usterką | % | zmienione pola | wszystkie dotknięte |
|---|---|---|---|---|---|
| science | 99 | 13 | 13,1% | 17 | 16 |
| exams-tests | 74 | 33 | 44,6% | 48 | 34 |
| language-learning | 83 | 23 | 27,7% | 43 | 29 |
| math | 75 | 19 | 25,3% | 32 | 21 |
| countries-nationalities | 88 | 23 | 26,1% | 44 | 26 |
| jobs-professions | 73 | 22 | 30,1% | 34 | 29 |
| materials-objects | 66 | 17 | 25,8% | 24 | 18 |
| cycling | 67 | 21 | 31,3% | 39 | 21 |
| cruise-ferry | 64 | 18 | 28,1% | 28 | 22 |
| car-problems | 67 | 29 | 43,3% | 44 | 30 |
| fast-food-takeaway | 77 | 14 | 18,2% | 18 | 20 |
| board-games-puzzles | 90 | 17 | 18,9% | 28 | 32 |
| neighbors-community | 71 | 11 | 15,5% | 14 | 31 |
| elderly-care | 77 | 16 | 20,8% | 22 | 23 |
| babies | 68 | 12 | 17,6% | 15 | 24 |
| shopping-mall | 62 | 12 | 19,4% | 16 | 17 |
| emergencies-safety | 72 | 15 | 20,8% | 25 | 18 |
| describing-places | 73 | 20 | 27,4% | 34 | 22 |
| feelings-reactions-phrases | 70 | 28 | 40,0% | 45 | 28 |
| work-idioms | 74 | 26 | 35,1% | 39 | 36 |
| everyday-phrasal-verbs | 62 | 21 | 33,9% | 28 | 62 |
| slang-informal | 69 | 31 | 44,9% | 47 | 36 |
| **razem** | **1621** | **441** | **27,2%** | **684** | **595** |

Ocena: angielskie zdania są na ogół naturalne, osadzone w scenie i bez marek. Wysoki odsetek wynika głównie z trzech systematycznych nawyków: comma splice, mieszania znaczeń w AT/AA oraz BrE w synonimach. Bez interpunkcji wynik jest bliższy T1 (21%). Najczystsze pliki to science, neighbors-community i babies. Najwięcej pracy wymagały exams-tests i car-problems (comma splice, BrE, `forms`) oraz slang-informal i feelings-reactions-phrases (comma splice, rejestr, wulgaryzmy w AT).

## 3. Problemy systemowe

1. **Comma splice** (*Hurry up, the bus comes in five minutes!*; *Your radiator has a small crack, that's why it overheated.*): ok. 95 zdań EN. Poprawione na kropkę, średnik, dwukropek lub `!`. Polskie odpowiedniki z dwoma pełnymi zdaniami zmieniłem na kropkę lub półpauzę. Zostawiłem przecinek kontrastowy *I don't want X, I just want Y* (standard AmE, tak jak T3) oraz wtrącenia typu *knock on wood*.
2. **Dzielone cytaty z dwoma zdaniami** (*"How awful," I said, "you must have been so scared."*): poprawione na *I said. "You must…"*. Po polsku: `– powiedziałam. – „Musiałaś…”`.
3. **Numeracja pięter**: S12 przelicza już US *first floor* na parter, a S11 nie. Ujednoliciłem 8 zdań S11 (*second floor* → „pierwsze piętro” itd.).
4. **Jednostki**: zgodnie z decyzją T1 przeliczyłem mile, stopy, jardy, funty i mph w zdaniach, które nie mówią o samej skali (13 zdań). Zostawiłem zdania „pomiarowe” w `math` (pole i średnica w stopach na amerykańskim podwórku), stopnie Fahrenheita w `science.boiling-point` i hiperbolę „sto mil” w `cycling.backpedal`.
5. **`forms` w S12** zaczynały się od 3. os. lp., również w zwrotach i idiomach: 165 wpisów ujednoliconych do konwencji T1. S11 używa stylu S4 (`past; -ing` dla regularnych, `past – pp` dla nieregularnych). Zostawiłem go i poprawiłem tylko błędne wpisy typu `graded – graded`.
6. **„Sorry” w polskich zdaniach** (6×) → „Przepraszam”, „Wybacz”, „Wybaczcie”.
7. **BrE w `synonyms`/`natural`** przy haśle AmE (17 pól). BrE zostawiłem tylko w `acceptedAnswers` (uczący się może tak odpowiedzieć) i w `notePl`.

## 4. Najważniejsze poprawki

| plik | id | pole | było | jest | kategoria |
|---|---|---|---|---|---|
| slang-informal | lit | AT | …, `zajebisty` | usunięte | wulgaryzm |
| slang-informal | stoked | AT | `napalony na coś` | usunięte | konotacja seksualna |
| feelings-reactions-phrases | no-kidding | translation, ex0.pl | „bez jaj?” | „nie żartujesz?”, „Bez kitu!” | wulgaryzm |
| countries-nationalities | dutch | ex0 | *The Dutch are famous for being very direct.* | *The Dutch love their bikes…* | stereotyp narodowy |
| science | natural-sciences | AT | `nauki ścisłe` | usunięte | nauki ścisłe ≠ przyrodnicze |
| cruise-ferry | port-of-call | translation | „port docelowy” | „port zawinięcia” | błędny termin |
| elderly-care | respite-care | AT | `opieka zastępcza` | usunięte | w PL = piecza zastępcza |
| elderly-care | pension | AT | `renta` | usunięte | inne świadczenie |
| elderly-care | nightlight | translation | „lampka nocna” (= lampka przy łóżku) | „lampka do kontaktu” | fałszywy odpowiednik |
| jobs-professions | software-developer | AT | `deweloper oprogramowania` | usunięte | kalka |
| exams-tests | study-guide | AT | `ściągawka do nauki` | usunięte | ściągawka = cheat sheet |
| exams-tests | proctor | AT | `egzaminator` | usunięte | inna rola |
| exams-tests | test-score | ex0.en | *went up twenty points since…* | *has gone up … since my last attempt* | czas (since + present perfect) |
| exams-tests | pull-through | ex1.en | *pull through three more hours* | *I'll pull through somehow* | składnia (czasownik nieprzechodni) |
| exams-tests | lose-points | ex1.en | *under the word limit* | *shorter than the minimum word count* | logika |
| language-learning | what-do-you-call | ex1.pl | „Jak się nazywa kogoś, kto…” | „Jak się nazywa ktoś, kto…” | gramatyka PL |
| language-learning | consonant | ex0.en | *between the two consonants* of „street” | *between the consonants* | merytoryka (str = 3 spółgłoski) |
| math | probability | ex0.pl | „jeden do pięciu” | „jedna piąta” | 1:5 ≠ 1/5 |
| math | long-division | AT | `dzielenie w słupku` | `dzielenie pod kreską` | termin szkolny |
| math | solve-for-x | AT | `rozwiązać dla x` | usunięte | kalka |
| math | show-your-work | ex0.en | *full points* | *full credit* | kolokacja AmE |
| materials-objects | iron / velvet / concrete | AT/SYN | żeliwo / welur / cement | usunięte | inne materiały |
| materials-objects | rubber | ex1.en | *old rubber on the cushions* | *old rubber straps under the cushions* | logika |
| cycling | reinvent-the-wheel | AT | `odkrywać Amerykę` | `wyważać otwarte drzwi` | właściwy idiom PL |
| cycling | e-bike | AT | `elektryk` | usunięte | dwuznaczność |
| cruise-ferry | at-sea | AA | `sea day` | usunięte | inny termin |
| car-problems | stall | AT | `zgasnąć silnik` | usunięte | błędna konstrukcja |
| car-problems | coolant | ex0 | *coolant was almost empty* / „płyn był prawie pusty” | *coolant was really low* / „bardzo mało płynu” | logika |
| board-games-puzzles | on-a-roll | antonyms | `on a streak` (= synonim!) | `on a losing streak` | błąd |
| board-games-puzzles | clue | AT | `hasło` (w krzyżówce = odpowiedź) | usunięte | mieszanie znaczeń |
| board-games-puzzles | underdog | AT | `czarny koń` | usunięte | inne znaczenie (dark horse) |
| fast-food-takeaway | grab-a-bite | antonyms | `grab a bite to eat` | usunięte | to nie antonim |
| fast-food-takeaway | patty / filling / takeout | AT | kotlet mielony / pożywny / jedzenie z dowozem | usunięte | inne znaczenia |
| neighbors-community | yard-sale | AT | `pchli targ` | usunięte | flea market |
| babies | onesie / baby-carrier / baby-monitor | AT/AA | śpioszki / chusta, baby sling / monitor oddechu | usunięte | inne przedmioty |
| babies | adorable | ex0.pl | „najbardziej przesłodkie” | „najbardziej uroczy bobas” | pleonazm |
| shopping-mall | go-to-the-mall | ex0.pl | „córka z koleżankami idą” | „moja córka i jej koleżanki chodzą” | składnia PL |
| work-idioms | the-buck-stops-here | ex0.pl | lubi mówić, że „to on bierze…” | lubi mówić: „To ja biorę…” | cytat |
| work-idioms | step-up | ex1.pl | „żebyś wykazał się” (ta sama pracownica co w ex0) | „wykazała się” | spójność rodzaju |
| work-idioms | golden-handshake | translation, CEFR, note | „złoty spadochron”, C2 rare | „wysoka odprawa”, C1, nota BrE/AmE | |
| everyday-phrasal-verbs | tell-apart | ex1.en | *tell apart the real … from* | *tell the real … apart from* | szyk |
| slang-informal | buzzkill | AT | `psuj zabawa` | `psuja`, `coś, co psuje zabawę` | błąd PL |
| slang-informal | wack | AA | `wacky` | usunięte | inne słowo |
| describing-places | not-as-as | ex.pl | „był nie tak zatłoczony, jak” | „nie był tak zatłoczony, jak” | szyk PL |
| describing-places | airy | ex1.en | *the most airy* | *the airiest* | stopniowanie |

**IPA**: podwójny akcent główny w 5 złożeniach (scientific method/journal, reading comprehension, academic dishonesty, homeowners association). Poprawiłem też akcent w *safety precautions*, *pencils down*, *heads up* i *corner office*. Zmiany /ˈe-/ → /ˈæ-/ według Oxford US: parallel, Arabic, carousel, Samaritan. Nieakcentowane *for/to/as* zapisałem jako /fər tə əz/ (prepare for, be responsible for, look out for, be used for, close to, compared to, similar to, get around to, twice as, work as). Inne: *caught* /kɔːt/, *whatchamacallit* /ˈwɑːtʃ-/, *uh-huh* /əˈhʌ/. Kontrola końcowa: w 22 plikach nie ma już ɝ, ɚ ani ɛ.

**CEFR**: obniżyłem *prowler*, *pungent* i *golden handshake* (C2/rare → C1/less_common). Nie znalazłem rażących zaniżeń. Kilkanaście haseł C1, które pasowałyby do B2 (patrz §6), zostawiłem jako kwestię ocenną.

## 5. Odpowiedzi na prośby autorów

- **S11, wyjątki walidatora** (`chemist`, `jumper cables`, `real estate agent`, `get a flat`): walidator już ich nie zgłasza (0 ostrzeżeń). `chemist` z notą o AmE jest poprawny.
- **S12, IPA i CEFR w slang-informal, work-idioms i elderly-care**: sprawdzone wszystkie wpisy. Akcenty poprawiłem w §4. *bet*, *no cap*, *slay*, *rando* jako C1 są uczciwe dla uczącego się (rzadkie w podręcznikach, potoczne). *pungent*, *prowler* i *golden handshake* obniżyłem do C1.
- **Polskie odpowiedniki potoczne**:
  - „sztos” (*fire*), „wymiatać” (*crush it*, *killing it*) i „zarąbisty” (*dope*) to trafny, niewulgarny slang. Zostawione. Z AT usunąłem natomiast „zajebisty” i „napalony”.
  - „sypnąć plotkami” (*spill the tea*) brzmi lekko sztucznie. `translation` zmieniłem na „podzielić się plotkami”, a „sypnąć plotkami” i „dawaj, opowiadaj” (poprawiona literówka „dawać”) zostały w AT.
  - „wyjdź do ludzi” (*touch grass*) to dobry odpowiednik. W AT jest też „odklej się od ekranu”.
  - „szczyt w porze lunchu” (*lunch rush*) jest zrozumiały i poprawny. Zostawione.
  - „opieka wytchnieniowa” (*respite care*) to oficjalny polski termin (program rządowy). Poprawny; usunąłem tylko mylącą „opiekę zastępczą”.
  - „oświadczenie pro futuro” (*living will*) to poprawny polski termin prawniczy. Zostawione.
- **Ostrzeżenia o drugich znaczeniach** (shut up, lit, dope, hook up): obecne i poprawne. Wulgaryzmów w zdaniach EN nie ma. *that sucks* ma notę „unikaj w sytuacjach formalnych”, co wystarcza.
- **„zważyć się”** (prośba T2): w moim zakresie (everyday-phrasal-verbs) nie znalazłem tej formy w znaczeniu „zwarzyć się”.

## 6. Wątpliwości, których nie rozstrzygnąłem

- **CEFR o jeden poziom za wysoko (C1 → B2?)** w hasłach specjalistycznych lub idiomatycznych: control group, numerator/denominator, conjugate, cutting-edge, rigid, heavy-duty, upholstery, suspension, sail through/scrape by, hospice, wean, colic, stumped, ambiance, quaint, secluded, dignity, low-hanging fruit, pick someone's brain, read the room. To ocena, nie błąd.
- **`math`** zostawia stopy w zdaniach pomiarowych (area, diameter, radius, volume) zgodnie ze sceną amerykańskiego podwórka. Można je przeliczyć, jeśli koordynator woli spójność z T1.
- **Marki zgenerycyzowane**: *Meals on Wheels* (nazwa programu), *realtor* (znak towarowy NAR) w AA i SYN, *Allen key* (pierwotnie marka; w AmE częstsze *Allen wrench*), „farelka”. Zostawione jako słowa ogólne.
- **`homeowners association`**: AT „wspólnota mieszkaniowa” to przybliżenie (HOA dotyczy domów jednorodzinnych). Zostawione.
- **Identyczne tłumaczenia w jednym temacie** (ryzyko dwóch poprawnych odpowiedzi w zadaniu wyboru): *fussy* i *cranky* („marudny”), *off the clock* i *on the clock* (antonimy), *what a shame* i *what a pity* („jaka szkoda”), *get fired*, *get laid off* i *let go* („zostać zwolnionym” lub „zwolnić”), *catch you later* i *peace out* („na razie” lub „nara”). Ponawiam prośbę T3 do core-engine o pomijanie dystraktorów z identycznym `translation`.
- **`nice one`** jest bardziej brytyjskie (w AmE częściej samo *Nice!*). Zostawione, bo AA zawiera *nice!*.

## 7. Prośby do innych ról

- **data-pipeline / walidator**: (1) regułę, która zgłasza comma splice w `en`. Prosta heurystyka: `, (I|you|we|they|he|she|it|that|there)('s|'re|'m|'ll| is| are| was)` bez spójnika przed przecinkiem. W S11 i S12 to był najczęstszy błąd. (2) Ostrzeżenie dla `forms` czasowników i zwrotów, jeśli pierwszy człon nie jest formą bazową hasła (zgłaszała to już T1). (3) Opcjonalnie ostrzeżenie dla „Sorry” w `pl`.
- **topic-content (przyszłe shardy)**: piętra w USA przeliczać na polską numerację już w treści, a w `synonyms` i `natural` nie wpisywać BrE.
