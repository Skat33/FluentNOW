# Raport: english-qa, zakres QA-T4 (shardy S7 i S8)

Przejrzałem wszystkie 24 tematy z sekcji QA-T4, razem 1798 wpisów. W każdym wpisie sprawdziłem hasło, IPA, poziom CEFR, `frequency`, tłumaczenie, `acceptedTranslations` i `acceptedAnswers`, definicję, synonimy, `natural`, `forms`, notatkę oraz oba przykłady EN i PL razem z fokusami.

Wyniki kontroli:
- Wszystkie pliki przechodzą `validate-content.mjs --file`: 0 błędów, 0 ostrzeżeń.
- Walidacja całej bazy: 156 plików, 10 711 wpisów, 0 błędów, 0 ostrzeżeń.
- `build-index.mjs`: 142 tematy, 10 690 wpisów w tematach, 10 711 rekordów słownika.

Identyfikatorów wpisów nie zmieniałem. Nie uruchomiłem żadnego polecenia git.

Metoda była taka sama jak u T2. Narzędzia leżą w scratchpadzie `t4/`:
- `dump.mjs` tworzy kompaktowy widok każdego tematu;
- `fixes/<temat>.mjs` zawiera listę poprawek w formacie `[id, pole, wartość, kategoria]`;
- `apply.mjs` nanosi poprawki i sprawdza, czy `focusEn`/`focusPl` są podciągami zdań. Zapisuje JSON z wcięciem 2 spacji, w UTF-8, z LF, a log zmian (stara i nowa wartość każdego pola) prowadzi w `t4/log/<temat>.json`.

## 1. Statystyka

„Wpisy z poprawką” to poprawki merytoryczne; samo ujednolicenie IPA się do nich nie wlicza.

| plik | wpisów | wpisów z poprawką | % | zmienionych pól | ujednolicone IPA |
|---|---|---|---|---|---|
| movies-tv | 99 | 15 | 15,2% | 22 | 13 |
| music | 93 | 12 | 12,9% | 19 | 9 |
| books-reading | 84 | 14 | 16,7% | 21 | 14 |
| art-museum | 79 | 11 | 13,9% | 15 | 10 |
| hobbies-crafts | 78 | 13 | 16,7% | 22 | 11 |
| photography | 73 | 11 | 15,1% | 17 | 9 |
| video-games | 72 | 12 | 16,7% | 32 | 9 |
| football | 78 | 11 | 14,1% | 14 | 8 |
| concerts-festivals | 68 | 13 | 19,1% | 15 | 17 |
| theater | 69 | 14 | 20,3% | 25 | 6 |
| parties-celebrations | 72 | 11 | 15,3% | 24 | 13 |
| holidays-traditions | 70 | 9 | 12,9% | 11 | 16 |
| friendship | 71 | 5 | 7,0% | 6 | 5 |
| dating-relationships | 69 | 12 | 17,4% | 20 | 5 |
| wedding | 70 | 8 | 11,4% | 12 | 2 |
| parenting | 70 | 12 | 17,1% | 17 | 8 |
| arguments-conflict | 68 | 7 | 10,3% | 11 | 3 |
| giving-advice | 67 | 6 | 9,0% | 7 | 4 |
| storytelling | 69 | 7 | 10,1% | 15 | 3 |
| beauty-hairdresser | 78 | 10 | 12,8% | 16 | 2 |
| repairs-diy | 84 | 11 | 13,1% | 15 | 3 |
| utilities-bills | 72 | 9 | 12,5% | 13 | 6 |
| moving-house | 64 | 8 | 12,5% | 16 | 2 |
| garden-plants | 81 | 9 | 11,1% | 9 | 3 |
| **razem** | **1798** | **250** | **13,9%** | **394** | **181** |

**Zmienione pola według kategorii (394):**

| kategoria | pól |
|---|---|
| polskie tłumaczenia przykładów / `focusPl` / `translation` (PL) | 185 |
| `acceptedTranslations` / `acceptedAnswers` mieszające znaczenia (ACC) | 94 |
| przykłady EN: gramatyka, logika, naturalność (EN) | 52 |
| synonimy, `natural`, definicje, notatki, `forms` (DEF) | 26 |
| słownictwo BrE w polach AmE (AME) | 22 |
| IPA, pojedyncze błędne transkrypcje (IPA) | 8 |
| CEFR / frequency (CEFR) | 5 |
| nazwy marek (BRAND) | 2 |

