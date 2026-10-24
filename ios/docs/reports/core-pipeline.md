# Raport: core-pipeline (FEEDBACK-7 L1: słownik rdzeniowy)

Swift napisany na Windows **bez kompilatora**. Każdą użytą sygnaturę sprawdziłem grepem, a wszystkie zmienione pliki Swift przeszły lexer składni (nawiasy z interpolacją, BOM/CR, `try!`/`as!`/`fatalError`). Narzędzia Node uruchomione, wyniki w §6.

## 1. Co zrobiono

### Lista lematów
- `ios/docs/CORE-MASTER.json` (1,45 MB, jeden lemat na linię) i `ios/docs/CORE-MASTER.md`: oba pliki generuje `ios/tools/build-core-master.mjs`.
- Pola lematu: `id`, `lemma`, `pos` (PL), `level`, `priority`, `sources`, `senses`, `status`, `missingPos`, `estimate`, `shard`, `base` (do 8 istniejących wpisów: `r`, `p`, `l`, `pos`), `core`.
- **5 367 haseł.**
  - Źródła: NGSL 2 730, NAWL 792, tylko uzupełnienie FluentNOW 1 845.
  - Części mowy: rzeczowniki 2 165, przymiotniki 1 216, czasowniki 1 026, czasowniki frazowe 321, przysłówki 295, zwroty 198, przyimki 72, idiomy 30, spójniki 27, zaimki 17.
- **Status względem bazy** (tematy + starter + core):

  | Status | Liczba | Znaczenie |
  |---|---|---|
  | `new` | 2 851 | hasła brak w bazie |
  | `partial` | 289 | brakuje części mowy |
  | `check` | 2 211 | hasło jest; autor sprawdza, czy jest też jego ogólne znaczenie |
  | `done` | 16 | gotowe w pliku-wzorze |

  Szacunkowo **3 350 wpisów** do napisania.
- Rozkład CEFR (szacunek redakcyjny dla głównego znaczenia):

  | | A1 | A2 | B1 | B2 | C1 | C2 |
  |---|---|---|---|---|---|---|
  | wszystkie hasła | 484 | 688 | 1320 | 1426 | 1246 | 203 |
  | do napisania (new + partial) | 174 | 267 | 630 | 866 | 1005 | 198 |

- Wymagane słowa: wszystkie 24 są na liście, ze statusem `new`. *attain*, *achieve*, *obtain*, *ensure*, *maintain*, *require*, *sufficient*, *adequate*, *consequence*, *significant*, *despite*, *whereas*, *nevertheless*, *reluctant*, *thorough* i *tend* są już napisane we wzorze. Pozostałe (*assume*, *enhance*, *establish*, *indicate*, *interpret*, *occur*, *perceive*, *pursue*) są przydzielone do shardów C02/C03.
- **Shardy: 8**, grupowane według priorytetu (częstości). Uzasadnienie:
  - spójny zakres poziomów w shardzie;
  - najważniejsze słowa powstają pierwsze, nawet jeśli L2 się nie zakończy.

  Przydział jest stały: kolejne uruchomienia go zachowują, `--reshard` zmienia go tylko na żądanie.

  | Shard | Hasła | Do napisania | Do sprawdzenia | Szac. wpisy | CEFR |
  |---|---|---|---|---|---|
  | C01 | 620 | 357 | 262 | 458 | A1–B2 (rank NGSL 2–678) |
  | C02 | 850 | 355 | 487 | 394 | A1–C1 (NGSL 679–1533) |
  | C03 | 768 | 410 | 356 | 434 | A1–C1 (NGSL 1534–2307) |
  | C04 | 865 | 396 | 468 | 407 | A1–C2 (koniec NGSL + start pasm) |
  | C05 | 778 | 422 | 353 | 433 | B1–B2 |
  | C06 | 621 | 470 | 151 | 487 | B2–C1 |
  | C07 | 613 | 486 | 126 | 492 | C1 |
  | C08 | 252 | 244 | 8 | 245 | C1–C2 (do dopełnienia lub połączenia z C07) |

