# Raport: core-content, shard C04

## 1. Co zrobiono

Plik: `ios/FluentNOW/Resources/Content/core/core-c04.json` (nowy, format §6 CONTENT-SCHEMA; kategorie `core-c04.a1` … `core-c04.c2`, wpisy w kategorii w kolejności listy roboczej).

| | Liczba |
|---|---|
| Haseł na liście sharda | 864 (367 `new`, 29 `partial`, 468 `check`) |
| Hasła `new` napisane | 366 / 367 (pominięte: *on purpose*, zob. §4) |
| Hasła `partial` uzupełnione | 26 / 29 (pominięte: *congratulations*, *hardly ever*, *by heart*, zob. §4) |
| Hasła `check`, do których dopisano ogólne znaczenie | 61 |
| Hasła `check` pominięte (ogólne znaczenie jest już w bazie) | 407 |
| **Wpisy (znaczenia)** | **475** (453 różne `term`) |
| **Przykłady** | **1765** (średnio 3,7 na wpis; 3–5 na każdy) |

Rozkład CEFR wpisów: A1 6 · A2 72 · B1 183 · B2 116 · C1 97 · C2 1.

Walidator: `node ios/tools/validate-content.mjs --file …/core/core-c04.json` → **0 błędów, 0 ostrzeżeń** (w tym brak `core-in-base`, `duplicate-example`, `duplicate-term-translation`, `core-example-variety`, `comma-splice`, `forms-base`, `pl-english`). Każdy wpis z 4–5 przykładami ma pytanie albo przeczenie. Nie uruchamiałem `build-index.mjs`, pełnego `build-core-master.mjs` ani git.

## 2. Wybrane decyzje redakcyjne

- **Wiele znaczeń jako osobne wpisy**: *advocate* (zwolennik n. / opowiadać się za v.), *establishment* (założenie / lokal), *prompt* (skłonić v. / szybki adj.), *dismiss* (odrzucić / zwolnić), *compromise* (pójść na kompromis / narazić na szwank), *swear* (przeklinać / przysięgać), *rough* (ciężki / przybliżony), *offense* (przestępstwo / obraza), *come out* (ukazać się / wyjść na jaw), *go down* (zejść A2 / spaść B1), *bring back* (przywieźć / przywołać), *take back* (cofnąć słowa / oddać do sklepu), *give away* (rozdać / zdradzić), *make up* (wymyślić / stanowić), *come on* (włączyć się – czasownik frazowy / „no chodź, dalej” – wykrzyknik); pary rzeczownik–czasownik: *divorce, glance, boost, cure, hurry, ski, magic* (n./adj.).
- **`check` → dopisane ogólne znaczenie** tam, gdzie baza miała tylko wąskie znaczenie tematyczne, np. *recovery* (powrót do zdrowia; w bazie tylko „powrót do normalności”), *tube* (rurka), *drag* (ciągnąć; w bazie tylko przeciąganie myszką), *angle* (punkt widzenia), *offense* (przestępstwo; obraza — w bazie tylko „atak” w sporcie), *cap* (nakrętka), *permission* (pozwolenie; w bazie „uprawnienie” aplikacji), *promotion* (promocja sprzedażowa), *chest* (skrzynia), *pump* (pompa; w bazie dystrybutor), *flash* (błysk), *historic* (historyczny/przełomowy), *twist, tackle, gear* (bieg), *clause* (zdanie składowe), *penalty* (kara), *curious* (ciekawy czegoś), *shelter* (schronienie), *regulate, mystery* (tajemnica; w bazie tylko „kryminał”), *amendment* (poprawka), *bunch* (mnóstwo), *tissue* (tkanka), *reflection* (refleksja), *nerve* (odwaga/tupet), *chase* (gonić; w bazie tylko „upominać się o”), *storage* (przechowywanie; w bazie tylko pamięć telefonu), *snap, immigration, tender* (czuły), *attachment* (przywiązanie), *exit* (wyjście; w bazie tylko zjazd z autostrady), *journal* (czasopismo naukowe), *grain* (ziarno), *bat* (kij), *bubble, correction, workshop* (warsztat), *backward*, czasowniki frazowe *pick up* (podnieść), *come back, go away, go on* (dziać się), *give back, get away, check out* (sprawdzić/zobaczyć), *fill in* (zastąpić), *turn up* (pojawić się), *turn around* (odwrócić się), *cool down, work out* (obliczyć), *set up* (założyć firmę/konto), *go out* (zgasnąć), *take out* (zabrać do restauracji).
- **Rozróżnienie od wpisów bazy nawiasem w `translation`** (jak w C03): *bubble* → „bańka (mydlana)” (w temacie *economy* jest „bańka” spekulacyjna), *curious* → „ciekawy (czegoś)”, *journal* → „czasopismo (naukowe)”, *take back* → „oddać (do sklepu)”, *take out* → „zabrać (do restauracji)”, *compound* → „związek (chemiczny)”, *carbon* → „węgiel (pierwiastek)”, *clause* → „zdanie (składowe)”.
- Jednostki: w polskich zdaniach wartości metryczne (*fifty pounds* → „dwadzieścia trzy kilogramy”, *a foot of snow* → „trzydziestocentymetrowa warstwa”).
- `notePl` m.in.: fałszywi przyjaciele (*consequently* ≠ konsekwentnie, *pretend* ≠ pretendować, *paragraph* ≠ paragraf, *after all* ≠ po wszystkim, *motor* ≠ motocykl, *racial* ≠ rasowy pies), mylone pary (*historic/historical, electric/electrical, classical/classic, even though/even if, by accident/by chance, sometime/sometimes, altogether/all together, relaxed/relaxing*), formy (*found – founded* vs *find – found*, *burst – burst – burst*, *read* /riːd/–/red/), AmE vs BrE (*dialog, catalog, afterward, backward, transportation, counseled, fulfill, elementary school*), rejestr (*reckon, keen on, cinema, lecturer, parcel, beneath, infant*).

