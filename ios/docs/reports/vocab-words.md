# Raport: vocab-words — pojedyncze słowa (FEEDBACK-10 P4)

Pliki: `ios/FluentNOW/Resources/Content/core/core-c14.json`, `core/core-c15.json` (nowe). Innych plików treści nie zmieniałem. Nie uruchamiałem `build-index.mjs`, `build-core-master.mjs` ani gita.
Skrypty i dane robocze: `C:\Users\HARDPC~1\AppData\Local\Temp\claude\C--Users-HARD-PC-Desktop-FluentNOW\df8a4d3f-88ca-4686-a14a-24fd1bd92a1b\scratchpad\vwords\`. Treść jest pisana w zwartym formacie `c14-0N.txt` / `c15-0N.txt`. `build.mjs` składa z nich oba shardy: nadaje `id`, grupuje wpisy w kategorie wg CEFR i uzupełnia `acceptedTranslations`/`acceptedAnswers`. Poza tym są tam `exists.mjs` (wyszukiwanie duplikatów), `rep.mjs` (poprawki punktowe), `short.mjs` i `final.mjs` (kontrole końcowe).

## 1. Wynik

| | core-c14 | core-c15 | razem |
|---|---|---|---|
| wpisy | 287 | 274 | **561** |
| przykłady | 1038 | 853 | **1891** (średnio 3,4 na wpis) |
| walidator `--file` | 0 błędów, 0 ostrzeżeń | 0 błędów, 0 ostrzeżeń | |
| walidator całej bazy (171 plików, 16 286 wpisów, z C10–C13 innych agentów) | | | **0 błędów, 0 ostrzeżeń** |

Rozkład CEFR:

| | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|
| core-c14 | 45 | 86 | 152 | 4 | – |
| core-c15 | 9 | 35 | 49 | 165 | 16 |
| **razem** | 54 (9,6%) | 121 (21,6%) | 201 (35,8%) | 169 (30,1%) | 16 (2,9%) |

Cel z zadania: B1 ok. 25%, B2 ok. 40%, C1 ok. 25%, reszta A2/C2. B1 wyszło trochę poniżej celu, a C1 powyżej. Powód: baza (tematy, starter, C01–C09) pokrywa już prawie całe ogólne słownictwo B1. Z ok. 900 sprawdzonych kandydatów B1 brakowało tylko kilkudziesięciu (zob. §2).

Części mowy: rzeczowniki 239, czasowniki 140, przymiotniki 132, przysłówki 50 (C14: 157/47/54/29; C15: 82/93/78/21).

Podział shardów:
- **C14**: słowa codzienne A2–B1 (jedzenie, dom, przedmioty, przysłówki sposobu, czasowniki emocji) oraz słownictwo pracy, biznesu i usług B2 z list BSL/TSL.
- **C15**: słowa z przedrostkami (un-, mis-, re-, dis-), przysłówki B2, brakujące znaczenia częstych słów, słownictwo opisu, emocji i charakteru C1, biznes i prawo C1 oraz C2.

## 2. Źródła i licencje

| Źródło | Autorzy | Licencja (sprawdzona WebFetch na newgeneralservicelist.com, 2026-11-02) | Użycie |
|---|---|---|---|
| Business Service List (BSL) 1.20 | Browne, C., Culligan, B. | CC BY-SA 4.0 | kandydaci B2–C1 (biznes, finanse, prawo) |
| TOEIC Service List (TSL) 1.2 | Browne, C., Culligan, B. | CC BY-SA 4.0 | kandydaci A2–B2 (usługi, biuro, podróże, codzienność) |
| NGSL-Spoken 1.2 | Browne, C., Culligan, B. | CC BY-SA 4.0 | sprawdzona; wszystkie lematy są już w bazie, więc lista nic nie wniosła |
| Własne listy redakcyjne | FluentNOW | jak repozytorium | słowa „życiowe” (dom, zdrowie, jedzenie, ubrania, emocje, charakter), przysłówki, słownictwo C1–C2, brakujące znaczenia |

Pobrałem kolumny lematów (pliki `*_stats.csv`). Listy robocze leżą w scratchpadzie (`bsl.txt`, `tsl.txt`). Nie kopiowałem list zastrzeżonych (Oxford 3000/5000, COCA, EVP). CEFR, części mowy, definicje i przykłady to moje oceny i moje zdania. Nie przepisywałem ich ze słowników.

**Duplikaty.** `exists.mjs` porównuje kandydata (małe litery) z polami `term` i `acceptedAnswers` we wszystkich `topics/*.json`, `core/*.json` i `starter-words.json` oraz z polami `t`/`k` w `dictionary-index.json`. Sprawdziłem w ten sposób ok. 4 000 kandydatów. Brakujących słów było: BSL 445/1391, TSL 312/1224, listy własne łącznie ok. 380. Z brakujących wybrałem słowa przydatne uczniowi. Pominąłem terminologię wąsko finansową (*annuity, derivative, receivable, debenture, fiduciary, covariance*), słowa BrE (*cheque, petrol, redundancy, queue*), archaizmy (*hereby, hitherto*) oraz przysłówki, których znaczenie wynika wprost z przymiotnika. Walidator dodatkowo sprawdza unikalność term+translation i zdań w całej bazie, także w C10–C13 pisanych równolegle. Dwa zdania okazały się identyczne z istniejącymi (`core-c06` *consciousness*, `core-c10` *stab someone in the back*) i je wymieniłem.

## 3. Nowe znaczenia słów już obecnych w bazie

Dopisane tylko wtedy, gdy tłumaczenie wyraźnie różni się od istniejącego i znaczenie jest częste:

| wpis | znaczenie | co było w bazie |
|---|---|---|
| core.plant | zakład, fabryka (B2) | roślina; sadzić; siać |
| core.issue | numer, wydanie czasopisma (B2) | problem; kwestia |
| core.issue-2 | wydać, wystawić (dokument), ogłosić (B2) | j.w. |
| core.trip-2 | potknąć się (B1) | podróż; kurs |
| core.toast | tost, grzanka (A2) | tylko „toast” (wznieść toast) |
| core.honey-2 | kochanie, skarbie (B1) | brak *honey* w ogóle (dopisany też „miód”, A2) |
| core.cell | cela (B2) | komórka (biol.); telefon komórkowy |
| core.spring | sprężyna (B2) | wiosna; źródło |
| core.sound-2 | rozsądny, solidny (C1) | dźwięk; brzmieć |
| core.content-2 | zadowolony (C1) | treści; zawartość |
| core.novel | nowatorski (C1) | powieść |
| core.minute | drobniutki, znikomy (C1, /maɪˈnuːt/) | minuta |
| core.lap / core.lap-2 | kolana (B1) / okrążenie (B2) | brak |
| core.grave / core.grave-2 | grób (B2) / poważny (C1) | brak |
| core.sole / core.sole-2 | podeszwa (B2) / jedyny (C1) | brak |
| core.mine, core.mole | kopalnia (B2), pieprzyk (B2) | brak |

Ciekawostka z wyszukiwania: w bazie brakowało też zupełnie podstawowych słów, m.in. *thought* (rzeczownik), *honey, olive, cinnamon, cereal, pancake, noodles, soap, candy, pasta, flour, fog, jam, mask, parking, fortunately*. Wszystkie są dopisane.

## 4. Standard wpisów

Wszystkie wpisy są zgodne z 03b i CONTENT-SCHEMA §1/§6:
- IPA w konwencji Oxford US, z jawnym /ə/ w -ʃən, -bəl, -təl. Kontrola `final.mjs` nie znalazła różnic IPA względem wpisów bazy o tym samym haśle i części mowy, a `short.mjs` nie znalazł ɛ/ɝ/ɚ ani -ʃn.
- `forms` wg konwencji: trzy formy czasownika z wariantem -ing tam, gdzie pisownia się zmienia (`stab – stabbed – stabbed; stabbing`), oraz `(niepoliczalny)` i `(liczba mnoga)` przy rzeczownikach.
- `acceptedTranslations` zawierają tylko odpowiedniki danego znaczenia. Usunąłem pozycje z innych znaczeń, np. w *needy*, *charitable*, *breezy*, *flatter*, *doormat*, *confer*, *congestion* i *mine*, a kilka znaczeń rozdzieliłem na osobne wpisy.
- Każdy wpis ma 3–5 przykładów. Przy 4–5 przykładach jest co najmniej jedno pytanie lub przeczenie. `focusEn`/`focusPl` są dokładnymi podciągami zdań.
- Zdania mają po 6–20 słów, poza 46 pięciowyrazowymi pytaniami lub krótkimi zdaniami (ok. 2,4%; w C01–C09 jest ok. 3%). Zdań czterowyrazowych nie ma.
- `notePl` opisuje głównie fałszywych przyjaciół (*magazine ≠ magazyn*, *raisin ≠ winogrono*, *pasta*, *mandate ≠ mandat drogowy*, *alternatively = ewentualnie ≠ eventually*), pary mylone (*economic/economical*, *electric/electrical*, *specially/especially*, *worried/worrying*, *discreet/discrete*, *ingenious/ingenuous*) i różnice AmE/BrE (*vest*, *candy*, *oatmeal/porridge*, *clothespin*, *revision*).
- Pisownia AmE (*liter, centimeter, odor, savor, enrollment, unraveled, misspelled*). Nie ma marek, osób publicznych ani polityki partyjnej.

## 5. Lista haseł

### core-c14.json
- **A2** (45): thought, picnic, mask, soap, candy, pasta, flour, fog, jam, toast, parking, motorcycle, lunchtime, doorbell, heater, snowy, sticker, someday, fortunately, luckily, loudly, politely, happily, kilogram, liter, webpage, runner, yoga, circus, vanilla, skateboard, workbook, centimeter, gram, bracelet, cereal, oatmeal, pancake, waffle, cracker, melon, coconut, noodles, sandal, slipper
- **B1** (86): ink, underline, indoor, briefcase, optional, booklet, packet, jet, hourly, reopen, airfare, tunnel, safely, sauna, enjoyable, silently, amateur, unused, cordless, handbook, hiker, lighter, comfortably, decoration, daytime, ironing, streaming, liar, deodorant, razor, salesman, specially, postal, stereo, sedan, drum, cage, fax, electrical, automobile, newsstand, housekeeper, inspector, spy, loser, memo, explosion, explode, logo, broadband, cheaply, instant, triple, businessman, warehouse, poorly, trip (potknąć się), pimple, almond, walnut, raisin, vest, resize, worrying, overcook, confuse, bore, excite, embarrass, frighten, secretly, softly, angrily, nervously, proudly, patiently, rudely, bravely, carelessly, tightly, neatly, warmly, strangely, wisely, lastly, lap (kolana)
- **B2** (152): inventory, merger, retailer, broker, lender, borrower, bankruptcy, bankrupt, trader, patent, administrative, authorize, query, costly, withdrawal, completion, quarterly, annually, deputy, franchise, duplicate, outsider, virtual, repayment, marketplace, distributor, merchant, trademark, prosecutor, shipment, subscriber, handful, unchanged, batch, customize, publicity, residential, promotional, recruitment, resignation, removal, placement, certification, protester, financially, nationwide, homeowner, relocation, refundable, dealership, showroom, finalize, lengthy, garment, economical, healthcare, wellness, enrollment, cosmetic, spectator, ambassador, architectural, enthusiast, redecorate, reconsider, needy, continental, footwear, incoming, contestant, cleanliness, introductory, recreation, recreational, institute, advertiser, sensor, prototype, outbreak, cargo, fleet, aviation, timber, serial, saver, globe, commentator, charitable, compatible, inconsistent, unrelated, constructive, defensive, disastrous, consecutive, prevention, lap (okrążenie), snooze, weaken, widen, broaden, regain, relieve, nominate, enlarge, depart, opt, frustrate, isolate, endanger, complicate, dedicate, terrify, bless, rot, stab, tame, stray, wreck, haunt, blur, glitter, crumble, obsess, excel, entitle, sane, ironic, literal, absurd, accidental, addict, decisive, drastic, quirky, wholesome, wicked, delight, terror, brag, blush, spooky, odor, worthless, bullying, retiree, seasoning, nausea, downpour, breezy, vaccinate, fragrance
- **C1** (4): census, freight, seeker, editorial

### core-c15.json
- **A2** (9): honey (miód), pudding, olive, cinnamon, apricot, kiwi, grapefruit, mitten, bikini
- **B1** (35): unwell, untidy, rechargeable, washable, long-distance, underweight, sleepless, sugar-free, untie, unzip, disobey, mishear, misspell, replay, honey (kochanie), custard, mint, dill, tangerine, fig, coaster, apron, clothespin, padlock, doormat, keychain, beanie, tights, leggings, overalls, nightgown, robe, eyeliner, lotion, tweezers
- **B2** (49): tasteless, unavoidable, disloyal, misread, rethink, reunite, intentionally, publicly, privately, openly, officially, considerably, unusually, repeatedly, exclusively, ideally, legally, urgently, smoothly, alternatively, sharply, efficiently, willingly, thankfully, oddly, indirectly, revision, declaration, exploration, inability, adoption, nutmeg, plant (zakład), issue (numer), issue (wydać), grave (grób), mine (kopalnia), sole (podeszwa), mole (pieprzyk), cell (cela), spring (sprężyna), riot, bribe, assault, shield, probable, passive, certainty, fate
- **C1** (165): grave (poważny), sole (jedyny), novel (nowatorski), sound (rozsądny), content (zadowolony), minute (drobniutki), abrupt, allege, astonish, audible, avid, awe, bewildered, bleak, bliss, blunder, brisk, brittle, colossal, commend, confide, crave, cynical, dazzle, destined, devour, dire, discreet, dismay, disperse, dodge, dormant, dread, dwindle, earnest, elated, evade, expel, extravagant, fabricate, feeble, ferocious, fickle, flatter, flinch, formidable, frantic, gruesome, harass, hasty, hoard, humiliate, hustle, hypocrite, ignite, illuminate, immerse, impartial, inflict, ingenious, intrude, lavish, loathe, magnify, meddle, menace, mischief, murky, narrate, outspoken, perplexed, persevere, pinpoint, plea, poignant, potent, pristine, prodigy, quench, quirk, radiant, ravenous, recede, recount, relish, repel, retaliate, rummage, sabotage, savor, scramble, shrewd, shudder, sluggish, solemn, sparse, squander, stifle, subdue, submerge, suffocate, swarm, tarnish, taunt, thwart, torment, transient, turbulent, unanimous, uncanny, unearth, unravel, uproar, utmost, vicious, vigilant, wade, waver, wield, wince, wretched, zeal, stench, hideous, grumble, tiptoe, chuckle, doze, cowardly, gullible, tactless, uptight, mildew, incur, defer, oversee, compliance, predecessor, soar, mandate, disclosure, coalition, takeover, offset, restructure, applicable, substantially, insider, exempt, interim, jurisdiction, municipal, amend, demographic, prospective, speculation, allegation, cease, prosecute, veto, negligence, malfunction, waive, hazardous, congestion
- **C2** (16): litigation, ratify, clout, demise, confer, oust, heed, ensue, forfeit, renounce, revere, scorn, steadfast, wistful, falter, coax

## 6. Wątpliwości i uwagi dla vocab-qa i koordynatora

1. **Proporcje CEFR.** B1 ma 21,6% (cel ok. 25%), a C1 30% (cel ok. 25%). Wynika to z bazy: brakujące słowa B1 są nieliczne. Jeśli trzeba wyrównać, można dopisać kolejne słowa B1 z przedrostkami (un-, re-, mis-) lub przysłówki sposobu. Nie robiłem tego, bo słowa te są w dużej mierze przewidywalne.
2. **Granice znaczeń.** Kilka wpisów obejmuje bliskie odcienie jednego znaczenia, wspomniane w definicji: *trademark* („znak rozpoznawczy”), *handful* („absorbujące dziecko”), *wicked* („łobuzerski”), *mine* („żyła złota” w przykładzie z *gold mine*), *plea* (także „przyznanie się / nieprzyznanie się do winy” w sądzie), *issue* (numer czasopisma). Do decyzji QA: czy wydzielać je w osobne wpisy.
3. **Hasła złożone.** *long-distance* i *sugar-free* to przymiotniki z łącznikiem, czyli formalnie jedno słowo. *noodles* zapisałem w liczbie mnogiej (`forms: noodle (lp.)`), bo tak się go używa.
4. **Jednostki metryczne** (*kilogram, liter, centimeter, gram*): w notkach zaznaczyłem, że w USA na co dzień używa się jednostek imperialnych.
5. **Rejestr potoczny** oznaczyłem przy *honey* (kochanie), *loser*, *brag*, *spooky*, *snooze*, *hustle*, *uptight* i *clout*. Ostatnie dwa mogą wymagać oceny QA.
6. **Poprawki w trakcie.** Porcje po 31–50 haseł (7 w C14 i 7 w C15). Po każdej porcji uruchamiałem walidator i poprawiałem wszystkie ostrzeżenia: `core-example-variety`, średniki w `acceptedTranslations`, BrE *sweets*/*biscuit*, „A herb” zamienione na „An herb” oraz dwa zdania zdublowane z innymi shardami.
7. **Po zakończeniu fali** koordynator powinien uruchomić `node ios/tools/build-index.mjs` (C14/C15 trafią do `dictionary-index.json`), potem `build-core-master.mjs` i pełne `validate-content.mjs`. Przed tym nowe hasła nie są widoczne w wyszukiwarce słownika.
