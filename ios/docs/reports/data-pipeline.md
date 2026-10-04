# Raport: data-pipeline

## 1. Co zrobiono (pliki)

Narzędzia (`ios/tools/`, Node 24, bez zależności npm):

| Plik | Rola |
|---|---|
| `validate-content.mjs` | walidator całej treści (tematy §1, starter-words, banki §5, indeksy §2–§3); `--file` (wielokrotnie), `--json`, `--errors-only`, `--root`, `--self-test` |
| `lib/bank-validators.mjs` | reguły dla banków i indeksów (ładowane leniwie przez walidator) |
| `build-index.mjs` | generuje `topics/index.json` i `dictionary-index.json`; idempotentny (`generatedAt` zmienia się tylko przy zmianie treści), `--check` |
| `export-web-content.mjs` | eksport banków strony do JSON-ów aplikacji |
| `lib/web-loader.mjs` | wykonuje moduły TS strony bezpośrednio z `web-source/` (hooki `module.registerHooks` + `stripTypeScriptTypes`), bez kopiowania i bez modyfikacji plików |
| `verify-export.mjs` | porównuje źródło z eksportem (liczności, pełna równość pól, zakresy odpowiedzi, próbki, rozmiary) |
| `fixtures/` | `valid-topic.json`, `invalid-topic.json`, `invalid-grammar.json`, `invalid-idioms.json`, `invalid-readings.json` + pliki `*.expected.json` z oczekiwanymi regułami |

Treść (`ios/FluentNOW/Resources/Content/`, wszystko poza `topics/<id>.json`):
`grammar/A1.json` … `grammar/C2.json` (1800 zadań), `exercises.json` (72), `idioms.json` (108), `readings.json` (42 czytanki, 173 pytania), `starter-words.json` (21 znaczeń z 18 słów), `recommendations.json` (5), `answer-variants.json` (41 grup znaczeń, 62 pary aspektowe, 6 aliasów), `topics/index.json` i `dictionary-index.json` (generowane).

Dokumenty: `CONTENT-SCHEMA.md` §5 (dokładne kształty plików banków, podział gramatyki, indeksy, wydajność; wiersz grammar w §4 wskazuje na §5.1) oraz `reports/content-issues-web-banks.md` (dla english-qa).

## 2. Publiczne API / kontrakty

**CLI walidatora (stałe od pierwszej wersji, tylko dopisuję reguły):**
```
node ios/tools/validate-content.mjs [--file <ścieżka>]... [--json] [--errors-only|--quiet] [--root <katalog>] [--self-test]
kody wyjścia: 0 = brak błędów (ostrzeżenia nie zmieniają kodu), 1 = błędy, 2 = złe argumenty
tekst: "BŁĘDY (n):" / "OSTRZEŻENIA (n):", linie "  <plik>:<entryId>: <komunikat>", podsumowanie "OK|NIE PRZESZŁO: plików …"
--json: { ok, files, entries, errorCount, warningCount, errors: [{file, id, rule, message}], warnings: [...] }
```
Przy `--file` dla pliku z katalogu treści unikalność `id` i przykładów jest sprawdzana względem całej bazy (cudze pliki w trakcie zapisu, z niepoprawnym JSON-em, są pomijane), ale zgłaszane są tylko problemy wskazanego pliku. Pole `rule` w JSON-ie jest stabilne (np. `focus-en`, `duplicate-example`, `british-spelling`).

**Pozostałe narzędzia:** `node ios/tools/build-index.mjs [--root] [--check]`, `node ios/tools/export-web-content.mjs [--root]`, `node ios/tools/verify-export.mjs [--root]`.

