# Raport: english-qa, słownik rdzeniowy — core-qa-4 (core-c07.json, core-c08.json)

Raport agenta core-qa-4 (zapis pliku przez subagenta był zablokowany — zapisał koordynator).

## 1. Statystyka

| | core-c07 | core-c08 | razem |
|---|---|---|---|
| Wpisy sprawdzone | 546 | 241 | **787** |
| Przykłady sprawdzone | 1662 | 729 | **2391** |
| Wpisy poprawione | 101 (18,5%) | 33 (13,7%) | 134 (17,0%) |
| — bez zmian wyłącznie redakcyjnych | 92 (16,8%) | 29 (12,0%) | 121 (15,4%) |
| — w tym błąd po stronie EN | 21 (3,8%) | 5 (2,1%) | 26 (3,3%) |
| Zmienione pola | 126 | 38 | 164 |
| Walidator `--file` | 0 / 0 | 0 / 0 | |

Nie dodano ani nie usunięto wpisów, `id` bez zmian, formatowanie zachowane (round-trip bajt w bajt; liczba zmienionych linii = liczba zmian).

Angielski autorów bardzo dobry; najwięcej poprawek w polskich tłumaczeniach przykładów (kalki, rekcja, przecinek przed „czy” w pytaniach alternatywnych) i w `acceptedTranslations` z odpowiednikiem innego znaczenia.

## 2. Poprawki według kategorii (wpisy / pola)

| Kategoria | c07 | c08 |
|---|---|---|
| Polskie tłumaczenia (kalki, rekcja, interpunkcja, focusPl) | 45 / 48 | 16 / 16 |
| `acceptedTranslations` z innym znaczeniem lub częścią mowy | 39 / 39 | 12 / 12 |
| Naturalność EN (AmE) | 10 / 11 | 5 / 5 |
| Przykład w innym znaczeniu lub części mowy | 8 / 9 | — |
| Gramatyka EN | 3 / 5 | — |
| `forms` | 3 / 3 | 1 / 1 |
| IPA | 2 / 2 | — |
| Inne (powtórzone zdania PL, marka, polityka, definicja, notatka) | 9 / 9 | 4 / 4 |

## 3. Najważniejsze poprawki

1. Fałszywi przyjaciele w AT: *discrete* „dyskretny”, *notorious* „notoryczny” (teraz „osławiony”), *integrity* „integralność”, *vocal* „wokalny”.
2. *idle*: *Don't leave your engine idle…* (błędne w AmE) → *Thousands of workers were left idle by the strike.*
3. *inflate-2*: „Sukces wybujał mu ego” → „Przez sukces ma wybujałe ego”.
4. *compassionate*: *compassionate leave* (BrE) → przykład AmE.
5. AT z innym znaczeniem usunięte: *inevitable* „nieodwracalny”, *admittedly* „niewątpliwie”, *infamous* „słynny”, *aspire* „początkujący”, *solitude* „samotnia”.
6. Przykłady w innym znaczeniu wymienione: *wit*, *shed*, *condemn*, *demolish*; *aspire/disclose/foresee/prolong* — przykłady z przymiotnikami pochodnymi zamienione na czasownik.
7. *disguise-2*: „błogosławieństwem w nieszczęściu” → „szczęściem w nieszczęściu”.
8. *lifelong*: nazwa prawdziwego klubu → *the local baseball team*.
9. IPA *fall for* / *call for* → słaba forma `/fər/`.
10. *sensory*: „zmysłowy” → „sensoryczny”; para *meager/paltry* — wspólne AT („skromny”, „nędzny”).

Pary bliskoznaczne (redundant/superfluous, appease/placate, ubiquitous/pervasive, ardent/staunch/fervent, candid/frank/sincere, mandatory/compulsory/obligatory, infamous/notorious, vulnerable/susceptible/prone) mają już nakładające się AT.

## 4. Wątpliwości

- Utrwalone kolokacje z przymiotnikiem odczasownikowym w przykładach czasowników zostawione (*refined sugar*, *thriving*, *gripping*, *inflated ego*, *foster parents*).
- CEFR bez zmian; *exhaustion* i *outlook* mogłyby być B2.
- Lekko polityczne konteksty neutralne zostawione; zmienione dwa przykłady z wyborami.

## 5. Działania koordynatora po raporcie

- IPA „… for” w tematach ujednolicone do słabej formy `/fər/` (15 haseł, m.in. `cooking.call-for`, `cybersecurity.fall-for`, *root for*, *run for*, *sign up for*); wyjątek: *not what I asked for* (przyimek na końcu zdania — forma mocna).
- `core.go-for` przekazane core-qa-3.
- Przebudowa `dictionary-index.json` i `CORE-MASTER` po zakończeniu fali.

## 6. Tabela zmian

Format: `plik | id | pole | było | jest | kategoria`; `exN` = przykład N (od zera), „‖” rozdziela EN i PL.

