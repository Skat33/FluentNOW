# Raport: english-qa, zakres QA-T5 (shardy S9 + S10, 24 tematy)

Przejrzałem ręcznie wszystkie 24 tematy z sekcji QA-T5, razem 1516 wpisów. W każdym wpisie sprawdziłem hasło, IPA, CEFR, frekwencję, rejestr, tłumaczenie, definicję, `natural`, `forms`, synonimy, notatkę, `acceptedAnswers`, `acceptedTranslations` oraz oba przykłady EN/PL razem z fokusami. Tematy przeglądałem porcjami po 30–40 wpisów w kompaktowym widoku generowanym skryptem.

Poprawki nanosiłem skryptem Node (`scratchpad/t5/apply.mjs` + `fixes/<temat>.mjs`). Skrypt przed zapisem sprawdza, czy `focusEn`/`focusPl` są podciągami zdań, zapisuje JSON z wcięciem 2 spacji, w UTF-8 i z LF, a każdą zmianę loguje. Identyfikatorów wpisów nie zmieniałem. Poleceń git nie uruchamiałem.

- Po każdym pliku `validate-content.mjs --file`: 0 błędów, 0 ostrzeżeń. Wszystkie 24 pliki razem: `OK: plików 24, wpisów 1516, błędów 0, ostrzeżeń 0`.
- Na końcu `build-index.mjs`: 142 tematy, 10 690 wpisów w tematach, 10 711 rekordów słownika. Pełna baza `--errors-only`: 0 błędów. 26 ostrzeżeń dotyczy plików spoza mojego zakresu.
- Pełny dziennik zmian (było → jest dla każdego pola): `english-qa-T5-changes.md`.

## 1. Statystyka

| plik | wpisów | wpisów z poprawką merytoryczną | % | zmienionych pól | ujednolicone IPA |
|---|---|---|---|---|---|
| project-management | 74 | 8 | 10,8% | 12 | 4 |
| negotiations | 61 | 13 | 21,3% | 35 | 4 |
| presentations | 61 | 7 | 11,5% | 12 | 3 |
| marketing-sales | 62 | 14 | 22,6% | 19 | 3 |
| entrepreneurship | 61 | 13 | 21,3% | 26 | 3 |
| finance-accounting | 63 | 16 | 25,4% | 32 | 7 |
| law-contracts | 63 | 13 | 20,6% | 18 | 6 |
| government-offices | 62 | 13 | 21,0% | 17 | 9 |
| insurance | 60 | 12 | 20,0% | 25 | 1 |
| taxes | 61 | 9 | 14,8% | 18 | 1 |
| programming-it | 60 | 7 | 11,7% | 9 | 5 |
| artificial-intelligence | 61 | 6 | 9,8% | 14 | 3 |
| environment-climate | 71 | 18 | 25,4% | 26 | 3 |
| nature-landscape | 67 | 12 | 17,9% | 17 | 3 |
| natural-disasters | 63 | 16 | 25,4% | 25 | 9 |
| space-astronomy | 63 | 8 | 12,7% | 12 | 3 |
| farming-countryside | 62 | 21 | 33,9% | 27 | 2 |
| news-media | 63 | 9 | 14,3% | 13 | 6 |
| politics-elections | 63 | 9 | 14,3% | 14 | 5 |
| economy | 62 | 3 | 4,8% | 3 | 3 |
| history | 64 | 9 | 14,1% | 10 | 1 |
| city-life | 61 | 11 | 18,0% | 14 | 3 |
| volunteering-charity | 61 | 20 | 32,8% | 28 | 3 |
| religion-beliefs | 67 | 9 | 13,4% | 14 | 6 |
| **razem** | **1516** | **276** | **18,2%** | **440** | **96** |

Odsetek wypada wyżej niż u T2 (4,2%) i T3 (7,9%). Główny powód to `acceptedTranslations`/`acceptedAnswers`, które u autorów S9/S10 często dopisywały wyrazy pokrewne, ale o innym znaczeniu. Usunięcie pojedynczego takiego wariantu liczę jako poprawkę wpisu. Bez tej kategorii odsetek wynosi około 10%. Sama angielszczyzna była bardzo czysta: 25 wpisów z poprawką zdania EN na 1516.