**Kształty plików:** `CONTENT-SCHEMA.md` §5.1–§5.9. Najważniejsze dla core-engine i platform-services:
- **nie ma `grammar.json`**: są `grammar/<poziom>.json` = `{schemaVersion, source, version: 36, level, rules: [String], items: [ProductionItem]}`;
- w `idioms.json` `answer` jest zawsze `0`, więc opcje trzeba tasować przy wyświetlaniu;
- opcjonalne pola TS mogą nie występować w JSON-ie (trzeba dekodować przez `decodeIfPresent`), a żadna wartość nie jest `null`;
- pula „produkcji” poziomu = `exercises.json[level]` + `grammar/<level>.json.items`, w tej kolejności (jak `productionPool` na stronie).

## 3. Odstępstwa od strony i dlaczego

1. **Gramatyka podzielona na poziomy:** jeden plik miałby ok. 1,96 MB (próg z mojej roli: 1,5 MB). Pliki mają 285–402 KB i ładuje się tylko bieżący poziom. Dodane pole `rules` (`productionRules` strony).
2. **`bankId` dla idiomów** (`idiom-v1-<poziom>-<nn>`): strona ich nie miała, a są potrzebne do śledzenia „widzianych”.
3. **Trzeci dystraktor zapisany w danych** dla 11 zadań z `exercises.json`. Strona dokładała go w locie z mapy zaszytej w `starterPractice`. Jedna drobna różnica: `Close` → „To close” (strona: „to close”), bo luka stoi na początku zdania.
4. **Starter-words:** IPA zamienione na General American (6 haseł), dodana `frequency`, `forms` w formacie `do – did – done`, listy rozdzielane `; `, `focusEn` dopasowane wielkością liter do zdania. Translation „bank — instytucja finansowa” zmienione na „bank”, register „zawodowy” na „neutralny”. Pominięte: wyniki i recenzje demo, kolekcje, tagi.
5. **Błąd strony w `polishAnswers`:** dzieli tłumaczenie po przecinku, więc „załapać, jak coś działa” dawało osobny akceptowany wariant „jak coś działa”. Eksport odrzuca takie fragmenty zaczynające się od spójnika lub zaimka względnego. Silnik Swift powinien tego nie powielać (patrz §5 prośby).
6. **`acceptedTranslations` przycięte do 8** (limit schematu) dla `starter.tell` (strona miała 10). Pełna lista jest w `answer-variants.json`.
7. **Poprawki pisowni AmE:** rubbish→trash, practised→practiced, recognised→recognized w czytankach (konsekwentnie w akapitach, opcjach i evidence), travelled→traveled w jednym dystraktorze.
8. **`readings.json`** zawiera też 12 dawnych czytanek (`tutor-local.ts` `readings`/`extraReadings` i `advanced-readings.ts`), na stronie nieużywanych od v39. Mają id `reading-legacy-*` i `topic: ""`. Do oceny przez english-qa; można je usunąć z eksportu jedną linią.
9. **Pominięty martwy kod strony:** `grammarQuestions` i `idiomQuestions` w `tutor-local.ts` (strona ich nie używa; idiomy i gramatyka idą przez `idiomPool`/`productionPool`).
10. **Poprawki raportów użytkowników** (`report-corrections`, D1) to dane runtime serwera, poza repozytorium; w eksporcie `corrected*` działa jak tożsamość.

## 4. Znane ryzyka / rzeczy niesprawdzone

- Nie piszę kodu Swift, więc nie ma tu ryzyka kompilacji. Ryzykiem jest zgodność dekoderów core-engine z §5; rozmawiałem o tym z core-engine (wiadomość wysłana).
- `topics/index.json` i `dictionary-index.json` zestarzeją się, gdy agenci treści dopiszą tematy. **Po zakończeniu pracy agentów treści trzeba uruchomić `node ios/tools/build-index.mjs`** (walidator ostrzega regułą `index-stale`).
- Heurystyki (BrE, a/an, IPA, wielkie litery w haśle) to ostrzeżenia i mogą być fałszywe. Dostroiłem je na plikach agentów treści: X-ray, x-ray, e-mail, trójgłoski GA aɪə/aʊə/eɪə/oʊə, nazwy własne typu Monday, Wi-Fi, go Dutch.
- Walidator nie sprawdza, czy polska podpowiedź w gramatyce odpowiada angielskiemu czasownikowi (przykład: 45 zadań „analizować” → „review”; opisane w content-issues).
- Loader wykonuje kod strony z atrapą `zod`. Jeśli strona zacznie wywoływać walidację zod przy imporcie modułów, eksport trzeba będzie dostosować; dziś import jest czysty.