### Źródła i dane narzędzi (`ios/tools/data/core/`)
- `ngsl-1.2.txt` (2 809 lematów, w kolejności rankingu) i `nawl-1.2.txt` (957): kopie list, pobrane jako tekst przez WebFetch (bez zapisu plików z sieci).
- `annotations-ngsl.txt` i `annotations-nawl.txt`: własne adnotacje redakcyjne.
  - Dla każdego lematu: hasło dla ucznia, części mowy, CEFR, szacowana liczba znaczeń.
  - Mapowania lematów na hasła: `excite` → *excited*/*exciting*, `accord` → *according to*, `TRUE` → *true*, `rid` → *get rid of*.
  - Lista `drop:` z uzasadnieniem: słowa gramatyczne A1, zaimki, liczebniki, wulgaryzmy, BrE (*whilst*, *autumn*, *pub*), tematy drażliwe, terminologia ścisła NAWL.
  - Skrypt sprawdza, że każdy lemat źródła ma adnotację albo jest na liście `drop:`.
- `supplement.txt`: uzupełnienie FluentNOW w sekcjach:
  - `@phrasal` (≈320 czasowników frazowych);
  - `@function` (spójniki i przyimki złożone, wyrażenia łączące: *in spite of*, *provided that*, *as long as*…);
  - `@phrase` (kolokacje i zwroty: *make a decision*, *take into account*…);
  - `@general` (słownictwo ogólne B1–C1, m.in. *attain*, *reluctant*, *thorough*);
  - `@advanced` (≈200 przydatnych C2).

### Licencje (zweryfikowane WebFetch na stronie projektu, 24.10.2026)
- **NGSL 1.2** i **NAWL 1.2** (Browne, C., Culligan, B., Phillips, J.): obie strony podają „licensed under a Creative Commons Attribution-ShareAlike 4.0 International License”. Źródła: <https://www.newgeneralservicelist.com/new-general-service-list>, <https://www.newgeneralservicelist.com/new-academic-word-list>.
- Lista pochodna (`CORE-MASTER.*`) ma tę samą licencję **CC BY-SA 4.0** z uznaniem autorstwa. Jest to zapisane w JSON (`license`, `sources`) i w MD.
- Z list zastrzeżonych (Oxford 3000/5000, EVP, Cambridge, Longman) nie skopiowano niczego. CEFR to własna ocena.

### Treść
- `ios/FluentNOW/Resources/Content/core/` (nowy katalog) z plikiem-wzorem `core-c01.json`:
  - **17 wpisów** (16 haseł; *maintain* ma 2 znaczenia), w kategoriach `b1`/`b2`/`c1`, 3–5 przykładów na znaczenie, 65 przykładów łącznie;
  - przykłady w różnych czasach i sytuacjach, z pytaniami i przeczeniami;
  - IPA według konwencji, `forms`, `notePl` przy pułapkach (*despite* bez *of*, *ensure*/*insure*, *thorough*/*through*/*though*);
  - walidator: 0 błędów, 0 ostrzeżeń.
- `project.yml`: `FluentNOW/Resources/Content` jest dodany jako `type: folder`, więc `core/` trafia do bundla bez zmian (sprawdzone).

### Narzędzia
- **`validate-content.mjs`**:
  - typ pliku `core` (katalog `core/` albo kształt z `group: "core"`) i nowa funkcja `validateCore`. Sprawdza:
    - `id` = `core-cNN` = nazwa pliku;
    - `group` = `core`;
    - kategorie `<id>.<kebab>`, przy czym `scenePl` może być puste;
    - wpisy z prefiksem `core.`.
  - `validateEntry(…, { examples })`: tematy mają dokładnie 2 przykłady, core 3–5. Duplikat przykładu w obrębie wpisu jest wykrywany dla dowolnej liczby przykładów.
  - Nowe błędy:
    - `core-id`, `core-group`;
    - `topic-id-reserved` (temat nie może mieć id `core` ani `core-*`);
    - `duplicate-term-translation` także między shardami core.
  - Nowe ostrzeżenia:
    - `core-in-base`: to samo hasło i tłumaczenie jest już w temacie lub starterze;
    - `core-example-variety`: przy 4–5 przykładach brak pytania i przeczenia;
    - `core-size`: plik ma ponad 650 wpisów.
  - Przy `--file` pula globalna obejmuje `core/`, więc unikalność przykładów i id jest sprawdzana w całej bazie.
  - Ostrzeżenia z content-final (`comma-splice`, `forms-base`, `pl-english`, `pl-imperial-units`, `accepted-format`) działają też dla core.
  - Self-test: fixtures `valid-core.json` i `invalid-core.json` z plikami `*.expected.json` oraz asercje dla `topic-id-reserved` i `classify`.