## 3. Zmiany CEFR / części mowy względem listy

- *regret* (rzeczownik „żal”) B1→B2; *go down* (zejść) B1→A2 (znaczenie „spaść o cenach” zostało B1).
- Kolejne znaczenia mają własny CEFR: *rough* ciężki B1 / przybliżony B2; *offense* obraza B2 / przestępstwo C1; *compromise* B2 / C1; *come out* B1 / B2; *give away* B1 / B2; *make up* B1 / B2; *bring back* A2 / B1; *take back* B1 / A2; *come on* B1 (czasownik frazowy) / A2 (wykrzyknik).
- Część mowy: *come on* — oprócz brakującego czasownika frazowego („włączyć się”) dopisany wykrzyknik „no chodź / dalej”, bo istniejący wpis bazy („no weź!”) to inne użycie. *super* — tylko przysłówek („bardzo”, potoczny AmE); przymiotnik *super* pominąłem jako rzadki w AmE.

## 4. Wątpliwości i uwagi dla koordynatora

- **Pominięte `partial`** (to samo znaczenie jest w bazie, różnica jest tylko w etykiecie części mowy): *congratulations* (baza: „gratulacje” jako wykrzyknik), *hardly ever* (baza: „prawie nigdy” jako zwrot), *by heart* (baza: „na pamięć” jako idiom). Nowy wpis dałby `core-in-base` lub dubel znaczenia. Po przeliczeniu `build-core-master.mjs` nadal będą `partial` — można je przestawić ręcznie na „done”.
- **Pominięte `new`: *on purpose*** — w trakcie pracy hasło z tym samym tłumaczeniem („celowo”) pojawiło się w `core-c02.json` (`core.on-purpose`); walidator zgłosił duplikat id i term+translation, więc usunąłem swój wpis.
- **Kolizje zdań z innymi shardami**: kilkanaście moich zdań okazało się identycznych z przykładami w C01/C02/C03/C05 (np. *The keys are on top of the fridge.*, *We met by chance at the airport.*); wszystkie zastąpiłem. Ponieważ C01/C02 pisane są równolegle, warto po fali puścić pełny walidator — kolizja mogła powstać po mojej ostatniej walidacji po stronie innego sharda.
- **Pominięte `check`** (407): ogólne znaczenie jest już w bazie. Do ewentualnego dopisania w kolejnej fali (rzadsze lub frazowe znaczenia): *stroke* (a stroke of luck), *mad* (szalony), *craft* (statek / kunszt), *seal* (pieczęć), *mount* (narastać), *stake* (at stake), *boom* (huk), *charity* (dobroczynność), *deposit* (złoże, osad).
- `interviewer` ma długie tłumaczenie główne („osoba prowadząca rozmowę kwalifikacyjną”); krótsze warianty (*rekruter, prowadzący wywiad, ankieter*) są w `acceptedTranslations`.
- Rozmiar pliku: 475 wpisów (poniżej progu `core-size` 650).

## 5. Prośby do innych ról

- Koordynator: po fali uruchomić `build-index.mjs` → `build-core-master.mjs` → pełny `validate-content.mjs` (zgodnie z §6). Statusy 61 haseł `check` z dopisanymi znaczeniami zmienią się dopiero po przeliczeniu.

## 6. Narzędzia robocze (poza repozytorium)

Treść pisałem w zwięzłym formacie tekstowym i zamieniałem na JSON skryptem Node w scratchpadzie (`…/scratchpad/c04w/`: `b01.txt`…`b12.txt`, `conv.mjs` — kopia konwertera z C03 z podmienionym id; `fix1.mjs`, `delent.mjs` — pomocnicze podmiany). Skrypt sortuje wpisy według kolejności z listy roboczej i układa je w kategorie CEFR. Plik JSON to jedyny wynik w repozytorium.
