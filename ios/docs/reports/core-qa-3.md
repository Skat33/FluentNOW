# Raport: english-qa, słownik rdzeniowy — core-qa-3 (shardy C05 + C06)

Zakres: `ios/FluentNOW/Resources/Content/core/core-c05.json`, `core-c06.json`. Innych plików nie zmieniałem. Nie uruchamiałem `build-index.mjs`, `build-core-master.mjs` ani gita.

## 1. Wynik

| | C05 | C06 | razem |
|---|---|---|---|
| wpisy przejrzane ręcznie (przed korektą) | 490 | 566 | 1056 |
| przykłady przejrzane | 1745 | 1890 | 3635 |
| wpisy z co najmniej jedną poprawką | 76 | 42 | 118 |
| **odsetek wpisów z błędem** | **15,5%** | **7,4%** | 11,2% |
| zmienione pola (operacje) | 95 | 45 | 140 |
| dopisane znaczenia (nowe wpisy) | 1 | 2 | 3 |
| wpisy po korekcie | 491 | 568 | 1059 |

Walidator po korekcie: `validate-content.mjs --file core-c05.json` → **OK: wpisów 491, błędów 0, ostrzeżeń 0**; `--file core-c06.json` → **OK: wpisów 568, błędów 0, ostrzeżeń 0** (duplikaty przykładów sprawdzone względem całej bazy).
Format plików zachowany: poprawki nanoszone skryptem na tekście pliku (zamiana dokładnego fragmentu w obrębie bloku wpisu, sprawdzane 1 trafienie). Liczba zmienionych linii zgadza się z liczbą operacji (C05: 93 linie zmienione + 26 dopisanych; C06: 45 zmienionych + 52 dopisane). Identyfikatory istniejących wpisów bez zmian.

## 2. Poprawki według kategorii (liczba wpisów)

| kategoria | C05 | C06 | przykłady |
|---|---|---|---|
| polskie tłumaczenia (kalki, rekcja, szyk, interpunkcja, „Pan” z wielkiej litery w dialogu) | 29 | 19 | *Swędzi mnie plecy* → *Swędzą mnie plecy*; *stanowcze stanowisko* → *zdecydowanie sprzeciwił się*; *rodzona krew* → *moja rodzina*; *inwazja szarańczy* (grasshoppers) → *koników polnych*; *Nie potwierdziła ani nie zaprzeczyła plotkom* (rekcja) → *Ani nie potwierdziła plotek, ani im nie zaprzeczyła* |
| `acceptedTranslations` mieszające znaczenia / części mowy / błędne słowa | 29 | 14 | *hawk* → bez „sokół”; *risky* → bez „hazardowy”; *mysterious* → bez „tajemnie”; *sword* → bez „szabla/szpada”; *injection* → bez „szczepienie”; *confess* → bez „spowiadać się”; *exotic* → bez nieistniejącego „dalekobrzeżny”; *inevitably* → bez „nieuniknienie/nieodwołalnie”; *credibility* → bez „prawdopodobieństwo”; *authority* (władza) → bez „autorytet” (to osobny wpis authority-3) |
| EN — gramatyka i naturalność | 11 | 10 | *I was positively surprised* (polonizm) → *Most of the reviews spoke positively…*; *Tickets for children aged twelve and onwards* → *From now onwards…*; *Was the whole building burned down?* → *Did the whole building burn down?*; *while it's renovated* → *while it's being renovated*; *Is wind power more renewable than solar?* (bez sensu) → przykład o przedłużaniu prawa jazdy |
| przykład nie w znaczeniu hasła | 7 | 1 | *bullet* (bulletproof vest, bullet train, bullet points) → 3 nowe zdania o „kuli”; *turn to page 25* we wpisie „zwrócić się do (o pomoc)”; *break out of jail* we wpisie „wybuchnąć”; *put my name down* we wpisie „odłożyć”; *alien life* we wpisie „obcy (nieznany)”; *bring in tourists* we wpisie „przynosić dochód”; *Pardon my French* bez przekleństwa; *optical fiber* (AmE: fiber-optic) |
| EN — standard amerykański | 3 | 0 | *power cut* → *power outage*; *conditional place at the university* (BrE) → *conditional admission*; paszport *out of date* (AmE: expired) → przykład z mapami w GPS |
| IPA | 6 | 0 | *unlock* /ˌʌnˈlɑːk/ → /ʌnˈlɑːk/, *outstanding* → /aʊtˈstændɪŋ/, *on board* → /ˌɑːn ˈbɔːrd/, *go with* → /ˈɡoʊ ˌwɪð/ (ujednolicenie z bazą); *go for* /fɔːr/ → /fər/ (forma słaba); *time-consuming* — usunięty akcent poboczny po głównym |
| `forms` | 2 | 1 | *useless*, *unkind* → stopniowanie z more/most; *competence* → (niepoliczalny) |
| `notePl` | 1 | 0 | *for good* — notatka myląca („nie znaczy na dobre”) przeredagowana |

## 3. Najważniejsze poprawki