## 5. Prośby do innych ról

- **core-engine** (`Sources/FluentKit/Content/`): dekodery według §5. Konkretnie: `grammar/<L>.json` zamiast `grammar.json`; opcjonalne pola przez `decodeIfPresent`; tasowanie opcji idiomów, bo `answer` zawsze wynosi 0; przy portowaniu `polishAnswers` nie dodawać fragmentów po przecinku zaczynających się od „jak/że/co/który/aby/żeby/gdy/kiedy/gdzie” (pkt 5 w §3); akceptowane tłumaczenia to `acceptedTranslations` wpisu ∪ `polishSenseVariants`/`polishAspectPairs`.
- **platform-services** (`ContentLibrary`): ładować `grammar/<poziom>.json`, `readings.json`, `exercises.json` i `idioms.json` leniwie, poza głównym wątkiem; przy starcie tylko indeksy i małe pliki (§5.9). `dictionary-index.json` (dziś ok. 120 KB, rośnie z tematami) dekodować w tle.
- **design-shell** (`project.yml`): `Resources/Content` dodać jako **folder reference** (z podkatalogami `topics/` i `grammar/`), żeby ścieżki w bundle zostały zachowane.
- **english-qa:** `ios/docs/reports/content-issues-web-banks.md`.
- **koordynator / topic-content:** po zakończeniu fali uruchomić `build-index.mjs`, a potem `validate-content.mjs`.

## 6. Testy i wyniki uruchomień (stan końcowy)

- `node ios/tools/validate-content.mjs --self-test`: **SELF-TEST OK**. Obejmuje 26 testów jednostkowych heurystyk (a/an z wyjątkami, BrE pisownia i słownictwo bez fałszywych -ise, flat tire, IPA, cudzysłowy polskie, normalizacja) oraz 5 fixtures: poprawny temat ma 0 błędów; 4 błędne pliki muszą wywołać 30 + 8 + 7 + 6 oczekiwanych reguł.
- `node ios/tools/validate-content.mjs`: **OK: 29 plików, 1359 wpisów, 0 błędów, 7 ostrzeżeń**. Ostrzeżenia dotyczą tematów w trakcie pisania oraz jednego „queue” w czytance. Czas ok. 0,8 s.
- `node ios/tools/verify-export.mjs`: **WERYFIKACJA OK**, 89 sprawdzeń bez rozbieżności, m.in.:
  - grammar 6×300 = 1800, wszystkie zadania identyczne z `grammar-bank.json`, `rules` = `productionRules`, żaden dystraktor nie jest odpowiedzią;
  - exercises 6×12 = 72 (startery 0/4/4/4/0/0 + exercise-bank 12/8/8/8/12/12), identyczne z `productionPool` (bez dodanych dystraktorów), `bankId` = `grammarTaskId`, każde zadanie ma ≥ 3 dystraktory;
  - idioms 6×18 (6 bazowych + 12 z rozszerzenia), identyczne z `idiomPool(level, 0)`, `answer` w zakresie, 4 unikalne opcje;
  - readings 42 (30 z banku + 12 dawnych, 7 na poziom), 173 pytania, wszystkie `answer` w zakresie `options`, wszystkie id banku obecne;
  - starter-words 21 znaczeń, pary EN/PL przykładów identyczne ze `starterLookup`;
  - recommendations 5, answer-variants identyczne;
  - żaden plik nie przekracza 1,5 MB.
- `node ios/tools/export-web-content.mjs` uruchomiony drugi raz: 12/12 plików „bez zmian” (deterministyczny). `build-index.mjs --check`: indeksy aktualne. W chwili pisania: 15 tematów, 1325 wpisów, 1346 rekordów słownika.
