# Raport: english-qa, słownik rdzeniowy — zakres core-qa-1 (core-c01.json, core-c02.json)

## 1. Co zrobiono

Pliki (tylko te dwa): `ios/FluentNOW/Resources/Content/core/core-c01.json`, `ios/FluentNOW/Resources/Content/core/core-c02.json`.

Przejrzałem ręcznie każdy wpis i każdy przykład: gramatykę i naturalność AmE, zgodność przykładu ze znaczeniem i częścią mowy, `focusEn`/`focusPl`, polskie tłumaczenia, `acceptedTranslations`/`acceptedAnswers`, IPA (porównanie z całą bazą), CEFR, `forms`, kompletność znaczeń najczęstszych haseł. Pracowałem na kompaktowych widokach (skrypt Node, porcje po 40 wpisów). Poprawki wprowadzał skrypt z listą operacji: plik jest parsowany i zapisywany z powrotem tym samym formatowaniem (test round-trip bajt w bajt przed zmianami: OK). Liczba zmienionych linii zgadza się z liczbą zmian (c01: 137 zmian pól → 119 linii, bo kilka zmian trafiło w ten sam przykład; c02: 68 → 62). Dopisane wpisy wydłużyły pliki o 344 i 27 linii. `id` istniejących wpisów nie zmieniałem.

| | core-c01 | core-c02 | razem |
|---|---|---|---|
| Wpisy sprawdzone | 553 | 525 | **1078** |
| Przykłady sprawdzone | 2271 | 1937 | **4208** |
| Wpisy poprawione | 98 (17,7%) | 47 (9,0%) | 145 (13,5%) |
| — w tym z błędem merytorycznym (EN, PL, znaczenie, focus, IPA) | 51 (9,2%) | 30 (5,7%) | 81 (7,5%) |
| — w tym błąd po stronie angielskiej (gramatyka, naturalność, przykład w innym znaczeniu) | 21 (3,8%) | 13 (2,5%) | 34 (3,2%) |
| Zmienione pola | 137 | 68 | 205 |
| Dopisane znaczenia (nowe wpisy) | 13 (58 przykładów) | 1 (5 przykładów) | 14 |
| Wpisy po zmianach | 566 | 526 | 1092 |
| Walidator `--file` | 0 błędów, 0 ostrzeżeń | 0 błędów, 0 ostrzeżeń | |

Ocena autorów: C02 jest wyraźnie czystszy (5,7% wpisów z błędem merytorycznym) niż C01 (9,2%). W obu plikach angielski jest na ogół bardzo dobry. Najczęstszy problem to `acceptedTranslations` mieszające znaczenia lub części mowy. Przy hasłach `check` autor C01 kilka razy błędnie uznał, że ogólne znaczenie już jest w bazie.

## 2. Poprawki według kategorii

| Kategoria | c01 (wpisy / pola) | c02 (wpisy / pola) | Przykłady |
|---|---|---|---|
| `acceptedTranslations`/`acceptedAnswers` mieszające znaczenia lub części mowy | 59 / 60 | 24 / 24 | other „kiedy indziej”; check „zapytać”; kill „zginąć”; drop „podrzucić”; pick „odebrać, podnieść”; order „nieczynny; żeby”; site „budowa; strona”; heat „podgrzanie”; threat „grozić”; leadership „przywódczy”; little bez „a little” w AA |
| Polskie tłumaczenia (kalki, szyk, interpunkcja, błędna rekcja) | 25 / 43 | 10 / 16 | „pojechać do Florydy” → „na Florydę”; „Brzmisz na zmęczonego” → „Masz zmęczony głos”; „nie są koniecznie lepsze” → „niekoniecznie są lepsze”; „kompletnym marnowaniem pieniędzy” → „kompletną stratą pieniędzy”; „duża obecność policji” → „liczne siły policji”; brak przecinka po „Ogólnie rzecz biorąc”; „nie da się się obyć” (podwójne „się”) |
| Naturalność EN (AmE) | 10 / 11 | 11 / 17 | „The test wasn't a bit difficult” (BrE, dwuznaczne) → nowe zdanie; „It's not mostly/mainly about the money” → nowe zdania; „public transport” → przykłady z „transport” w sensie przewozu (AmE: public transportation); „Please take a chair” → „pull up a chair”; „by error” → „in error”; „stop signal” → „signal to stop”; „only local money” → „the local currency” |
| Przykład w innym znaczeniu lub innej części mowy | 9 / 10 | 1 / 1 | only (przysłówek) z przykładem przymiotnikowym „the only reason”; pick („wybrać”) z „pick you up”; set („ustawić”) z „setting up an office”; clear („sprzątnąć”) z „cleared up” o pogodzie; behind (przyimek) z „behind by ten points”; drop („upuścić”) z „drop me off”; figure-3 z dwoma przykładami „figure out”; order z „in order to”; serve z obsługą klientów; opposite (przymiotnik) z rzeczownikiem „the opposite of” |
| Gramatyka EN | 2 / 2 | 1 / 1 | „All together, the trip cost…” (powinno być *altogether*) → nowe zdanie; syn. „travelling” (BrE) → „traveling”; „settled in to your apartment” → „settled into” |
| `focusEn`/`focusPl` niepełne | — | 6 / 8 | emerge „na jaw” → „Wyszły na jaw”; somewhere „somewhere” → „somewhere else”; hardly: „prawie” → „prawie nie / prawie wcale / prawie w ogóle”; interview „interviewed” → „being interviewed” |
| `forms` (konwencja) | 6 / 6 | — | while-2, past, public, press: „(lp.)” → „… (tylko lp.)”; sense-2 „(lp.)” → „(niepoliczalny)”; point-2 „(niepoliczalny)” → „points” |
| IPA | — | 1 / 1 | beyond /biˈɑːnd/ → /bɪˈjɑːnd/ |
| Inne (powtórzenia zdań między hasłami, uwaga redakcyjna) | 5 / 5 | — | put/back: prawie to samo zdanie o mleku; late/work: to samo polskie zdanie; mind/care: „Do you mind/care if I open the window?”; enough-2/old: „not old enough to drive”; public: dwa razy „open to the public” |

