# Raport: english-qa, zakres QA-T2 (shardy S3 i S4)

Przejrzałem wszystkie 24 tematy, czyli 2019 wpisów. W każdym wpisie sprawdziłem hasło, IPA, poziom CEFR, tłumaczenie, `acceptedTranslations` i `acceptedAnswers`, definicję, synonimy, notatkę oraz oba przykłady EN i PL razem z fokusami. Wszystkie pliki przechodzą `validate-content.mjs` (24 pliki, 2019 wpisów, 0 błędów, 0 ostrzeżeń). Indeks przebudowałem poleceniem `build-index.mjs` (142 tematy, 10 690 wpisów, 10 711 rekordów słownika). Identyfikatorów wpisów nie zmieniałem. Gita nie uruchamiałem, poza jednym przypadkowym, tylko do odczytu `git diff --stat` na samym początku pracy.

Poprawki nanosiłem skryptem w scratchpadzie (`t2/fixes/<temat>.mjs` i `apply.mjs`). Skrypt sprawdzał, czy `focusEn` i `focusPl` są podciągami zdań, zapisywał JSON z wcięciem 2 spacji, w UTF-8 i z LF, a log zmian prowadził w `t2/log/`.

## 1. Statystyka

| plik | wpisów | wpisów z poprawką merytoryczną | % | zmienionych pól | ujednolicone IPA (ɛ→e) |
|---|---|---|---|---|---|
| restaurant | 112 | 6 | 5,4% | 8 | 23 |
| cafe-bakery | 102 | 7 | 6,9% | 9 | 13 |
| cooking | 104 | 5 | 4,8% | 7 | 13 |
| grocery-shopping | 86 | 3 | 3,5% | 4 | 15 |
| fruits-vegetables | 85 | 1 | 1,2% | 3 | 17 |
| meat-fish-dairy | 88 | 3 | 3,4% | 10 | 17 |
| drinks-bar | 75 | 4 | 5,3% | 7 | 8 |
| diet-nutrition | 77 | 4 | 5,2% | 8 | 13 |
| house-rooms | 81 | 5 | 6,2% | 8 | 12 |
| furniture-household | 79 | 4 | 5,1% | 5 | 19 |
| cleaning-chores | 83 | 2 | 2,4% | 2 | 7 |
| renting-apartment | 68 | 3 | 4,4% | 4 | 20 |
| doctor-visit | 105 | 1 | 1,0% | 1 | 0 |
| symptoms-illness | 95 | 9 | 9,5% | 12 | 0 |
| body-parts | 89 | 2 | 2,2% | 2 | 0 |
| pharmacy | 74 | 4 | 5,4% | 8 | 0 |
| hospital-emergency | 74 | 3 | 4,1% | 3 | 0 |
| dentist | 63 | 3 | 4,8% | 3 | 0 |
| fitness-gym | 77 | 5 | 6,5% | 6 | 0 |
| mental-health | 79 | 1 | 1,3% | 2 | 0 |
| sleep | 74 | 2 | 2,7% | 2 | 0 |
| sports | 88 | 1 | 1,1% | 1 | 0 |
| pets | 75 | 4 | 5,3% | 4 | 0 |
| animals | 86 | 3 | 3,5% | 3 | 0 |
| **razem** | **2019** | **85** | **4,2%** | **122** | **177** |

**Zmienione pola według kategorii (122):**

| kategoria | pól |
|---|---|
| polskie tłumaczenia przykładów / `focusPl` / `translation` | 39 |
| synonimy, definicje, notatki, rejestr (`DEF`) | 38 |
| `acceptedTranslations` / `acceptedAnswers` mieszające znaczenia (`ACC`) | 33 |
| przykłady EN (gramatyka, naturalność) | 9 |
| słownictwo BrE w polach AmE | 2 |
| IPA (pojedyncza błędna transkrypcja) | 1 |

**Konwencja IPA.** Uzgodniłem ją z english-qa-T1 i english-qa-T3; obaj potwierdzili. Obowiązuje styl Oxford Learner's US:
- samogłoska DRESS jako /e/, a nie /ɛ/;
- /ɜːr/ w sylabie akcentowanej, /ər/ w nieakcentowanej, bez ɝ/ɚ;
- /iː uː ɑː ɔː oʊ/;
- przed r: /ɪr er ʊr ɑːr ɔːr/;
- trójgłoski /aɪər aʊər/.

