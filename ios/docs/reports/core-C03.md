# Raport: core-content, shard C03

## 1. Co zrobiono

Plik: `ios/FluentNOW/Resources/Content/core/core-c03.json` (nowy, format §6 CONTENT-SCHEMA; kategorie `core-c03.a1` … `core-c03.c1`, wpisy w kategorii w kolejności listy roboczej).

| | Liczba |
|---|---|
| Haseł na liście sharda | 766 (361 `new`, 49 `partial`, 356 `check`) |
| Hasła `new` napisane | 361 / 361 |
| Hasła `partial` uzupełnione | 49 / 49 |
| Hasła `check`, do których dopisano ogólne znaczenie | 67 |
| Hasła `check` pominięte (ogólne znaczenie jest już w bazie) | 289 |
| **Wpisy (znaczenia)** | **548** (477 różnych `term`) |
| **Przykłady** | **2007** (średnio 3,7 na wpis; 3–5 na każdy) |

Rozkład CEFR wpisów: A1 8 · A2 47 · B1 169 · B2 234 · C1 90 · C2 0.

Walidator: `node ios/tools/validate-content.mjs --file …/core/core-c03.json` → **0 błędów, 0 ostrzeżeń** (w tym brak `core-in-base`, `duplicate-example`, `core-example-variety`, `comma-splice`, `forms-base`). Każdy wpis z 4–5 przykładami ma pytanie albo przeczenie. Nie uruchamiałem `build-index.mjs`, pełnego `build-core-master.mjs` ani git.

## 2. Wybrane decyzje redakcyjne

- **Wiele znaczeń jako osobne wpisy**, np. *provision* (zapewnienie / postanowienie), *concentrate* (skupić się / skupiać w jednym miejscu), *reasonable* (rozsądny / przystępny cenowo), *odd* (dziwny / nieparzysty), *succeed* (odnieść sukces / objąć stanowisko po), *resolution* (postanowienie / rozdzielczość / rozwiązanie), *expose*, *estate*, *convention*, *foundation*, *bother*, *badly*, *interpret*, *panel*, *demonstration*, *fault*, *youth*, *vision*, *intelligence*.
- **`check` → dopisane ogólne znaczenie** tam, gdzie baza miała tylko wąskie znaczenie tematyczne, np. *shot* (próba, *give it a shot*), *session* (zajęcia), *loan* (pożyczka), *tip* (wskazówka; czubek), *rare* (rzadki — w bazie tylko „krwisty”), *soul* (dusza — w bazie tylko gatunek muzyczny), *platform* (platforma), *foundation* (podstawa; fundacja — w bazie tylko „podkład”), *expansion* (rozwój — w bazie tylko dodatek do gry), *framework* (ramy), *knock* (pukać), *gate* (brama), *chip* (chipsy — AmE), *meter* (metr), *cloud* (chmura na niebie — w bazie tylko chmura obliczeniowa), *dish* (naczynie), *withdraw* (wycofać się).
- **Hasła-zwroty zamiast samego lematu** (pole `term` inne niż lemat listy): *in a row* (dla `row` — „rząd” już w bazie), *be sick of* (dla `sick` — „chory” już w bazie). Dla *folk* wpis `folk` z formą *folks* (AmE: ludzie / rodzice). *mate* opisane głównie w złożeniach AmE (*roommate, classmate, teammate*), bo samo *mate* = kumpel jest brytyjskie.
- **Rozróżnienie od wpisów bazy przez inne tłumaczenie**: *peak* → „szczyt (najwyższy poziom)” i *cloud* → „chmura (na niebie)” (tłumaczenie bez nawiasu dublowałoby się z wpisem tematu, zob. §4).

## 3. Zmiany CEFR / części mowy względem listy

- CEFR obniżone (lista była zawyżona dla najczęstszego znaczenia): *somewhat, merely, self, prime, motion, forth, fundamental, distinguish, substantial, occupy, dominate, ease (rzecz.), assure, strain, strip (rzecz.), resistance, entitled, core (przym.), variable (przym.)* C1→B2; *opposition (sprzeciw)* C1→B2 (opozycja polityczna została w C1); *resolution (postanowienie)* C1→B1; *folk (ludowy)* B2→B1; *grab* B2→B1.
- CEFR podwyższone: *sail* A2→B1, *brilliant* A2→B1.
- Kolejne znaczenia mają własny CEFR (np. *judgment* osąd B2 / wyrok C1; *absence* nieobecność B2 / brak C1).
- Część mowy: *plenty, latter* → `zaimek` (zgodnie z listą); *dozen* opisane jako *dozens of* = dziesiątki (tuzin już w bazie).

## 4. Wątpliwości i uwagi dla koordynatora

- **Tłumaczenia z nawiasem** (*peak* „szczyt (najwyższy poziom)”, *cloud* „chmura (na niebie)”) — dobrałem je tak, żeby walidator nie zgłaszał `core-in-base`. Znaczenie *chmura* jest inne niż w temacie (tam: chmura obliczeniowa), ale klucz term+tłumaczenie byłby ten sam. Jeśli wolicie inny sposób rozróżniania znaczeń, wystarczy zmienić `translation` (pozostałe pola są gotowe).
- **Pominięte `check`** (289): ogólne znaczenie jest już w bazie, a dodatkowe znaczenia są rzadkie albo tylko frazowe (np. *hunt for*, *bend*, *spell* = zaklęcie, *yard* = jard, *smart* = elegancki w BrE). Na życzenie można je dopisać w kolejnej fali.
- `mathematics` stoi obok `math` z tematu *school* (inny `term`, to samo tłumaczenie). Zostawiłem, bo *mathematics* to osobne hasło NGSL, w notce jest „w mowie AmE prawie zawsze math”.
- `pupil`, `secondly`, `fellow` mają w `notePl` informację o rejestrze i częstości w AmE.
- Przykłady z jednostkami imperialnymi mają po polsku wartości metryczne (np. *two feet of snow* → „sześćdziesiąt centymetrów śniegu”, *fifty pounds* → „około dwudziestu trzech kilogramów”).
- Rozmiar pliku: 548 wpisów (poniżej progu `core-size` 650).

## 5. Prośby do innych ról

- Koordynator: po fali uruchomić `build-index.mjs` → `build-core-master.mjs` → pełny `validate-content.mjs` (zgodnie z §6). Statusy `check` dla 67 haseł z dopisanymi znaczeniami zmienią się dopiero po przeliczeniu.

## 6. Narzędzia robocze (poza repozytorium)

Treść pisałem w zwięzłym formacie tekstowym i zamieniałem na JSON skryptem Node w scratchpadzie (`…/scratchpad/c03w/`: `b01.txt`…`b15.txt`, `conv.mjs`). Skrypt sortuje wpisy według kolejności z listy roboczej i układa je w kategorie CEFR. Plik JSON to jedyny wynik w repozytorium.
