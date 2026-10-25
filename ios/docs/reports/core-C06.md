# Raport: core-content, shard C06

## 1. Co zrobiono

Plik: `ios/FluentNOW/Resources/Content/core/core-c06.json` (nowy, format §6 CONTENT-SCHEMA; id `core-c06`, kategorie `core-c06.b1`, `core-c06.b2`, `core-c06.c1`; w kategorii kolejność z listy roboczej). Innych plików bazy nie zmieniałem.

| | Liczba |
|---|---|
| Haseł na liście sharda | 621 (452 `new`, 18 `partial`, 151 `check`) |
| Hasła `new` napisane | 452 / 452 |
| Hasła `partial` uzupełnione | 18 / 18 |
| Hasła `check` z dopisanym ogólnym znaczeniem | 49 |
| Hasła `check` pominięte (ogólne znaczenie już w bazie) | 102 |
| **Wpisy (znaczenia)** | **566** (522 różne `term`) |
| **Przykłady** | **1890** (374 wpisy po 3, 192 po 4) |
| Rozmiar pliku | ~886 KB (poniżej progu `core-size` 650 wpisów) |

Rozkład CEFR wpisów: B1 15 · B2 201 · C1 350.
Części mowy: rzeczownik 235, przymiotnik 174, czasownik 136, przysłówek 20, czasownik frazowy 1.

Walidator: `node ios/tools/validate-content.mjs --file …/core/core-c06.json` → **OK: plików 1, wpisów 566, błędów 0, ostrzeżeń 0** (w tym bez `core-in-base`, `duplicate-example`, `core-example-variety`, `comma-splice`, `forms-base`). Każdy przykład ma 6–20 słów. Każdy wpis z 4 przykładami ma pytanie albo przeczenie (tryb rozkazujący typu *Stop…* walidator liczy jako zdanie twierdzące, więc takie przykłady przerobiłem). IPA sprawdzone skryptem: dla haseł, które mają już IPA w bazie (ta sama część mowy), transkrypcja jest identyczna. Nie uruchamiałem `build-index.mjs`, `build-core-master.mjs` bez `--shard` ani gita.

## 2. Wybrane decyzje redakcyjne

- **Osobne wpisy na ważne znaczenia** (43 hasła mają ich kilka), np. *breakdown* ×3 (awaria / załamanie nerwowe / zestawienie kosztów), *squeeze* (ścisnąć / wcisnąć się), *stiff* (sztywny / ostry o konkurencji), *undo* (rozpiąć / odwrócić skutki), *boast* (przechwalać się / szczycić się), *gamble* (uprawiać hazard / zaryzykować), *repay* (spłacić / odwdzięczyć się), *polish* (wypolerować / dopracować), *stink* (śmierdzieć / być do niczego), *zip* (zapiąć / spakować plik), *bare* (goły / bare minimum), *accessible* (dostępny / przystępny), *consciousness* (przytomność / świadomość), *crude* (prymitywny / wulgarny), *degrade* (poniżać / niszczyć), *domain* (dziedzina / domena internetowa), *gut* (przeczucie / brzuch), *progressive* (postępowy / postępujący), *appendix* (aneks / wyrostek), *assembly* (apel szkolny / montaż), *beam* (promień / belka), *bracket* (przedział / nawias), *critically* (krytycznie / ciężko), *romance* (romans / romantyczność). Pary części mowy jako osobne wpisy: *alert*, *alike*, *worldwide*, *itch*, *wrinkle*, *daydream*, *clone*, *complement*, *decay*, *elaborate*, *elite*, *gauge*, *grasp*, *incline*, *probe*, *span*, *articulate*.
- **Hasła dodatkowe spoza listy** (przypięte do lematu przez `k:`): *starving* (przym. „umierający z głodu”, B1, przy *starve*), *blend in* (wtopić się, przy *blend*), *amusement park* (park rozrywki, przy *amusement*; baza go nie miała).
- **Pisownia AmE**: lemat listy *likeable* zapisany jako `likable` (forma amerykańska), *likeable* jest w `acceptedAnswers`.
- **`check` → dopisane ogólne znaczenie** (49): spoil (zepsuć), steep (wygórowany o cenie), thoughtful (przemyślany), tragedy (nieszczęście), unconscious (nieświadomy), undo (rozpiąć; odwrócić skutki), unreliable (zawodny), venue (miejsce wydarzenia), vivid (jaskrawy), applaud (pochwalać), assemble (zebrać się), bounce (odbijać się), browse (przeglądać), conquer (pokonać strach), fetch (przynieść), overnight (na noc; z dnia na dzień), bumpy (wyboisty), reserved (zarezerwowany), rotten (paskudny), unpaid (niezapłacony), allowance (dodatek pieniężny), earnings (zarobki), fantasy (fantazja), harmony (zgoda), adaptation (przystosowanie), bundle (plik, wiązka), chronic (chroniczny), closure (zamknięcie, likwidacja), conserve (chronić przyrodę), deficiency (niedociągnięcie), donor (dawca), elevate (podnieść poziom), fraction (mała część), gross (obrzydliwy, AmE potoczne), liable (narażony, liable to), likewise (podobnie), loop (pętla, kształt), magnitude (ogrom), manuscript (maszynopis), merge (połączyć się), migrate (przenosić się, o ludziach), mobility (mobilność), niche (swoje miejsce), objection (sprzeciw), outlet (ujście dla emocji), rejection (odrzucenie), reproduce (rozmnażać się), sniff (pociągać nosem), sphere (sfera).
- **`check` pominięte** (102) — ogólne znaczenie już jest w bazie, np. *slippery, soak, sore, spill, stubborn, suspicious, swallow, betray, crawl, enroll, kneel, loosen, affordable, renew, rinse, scrub, bossy, greasy, moody, qualified, rusty, acquaintance, guidance, privacy, temper, allocate, audit, consensus, ethics, inequality, mediate, predator, prey, productivity, pulse, ritual, sin*. Pełna lista: wynik `cov.mjs` (zob. §6).
- **Tłumaczenia z nawiasem** (żeby nie dublować pary term+tłumaczenie z tematem albo odróżnić znaczenia): np. *tragedy* „tragedia (nieszczęście)”, *venue* „miejsce (wydarzenia)”, *steep* „wygórowany (o cenie)”, *harmony* „harmonia (zgoda)”, *fraction* „ułamek (mała część)”, *closure* „zamknięcie (likwidacja)”, *niche* „nisza (swoje miejsce)”, *undo-2* „odwrócić (skutki)”, *bound* „na pewno (be bound to)”, *gut* „przeczucie (intuicja)”. W `acceptedTranslations` są zawsze warianty bez nawiasu.
- **Fałszywi przyjaciele i uwagi w `notePl`**: *sympathetic* ≠ sympatyczny, *sympathy* ≠ sympatia, *terrific* ≠ straszny, *complement* ≠ compliment, *physician* ≠ physicist; uwagi o AmE: *overtake* (o autach w AmE *pass*), *quarrel* i *fetch* (w AmE rzadsze niż *argue/fight*, *go get*), *fringe* i *basin* (grzywka / umywalka to BrE), *postgraduate* (w AmE częściej *graduate*), *brackets* (w AmE nawiasy kwadratowe), *dissertation* (w AmE zwykle doktorat), *sneak* (cz. przeszły *snuck*), *dumb* (znaczenie „niemy” obraźliwe), *disabled*, *chubby*.
- **Jednostki**: w polskich zdaniach wartości metryczne (np. Denver „na wysokości około tysiąca sześciuset metrów”).