S4 już stosował tę konwencję. W S3 wszędzie było /ɛ/, więc zamieniłem je automatycznie w 177 wpisach, także w IPA cytowanym w `notePl`. Kontrola automatyczna po zmianach:
- nie ma brytyjskich dwugłosek /ɪə eə ʊə əʊ/ ani /ɒ/;
- nie ma IPA bez rotyczności przy pisanym „r”;
- każde wielosylabowe IPA ma znak akcentu;
- wszystkie IPA są w ukośnikach i nie zawierają obcych znaków.

**CEFR.** Nie znalazłem rażących zawyżeń ani zaniżeń. Hasła o poziom za wysokie (np. `understaffed`, `throbbing`, `circuit`, `endurance`, `chronic` jako C1, gdzie bardziej pasuje B2) zostawiłem: to kwestia ocenna, nie błąd.

## 2. Najważniejsze poprawki

| plik | id | pole | było | jest | kategoria |
|---|---|---|---|---|---|
| meat-fish-dairy | curdle | translation, przykłady | zważyć się / zważyła / zważy się | zwarzyć się / zwarzyła / zwarzy się | PL ortografia („zważyć” = ważyć) |
| meat-fish-dairy | shellfish | e0.pl | Skorupiaki, takie jak małże i omułki… | Owoce morza w muszlach, takie jak małże i omułki… | terminologia (małże to mięczaki, nie skorupiaki) |
| pets | tick | definition | A small insect that bites… | A small creature, related to spiders, that bites… | merytoryka (kleszcz to pajęczak) |
| hospital-emergency | triage | ipa | /ˈtriːɑːʒ/ | /triˈɑːʒ/ | IPA, akcent GA |
| diet-nutrition | sodium | acceptedTranslations / acceptedAnswers / synonyms | sód; sól / salt / salt | sód / sodium / — | mieszanie znaczeń (sód ≠ sól) |
| doctor-visit | blood-test | acceptedTranslations | …; morfologia | badanie krwi; badania krwi | terminologia (morfologia to jedno konkretne badanie) |
| symptoms-illness | cold | acceptedTranslations | przeziębienie; katar | przeziębienie | mieszanie z hasłem `runny-nose` |
| symptoms-illness | strep-throat | acceptedTranslations | …; zapalenie gardła | …; paciorkowcowe zapalenie gardła | terminologia |
| symptoms-illness | tissue | synonyms | Kleenex | — | nazwa marki |
| pharmacy | bandage | acceptedAnswers / synonyms / notePl | Band-Aid… | adhesive bandage | nazwa marki |
| symptoms-illness | vomit | e0.pl | …zawieziemy go na pogotowie. | …zawieziemy go do lekarza. | PL (urgent care ≠ pogotowie) |
| sports | soccer | e0.en | In the US, people call soccer what most of the world calls football. | In the US, what most of the world calls football is called soccer. | EN logika zdania |
| fruits-vegetables | pit | e0 | …these cherries still have the pit inside. | …these cherries still have their pits. | EN naturalność |
| restaurant | split-the-bill | e1.en | split the bill onto two cards | split the bill between two cards | EN kolokacja |
| furniture-household | matching | e1.en | The chairs don't need to be matching… | We don't need matching chairs… | EN naturalność |
| house-rooms | settle-in | e1.en | settled in to their new rooms | settled into their new rooms | EN pisownia/gramatyka |
| diet-nutrition | trace | e1.en | …so it may have traces. | …in a factory that handles nuts, so it may contain traces. | EN kolokacja |
| drinks-bar | drink-2 | e1 | zdanie prawie identyczne jak e0 | I'll have one more drink and then head home. | przykłady zbyt podobne |
| pets | puppy | e0.pl | …spały w jednej wielkiej kupce. | …spały zbite w jedną wielką gromadkę. | PL dwuznaczność („kupka”) |
| pets | puppy-love | e1.pl | Ci dwoje nastolatków… wyglądają… | Tych dwoje nastolatków… wygląda… | PL składnia liczebnika zbiorowego |
| restaurant / cafe-bakery / grocery | cash-or-card, for-here-or-to-go, paper-or-plastic | e1.pl, focusPl | czy X czy Y | czy X, czy Y | PL interpunkcja |
| meat-fish-dairy | rare | synonyms | bloody | — | AmE (bloody nie jest synonimem w USA) |
| cafe-bakery | cookie | synonyms | biscuit | — | sprzeczne z notatką (biscuit w USA to co innego) |
| cafe-bakery | to-go | synonyms | takeout; takeaway | takeout | BrE w polu AmE |
| cleaning-chores | do-the-dishes | synonyms | wash up | wash the dishes | AmE (wash up = umyć ręce) |
| cafe-bakery | sourdough | acceptedTranslations | …; zakwas | …; pieczywo na zakwasie | mieszanie znaczeń (zakwas = starter) |
| house-rooms | deck | synonyms / natural / acceptedAnswers | patio | — / deck | mieszanie znaczeń |
| house-rooms | closet | notePl | mebel to „wardrobe” lub „dresser” | wolnostojąca szafa to „armoire” lub „wardrobe” | dresser = komoda |
| fitness-gym | mat / lunge | acceptedTranslations | karimata / zakrok | — | mieszanie znaczeń |
| animals | horse | acceptedTranslations | kobyła | konik | mieszanie znaczeń |
| animals | crocodile | synonyms | alligator | — | to inne zwierzę |

