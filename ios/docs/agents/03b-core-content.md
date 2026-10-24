# Rola: core-content („autor słownika rdzeniowego”) — shardy C01…C08

Fala L2 z FEEDBACK-7. Uruchamiana jako kilka równoległych **shardów** (po 3 naraz). Obszar: **wyłącznie** plik `ios/FluentNOW/Resources/Content/core/core-<shard>.json` twojego sharda (np. `core-c03.json`). Raport: `ios/docs/reports/core-content-<shard>.md`.

Przeczytaj najpierw: `ios/docs/AGENTS-BRIEF.md` §5 i §7, `ios/docs/CONTENT-SCHEMA.md` §1 (cały, z konwencjami `forms`/IPA i ostrzeżeniami redakcyjnymi) oraz **§6 (słownik rdzeniowy)**, `ios/docs/CORE-MASTER.md`. Wzór jakości: `core/core-c01.json` (17 wpisów, m.in. *attain, ensure, maintain/maintain-2, despite, whereas, tend*).

## Cel

Baza tematów (142 tematy, ~10 700 wpisów) pokrywa sytuacje (lotnisko, lekarz…), ale brakuje **ogólnego rdzenia języka** — słów, które aplikacja musi znać przy szybkim dodawaniu, w czytankach i w teście poziomu (*achieve, require, significant, despite…*). Twój shard to część tego rdzenia, wybrana z list NGSL/NAWL (CC BY-SA) i uzupełnienia FluentNOW. Każde znaczenie dostaje **3–5 przykładów** zamiast 2 — więcej zdań = więcej różnorodnych zadań (luka, tłumaczenie, rozsypanka, słuchanie).

## Lista robocza

```
node ios/tools/build-core-master.mjs --shard C03          # hasła do napisania i do sprawdzenia
node ios/tools/build-core-master.mjs --shard C03 --all    # także gotowe
```

Kolumny: `status | hasło | części mowy | CEFR | szac. wpisy | istniejące wpisy bazy (tłumaczenie [pos, CEFR] referencja)`.

| Status | Co robisz |
|---|---|
| `new` | hasła nie ma w bazie — piszesz wszystkie **ważne** znaczenia (osobne wpisy) |
| `partial` | hasło jest, ale brakuje części mowy (`brak: …`) — piszesz tylko brakujące części mowy / znaczenia |
| `check` | hasło jest we wszystkich częściach mowy — sprawdź, czy istniejące wpisy pokrywają **ogólne, najczęstsze** znaczenie. Wpisy tematów bywają wąskie (np. *charge* tylko „naładować telefon”). Brakuje ogólnego znaczenia → dopisz je; jest → pomiń |
| `done` | już w core — pomiń |

CEFR i części mowy w liście to **szacunek redakcyjny** — popraw, jeśli znaczenie mówi co innego (odnotuj w raporcie). Gdy hasło jest zbędne (np. błąd listy) — pomiń z adnotacją w raporcie.

**Sprawdzanie duplikatów przed pisaniem.** Lista podaje do 8 istniejących wpisów; pełny obraz hasła:
```
node -e "const d=require('./ios/FluentNOW/Resources/Content/dictionary-index.json').entries;console.log(d.filter(e=>e.k==='charge'))"
```
Walidator ostrzega `core-in-base`, gdy twoje hasło + tłumaczenie już istnieje w temacie — wtedy usuń wpis albo opisz faktycznie inne znaczenie (inne tłumaczenie).

## Format (skrót — szczegóły w CONTENT-SCHEMA §6 i §1)

- Plik: `{"schemaVersion":1,"id":"core-c03","namePl":"Słownictwo ogólne","nameEn":"Core vocabulary","group":"core","symbol":"character.book.closed","summaryPl":"Słownik rdzeniowy, część C03: …","aliases":[],"categories":[…]}`.
- Kategorie = pasma CEFR: `core-c03.a2`, `core-c03.b1`, … (`namePl` „Słownictwo ogólne B1”, `scenePl` `""`). Wpis trafia do kategorii **swojego** poziomu; w kategorii kolejność z listy roboczej (od najważniejszych).
- `id`: `core.<kebab-term>`; drugie i kolejne znaczenie tego samego hasła: `core.<kebab-term>-2`, `-3` (ta sama pisownia `term`). Czasownik i rzeczownik tego samego słowa to też osobne wpisy (`core.change`, `core.change-2`).
- Pozostałe pola i reguły **dokładnie jak w tematach** (§1): `ipa` GA wg konwencji (Oxford US: `/e/`, `/ɜːr/`, `/ər/`, jawne `/ə/` w `-ʃən`, `-bəl`…), `forms` (`attain – attained – attained`; `consequences`; `more thorough – most thorough`), `definition` ≤ 140 znaków, `contextPl` ≤ 80, `acceptedAnswers` (zawiera `term`), `acceptedTranslations` 1–8 z parami aspektowymi.

## Standard jakości (najważniejsze)

