# Raport: english-qa, zakres QA-T1 (S1 + S2, 24 tematy)

## 1. Co zrobiono

Sprawdziłem każdy z **2025 wpisów** w 24 plikach `ios/FluentNOW/Resources/Content/topics/`: greetings-introductions, numbers-time, colors-shapes-sizes, family, personality, appearance, emotions, daily-routine, weather, clothes-fashion, small-talk, opinions-agreeing, airport, flight, hotel, train-travel, public-transport, driving, directions, sightseeing, beach-vacation, camping-hiking, border-immigration, car-rental.

Metoda:
- Każdy plik zrzucałem skryptem Node (w scratchpadzie, poza repo) do kompaktowego widoku: `term | IPA | pos | level | translation | AT | AA | DEF | forms | NOTE | 2× EN/PL z focus`. Czytałem go porcjami po 40–50 wpisów.
- Poprawki nanosiłem skryptem z łatkami. Każda operacja sprawdzała starą wartość, a plik zapisywał się dopiero wtedy, gdy wszystkie operacje przeszły. Format pozostał bez zmian: `JSON.stringify(…, null, 2)` + LF, UTF-8 bez BOM. Przed zmianami sprawdziłem, że ten format odtwarza każdy z 24 plików bajt w bajt.
- Wszystkie zmiany zapisałem w dzienniku (`changes.jsonl`: plik, id, pole, było, jest, kategoria). Na nim opierają się statystyki poniżej.
- Nie zmieniłem żadnego `id`. Nie uruchamiałem gita.
- Na koniec dla każdego pliku i całej bazy: `node ios/tools/validate-content.mjs` dał **OK: plików 156, wpisów 10711, błędów 0, ostrzeżeń 0**. Potem uruchomiłem `node ios/tools/build-index.mjs`: 142 tematy, 10690 wpisów w tematach, 10711 rekordów słownika.

### Konwencja IPA (uzgodniona z english-qa-T2)

Styl OALD US (General American): `iː uː ɑː ɔː oʊ`, akcentowane `ɜːr`, nieakcentowane `ər`, `ɑːr ɔːr ɪr er ʊr`, trójgłoski `aɪər eɪər`. Samogłoska DRESS to `/e/`, nie `ɛ`. Nie używamy `ɝ`/`ɚ`. Końcowe nieakcentowane `/i/` (happy). „your” w pozycji nieakcentowanej to `/jər/`. W zwrotach akcent główny pada na słowo nośne, a pozostałe akcentowane sylaby mają akcent poboczny `ˌ`. T1 trzymał się tej konwencji od początku. Wyjątki poprawiłem: jedno `ɝː`, kilkanaście zwrotów z dwoma akcentami głównymi, 10× `jʊr` → `jər` i jedno `/fəˈmɪliər/` → `/fəˈmɪljər/` (dla spójności między plikami).

## 2. Statystyka

Łącznie 581 zmian pól. Dotknięte zostały 452 wpisy (22,3%), z czego **223 wpisy (11,0%) miały błąd redakcyjny**. Pozostałe zmiany były mechaniczne: naprawa struktury list akceptowanych odpowiedzi i ujednolicenie pola `forms`.

### Zmiany wg kategorii

| kategoria | zmian pól | wpisów | opis |
|---|---|---|---|
| struktura `acceptedTranslations`/`acceptedAnswers` (mechaniczne) | 169 | 166 | sklejone pozycje `"a; b"`, pozycje z nawiasem `"padać (o deszczu)"` i pozycje z przecinkiem `"steward, stewardesa"` (patrz §3) |
| `forms` (mechaniczne, S2) | 107 | 107 | `checks in – checked in – checked in` → `check in – checked in – checked in`; 3 brakujące formy podstawowe |
| polskie tłumaczenia przykładów / `focusPl` | 120 | 70 | kalki, błędy fleksji, nienaturalny szyk, nieprzeliczone jednostki |
| `acceptedTranslations`/`acceptedAnswers` (merytoryczne) | 63 | 57 | mieszanie znaczeń, części mowy i innych haseł |
| IPA | 41 | 41 | `ɝ`, podwójny akcent główny, `jʊr`, akcent w czasownikach frazowych |
| CEFR | 38 | 37 | zawyżenia (C1 → B2, A2 → B1) |
| zdania angielskie | 21 | 19 | pytania zależne z szykiem pytania bez cudzysłowu, comma splice, „the city hall”, nienaturalne kolokacje |
| `register` / `forms` / `synonyms` | 16 | 16 | „slangowy” → „potoczny”, `politer` → `more polite`, błędny synonim |
| `translation` | 6 | 6 | „temperament” → „porywczość”, „manifest modowy”, „byłeś gdzieś ciekawym” |

### Odsetek wpisów z błędem redakcyjnym (bez zmian mechanicznych)

