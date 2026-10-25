# Raport: core-content, shard C07

## 1. Co zrobiono

Plik: `ios/FluentNOW/Resources/Content/core/core-c07.json` (nowy, format §6 CONTENT-SCHEMA; kategorie `core-c07.b2` i `core-c07.c1`, wpisy w kategorii w kolejności listy roboczej).

| | Liczba |
|---|---|
| Haseł na liście sharda | 612 (479 `new`, 7 `partial`, 126 `check`) |
| Hasła `new` napisane | 479 / 479 |
| Hasła `partial` uzupełnione | 6 / 7 (pominięte: *on behalf of*, zob. §4) |
| Hasła `check`, do których dopisano ogólne znaczenie | 29 |
| Hasła `check` pominięte (ogólne znaczenie jest już w bazie) | 97 |
| **Wpisy (znaczenia)** | **546** (515 różnych `term`, w tym *in vain* dopisane przy *vain*) |
| **Przykłady** | **1662** (522 wpisy po 3, 24 po 4) |

Rozkład CEFR wpisów: B2 53 · C1 493 (shard to głównie słownictwo C1 — akademickie, czasowniki frazowe, idiomy, cechy i emocje).
Części mowy: przymiotnik 150, czasownik 145, rzeczownik 139, czasownik frazowy 53, przysłówek 28, zwrot 12, przyimek 10, idiom 7, spójnik 2.

Walidator: `node ios/tools/validate-content.mjs --file …/core/core-c07.json` → **0 błędów, 0 ostrzeżeń** (w tym brak `core-in-base`, `duplicate-example`, `duplicate-term-translation`, `core-example-variety`, `comma-splice`, `forms-base`, `pl-english`). Wszystkie przykłady mają 6–20 słów (sprawdzane dodatkowo w konwerterze). Nie uruchamiałem `build-index.mjs`, pełnego `build-core-master.mjs` ani git.

## 2. Wybrane decyzje redakcyjne

- **Wiele znaczeń jako osobne wpisy**: *superior* (lepszy adj. / przełożony n.), *transmit* (przesyłać / przenosić chorobę), *weave* (tkać / lawirować), *set back* (opóźnić / kosztować kogoś), *catch on* (przyjąć się / załapać), *dig into* (zagłębić się / zabrać się do jedzenia), *hold out* (wytrzymać / wyciągnąć rękę), *make for* (kierować się do / sprzyjać), *cave in* (zawalić się / ugiąć się), *conviction* (przekonanie / wyrok skazujący), *oversight* (przeoczenie / nadzór), *cultivate* (uprawiać / pielęgnować relacje), *deliberate* (celowy adj. / naradzać się v.), *disguise* (v./n.), *enclose* (załączyć / ogrodzić), *foster* (sprzyjać / być rodziną zastępczą), *grip* (v./n.), *halt* (v./n.), *plead* (błagać / przyznać się w sądzie), *retreat* (wycofać się v. / wyjazd integracyjny n.), *seize* (chwycić / przejąć), *unfold* (rozgrywać się / rozłożyć), *utter* (wypowiedzieć v. / kompletny adj.), *vow* (v./n.), *fling* (cisnąć v. / przelotny romans n.), *inflate* (napompować / zawyżać), *plunge* (gwałtownie spaść / rzucić się do wody), *sophisticated* (wyrafinowany / zaawansowany), *consistency* (konsekwencja / konsystencja), *denial* (zaprzeczenie / wypieranie), *take in* (przygarnąć / przyswoić — oba jako `check`).
- **`vain` + `in vain`**: obok przymiotnika „próżny” dopisałem zwrot *in vain* („na próżno”, `k: vain`) — to najczęstsze użycie.
- **`check` → dopisane ogólne znaczenie** (baza miała tylko wąskie znaczenie tematyczne): *stimulus* (bodziec), *thesis* (teza), *transmission* (transmisja/przenoszenie), *usage* (użycie słów), *take in* ×2, *call for* (wzywać do), *fall for* (zakochać się w), *make up for* (nadrobić), *stand by* (podtrzymywać zdanie), *wipe out* (zniszczyć doszczętnie), *step up* (zwiększyć), *size up* (ocenić), *confront* (stawić czoła), *quest* (poszukiwanie), *benchmark* (punkt odniesienia), *accommodate* (pomieścić), *concede* (przyznać niechętnie), *embark* (rozpocząć przedsięwzięcie), *juggle* (żonglować), *linger* (utrzymywać się), *sway* (przekonać), *thrive* (kwitnąć), *devastating* (druzgocący), *vibrant* (jaskrawy o kolorach), *fraud* (oszust — osoba), *shed* (pozbyć się/zrzucić), *blunt* (bezpośredni), *crooked* (nieuczciwy), *premature* (przedwczesny).
- **Nawias w `translation` przy kolizji z tematem** (zawsze z wariantem bez nawiasu w `acceptedTranslations`): *syndrome* „zespół (objawów)”, *transmit-2* „przenosić (chorobę)”, *put forward* „przedstawić (propozycję)”, *set back-2* „kosztować (kogoś)”, *stand by* „podtrzymywać (zdanie)”, *wind up* „skończyć (gdzieś)”, *step down* „ustąpić (ze stanowiska)”, *pin down* „ustalić (dokładnie)”, *scale back* „zmniejszyć (skalę)”, *tune in* „włączyć (program)”, *put across* „przekazać (myśl)”, *hold out-2* „wyciągnąć (rękę)”, *live up to* „spełnić (oczekiwania)”, *behalf* „w imieniu (kogoś)”, *concede* „przyznać (niechętnie)”, *embark* „rozpocząć (przedsięwzięcie)”, *cherish* „pielęgnować (wspomnienia)”, *cultivate-2* „pielęgnować (relacje)”, *mourn* „opłakiwać (zmarłego)”, *plead-2* „przyznać się (w sądzie)”, *retreat-2* „wyjazd (integracyjny)”, *resilience/resilient* „odporność/odporny (psychicznie)”, *scarce* „rzadki (deficytowy)”, *gasp* „westchnąć (ze zdziwienia)”, *plunge-2* „rzucić się (do wody)”, *foster-2* „wychowywać (jako rodzina zastępcza)”.
- `notePl` m.in.: fałszywi przyjaciele (*invaluable* ≠ bezwartościowy, *arguably* ≠ spornie, *ignorant* ≠ ignorujący, *infamous* ≠ nieznany, *hostile*, *trivial*, *integrity* ≠ zwykle integralność, *notorious* vs „notoryczny”, *vegetation*), mylone pary (*conscience/conscious*, *morale/moral*, *invoke/evoke*, *formerly/formally*, *continually/continuously*, *inhabit/inhibit*, *by no means/by all means*), konstrukcje (*await* bez *for*, *superior to*, *accustomed to + -ing*, *scarcely* bez *not*, *dispose of*, *dwell on*, *embark on*, *refrain from*), wymowa (*subtle*, *condemn*, *knowledgeable*, *wound* /waʊnd/, *mischievous*, *threshold*, *transplant* n./v., *deliberate* v./adj., *resume* v. vs *résumé*), AmE vs BrE (*tumor*, *endeavor*, *skepticism/skeptical*, *inquire*).
- Jednostki: w polskich zdaniach tylko wartości metryczne (np. *shed a few pounds* → „zrzuciłem parę kilogramów”).