- **`build-index.mjs`**: `dictionary-index.json` obejmuje `core/*.json` (`r` = `core-c01/core.attain`). `topics/index.json` ich nie zawiera. Pliki z błędną nazwą lub kształtem są pomijane z ostrzeżeniem. Stałe `CORE_DIR` i `CORE_FILE_ID` pochodzą z walidatora.
- **`build-core-master.mjs`** (nowy): składa listę ze źródeł, liczy statusy i przydziela shardy. Tryby:
  - bez argumentów: przelicza statusy i zachowuje przydział shardów;
  - `--check`: kod 1, gdy pliki są nieaktualne;
  - `--reshard`;
  - `--shard C03 [--all]`: lista robocza autora.

  Skrypt jest idempotentny: `generatedAt` zmienia się tylko przy zmianie treści.

### Kod
- FluentKit, `Content/CoreVocabulary.swift` (nowy). Szczegóły w §2.
- `Content/TopicGeneration.swift`: `TopicEntryValidator.issues(_:exampleCounts: = 2...2)`. Dotychczasowe wywołania działają bez zmian; duplikaty przykładów są wykrywane dla dowolnej liczby.
- `Content/VocabularyMerger.swift`: `addTopicEntries` dla pliku core nie ustawia `topic` ani `scene` (kategorie core to pasma CEFR, nie sytuacje). Kolekcja = `namePl` („Słownictwo ogólne”). Przykłady trafiają do znaczenia w całości, jak dotąd. `ExamplePool` nie wymagał zmian, bo bez `enrichment` używa wszystkich przykładów.
- `FluentNOW/Services/Content/ContentLibrary.swift`:
  - `topic(id:)`: dla `core-cNN` czyta `core/<id>.json` przez `ContentDecoder.coreFile`.
  - `entry(reference:)` i `lookup(term:)` (przez prywatne `locate`) rozwiązują `core-…/…`. Gdy wpisu nie ma we wskazanym shardzie, szukają go po id w pozostałych shardach, więc stare `contentRef` przetrwają przetasowanie.
  - Propozycja słowa z core ma kolekcję „Słownictwo ogólne” i nie ma kategorii ani sceny. Dla tematów zachowanie się nie zmieniło.
  - Nowe `coreFileIDs()`.
  - `validateAll()` sprawdza też pliki core.
  - Katalog wyszukiwania tematów czyta tylko `topics/` i dodatkowo odrzuca id `core-*`, więc `TopicSearch` nigdy nie pokaże core jako tematu.
- Testy:
  - `Packages/FluentKit/Tests/FluentKitTests/CoreVocabularyTests.swift` (nowy, 6 testów).
  - `FluentNOWTests/Services/ContentLibraryTests.swift`: dopisany 1 test.
- Dokumenty:
  - `CONTENT-SCHEMA.md`: nowy **§6** (format, reguły walidatora, indeksy, API aplikacji, kolejność narzędzi), w §3 `r` dla core, w §5.9 wiersz o wydajności;
  - `ios/docs/agents/03b-core-content.md` (nowy): instrukcja dla autorów L2.

## 2. Publiczne API / kontrakty

