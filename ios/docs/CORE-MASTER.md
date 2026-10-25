# CORE-MASTER — słownik rdzeniowy (FEEDBACK-7 L1)

> **Plik generowany** przez `node ios/tools/build-core-master.mjs` (nie edytuj ręcznie — zmieniaj źródła w `ios/tools/data/core/`).
> Dane: `ios/docs/CORE-MASTER.json`. Format wpisów treści: `ios/docs/CONTENT-SCHEMA.md` §6. Instrukcja autorów: `ios/docs/agents/03b-core-content.md`.

## Źródła i licencje

| Źródło | Autorzy | Licencja | Użycie |
|---|---|---|---|
| [New General Service List (NGSL) 1.2](https://www.newgeneralservicelist.com/new-general-service-list) (2809 lematów, ranking częstości) | Browne, C., Culligan, B., Phillips, J. | CC BY-SA 4.0 | rdzeń listy; ranking NGSL = priorytet |
| [New Academic Word List (NAWL) 1.2](https://www.newgeneralservicelist.com/new-academic-word-list) (957 lematów) | Browne, C., Culligan, B., Phillips, J. | CC BY-SA 4.0 | słownictwo akademickie / ogólne B2–C1 (bez terminologii ścisłej) |
| Uzupełnienie FluentNOW (`supplement.txt`) | redakcja FluentNOW | jak repozytorium | czasowniki frazowe, wyrażenia łączące, kolokacje, słownictwo ogólne i C1–C2 spoza NGSL/NAWL |

Listy NGSL i NAWL zweryfikowano na stronie projektu (WebFetch, 2026-10-24): obie z dopiskiem „licensed under a Creative Commons Attribution-ShareAlike 4.0 International License”. Kopie list źródłowych: `ios/tools/data/core/ngsl-1.2.txt`, `nawl-1.2.txt`. Lista pochodna (ten plik i `CORE-MASTER.json`) jest udostępniana na tej samej licencji **CC BY-SA 4.0** z uznaniem autorstwa jak wyżej.

**Nie korzystamy** z list zastrzeżonych (Oxford 3000/5000, English Vocabulary Profile, Cambridge, Longman Communication 3000) — ani do kopiowania, ani do importu poziomów. CEFR, części mowy i formy haseł to **własne oceny redakcyjne** FluentNOW (`annotations-*.txt`, `supplement.txt`).

## Jak powstała lista

1. NGSL: lematy przypisane do haseł dla ucznia (`excite` → *excited*, *exciting*; `accord` → *according to*; `TRUE` → *true*), z częściami mowy i CEFR. Pominięte (103): słowa gramatyczne A1 (the, of, will, can…), zaimki, liczebniki, wykrzyknienia, wulgaryzmy, formy brytyjskie (*whilst*, *autumn*, *pub*), tematy drażliwe.
2. NAWL: bez terminologii specjalistycznej i przedrostków (pominięto 165).
3. Uzupełnienie FluentNOW (1845 pozycji): czasowniki frazowe, spójniki i przyimki złożone (*despite*, *whereas*, *nevertheless* są w NGSL; tu m.in. *in spite of*, *as long as*, *provided that*), kolokacje i zwroty (*make a decision*, *take into account*), słownictwo ogólne B1–C1 (np. *attain*, *reluctant*, *thorough*) i ograniczona lista C1–C2 „przydatnych w życiu”.
4. Duplikaty między źródłami są scalane (pole `sources` wymienia wszystkie).
5. Status względem bazy (`dictionary-index`: tematy + starter) i plików `core/`.

## Pola `lemmas[]`

| Pole | Znaczenie |
|---|---|
| `id` | kebab-case hasła — z niego powstaje `id` wpisu: `core.<id>`, kolejne znaczenia `core.<id>-2`, `-3` |
| `lemma` | hasło w formie słownikowej (tak jak `term` wpisu) |
| `pos` | części mowy do pokrycia (PL, wg CONTENT-SCHEMA §1), w kolejności ważności |
| `level` | szacowany CEFR **głównego** znaczenia (wpisy dostają CEFR per znaczenie) |
| `priority` | mniejszy = ważniejszy: ranking NGSL (1–2809), potem pasma poziomów A1→C2 dla NAWL i uzupełnienia (od 3000) |
| `sources` | `NGSL #ranking`, `NAWL <lemat>`, `FluentNOW/<sekcja>` |
| `senses` | szacowana liczba ważnych znaczeń (wpisów) dla nowego hasła |
| `status` | `new` — brak w bazie; `partial` — hasło jest, ale brakuje części mowy z `missingPos`; `check` — hasło jest we wszystkich częściach mowy, autor sprawdza tylko, czy brakuje **ogólnego** znaczenia (wpisy tematów bywają wąskie); `done` — są wpisy w `core/` |
| `missingPos` | części mowy bez wpisu w bazie ani w core |
| `estimate` | szacowana liczba wpisów do napisania (do bilansowania shardów) |
| `shard` | przydział `C01`…; plik `core/core-c01.json` |
| `base` | do 8 istniejących wpisów bazy o tym samym haśle: `r` (referencja), `p` (tłumaczenie), `l` (CEFR), `pos` |
| `core` | referencje istniejących wpisów core |

**Shardy** grupują hasła **wg priorytetu (częstości)**: C01 zawiera najczęstsze brakujące słowa, kolejne coraz rzadsze — każdy shard ma spójny zakres poziomów, a niedokończona fala L2 i tak pokryje to, co najważniejsze. Cel: ok. 500 szacowanych wpisów na shard. Przydział jest **stały** (ponowne uruchomienie zachowuje shardy; `--reshard` tylko przed startem L2).

## Podsumowanie

- Hasła: **5367** (NGSL: 2730, NAWL: 792, tylko uzupełnienie FluentNOW: 1845).
- Status: nowe **137**, częściowe 25, do sprawdzenia 1840, gotowe w core 3365.
- Szacowane wpisy do napisania: **163**.

| CEFR | A1 | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|---|
| wszystkie hasła | 484 | 688 | 1320 | 1426 | 1246 | 203 |
| do napisania (new + partial) | 4 | 3 | 8 | 8 | 121 | 18 |

| Część mowy (główna) | Hasła |
|---|---|
| rzeczownik | 2165 |
| czasownik | 1026 |
| przymiotnik | 1216 |
| przysłówek | 295 |
| przyimek | 72 |
| spójnik | 27 |
| zaimek | 17 |
| czasownik frazowy | 321 |
| zwrot | 198 |
| idiom | 30 |

## Shardy

| Shard | Plik | Hasła | Do napisania | Do sprawdzenia | Gotowe | Szac. wpisy | A1 | A2 | B1 | B2 | C1 | C2 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| C01 | `core/core-c01.json` | 620 | 6 | 219 | 395 | 6 | 249 | 186 | 163 | 22 | 0 | 0 |
| C02 | `core/core-c02.json` | 850 | 3 | 394 | 453 | 3 | 146 | 176 | 345 | 175 | 8 | 0 |
| C03 | `core/core-c03.json` | 768 | 0 | 291 | 477 | 0 | 52 | 120 | 264 | 235 | 97 | 0 |
| C04 | `core/core-c04.json` | 865 | 4 | 407 | 454 | 4 | 37 | 206 | 358 | 151 | 111 | 2 |
| C05 | `core/core-c05.json` | 778 | 9 | 317 | 452 | 9 | 0 | 0 | 190 | 588 | 0 | 0 |
| C06 | `core/core-c06.json` | 621 | 1 | 102 | 518 | 1 | 0 | 0 | 0 | 255 | 366 | 0 |
| C07 | `core/core-c07.json` | 613 | 121 | 103 | 389 | 121 | 0 | 0 | 0 | 0 | 613 | 0 |
| C08 | `core/core-c08.json` | 252 | 18 | 7 | 227 | 19 | 0 | 0 | 0 | 0 | 51 | 201 |

Lista robocza sharda: `node ios/tools/build-core-master.mjs --shard C03` (z `--all` także hasła gotowe i do sprawdzenia).