**Zmienione pola według kategorii (440 pól):**

| kategoria | pól | wpisów |
|---|---|---|
| ACC: `acceptedTranslations`/`acceptedAnswers` mieszające znaczenia, BrE w AA | 145 | 136 |
| PL: tłumaczenia przykładów, `focusPl`, `translation` (kalki, rekcja, błędne terminy) | 173 | 116 |
| DEF: definicje, synonimy, `natural`, notatki | 42 | 34 |
| EN: gramatyka i naturalność zdań EN | 33 | 25 |
| CEFR / frekwencja / rejestr | 21 | 18 |
| AmE: forma brytyjska w polu amerykańskim | 17 | 13 |
| IPA ręcznie (akcent, błąd) | 5 | 5 |
| przykład niezgodny ze znaczeniem | 2 | 1 |
| nazwa marki | 1 | 1 |
| neutralność | 1 | 1 |

**IPA.** Stosowałem wspólną konwencję z T2/T3 (styl Oxford Learner's US):
- /e/ zamiast /ɛ/;
- /ɜːr/ w sylabie akcentowanej, /ər/ w nieakcentowanej, bez ɝ/ɚ;
- jeden akcent główny w złożeniach.

Pliki S9/S10 miały ɝː w 96 wpisach (97 pól, w tym jedna transkrypcja w `notePl` przy *convert*). Zamieniłem je skryptem na ɜːr. ɚ i ɛ w tych plikach nie występowały. Ręcznie poprawiłem:
- `tabloid`: /ˈtæbləɪd/ → /ˈtæblɔɪd/ (błędna samogłoska);
- podwójny akcent główny: `software engineer`, `volunteer appreciation`;
- akcent w złożeniach przymiotnik + rzeczownik: `humanitarian aid` → /hjuːˌmænɪˌteriən ˈeɪd/, `food insecurity` → /ˌfuːd ɪnsɪˈkjʊrəti/.

Kontrola automatyczna po zmianach nie znajduje:
- ɝ/ɚ/ɛ ani brytyjskich dwugłosek (trójgłoski /aɪə aʊə/ są poprawne);
- akcentowanego /ər/;
- wielowyrazowego IPA bez akcentu głównego;
- więcej niż jednego akcentu głównego.

Wyrywkowo sprawdziłem też hasła wskazane przez autorów: epicenter, magnitude, archaeologist, reincarnation, Hanukkah, the Quran, bodega, gentrification, walk-away point, withhold, per diem, net 30, W-2. Wszystkie są poprawne.

**Prośba koordynatora (średniki w listach).** Skrypt `splitsemi.mjs` nie znalazł w moich 24 plikach żadnego elementu `acceptedAnswers`/`acceptedTranslations` sklejonego średnikiem. Wszystkie warianty są osobnymi elementami tablic. Każdy nowy element, który dodałem, to jedna naturalna odpowiedź.

## 2. Najważniejsze poprawki

### Terminologia specjalistyczna (prośba autorów S9)

| plik | id | było | jest | uwaga |
|---|---|---|---|---|
| finance-accounting | liabilities | translation „pasywa” | „zobowiązania” + notatka | pasywa = zobowiązania + kapitał własny; błąd merytoryczny |
| finance-accounting | accounts-payable | „zobowiązania” | „zobowiązania wobec dostawców” | rozróżnienie od *liabilities* |
| finance-accounting | petty-cash | „drobna gotówka” | „kasa podręczna” | właściwy termin księgowy |
| finance-accounting | fiscal-year | AT „rok podatkowy” | usunięte | rok obrotowy ≠ rok podatkowy |
| entrepreneurship | equity | AT „kapitał własny” | usunięte | to inne znaczenie (bilansowe), a tu chodzi o udziały |
| insurance | policyholder | „ubezpieczony” | „ubezpieczający” (+ wariant „ubezpieczony”) | posiadacz polisy to w prawie polskim ubezpieczający |
| insurance | claim | „roszczenie” | „zgłoszenie szkody” | naturalny termin ubezpieczeniowy; przykłady przeredagowane |
| insurance | deductible | AT „franszyza” | usunięte (zostaje „franszyza redukcyjna”, „udział własny”) | samo „franszyza” to też franszyza integralna (inny mechanizm) |
| insurance | pre-existing-condition | AT „choroba współistniejąca” | usunięte; translation skrócone do „wcześniej istniejąca choroba” | współistniejąca = comorbidity |
| insurance | beneficiary | „głównego uposażonego” o żonie | „główną uposażoną” | „uposażony” jest poprawnym terminem; poprawiony tylko rodzaj |
| law-contracts | penalty | AT „grzywna”, AA „fine” | usunięte; `natural` = „late fee” | kara umowna ≠ grzywna (kara państwowa) |
| law-contracts | valid | AT „prawomocny” | usunięte | prawomocny = o wyroku |
| law-contracts | hearing | AT „przesłuchanie” | usunięte | inne znaczenie |
| law-contracts | loophole | def. „A small mistake in a law…” | „A gap in a law or rule that lets people legally avoid obeying it.” | precyzja |
| negotiations | walk-away-point | „punkt wyjścia z negocjacji” | „punkt rezygnacji” | „punkt wyjścia” znaczy po polsku „starting point”, czyli coś przeciwnego |
| negotiations | bottom-line | „absolutne minimum” (kupujący, „więcej nie zapłacimy”) | „nieprzekraczalna granica”; kwoty ujednolicone ze sceną (2,40 $) | sprzeczność logiczna w przykładzie i scenie |
| negotiations | concession | AT „koncesja” | usunięte | koncesja = zezwolenie |
| taxes | tax-evasion | AT „unikanie podatków” | usunięte | to *tax avoidance*; mieszało dwa hasła |
| government-offices | register | AT „zameldować” | usunięte | meldunek to inna instytucja |
| natural-disasters | emergency-alert | „alert ratunkowy” | „komunikat ostrzegawczy” (+ „alert RCB”) | „alert ratunkowy” nie funkcjonuje po polsku |
| volunteering-charity | food-insecurity | „niedożywienie z biedy” | „brak bezpieczeństwa żywnościowego” | niedożywienie = malnutrition |
| volunteering-charity | food-bank | AT „jadłodzielnia” | usunięte | jadłodzielnia to inna instytucja |

Terminy, które sprawdziłem i które są poprawne: „uposażony”, „franszyza redukcyjna/udział własny”, „likwidator szkód”, „okres karencji”, „rok obrotowy”, „należności/zobowiązania” (w AR/AP), „wezwanie do zapłaty”, „pełnomocnictwo”, „termin przedawnienia”, „stan klęski żywiołowej” (w notatce).

### Angielski i AmE

| plik | id | pole | było | jest |
|---|---|---|---|---|
| negotiations | lowball | e0 + def. | *They tried to lowball us with an offer of one fifty.* (dostawca „zaniża” cenę sprzedaży, co kupującemu się opłaca) | *They lowballed the price to win the contract, then added extra fees.*; def. „offer or quote a price that is unrealistically low” |
| finance-accounting | chase | e1 + notatka | *Can you chase the restaurant about the March invoice?* (BrE) | *Can you chase down the March payment…*; notatka o AmE *follow up on* |
| finance-accounting | company-card | AA | business card | usunięte (business card = wizytówka) |
| finance-accounting | revenue | AA/syn | income | usunięte (income ≠ revenue) |
| entrepreneurship | go-bust | notatka | — | „brzmi bardziej brytyjsko; w AmE *go under*, *go belly up*” |
| city-life | spoiled-for-choice | AA/notatka | spoilt for choice | usunięte; notatka, że idiom jest bardziej brytyjski |
| presentations | extension-cord | syn/AA/AT | power strip / listwa zasilająca | usunięte (inna rzecz; konsekwentnie z decyzją T2) |
| presentations | give-a-presentation | notatka | „Nie *make a presentation*” | *make a presentation* też jest poprawne |
| taxes | tax | e0 | *goes to tax* | *goes to taxes* |
| marketing-sales | competitor | e1 | *every competitor drink* | *every competitor's drink* |
| marketing-sales | catchy | e1 | *a slogan more catchy than…* | *a catchier slogan than…* |
| entrepreneurship | be-your-own-boss | e1 | *To be your own boss sounds great…* | *Being your own boss sounds great…* |
| farming-countryside | milk | e0 | *at five and at five* | *at five in the morning and five in the afternoon* |
| natural-disasters | trapped | e1 | *pulled an old man out who was trapped…* | *pulled out an old man who was trapped…* |
| politics-elections | reelected | e1 | *Hardly anyone on the council fails to get reelected.* | *Almost everyone on the council gets reelected.* |
| różne | open-source, back-end, inner-city, small-town | e* | przymiotnik złożony bez łącznika przed rzeczownikiem | z łącznikiem (zgodnie z własną notatką wpisu) |
| różne | plateaux, unspoilt, civilisation, artefact, burnt out, worshipping, advert | AA | formy BrE | usunięte / zamienione na AmE |
| artificial-intelligence | facial-recognition | AA | face ID | usunięte (nazwa marki) |

### Polszczyzna (wybrane)

| plik | id | było | jest |
|---|---|---|---|
| presentations | confident | starałem się brzmieć **pewnie siebie** | starałem się sprawiać wrażenie **pewnego siebie** |
| marketing-sales | competitor | **wszystkie spróbowaliśmy** | **spróbowaliśmy każdego z nich** (rekcja *spróbować czegoś*) |
| finance-accounting | company-card | **Lunchu** ze znajomymi nie można płacić | **Za lunch** ze znajomymi… |
| programming-it | tech-industry | …że **nigdy nie przestaje się uczyć** (podmiotem staje się branża) | …że **uczyć się trzeba przez cały czas** |
| entrepreneurship | growing-pains | „problemy wieku dorastania” | „choroby wieku dziecięcego” (idiom biznesowy) |
| entrepreneurship | startup-costs | **zaniżyłyśmy** koszty (celowo) | **nie doszacowałyśmy** kosztów |
| history | bc / ad | p.n.e.. / n.e.. | podwójna kropka usunięta |
| history | ahead-of-its-time | ciotecznababcia | cioteczna babcia |
| religion-beliefs | nun | **ciotka babci** (to inna osoba) | **cioteczna babcia** = *great-aunt* |
| natural-disasters | tear-off | **Dachówki** (*shingles*) | **Gonty** (amerykańskie *shingles*) |
| space-astronomy | light-years-ahead | **są o lata świetlne przed** tymi (kalka) | **wyprzedzają o lata świetlne** te… |
| negotiations | shake-on-it | „przybić na to” | „podać sobie ręce” (+ AT „przybić targu”) |
| politics-elections | landslide | **wygrał miażdżącym zwycięstwem** | **odniósł miażdżące zwycięstwo** |
| law-contracts | party | Obie strony muszą podpisać każdą **stronę** umowy | …każdą **kartkę** umowy |
| programming-it | it-support | rozmawiać **z sfrustrowanymi** | **ze sfrustrowanymi** |

### `acceptedTranslations`/`acceptedAnswers` mieszające znaczenia (wybrane z 136 wpisów)

- objective → „zadanie”; milestone → „etap” (kolizja z *phase*); capacity → „przepustowość, wydajność”; setback → „wpadka, przeszkoda” (kolizja z *roadblock*);
- break down → *break into*; leverage → *bargaining chip* (translation zmienione na „przewaga”); concession → „koncesja”; handout → „ulotka”;
- advertise → „ogłaszać”; quota → „limit”; objection → „sprzeciw”; pitch → „oferta”; landing page → „strona lądowania”;
- CFO → „główny księgowy”; quarter → *Q1, Q2*; paper trail → „ślad na papierze”; confidential → *private*, „tajny”;
- date of birth → *birthday*; certificate → „akt”; process → „przetworzyć”; official → „formalny”; permit → „przepustka”; resident → „rezydent”;
- mist → *fog*; meadow/pasture → *field/meadow*; field → „łąka”; dirt road → *gravel road*/„szutrówka”; fertilizer → *manure*; hen → „kwoka”; hayride → „kulig”;
- devastating → *devastated*; landslide (disasters) → *mudslide*/„lawina błotna”; storm surge → „cofka”; magnitude → „skala”;
- economy → „ekonomia”; boom → „koniunktura”; emperor → *empress*/„cesarzowa”; invade/independence/concede/censorship/homelessness → rzeczowniki lub inne części mowy;
- church → „cerkiew”; bar mitzvah → *bat mitzvah*; peasant → „wieśniak” (pejoratywne); make a difference → „robić różnicę” (kalka); fulfilling → „spełniający”; a blessing in disguise → „błogosławieństwo w przebraniu”.

### CEFR i frekwencja

- C2 → C1: valuation, bootstrap, power of attorney, statute of limitations, umbrella policy, proof of loss, depreciation, tax avoidance, holier-than-thou (+ rare → less_common). Wszystkie to standardowe terminy z prasy i życia codziennego w USA, a C2 zostawiam dla haseł literackich lub archaicznych.
- C1 → B2: living paycheck to paycheck (spójnie z decyzją T3), a blessing in disguise.
- Frekwencja rare → less_common: upcycle, undergrowth, nebula, batten down the hatches.
- Rejestr: nail it (slangowy → potoczny), creek (potoczny → neutralny; w AmE to zwykłe słowo), tabloid (potoczny → neutralny), upcycle i undergrowth (→ neutralny).
- Bez zmian, oceny uczciwe: walk-away point (C1, rare), withhold (C1), deliverable (C1), go to seed (C2, rare), splashdown (C1, rare).

### Neutralność (S10)

Tematy politics-elections, religion-beliefs i history są napisane neutralnie i równorzędnie. Nie ma w nich partii ani polityków z nazwy, ocen ani szczegółów przemocy. Wprowadziłem jedną zmianę, dla symetrii: *liberal* miał notatkę „w USA zwykle poglądy lewicowe”, a *conservative* żadnej. Dodałem do niego analogiczną notatkę „zwykle poglądy prawicowe”. Usunąłem też pejoratywne „wieśniak” z *peasant*. Idiom „raz na ruski rok” przy *once in a blue moon* zostawiłem: to standardowy frazeologizm polski, ale zob. wątpliwości.

## 3. Wątpliwości (nierozstrzygnięte)

1. **Zbiorcze tłumaczenia opisowe** zostawiłem tam, gdzie polski nie ma jednowyrazowego odpowiednika: outreach („działania pomocowe w terenie”), swing state („stan wahający się”), too close to call, nice-to-have („miły dodatek”), scoop (zmienione na „materiał na wyłączność”).
2. **Te same tłumaczenia w jednym temacie**, na przykład back down / back out („wycofać się”), wild / rugged („dziki”), comprehensive coverage („autocasco”, z notatką o różnicy). Działają poprawnie, ale grozi to dwiema poprawnymi odpowiedziami w ćwiczeniu z dystraktorami. Prośbę T3 do core-engine o pomijanie dystraktorów z identycznym `translation` podtrzymuję.
3. **„raz na ruski rok”** (*once in a blue moon*) to bardzo częsty polski frazeologizm, ale bywa odbierany jako etnicznie nacechowany. Neutralne warianty („bardzo rzadko”, „od święta”) są w AT. Decyzję, czy zmienić główne tłumaczenie, zostawiam koordynatorowi.
4. **„deweloper”, „elektryk”, „lumpeks”, „fucha”** to potoczne lub wieloznaczne polskie słowa. Usunąłem tylko „deweloper” przy *developer* (po polsku to firma budowlana). Pozostałe zostawiłem jako potoczne warianty akceptowane.
5. **Pojedyncze hasła S9/S10 zdublowane z innymi tematami**, na przykład *go live* (project-management i news-media, inne znaczenia) czy *landslide* (dwa znaczenia w dwóch tematach), mają poprawne notatki. Nie zmieniałem ich.
6. **CEFR haseł kulturowych USA** (W-2, 1099, DMV, yard sign, county fair) to ocena redakcyjna bez dostępu do słownika zewnętrznego.

## 4. Prośby

- **core-engine / ui-learning**: przy losowaniu dystraktorów pomijać hasła z identycznym `translation` (jak w raporcie T3).
- **Koordynator**: decyzja w sprawie „raz na ruski rok” (pkt 3.3).