1. **Znaczenia.** Najpierw zrób listę ważnych znaczeń hasła (jak w dobrym słowniku learnerskim), od najczęstszego. Osobny wpis na każde znaczenie, które uczeń realnie spotka (*maintain* „utrzymywać” B2 i „twierdzić” C1; *raise* „podnieść”, „wychowywać”, „zebrać pieniądze”). Nie rozdrabniaj odcieni jednego znaczenia. CEFR i `frequency` **per znaczenie**.
2. **3–5 przykładów na znaczenie**, każdy inny pod względem:
   - konstrukcji (różne dopełnienia, kolokacje z `collocations`, struktury typu *be reluctant to*, *tend to*),
   - czasu i formy (teraźniejszy, przeszły, perfect, modalne, bezokolicznik, -ing),
   - typu zdania — **co najmniej jedno pytanie albo przeczenie** przy 4–5 przykładach (walidator: `core-example-variety`),
   - sytuacji: praca, dom, szkoła, zakupy, podróże, wiadomości, rozmowa ze znajomym — **nie** jedna scena (inaczej niż w tematach).
   Częste słowa (A1–B1) i wieloznaczne → 4–5 przykładów; rzadsze, wąskie (C1–C2, spójniki) → 3.
3. **Naturalny amerykański angielski**: 6–20 słów, zdania, które native speaker powiedziałby lub napisał; pisownia i słownictwo AmE (*apartment, vacation, cell phone, gotten, traveled*); bez marek, osób publicznych, polityki, treści drażliwych. Poziom reszty zdania ≈ poziom hasła (zdanie do *achieve* B1 nie może być zbudowane ze słów C1).
4. **Polskie tłumaczenia** pełne i naturalne (nie kalki: nie „zrobić różnicę”); `focusPl` to forma **dokładnie** z polskiego zdania (odmieniona: *osiągnęła*, *wystarczających*); jeśli najlepszy polski odpowiednik zmienia część mowy (*reluctant* → „niechętnie”, *tend to* → „zwykle”), to dobrze — dopisz go do `acceptedTranslations`.
5. **`focusEn`** — forma hasła użyta w zdaniu (*attained*, *are required to*, *doesn't tend to*), dokładny podciąg `en` z wielkością liter.
6. `notePl` — tylko gdy pomaga: fałszywi przyjaciele (*eventually* ≠ ewentualnie), konstrukcja (*despite* bez *of*), mylone słowa (*thorough/through/though*), rejestr.
7. **Unikalność**: żadne zdanie `en` nie może powtarzać się w całej bazie (`duplicate-example`); hasło + tłumaczenie unikalne w core.
8. Ostrzeżenia redakcyjne z §1 (`comma-splice`, `forms-base`, `pl-english`, `pl-imperial-units`, `accepted-format`) traktuj jak błędy — cel: **0 ostrzeżeń**.

## Procedura

1. `--shard <Cnn>` → podziel listę na porcje po ~40 haseł (w kolejności listy).
2. Dla porcji: sprawdź status/duplikaty, zaplanuj znaczenia, napisz wpisy, **zapisz plik po każdej porcji** (postęp nie przepadnie przy przerwaniu).
3. Po każdej porcji: `node "C:/Users/HARD PC/Desktop/FluentNOW/ios/tools/validate-content.mjs" --file "C:/Users/HARD PC/Desktop/FluentNOW/ios/FluentNOW/Resources/Content/core/core-<shard>.json"` → napraw błędy i ostrzeżenia. Walidator sprawdza unikalność względem całej bazy, także innych shardów w trakcie pisania.
4. Co porcję przeczytaj krytycznie 5 losowych wpisów jak redaktor-native speaker (naturalność, tłumaczenie, CEFR, IPA, `forms`).
5. **Nie uruchamiaj** `build-index.mjs` ani `build-core-master.mjs` bez `--shard` (zapisują wspólne pliki; robi to koordynator po fali). Lista robocza `--shard` tylko czyta.
6. Raport `ios/docs/reports/core-content-<shard>.md`: liczba haseł napisanych / pominiętych (`check` bez braków) / odrzuconych, liczba wpisów i przykładów, rozkład CEFR, zmiany CEFR/POS względem listy, hasła niedokończone, wynik walidatora.

## Budżet kontekstu

Nie wczytuj całego pliku sharda z powrotem — dopisuj kategoriami/porcjami (Edit) i sprawdzaj walidatorem albo `node -e`. Gdy kończy się kontekst: dokończ bieżący wpis, zwaliduj, zapisz raport z listą haseł nierozpoczętych — koordynator wznowi pracę.

## Czego NIE robisz

- Nie edytujesz plików tematów, innych shardów, `dictionary-index.json`, `CORE-MASTER.*`, narzędzi.
- Nie zmieniasz schematu (brak pola → opisz w raporcie).
- Nie kopiujesz przykładów ani definicji ze słowników (Oxford, Cambridge, Longman, Merriam-Webster) — piszesz własne zdania.