IPA: wszystkie transkrypcje porównałem automatycznie z całą bazą (tematy, startery, inne shardy). Różnice dotyczą wyłącznie innej części mowy i są poprawne (live v. /lɪv/, close v. /kloʊz/, increase n. /ˈɪnkriːs/, present v. /prɪˈzent/, produce v., address v., separate adj., decrease n., combine v., suspect v., conduct n.). To samo hasło w tej samej części mowy ma w C01/C02 wszędzie tę samą transkrypcję. Nie znalazłem `ɝ ɚ ɛ`, `-ʃn`, `n̩`.

CEFR: nie zmieniałem. Poziomy są uczciwe i spójne z bazą, a autorskie zmiany względem listy (np. *get* „rozumieć” B1, *state* „stwierdzić” B2) są uzasadnione.

## 3. Dopisane znaczenia (kompletność najczęstszych haseł)

Przejrzałem znaczenia wszystkich haseł z list roboczych C01 i C02 (`build-core-master.mjs --shard … --all`, tylko odczyt) na tle całej bazy. Wpisy z czasownikami *get, take, make, go, have, keep, set, run, leave, see, look, give, turn, break, hold* mają w core lub bazie wszystkie główne znaczenia ogólne. Brakowało tych 14, każde jest częste, poziom A1–B2 (wpisy na końcu kategorii swojego poziomu, 4–5 przykładów, pytanie lub przeczenie w każdym):

| id | hasło | część mowy | CEFR | tłumaczenie | co było w bazie |
|---|---|---|---|---|---|
| core.game | game | rzeczownik | A1 | gra | tylko „mecz” |
| core.area | area | rzeczownik | A2 | okolica, obszar | tylko „pole powierzchni” (math) |
| core.call-2 | call | czasownik | A2 | nazywać, nazwać | tylko „dzwonić” i „rozmowa telefoniczna” |
| core.back-2 | back | przymiotnik | A2 | tylny | plecy, z powrotem, wesprzeć |
| core.right-5 | right | przysłówek | A2 | tuż, dokładnie (right here/now/after) | poprawny, prawy, w prawo, prawo |
| core.piece | piece | rzeczownik | A2 | kawałek | tylko „praca” (art-museum) |
| core.rest | rest | rzeczownik | A2 | reszta (the rest of) | tylko „odpoczynek”/„odpocząć” |
| core.hand | hand | czasownik | A2 | podać, wręczyć | tylko rzeczownik |
| core.take-4 | take | czasownik | A2 | przyjąć, przyjmować (karty, pracę, rezerwacje) | brać, zabrać, zająć (czas) |
| core.show-2 | show | rzeczownik | A2 | program, przedstawienie | tylko „koncert” |
| core.room | room | rzeczownik | B1 | miejsce (przestrzeń) | tylko „pokój” |
| core.related | related | przymiotnik | B1 | związany (z czymś) | tylko „spokrewniony” |
| core.claim | claim | czasownik | B2 | twierdzić | tylko „zgłoszenie szkody”, „odliczyć” |
| core.dream-3 | dream | rzeczownik | A2 | marzenie | tylko „sen” (rzeczownik), śnić, marzyć |

Rozważone, ale niedopisane (rzadsze albo częściowo pokryte): *run* „kursować”, *position* „pozycja”, *service* „usługa”, *head* „szef”, *turn* „stać się”, *close* „blisko” (jest zwrot `close to`), *couple* „parę” (jest zwrot `a couple of`), *come from* (jest w temacie), *right away* (jest w C04).

## 4. Najważniejsze poprawki (te, które uczeń by zapamiętał)

1. **core.together**: „All together, the trip cost about two thousand dollars.” → błąd *all together* / *altogether*. Zastąpione przez „It's so nice to have the whole family together again.” (usunięte też AT „w sumie”).
2. **core.bit**: „The test wasn't a bit difficult.” w AmE brzmi jak „wcale nie był trochę trudny” (BrE *not a bit* = wcale). Zastąpione przez „Could you turn the music down a bit?”. Poprawiona też notatka.
3. **core.pick**, **core.set**, **core.clear-3**, **core.drop**, **core.order**, **core.serve**, **core.figure-3**: przykłady z czasownikami frazowymi lub innym znaczeniem (*pick up, set up, clear up, drop off, in order to*, obsługa klientów, *figure out*). Wymienione na przykłady z hasłem w opisywanym znaczeniu.
4. **core.only**, **core.behind**, **core.opposite**: przykład z inną częścią mowy niż wpis.
5. **core.transport**: przykłady z „public transport” (BrE). Teraz przykłady z przewozem (*air transport, the transport of the furniture*) i nota o AmE *public transportation* (`core.transportation` jest w C04).
6. **core.plan**: „pojechać do Florydy” → „na Florydę”. **core.sound**: kalka „Brzmisz na zmęczonego” → „Masz zmęczony głos”. **core.necessarily**: „nie są koniecznie lepsze” → „niekoniecznie są lepsze”.
7. **core.perhaps**: „It wasn't perhaps the best idea.” (zły szyk) → „That perhaps wasn't the best idea.”. **core.settle**: „settled in to your new apartment” → „settled into”.
8. **core.mostly**, **core.mainly**, **core.extremely**: nienaturalne przeczenia („It's not mostly about money”, „weren't extremely friendly”) → naturalne pytania.
9. **acceptedTranslations**: 83 wpisy oczyszczone z odpowiedników innych znaczeń lub fraz (np. *kill* „zginąć”, *check* „zapytać”, *air* „lotniczo”, *real* „prawdziwie”, *vote* „zagłosować”, *conclude* „wniosek”). Grader nie przyjmie już np. „zginąć” jako tłumaczenia *kill*.
10. **core.beyond**: IPA /biˈɑːnd/ → /bɪˈjɑːnd/ (GA, jak /bɪ-/ w *before*).

Pełna tabela zmian: §7.

## 5. Wątpliwości (nierozstrzygnięte)