| plik | wpisy | z błędem | % | wszystkie dotknięte |
|---|---|---|---|---|
| greetings-introductions | 116 | 20 | 17,2% | 54 |
| numbers-time | 120 | 10 | 8,3% | 32 |
| colors-shapes-sizes | 113 | 12 | 10,6% | 18 |
| family | 94 | 11 | 11,7% | 27 |
| personality | 93 | 6 | 6,5% | 8 |
| appearance | 82 | 6 | 7,3% | 11 |
| emotions | 86 | 6 | 7,0% | 14 |
| daily-routine | 91 | 11 | 12,1% | 18 |
| weather | 89 | 8 | 9,0% | 16 |
| clothes-fashion | 100 | 8 | 8,0% | 21 |
| small-talk | 84 | 8 | 9,5% | 15 |
| opinions-agreeing | 94 | 8 | 8,5% | 8 |
| airport | 105 | 10 | 9,5% | 22 |
| flight | 89 | 11 | 12,4% | 24 |
| hotel | 86 | 11 | 12,8% | 20 |
| train-travel | 63 | 5 | 7,9% | 10 |
| public-transport | 61 | 4 | 6,6% | 13 |
| driving | 77 | 16 | 20,8% | 25 |
| directions | 65 | 10 | 15,4% | 17 |
| sightseeing | 63 | 6 | 9,5% | 10 |
| beach-vacation | 63 | 11 | 17,5% | 19 |
| camping-hiking | 62 | 7 | 11,3% | 11 |
| border-immigration | 63 | 9 | 14,3% | 20 |
| car-rental | 66 | 9 | 13,6% | 19 |
| **razem** | **2025** | **223** | **11,0%** | **452** |

Ocena ogólna: jakość jest dobra. Angielskie zdania przykładowe są prawie zawsze naturalne i osadzone w scenie. Nie znalazłem błędów w przedimkach, brytyjskiej pisowni ani nazw marek. Najwięcej usterek dotyczyło polskich tłumaczeń przykładów: kalk i nieprzeliczonych jednostek. Drugie miejsce zajmują list akceptowanych odpowiedzi.

## 3. Problemy systemowe (ważne dla kodu i pozostałych QA)

1. **Sklejone pozycje w `acceptedTranslations`** występowały tylko w S1: 107 wpisów, np. `"jak się czujesz; jak leci"` jako jeden element tablicy. `VocabularyGrader.polishAnswers` porównuje zapisane warianty w całości i nie dzieli ich na `; , /`. Takie pozycje były więc **martwe**: nikt nie wpisze średnika. Rozdzieliłem je na osobne elementy i usunąłem duplikaty. W pozostałych plikach całej bazy tego problemu nie ma (sprawdzone skryptem).
2. **Pozycje z nawiasem lub przecinkiem** w `acceptedTranslations` (S1 i S2, 57 pozycji), np. `"padać (o deszczu)"`, `"wpół do (następnej godziny)"`, `"steward, stewardesa"`. `answerKey` usuwa tylko etykiety `(AmE)`/`(BrE)`. Takiej pozycji nie dało się więc uznać, bo użytkownik musiałby wpisać nawias. Zamieniłem je na formy do wpisania (`padać`, `wpół do`, `steward` + `stewardesa`). Przecinki gramatyczne zostawiłem (`myślę, że`, `jaki ojciec, taki syn`). Dwa hasła wymagały przy tym zmiany `translation`, żeby walidator nadal widział rdzeń: `numbers-time.by` → „najpóźniej do”, `emotions.lucky` → „mający szczęście”.
3. **`forms` w S2** zaczynały się od formy 3. os. lp. (`cancels – canceled – canceled`). Zwykle zapis „X – Y – Z” czyta się jako bezokolicznik – czas przeszły – imiesłów. Ujednoliciłem do konwencji S1 (107 wpisów).
4. **Pytania zależne zapisane jak pytania bezpośrednie bez cudzysłowu** (S2), np. *I asked a woman how do I get to Main Street.* Uczący się zapamiętałby błędny szyk. Przepisałem je na mowę niezależną z cudzysłowem: 6 wpisów (directions, train-travel, beach-vacation, border-immigration).

## 4. Najważniejsze poprawki