## 3. Zmiany CEFR / części mowy względem listy

- CEFR obniżone: *whistle* (cz.), *upgrade* (cz.), *sip* (rzecz.), *sweat* (rzecz.) B2→B1; *bizarre, chunk, flip, fluid, lump, overhead* (przysł.) C1→B2. *undo* (rozpiąć), *reserved* (zarezerwowany), *unpaid* (niezapłacony), *bumpy* (wyboisty), *overnight* (na noc) — B1; *gross* (obrzydliwy) B1.
- CEFR podwyższone: *overtake* B2→C1 (w AmE głównie „prześcignąć”), *applaud-2* (pochwalać) C1, *boast-2*, *stiff-2*, *accessible-2* C1.
- Kolejne znaczenia mają własny CEFR (np. *appendix* aneks C1 / wyrostek B2; *bracket* przedział C1 / nawias B2; *assembly* apel B2 / montaż C1; *breakdown* awaria B2 / pozostałe C1).
- Części mowy bez zmian względem listy, poza dodatkami z §2 (*starving* przym., *blend in* czasownik frazowy).

## 4. Wątpliwości i uwagi dla koordynatora

- **Pominięte świadomie**: *execute / execution* w znaczeniu „stracić / egzekucja” (treść drażliwa; opisane tylko „wykonać, realizacja”); *hedge* (zabezpieczenie finansowe — wąskie, specjalistyczne); *algorithm* — wpis tematu ma wąską definicję (media społecznościowe), ale polskie tłumaczenie jest identyczne, więc nie dublowałem. Na życzenie można dopisać.
- **Treści wrażliwe, ale częste w wiadomościach** (*missile, regime, slavery, invasion, nationalism, discrimination, corruption*) napisane neutralnie, bez przemocy.
- Kilka polskich odpowiedników zmienia część mowy (np. *unwilling* → „nie chcieć”, *worthwhile* → „warto”, *unreasonable* → „przesadzać”, *tempting* → „kusi”); te formy są w `acceptedTranslations`.

## 5. Prośby do innych ról

- Koordynator: po fali uruchomić `build-index.mjs` → `build-core-master.mjs` → pełny `validate-content.mjs` (§6). Statusy 49 haseł `check` z dopisanym znaczeniem zmienią się dopiero po przeliczeniu.

## 6. Narzędzia robocze (poza repozytorium)

Scratchpad sesji, katalog `c06w/`: `b01.txt`…`b14.txt` (format zwięzły), `conv.mjs` (konwerter → JSON, kolejność według listy, kontrola podciągów `focusEn`/`focusPl`, długości `definition`/`contextPl`, liczby przykładów), `look.mjs` (podgląd wpisów bazy z IPA), `cov.mjs` (pokrycie listy: brakujące `new/partial`, `check` z wpisem i bez), `ipachk.mjs` (zgodność IPA z bazą i słowa BrE), `lengthen.mjs` (wydłużenie przykładów poniżej 6 słów). JSON w repozytorium to jedyny wynik.

## 7. Hasła niedokończone

Brak — przeszedłem całą listę C06 (621 haseł).
