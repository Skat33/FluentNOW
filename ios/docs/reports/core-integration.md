# core-integration — podłączenie słownika rdzeniowego (FEEDBACK-7) do Polecanych i testu

Pozycje 34–35 `CODE-QA-BACKLOG.md` (polecane słówka z core, test poziomujący z core) + domknięcie dystraktorów „Wybierz znaczenie” dla par bliskoznacznych z core. Treść JSON nie była zmieniana; git i `build-index.mjs` nie były uruchamiane.

## 1. Co zmieniono (plik → zmiana)

### FluentKit
- `Analysis/UsefulWordRecommender.swift`
  - `UsefulWordCandidate.isCore` (wyliczane z `topicID` = shard `core-cNN`).
  - `UsefulWordReason.coreVocabulary` — „słownictwo ogólne, przydatne w wielu sytuacjach” (zamiast `.everyday` dla wpisów core).
  - `candidates(...)`: gałąź `reference.isCore` → nazwa `CoreVocabulary.collectionName`, grupa `coreGroup = "basics"` (grupa codzienna, +12). `less_common` core trafia do puli tylko dla rodzin wyrazów (jak dotąd).
  - `recommend(...)`: wpis core poza rodziną wyrazów musi mieścić się w **poziom ucznia ±1** (od poziomu −1, `coreLevelsBelow = 1`, do celu = poziom +1); tematów nie dotyczy (stara reguła). Core nigdy nie liczy się jako „temat, którego się uczysz” (`learnedCount` = 0 — kolekcja „Słownictwo ogólne” nie daje bonusu tematu). Częstość: bez zmian (`very_common` +40, `common` +26, potem remis po częstości) — wyższa częstość ma pierwszeństwo. Posiadane słowa (klucz hasła lub referencja) wykluczone jak wszędzie. Rodziny wyrazów (`WordFamilyIndex` budowany z całego `dictionary-index`, więc obejmuje core) działają dla core, łącznie z `less_common`.
  - `UsefulWordProfile.make`: `topicCounts` nie liczy referencji core (shard to pasmo częstości, nie temat).
- `Assessment/AssessmentBuilder.swift`
  - `bankEntries(topic:band:fromLearnerTopics:)`: dla pliku core `categoryName`/`scene` = `nil` (kategorie core to pasma CEFR — jak `VocabularyMerger.addTopicEntries`).
  - Nowe: `coreFileLimit = 3`, `coreFileIDs(entries:band:available:limit:)` — wybór shardów najbogatszych w częste wpisy z dolnego i górnego poziomu pasma wg rekordów `dictionary-index` (bez dekodowania shardów); bez rekordów → pierwsze shardy (najczęstsze słowa).
  - `learnerTopicIDs`: pomija referencje core.
- `Sessions/MeaningOptions.swift` — dystraktor odrzucany, gdy **pełny** zbiór kluczy kandydata (tłumaczenie, jego części, `acceptedTranslations`, warianty `PolishAnswerIndex`, pary aspektowe) przecina się z pełnym zbiorem kluczy celu — w obu kierunkach naraz. Wcześniej nie było sprawdzane przecięcie *akceptowanych odpowiedzi celu* z *akceptowanymi odpowiedziami kandydata* (np. redundant „nadmiarowy” [zbędny] vs superfluous „zbyteczny” [zbędny]). Do kluczy dochodzą formy luźne `TextNormalizer.looseKeys` (bez nawiasów i interpunkcji wewnętrznej: „szkoda (że)” = „szkoda”). Nowe publiczne: `MeaningOptions.comparisonKeys(_:)`, `MeaningOptions.overlaps(_:target:answerIndex:)`.

