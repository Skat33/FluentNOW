# Runda 7 — słownik rdzeniowy (core vocabulary)

Wymaganie właściciela: „zasób słownictwa kuleje (np. nie wykrywa *attain*) — zwiększ solidnie, niech agent weryfikuje słowa, do każdego słowa kilka zdań i zadań do ćwiczeń”.

Diagnoza koordynatora: baza (10 711 rekordów, 9 059 haseł) powstała z 142 tematów sytuacyjnych, więc brakuje **ogólnego rdzenia języka** — sprawdzone 25 częstych słów (achieve, require, significant, despite, ensure, attain…) — brak wszystkich.

## L1. Lista rdzeniowa i infrastruktura (agent: core-pipeline)
1. **Lista lematów** `ios/docs/CORE-MASTER.json` (+ krótki opis w `CORE-MASTER.md`): ok. **5 000–6 000** haseł ogólnych, łączących:
   - słownictwo najczęstsze (ogólne listy frekwencyjne o otwartej licencji, np. NGSL — New General Service List, CC BY-SA; zweryfikuj licencję i źródło przez WebFetch; nie kopiuj list zastrzeżonych, np. Oxford 3000/5000 — można z nich korzystać tylko jako ogólnej orientacji, nie przepisywać),
   - słownictwo akademickie/ogólne B2–C1 (np. NAWL, CC BY-SA),
   - najczęstsze czasowniki frazowe i kolokacje, słowa funkcyjne (spójniki, przyimki, przysłówki: despite, whereas, nevertheless…),
   - słowa „przydatne w życiu” C1–C2 (ograniczona liczba).
   Dla każdego: lemat, część mowy (PL wg schematu), szacowany CEFR, priorytet/częstość, flaga „już w bazie” (to samo hasło i to samo znaczenie istnieje w `topics/*.json` → pomiń lub tylko uzupełnij brakujące znaczenia), przydział do sharda (C1…Cn, ~450–550 haseł na shard, grupowanie alfabetyczne lub frekwencyjne — wybierz to, co ułatwi pracę autorów).
2. **Format i miejsce:** nowy katalog `ios/FluentNOW/Resources/Content/core/` z plikami `core-<shard>.json` w formacie zgodnym z `TopicFile` (CONTENT-SCHEMA §1; `group: "core"`, kategorie np. wg poziomu lub litery), z różnicą: **przykłady 3–5 na znaczenie** (zamiast dokładnie 2), wieloznaczne hasła = osobne wpisy na każde ważne znaczenie (sufiks `-2`, `-3`). Udokumentuj w `CONTENT-SCHEMA.md` (nowy §).
3. **Walidator i indeksy:** `validate-content.mjs` — reguły dla `core/` (3–5 przykładów, reszta jak tematy, unikalność przykładów w całej bazie, nowe ostrzeżenia z content-final); `build-index.mjs` — `dictionary-index.json` obejmuje `core/` (`r`: `core-<shard>/<id>`), indeks tematów **nie** (core nie jest tematem).
4. **Aplikacja:** `ContentLibrary` (FluentKit `ContentDecoder`/`ContentSearch` jeśli trzeba) rozwiązuje odwołania `core-…/…` przy szybkim dodawaniu, polecanych słówkach, słowniczkach czytanek i teście; `TopicSearch` pomija `core/` (żeby nie wyskakiwał „temat” core) — ale słowa core mogą być dobierane do wyników tematu, jeśli pasują znaczeniem (opcjonalnie). Wszystkie przykłady wpisu trafiają do znaczenia (`ExamplePool` obsłuży więcej przykładów → większa różnorodność zadań). Testy.
5. **Instrukcja dla autorów** `ios/docs/agents/03b-core-content.md` (na wzór `03-topic-content.md`): standard jakości, 3–5 przykładów (różne konstrukcje, czasy, zdania twierdzące/przeczące/pytające, typowe kolokacje), naturalny amerykański angielski, `focusEn`/`focusPl`, konwencje `forms`/IPA z CONTENT-SCHEMA §1, CEFR per znaczenie, sprawdzenie duplikatów z bazą przed pisaniem.

## L2. Treść rdzeniowa (agenci: core-C1…Cn, po 3 naraz)
Wg `03b-core-content.md` i przydziału z `CORE-MASTER.json`.

## L3. Weryfikacja (agenci: core-qa, po zakończeniu shardów)
Pełna korekta jak english-qa T1–T6 (gramatyka, naturalność, AmE, IPA, CEFR, polszczyzna, akceptowane odpowiedzi, poprawność znaczeń) + kontrola, czy każde ważne znaczenie częstych słów jest obecne.