1. **bullet** (C05): 3 z 4 przykładów nie ilustrowały znaczenia „kula” (kamizelka kuloodporna, szybki pociąg, wypunktowanie) — uczący się nauczyłby się złego skojarzenia; nowe zdania + kolokacje.
2. **positively** — *positively surprised* to polonizm/germanizm; native powie *pleasantly surprised*.
3. **onwards** — *children aged twelve and onwards* jest niegramatyczne (poprawnie: *and up/over*).
4. **turn to**, **break out**, **put down**, **bring in-2**, **alien** — przykłady z innym znaczeniem niż hasło; wymienione i oczyszczone `acceptedTranslations`.
5. **Pardon my French** użyte bez wulgaryzmu (zdanie nienaturalne) → typowe *Pardon? Could you say that again…*
6. Błędne polskie słowa w AT: *dalekobrzeżny*, *nieuniknienie*, *jak by*, *nie śpiący* (→ *niespiący*), oraz fałszywe odpowiedniki (*hawk* = „sokół”, *risky* = „hazardowy”, *radar* = „niezauważony”).
7. Polskie zdania z błędną rekcją lub szykiem: *Swędzi mnie plecy*, *brakuje dramatycznie*, *Nie potwierdziła ani nie zaprzeczyła plotkom*, *Proszę daj mi znać* (przecinek), *byli za głośno*.
8. IPA tego samego hasła w tym samym znaczeniu ujednolicone z bazą (*unlock*, *outstanding*, *on board*, *go with*). Pozostałe różnice IPA względem bazy są zasadne (inna część mowy: *refund, refill, impact, insult, discharge, upgrade, overlap, overhead*; inne znaczenie: *tear up* /ter/ vs /tɪr/; *used* /juːst/ w *be used to*).

## 4. Dopisane znaczenia (format §6)

| plik | id | hasło | znaczenie | CEFR | przykłady |
|---|---|---|---|---|---|
| C05 | `core.punch-2` | punch (rzeczownik) | cios | B2 | 4 (w tym przeczenie), kolokacje *throw a punch, pack a punch* |
| C06 | `core.alert-3` | alert (rzeczownik) | alert, ostrzeżenie, powiadomienie | B2 | 4 (w tym pytanie), *weather/text alert, on high alert* |
| C06 | `core.slash-2` | slash (rzeczownik) | ukośnik | B2 | 4 (w tym pytanie), AmE *singer slash actress* |

Sprawdziłem w `dictionary-index.json` pozostałe ważne znaczenia haseł z obu shardów (np. *spoil* rozpieszczać, *crush* zauroczenie, *pinch* szczypta, *gross* brutto, *conserve* oszczędzać, *allowance* kieszonkowe, *thoughtful* troskliwy, *rotten* zgniły, *unconscious* nieprzytomny, *quit* rzucić pracę, *valid* ważny, *bully* łobuz, *sip* sączyć) — są już w bazie tematów, więc ich nie dublowałem.

## 5. CEFR

Bez zmian poziomów. Rozkład w obu shardach jest uczciwy (C05: B1/B2; C06: B2/C1). Skrypt porównał poziomy z wpisami bazy o tym samym haśle, części mowy i wspólnym tłumaczeniu. Wszystkie różnice dotyczą innych znaczeń (np. *fraction* C1 „mała część” wobec *math.fraction* B1 „ułamek”; *bitter* B2 „rozgoryczony” wobec A2 „gorzki”), więc są zasadne.

## 6. Wątpliwości (nierozstrzygnięte)

- *fraction* „ułamek (mała część)” C1: *a fraction of the price* można by obniżyć do B2. Zostawiłem ocenę autora.
- *breakdown* (awaria): w AT jest „załamanie” (*breakdown of talks*), które pokrywa się z *breakdown-2* „załamanie (nerwowe)”. Zostawiłem, bo obie formy są poprawne w swoich zdaniach.
- *sniff* „pociągać nosem”: jeden przykład dotyczy wąchania (*sniffed the milk*), a „wąchać” jest w AT. To bliskie znaczenie, więc zostawiłem.
- *pity* / *shame* (oba „szkoda”) oraz *once in a while* / *now and then* / *every now and then* mają identyczne lub bardzo bliskie tłumaczenia. To prawdziwe synonimy, ale przy losowaniu dystraktorów może to dać dwie poprawne odpowiedzi (prośba z raportu T3 nadal aktualna).
- „Państwo” / „Pana” z wielkiej litery zostawiłem w dwóch komunikatach pisemnych (*get in touch*, *at your convenience*), bo to styl korespondencji. W dialogach zmieniłem na małą literę, zgodnie z bazą (233 × „pan” w tematach).
- *dissertation*, *postgraduate*, *quarrel*, *fetch*, *compulsory* mają już w `notePl` uwagi o rejestrze BrE/AmE. Przykłady zostawiłem.

## 7. Narzędzia (scratchpad `cqa3/`, poza repozytorium)

`view.mjs` (widok kompaktowy porcjami po 40 wpisów), `ipachk.mjs` (IPA wobec całej bazy i konwencji), `pat.mjs` (wzorce: a/an, BrE, podwójne spacje, długość, pytajnik PL/EN, AT bez tłumaczenia), `cefr.mjs` (spójność CEFR), `apply.mjs` (poprawki tekstowe w obrębie bloku wpisu + dziennik), `fx05_*.json`, `fx06_*.json` (listy poprawek), `table.mjs` (tabela poniżej).

## 8. Pełna tabela zmian