Odsetek jest wyższy niż u T2 (4,2%) z dwóch powodów. Po pierwsze, liczę osobno każde pole, a zmiana zdania PL zwykle pociąga za sobą zmianę `focusPl`. Po drugie, ostro czyściłem `acceptedTranslations`/`acceptedAnswers`, w których było dużo wariantów o innym znaczeniu. Samych błędów, które uczący się mógłby zapamiętać (błędne EN, błędna polszczyzna, fałszywe tłumaczenia), było około 8% wpisów.

**Konwencja IPA (T1–T3).** Stosowałem styl Oxford Learner's US:
- /e/ zamiast /ɛ/;
- /ɜːr/ w sylabie akcentowanej, /ər/ w nieakcentowanej, bez ɝ/ɚ;
- /iː uː ɑː ɔː oʊ/;
- przed r: /ɪr er ʊr ɑːr ɔːr/;
- znak akcentu w wyrazach wielosylabowych.

Shardy różniły się konwencją:
- S7 wszędzie używał /ɛ/; zamieniłem je automatycznie na /e/.
- S8 używał /ɝː/; zamieniłem je na /ɜːr/.
- Razem ujednoliciłem IPA w 181 wpisach, także w IPA cytowanym w `notePl` (np. `record` /ˈrekərd/, `desert` /ˈdezərt/).

Kontrola automatyczna po zmianach: brak ɛ/ɝ/ɚ, brak brytyjskich dwugłosek /ɪə eə ʊə əʊ ɒ/, brak IPA bez rotyczności przy pisanym „r”, każde wielosylabowe IPA ma znak akcentu. Prośbę autora S8 o kontrolę IPA wyrywkowych haseł (`balayage`, `esthetician`, `officiant`, `kilowatt-hour`, `succulent`, `aphid`) sprawdziłem: wszystkie są poprawne.

Poprawiłem 8 błędnych transkrypcji:

| hasło | było | jest |
|---|---|---|
| `maternity leave` | /ˈmətɝːnəti liːv/ (akcent na złej sylabie) | /məˈtɜːrnəti ˌliːv/ |
| `paternity leave` | /pəˈtɝːnəti liːv/ | /pəˈtɜːrnəti ˌliːv/ |
| `how about` | /ˈhaʊ əˌbaʊt/ | /ˌhaʊ əˈbaʊt/ |
| `the other day` | /ði ˈʌðər deɪ/ | /ði ˌʌðər ˈdeɪ/ |
| `flip through` | /ˈflɪp θruː/ | /ˌflɪp ˈθruː/ |
| `fit through` | /ˈfɪt θruː/ | /ˌfɪt ˈθruː/ |
| `transfer service` | /ˌtrænsfɝː ˈsɝːvɪs/ (akcent czasownika na 1. sylabie) | /trænsˌfɜːr ˈsɜːrvɪs/ |
| `penalty shootout` | /ˈpenəlti ˈʃuːtaʊt/ (dwa akcenty główne) | /ˈpenəlti ˌʃuːtaʊt/ |

## 2. Najważniejsze poprawki

