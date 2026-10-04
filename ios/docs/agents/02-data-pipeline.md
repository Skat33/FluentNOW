# Rola: data-pipeline — przeniesienie banków treści i narzędzia

Fala 1. Obszar: `ios/tools/`, `ios/FluentNOW/Resources/Content/` (wszystko **poza** `topics/<id>.json`, które tworzy topic-content), sekcja §5 w `ios/docs/CONTENT-SCHEMA.md`. Raport: `ios/docs/reports/data-pipeline.md`.

## Cel

Przenieść całą wbudowaną treść strony do plików JSON zgodnych z `CONTENT-SCHEMA.md` oraz dostarczyć narzędzia, które pilnują jakości treści dla wszystkich innych agentów.

## Zadania (w tej kolejności — walidator jest potrzebny innym agentom jak najszybciej)

1. **`ios/tools/validate-content.mjs`** (najpierw!) — Node 24, bez zależności npm. Waliduje wszystkie pliki w `Resources/Content/`:
   - schemat każdego pliku wg `CONTENT-SCHEMA.md` (typy, wymagane klucze, brak `null`, dozwolone wartości enumów, `schemaVersion`);
   - `focusEn ⊂ en`, `focusPl ⊂ pl` (dokładnie), dokładnie 2 przykłady, `en` kończy się `. ? !`, brak podwójnych spacji, brak spacji przed `, . ? !`, zrównoważone cudzysłowy/nawiasy;
   - unikalność `id` w całej bazie; brak duplikatów `term`+`translation` w obrębie tematu; brak identycznych przykładów w całej bazie;
   - heurystyki angielskiego: brytyjska pisownia (lista: colour, favourite, centre, theatre, travelled, cancelled, organise/-isation, realise, analyse, licence (rzeczownik ok w AmE? nie — license), programme, grey, mum, flat (mieszkanie), lift (winda), queue, holiday (w sensie urlop) itp. — ostrzeżenie, nie błąd, dla słów wieloznacznych), `a` przed samogłoską / `an` przed spółgłoską (z wyjątkami: a university, an hour, a one-, an MBA…), powtórzone słowo („the the”), wielka litera na początku zdania;
   - polskie heurystyki: brak `(AmE)`/`(BrE)`, wielka litera na początku zdania `pl`;
   - tryb `--file <ścieżka>` (pojedynczy plik), `--json` (wynik maszynowy), kody wyjścia: 0 = OK, 1 = błędy. Ostrzeżenia nie zmieniają kodu wyjścia. Wynik: zwięzła lista `plik:entryId: komunikat`.
2. **`ios/tools/build-index.mjs`** — generuje `topics/index.json` i `dictionary-index.json` (§2, §3) ze wszystkich `topics/*.json` + `starter-words.json`. Idempotentny, deterministyczny (sortowanie), uruchamialny wielokrotnie w trakcie pracy agentów treści.
3. **`ios/tools/export-web-content.mjs`** — eksport banków ze strony (`web-source/lib/data/*`, `lib/learning.ts` seed/STARTER, `lib/tutor-local.ts`, `lib/answer-variants.ts`, `lib/production.ts` starter) do `grammar.json`, `exercises.json`, `idioms.json`, `readings.json`, `starter-words.json`, `recommendations.json`, `answer-variants.json`. Node 24 umie usuwać typy z `.ts`, ale importy bez rozszerzeń mogą nie działać — rozwiąż to (np. skopiuj potrzebne moduły do katalogu tymczasowego w scratchpadzie i popraw importy, albo napisz własny loader). **Nie modyfikuj `web-source/`.** Idiomy i ćwiczenia rozwiń do obiektów dokładnie tak, jak robi to kod strony (np. `starterPractice`, `exercise-bank` wiersze → `ProductionItem`). Starter-words: przenieś do formatu Entry (§1), uzupełniając brakujące pola (IPA zamień na General American, tłumaczenia przykładów z `pairs`, `acceptedAnswers`). Jeśli w seedzie są pola, których Entry nie ma (np. przykładowe wyniki demo) — pomiń, aplikacja startuje z czystym stanem.
4. **Weryfikacja przeniesienia** — skrypt `ios/tools/verify-export.mjs` porównujący liczności i próbki (np. 1800 zadań gramatycznych, wszystkie czytanki z pytaniami i `answer` w zakresie `options`) między źródłem a JSON-em. Uruchom i wklej wynik do raportu.
5. **Wydajność ładowania** — zmierz rozmiary plików. Jeśli `grammar.json` > 1,5 MB, rozważ podział na `grammar/A1.json`…`C2.json` (aplikacja ładuje tylko potrzebny poziom). Decyzję wpisz do §5 schematu.
6. **Uruchom walidator na swoich plikach** — banki ze strony mogą mieć błędy (to dobrze, że je znajdziemy). Błędy schematu napraw w eksporcie; błędy językowe wypisz do `ios/docs/reports/content-issues-web-banks.md` (plik, id, problem, propozycja) — przejmie je english-qa. Oczywiste literówki możesz poprawić od razu w eksporcie (lista poprawek w raporcie).
7. Uzupełnij §5 w `CONTENT-SCHEMA.md`: dokładne kształty plików banków (przykład JSON każdego), ewentualny podział plików.

## Uwagi

- Agenci topic-content (6 równoległych) będą uruchamiać twój walidator — od chwili zapisania pierwszej działającej wersji nie zmieniaj jego interfejsu CLI, tylko dodawaj reguły. Jeśli dodasz nową regułę, która może masowo oblać istniejące pliki, zrób ją ostrzeżeniem.
- Twórz testowy plik tematu `topics/_sample.json`? **Nie** — zamiast tego miej fixture w `ios/tools/fixtures/` i test `node ios/tools/validate-content.mjs --self-test`.