```swift
// FluentKit
public enum CoreVocabulary {
    static let directory = "core", group = "core", filePrefix = "core-c", entryPrefix = "core."
    static let collectionName = "Słownictwo ogólne", exampleRange: ClosedRange<Int> = 3...5
    static func isCoreFile(_ id: String) -> Bool
    static func isCoreEntryID(_ id: String) -> Bool
    static func isCore(_ topic: TopicFile) -> Bool
    static func relativePath(file id: String) -> String          // "core/core-c01.json"
    static func fileIDs(fromFileNames: [String]) -> [String]
    static func entryIssues(_ entry: TopicEntry) -> [String]
}
public extension ContentReference { var isCore: Bool; var relativePath: String }   // starter-words.json | core/… | topics/…
public extension ContentDecoder { static func coreFile(from data: Data) throws -> TopicFile }
TopicEntryValidator.issues(_ entry: TopicEntry, exampleCounts: ClosedRange<Int> = 2...2) -> [String]

// Aplikacja (actor ContentLibrary): sygnatury bez zmian, rozszerzone zachowanie + jedna nowa metoda
func topic(id: String) async throws -> TopicFile        // "core-c01" → core/core-c01.json
func entry(reference: String) async throws -> TopicEntry // "core-c01/core.attain" (fallback po id)
func lookup(term: String) async -> Lookup?               // obejmuje wpisy core z dictionary-index
func coreFileIDs() -> [String]                           // nowe
```

Kontrakt treści: `CONTENT-SCHEMA.md` §6. Id wpisu `core.<kebab>[-n]` nie zależy od sharda. `r` w indeksie ma postać `core-cNN/core.<kebab>`.

## 3. Odstępstwa i decyzje

- **Id wpisów `core.<hasło>`, a nie `core-c01.<hasło>`.** Id jest unikalne w bazie i nie zależy od sharda. `ContentLibrary` odnajduje przeniesiony wpis po samym id.
- **Shardy według częstości, nie alfabetu.** Podział na kategorie według CEFR.
- **Bilans shardów** liczony w szacowanych wpisach do napisania. Hasło `check` waży 0,25.
- **Plik-wzór `core-c01.json` zawiera hasła przydzielone do C02–C07.** Mają status `done`, a pole `core` wskazuje plik. Autor C01 dopisuje swoje hasła do tego samego pliku.
- **Hasło w kilku źródłach** dostaje priorytet z najwyższego z nich (NGSL ma pierwszeństwo). Pole `sources` wymienia wszystkie.
- **Rozkład CEFR jest przesunięty ku C1 (1 246 haseł).** Powód: NAWL plus uzupełnienie C1. C2 ograniczyłem do 203. Jeśli L2 ma być krótsza, C08 i część C07 można pominąć bez szkody dla rdzenia.
- **Wpisy z NGSL A1, które są czysto gramatyczne** (*the, of, will, can, if…*), zostały pominięte, bo obsługuje je moduł gramatyki. Prawdziwe spójniki i przyimki ogólne zostały (*despite, whereas, although, unless, beyond…*).

## 4. Ryzyka / niesprawdzone

- **Kompilacja.** Jest kilka konstrukcji do sprawdzenia:
  - `public extension ContentReference` z obliczanymi właściwościami;
  - `ContentDecoder.decode` wołane z `public extension`;
  - w `ContentLibrary.locate`: `try? await` w `if let` / `guard let` oraz krotka z etykietami;
  - pętla `for … where` w aktorze.

  Lexer nie zgłasza problemów, wzorce są takie jak w istniejącym kodzie.
- **Statusy `check`/`partial` porównują hasło i część mowy, nie znaczenie.** Dlatego autor L2 musi przejrzeć 2 211 haseł `check`. Instrukcja to opisuje, a ostrzeżenie `core-in-base` łapie dosłowne duplikaty.
- **CEFR i części mowy to szacunek redakcyjny.** Autorzy poprawiają je per znaczenie.
- **Rozmiar.** Shard ma ok. 0,9 MB JSON, ładowany leniwie. `dictionary-index.json` urośnie o ok. 3 400 rekordów (~+0,4 MB) i jest nadal dekodowany w tle.
- **Pełne skanowanie shardów przy brakującym wpisie core** dzieje się tylko wtedy, gdy referencja jest nieaktualna. Pliki trafiają potem do pamięci podręcznej, ale wszystkie 8 może się wczytać.