| plik | id | pole | było | jest | kategoria |
|---|---|---|---|---|---|
| wedding | best-man | notePl | świadkowie w USA „nie podpisują dokumentów jak w Polsce” | w wielu stanach świadek podpisuje dokumenty ślubu | merytoryka |
| storytelling | thats-another-story | e0.en | How I got out of the closet… | How I got out of the locked bathroom… | dwuznaczność („come out of the closet”) |
| repairs-diy | blown-fuse | e1.en | Old houses… still have blown fuses instead of breakers | In old houses…, a blown fuse is more common than a tripped breaker | logika zdania |
| repairs-diy | drywall | synonyms | plasterboard; sheetrock | wallboard | marka (Sheetrock) + BrE |
| parenting | diaper | acceptedTranslations | …; pampers | — | marka |
| parenting | stay-at-home-dad | acceptedAnswers | stay-at-home mom | — | mieszanie znaczeń |
| giving-advice | you-should / strongly-advise | acceptedAnswers | you shouldn't / strongly advise against | — | przeciwne znaczenie |
| arguments-conflict | you-always | acceptedAnswers | you never | — | przeciwne znaczenie |
| football | first-half | acceptedTranslations / acceptedAnswers | druga połowa / second half | — | inne hasło |
| movies-tv | catch-up-on | acceptedAnswers | catch up with | — | inne znaczenie (z osobą) |
| video-games | crash / freeze | translation, acc. | crash = „zawiesić się”, ans „freeze” | crash = „wysypać się”; freeze bez „zamarznąć” | rozdzielenie znaczeń |
| arguments-conflict | point-fingers | translation, e0.pl | wytykać (się) palcami | szukać winnych / obwiniać się nawzajem | PL fałszywy odpowiednik (wytykać palcami = wyśmiewać) |
| arguments-conflict | storm-off | translation | wyjść wściekłym | wyjść wściekły | PL przypadek |
| parties-celebrations | party-pooper | translation, przykłady | psuj zabawa, „być psujem zabawy” | psujący zabawę; „Nie psuj zabawy” | PL niepoprawny rzeczownik |
| wedding | bridesmaid | e0.pl | Wszystkie pięć druhen miało… | Każda z pięciu druhen miała… | PL składnia liczebnika |
| theater | curtain-call | e1.pl | Było czworo ukłonów | Aktorzy cztery razy wychodzili do ukłonów | PL liczebnik zbiorowy |
| photography | battery | e0.pl | wystarcza na około czterystu zdjęć | …czterysta zdjęć | PL przypadek |
| dating-relationships | single | acc., e1.pl | samotna; „samotnych znajomych” | wolny/wolna, singiel/singielka | mieszanie znaczeń (single ≠ samotny) |
| dating-relationships | clingy | translation | zaborczy | przylepny | mieszanie znaczeń (= possessive) |
| beauty-hairdresser | highlights / balayage | acceptedTranslations | baleyage | — / balejaż | błąd ortograficzny + inna technika |
| beauty-hairdresser | roots | acceptedTranslations | korzenie włosów | — | inne znaczenie |
| utilities-bills | the-power-went-out | translation | wyłączyli prąd | wysiadł prąd | PL sens (ktoś wyłączył vs awaria) |
| hobbies-crafts | yarn | acceptedAnswers / synonyms | wool | — | BrE / materiał ≠ włóczka |
| art-museum | coat-check | synonyms / natural | cloakroom | coatroom (cloakroom tylko w acceptedAnswers) | AmE |
| movies-tv | rerun | synonyms / natural | repeat | — | BrE |
| concerts-festivals | schedule | synonyms | timetable | — | BrE |
| football | yellow-card | acceptedAnswers / synonyms | booking | caution | BrE |
| football | field / coach / goalie / fan | natural | pitch / manager / goalkeeper / supporter | — | `natural` to nie bardziej potoczny odpowiednik |
| parenting | burp | przykłady PL | Nie zapomnij, żeby mu się odbiło | Nie zapomnij go odbić | PL naturalność |
| storytelling | cliffhanger | translation, przykłady | zawieszenie akcji / „zostawiać w zawieszeniu akcji” | zakończenie w napięciu / „urwać w najciekawszym momencie” | PL naturalność |
| video-games | headset | e0.en | Put on your headset; I can't hear you over the music | Put on your headset so I can hear you better | logika |
| video-games | graphics | e0/e1.en | so real…; lower the graphics | so realistic…; lower the graphics settings | EN kolokacja |
| music | play-by-ear | e0.en | she can play by ear almost anything | she can play almost anything by ear | EN szyk |
| music | catchy | e1.en | something more catchy | something catchier | EN stopniowanie |
| books-reading | romance-novel | e0.en | The romance novels are on the table by the door with pink covers | The romance novels with pink covers are on the table… | EN dwuznaczność |
| holidays-traditions | mothers-day | e0 | …isn't on a fixed date like in Poland | …isn't on a fixed date, unlike in Poland | EN/PL odwrócony sens |
| holidays-traditions | be-thankful-for | e0.en | said what they are thankful for | said what they were thankful for | EN następstwo czasów |
| photography | aperture | level / frequency | C2 rare | C1 less_common | CEFR |
| movies-tv | flop | level | C1 | B2 | CEFR |
| arguments-conflict | extend-an-olive-branch | level | C2 | C1 | CEFR (prośba S8) |
| giving-advice | top-tip | notePl / acceptedAnswers | — | dodano „pro tip” (AmE) | AmE |
| parenting | look-after | notePl | — | w AmE częściej „take care of / watch” | AmE |

Pozostałe poprawki są tego samego typu.
- **Usunięte warianty o innym znaczeniu** z `acceptedTranslations`: `wkrętarka` (drill), `godzina policyjna` (curfew), `wynagrodzenie` (reward), `ogródek` (gardening), `sztuka współczesna` (modern art), `złol`, `notowanie`, `kopia`, `z dedykacją`, `tekściarz`, `muzyczka`, `wodociąg`, `nocna taryfa`, `zaciemnienie`, `osoba towarzysząca` (significant other), `laurka`, `przekomarzać się` i podobne.
- **Usunięte błędne `acceptedAnswers`/`synonyms`**: `statue` przy sculpture, `outfit` przy costume, `mezzanine` przy balcony, `jack-o'-lantern` przy pumpkin, `dirt` przy mud, `stage dive` przy crowd-surf, `bauble` (BrE) i podobne.
- **Wygładzona polszczyzna**: kalki („co czyni go”, „biorąc pod uwagę wszystko”), szyk („przewiń do tyłu trochę”), aspekt i rodzaj („graliśmy” w gronie kobiet → „grałyśmy”), realia („Imię mojej kuzynki w napisach” → „Nazwisko”, „śmiech z offu” → „śmiech z puszki”, „wizytówki przy talerzach” → „winietki”).