- **series** /ˈsɪriːz/ (C02). Autor C02 prosił o ujednolicenie z `topics/movies-tv.json`. Automat nie wykazał tam hasła `series` o innej transkrypcji (hasło w temacie ma inną postać), więc zostawiłem tak, jak jest. Oxford US podaje /ˈsɪriz/. Decyzja należy do content-final.
- **proceed** /proʊˈsiːd/ (częściej /prəˈsiːd/) i **toward** /tɔːrd/ (też /təˈwɔːrd/): oba warianty są poprawne GA, więc zostawiłem.
- **Tłumaczenia z nawiasem** („przez (kogoś)”, „zająć (czas)”, „prosty (łatwy)”, „miejsce (przestrzeń)”): zostawione zgodnie z briefem. Wariant bez nawiasu jest zawsze w AT. Jeśli UI pokazuje `translation` dosłownie, decyzja po stronie UI.
- **Celowa zmiana części mowy w AT** (np. *back* → „wrócić, oddać”, *fun* → „bawić się”, *aware* → „zdawać sobie sprawę”): zostawiona tam, gdzie wynika z najlepszego polskiego odpowiednika (zgodnie ze standardem 03b). Usunąłem tylko pozycje, które były tłumaczeniem innej frazy.
- **Polskie bezosobowe „bank otwierają o dziewiątej”, „sklep zamykają”**: potoczne i poprawne, zostawione.
- **core.transport**: `frequency` zostawiłem `common`. W AmE rzeczownik w tym znaczeniu jest raczej `less_common`.
- **Nowe wpisy** są dopisane na końcu kategorii swojego poziomu, a nie według kolejności z listy częstości. Jeśli kolejność ma znaczenie, przestawi ją `build-core-master`/koordynator.
- Na początku pracy i przy jednym sprawdzeniu omyłkowo uruchomiłem dwa polecenia git tylko do odczytu (`status`, `show`). Niczego nie zmieniły.

## 6. Prośby do innych ról

- **Koordynator / core-pipeline**: po fali uruchomić `build-index.mjs` i `build-core-master.mjs` (nie uruchamiałem), potem pełne `validate-content.mjs`. Nowe wpisy: core.game, area, call-2, back-2, right-5, piece, rest, hand, take-4, show-2, room, related, claim (C01) i dream-3 (C02).
- **content-final / english-qa tematów** (poza moim zakresem, z raportu C01): `topics/directions.json` → `directions.far` ma `pos` przymiotnik przy znaczeniu „daleko”.
- **Autorzy C03–C08**: przy hasłach `check` sprawdzać tłumaczenia, nie tylko obecność hasła w bazie. Wiele haseł ma w bazie tylko wąskie znaczenie tematyczne (*area* = pole powierzchni, *piece* = dzieło sztuki, *game* = mecz).

## 7. Tabela zmian

`plik | id | pole | było | jest | kategoria` (dopisane wpisy: §3; `exN` = przykład N od zera, „‖” rozdziela EN i PL).