| plik | id | pole | było | jest | kategoria |
|---|---|---|---|---|---|
| beach-vacation | tan | ex2.pl | „na mojej **opaliźnie**” | „na mojej **opaleniźnie**” | fleksja PL |
| family | close | ex2.pl | „Jestem **bliżej z babcią** niż z rodzicami.” | „Jestem bardziej zżyta z babcią…” | kalka PL |
| numbers-time | by | ex1.pl | „**Ostateczne slajdy potrzebuję**…” | „Potrzebuję ostatecznych slajdów…” | rząd przypadka |
| numbers-time | soon | ex2 | przykład na *as soon as* (inne wyrażenie) | nowy przykład na *soon* | zgodność z hasłem |
| numbers-time | a-few | acceptedAnswers | `a few, few` | `a few` | mieszanie znaczeń (few = niewiele) |
| numbers-time | a-couple-of | AT | `…, para` | usunięte | mieszanie znaczeń |
| greetings-introductions | ive-heard-so-much-about-you | ipa | `ˈhɝːd` | `ˈhɜːrd` | konwencja IPA |
| greetings-introductions | go-by | ipa | `/ˈɡoʊ ˌbaɪ/` | `/ˌɡoʊ ˈbaɪ/` | akcent czasownika frazowego |
| greetings-introductions | goodbye | AT | `pożegnać się, żegnać się` | `do zobaczenia` | część mowy |
| greetings-introductions | catch-up | AT | `pogadać, co słychać` | usunięte | inne znaczenie |
| family | pass-away | AT | `zmarł` | `odchodzić, umierać` | forma odmieniona zamiast hasła |
| family | like-father-like-son | AT | `jaki ojciec`, `taki syn` (osobno) | `jaki ojciec taki syn` | fragmenty uznawane jako odpowiedź |
| personality | temper | translation | „temperament” | „porywczość” | fałszywy odpowiednik |
| clothes-fashion | fashion-statement | translation | „manifest modowy” | „wyrazisty element stroju” | kalka |
| small-talk | been-anywhere-nice | translation | „byłeś gdzieś **ciekawym**” | „byłeś w jakimś fajnym miejscu” | błąd gramatyczny PL |
| colors-shapes-sizes | checkered | acceptedAnswers | `checkered, plaid` | `checkered, checked` | plaid ≠ checkered |
| appearance | redhead | acceptedAnswers | `redhead, red hair` | `redhead` | inne hasło |
| appearance | ugly | ex2.en | *My last blind date warned me I'd find him ugly* (nielogiczne) | *My friend warned me that my blind date was ugly…* | logika zdania |
| weather | every-cloud-has-a-silver-lining | ex1/ex2 | comma splice | dwukropek | interpunkcja EN |
| weather | expect | ex2.pl | „do pięciu centymetrów opadów” | „do pięćdziesięciu milimetrów deszczu” | jednostki |
| directions | how-do-i-get-to | ex2 | *I asked … how do I get to Main Street.* | *I asked …, "How do I get to Main Street?"* | szyk EN |
| directions | excuse-me | ex2.en | *the way to the city hall* | *the way to City Hall* | przedimek AmE |
| train-travel | is-this-seat-taken | ex2 | *I asked is this seat taken, and…* | *I asked, "Is this seat taken?" and…* | szyk EN |
| driving | traffic-light | ex1.pl | „Zatrzymaj się na sygnalizacji świetlnej” | „Zatrzymaj się na światłach” | naturalność PL |
| driving | u-turn | ex2.pl | „Nie można tu wykonać zawracania” | „Tu nie można zawracać” | naturalność PL |
| driving | crosswalk | ex2 | prawie kopia przykładu 1 | nowy przykład | różnorodność |
| driving | backseat-driver | ex1/ex2.pl | „Przestań być pasażerem, który poucza kierowcę” | „Przestań się mądrzyć z tylnego siedzenia” | opisowe → naturalne |
| hotel | concierge | AT | `konsjerż, portier` | `konsjerż` | portier = doorman |
| hotel | charge | ex2.pl | „Nie rozpoznaję tej opłaty” | „Nie wiem, skąd się wzięła ta opłata…” | kalka |
| car-rental | grace-period | translation | „okres karencji” | „okres tolerancji” | błędny termin (karencja ≠ tolerancja) |
| airport | miss | acceptedAnswers | `miss, miss out` | `miss` | inne znaczenie |
| airport | checked-bag, weigh, scale, weight-limit | ex.pl | „pięćdziesiąt funtów” itd. | „23 kilogramy” itd. | jednostki w zdaniu PL |
| flight | first-class | ex1.pl | „Zasłona … była zasłonięta” | „Zasłona oddzielająca pierwszą klasę była zaciągnięta” | tautologia |
| beach-vacation | beach / sandcastle | AT | `wybrzeże` / `babka z piasku` | usunięte | inne znaczenie |
| camping-hiking | blister | AT | `odcisk` | usunięte | odcisk ≠ pęcherz |
| border-immigration | denied-entry | AT | `nie wpuszczony` | `niewpuszczony` | ortografia PL |
| public-transport | stop-request | translation/AT | `przycisk „na żądanie”` | `przycisk przystanku na żądanie` | cudzysłów w odpowiedzi |