## 3. Prośby autorów i wcześniejsze ustalenia

- **S7, „football”**: cała terminologia jest konsekwentnie amerykańska (soccer, field, cleats, tie, overtime, practice). Notatki BrE są poprawne. Usunąłem tylko BrE z pól `natural`/`synonyms` (pitch, booking, manager jako `natural`). Hasło `soccer` zachowuje `football` w `acceptedAnswers` i `synonyms`, bo temat dotyczy „football” poza USA, a notatka to wyjaśnia.
- **S7, święta PL/US**: realia są poprawne. Wigilia, pasterka, opłatek, święconka, lany poniedziałek, 1 listopada, Thanksgiving w czwarty czwartek listopada, Dzień Matki w USA w drugą niedzielę maja i w Polsce 26 maja. Poprawiłem tylko zdanie o Dniu Matki, które miało odwrócony sens.
- **S8, IPA i CEFR** (pkt 4 raportu S8): IPA sprawdzone w całości, poprawki opisuje §1. `extend an olive branch` zmieniłem z C2 na C1. Pozostałe wątpliwe poziomy (`ride or die`, `frenemy`, `cowlick`, `trip a breaker`, `budget billing`, `root rot`) mieszczą się w C1/B2 i zostawiłem je.
- **T2, literówka „zważy”**: w moim zakresie (`giving-advice`) grep znajduje wyłącznie „rozważyć/rozważać”, czyli formy poprawne.
- **Koordynator, warianty sklejone średnikiem**: w żadnym z 24 plików nie ma elementu `acceptedTranslations`/`acceptedAnswers` zawierającego „;”. Każdy element listy to jedna odpowiedź.

## 4. Wątpliwości, których nie rozstrzygnąłem

1. **CEFR o jeden poziom za wysoko (C1 zamiast B2)** w kilkudziesięciu hasłach. Przykłady:
   - S7: `gripping`, `skim`, `memoir`, `pastime`, `therapeutic`, `embroidery`, `viewfinder`, `brushstroke`, `perspective`, `symbolize`, `curator`, `candid`, `picture-perfect`, `upstage` (C2);
   - S8: `bicker`, `clash`, `storm off`, `escalate`, `at a loss`, `vivid`, `soulmate`, `honeymoon phase`, `growth spurt`, `sleep-deprived`, `childproof`, `pamper`, `updo`, `downsize`, `bittersweet`, `conserve`, `mulch`, `sow`, `prenup`, `stud finder`, `drywall`.

   To nie są rażące błędy. Warto je ujednolicić według korpusu w całej bazie, razem z listą T2.
2. **Hasła BrE-owe jako warianty akceptowane**: `bookshop`, `cloakroom`, `shin pads`, `bear in mind`, `moisturiser`, `to cut a long story short`, `gatecrash`. Zostawiłem je w `acceptedAnswers`, bo nie są błędem, a uczący się z europejskich podręczników tak odpowie. Nie ma ich w polach `synonyms`/`natural`.
3. **Format `forms`**: S7 zapisuje formy przez „;” (`watched; watching`), a S8 przez „–” z 3. os. l.poj. (`watches – watched – watched`). Poprawiłem dwa niekompletne wpisy w S8 (`stood – stood`, `swept – swept`, `took – taken`). Ujednolicenie całej bazy proponuję zrobić osobnym skryptem (por. T2 §4.2).
4. **Długie tłumaczenia opisowe** (`dzień, w którym włosy się nie układają`, `piosenka, która chodzi po głowie`, `przyjęcie dla przyszłej panny młodej`) są poprawne, ale nieporęczne w trybie przypominania. Zostawiłem je, bo w polszczyźnie nie ma krótszego ekwiwalentu.
5. **Ekwiwalent `the time of my life`**: tłumaczenie „najlepsza zabawa w życiu” pasuje słabo, naturalniej brzmi „bawić się najlepiej w życiu”. Zmieniłem tylko przykład, a `translation` zostawiłem.
6. **Stopnie Fahrenheita**: w przykładzie `crank up` dopisałem „Fahrenheita” w PL. W innych tematach może być więcej stopni F bez jednostki w PL.