| plik | id | pole | było | jest | kategoria |
|---|---|---|---|---|---|
| c01 | core.also | ex2.pl | Ja też nie jestem pewien daty. | Nie jestem też pewien daty. | pl |
| c01 | core.other | acceptedTranslations | inny; pozostały; kiedy indziej | inny; pozostały | accepted |
| c01 | core.only | ex3 | Is that the only reason you called? ‖ To jedyny powód, dla którego zadzwoniłeś? | Don't worry. It only takes five minutes. ‖ Nie martw się. To zajmie tylko pięć minut. | sense |
| c01 | core.little | acceptedAnswers | little; a little bit | little; a little; a little bit | accepted |
| c01 | core.put | ex1 | Put the milk back in the fridge, please. ‖ Wstaw, proszę, mleko z powrotem do lodówki. | Put the groceries on the counter, please. ‖ Połóż, proszę, zakupy na blacie. | other |
| c01 | core.interested | acceptedTranslations | zainteresowany; interesować się; ciekawy | zainteresowany; interesować się | accepted |
| c01 | core.interested | ex2.pl | Bardzo chce nauczyć się gotować. | Jest bardzo zainteresowana nauką gotowania. | pl |
| c01 | core.interested | ex2.focusPl | Bardzo chce | bardzo zainteresowana | pl |
| c01 | core.late | ex0 | I worked late every day last week. ‖ W zeszłym tygodniu codziennie pracowałem do późna. | My dad often works late on Fridays. ‖ Tata w piątki często pracuje do późna. | other |
| c01 | core.plan | ex1.pl | Planujemy pojechać do Florydy w marcu. | Planujemy w marcu pojechać na Florydę. | pl |
| c01 | core.love | ex3.pl | Film nie zachwycił jej, ale podobała jej się muzyka. | Film jej nie zachwycił, ale podobała jej się muzyka. | pl |
| c01 | core.together | ex4 | All together, the trip cost about two thousand dollars. ‖ W sumie wycieczka kosztowała około dwóch tysięcy dolarów. | It's so nice to have the whole family together again. ‖ Tak miło, że cała rodzina znowu jest razem. | gram-en |
| c01 | core.together | acceptedTranslations | razem; wspólnie; w sumie | razem; wspólnie | accepted |
| c01 | core.center | acceptedTranslations | centrum, środek; centrum; środek; ośrodek; dom kultury | centrum, środek; centrum; środek; ośrodek | accepted |
| c01 | core.walk | ex3.pl | Nie wracaj do domu sama tak późno. | Nie wracaj sama pieszo do domu tak późno. | pl |
| c01 | core.walk | ex3.focusPl | Nie wracaj do domu | Nie wracaj sama pieszo do domu | pl |
| c01 | core.difficult | ex0.pl | Japoński to trudny do nauczenia się język. | Japoński to trudny język do nauki. | pl |
| c01 | core.check | acceptedTranslations | sprawdzić, sprawdzać; sprawdzić; sprawdzać; skontrolować; zapytać | sprawdzić, sprawdzać; sprawdzić; sprawdzać; skontrolować | accepted |
| c01 | core.point | ex1.pl | Pokazywanie palcem na ludzi jest niegrzeczne. | Nieładnie jest pokazywać ludzi palcem. | pl |
| c01 | core.point | ex1.focusPl | Pokazywanie palcem | pokazywać ludzi palcem | pl |
| c01 | core.while-2 | forms | (lp.) | a while (tylko lp.) | forms |
| c01 | core.include | acceptedTranslations | zawierać, obejmować; zawierać; obejmować; uwzględnić; wliczać; dopisać | zawierać, obejmować; zawierać; obejmować; uwzględnić; wliczać | accepted |
| c01 | core.away | translation | (oddalony) stąd, daleko | daleko, z dala | accepted |
| c01 | core.away | acceptedTranslations | (oddalony) stąd, daleko; stąd; daleko; z dala; nie ma (kogoś) | daleko, z dala; daleko; z dala; stąd; oddalony | accepted |
| c01 | core.away | ex1.pl | Rodziców nie ma w ten weekend, wyjechali. | Rodzice wyjechali na weekend. | pl |
| c01 | core.away | ex1.focusPl | nie ma | wyjechali | pl |
| c01 | core.less | acceptedTranslations | mniej; mniejszy | mniej | accepted |
| c01 | core.enough-2 | ex0 | She isn't old enough to drive. ‖ Nie jest wystarczająco dorosła, żeby prowadzić. | Is the water warm enough for swimming? ‖ Czy woda jest wystarczająco ciepła, żeby pływać? | other |
| c01 | core.care | ex1.en | Handle the box with care. It's glass. | Handle the box with care. There's glass inside. | nat-en |
| c01 | core.care-2 | ex2 | Do you care if I open the window? ‖ Przeszkadza ci, jeśli otworzę okno? | She doesn't care about money at all. ‖ Pieniądze w ogóle jej nie obchodzą. | other |
| c01 | core.past | forms | (lp.) | the past (tylko lp.) | forms |
| c01 | core.past | acceptedTranslations | przeszłość; dawniej | przeszłość | accepted |
| c01 | core.mind-2 | acceptedTranslations | mieć coś przeciwko; przeszkadzać; nieważne | mieć coś przeciwko; przeszkadzać | accepted |
| c01 | core.bit | ex4 | The test wasn't a bit difficult. ‖ Test nie był ani trochę trudny. | Could you turn the music down a bit? ‖ Możesz trochę ściszyć muzykę? | nat-en |
| c01 | core.bit | notePl | A bit + przymiotnik = trochę (a bit tired); not a bit = ani trochę. | A bit + przymiotnik = trochę (a bit tired); a bit of + rzeczownik = trochę czegoś, kawałek. | nat-en |
| c01 | core.real | acceptedTranslations | prawdziwy; rzeczywisty; prawdziwie | prawdziwy; rzeczywisty | accepted |
| c01 | core.top | acceptedTranslations | góra, szczyt; góra; szczyt; wierzch; najwyższy | góra, szczyt; góra; szczyt; wierzch | accepted |
| c01 | core.sound | ex1.pl | Brzmisz na zmęczonego. Wszystko w porządku? | Masz zmęczony głos. Wszystko w porządku? | pl |
| c01 | core.sound | ex1.focusPl | Brzmisz | Masz zmęczony głos | pl |
| c01 | core.perhaps | ex3 | It wasn't perhaps the best idea. ‖ To nie był chyba najlepszy pomysł. | That perhaps wasn't the best idea. ‖ To chyba nie był najlepszy pomysł. | nat-en |
| c01 | core.front | acceptedTranslations | przód; przed; z przodu | przód; z przodu | accepted |
| c01 | core.front-2 | acceptedTranslations | przedni, frontowy; przedni; frontowy; wejściowy; pierwszy | przedni, frontowy; przedni; frontowy; wejściowy | accepted |
| c01 | core.behind | ex3 | Our team was behind by ten points at halftime. ‖ Do przerwy nasza drużyna przegrywała dziesięcioma punktami. | Is there any parking behind the building? ‖ Czy za budynkiem jest jakiś parking? | sense |
| c01 | core.travel-2 | synonyms | trip; travelling | traveling | gram-en |
| c01 | core.kill | acceptedTranslations | zabić; zabijać; zginąć | zabić; zabijać | accepted |
| c01 | core.air | acceptedTranslations | powietrze; lotniczo | powietrze | accepted |
| c01 | core.pick | ex3 | I'll pick you up at the station at six. ‖ Odbiorę cię z dworca o szóstej. | Did you pick a date for the wedding yet? ‖ Wybraliście już datę ślubu? | sense |
| c01 | core.pick | acceptedTranslations | wybrać, wybierać; wybrać; wybierać; odebrać; podnieść | wybrać, wybierać; wybrać; wybierać | accepted |
| c01 | core.contact | acceptedTranslations | skontaktować się; kontaktować się; kontakt | skontaktować się; kontaktować się | accepted |
| c01 | core.foreign | acceptedTranslations | zagraniczny, obcy; zagraniczny; obcy; za granicą | zagraniczny, obcy; zagraniczny; obcy | accepted |
| c01 | core.foreign | ex3 | You can change foreign money at the airport. ‖ Na lotnisku można wymienić walutę obcą. | You can exchange foreign currency at the airport. ‖ Na lotnisku można wymienić obcą walutę. | nat-en |
| c01 | core.pretty | acceptedTranslations | dość, całkiem; dość; całkiem; dosyć; właściwie | dość, całkiem; dość; całkiem; dosyć | accepted |
| c01 | core.drop | acceptedTranslations | upuścić, spaść; upuścić; upuszczać; spaść; spadać; podrzucić | upuścić, spaść; upuścić; upuszczać; spaść; spadać | accepted |
| c01 | core.drop | ex3 | Can you drop me off at the station? ‖ Możesz podrzucić mnie na dworzec? | Did you drop something? I heard a noise. ‖ Upuściłeś coś? Słyszałem jakiś hałas. | sense |
| c01 | core.inside | acceptedTranslations | do środka, wewnątrz; do środka; w środku; wewnątrz; w domu | do środka, wewnątrz; do środka; w środku; wewnątrz | accepted |
| c01 | core.nature | ex2 | Is it safe to drink water in nature? ‖ Czy można bezpiecznie pić wodę ze źródeł w przyrodzie? | Is there a nature trail near the campsite? ‖ Czy w pobliżu kempingu jest ścieżka przyrodnicza? | nat-en |
| c01 | core.worker | acceptedTranslations | pracownik; robotnik; pracowity | pracownik; robotnik | accepted |
| c01 | core.true | acceptedTranslations | prawdziwy, zgodny z prawdą; prawdziwy; prawda; zgodny z prawdą; spełnić się | prawdziwy, zgodny z prawdą; prawdziwy; prawda; zgodny z prawdą | accepted |
| c01 | core.hold | acceptedTranslations | trzymać; potrzymać; przytrzymać; poczekać | trzymać; potrzymać; przytrzymać | accepted |
| c01 | core.follow | ex1.pl | Po prostu jedź za znakami na lotnisko. | Po prostu kieruj się znakami na lotnisko. | pl |
| c01 | core.follow | ex1.focusPl | jedź za znakami | kieruj się znakami | pl |
| c01 | core.die | ex2.pl | Umieram z ciekawości, żeby zobaczyć nowy film! | Strasznie chcę zobaczyć ten nowy film! | pl |
| c01 | core.die | ex2.focusPl | Umieram z ciekawości | Strasznie chcę | pl |
| c01 | core.need-2 | ex2.pl | Czy w tym roku jest potrzeba więcej wolontariuszy? | Czy w tym roku potrzeba więcej wolontariuszy? | pl |
| c01 | core.mean-2 | acceptedTranslations | zamierzać, chcieć; zamierzać; chcieć; mieć zamiar; zbierać się | zamierzać, chcieć; zamierzać; chcieć; mieć zamiar | accepted |
| c01 | core.company-2 | acceptedTranslations | towarzystwo; goście | towarzystwo | accepted |
| c01 | core.point-2 | forms | (niepoliczalny) | points | forms |
| c01 | core.case | acceptedTranslations | przypadek; sytuacja; wypadek; razie | przypadek; sytuacja; wypadek | accepted |
| c01 | core.keep-3 | ex1.pl | Ta kurtka zapewni ci ciepło w górach. | W tej kurtce będzie ci ciepło w górach. | pl |
| c01 | core.keep-3 | ex1.focusPl | zapewni ci ciepło | będzie ci ciepło | pl |
| c01 | core.set | ex3 | We're setting up a new office in Denver. ‖ Otwieramy nowe biuro w Denver. | Don't forget to set the timer for the pizza. ‖ Nie zapomnij nastawić minutnika na pizzę. | sense |
| c01 | core.state | collocations | in good state; state of mind; a state of emergency; in a terrible state | state of mind; a state of emergency; in a terrible state; a state of shock | nat-en |
| c01 | core.against | ex2 | Don't lean against the door. It's wet paint. ‖ Nie opieraj się o drzwi. Są świeżo pomalowane. | Don't lean against the door. The paint is still wet. ‖ Nie opieraj się o drzwi. Farba jeszcze nie wyschła. | nat-en |
| c01 | core.though | acceptedTranslations | chociaż, mimo że; chociaż; choć; mimo że; jakby | chociaż, mimo że; chociaż; choć; mimo że | accepted |
| c01 | core.face | ex0.pl | Obecnie mamy w pracy dużo problemów. | Musimy teraz w pracy zmierzyć się z wieloma problemami. | pl |
| c01 | core.face | ex0.focusPl | mamy | zmierzyć się | pl |
| c01 | core.present | acceptedTranslations | obecny; teraźniejszy; obecnie | obecny; teraźniejszy | accepted |
| c01 | core.public | forms | (lp.) | the public (tylko lp.) | forms |
| c01 | core.public | acceptedTranslations | publiczność, ludzie; publiczność; ludzie; społeczeństwo; publicznie | publiczność, ludzie; publiczność; ludzie; społeczeństwo | accepted |
| c01 | core.public | ex2 | The new park will open to the public in May. ‖ Nowy park zostanie otwarty dla mieszkańców w maju. | The public has a right to know the truth. ‖ Społeczeństwo ma prawo znać prawdę. | other |
| c01 | core.control | acceptedTranslations | kontrola; panowanie; władza; pilot | kontrola; panowanie; władza | accepted |
| c01 | core.sort | acceptedTranslations | rodzaj; typ; jakby | rodzaj; typ | accepted |
| c01 | core.sort | ex3.pl | Jestem jakby zmęczony. Możemy iść do domu? | Jestem trochę zmęczony. Możemy iść do domu? | pl |
| c01 | core.sort | ex3.focusPl | jakby | trochę | pl |
| c01 | core.fall | acceptedTranslations | spaść, spadać; spaść; spadać; opaść; zasnąć | spaść, spadać; spaść; spadać; opaść | accepted |
| c01 | core.power | acceptedTranslations | władza, moc; władza; moc; siła; dar | władza, moc; władza; moc; siła | accepted |
| c01 | core.return-2 | ex2 | The kids are excited about the return of their dad. ‖ Dzieci nie mogą się doczekać powrotu taty. | The kids can't wait for their dad's return. ‖ Dzieci nie mogą się doczekać powrotu taty. | nat-en |
| c01 | core.matter | ex3.pl | Twoja opinia naprawdę liczy się dla mnie. | Twoja opinia naprawdę się dla mnie liczy. | pl |
| c01 | core.matter | ex3.focusPl | liczy się | liczy | pl |
| c01 | core.mind | acceptedTranslations | umysł, głowa; umysł; głowa; myśli; zdanie | umysł, głowa; umysł; głowa; myśli | accepted |
| c01 | core.force | acceptedTranslations | zmusić, zmuszać; zmusić; zmuszać; musieć; na siłę | zmusić, zmuszać; zmusić; zmuszać | accepted |
| c01 | core.share | acceptedTranslations | część, udział; część; udział; akcja | część, udział; część; udział | accepted |
| c01 | core.clear-3 | ex3 | The weather cleared up in the afternoon. ‖ Po południu się przejaśniło. | Don't forget to clear your desk before you leave. ‖ Nie zapomnij uprzątnąć biurka przed wyjściem. | sense |
| c01 | core.either | acceptedTranslations | jeden z dwóch, którykolwiek; jeden z dwóch; którykolwiek; dowolny; żaden; albo | jeden z dwóch, którykolwiek; jeden z dwóch; którykolwiek; dowolny; żaden | accepted |
| c01 | core.per | acceptedTranslations | na, za (każdy); na; za; od; dziennie | na, za (każdy); na; za; od | accepted |
| c01 | core.toward | acceptedTranslations | w kierunku, w stronę; w kierunku; w stronę; ku; pod koniec; do | w kierunku, w stronę; w kierunku; w stronę; ku; pod koniec; wobec | accepted |
| c01 | core.toward | ex3 | How do you feel toward your old school? ‖ Co czujesz do swojej dawnej szkoły? | Why is she so unfriendly toward her neighbors? ‖ Dlaczego jest taka nieżyczliwa wobec sąsiadów? | nat-en |
| c01 | core.sense-2 | forms | (lp.) | (niepoliczalny) | forms |
| c01 | core.sense-2 | ex0.pl | Twój plan ma dużo sensu. | Twój plan jest bardzo sensowny. | pl |
| c01 | core.sense-2 | ex0.focusPl | ma dużo sensu | jest bardzo sensowny | pl |
| c01 | core.condition-2 | acceptedTranslations | warunek; regulamin | warunek | accepted |
| c01 | core.certain | acceptedTranslations | pewny, pewien; pewny; pewien; przekonany; na pewno | pewny, pewien; pewny; pewien; przekonany | accepted |
| c01 | core.forward | acceptedTranslations | naprzód, do przodu; naprzód; do przodu; dalej; cieszyć się na | naprzód, do przodu; naprzód; do przodu; dalej | accepted |
| c01 | core.especially | acceptedTranslations | szczególnie, zwłaszcza; szczególnie; zwłaszcza; specjalnie; szczególny | szczególnie, zwłaszcza; szczególnie; zwłaszcza; specjalnie | accepted |
| c01 | core.site | acceptedTranslations | teren, miejsce; teren; miejsce; plac; budowa; strona | teren, miejsce; teren; miejsce; plac | accepted |
| c01 | core.act-2 | acceptedTranslations | zachowywać się; zachować się; udawać | zachowywać się; zachować się | accepted |
| c01 | core.act-2 | ex3.pl | Czemu ona jest taka zdenerwowana dzisiaj? | Czemu ona się dziś tak nerwowo zachowuje? | pl |
| c01 | core.act-2 | ex3.focusPl | jest taka zdenerwowana | tak nerwowo zachowuje | pl |
| c01 | core.serve | acceptedTranslations | podawać (jedzenie); podawać; podać; serwować; obsłużyć | podawać (jedzenie); podawać; podać; serwować | accepted |
| c01 | core.serve | ex3 | The waiter served us very quickly. ‖ Kelner bardzo szybko nas obsłużył. | What time do you stop serving lunch? ‖ Do której podajecie lunch? | sense |
| c01 | core.trade | ex3.pl | Oddaliśmy w rozliczeniu u dealera nasz stary samochód. | W salonie oddaliśmy w rozliczeniu nasz stary samochód. | pl |
| c01 | core.trade | ex3.focusPl | Oddaliśmy w rozliczeniu | oddaliśmy w rozliczeniu | pl |
| c01 | core.vote | acceptedTranslations | głos (w głosowaniu), głosowanie; głos; głosowanie; zagłosować | głos (w głosowaniu), głosowanie; głos; głosowanie | accepted |
| c01 | core.attention | ex2.pl | Dzieci w ogóle nie zwracały uwagi na mnie. | Dzieci w ogóle nie zwracały na mnie uwagi. | pl |
| c01 | core.attention | ex2.focusPl | nie zwracały uwagi | nie zwracały na mnie uwagi | pl |
| c01 | core.particularly | ex0.pl | Nie jestem specjalnie głodny w tej chwili. | W tej chwili nie jestem specjalnie głodny. | pl |
| c01 | core.particularly | ex0.focusPl | Nie jestem specjalnie | nie jestem specjalnie | pl |
| c01 | core.suppose | acceptedTranslations | przypuszczać, sądzić; przypuszczać; sądzić; chyba; mieć (coś zrobić) | przypuszczać, sądzić; przypuszczać; sądzić; chyba | accepted |
| c01 | core.laugh-2 | acceptedTranslations | śmiech; żart | śmiech | accepted |
| c01 | core.laugh-2 | ex3 | Isn't that a funny laugh? ‖ Czy to nie jest zabawny śmiech? | Her laugh isn't loud, but it's contagious. ‖ Jej śmiech nie jest głośny, ale za to zaraźliwy. | nat-en |
| c01 | core.simply | ex3.pl | Wyszła zwyczajnie dlatego, że się nudziła. | Wyszła po prostu dlatego, że się nudziła. | pl |
| c01 | core.simply | ex3.focusPl | zwyczajnie | po prostu | pl |
| c01 | core.attack | acceptedTranslations | atak; napaść; zawał | atak; napaść | accepted |
| c01 | core.surprising | acceptedTranslations | zaskakujący; nic dziwnego; dziwny | zaskakujący; nic dziwnego | accepted |
| c01 | core.affect | ex1.pl | Jak nowe przepisy wpłyną na nas? | Jak nowe przepisy na nas wpłyną? | pl |
| c01 | core.press | forms | (lp.) | the press (tylko lp.) | forms |
| c01 | core.order | acceptedTranslations | kolejność, porządek; kolejność; porządek; nieczynny; żeby | kolejność, porządek; kolejność; porządek | accepted |
| c01 | core.order | ex2 | I left early in order to catch the train. ‖ Wyszedłem wcześnie, żeby zdążyć na pociąg. | The books on this shelf are in no particular order. ‖ Książki na tej półce nie są ułożone w żadnej konkretnej kolejności. | sense |
| c01 | core.ensure | acceptedTranslations | zapewnić; zapewniać; dopilnować; zagwarantować; upewnić się | zapewnić; zapewniać; dopilnować; zagwarantować | accepted |
| c01 | core.figure-3 | ex2 | I can't figure out how this machine works. ‖ Nie mogę rozgryźć, jak działa ta maszyna. | I figured it would rain, so I didn't bring my bike. ‖ Doszedłem do wniosku, że będzie padać, więc nie wziąłem roweru. | sense |
| c01 | core.figure-3 | ex3 | Did you figure out what was wrong with the car? ‖ Rozgryzłeś, co było nie tak z samochodem? | Why didn't you call? – I figured you were busy. ‖ Czemu nie zadzwoniłeś? – Uznałem, że jesteś zajęty. | sense |
| c01 | core.figure-3 | acceptedTranslations | sądzić, uznać; sądzić; uznać; pomyśleć; rozgryźć; dojść do wniosku | sądzić, uznać; sądzić; uznać; pomyśleć; dojść do wniosku | accepted |
| c01 | core.bear | ex0.pl | Nie potrafię oglądać horrorów. | Nie jestem w stanie oglądać horrorów. | pl |
| c01 | core.bear | ex0.focusPl | Nie potrafię | Nie jestem w stanie | pl |
| c01 | core.bear | acceptedTranslations | znieść, wytrzymać; znieść; znosić; wytrzymać; pamiętać | znieść, wytrzymać; znieść; znosić; wytrzymać | accepted |
| c01 | core.relate | acceptedTranslations | odnosić się, wiązać się; odnosić się; wiązać się; utożsamiać się; rozumieć | odnosić się, wiązać się; odnosić się; wiązać się; utożsamiać się | accepted |
| c01 | core.fine | ex1 | Is it fine if I bring a friend? ‖ Czy mogę przyprowadzić znajomego? Nie będzie problemu? | Is it fine if I bring a friend? ‖ Czy to w porządku, jeśli przyprowadzę znajomego? | pl |
| c02 | core.quickly | acceptedTranslations | szybko; prędko; najszybciej | szybko; prędko | accepted |
| c02 | core.dollar | ex3.en | They don't accept dollars here, only local money. | They don't accept dollars here, only the local currency. | nat-en |
| c02 | core.chair | ex0 | Please take a chair and sit down. ‖ Weź krzesło i usiądź. | Please pull up a chair and sit down. ‖ Przysuń sobie krzesło i usiądź. | nat-en |
| c02 | core.chair | collocations | sit on a chair; take a chair; kitchen chair; office chair | sit on a chair; pull up a chair; kitchen chair; office chair | nat-en |
| c02 | core.transport | ex0 | The city has very good public transport. ‖ Miasto ma bardzo dobry transport publiczny. | Air transport is fast, but it isn't cheap. ‖ Transport lotniczy jest szybki, ale nie jest tani. | nat-en |
| c02 | core.transport | ex1 | What's the cheapest form of transport in this country? ‖ Jaki jest najtańszy środek transportu w tym kraju? | The company pays for the transport of all our equipment. ‖ Firma płaci za transport całego naszego sprzętu. | nat-en |
| c02 | core.transport | ex3 | The village doesn't have any transport to the city at night. ‖ Wieczorem z wioski nie ma żadnego dojazdu do miasta. | Who paid for the transport of the furniture? ‖ Kto zapłacił za transport mebli? | nat-en |
| c02 | core.transport | collocations | public transport; means of transport; transport costs | air transport; the transport of goods; transport costs | nat-en |
| c02 | core.transport | notePl | W AmE częściej "transportation", np. public transportation. | W AmE komunikacja miejska to „public transportation”; transport częściej oznacza przewóz ludzi lub towarów. | nat-en |
| c02 | core.transport | contextPl | O środkach transportu i przewozie | O przewozie ludzi i towarów | nat-en |
| c02 | core.transport | acceptedTranslations | transport; komunikacja; dojazd; przewóz | transport; przewóz | accepted |
| c02 | core.somewhere | ex2.focusEn | somewhere | somewhere else | focus |
| c02 | core.strange | ex2.pl | W obcym łóżku zawsze nie mogę zasnąć. | W obcym łóżku nigdy nie mogę zasnąć. | pl |
| c02 | core.impossible | ex3 | Why is it so impossible to get a doctor's appointment? ‖ Dlaczego tak trudno umówić się do lekarza? | Why is it impossible to get a doctor's appointment this week? ‖ Dlaczego w tym tygodniu nie da się umówić do lekarza? | pl |
| c02 | core.opposite | ex3 | "Hot" is the opposite of "cold." ‖ „Gorący” to przeciwieństwo słowa „zimny”. | We sat on opposite sides of the table. ‖ Siedzieliśmy po przeciwnych stronach stołu. | sense |
| c02 | core.opposite | acceptedTranslations | przeciwny; odwrotny; odmienny; przeciwieństwo | przeciwny; odwrotny; odmienny | accepted |
| c02 | core.interview | acceptedTranslations | przeprowadzić rozmowę; przeprowadzić wywiad; przeprowadzać; rozmawiać; rozmowa kwalifikacyjna | przeprowadzić rozmowę; przeprowadzić wywiad; przeprowadzać rozmowę; przeprowadzać wywiad; rozmawiać | accepted |
| c02 | core.interview | ex3.focusEn | interviewed | being interviewed | focus |
| c02 | core.exchange | acceptedTranslations | wymiana; zamiana; zamian | wymiana; zamiana | accepted |
| c02 | core.heat | acceptedTranslations | ogrzewać; ogrzać; podgrzać; podgrzewać; nagrzać; podgrzanie | ogrzewać; ogrzać; podgrzać; podgrzewać; nagrzać | accepted |
| c02 | core.waste | acceptedTranslations | marnowanie; marnotrawstwo; strata; zmarnować się | marnowanie; marnotrawstwo; strata | accepted |
| c02 | core.waste | ex0.pl | Ten drogi telefon był kompletnym marnowaniem pieniędzy. | Ten drogi telefon był kompletną stratą pieniędzy. | pl |
| c02 | core.waste | ex0.focusPl | marnowaniem | stratą | pl |
| c02 | core.equal | ex2.pl | Jedna filiżanka to mniej więcej tyle samo co 250 mililitrów. | Jedna szklanka odpowiada mniej więcej 250 mililitrom. | pl |
| c02 | core.equal | ex2.focusPl | tyle samo | odpowiada | pl |
| c02 | core.extremely | ex3 | The hotel staff weren't extremely friendly, but they were helpful. ‖ Personel hotelu nie był szczególnie miły, ale był pomocny. | Isn't it extremely expensive to live in New York? ‖ Czy życie w Nowym Jorku nie jest niezwykle drogie? | nat-en |
| c02 | core.extremely | acceptedTranslations | niezwykle; niezmiernie; bardzo; strasznie; skrajnie; szczególnie | niezwykle; niezmiernie; bardzo; strasznie; skrajnie | accepted |
| c02 | core.mostly | ex3 | It's not mostly about money; it's about respect. ‖ Nie chodzi głównie o pieniądze; chodzi o szacunek. | Is the class mostly beginners? ‖ Czy w grupie są głównie początkujący? | nat-en |
| c02 | core.essential | contextPl | O rzeczach, bez których nie da się się obyć | O rzeczach, bez których nie można się obyć | pl |
| c02 | core.employ | acceptedTranslations | zatrudniać; zatrudnić; zatrudniony; zatrudnienie | zatrudniać; zatrudnić | accepted |
| c02 | core.possibly | ex3.focusPl | mowy | Nie ma mowy | focus |
| c02 | core.onto | ex3 | Don't put your bag onto the seat next to you. ‖ Nie kładź torby na siedzeniu obok. | Can you help me lift this box onto the shelf? ‖ Pomożesz mi podnieść to pudło na półkę? | nat-en |
| c02 | core.bomb | acceptedTranslations | bomba; ładunek wybuchowy; bombowy | bomba; ładunek wybuchowy | accepted |
| c02 | core.mainly | ex3 | It's not mainly about the money for me. ‖ Dla mnie nie chodzi głównie o pieniądze. | Do you use this room mainly as an office? ‖ Czy używasz tego pokoju głównie jako biura? | nat-en |
| c02 | core.participate | acceptedTranslations | uczestniczyć; brać udział; wziąć udział; udział | uczestniczyć; brać udział; wziąć udział | accepted |
| c02 | core.error | collocations | human error; an error message; make an error; by error | human error; an error message; make an error; in error | nat-en |
| c02 | core.arrest | acceptedTranslations | aresztowanie; areszt; zatrzymanie; aresztowany | aresztowanie; areszt; zatrzymanie | accepted |
| c02 | core.signal | ex4.en | Didn't you see the stop signal? | Didn't you see the signal to stop? | nat-en |
| c02 | core.beyond | ipa | /biˈɑːnd/ | /bɪˈjɑːnd/ | ipa |
| c02 | core.overall-2 | ex0.pl | Ogólnie rzecz biorąc jestem bardzo zadowolony z nowej pracy. | Ogólnie rzecz biorąc, jestem bardzo zadowolony z nowej pracy. | pl |
| c02 | core.presence | ex1.pl | Na koncercie była duża obecność policji. | Na koncercie były obecne liczne siły policji. | pl |
| c02 | core.presence | ex1.focusPl | obecność | obecne | pl |
| c02 | core.introduction | acceptedTranslations | wprowadzenie; przedstawienie; przedstawić | wprowadzenie; przedstawienie | accepted |
| c02 | core.emerge | ex1.focusPl | na jaw | Wyszły na jaw | focus |
| c02 | core.circumstance | ex2.pl | W żadnych okolicznościach nie otwieraj tych drzwi. | Pod żadnym pozorem nie otwieraj tych drzwi. | pl |
| c02 | core.circumstance | ex2.focusPl | okolicznościach | Pod żadnym pozorem | pl |
| c02 | core.apparently | ex3 | Is the store apparently closing for good? ‖ Czy sklep podobno zamyka się na dobre? | Apparently, it's going to snow tomorrow. Is that true? ‖ Podobno jutro ma padać śnieg. To prawda? | nat-en |
| c02 | core.settle | ex1.en | Have you settled in to your new apartment yet? | Have you settled into your new apartment yet? | gram-en |
| c02 | core.commit | collocations | commit a crime; commit a mistake; commit murder | commit a crime; commit an error; commit murder | nat-en |
| c02 | core.hardly | acceptedTranslations | ledwo; ledwie; prawie nie; prawie wcale; prawie | ledwo; ledwie; prawie nie; prawie wcale | accepted |
| c02 | core.hardly | ex1.focusPl | prawie | prawie w ogóle | focus |
| c02 | core.hardly | ex2.focusPl | prawie | prawie wcale | focus |
| c02 | core.hardly | ex3.focusPl | prawie | prawie nie | focus |
| c02 | core.threat | acceptedTranslations | groźba; pogróżka; grozić; zagrozić | groźba; pogróżka | accepted |
| c02 | core.conclude | acceptedTranslations | dojść do wniosku; wywnioskować; stwierdzić; wniosek | dojść do wniosku; wywnioskować; stwierdzić | accepted |
| c02 | core.conclude | ex1.focusPl | wniosek | wniosek możemy wyciągnąć | focus |
| c02 | core.finance | acceptedTranslations | finanse; finansowy | finanse | accepted |
| c02 | core.corporate | acceptedTranslations | korporacyjny; firmowy; korporacja; firma | korporacyjny; firmowy | accepted |
| c02 | core.escape-2 | acceptedTranslations | ucieczka; ewakuacyjny; ujść cało | ucieczka | accepted |
| c02 | core.confidence | acceptedTranslations | zaufanie; wiara; zaufać | zaufanie; wiara | accepted |
| c02 | core.leadership | acceptedTranslations | przywództwo; kierownictwo; przywódczy | przywództwo; kierownictwo | accepted |
| c02 | core.necessarily | ex0.pl | Drogie restauracje nie są koniecznie lepsze od tanich. | Drogie restauracje niekoniecznie są lepsze od tanich. | pl |
| c02 | core.necessarily | ex0.focusPl | koniecznie | niekoniecznie | pl |
| c02 | core.expense | ex3.pl | Nie rób sobie dla mnie kosztów; wystarczy zwykła kolacja. | Nie narażaj się dla mnie na koszty; wystarczy zwykła kolacja. | pl |
| c02 | core.expense | ex3.focusPl | kosztów | koszty | pl |
| c02 | core.desire-2 | acceptedTranslations | pragnąć; pożądać; życzyć sobie; pożądany | pragnąć; pożądać; życzyć sobie | accepted |
| c02 | core.commit-2 | acceptedTranslations | zobowiązać się; zobowiązywać się; oddany; poświęcić się | zobowiązać się; zobowiązywać się; poświęcić się | accepted |
| c02 | core.bind | acceptedTranslations | zobowiązywać; zobowiązać; wiązać; wiążący; obowiązywać | zobowiązywać; zobowiązać; wiązać; obowiązywać | accepted |