## 5. Prośby do innych ról

- **Koordynator → właściciel rekomendacji / ui-library.** study-layout odmówił, bo to poza jego obszarem. Polecane słówka obecnie pomijają core:
  - `UsefulWordRecommender.candidates` (FluentKit `Analysis/`): referencja core nie ma `TopicSummary`. Proponowana gałąź: `else if reference.isCore { name = CoreVocabulary.collectionName; group = "basics" }`.
  - `Features/Today/UsefulWordsCatalog.readDetails` czyta `topics/\(file).json`. Należy użyć `reference.relativePath` i `ContentDecoder.coreFile`.
  - `UsefulWordsAdder` działa już teraz (przez `topic(id:)`).
- **Koordynator → test-mode, kolejna runda.** Test poziomu (K4) bierze dziś słowa bazy tylko z `topics/index.json`. test-mode potwierdził, że wpięcie core to mała zmiana w `Features/Study/Test/TestLoader.swift`: `coreFileIDs()` → `topic(id:)` dla każdego sharda → `AssessmentBuilder.bankEntries(topic:band:fromLearnerTopics: false)`. W tej rundzie tego nie zmienia. Szybki test onboardingu (`PlacementTest.makeQuestions(dictionary:)`) obejmuje core automatycznie przez `dictionary-index`.
- **Koordynator L2:**
  - start shardów C01–C08 według `03b-core-content.md`, po 3 naraz;
  - po każdej fali uruchomić kolejno: `build-index.mjs` → `build-core-master.mjs` → `validate-content.mjs`;
  - autorzy **nie** uruchamiają skryptów zapisujących wspólne pliki.
- **reading / english-qa:** słowniczki czytanek mogą teraz wskazywać wpisy core w `ref`. Przykłady: *despite*, *whereas*, *significant*.

## 6. Testy i wyniki skryptów

- **`CoreVocabularyTests`** (XCTest, nieuruchomione — brak Swifta na Windows):
  - id i ścieżki (`isCoreFile`, `isCoreEntryID`, `relativePath`, `fileIDs`);
  - walidator: core przyjmuje 3–5 przykładów, odrzuca 2 i 6, wymaga prefiksu `core.`, tematy nadal mają dokładnie 2, wykrywa powtórzone przykłady;
  - dodanie wpisu z 5 przykładami: wszystkie 5 trafiają do znaczenia (`availableExampleCount` = 5), `ExamplePool` rotuje 0…4, kolekcja „Słownictwo ogólne”, `contentRef`, brak `topic` i `scene`;
  - `suggestion` → `lookup` → `mergeSuggestions` zachowuje wszystkie przykłady;
  - prawdziwe pliki `core/`: dekodowanie, `group`/`namePl`, `entryIssues` puste, unikalne id;
  - każdy wpis core jest w `dictionary-index.json` (a *attain* w `ContentSearch`); `topics/index.json` nie zawiera core.
- **`ContentLibraryTests.testCoreReferencesResolveAndCoreIsNotATopic`**:
  - rozwiązanie referencji i fallback z `core-c99/…`;
  - błąd dla nieistniejącego wpisu;
  - `lookup` z kolekcją core i kompletem przykładów;
  - brak core w katalogu i rankingu tematów.
- Skrypty:
  - `node ios/tools/validate-content.mjs` → **OK: 157 plików, 10 728 wpisów, 0 błędów, 0 ostrzeżeń**;
  - `node ios/tools/validate-content.mjs --self-test` → **SELF-TEST OK** (w tym `valid-core` 0/0 oraz `invalid-core` z 6 oczekiwanymi błędami i 1 oczekiwanym ostrzeżeniem);
  - `node ios/tools/build-index.mjs` → 142 tematy, **10 728 rekordów słownika (w tym core 17)**; `topics/index.json` bez zmian; `--check` OK;
  - `node ios/tools/build-core-master.mjs --check` → aktualne (5 367 haseł, 8 shardów);
  - `node ios/tools/apply-reading-glossary.mjs --check` → OK.