Pozostałe poprawki są tego samego typu: usunięcie błędnych synonimów (oat milk → almond milk, smoothie → shake, rug → carpet, extension cord → power strip, radiator → heater, credit check → background check, burn the midnight oil → pull an all-nighter i podobne), usunięcie mylących `acceptedTranslations` (blender → mikser, raw → niedopieczony, produce → warzywniak, junk → złom, repair → remont, cavity → próchnica, bloated → przejedzony i podobne) oraz drobne wygładzenia polszczyzny. Pełna lista ze starą i nową wartością każdego pola jest w `scratchpad/t2/log/*.json`.

## 3. Prośby autorów (S3 §5, S4 §5)

- **Pary znaczeniowe** `waiter`/`server`, `main course`/`entrée`, `deal`/`overpriced`, `essentials`/`staple`, `landlord`/`owner`: wszystkie są poprawnie rozróżnione. `server` to neutralne słowo AmE z prawidłową notatką. `entrée` jako danie główne w USA jest poprawne. `landlord` ma znaczenie „wynajmujący”, a `owner` ogólne „właściciel”. Bez zmian.
- **IPA długich zwrotów**: sprawdzone wszystkie. Poprawiłem tylko `triage`; reszta, łącznie z konwencją ɜːr, jest poprawna.
- **Idiomy**: `like herding cats` → „jak pilnowanie worka pcheł” i `in a funk` → „w dołku” to trafne, naturalne odpowiedniki. Bez zmian.
- **`mince`** (czasownik w AmE), **`tube`** (tubka) i **`trainers`** (l.mn. od trainer) to fałszywe alarmy walidatora. Walidator już ich nie zgłasza (0 ostrzeżeń).

## 4. Wątpliwości, których nie rozstrzygnąłem

1. **CEFR o jeden poziom za wysoko** (C1 zamiast B2) w kilkunastu hasłach specjalistycznych: `understaffed`, `throbbing`, `hygienist`, `plaque`, `circuit`, `endurance`, `chronic`, `discharge`, `concussion`, `migrate`, `enclosure`, `sleep-deprived`, `blue light`. To nie są rażące błędy, więc ich nie ruszałem. Warto je ujednolicić według korpusu.
2. **Format `forms`**: S3 używa „–” (`cozier – coziest`), a S4 „;” (`sharper; sharpest`). Schemat podaje „–” dla odmiany czasownika, więc warto ujednolicić całą bazę osobnym skryptem.
3. **`doctor-visit.doctors-note`**: wśród `acceptedTranslations` są „zwolnienie lekarskie” i „zwolnienie”, choć notatka mówi, że to nie formalne L4. Zostawiłem, bo uczący się naturalnie tak odpowie.
4. **`urgent-care`**: tłumaczenie „punkt pomocy doraźnej” / „nocna i świąteczna pomoc” jest przybliżone, bo w Polsce nie ma dokładnego odpowiednika. Zostawiłem.
5. **Literówka w innych tematach**: forma „zważyć się” w znaczeniu „zwarzyć się” może występować poza moim zakresem. `grep` „zważy” znalazł pliki airport, everyday-phrasal-verbs, giving-advice i post-office. Prawdopodobnie chodzi tam o „ważyć”, ale warto, żeby QA-T1, T3 i T6 to sprawdziły.