| plik | id | pole | było | jest | kategoria |
|---|---|---|---|---|---|
| c05 | core.do-research | tekst | Zrobiłeś jakiekolwiek rozeznanie przed kupnem tego samochodu? | Zrobiłeś jakieś rozeznanie przed kupnem tego samochodu? | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.do-research | przykład | "focusPl": "Zrobiłeś jakiekolwiek rozeznanie" | "focusPl": "Zrobiłeś jakieś rozeznanie" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.up-to-date | przykład | "pl": "Jak jesteś na bieżąco z wiadomościami?", "focusEn": "stay up to date", "focusPl": "jesteś na bieżąco" | "pl": "Jak dbasz o to, żeby być na bieżąco z wiadomościami?", "focusEn": "stay up to date", "focusPl": "być na bieżąco" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.out-of-date | przykład | { "en": "My passport is out of date, so I need to renew it.", "pl": "Mój paszport stracił ważność, więc muszę go odnowić.", "focusEn": "o… | { "en": "The maps on my GPS are out of date, so the new highway isn't there.", "pl": "Mapy w mojej nawigacji są nieaktualne, więc nie ma … | EN – AmE |
| c05 | core.out-of-date | AT | ["nieaktualny", "przestarzały", "nieważny", "przeterminowany"] | ["nieaktualny", "przestarzały", "niemodny", "zdezaktualizowany"] | acceptedTranslations |
| c05 | core.believe-it-or-not | AT | ["wierz lub nie", "wierz albo nie", "wierzcie lub nie", "uwierz mi", "uwierzcie"] | ["wierz lub nie", "wierz albo nie", "wierzcie lub nie", "wierzcie albo nie", "uwierzcie"] | acceptedTranslations |
| c05 | core.over-and-over | tekst | aż była perfekcyjna. | aż wychodziła jej perfekcyjnie. | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.awake | tekst | "nie śpiący" | "niespiący" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.energetic | przykład | "pl": "Nie czuję się dziś zbyt pełen energii.", "focusEn": "energetic", "focusPl": "pełen energii" | "pl": "Nie mam dziś za bardzo energii.", "focusEn": "energetic", "focusPl": "energii" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.mysterious | AT | ["tajemniczy", "zagadkowy", "niewyjaśniony", "tajemnie"] | ["tajemniczy", "zagadkowy", "niewyjaśniony"] | acceptedTranslations |
| c05 | core.risky | AT | ["ryzykowny", "niebezpieczny", "hazardowy"] | ["ryzykowny", "niebezpieczny", "ryzykancki"] | acceptedTranslations |
| c05 | core.useless | forms |  | more useless – most useless | forms |
| c05 | core.unlock | ipa | /ˌʌnˈlɑːk/ | /ʌnˈlɑːk/ | IPA |
| c05 | core.aloud | AT | ["na głos", "głośno", "na głos czytać"] | ["na głos", "głośno"] | acceptedTranslations |
| c05 | core.unkind | forms | unkinder – unkindest | more unkind – most unkind | forms |
| c05 | core.willing | tekst | Czy jest Pan skłonny | Czy jest pan skłonny | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.pardon | tekst | chyba siedzi Pan na moim | chyba siedzi pan na moim | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.pardon | przykład | { "en": "Pardon my French, but that was a terrible movie.", "pl": "Wybaczcie mój język, ale to był okropny film.", "focusEn": "Pardon my … | { "en": "Pardon? Could you say that again a little more slowly?", "pl": "Słucham? Mógłby pan powtórzyć trochę wolniej?", "focusEn": "Pard… | przykład nie w tym znaczeniu |
| c05 | core.approximate | tekst | Może mi Pan podać | Może mi pan podać | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.identification-2 | tekst | Ma Pan przy sobie | Ma pan przy sobie | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.mineral | tekst | Woli Pani wodę | Woli pani wodę | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.activate | AT | ["aktywować", "aktywizować", "uruchomić", "uruchamiać", "włączyć", "włączać"] | ["aktywować", "uruchomić", "uruchamiać", "włączyć", "włączać"] | acceptedTranslations |
| c05 | core.alien | przykład | { "en": "Do you think alien life exists on other planets?", "pl": "Myślisz, że na innych planetach istnieje obce życie?", "focusEn": "ali… | { "en": "The custom of tipping is alien to people from some countries.", "pl": "Zwyczaj dawania napiwków jest obcy ludziom z niektórych k… | przykład nie w tym znaczeniu |
| c05 | core.alien | tekst | alien to someone; an alien culture; alien life | alien to someone; an alien culture; an alien concept | przykład nie w tym znaczeniu |
| c05 | core.alien | AT | ["obcy", "dziwny", "nieznany", "pozaziemski"] | ["obcy", "dziwny", "nieznany", "obcy komuś"] | acceptedTranslations |
| c05 | core.bullet | przykład | { "en": "All the police officers at the event wore bulletproof vests.", "pl": "Wszyscy policjanci na imprezie mieli na sobie kamizelki ku… | { "en": "The old soldier still has a bullet in his leg from the war.", "pl": "Stary żołnierz wciąż ma w nodze kulę z czasów wojny.", "foc… | przykład nie w tym znaczeniu |
| c05 | core.bullet | przykład | { "en": "We took the bullet train from Tokyo to Kyoto.", "pl": "Pojechaliśmy szybkim pociągiem z Tokio do Kioto.", "focusEn": "bullet tra… | { "en": "The museum displays bullets and helmets from the Civil War.", "pl": "W muzeum wystawiane są kule i hełmy z czasów wojny secesyjn… | przykład nie w tym znaczeniu |
| c05 | core.bullet | przykład | { "en": "Can you put the main ideas in bullet points?", "pl": "Możesz wypunktować najważniejsze pomysły?", "focusEn": "bullet points", "f… | { "en": "Did the police find any bullets at the scene?", "pl": "Czy policja znalazła na miejscu jakieś kule?", "focusEn": "bullets", "foc… | przykład nie w tym znaczeniu |
| c05 | core.bullet | tekst | bulletproof vest; bullet train; bullet point | bulletproof vest; bullet hole; bullet point | przykład nie w tym znaczeniu |
| c05 | core.classify | przykład | "pl": "Naukowcy klasyfikują zwierzęta w różne grupy.", "focusEn": "classify", "focusPl": "klasyfikują" | "pl": "Naukowcy dzielą zwierzęta na różne grupy.", "focusEn": "classify", "focusPl": "dzielą" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.conditional | przykład | { "en": "She got a conditional place at the university.", "pl": "Dostała warunkowe miejsce na uniwersytecie.", "focusEn": "conditional", … | { "en": "She got conditional admission to the university.", "pl": "Została warunkowo przyjęta na uniwersytet.", "focusEn": "conditional",… | EN – AmE |
| c05 | core.conditional | AT | ["warunkowy", "zależny od", "uzależniony od"] | ["warunkowy", "warunkowo", "zależny od", "uzależniony od"] | acceptedTranslations |
| c05 | core.disability | AT | ["niepełnosprawność", "niepełnosprawności", "upośledzenie", "trudności"] | ["niepełnosprawność", "niepełnosprawności"] | acceptedTranslations |
| c05 | core.enormously | przykład | { "en": "Didn't your English improve enormously last year?", "pl": "Czy twój angielski nie poprawił się w zeszłym roku ogromnie?", "focus… | { "en": "Has the city changed enormously since you were a kid?", "pl": "Czy miasto ogromnie się zmieniło, odkąd byłeś dzieckiem?", "focus… | EN – gramatyka/naturalność |
| c05 | core.freely | AT | ["swobodnie", "wolno", "otwarcie", "bez ograniczeń", "za darmo"] | ["swobodnie", "otwarcie", "bez ograniczeń", "bez przeszkód"] | acceptedTranslations |
| c05 | core.hawk | AT | ["jastrząb", "sokół"] | ["jastrząb"] | acceptedTranslations |
| c05 | core.historically | przykład | "pl": "Historycznie ta dzielnica była domem wielu polskich imigrantów.", "focusEn": "Historically", "focusPl": "Historycznie" | "pl": "Dawniej w tej dzielnicy mieszkało wielu polskich imigrantów.", "focusEn": "Historically", "focusPl": "Dawniej" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.historically | AT | ["historycznie", "w przeszłości", "z historycznego punktu widzenia", "tradycyjnie"] | ["historycznie", "w przeszłości", "dawniej", "z historycznego punktu widzenia", "tradycyjnie"] | acceptedTranslations |
| c05 | core.injection | AT | ["zastrzyk", "iniekcja", "szczepienie"] | ["zastrzyk", "iniekcja"] | acceptedTranslations |
| c05 | core.marker | AT | ["marker", "flamaster", "pisak", "zakreślacz"] | ["marker", "flamaster", "pisak"] | acceptedTranslations |
| c05 | core.onwards | przykład | { "en": "Tickets for children aged twelve and onwards cost the same as adult tickets.", "pl": "Bilety dla dzieci od dwunastego roku życia… | { "en": "From now onwards, all our meetings will start at nine sharp.", "pl": "Od teraz wszystkie nasze spotkania będą się zaczynać punkt… | EN – gramatyka/naturalność |
| c05 | core.oral | przykład | { "en": "Is this medicine oral, or is it an injection?", "pl": "Ten lek jest doustny czy w zastrzyku?", "focusEn": "oral", "focusPl": "do… | { "en": "Is this an oral medication, or is it an injection?", "pl": "Czy to lek doustny, czy w zastrzyku?", "focusEn": "oral", "focusPl":… | EN – gramatyka/naturalność |
| c05 | core.physically | przykład | "pl": "Czy trzeba być osobiście, żeby podpisać dokumenty?", "focusEn": "physically present", "focusPl": "być osobiście" | "pl": "Czy trzeba stawić się osobiście, żeby podpisać dokumenty?", "focusEn": "physically present", "focusPl": "stawić się osobiście" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.positively | przykład | { "en": "I was positively surprised by the hotel.", "pl": "Hotel mnie pozytywnie zaskoczył.", "focusEn": "positively", "focusPl": "pozyty… | { "en": "Most of the reviews spoke positively about the hotel.", "pl": "Większość recenzji wypowiadała się o hotelu pozytywnie.", "focusE… | EN – gramatyka/naturalność |
| c05 | core.shortly | tekst | Lekarz zaraz do Pana przyjdzie. | Lekarz zaraz do pana przyjdzie. | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.spray-2 | przykład | "pl": "Ktoś popsikał farbą cały nasz płot.", "focusEn": "sprayed", "focusPl": "popsikał" | "pl": "Ktoś pomazał sprayem cały nasz płot.", "focusEn": "sprayed", "focusPl": "pomazał sprayem" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.stack | przykład | "pl": "Zamówiłem stertę naleśników z syropem.", "focusEn": "stack", "focusPl": "stertę" | "pl": "Zamówiłem stos naleśników z syropem.", "focusEn": "stack", "focusPl": "stos" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.sword | AT | ["miecz", "szabla", "szpada"] | ["miecz", "miecze"] | acceptedTranslations |
| c05 | core.sword | przykład | "pl": "Dzieci walczyły na patyki jak na miecze na podwórku.", "focusEn": "sword fight", "focusPl": "walczyły na patyki jak na miecze" | "pl": "Dzieci bawiły się na podwórku w walkę na miecze, używając patyków.", "focusEn": "sword fight", "focusPl": "walkę na miecze" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.technically | przykład | "pl": "Czy da się technicznie naprawić stary telefon?" | "pl": "Czy naprawa starego telefonu jest technicznie możliwa?" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.put-down | przykład | { "en": "Can you put my name down for the trip?", "pl": "Możesz zapisać mnie na wycieczkę?", "focusEn": "put my name down", "focusPl": "z… | { "en": "She put down her coffee and answered the phone.", "pl": "Odstawiła kawę i odebrała telefon.", "focusEn": "put down", "focusPl": … | przykład nie w tym znaczeniu |
| c05 | core.put-down | AT | ["odłożyć", "odkładać", "położyć", "postawić", "zapisać"] | ["odłożyć", "odkładać", "położyć", "postawić", "odstawić"] | acceptedTranslations |
| c05 | core.put-down-2 | przykład | "pl": "Nie pozwól nikomu się poniżać.", "focusEn": "put you down", "focusPl": "się poniżać" | "pl": "Nie pozwól, żeby ktokolwiek cię poniżał.", "focusEn": "put you down", "focusPl": "cię poniżał" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.put-down-2 | przykład | "pl": "Mój szef zamiast pomagać ludziom, umniejsza ich.", "focusEn": "puts people down", "focusPl": "umniejsza ich" | "pl": "Zamiast pomagać ludziom, mój szef ich poniża.", "focusEn": "puts people down", "focusPl": "ich poniża" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.bring-up | przykład | { "en": "How were you brought up to treat older people?", "pl": "Jak cię nauczono w domu traktować starszych ludzi?", "focusEn": "brought… | { "en": "I was brought up to always say please and thank you.", "pl": "Wychowano mnie tak, żebym zawsze mówił „proszę” i „dziękuję”.", "f… | EN – gramatyka/naturalność |
| c05 | core.bring-in-2 | przykład | { "en": "The summer festival brings in a lot of tourists.", "pl": "Letni festiwal przyciąga wielu turystów.", "focusEn": "brings in", "fo… | { "en": "The summer festival brings in a lot of money for local businesses.", "pl": "Letni festiwal przynosi miejscowym firmom dużo pieni… | przykład nie w tym znaczeniu |
| c05 | core.bring-in-2 | AT | ["przynosić (dochód)", "przynosić", "przynieść", "przyciągać", "zarabiać"] | ["przynosić (dochód)", "przynosić", "przynieść", "przynosić dochód", "zarabiać"] | acceptedTranslations |
| c05 | core.break-out | przykład | { "en": "Two prisoners broke out of the jail last night.", "pl": "Zeszłej nocy z więzienia uciekło dwóch więźniów.", "focusEn": "broke ou… | { "en": "Did any arguments break out at the meeting?", "pl": "Czy na zebraniu wybuchły jakieś kłótnie?", "focusEn": "break out", "focusPl… | przykład nie w tym znaczeniu |
| c05 | core.break-out | AT | ["wybuchnąć", "wybuchać", "wybuchnąć nagle", "uciec"] | ["wybuchnąć", "wybuchać", "rozpętać się"] | acceptedTranslations |
| c05 | core.break-out | tekst | "notePl": "" | "notePl": "Break out of (prison) = uciec (z więzienia); break out in a rash = dostać wysypki." | przykład nie w tym znaczeniu |
| c05 | core.break-in-2 | przykład | { "en": "It took a week to break in the new baseball glove.", "pl": "Rozbicie nowej rękawicy baseballowej zajęło tydzień.", "focusEn": "b… | { "en": "It took about a week to break in my new running shoes.", "pl": "Rozchodzenie nowych butów do biegania zajęło mi mniej więcej tyd… | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.break-in-2 | AT | ["rozchodzić (buty)", "rozchodzić", "rozbić", "ułożyć"] | ["rozchodzić (buty)", "rozchodzić", "rozchodzić buty"] | acceptedTranslations |
| c05 | core.pull-out | przykład | "pl": "Samochód wyjechał przede mną, nie patrząc." | "pl": "Jakiś kierowca wyjechał tuż przede mną, nawet się nie rozglądając." | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.stand-up-for | przykład | "pl": "Musisz nauczyć się bronić siebie.", "focusEn": "stand up for yourself", "focusPl": "bronić siebie" | "pl": "Musisz nauczyć się stawać w swojej obronie.", "focusEn": "stand up for yourself", "focusPl": "stawać w swojej obronie" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.turn-to | przykład | { "en": "Please open your books and turn to page twenty-five.", "pl": "Proszę otworzyć książki na stronie dwudziestej piątej.", "focusEn"… | { "en": "Who do you turn to when you need advice about money?", "pl": "Do kogo się zwracasz, kiedy potrzebujesz porady w sprawie pieniędz… | przykład nie w tym znaczeniu |
| c05 | core.turn-to | AT | ["zwrócić się do", "zwracać się do", "szukać pomocy u", "uciekać się do", "otworzyć na"] | ["zwrócić się do", "zwracać się do", "szukać pomocy u", "uciekać się do", "szukać"] | acceptedTranslations |
| c05 | core.burn-down | przykład | { "en": "Was the whole building burned down?", "pl": "Czy cały budynek spłonął?", "focusEn": "burned down", "focusPl": "spłonął" } | { "en": "Did the whole building burn down?", "pl": "Czy cały budynek spłonął?", "focusEn": "burn down", "focusPl": "spłonął" } | EN – gramatyka/naturalność |
| c05 | core.kick-out | tekst | bo byli za głośno. | bo zachowywali się za głośno. | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.shut-up | przykład | { "en": "The baby finally shut up and fell asleep.", "pl": "Dziecko w końcu ucichło i zasnęło.", "focusEn": "shut up", "focusPl": "ucichł… | { "en": "The neighbors' dog finally shut up around midnight.", "pl": "Pies sąsiadów w końcu ucichł około północy.", "focusEn": "shut up",… | EN – gramatyka/naturalność |
| c05 | core.go-for | ipa | /ˈɡoʊ fɔːr/ | /ˈɡoʊ fər/ | IPA |
| c05 | core.go-with | ipa | /ˈɡoʊ wɪð/ | /ˈɡoʊ ˌwɪð/ | IPA |
| c05 | core.in-spite-of | tekst | in spite of the power cut? | in spite of the power outage? | EN – AmE |
| c05 | core.in-addition-to | AT | ["oprócz", "poza", "w dodatku do", "obok", "prócz"] | ["oprócz", "poza", "obok", "prócz", "w dodatku"] | acceptedTranslations |
| c05 | core.as-though | AT | ["jak gdyby", "jakby", "jak by", "tak jakby"] | ["jak gdyby", "jakby", "tak jakby"] | acceptedTranslations |
| c05 | core.rather-than | przykład | "pl": "Wolę herbatę zamiast kawy, poproszę." | "pl": "Poproszę herbatę zamiast kawy." | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.rather-than | AT | ["zamiast", "a nie", "raczej niż", "niż"] | ["zamiast", "a nie", "niż"] | acceptedTranslations |
| c05 | core.in-favor-of | AT | ["za", "na rzecz", "na korzyść", "popierający", "zwolennik"] | ["za", "na rzecz", "na korzyść", "popierający"] | acceptedTranslations |
| c05 | core.not-only-but-also | przykład | { "en": "Exercise is not only good for your body but also for your mind.", "pl": "Ćwiczenia są dobre nie tylko dla ciała, ale również dla… | { "en": "Exercise is good not only for your body but also for your mind.", "pl": "Ćwiczenia są dobre nie tylko dla ciała, ale również dla… | EN – gramatyka/naturalność |
| c05 | core.additionally | przykład | { "en": "The room was small and additionally very noisy.", "pl": "Pokój był mały, a do tego bardzo głośny.", "focusEn": "additionally", "… | { "en": "The room was small; additionally, the walls were very thin.", "pl": "Pokój był mały, a do tego miał bardzo cienkie ściany.", "fo… | EN – gramatyka/naturalność |
| c05 | core.beforehand | tekst | Proszę daj mi znać wcześniej | Proszę, daj mi znać wcześniej | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.on-board | ipa | /ɑːn ˈbɔːrd/ | /ˌɑːn ˈbɔːrd/ | IPA |
| c05 | core.on-second-thought | przykład | "pl": "Po zastanowieniu może jednak dzwonienie do niego to nie jest dobry pomysł." | "pl": "Po zastanowieniu myślę, że jednak lepiej do niego nie dzwonić." | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.for-good | tekst | For good nie znaczy „na dobre” w sensie „dla dobra”. | For good nie znaczy „dla dobra” — to „na dobre, na zawsze”. | notePl |
| c05 | core.time-consuming | ipa | /ˈtaɪm kənˌsuːmɪŋ/ | /ˈtaɪm kənsuːmɪŋ/ | IPA |
| c05 | core.as-it-turns-out | przykład | { "en": "As it turns out, the store was closed anyway.", "pl": "Jak się okazało, sklep i tak był zamknięty.", "focusEn": "As it turns out", | { "en": "As it turned out, the store was closed anyway.", "pl": "Jak się okazało, sklep i tak był zamknięty.", "focusEn": "As it turned o… | EN – gramatyka/naturalność |
| c05 | core.the-other-way-around | AT | ["na odwrót", "odwrotnie", "w drugą stronę", "wręcz przeciwnie"] | ["na odwrót", "odwrotnie", "w drugą stronę"] | acceptedTranslations |
| c05 | core.confess | AT | ["przyznać się", "przyznawać się", "wyznać", "wyznawać", "spowiadać się"] | ["przyznać się", "przyznawać się", "wyznać", "wyznawać"] | acceptedTranslations |
| c05 | core.doubtful | przykład | { "en": "Is it doubtful that he'll play on Sunday?", "pl": "Czy to niepewne, że zagra w niedzielę?", "focusEn": "doubtful", "focusPl": "n… | { "en": "My boss looked doubtful when I suggested working from home.", "pl": "Szef miał sceptyczną minę, kiedy zaproponowałem pracę z dom… | EN – gramatyka/naturalność |
| c05 | core.exotic | AT | ["egzotyczny", "niezwykły", "dalekobrzeżny"] | ["egzotyczny", "niezwykły"] | acceptedTranslations |
| c05 | core.imitate | AT | ["naśladować", "imitować", "kopiować", "przedrzeźniać", "udawać"] | ["naśladować", "imitować", "kopiować", "przedrzeźniać"] | acceptedTranslations |
| c05 | core.inspect | przykład | "pl": "Na granicy funkcjonariusz przeszukał nasze bagaże.", "focusEn": "inspected", "focusPl": "przeszukał" | "pl": "Na granicy funkcjonariusz skontrolował nasze bagaże.", "focusEn": "inspected", "focusPl": "skontrolował" | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.irritating | tekst | Ta piosenka jest tak irytująca, a nie mogę przestać jej nucić. | Ta piosenka jest tak irytująca, a mimo to nie mogę przestać jej nucić. | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.outstanding | ipa | /ˌaʊtˈstændɪŋ/ | /aʊtˈstændɪŋ/ | IPA |
| c05 | core.scold | tekst | Proszę, nie krzycz na niego, to był wypadek. | Proszę, nie krzycz na niego, to było niechcący. | PL (tłumaczenie/kalka/interpunkcja) |
| c05 | core.punch → nowy wpis | — | — | (nowe znaczenie, zob. §4) | dopisane znaczenie |
| c05 | core.authority | AT | ["władza", "uprawnienia", "prawo", "autorytet", "zwierzchnictwo"] | ["władza", "uprawnienia", "prawo", "zwierzchnictwo"] | acceptedTranslations |
| c06 | core.overnight | AT | ["na noc", "przez noc", "w nocy", "na noc w"] | ["na noc", "przez noc", "w nocy", "przez całą noc"] | acceptedTranslations |
| c06 | core.amusement-park | przykład | "pl": "Nie lubię karuzeli w parkach rozrywki, które kręcą do góry nogami.", "focusEn": "amusement park rides", "focusPl": "karuzeli w par… | "pl": "Nie lubię takich atrakcji w parkach rozrywki, na których wisi się do góry nogami.", "focusEn": "amusement park rides", "focusPl": … | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.sympathy | przykład | "pl": "Przyjmij wyrazy głębokiego współczucia z powodu twojej straty." | "pl": "Przyjmij nasze wyrazy głębokiego współczucia." | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.renovate | tekst | while it's renovated. | while it's being renovated. | EN – gramatyka/naturalność |
| c06 | core.itch-2 | przykład | "pl": "Swędzi mnie plecy w miejscu, do którego nie mogę sięgnąć.", "focusEn": "have an itch", "focusPl": "Swędzi mnie" | "pl": "Swędzą mnie plecy w miejscu, do którego nie mogę sięgnąć.", "focusEn": "have an itch", "focusPl": "Swędzą mnie" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.amused | AT | ["rozbawiony", "z rozbawieniem", "ubawiony", "zajęty"] | ["rozbawiony", "z rozbawieniem", "ubawiony"] | acceptedTranslations |
| c06 | core.disabled | AT | ["niepełnosprawny", "z niepełnosprawnością", "z niepełnosprawnościami", "inwalida"] | ["niepełnosprawny", "z niepełnosprawnością", "z niepełnosprawnościami"] | acceptedTranslations |
| c06 | core.fictional | AT | ["fikcyjny", "zmyślony", "wymyślony", "literacki"] | ["fikcyjny", "zmyślony", "wymyślony"] | acceptedTranslations |
| c06 | core.meaningless | przykład | "focusEn": "meaningless", "focusPl": "nie traci sensu" | "focusEn": "meaningless", "focusPl": "traci sensu" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.renewable | przykład | { "en": "Is wind power more renewable than solar?", "pl": "Czy energia wiatrowa jest bardziej odnawialna niż słoneczna?", "focusEn": "mor… | { "en": "Is a driver's license renewable online, or do you have to go in person?", "pl": "Czy prawo jazdy można przedłużyć przez internet… | EN – gramatyka/naturalność |
| c06 | core.renewable | AT | ["odnawialny", "z możliwością przedłużenia", "ekologiczny"] | ["odnawialny", "z możliwością przedłużenia", "do przedłużenia"] | acceptedTranslations |
| c06 | core.shocking | przykład | { "en": "Weren't you shocked by the results? The numbers were shocking.", "pl": "Nie zaskoczyły cię wyniki? Liczby były szokujące.", "foc… | { "en": "Wasn't it shocking how quickly the store closed?", "pl": "Czy to nie szokujące, jak szybko zamknięto ten sklep?", "focusEn": "sh… | EN – gramatyka/naturalność |
| c06 | core.well-educated | AT | ["wykształcony", "dobrze wykształcony", "oczytany"] | ["wykształcony", "dobrze wykształcony"] | acceptedTranslations |
| c06 | core.allowance | tekst | Soldiers living off the base get a housing allowance. | Soldiers living off base get a housing allowance. | EN – gramatyka/naturalność |
| c06 | core.perfection | tekst | Stek był upieczony do perfekcji. | Stek był przyrządzony do perfekcji. | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.relaxation | przykład | { "en": "Our vacation wasn't much relaxation with three small kids.", "pl": "Z trojgiem maluchów urlop nie był zbyt relaksujący.", "focus… | { "en": "With three small kids, there wasn't much time for relaxation on our vacation.", "pl": "Z trojgiem maluchów na urlopie nie było w… | EN – gramatyka/naturalność |
| c06 | core.bound | przykład | "pl": "Czy cena nie musi pójść w górę po świętach?", "focusEn": "bound to", "focusPl": "musi" | "pl": "Czy po świętach cena na pewno nie pójdzie w górę?", "focusEn": "bound to", "focusPl": "na pewno" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.loop | AT | ["pętla", "pętelka", "kółko", "obwód", "w kółko"] | ["pętla", "pętelka", "kółko", "w kółko"] | acceptedTranslations |
| c06 | core.acute | przykład | "pl": "Na terenach wiejskich brakuje dramatycznie pielęgniarek.", "focusEn": "acute shortage", "focusPl": "brakuje dramatycznie" | "pl": "Na terenach wiejskich dramatycznie brakuje pielęgniarek.", "focusEn": "acute shortage", "focusPl": "dramatycznie brakuje" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.affirm | przykład | "pl": "Nie potwierdziła ani nie zaprzeczyła plotkom.", "focusEn": "didn't affirm", "focusPl": "Nie potwierdziła" | "pl": "Ani nie potwierdziła plotek, ani im nie zaprzeczyła.", "focusEn": "didn't affirm", "focusPl": "nie potwierdziła" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.circulate | tekst | Proszę roześlij ten mail | Proszę, roześlij ten mail | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.clone | przykład | { "en": "The first animal clone was a sheep.", "pl": "Pierwszym sklonowanym zwierzęciem była owca.", | { "en": "The most famous animal clone was a sheep named Dolly.", "pl": "Najsłynniejszym sklonowanym zwierzęciem była owca Dolly.", | EN – gramatyka/naturalność |
| c06 | core.competence | forms | competences | (niepoliczalny) | forms |
| c06 | core.credibility | AT | ["wiarygodność", "zaufanie", "prawdopodobieństwo"] | ["wiarygodność", "zaufanie"] | acceptedTranslations |
| c06 | core.cue | przykład | "pl": "Aktor przegapił swoją kwestię i wszedł na scenę za późno.", "focusEn": "missed his cue", "focusPl": "przegapił swoją kwestię" | "pl": "Aktor przegapił moment swojego wejścia i pojawił się na scenie za późno.", "focusEn": "missed his cue", "focusPl": "przegapił mome… | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.cue | AT | ["sygnał", "znak", "wskazówka", "kwestia", "jak na zawołanie"] | ["sygnał", "znak", "wskazówka", "jak na zawołanie"] | acceptedTranslations |
| c06 | core.dependence | przykład | { "en": "Many young adults still have financial dependence on their parents.", "pl": "Wielu młodych dorosłych wciąż jest finansowo zależn… | { "en": "His dependence on painkillers worried his doctor.", "pl": "Jego uzależnienie od leków przeciwbólowych niepokoiło lekarza.", "foc… | EN – gramatyka/naturalność |
| c06 | core.disturbance | tekst | Please work quietly to avoid any disturbance to other guests. | Please keep your voices down to avoid any disturbance to other guests. | EN – gramatyka/naturalność |
| c06 | core.elite | przykład | "pl": "Trenuje z krajową elitą lekkoatletyczną." | "pl": "Trenuje z krajową elitą sportową." | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.faculty | AT | ["kadra dydaktyczna", "grono pedagogiczne", "wykładowcy", "nauczyciele", "zdolności"] | ["kadra dydaktyczna", "kadra", "grono pedagogiczne", "wykładowcy", "nauczyciele", "zdolności"] | acceptedTranslations |
| c06 | core.flesh | przykład | "pl": "To moja rodzona krew, więc oczywiście mu pomogę.", "focusEn": "flesh and blood", "focusPl": "rodzona krew" | "pl": "To przecież moja rodzina, więc oczywiście mu pomogę.", "focusEn": "flesh and blood", "focusPl": "moja rodzina" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.inevitably | AT | ["nieuchronnie", "nieuniknienie", "siłą rzeczy", "oczywiście", "nieodwołalnie"] | ["nieuchronnie", "siłą rzeczy", "oczywiście"] | acceptedTranslations |
| c06 | core.instability | tekst | Moving schools often can cause instability for children. | Changing schools too often can cause instability for children. | EN – gramatyka/naturalność |
| c06 | core.invasion | tekst | inwazji szarańczy. | inwazji koników polnych. | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.optical | przykład | { "en": "Our town finally has optical fiber internet.", "pl": "W naszym miasteczku w końcu jest internet światłowodowy.", "focusEn": "opt… | { "en": "Optical sensors in the camera can detect even small movements.", "pl": "Czujniki optyczne w kamerze wykrywają nawet drobne ruchy… | przykład nie w tym znaczeniu |
| c06 | core.optical | AT | ["optyczny", "wzrokowy", "światłowodowy"] | ["optyczny", "wzrokowy"] | acceptedTranslations |
| c06 | core.practitioner | przykład | "pl": "Zamiast lekarza przyjęła mnie wykwalifikowana pielęgniarka.", "focusEn": "nurse practitioner", "focusPl": "wykwalifikowana pielęgn… | "pl": "Zamiast lekarza przyjęła mnie pielęgniarka z uprawnieniami do leczenia.", "focusEn": "nurse practitioner", "focusPl": "pielęgniark… | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.radar | AT | ["radar", "pole widzenia", "niezauważony"] | ["radar"] | acceptedTranslations |
| c06 | core.ray | tekst | Przez zasłony przedostały się pierwsze promienie słońca. | Przez zasłony wpadły pierwsze promienie słońca. | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.realism | przykład | { "en": "Is there enough realism in the new budget?", "pl": "Czy w nowym budżecie jest dość realizmu?", "focusEn": "realism", "focusPl": … | { "en": "Doesn't the plan need a bit more realism?", "pl": "Czy temu planowi nie przydałoby się trochę więcej realizmu?", "focusEn": "rea… | EN – gramatyka/naturalność |
| c06 | core.realm | AT | ["sfera", "dziedzina", "obszar", "królestwo"] | ["sfera", "dziedzina", "obszar"] | acceptedTranslations |
| c06 | core.retrieve | przykład | "pl": "Wróciłem do restauracji po parasol.", "focusEn": "to retrieve", "focusPl": "po" | "pl": "Wróciłem do restauracji, żeby odebrać parasol.", "focusEn": "to retrieve", "focusPl": "odebrać" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.rotate | przykład | "pl": "Jak często należy zamieniać opony w samochodzie?", "focusEn": "rotate", "focusPl": "zamieniać" | "pl": "Jak często należy przekładać opony w samochodzie?", "focusEn": "rotate", "focusPl": "przekładać" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.span | przykład | "pl": "Małe dzieci mają krótką zdolność skupienia uwagi.", "focusEn": "attention span", "focusPl": "zdolność skupienia uwagi" | "pl": "Małe dzieci potrafią skupić uwagę tylko na krótko.", "focusEn": "attention span", "focusPl": "skupić uwagę" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.stance | przykład | "pl": "Burmistrz zajął stanowcze stanowisko przeciwko nowemu kasynu.", "focusEn": "firm stance", "focusPl": "stanowcze stanowisko" | "pl": "Burmistrz zdecydowanie sprzeciwił się budowie nowego kasyna.", "focusEn": "firm stance", "focusPl": "zdecydowanie sprzeciwił się" | PL (tłumaczenie/kalka/interpunkcja) |
| c06 | core.alert-2 → nowy wpis | — | — | (nowe znaczenie, zob. §4) | dopisane znaczenie |
| c06 | core.sniff → nowy wpis | — | — | (nowe znaczenie, zob. §4) | dopisane znaczenie |

## 9. Dopisek: przyimki w czasownikach frazowych (uwaga koordynatora)

W obu shardach sprawdziłem wszystkie hasła zakończone przyimkiem. Wszystkie hasła na *for* mają słabą formę /fər/: *go for* (poprawione z /fɔːr/), *stand for*, *stand up for*. Słabą formę mają też *to* /tə/ i *of* /əv/. Wyjątek to *on*, które zostaje jako /ɑːn/ (*live on, wait on, look down on, check up on*), zgodnie z bazą (*count on, rely on*). Partykuły przysłówkowe (*bring in, turn in, fit in*…) są akcentowane, co jest poprawne.