### Aplikacja
- `Services/Content/ContentLibrary.swift`
  - `topic(id:)` dla `core-cNN` → `coreFile(id:)`: dekodowanie w `Task.detached` (poza aktorem — inne zapytania do treści nie czekają ~50–100 ms na shard), deduplikacja trwających wczytań (`coreLoads`), wynik w `topicCache`.
  - Nowe: `coreFiles(ids:) async -> [TopicFile]` (shardy równolegle, pomija nieczytelne/nie-core, kolejność jak `ids`), `coreDictionaryEntries() async -> [DictionaryIndex.Entry]` (rekordy core z indeksu słownika, cache).
- `Features/Today/UsefulWordsCatalog.swift`
  - `readDetails` → `async`, pliki równolegle (`withTaskGroup`), nowa `readFileDetails` czyta ścieżkę z `ContentReference.relativePath` i dekoduje `ContentDecoder.coreFile` / `topicFile` / `starterWords`. Shard core zwraca szczegóły **wszystkich** swoich wpisów (małe: rejestr, część mowy, IPA, 1 przykład) — kolejne przebiegi rankingu i „Odśwież propozycje” nie dekodują shardu ponownie.
  - Kolejność: kandydaci z samego `dictionary-index` → ranking → szczegóły tylko dla wyników puli (72) → filtr rejestru (slang/specjalistyczne core odpadają jak w tematach).
  - `UsefulWordsAdder`: core idzie przez `content.topic(id:)` + `VocabularyMerger.addTopicEntries` z **pełnego** pliku → znaczenie dostaje wszystkie 3–5 przykładów, kolekcja „Słownictwo ogólne”, bez kategorii/sceny. Wpis nieobecny w pliku (np. przeniesiony shard) liczony jako `failed`, nie gubiony po cichu.
  - Switch `isFromLearnedTopic` uzupełniony o `.coreVocabulary`; `init(rootURL:)` do testów.
- `Features/Study/Test/TestLoader.swift` — `bankEntries` dokłada `coreBankEntries`: `coreFileIDs()` → `coreDictionaryEntries()` → `AssessmentBuilder.coreFileIDs` (3 shardy) → `coreFiles(ids:)` → `AssessmentBuilder.bankEntries(topic:band:fromLearnerTopics: false)`. Tematy jak dotąd (także gdy brak `topics/index.json` core nadal działa). `addBankWords` dodaje wpisy core z pełnego pliku (wszystkie przykłady). `TestSessionModel` bez zmian (stan „preparing” już pokazuje ładowanie).

### Dlaczego tak (wymagania FEEDBACK-6/7)
- Test: pasmo i adaptacja bez zmian (`AssessmentBand`, maks. 6 słów stretch, `maxBankPerTier = 30`) → poziom spójny, każdy typ zadania, 30 pytań ≈ 18 min, bez cofania. Core trafia do puli „others” (losowo razem z tematami, po słowach z tematów ucznia); przy ~600–900 częstych wpisach z pasma w 3 shardach stanowi zdecydowaną większość słów z bazy. Symulacja na realnym indeksie (top-3 shardy / liczba częstych wpisów): A1 → c01,c02,c03 (A1: 201); A2/B1 → c01,c02,c04 (A2: 334, B1: 560); B2 → c05,c02,c03 (B1: 471, B2: 733); C1 → c06,c05,c02 (B2: 730, C1: 199). C2 — core prawie nie ma częstych C2, test C2 nadal opiera się na tematach.
- Polecane: core = grupa codzienna → przy limicie puli 72 core może zająć do ~29 miejsc (limit grupy) i do 15 na shard; przy limicie 20: do 8.