## 3. Zmiany CEFR / części mowy względem listy

- CEFR obniżone C1→B2 (znaczenie znane już na B2): *strategic, superior* (adj.), *vague, take in* ×2, *fall for, make up for, hold back, get down to, live up to, narrow down, tune in, catch on-2* (załapać), *tear down, zone out, dig into-2, get ahead, give off, hold out-2, let off, run by, provided that, providing, in terms of, concerning, as for, prior to, regardless of, thoroughly, back and forth, take into account, take for granted, draw a conclusion, as a rule, to some extent, out of the blue, deliberate* (adj.), *juggle* (żonglować), *unfold-2* (rozłożyć), *brutal, devastated, fatal, harsh, hectic, inevitable, vulnerable, sophisticated-2, exceptional, upcoming, tolerate, unaware, hassle, fuss*.
- Część mowy: *deliberate, disguise, grip, halt, retreat, vow* — obie części mowy zgodnie z listą; dodatkowo *utter* (adj.) i *fling* (n.) obok czasowników z listy; *in vain* jako zwrot przy *vain*.
- *dispose, dwell, embark* opisane w konstrukcjach *dispose of / dwell on / embark on* (w `acceptedAnswers` obie formy) — samodzielnie prawie nie występują.

## 4. Wątpliwości i uwagi dla koordynatora

- **Pominięte `partial`: *on behalf of*** — baza ma „w imieniu” jako zwrot (`flight`, `greetings-introductions`); różnica tylko w etykiecie części mowy (jak *congratulations* w C04). Zamiast tego napisałem `new` *behalf* („w imieniu (kogoś)”, konstrukcje *on my/his behalf*, `acceptedAnswers` z *on behalf of*). Po przeliczeniu *on behalf of* nadal będzie `partial` — można je ręcznie oznaczyć jako zrobione.
- **Pominięte `check`** (97): ogólne znaczenie jest już w bazie (np. *stereotype, syllabus, thread, toxic, trait, iron out* — w bazie definicja „rozwiązać drobne problemy”, *rigid, endorse, nag, numb, hollow*). Do ewentualnego dopisania w kolejnej fali: *endorse* „poprzeć (pomysł)”, *rigid* „sztywny (zasady)” (to samo tłumaczenie co w temacie → `core-in-base`), *rattle* „zdenerwować” (*rattled*), *evaporate* „ulotnić się”.
- **Kolizje zdań z innymi shardami**: cztery moje zdania były identyczne z przykładami w C03/C04 (*prior to*, *regardless of*, *to some extent*, *the tip of the iceberg*) — zastąpione. C05/C06 pisane równolegle, więc warto po fali puścić pełny walidator.
- IPA *call for* (`/ˈkɔːl fɔːr/`), *fall for* (`/ˈfɔːl ˌfɔːr/`) skopiowane z bazy dla spójności, choć odbiegają od konwencji słabej formy przyimka (`/fər/`) — prośba do english-qa o ujednolicenie w tematach `cooking` i `cybersecurity`.
- Rozmiar pliku: 546 wpisów (poniżej progu `core-size` 650).

## 5. Prośby do innych ról

- Koordynator: po fali uruchomić `build-index.mjs` → `build-core-master.mjs` → pełny `validate-content.mjs` (zgodnie z §6). Statusy 29 haseł `check` z dopisanymi znaczeniami zmienią się dopiero po przeliczeniu.

## 6. Narzędzia robocze (poza repozytorium)

Treść pisałem w zwięzłym formacie tekstowym i zamieniałem na JSON skryptem Node w scratchpadzie (`…/scratchpad/c07w/`: `b01.txt`…`b13.txt`, `conv.mjs` — konwerter z C04 z dodatkową kontrolą długości zdań 6–20 słów i cyrylicy; `look.mjs` — podgląd wpisów bazy z IPA; `run.sh`). Skrypt sortuje wpisy według kolejności listy roboczej i układa je w kategorie CEFR. Plik JSON to jedyny wynik w repozytorium.

## 7. Hasła niedokończone

Brak — przeszedłem całą listę C07 (612 haseł).