| plik | id | pole | było | jest | kategoria |
|---|---|---|---|---|---|
| c07 | core.fall-for | ipa | /ˈfɔːl ˌfɔːr/ | /ˈfɔːl fər/ | ipa |
| c07 | core.tear-down | ex1.en | The house was torn down in the nineteen-seventies. | The house was torn down back in the seventies. | nat-en |
| c07 | core.let-off | ex0.pl | Policjant puścił mnie wolno, dając tylko upomnienie. | Policjant skończył na upomnieniu i puścił mnie wolno. | pl |
| c07 | core.prior-to | acceptedTranslations | przed; zanim; uprzednio; wcześniej niż | przed; zanim; wcześniej niż | accepted |
| c07 | core.regardless-of | acceptedTranslations | bez względu na; niezależnie od; mimo; nie zważając na | bez względu na; niezależnie od; nie zważając na | accepted |
| c07 | core.juggle | ex1.en | My uncle taught me how to juggle with oranges. | My uncle taught me how to juggle oranges. | nat-en |
| c07 | core.brutal | ex1.pl | Zeszła zima była okropna, z tygodniami mrozu. | Zeszła zima była okropna: mróz trzymał całymi tygodniami. | pl |
| c07 | core.inevitable | acceptedTranslations | nieunikniony; nieuchronny; nieuchronnie; nieodwracalny | nieunikniony; nieuchronny | accepted |
| c07 | core.tempt | ex3.pl | Nie daj się skusić niską ceną do kupienia czegoś, czego nie potrzebujesz. | Nie daj się skusić niską ceną i nie kupuj czegoś, czego nie potrzebujesz. | pl |
| c07 | core.thesis | ex1.pl | Główna teza autora brzmi tak, że miasta potrzebują mniej samochodów. | Główna teza autora głosi, że miasta potrzebują mniej samochodów. | pl |
| c07 | core.threshold | notePl | Wymowa bez „h” w środku: /ˈθreʃhoʊld/ — dwie sylaby thresh-hold. | Pisownia z jednym „h” (threshold), choć wymawia się dwie sylaby thresh-hold: /ˈθreʃhoʊld/. | other |
| c07 | core.transmit-2 | ex1 | You can transmit the flu before you feel sick. ‖ Grypę można przenosić, zanim poczujesz się chory. | You can transmit the flu before you feel sick. ‖ Możesz zarażać grypą, zanim poczujesz się chory. | pl |
| c07 | core.wisdom | acceptedTranslations | mądrość; rozsądek; mądre; mądry | mądrość; rozsądek | accepted |
| c07 | core.set-back | ex1 | The injury set him back, but he's training again now. ‖ Kontuzja go wyhamowała, ale teraz znowu trenuje. | The injury set him back, but he's training again now. ‖ Kontuzja zahamowała jego postępy, ale teraz znowu trenuje. | pl |
| c07 | core.set-back | acceptedTranslations | opóźnić; opóźniać; spowolnić; wyhamować; cofnąć | opóźnić; opóźniać; spowolnić; zahamować; cofnąć | accepted |
| c07 | core.call-for | ipa | /ˈkɔːl fɔːr/ | /ˈkɔːl fər/ | ipa |
| c07 | core.hold-off | ex1 | Luckily, the rain held off until the end of the wedding. ‖ Na szczęście deszcz nie spadł aż do końca wesela. | Luckily, the rain held off until the end of the wedding. ‖ Na szczęście deszcz wstrzymał się aż do końca wesela. | pl |
| c07 | core.make-for-2 | ex2 | His crazy stories make for a very entertaining evening. ‖ Dzięki jego zwariowanym historiom wieczór jest bardzo zabawny. | His crazy stories make for a very entertaining evening. ‖ Jego zwariowane historie zapewniają bardzo zabawny wieczór. | pl |
| c07 | core.in-line-with | ex0 | Salaries will rise in line with inflation. ‖ Pensje wzrosną zgodnie z inflacją. | Salaries will rise in line with inflation. ‖ Pensje wzrosną proporcjonalnie do inflacji. | pl |
| c07 | core.in-line-with | acceptedTranslations | zgodnie z; zgodny z; zgodna z; w zgodzie z; na równi z | zgodnie z; zgodny z; zgodna z; w zgodzie z; proporcjonalnie do | accepted |
| c07 | core.all-in-all | ex0.pl | Hotel był trochę głośny, ale ogólnie rzecz biorąc świetnie się bawiliśmy. | Hotel był trochę głośny, ale ogólnie rzecz biorąc, świetnie się bawiliśmy. | pl |
| c07 | core.evidently | acceptedTranslations | najwyraźniej; wyraźnie; ewidentnie; widocznie; oczywiście | najwyraźniej; wyraźnie; ewidentnie; widocznie | accepted |
| c07 | core.admittedly | acceptedTranslations | co prawda; wprawdzie; przyznaję; trzeba przyznać; niewątpliwie | co prawda; wprawdzie; przyznaję; trzeba przyznać | accepted |
| c07 | core.ironically | acceptedTranslations | jak na ironię; paradoksalnie; o ironio; ironicznie | jak na ironię; paradoksalnie; o ironio | accepted |
| c07 | core.mutually | ex1 | The meeting time was mutually agreed by both sides. ‖ Termin spotkania został ustalony przez obie strony. | The date of the meeting was mutually agreed. ‖ Termin spotkania ustalono za obopólną zgodą. | nat-en |
| c07 | core.mutually | acceptedTranslations | wzajemnie; obustronnie; nawzajem; przez obie strony | wzajemnie; obustronnie; obopólnie; nawzajem; przez obie strony | accepted |
| c07 | core.so-to-speak | ex2.pl | Nowy kierownik dopiero się, że tak to ujmę, wdraża. | Nowy kierownik dopiero, że tak to ujmę, poznaje teren. | pl |
| c07 | core.behalf | acceptedTranslations | w imieniu (kogoś); w imieniu; za kogoś; za; na rzecz | w imieniu (kogoś); w imieniu; za kogoś | accepted |
| c07 | core.gratitude | acceptedTranslations | wdzięczność; podziękowanie | wdzięczność | accepted |
| c07 | core.grief | ex2.en | Is there a support group for grief in our area? | Is there a grief support group in our area? | nat-en |
| c07 | core.hardship | ex2 | Moving away from family can cause real hardship. ‖ Wyprowadzka z dala od rodziny może być prawdziwym wyzwaniem. | Moving away from family can cause real hardship. ‖ Wyprowadzka daleko od rodziny może przysporzyć prawdziwych trudności. | pl |
| c07 | core.hardship | acceptedTranslations | trudności; trudy; ciężkie warunki; niedostatek; bieda; wyzwanie | trudności; trudy; ciężkie warunki; niedostatek; bieda | accepted |
| c07 | core.compassion | acceptedTranslations | współczucie; litość; empatia; serce | współczucie; litość; empatia | accepted |
| c07 | core.despair | ex2.en | Don't give in to despair, things will get better. | Don't give in to despair. Things will get better. | gram-en |
| c07 | core.devotion | acceptedTranslations | oddanie; przywiązanie; poświęcenie; pobożność | oddanie; przywiązanie; poświęcenie | accepted |
| c07 | core.integrity | acceptedTranslations | uczciwość; prawość; rzetelność; wiarygodność; integralność | uczciwość; prawość; rzetelność; wiarygodność | accepted |
| c07 | core.misery | ex2 | Just tell me the results and put me out of my misery! ‖ Po prostu podaj mi wyniki i skończ moje męki! | Just tell me the results and put me out of my misery! ‖ Po prostu podaj mi wyniki i nie trzymaj mnie dłużej w niepewności! | pl |
| c07 | core.modesty | acceptedTranslations | skromność; pokora; skromny | skromność; pokora | accepted |
| c07 | core.modesty | ex2 | Don't give me that false modesty. You know you're good! ‖ Nie udawaj skromnego, wiesz, że jesteś dobry! | Don't give me that false modesty. You know you're good! ‖ Nie udawaj skromnego. Wiesz, że jesteś dobry! | pl |
| c07 | core.plight | forms | (lp.) | plights | forms |
| c07 | core.recollection | acceptedTranslations | wspomnienie; pamięć; przypomnienie; pamiętać | wspomnienie; pamięć; pamiętać | accepted |
| c07 | core.resentment | ex2 | Don't let resentment build up, talk to her about it. ‖ Nie pozwól, żeby narastał w tobie żal, porozmawiaj z nią o tym. | Don't let resentment build up. Talk to her about it. ‖ Nie pozwól, żeby narastał w tobie żal. Porozmawiaj z nią o tym. | gram-en |
| c07 | core.stigma | ex2 | Asking for help shouldn't carry any stigma. ‖ Proszenie o pomoc nie powinno nikogo piętnować. | Asking for help shouldn't carry any stigma. ‖ Proszenie o pomoc nie powinno być powodem do wstydu. | pl |
| c07 | core.temptation | acceptedTranslations | pokusa; kuszenie; skłonność | pokusa; kuszenie | accepted |
| c07 | core.urgency | ex2.pl | Słyszałem w jej głosie w telefonie, że sprawa jest pilna. | Przez telefon słyszałem w jej głosie, że sprawa jest pilna. | pl |
| c07 | core.wit | ex2 | You need to keep your wits about you in a big city. ‖ W dużym mieście trzeba mieć oczy dookoła głowy. | I've always admired your sharp wit. ‖ Zawsze podziwiałem twój cięty dowcip. | sense |
| c07 | core.wit | collocations | a quick wit; sharp wit; humor and wit; keep your wits about you | a quick wit; sharp wit; dry wit; humor and wit | sense |
| c07 | core.wit | acceptedTranslations | dowcip; poczucie humoru; błyskotliwość; bystrość; rozum | dowcip; poczucie humoru; błyskotliwość; bystrość | accepted |
| c07 | core.aftermath | forms | (lp.) | the aftermath (tylko lp.) | forms |
| c07 | core.aftermath | acceptedTranslations | następstwa; skutki; pokłosie; w następstwie; po | następstwa; skutki; pokłosie; w następstwie | accepted |
| c07 | core.aspire | ex2 | He's an aspiring writer who works at a coffee shop. ‖ Jest początkującym pisarzem, który pracuje w kawiarni. | He aspired to a career in medicine, but he became a teacher. ‖ Marzył o karierze lekarza, ale został nauczycielem. | sense |
| c07 | core.aspire | acceptedTranslations | aspirować; dążyć do; marzyć o; mieć ambicje; początkujący | aspirować; dążyć do; marzyć o; mieć ambicje | accepted |
| c07 | core.await | acceptedTranslations | oczekiwać; czekać na; czekać; wyczekiwać; wyczekiwany | oczekiwać; czekać na; czekać; wyczekiwać | accepted |
| c07 | core.coincide | ex1.pl | Premiera książki została zaplanowana tak, żeby zbiegła się z filmem. | Premierę książki zaplanowano tak, żeby zbiegła się z premierą filmu. | pl |
| c07 | core.condemn | ex2 | The old building was condemned as unsafe. ‖ Stary budynek uznano za nienadający się do użytku. | Many parents condemned the decision to cancel the school bus. ‖ Wielu rodziców potępiło decyzję o likwidacji szkolnego autobusu. | sense |
| c07 | core.condemn | acceptedTranslations | potępiać; potępić; skazywać; skazać; uznać za nienadający się do użytku | potępiać; potępić | accepted |
| c07 | core.defy | ex0 | The teenagers defied their parents and went to the party anyway. ‖ Nastolatki sprzeciwiły się rodzicom i i tak poszły na imprezę. | The teenagers defied their parents and went to the party anyway. ‖ Nastolatki nie posłuchały rodziców i mimo to poszły na imprezę. | pl |
| c07 | core.demolish | ex2 | The kids demolished the whole pizza in five minutes. ‖ Dzieci w pięć minut zmiotły całą pizzę. | The lawyer demolished the witness's story in just ten minutes. ‖ Adwokat w dziesięć minut rozbił w puch zeznania świadka. | sense |
| c07 | core.demolish | acceptedTranslations | wyburzyć; wyburzać; zburzyć; rozebrać; zniszczyć; zmieść | wyburzyć; wyburzać; zburzyć; rozebrać; zniszczyć; rozbić w puch | accepted |
| c07 | core.disclose | ex2 | The house sold for an undisclosed amount. ‖ Dom sprzedano za nieujawnioną kwotę. | He didn't disclose the price, but it looked expensive. ‖ Nie zdradził ceny, ale wyglądało to na coś drogiego. | sense |
| c07 | core.disclose | acceptedTranslations | ujawnić; ujawniać; wyjawić; podać; podawać do wiadomości | ujawnić; ujawniać; wyjawić; zdradzić; podać; podawać do wiadomości | accepted |
| c07 | core.disguise-2 | ex1 | Losing that job was a blessing in disguise. ‖ Utrata tamtej pracy okazała się błogosławieństwem w nieszczęściu. | Losing that job was a blessing in disguise. ‖ Utrata tamtej pracy okazała się szczęściem w nieszczęściu. | pl |
| c07 | core.dwell | ex0.pl | Nie rozpamiętuj swoich błędów, po prostu wyciągnij z nich naukę. | Nie rozpamiętuj swoich błędów. Po prostu wyciągnij z nich wnioski. | pl |
| c07 | core.evoke | ex2 | The old photos didn't evoke anything for him. ‖ Stare zdjęcia nic mu nie przypominały. | The old photos didn't evoke any memories for him. ‖ Stare zdjęcia nie przywołały u niego żadnych wspomnień. | nat-en |
| c07 | core.foresee | ex2 | We don't plan to move in the foreseeable future. ‖ W dającej się przewidzieć przyszłości nie planujemy przeprowadzki. | I don't foresee any changes before next year. ‖ Nie przewiduję żadnych zmian przed przyszłym rokiem. | sense |
| c07 | core.grip | ex2.pl | To trzymający w napięciu film, przy którym do końca zgadujesz. | To trzymający w napięciu film, który do końca nie zdradza zakończenia. | pl |
| c07 | core.invoke | ex1.pl | Firma powołała się na klauzulę w umowie, żeby zerwać umowę. | Firma powołała się na klauzulę w umowie, żeby wycofać się z transakcji. | pl |
| c07 | core.lure | ex1 | The company lured her away from her old job with a higher salary. ‖ Firma podkupiła ją z poprzedniej pracy wyższą pensją. | The company lured her away from her old job with a higher salary. ‖ Firma podkupiła ją poprzedniemu pracodawcy, oferując wyższą pensję. | pl |
| c07 | core.overwhelm | ex1 | The kindness of strangers overwhelmed her. ‖ Życzliwość obcych ludzi ją przytłoczyła. | The kindness of strangers overwhelmed her. ‖ Życzliwość obcych ludzi głęboko ją poruszyła. | pl |
| c07 | core.overwhelm | acceptedTranslations | przytłaczać; przytłoczyć; zalewać; zalać; obezwładniać | przytłaczać; przytłoczyć; zalewać; zalać; obezwładniać; poruszyć | accepted |
| c07 | core.plead-2 | acceptedTranslations | przyznać się (w sądzie); przyznać się do winy; przyznać się; nie przyznać się | przyznać się (w sądzie); przyznać się do winy; przyznać się | accepted |
| c07 | core.prolong | ex2 | Prolonged exposure to the sun can damage your skin. ‖ Długotrwałe przebywanie na słońcu może uszkodzić skórę. | The doctors managed to prolong her life by several years. ‖ Lekarzom udało się przedłużyć jej życie o kilka lat. | sense |
| c07 | core.prolong | acceptedTranslations | przedłużać; przedłużyć; przeciągać; wydłużać; długotrwały | przedłużać; przedłużyć; przeciągać; wydłużać | accepted |
| c07 | core.prosper | ex0.pl | Miasteczko rozkwitło po przyjściu kolei. | Miasteczko rozkwitło, gdy dotarła do niego kolej. | pl |
| c07 | core.retreat-2 | acceptedTranslations | wyjazd (integracyjny); wyjazd; odskocznia; zacisze; azyl; odwrót | wyjazd (integracyjny); wyjazd; odskocznia; zacisze; azyl | accepted |
| c07 | core.stumble | definition | To almost fall while walking, or to make mistakes when speaking. | To almost fall while walking, to make mistakes when speaking, or (stumble across) to find something by chance. | other |
| c07 | core.surrender | ex2 | The document marks the surrender of the city. ‖ Ten dokument upamiętnia kapitulację miasta. | The judge ordered the surrender of his passport. ‖ Sędzia nakazał mu oddanie paszportu. | nat-en |
| c07 | core.sway | ex2 | The good reviews swayed us to try the new restaurant. ‖ Dobre recenzje przekonały nas do wypróbowania nowej restauracji. | In the end, the low price swayed us. ‖ Ostatecznie przekonała nas niska cena. | nat-en |
| c07 | core.thrive | ex0 | Some people really thrive on stress and deadlines. ‖ Niektórzy ludzie świetnie funkcjonują pod presją i terminami. | Some people really thrive on stress and deadlines. ‖ Niektórzy ludzie najlepiej funkcjonują pod presją i przy napiętych terminach. | pl |
| c07 | core.unfold | ex0 | We watched the news as events unfolded. ‖ Oglądaliśmy wiadomości, kiedy rozgrywały się wydarzenia. | We watched the news as events unfolded. ‖ Oglądaliśmy wiadomości i patrzyliśmy, jak rozwijają się wydarzenia. | pl |
| c07 | core.utter | ex1 | She uttered a quiet "thank you" and left. ‖ Wymamrotała ciche „dziękuję” i wyszła. | She uttered a quiet "thank you" and left. ‖ Powiedziała cicho „dziękuję” i wyszła. | pl |
| c07 | core.utter | ex2 | Nobody uttered a sound while the judge spoke. ‖ Nikt nie wydał dźwięku, kiedy mówił sędzia. | Nobody uttered a sound while the judge spoke. ‖ Kiedy mówił sędzia, nikt nie wydał z siebie żadnego dźwięku. | pl |
| c07 | core.accustomed | ex1 | She's accustomed to working long hours. ‖ Jest przyzwyczajona do pracy po wiele godzin. | She's accustomed to working long hours. ‖ Jest przyzwyczajona do długiego dnia pracy. | pl |
| c07 | core.compassionate | ex1 | He was given compassionate leave after his father died. ‖ Po śmierci ojca dostał urlop okolicznościowy. | Thank you for being so compassionate when my dad died. ‖ Dziękuję, że byłeś tak wyrozumiały, kiedy zmarł mój tata. | nat-en |
| c07 | core.compassionate | collocations | a compassionate person; compassionate leave; compassionate care | a compassionate person; compassionate care; a compassionate response | nat-en |
| c07 | core.conscientious | ex2.pl | Rozważny kierowca zawsze patrzy w lusterka. | Sumienny kierowca zawsze sprawdza lusterka. | pl |
| c07 | core.conscientious | ex2.focusPl | Rozważny | Sumienny | pl |
| c07 | core.eternal | forms | more eternal – most eternal |  | forms |
| c07 | core.eternal | ex2.pl | Odwieczne pytanie w naszym domu to, co zjeść na kolację. | Odwieczne pytanie w naszym domu brzmi: co zjeść na kolację? | pl |
| c07 | core.flawless | ex0.pl | Gimnastyczka dała bezbłędny występ. | Gimnastyczka wykonała bezbłędny układ. | pl |
| c07 | core.graceful | ex2 | He made a graceful exit after losing the election. ‖ Po przegranych wyborach wycofał się z klasą. | He made a graceful exit after losing the final. ‖ Po przegranym finale pożegnał się z klasą. | other |
| c07 | core.infamous | ex2 | My uncle's infamous chili is way too spicy. ‖ Słynne chili mojego wujka jest o wiele za ostre. | My uncle's infamous chili is way too spicy. ‖ Osławione chili mojego wujka jest o wiele za ostre. | pl |
| c07 | core.infamous | acceptedTranslations | osławiony; niesławny; owiany złą sławą; słynący z; słynny | osławiony; niesławny; owiany złą sławą; słynący z | accepted |
| c07 | core.knowledgeable | ex2 | Ask Tom because he's the most knowledgeable person about computers. ‖ Zapytaj Toma, bo on najlepiej zna się na komputerach. | Ask Tom. He's the most knowledgeable person here about computers. ‖ Zapytaj Toma. On najlepiej zna się tu na komputerach. | nat-en |
| c07 | core.monotonous | acceptedTranslations | monotonny; nudny; jednostajny; jednolity | monotonny; nudny; jednostajny | accepted |
| c07 | core.notorious | translation | notoryczny | osławiony | pl |
| c07 | core.notorious | acceptedTranslations | notoryczny; znany z czegoś złego; słynący z; osławiony; mający złą sławę | osławiony; znany z czegoś złego; słynący z; mający złą sławę; niesławny | accepted |
| c07 | core.robust | ex1 | My grandfather is in robust health at ninety. ‖ Mój dziadek w wieku dziewięćdziesięciu lat cieszy się dobrym zdrowiem. | My grandfather is in robust health at ninety. ‖ Mój dziadek w wieku dziewięćdziesięciu lat cieszy się doskonałym zdrowiem. | pl |
| c07 | core.swift | ex0.pl | Dziękuję za szybką odpowiedź. | Dziękujemy za szybką odpowiedź. | other |
| c07 | core.vain | ex2 | Don't be vain about your talent. ‖ Nie bądź zarozumiały z powodu swojego talentu. | Is he really that vain about his looks? ‖ Czy on naprawdę jest aż tak próżny, jeśli chodzi o wygląd? | nat-en |
| c07 | core.notable | ex1.pl | Na przyjęcie przyszli wszyscy z jednym znaczącym wyjątkiem. | Na przyjęcie przyszli wszyscy, z jednym znaczącym wyjątkiem. | pl |
| c07 | core.stingy | ex1 | The restaurant is a bit stingy with the portions. ‖ Ta restauracja trochę skąpi na porcjach. | The restaurant is a bit stingy with the portions. ‖ Ta restauracja trochę oszczędza na porcjach. | pl |
| c07 | core.well-being | ex2 | A walk in the park gives me a sense of well-being. ‖ Spacer po parku daje mi poczucie dobrego samopoczucia. | A walk in the park gives me a sense of well-being. ‖ Spacer po parku poprawia mi samopoczucie. | pl |
| c07 | core.inflate | ex1 | We inflated fifty balloons for the party. ‖ Napompowaliśmy na przyjęcie pięćdziesiąt balonów. | We inflated fifty balloons for the party. ‖ Nadmuchaliśmy na przyjęcie pięćdziesiąt balonów. | pl |
| c07 | core.inflate-2 | ex2 | Success has given him an inflated ego. ‖ Sukces wybujał mu ego. | Success has given him an inflated ego. ‖ Przez sukces ma wybujałe ego. | pl |
| c07 | core.shed | ex2 | Can you shed some light on what happened? ‖ Możesz rzucić trochę światła na to, co się stało? | The company plans to shed two hundred jobs next year. ‖ Firma planuje w przyszłym roku zlikwidować dwieście miejsc pracy. | sense |
| c07 | core.shed | acceptedTranslations | pozbyć się; zrzucić; zrzucać; gubić; ronić (łzy); rzucić światło na | pozbyć się; zrzucić; zrzucać; gubić; zlikwidować | accepted |
| c07 | core.blunt | ex0.pl | Mówiąc wprost, nie sądzę, że twój plan się uda. | Mówiąc wprost, nie sądzę, żeby twój plan się udał. | pl |
| c07 | core.idle | ex1 | Don't leave your engine idle while you wait. ‖ Nie zostawiaj włączonego silnika na postoju, kiedy czekasz. | Thousands of workers were left idle by the strike. ‖ Przez strajk tysiące pracowników zostały bez zajęcia. | gram-en |
| c07 | core.idle | collocations | sit idle; stand idle; idle engine; idle chatter | sit idle; stand idle; idle machines; idle chatter | gram-en |
| c07 | core.idle | contextPl | O stojących maszynach, bezczynnych ludziach i silniku na biegu jałowym | O stojących maszynach, bezczynnych ludziach i niewykorzystanym czasie | gram-en |
| c07 | core.idle | acceptedTranslations | bezczynny; bezczynnie; nieużywany; nieczynny; jałowy | bezczynny; bezczynnie; nieużywany; nieczynny; bez zajęcia | accepted |
| c07 | core.incapable | acceptedTranslations | niezdolny; niezdolna; nie potrafić; nie być w stanie; nieudolny | niezdolny; niezdolna; nie potrafić; nie być w stanie | accepted |
| c07 | core.lasting | ex0 | She made a lasting impression on everyone at the interview. ‖ Na rozmowie zrobiła na wszystkich trwałe wrażenie. | She made a lasting impression on everyone at the interview. ‖ Na rozmowie zrobiła na wszystkich niezatarte wrażenie. | pl |
| c07 | core.lasting | ex2.pl | Potrzebujemy trwałego rozwiązania, a nie doraźnej łatki. | Potrzebujemy trwałego rozwiązania, a nie prowizorki. | pl |
| c07 | core.lifelong | ex2 | She's a lifelong fan of the Chicago Cubs. ‖ Od zawsze kibicuje drużynie Chicago Cubs. | She's a lifelong fan of the local baseball team. ‖ Od zawsze kibicuje miejscowej drużynie baseballowej. | other |
| c07 | core.mandatory | ex0.pl | Szkolenie BHP jest obowiązkowe dla wszystkich nowych pracowników. | Szkolenie BHP jest obowiązkowe dla każdego nowego pracownika. | other |
| c07 | core.premature | ex0 | It's premature to say who will win the election. ‖ Jest za wcześnie, żeby mówić, kto wygra wybory. | It's premature to say who will win the championship. ‖ Jest za wcześnie, żeby mówić, kto zdobędzie mistrzostwo. | other |
| c07 | core.pushy | acceptedTranslations | natarczywy; nachalny; namolny; przebojowy; naciskać | natarczywy; nachalny; namolny; naciskać | accepted |
| c07 | core.vocal | acceptedTranslations | głośno wyrażający zdanie; głośny; otwarcie krytykujący; głośno; wokalny | głośno wyrażający zdanie; głośny; otwarcie krytykujący; głośno | accepted |
| c07 | core.confession | ex1 | The suspect made a full confession. ‖ Podejrzany złożył pełne wyznanie. | The suspect made a full confession. ‖ Podejrzany w pełni przyznał się do winy. | pl |
| c07 | core.denial | acceptedTranslations | zaprzeczenie; dementi; zdementować; zaprzeczyć; odmowa | zaprzeczenie; dementi; zdementować; zaprzeczyć | accepted |
| c07 | core.usage | notePl | Usage zużycia prądu czy danych to zużycie (data usage). | Przy prądzie, wodzie czy danych usage to zużycie (data usage = zużycie danych). | other |
| c07 | core.destiny | ex0.pl | Wierzysz w przeznaczenie, czy wszystko to tylko przypadek? | Wierzysz w przeznaczenie czy wszystko to tylko przypadek? | pl |
| c07 | core.nostalgia | ex2.pl | To tylko nostalgia, czy kiedyś naprawdę było lepiej? | To tylko nostalgia czy kiedyś naprawdę było lepiej? | pl |
| c07 | core.peculiar | ex1.pl | Miałem dziwne uczucie, że ktoś mnie obserwuje. | Miałem dziwne wrażenie, że ktoś mnie obserwuje. | other |
| c08 | core.exhaustion | ex2.pl | To prawdziwe wyczerpanie, czy po prostu potrzebujesz wolnego weekendu? | To prawdziwe wyczerpanie czy po prostu potrzebujesz wolnego weekendu? | pl |
| c08 | core.interference | ex2 | The referee's decision was final, with no interference allowed. ‖ Decyzja sędziego była ostateczna i nie dopuszczano żadnej ingerencji. | I don't appreciate your interference in my private life. ‖ Nie życzę sobie, żebyś wtrącał się w moje prywatne życie. | nat-en |
| c08 | core.irritation-2 | ex2 | Does the new soap give you any irritation? ‖ Czy to nowe mydło cię podrażnia? | Does the new soap cause any irritation? ‖ Czy nowe mydło powoduje jakieś podrażnienia? | nat-en |
| c08 | core.superstition | ex3 | The hotel doesn't have a thirteenth floor, out of superstition. ‖ Hotel nie ma trzynastego piętra, z przesądu. | The hotel doesn't have a thirteenth floor, out of superstition. ‖ Hotel z przesądu nie ma trzynastego piętra. | pl |
| c08 | core.vulnerability | ex2 | Older people have a greater vulnerability to the flu. ‖ Osoby starsze są bardziej podatne na grypę. | Older people have a greater vulnerability to the flu. ‖ Osoby starsze wykazują większą podatność na grypę. | pl |
| c08 | core.vulnerability | acceptedTranslations | bezbronność; wrażliwość; słabość; podatność; podatny | bezbronność; wrażliwość; słabość; podatność | accepted |
| c08 | core.hunch | ex3.pl | To było tylko przeczucie, czy ktoś ci powiedział? | To było tylko przeczucie czy ktoś ci powiedział? | pl |
| c08 | core.solitude | acceptedTranslations | samotność; odosobnienie; samotnia; bycie samemu | samotność; odosobnienie; bycie samemu | accepted |
| c08 | core.discrete | acceptedTranslations | odrębny; oddzielny; osobny; dyskretny | odrębny; oddzielny; osobny | accepted |
| c08 | core.innate | ex2.pl | Czy zdolność uczenia się języków jest wrodzona, czy nabyta? | Czy zdolność uczenia się języków jest wrodzona czy nabyta? | pl |
| c08 | core.sensory | translation | zmysłowy | sensoryczny | pl |
| c08 | core.sensory | acceptedTranslations | zmysłowy; sensoryczny; czuciowy | sensoryczny; zmysłowy; czuciowy; związany ze zmysłami | accepted |
| c08 | core.albeit | ex2 | We finally found an apartment, albeit a very small one. ‖ W końcu znaleźliśmy mieszkanie, wprawdzie bardzo małe. | We finally found an apartment, albeit a very small one. ‖ W końcu znaleźliśmy mieszkanie, chociaż bardzo małe. | pl |
| c08 | core.candid | ex1 | To be candid, I don't think the plan will work. ‖ Szczerze mówiąc, nie sądzę, żeby ten plan się udał. | To be candid, I don't think the plan will work. ‖ Mówiąc szczerze, nie sądzę, żeby ten plan się udał. | other |
| c08 | core.complacent | acceptedTranslations | zbyt pewny siebie; zadowolony z siebie; popadać w samozadowolenie; osiadać na laurach; tracić czujność; uśpiony | zbyt pewny siebie; zadowolony z siebie; popadać w samozadowolenie; osiadać na laurach; tracić czujność | accepted |
| c08 | core.exemplify | ex2 | Can you exemplify this rule with a sentence of your own? ‖ Czy możesz zilustrować tę zasadę własnym zdaniem? | Her career exemplifies what hard work can achieve. ‖ Jej kariera jest przykładem tego, co można osiągnąć ciężką pracą. | nat-en |
| c08 | core.inadvertently | ex2 | The new rules may inadvertently hurt small businesses. ‖ Nowe przepisy mogą mimowolnie zaszkodzić małym firmom. | The new rules may inadvertently hurt small businesses. ‖ Nowe przepisy mogą niezamierzenie zaszkodzić małym firmom. | pl |
| c08 | core.inadvertently | acceptedTranslations | niechcący; nieumyślnie; przypadkowo; mimowolnie; bezwiednie | niechcący; nieumyślnie; przypadkowo; niezamierzenie; mimowolnie; bezwiednie | accepted |
| c08 | core.intrinsic | acceptedTranslations | wewnętrzny; nieodłączny; samoistny; wrodzony; istotny | wewnętrzny; nieodłączny; samoistny; wrodzony | accepted |
| c08 | core.perpetual | forms | more perpetual – most perpetual |  | forms |
| c08 | core.precarious | ex1 | A tower of plates stood in a precarious pile next to the sink. ‖ Obok zlewu stała chwiejna wieża talerzy. | The plates were stacked in a precarious pile next to the sink. ‖ Talerze stały obok zlewu w chwiejnym stosie. | nat-en |
| c08 | core.lenient | ex0 | My parents were much more lenient with my little brother. ‖ Moi rodzice byli dużo bardziej pobłażliwi dla mojego młodszego brata. | My parents were much more lenient with my little brother. ‖ Moi rodzice byli dużo bardziej pobłażliwi wobec mojego młodszego brata. | pl |
| c08 | core.strenuous | ex0 | Avoid strenuous exercise for a week after the surgery. ‖ Przez tydzień po operacji unikaj forsownego wysiłku. | Avoid strenuous activity for a few days after the vaccine. ‖ Przez kilka dni po szczepieniu unikaj forsownego wysiłku. | other |
| c08 | core.impede | ex2 | Nothing should impede the ambulance on its way to the hospital. ‖ Nic nie powinno hamować karetki w drodze do szpitala. | Nothing should impede the ambulance on its way to the hospital. ‖ Nic nie powinno utrudniać przejazdu karetki do szpitala. | pl |
| c08 | core.conspicuous | ex0 | Put the sign in a conspicuous place near the door. ‖ Umieść tabliczkę w widocznym miejscu przy drzwiach. | Put the sign in a conspicuous place near the door. ‖ Umieść tabliczkę przy drzwiach w dobrze widocznym miejscu. | other |
| c08 | core.deride | ex1.pl | Krytycy wyśmiali film jako nudny i za długi. | Krytycy wyśmiali film, nazywając go nudnym i za długim. | pl |
| c08 | core.fervent | ex0 | It's my fervent hope that we'll all meet again next summer. ‖ Gorąco wierzę, że wszyscy spotkamy się znowu przyszłego lata. | It's my fervent hope that we'll all meet again next summer. ‖ Mam gorącą nadzieję, że wszyscy spotkamy się znowu przyszłego lata. | pl |
| c08 | core.frivolous | acceptedTranslations | błahy; niepoważny; lekkomyślny; frywolny; bezzasadny; zbędny | błahy; niepoważny; lekkomyślny; frywolny; bezzasadny | accepted |
| c08 | core.frivolous | ex1.pl | Sąd oddalił pozew jako bezzasadny. | Sąd oddalił pozew, uznając go za bezzasadny. | pl |
| c08 | core.hypocrisy | ex0.pl | To czysta hipokryzja zabraniać dzieciom telefonów, a samemu korzystać z niego cały dzień. | To czysta hipokryzja zabraniać dzieciom telefonów, a samemu nie wypuszczać swojego z ręki przez cały dzień. | pl |
| c08 | core.idiosyncratic | ex1 | My uncle has some idiosyncratic habits, like eating dessert first. ‖ Mój wujek ma kilka osobliwych nawyków, na przykład je deser na początku. | My uncle has some idiosyncratic habits, like reading the newspaper backward. ‖ Mój wujek ma kilka osobliwych nawyków, na przykład czyta gazetę od końca. | other |
| c08 | core.overt | ex2 | The ad doesn't use overt sales language. ‖ Ta reklama nie posługuje się wprost językiem sprzedażowym. | The ad doesn't use overt sales language. ‖ Ta reklama nie posługuje się jawnie sprzedażowym językiem. | pl |
| c08 | core.overt | acceptedTranslations | jawny; otwarty; widoczny; nieukrywany; wprost | jawny; otwarty; widoczny; nieukrywany; jawnie | accepted |
| c08 | core.skewed | ex2 | Isn't the prize list a little skewed toward older players? ‖ Czy lista nagród nie faworyzuje trochę starszych zawodników? | Isn't the schedule a little skewed toward morning people? ‖ Czy ten grafik nie jest trochę ustawiony pod rannych ptaszków? | nat-en |
| c08 | core.stagnant | ex2 | Don't let the water in the bird bath get stagnant. ‖ Nie pozwól, żeby woda w poidełku dla ptaków się zastała. | Don't let the water in the bird bath get stagnant. ‖ Nie pozwól, żeby woda w poidełku dla ptaków zrobiła się stęchła. | pl |
| c08 | core.tantamount | acceptedTranslations | równoznaczny; równoznaczny z; jednoznaczny z; równający się; właściwie | równoznaczny; równoznaczny z; jednoznaczny z; równający się | accepted |
| c08 | core.meager | acceptedTranslations | skromny; skąpy; marny; niewielki; niewystarczający | skromny; skąpy; marny; nędzny; niewielki; niewystarczający | accepted |
| c08 | core.paltry | acceptedTranslations | marny; nędzny; śmieszny; żałosny; mizerny | marny; nędzny; skromny; śmieszny; żałosny; mizerny | accepted |