CEFR: obniżyłem 37 haseł zawyżonych głównie do C1, np. *matte, distinctive, heritage, black sheep, overprotective, unwind, wind down, binge-watch, strike up a conversation, on the contrary, object, food for thought, hit the nail on the head, heatstroke, rip current, fender bender, tailgate, right of way, confiscate, smuggle, deport, picturesque, off the beaten path* → B2. *agree on* podniosłem z A2 do B1. Nie znalazłem rażących zaniżeń.

## 5. Odpowiedzi na prośby autorów

- **S1, idiomy C1:** *rain cats and dogs* → „lać jak z cebra” (B2, poprawne). *goody two-shoes* → „świętoszek/grzecznisia” (poprawne). *shoot the breeze* → „gadać o niczym” (poprawne; rejestr zmieniony ze „slangowy” na „potoczny”).
- **S2, IPA zwrotów wielowyrazowych:** przejrzane wszystkie. Poprawione akcenty: *safety demonstration, ears pop, come to a complete stop, breakfast included, continental breakfast, doesn't work*. Poza tym `jʊr` → `jər`.
- **S2, opisowe równoważniki:** *backseat driver*: przykłady przepisane na naturalne („mądrzyć się z tylnego siedzenia”, „pouczać kierowcę”), `translation` zostało. *outdoorsy*: przykład 1 przepisany („wielkim miłośnikiem przyrody”), do AT dodane „kochający przyrodę”. *uptown*: zostawione bez zmian, bo polszczyzna nie ma jednowyrazowego odpowiednika (patrz §6).
- **Jednostki:** w zdaniach, które nie mówią o samej skali, przeliczyłem funty, stopy, cale opadów i °F na kg, metry, mm i °C (9 przykładów). Zdania o samej skali (inch, foot, pound, Fahrenheit, mph) zostawiłem.

## 6. Wątpliwości, których nie rozstrzygnąłem

- `translation` opisowe bez naturalnego odpowiednika zostały: *uptown* („w kierunku północnej części miasta”), *people person*, *wet blanket*, *team player*, *carpool*, *sibling* („brat lub siostra”), *walking distance*. Przykłady poprawiłem tam, gdzie brzmiały sztucznie.
- *tide* ma w AT „przypływ” i „odpływ”. To węższe znaczenia, ale w praktyce tak się tłumaczy, więc zostawiłem.
- *validate* (kasować bilet) w scenie amerykańskiego pociągu: kasowniki to raczej realia europejskie. Treść zostawiłem.
- Słownictwo „Amerykanin w Polsce/USA”: niektóre polskie przykłady używają nazw własnych i realiów USA (Lincoln High, Park Street). Uznałem to za celowe.
- Kategorie 'en' i 'pl' w statystyce są przybliżone. Wymiana całego przykładu liczy się jako jedna zmiana „en”, choć obejmuje też zdanie PL.

## 7. Prośby do innych ról

- **data-pipeline / walidator:** dodać regułę `accepted-format`, która zgłasza elementy `acceptedTranslations`/`acceptedAnswers` zawierające `;`, `(`, `)`, `„”"` lub `, ` między dwoma pojedynczymi słowami. Grader nie dzieli zapisanych wariantów, więc takie pozycje nie działają. Druga reguła: `forms` dla czasowników powinno zaczynać się od formy hasła.
- **english-qa T2–T6:** sprawdzić u siebie te same wzorce, czyli §3 pkt 2–4. Problem ze średnikami dotyczył tylko S1, ale nawiasy i pytania zależne bez cudzysłowu mogą wystąpić gdzie indziej. Mój skrypt kontrolny opisałem w §1. Mogę go udostępnić.
- **core-engine (opcjonalnie):** rozważyć, żeby `polishAnswers` dzielił także zapisane `acceptedTranslations` na `;` i ignorował nawiasy objaśniające. To zabezpieczenie na przyszłe treści generowane przez AI.

## 8. Testy i wyniki skryptów

- `node ios/tools/validate-content.mjs --file <plik>` po każdym z 24 plików: 0 błędów, 0 ostrzeżeń.
- `node ios/tools/validate-content.mjs` (cała baza): `OK: plików 156, wpisów 10711, błędów 0, ostrzeżeń 0`.
- `node ios/tools/build-index.mjs`: `topics/index.json` (206.9 KB), `dictionary-index.json` (1334.7 KB), 142 tematy, 10690 wpisów, 10711 rekordów.
- Kontrole skryptem w zakresie T1: brak pozycji AT/AA ze średnikiem, nawiasem lub cudzysłowem; brak `ɝ ɚ ɛ ɒ əʊ`; brak `a` przed samogłoską i `an` przed spółgłoską (2 trafienia, *a U-turn* i *an SUV*, są poprawne); brak podwójnych spacji i spacji przed przecinkiem.