## 2. Publiczne API (nowe / zmienione)
```swift
// FluentKit
extension UsefulWordCandidate { public var isCore: Bool }
UsefulWordReason.coreVocabulary
UsefulWordRecommender.coreGroup: String          // "basics"
UsefulWordRecommender.coreLevelsBelow: Int        // 1
AssessmentBuilder.coreFileLimit: Int              // 3
AssessmentBuilder.coreFileIDs(entries: [DictionaryIndex.Entry], band: AssessmentBand, available: [String], limit: Int = coreFileLimit) -> [String]
MeaningOptions.comparisonKeys(_ keys: Set<String>) -> Set<String>
MeaningOptions.overlaps(_ candidate: WordMeaning, target: WordMeaning, answerIndex: PolishAnswerIndex = PolishAnswerIndex()) -> Bool
// Aplikacja (actor ContentLibrary)
func coreFiles(ids: [String]) async -> [TopicFile]
func coreDictionaryEntries() async -> [DictionaryIndex.Entry]
// UsefulWordsCatalog
init(rootURL: URL?)
```
`UsefulWordReason` ma nowy przypadek — jedyny wyczerpujący `switch` poza FluentKit (`UsefulWordsCatalog.isFromLearnedTopic`) zaktualizowany (grep całego repo).

## 3. Testy
FluentKit:
- `UsefulWordRecommenderTests`: `testCoreEntriesAreCandidates` (core w kandydatach, nazwa/grupa, `core/` bez numeru nie jest shardem, `less_common` dla rodzin), `testCoreFollowsTheLearnersLevelPlusMinusOne` (B2: B1–C1, A1: A1–A2, tematy po staremu, kolejność wg poziomu i częstości), `testCoreSkipsOwnedWordsAndHasItsOwnReason` (posiadane hasła/referencje, brak `topicCounts` dla core, powód `.coreVocabulary`, brak „z tematu Słownictwo ogólne”), `testCoreWordFamilyIgnoresTheLowerLevelLimit`, `testRealCoreVocabularyIsRecommendedAtTheLearnersLevel` (realny indeks, A2–C1: ≥10 core w puli 72, każdy w ±1 i częsty). Helper `registers(for:)` w teście realnej treści czyta też `core/` (inaczej test by się wywrócił po dodaniu core do kandydatów).
- `AssessmentTests`: `testCoreShardGivesGeneralBankWordsWithoutCategory`, `testCoreFilesRichestInTheBandAreLoaded`, `testCoreVocabularyAloneGivesAFullTestInTheBand` (sam core → pełne 30 slotów, wszystkie bloki, tylko A2–B2, stretch ≤ 6, 15–22 min), `testRealCoreVocabularyFillsEveryBand` (realne shardy A1–C1: ≥30 słów na poziom pasma, ≥3 przykłady).
- `SessionTests.testMeaningOptionsNeverOfferASecondCorrectAnswer` — pity/shame „szkoda”, redundant/superfluous (wspólne akceptowane „zbędny”), appease/placate („załagodzić (czyjś gniew)” → klucz luźny), once in a while/now and then, regret [„szkoda (że)”] w obu kierunkach, `overlaps`, `comparisonKeys`.

Aplikacja (`FluentNOWTests/Services/ContentLibraryTests.swift`):
- `testCoreFilesLoadOnceAndCoreDictionaryEntries` (współbieżne `topic(id:)` + `coreFiles`, pomijanie `core-c99`/tematu, cache, rekordy core z indeksu, wybór shardów).
- `testCoreRecommendationsHaveDetailsAndAddAllExamples` (`UsefulWordsCatalog(rootURL:)` na realnej treści: core w puli, szczegóły z przykładem, bez slangu; `UsefulWordsAdder` dodaje 1 znaczenie z **wszystkimi** przykładami wpisu do „Słownictwo ogólne”).
- `testLevelTestDrawsBaseWordsFromCore` (`TestLoader.makeSession` dla B1: słowa z core w `bankWords`, bez kategorii, poziomy A2–B2, każdy typ bloku).

Nie uruchomione (brak Swift na Windows) — do uruchomienia na Macu: `swift test` w `Packages/FluentKit` i schemat testów aplikacji.

## 4. Ryzyka kompilacji do sprawdzenia na Macu
- `FluentNOW/Features/Today/UsefulWordsCatalog.swift:172` — `withTaskGroup(of:returning:) { (group: inout TaskGroup<…>) async -> … in` z jawnym typem `inout` i `for await partial in group` (statyczna metoda aktora, nieizolowana). Fallback: `{ group in … }` albo pętla sekwencyjna.
- `UsefulWordsCatalog.swift:158` — `Task.detached { () async -> … in await UsefulWordsCatalog.readDetails(...) }` (prywatna statyczna metoda z zamknięcia w aktorze; wcześniej tak samo, tylko synchronicznie).
- `UsefulWordsCatalog.swift:273` — `topicFiles[reference.file]?.entry(id:) != nil` (opcjonalna krotka porównywana z `nil` — działa przez `_OptionalNilComparisonType`).
- `FluentNOW/Services/Content/ContentLibrary.swift:135` — `Task.detached(priority: .userInitiated) { () throws -> TopicFile in … }` przypisane do `Task<TopicFile, Error>`; `:94` `coreFiles` — krotki `(id:task:)` w tablicy, `try await item.task.value` w aktorze; `:108` `Self.log.error("\(message, privacy: .public)")`.
- `FluentNOWTests/Services/ContentLibraryTests.swift:158–160` — `async let single: TopicFile = library.topic(id:)` (rzucające, bez `try` w inicjalizatorze) i `try await (single, many)`.
- `Packages/FluentKit/Sources/FluentKit/Sessions/MeaningOptions.swift:81` — `allSatisfy` z jawnym typem; `TextNormalizer.looseKeys(key, using: TextNormalizer.answerKey)` (referencja do metody statycznej jako nie-ucieczkowe zamknięcie).
- `TestLoader.swift:60` — nieizolowana `private static func … async` wywoływana z `@MainActor makeSession` (wykonuje się poza głównym wątkiem — jak dotychczasowe `bankEntries`).

## 5. Wydajność
- Polecane: kandydaci z `dictionary-index` (jak dotąd, `Task.detached`), szczegóły tylko dla wyników puli; shardy core dekodowane równolegle w tle, raz na sesję aplikacji (cache szczegółów w `UsefulWordsCatalog`, ok. 0,3 KB na wpis). Pierwsze otwarcie Polecanych może czytać kilka shardów (~0,8 MB każdy) — w tle, ekran pokazuje stan ładowania; główny wątek nie dekoduje niczego.
- Test: 3 shardy zamiast 8, dekodowane równolegle poza aktorem i trzymane w `ContentLibrary.topicCache` (kolejne testy / dodawanie słów bez ponownego dekodowania; ok. kilka MB pamięci).
- `MeaningOptions`: dodatkowe klucze luźne liczone tylko dla kluczy z nawiasami/interpunkcją (szybka ścieżka dla zwykłych słów).

## 6. Co zostało / uwagi
- Testy niewykonane lokalnie (brak kompilatora) — uruchomić na Macu; progi w testach realnej treści (≥10 core w puli 72, ≥30 słów na poziom) wyliczone z obecnego indeksu.
- Opcjonalnie: `CONTRACTS.md` §4 i `CONTENT-SCHEMA.md` §6 „Aplikacja” mogą wspomnieć nowe `coreFiles(ids:)` / `coreDictionaryEntries()` i regułę ±1 w Polecanych (nie edytowałem dokumentów kontraktu — poza obszarem).
- Opcjonalnie: prewarm `coreDictionaryEntries()` w `warmUp()` nie jest potrzebny (indeks słownika i tak jest rozgrzewany).
- Uwaga procesowa: jedna podmiana w `MeaningOptions.swift` (kwalifikacja `MeaningOptions.comparisonKeys`) została zrobiona prostym `sed -i` zamiast narzędziem Edit — wynik sprawdzony, bez znaków `\`/heredoców.
- Backlog: pozycje 34–35 odznaczone; do pozycji o dystraktorach dopisana nota.
