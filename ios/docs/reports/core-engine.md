# Raport: core-engine — FluentKit

Pakiet: `ios/Packages/FluentKit` (Swift tools 5.9, iOS 17 / macOS 14, zero zależności, tylko `import Foundation`).
Stan: kod i testy napisane na Windows **bez kompilatora** — pierwsza kompilacja nastąpi na Macu (`cd ios/Packages/FluentKit && swift test`).

## 1. Co zrobiono (pliki)

```
Package.swift                         biblioteka FluentKit + FluentKitTests (XCTest, zasób Fixtures/)
Sources/FluentKit/
  FluentKit.swift                     FluentKitInfo (wersja kontraktu, zgodność web-v42)
  Support/   Timestamp.swift          Timestamp (= Double ms), TimeConstants, FluentClock, Date(timestamp:), jsRound
             Random.swift             SeededGenerator (SplitMix64), nextUnit(), FNV-1a (bitowo jak strona)
             DecodingHelpers.swift    tolerancyjne dekodowanie (lenient*, lossyArray, FailableDecodable)
             Collections.swift        stableSorted, subscript(safe:), uniqued
             TextScanning.swift       zamienniki regexów (granice \b, [A-Za-z], zwijanie spacji, foldPolish)
  Models/    Enums, Score (+SkillScores), Meaning (+Enrichment), Word, Review (+ReviewSummary),
             VocabSession (+VocabTask), LearnerSettings, LearnerState (+historie), Reading, Practice,
             Production, Combined, TutorTypes (ExamplePair, SenseSuggestion, Lookup, Grade, Recommendation)
  Scheduling/ Mastery.swift, Scheduler.swift (schedule/recordAnswer/applyReadingResults), ExamplePool.swift
  Sessions/  SessionBuilder (makeSession, allowedTaskTypes), Interleave, Confusable, MeaningOptions,
             GrammarSelection, PracticeBuilder (+PracticeContent), ReadingSelection (+LevelEstimator),
             CombinedSessionBuilder, PracticeFlow (przejścia ekranów ćwiczeń)
  Grading/   TextNormalizer, VocabularyGrader, PolishAnswerIndex, ProductionGrader, Cloze, ExerciseAudio (+ReadingTokenizer)
  Content/   AnswerVariants (+builtIn), TopicContent, Banks, ContentDecoder, ContentSearch, VocabularyMerger
  Sync/      StateSync (compactReviews, mergeStates, mergeWord, mergeDuplicateWords)
  ImportExport/ StateMigration, StateImporter (+ImportError, StateValidator), DelimitedImport (+StateExporter)
  Statistics/ ProgressStatistics
Tests/FluentKitTests/
  TestSupport.swift (port seed(), freshWord, IDGenerator, ConstantGenerator, treść syntetyczna, loader plików treści)
  SchedulingTests, SessionTests, GradingTests, ContentTests, SyncImportExportTests, PracticeTests,
  StatisticsTests, ModelCodingTests
  Fixtures/state-v31.json (kopia web-source/tests/fixtures)
```
Razem 57 plików Swift, ~9 500 linii (≈ 6 400 źródła, ≈ 3 100 testy).

## 2. Kluczowe decyzje / kontrakt dla fali 2

- **Daty:** wszystkie czasy to `Timestamp = Double` (ms od 1970, jak strona) — eksport strony wczytuje się bez konwersji. Na granicy z UI: `Date(timestamp:)`, `date.timestamp`. Zegar czyta tylko `FluentClock.now()`; każda funkcja logiki dostaje `now:`.
- **Losowość:** `inout G: RandomNumberGenerator` (`using:`); w testach `SeededGenerator`. Dla `makeSession` jest też przeciążenie bez RNG (systemowy).
- **Identyfikatory:** wstrzykiwane (`reviewID:`, `makeID:`, `id:`), domyślnie `UUID().uuidString.lowercased()`.
- **Czyste funkcje:** stan → nowy stan, brak singletonów i stanu globalnego. Wszystkie typy `Sendable` → można liczyć w `Task.detached`.
- **JSON:** klucze jak na stronie; `LearnerState` koduje wymagane-nullowalne `session` (oraz `combined`, `reading`, `practice`, `production`) jako `null`; `scores` jako obiekt `{ "recall": {...} }`. Dekodowanie tolerancyjne: brakujące pola → wartości domyślne, uszkodzone wpisy historii są pomijane, uszkodzone **sesje przejściowe** są odrzucane (nil) zamiast blokować import; **słowa/znaczenia dekodowane ściśle** (uszkodzone słowo = czytelny błąd, nic nie ginie po cichu). Po każdym dekodowaniu wołać `StateMigration.migrate` (robi to `StateImporter`).
- **Treść:** `ContentDecoder.*(from: Data)` wg CONTENT-SCHEMA §1–§5 (gramatyka w `grammar/<poziom>.json` → `GrammarLevelFile`; `PracticeContent(grammarFiles:exercises:idioms:readings:)`). Wbudowane znaczenia powstają **bez `enrichment`** (wszystkie przykłady od razu dostępne offline) i z `Meaning.contentRef = "<plik>/<entry id>"` (znaczniki „dodane” — `VocabularyMerger.addedContentReferences`).
- **Platform-services:** duplikaty rekordów CloudKit → `StateSync.mergeDuplicateWords` / `mergeWord`; scalanie dwóch stanów → `StateSync.mergeStates(local:remote:)`; okresowo → `compactReviews`.
- **UI:** typ ćwiczenia `ExerciseType` (0–4 jak strona) z `namePl`, `skill`, `estimatedSeconds`, `promptAudioAllowed`; ocena wpisu: `VocabularyGrader.localGrade` (dla luki najpierw `gradingWord`), potem `Scheduler.recordAnswer(... spellingCorrect: grade.spellingCorrect ...)`. `Grade.isFailure` jest `true` tylko dla `.incorrect` („uncertain” nie oblewa). `Grade.closestAnswer` ≠ nil → pokaż „Literówka? Poprawnie: …” i przycisk „Uznaj moją odpowiedź” (wtedy `correct: true, spellingCorrect: false`).
- **Wydajność:** `ContentSearch` budować raz poza głównym wątkiem; `PolishAnswerIndex` budować raz i przekazywać do `MeaningOptions`/`ConfusableDetector` (domyślny argument tworzy nowy indeks przy każdym wywołaniu — poprawne, ale wolniejsze); statystyki liczyć poza `body` i cache'ować.

## 3. Odstępstwa od strony (i błędy strony poprawione)

1. `recordAnswer`, `status`, `selectReadingMeanings`, `makeCombinedSession` używały `Date.now()` / `Math.random` — teraz czas i RNG są wstrzykiwane.
2. `recordAnswer` na stronie wysypywał się (`!`) dla nieistniejącego słowa/znaczenia — tu zwraca stan bez zmian.
3. `wordMastery` dzieliło przez 0 dla słowa bez znaczeń (NaN) — teraz 0.
4. `chooseType` sortował z niespójnym komparatorem (`random() - 0.5`) — teraz klucze rozstrzygające są losowane raz (poprawny porządek, deterministyczny dla ziarna).
5. `makeSession` liczył `reviews.filter` dla każdego znaczenia (O(n·m)), a tryb par był O(n²) — teraz słownik zliczeń i indeks rdzeni.
6. `makeCombinedSession`: pusta lista trybów → dzielenie przez 0; pusty bank → nieskończona pętla `while(remaining>0)` — zabezpieczone. `selectBankReading` dla pustego banku miał nieskończoną rekurencję — zwraca `nil`.
7. `starterPractice`/`idiomPool`/`starterProduction` przy pustej puli indeksowały `% 0` — zwracają puste zestawy.
8. Rotacja odpowiedzi (`answer = (4 - shift) % 4`) zakładała 4 opcje i klucz na pozycji 0 — uogólnione na n opcji i dowolny klucz.
9. **Synchronizacja (poprawa):** strona przy konflikcie brała wszystkie wyniki zwycięskiej kopii słowa (postęp z drugiego urządzenia ginął). Teraz `mergeWord` scala wyniki **per umiejętność** (wygrywa wynik z późniejszym `last`) dla tego samego znaczenia (ten sam termin i tłumaczenie). Reszta jak strona (unia historii, max podsumowań i `grammarSeen`, bank przykładów, `usedExamples`).
10. **Migracja (naprawy):** zduplikowane `id` słów są scalane (nie odrzucane); interwał przycinany do 0…90, NaN→0; sesja słownictwa z niepoprawnym ukończonym prefiksem jest odrzucana zamiast blokować cały import (strona odrzucała cały plik); puste sesje praktyki/produkcji → nil; indeksy przycinane.
11. **Import CSV:** wiersze, które użytkownik już ma (to samo słowo + tłumaczenie), są pomijane (strona tworzyła duplikaty); `pos` pusty zamiast zawsze „rzeczownik”; dodatkowo lista słów `word - tłumaczenie` (`–`, `—`, `=`). Parser działa na skalarach Unicode (w Swift `"\r\n"` to jeden `Character`).
12. **Ocenianie:** zgodnie z decyzją strony v38 literówka nie jest automatycznie zaliczana (test strony `lnd` → incorrect zachowany), ale `Grade.closestAnswer` umożliwia ręczne uznanie (realizuje „tolerancję literówek i osobną ocenę pisowni” bez fałszywych zaliczeń). Aliasy EN (`lend someone`) działają, gdy tłumaczenie zakotwicza zrecenzowaną grupę wariantów danego znaczenia (strona sprawdzała obecność w `seed()`). `answerKey` dodatkowo przycina końcową spację.
13. **make/do (uwaga english-qa):** `starter.do` ma teraz „robić, wykonywać”, co pokrywa się z wariantami `make` („robić”, „zrobić”). Dodano `PolishAnswerIndex`: (a) `MeaningOptions` nie podsuwa jako dystraktora tłumaczenia, które jest akceptowaną odpowiedzią znaczenia docelowego (pytanie byłoby niejednoznaczne); (b) `ConfusableDetector` uznaje za parę znaczenia o wspólnej akceptowanej odpowiedzi PL (make/do trafiają do „Słów w parach” mimo krótkich rdzeni); (c) ocenianie: „robić” poprawne dla do i make, „stworzyć” tylko dla make, „robić” niepoprawne dla „czy (w pytaniach)” — test `testMakeDoOverlapIsConfusableButNotAnAmbiguousDistractor`. Listy `acceptedAnswers` (w gramatyce do 9 pozycji) nie mają w kodzie żadnego limitu.
14. `idiomPool`: dystraktory liczone z poprawnych znaczeń pozostałych idiomów poziomu, jak `idiomPool(level, variant)` strony (plik ma `answer` zawsze 0 — rotacja i dystraktory zależą od `variant`).
15. `selectBankReading` korzysta z całego `readings.json` (także 12 dawnych czytanek `reading-legacy-*` — więcej treści przed powtórką).
16. `estimatedLevel` i „postęp wg poziomu” liczone per znaczenie (`meaning.level ?? word.level`); strona w statystyce poziomu liczyła per słowo.
17. Prognoza powtórek i licznik „do powtórki” nie liczą nigdy nie ćwiczonych znaczeń — są osobno w `StatsOverview.newMeanings` (strona wliczała je jako wymagalne z `due = 0`).
18. `Recommendation.focusPl` — eksport nie ma tego pola; fragment PL to dokładny podciąg zdania albo słowo o tym samym 4-literowym początku, inaczej `""` (nigdy nie-podciąg).
19. Pominięte celowo (AI/serwer, nie FluentKit): `meaning-enrichment` (generowanie 15 przykładów), raporty błędów, korekty z serwera (`report-corrections`), tematy generowane przez AI.

## 4. Ryzyka / niesprawdzone

- **Brak kompilacji.** Przegląd ręczny: importy, nawiasy (skrypt), brak `!`/`try!`/`as!`/`fatalError`, `Codable` enumu z wartościami powiązanymi ręcznie (`CombinedTask`), jawne `public init` wszędzie (memberwise jest internal), domyślne argumenty publicznych funkcji odwołują się tylko do publicznych symboli, wieloliniowe domknięcia mają jawne typy. Miejsca o mniejszej pewności:
  - `ContentSearch` przechowuje tablice krotek w typie `Sendable` — przy `strict-concurrency=minimal` bez ostrzeżeń; przy pełnym sprawdzaniu ewentualnie zamienić krotki na małe struktury.
  - Przekazanie lokalnej funkcji `add` jako nie-ucieczkowego parametru w `ContentSearch.search` (dozwolone, do potwierdzenia).
  - Dekodowanie `Bool` z liczby JSON (`1`) — traktowane jako błąd typu → wartość domyślna.
- **Testy sekwencji** (przeplatanie pięciu sesji, kolejność łączona) sprawdzają własności algorytmu, nie konkretne ciągi strony (inny generator). Jeśli `testFiveConsecutiveSessionsInterleaveAndFillBudget` lub `testInterleaveKeepsAllTasksAndAlternates` nie przejdą, to błąd portu `TaskInterleaver` (porównać z `interleaveTasks` w `learning.ts`).
- Testy wydajności mają duże marginesy (debug): `makeSession` 5 000 słów < 1 s (cel < 50 ms w release), `ContentSearch` < 100 ms/zapytanie (cel < 5 ms w release). Warto raz zmierzyć w release.
- Testy na prawdziwej treści czytają pliki przez `#filePath` z `ios/FluentNOW/Resources/Content`; bez nich robią `XCTSkip`. `testEveryBankItemGradesItsOwnKey` sprawdza 1 872 zadania — zależy od poprawek english-qa (nowe `acceptedAnswers` nie mogą pokrywać się z dystraktorami).
- `StateSync.utcDay` używa kalendarza gregoriańskiego UTC (jak `toISOString` strony); statystyki dzienne używają wstrzykniętego `Calendar` (strefa użytkownika).

## 5. Prośby do innych ról

- **platform-services:** (1) po każdym odczycie z SwiftData / imporcie → `StateMigration.migrate`; (2) dedup rekordów → `StateSync.mergeDuplicateWords`; (3) raz na start → `StateSync.compactReviews(state, now:)`; (4) zbuduj raz: `ContentSearch`, `PolishAnswerIndex(answerVariants)`, `PracticeContent` (ładuj tylko potrzebny `grammar/<poziom>.json`; poziom = `LevelEstimator.estimatedLevel(state).targetLevel`), `VocabularyMerger.starterWords(starter.words)` jako pula dystraktorów; (5) eksport: `StateExporter.exportJSON` (zgodny ze stroną), CSV: `StateExporter.ankiCSV`.
- **ui-learning:** sesja słówek: `SessionBuilder.makeSession` → `MeaningOptions.options` (typ 3), `Cloze.text`, `ExerciseAudio.*`, `VocabularyGrader.localGrade` → `Scheduler.recordAnswer`. Gramatyka/idiomy/produkcja/czytanie: `PracticeFlow.*`; sesje łączone: `CombinedSessionBuilder.makeSession/saveAnswer/advance`; przy wyświetleniu zadania z `bankId` wołać `GrammarSelector.markSeen` (jak strona). Wpis w miksie: `ProductionGrader.checkPracticeInput`, w produkcji `ProductionGrader.grade`.
- **ui-library:** Postępy/Dzisiaj: `ProgressStatistics.*`; słownik: `Word.status(now:)`, `Word.mastery`; dodawanie: `ContentSearch.search`, `VocabularyMerger.mergeSuggestions` / `addTopicEntries`; import CSV: `DelimitedImport.importRows`, JSON: `StateImporter.importJSON` (ewentualnie + `StateSync.mergeStates`).
- **data-pipeline / english-qa:** zachować `answer: 0` w `idioms.json` i unikalne `bankId`; `acceptedAnswers` zadań gramatycznych nie może zawierać formy z `distractors` (test to wykryje).

## 6. Testy

Nieuruchomione (brak Swift na Windows). 8 plików, ~120 testów XCTest:

- **Scheduling:** `masteryFromInterval` (NaN, ∞, ujemne), 6 statusów, wymowa nie liczy się do opanowania, podpowiedź ≠ błąd, naprawa trudności, progi wolnych odpowiedzi per typ, waga czytania nie skraca interwału, czas w przyszłości, nieudane zadanie wraca w innym formacie (pary → luka), błąd pisowni nie kasuje przypominania, `usedExamples`, `applyReadingResults`, pula przykładów (partie 15, uzupełnianie przy 3, limit 90).
- **Sessions:** progresja typów, pierwsza sesja same fiszki, pary z własnego słownika, make/do, luka tylko dla całych słów i form odmienionych, budżet + nowe znaczenia (dokładnie 8), pięć kolejnych sesji (przeplatanie, rozłożenie dominującego typu, determinizm ziarna), tryb pomyłek, kolekcje/archiwum, puste dane, opcje znaczeń (4 unikalne, deterministyczne, tasowane, pula startowa), wydajność 5 000 słów (+ tryb par).
- **Grading:** normalizacje, Levenshtein, lend/borrow (kierunek, dyktando dokładne, aliasy tylko dla właściwego znaczenia), literówki niezaliczane + `closestAnswer`, 17 przypadków zrecenzowanych wariantów PL, pary aspektowe (z negacją), zgodność `AnswerVariants.builtIn` z plikiem, produkcja (skróty they'd/I'd/she's/didn't; kolejność poprawna → dystraktor → literówka → ogólny; zmiana operatora/negacji ≠ literówka), `checkPracticeInput` (skróty, idiomy), audio z lukami, podświetlanie słów w czytance.
- **Content:** dekodowanie tematu, konwersja na słowa (dwa znaczenia → jedno słowo, bez `enrichment`, `contentRef`), ponowne dodanie nie kasuje postępu, wybrane wpisy, kolekcje, indeks słownika, wyszukiwanie (dokładne / prefiks / słowo w zwrocie / polskie / literówka), wydajność 20 000 rekordów, wszystkie pliki banków (1 800 zadań, 18 idiomów/poziom), każde z 1 872 zadań ocenia własny klucz, nieobsługiwana wersja schematu.
- **Sync/Import/Export:** fixture v31 (migracja addytywna, round-trip eksport→import identyczny), eksport zgodny ze stroną, normalizacja migracji (idempotencja), usuwanie niepublikowanych zadań, stare sesje praktyki, duplikaty słów (scalanie) i znaczeń (błąd), czytelne błędy importu, `compactReviews`, scalanie (najnowsza edycja, unia recenzji, postęp z dwóch urządzeń, bank przykładów, `grammarSeen`, podsumowania, historie, kolekcje, sesja łączona), CSV/TSV, lista słów, CSV Anki.
- **Practice:** hash `legacy-grammar-773677652` zgodny ze stroną, wybór gramatyki (niewidziane najpierw, rozkład reguł, brak powtórek do wyczerpania puli, potem najstarsze), kształt zestawów, klucz po rotacji, rotacja idiomów, produkcja, rezerwacja wstrzymanych sesji, czytanki, poziom CEFR, wybór znaczeń do czytanki, rekomendacje, przepływy praktyki/produkcji/czytania, sesja łączona.
- **Statistics:** tydzień i kalendarz (bez demo), seria i cel dzienny, umiejętności, poziomy, prognoza, przegląd, tygodniowe przekroczenia progu (tylko `masteryVersion 2`), trudne słowa, sumy.
- **Model coding:** ustawienia, `scores` jako obiekt, liczby/teksty tolerancyjnie, nieznany typ zadania, `CombinedTask` round-trip, `diagnosis: null`, tolerancyjne odpowiedzi AI, dopełnianie odpowiedzi, wymagane klucze `null`, daty/zaokrąglenia.

Uruchomione skrypty (Node): zgodność `AnswerVariants.builtIn` z `answer-variants.json` (41 grup, 62 pary — identyczne), kontrola nawiasów/CR/BOM wszystkich plików Swift (OK), skan `!`/`try!`/`as!`/`fatalError` (brak), skan interpolacji (OK).

## 7. Pełne publiczne API (sygnatury)

Wszystkie modele są `Codable, Sendable, Hashable` (`init(from:)` / własne `encode(to:)` pominięte w liście). `Timestamp = Double` (ms). Lista wygenerowana z kodu źródłowego.

```swift
// Content/AnswerVariants.swift
public struct AnswerVariants: Codable, Sendable, Hashable
    public struct SenseVariants: Codable, Sendable, Hashable
        public var term: String
        public var variants: [String]
        public init(term: String, variants: [String])
    public var schemaVersion: Int
    public var polishSenseVariants: [SenseVariants]
    public var polishAspectPairs: [[String]]
    public var englishAliases: [String: [String]]
    public init(schemaVersion: Int = 1, polishSenseVariants: [SenseVariants] = [], polishAspectPairs: [[String]] = [], englishAliases: [String: [String]] = [:])
    public static let builtIn

// Content/Banks.swift
public struct DictionaryIndex: Codable, Sendable, Hashable
    public struct Entry: Codable, Sendable, Hashable
        public var term: String
        public var key: String
        public var translation: String
        public var level: String
        public var frequency: String
        public var reference: String
        public init(term: String, key: String? = nil, translation: String, level: String = "", frequency: String = "", reference: String)
        public var contentReference: ContentReference?
        public var spokenFrequency: SpokenFrequency?
    public var schemaVersion: Int
    public var entries: [Entry]
    public init(schemaVersion: Int = 1, entries: [Entry] = [])
public struct GrammarLevelFile: Codable, Sendable, Hashable
    public var schemaVersion: Int
    public var version: Int
    public var level: String
    public var rules: [String]
    public var items: [ProductionItem]
    public init(schemaVersion: Int = 1, version: Int = 36, level: String, rules: [String] = [], items: [ProductionItem] = [])
public struct ProductionBank: Codable, Sendable, Hashable
    public var schemaVersion: Int
    public var version: Int
    public var levels: [String: [ProductionItem]]
    public init(schemaVersion: Int = 1, version: Int = 1, levels: [String: [ProductionItem]] = [:])
    public init(grammarFiles: [GrammarLevelFile])
    public func items(level: String) -> [ProductionItem]
public struct IdiomBank: Codable, Sendable, Hashable
    public var schemaVersion: Int
    public var levels: [String: [PracticeQuestion]]
    public init(schemaVersion: Int = 1, levels: [String: [PracticeQuestion]] = [:])
    public func items(level: String) -> [PracticeQuestion]
public struct ReadingBank: Codable, Sendable, Hashable
    public var schemaVersion: Int
    public var readings: [Reading]
    public init(schemaVersion: Int = 1, readings: [Reading] = [])
public struct StarterWords: Codable, Sendable, Hashable
    public var schemaVersion: Int
    public var words: [TopicEntry]
    public init(schemaVersion: Int = 1, words: [TopicEntry] = [])
public struct RecommendationBank: Codable, Sendable, Hashable
    public var schemaVersion: Int
    public var items: [Recommendation]
    public init(schemaVersion: Int = 1, items: [Recommendation] = [])

// Content/ContentDecoder.swift
public enum ContentError: Error, LocalizedError, Sendable, Equatable
    case unreadable(file: String)
    case invalidJSON(file: String, detail: String)
    case unsupportedVersion(file: String, version: Int)
    public var errorDescription: String?
public enum ContentDecoder
    public static let supportedSchemaVersion
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data, file: String = "") throws -> T
    public static func topicFile(from data: Data) throws -> TopicFile
    public static func topicIndex(from data: Data) throws -> TopicIndex
    public static func dictionaryIndex(from data: Data) throws -> DictionaryIndex
    public static func grammarLevel(from data: Data) throws -> GrammarLevelFile
    public static func exercises(from data: Data) throws -> ProductionBank
    public static func idioms(from data: Data) throws -> IdiomBank
    public static func readings(from data: Data) throws -> ReadingBank
    public static func starterWords(from data: Data) throws -> StarterWords
    public static func recommendations(from data: Data) throws -> RecommendationBank
    public static func answerVariants(from data: Data) throws -> AnswerVariants

// Content/ContentSearch.swift
public enum SearchMatchKind: Int, Sendable, Hashable, Comparable
    case exact = 0
    case prefix = 1
    case wordPrefix = 2
    case polish = 3
    case fuzzy = 4
    public static func < (lhs: SearchMatchKind, rhs: SearchMatchKind) -> Bool
public struct SearchHit: Sendable, Hashable
    public var entry: DictionaryIndex.Entry
    public var match: SearchMatchKind
    public var distance: Int
    public init(entry: DictionaryIndex.Entry, match: SearchMatchKind, distance: Int = 0)
public struct ContentSearch: Sendable
    public init(index: DictionaryIndex)
    public init(entries: [DictionaryIndex.Entry])
    public var count: Int
    public func search(_ query: String, limit: Int = 30) -> [SearchHit]
    public func meanings(of term: String) -> [DictionaryIndex.Entry]

// Content/TopicContent.swift
public struct TopicEntry: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var term: String
    public var ipa: String
    public var pos: String
    public var level: String
    public var frequency: SpokenFrequency?
    public var translation: String
    public var definition: String
    public var register: String
    public var contextPl: String
    public var natural: String
    public var forms: String
    public var collocations: String
    public var synonyms: String
    public var antonyms: String
    public var notePl: String
    public var examples: [ExamplePair]
    public var acceptedAnswers: [String]
    public var acceptedTranslations: [String]
    public init(id: String, term: String, ipa: String = "", pos: String = "", level: String = "", frequency: SpokenFrequency? = nil, translation: String, definition: String = "", register: String = "neutralny", contextPl: String = "", natural: String = "", forms: String = "", collocations: String = "", synonyms: String = "", antonyms: String = "", notePl: String = "", examples: [ExamplePair] = [], acceptedAnswers: [String] = [], acceptedTranslations: [String] = [])
public struct TopicCategory: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var namePl: String
    public var scenePl: String
    public var entries: [TopicEntry]
    public init(id: String, namePl: String, scenePl: String = "", entries: [TopicEntry] = [])
public struct TopicFile: Codable, Sendable, Hashable, Identifiable
    public var schemaVersion: Int
    public var id: String
    public var namePl: String
    public var nameEn: String
    public var group: String
    public var symbol: String
    public var summaryPl: String
    public var aliases: [String]
    public var categories: [TopicCategory]
    public init(schemaVersion: Int = 1, id: String, namePl: String, nameEn: String = "", group: String = "", symbol: String = "", summaryPl: String = "", aliases: [String] = [], categories: [TopicCategory] = [])
    public var allEntries: [TopicEntry]
    public var entryCount: Int
    public func entry(id entryID: String) -> (entry: TopicEntry, category: TopicCategory)?
public struct TopicGroup: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var namePl: String
    public var symbol: String
    public init(id: String, namePl: String, symbol: String)
public struct TopicCategorySummary: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var namePl: String
    public var entryCount: Int
    public init(id: String, namePl: String, entryCount: Int)
public struct TopicSummary: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var namePl: String
    public var nameEn: String
    public var group: String
    public var symbol: String
    public var summaryPl: String
    public var aliases: [String]
    public var entryCount: Int
    public var levels: [String: Int]
    public var categories: [TopicCategorySummary]
    public init(id: String, namePl: String, nameEn: String = "", group: String = "", symbol: String = "", summaryPl: String = "", aliases: [String] = [], entryCount: Int = 0, levels: [String: Int] = [:], categories: [TopicCategorySummary] = [])
    public func matches(_ query: String) -> Bool
public struct TopicIndex: Codable, Sendable, Hashable
    public var schemaVersion: Int
    public var generatedAt: String
    public var groups: [TopicGroup]
    public var topics: [TopicSummary]
    public init(schemaVersion: Int = 1, generatedAt: String = "", groups: [TopicGroup] = [], topics: [TopicSummary] = [])
    public func topics(inGroup groupID: String) -> [TopicSummary]
public struct ContentReference: Sendable, Hashable
    public var file: String
    public var entryID: String
    public init(file: String, entryID: String)
    public init?(_ raw: String)
    public var isStarter: Bool
    public var rawValue: String

// Content/VocabularyMerger.swift
public struct MergeResult: Sendable, Hashable
    public var state: LearnerState
    public var addedMeaningIDs: [String]
    public var skippedExisting: Int
    public init(state: LearnerState, addedMeaningIDs: [String], skippedExisting: Int)
public enum VocabularyMerger
    public static let defaultCollection
    public static func resolveExistingCollection(_ collections: [String], suggested: String, topic: String? = nil) -> String?
    public static func mergeSuggestions(_ state: LearnerState, lookup: Lookup, indices: [Int], collectionOverride: String? = nil, now: Timestamp, makeID: () -> String =
    public static func suggestion(from entry: TopicEntry, topicName: String, categoryName: String? = nil, scene: String? = nil, reference: String? = nil) -> SenseSuggestion
    public static func lookup(term: String, entries: [(entry: TopicEntry, suggestion: SenseSuggestion)]) -> Lookup
    public static func addTopicEntries(_ state: LearnerState, topic: TopicFile, entryIDs: [String]? = nil, collectionOverride: String? = nil, now: Timestamp, makeID: () -> String =
    public static func starterWords(_ entries: [TopicEntry]) -> [Word]
    public static func addedContentReferences(_ state: LearnerState) -> Set<String>

// FluentKit.swift
public enum FluentKitInfo
    public static let version
    public static let webCompatibility

// Grading/Cloze.swift
public struct ClozeSpan: Sendable, Hashable
    public var range: Range<String.Index>
    public var match: String
    public var characterOffset: Int
public enum Cloze
    public static let gap
    public static func span(in text: String, focus: String) -> ClozeSpan?
    public static func text(_ text: String, focus: String) -> String?

// Grading/ExerciseAudio.swift
public enum ExerciseAudio
    public static let speechGap
    public static func exerciseAudioText(context: String, solved: Bool, correctAnswer: String) -> String
    public static func vocabularyAudioText(example: String, focus: String, hidden: Bool) -> String
public struct ReadingToken: Sendable, Hashable
    public var text: String
    public var wordId: String?
    public init(text: String, wordId: String? = nil)
public enum ReadingTokenizer
    public static func tokens(text: String, words: [Word]) -> [ReadingToken]

// Grading/PolishAnswerIndex.swift
public struct PolishAnswerIndex: Sendable, Hashable
    public init(_ variants: AnswerVariants = .builtIn)
    public static func baseKeys(translation: String, saved: [String] = []) -> Set<String>
    public func keys(term: String, translation: String, saved: [String] = []) -> Set<String>

// Grading/ProductionGrader.swift
public struct PracticeInputResult: Sendable, Hashable
    public var correct: Bool
    public var choice: Int
    public init(correct: Bool, choice: Int)
public enum ProductionGrader
    public static func normalize(_ value: String, item: ProductionItem) -> String
    public static func grade(_ answer: String, item: ProductionItem) -> ProductionResult
    public static func checkPracticeInput(_ item: PracticeQuestion, value: String, variants: AnswerVariants = .builtIn) -> PracticeInputResult

// Grading/TextNormalizer.swift
public enum TextNormalizer
    public static func normalize(_ value: String) -> String
    public static func withoutDialectLabel(_ text: String) -> String
    public static func answerKey(_ text: String) -> String
    public static func englishAnswerKey(_ value: String) -> String
    public static func searchKey(_ text: String) -> String
    public static func levenshtein(_ left: String, _ right: String) -> Int

// Grading/VocabularyGrader.swift
public enum VocabularyGrader
    public static func polishAnswers(term: String, translation: String, saved: [String] = [], variants: AnswerVariants = .builtIn) -> [String]
    public static func polishAnswerKeys(term: String, translation: String, saved: [String] = [], index: PolishAnswerIndex) -> Set<String>
    public static func vocabularyAnswers(word: Word, meaning: Meaning, type: ExerciseType, variants: AnswerVariants = .builtIn) -> [String]
    public static func gradingWord(word: Word, meaning: Meaning, task: VocabTask) -> Word
    public static func localGrade(answer: String, word: Word, meaning: Meaning, type: ExerciseType, variants: AnswerVariants = .builtIn) -> Grade
    public static func examplePair(word: Word, meaning: Meaning, index: Int) -> ExamplePair?

// ImportExport/DelimitedImport.swift
public struct DelimitedImportResult: Sendable, Hashable
    public var state: LearnerState
    public var addedWords: Int
    public var addedMeanings: Int
    public var skippedExisting: Int
    public init(state: LearnerState, addedWords: Int, addedMeanings: Int, skippedExisting: Int)
public enum DelimitedImport
    public static let maxRows
    public static let maxCharacters
    public static func parse(_ text: String) throws -> [[String]]
    public static func importRows(_ text: String, into state: LearnerState, now: Timestamp, makeID: () -> String =
public enum StateExporter
    public static func exportJSON(_ state: LearnerState, pretty: Bool = true) throws -> Data
    public static func exportReviewsJSON(_ state: LearnerState) throws -> Data
    public static func ankiCSV(_ state: LearnerState) -> String

// ImportExport/StateImporter.swift
public enum ImportError: Error, LocalizedError, Sendable, Equatable
    case empty
    case tooLarge(maxMegabytes: Int)
    case notJSON
    case notFluentExport
    case unsupportedVersion(Int)
    case invalidData(String)
    case duplicateMeaningID(String)
    case tooManyWords(max: Int)
    case emptyWord(row: Int)
    case unclosedQuote
    case tooManyRows(max: Int)
    case missingFields(row: Int)
    case encodingFailed
    public var errorDescription: String?
public enum StateImporter
    public static let defaultMaxBytes
    public static let maxWords
    public static func importJSON(_ data: Data, maxBytes: Int = defaultMaxBytes) throws -> LearnerState
public enum StateValidator
    public static func validate(_ state: LearnerState, maxWords: Int = StateImporter.maxWords) throws
    public static func isValid(_ state: LearnerState) -> Bool

// ImportExport/StateMigration.swift
public enum StateMigration
    public static func migrate(_ input: LearnerState) -> LearnerState

// Models/Combined.swift
public struct CombinedQuestionTask: Codable, Sendable, Hashable
    public var mode: StudyMode
    public var question: PracticeQuestion
    public var level: String
    public var reading: Reading?
    public var readingIndex: Int?
    public var production: ProductionItem?
    public init(mode: StudyMode, question: PracticeQuestion, level: String, reading: Reading? = nil, readingIndex: Int? = nil, production: ProductionItem? = nil)
public enum CombinedTask: Codable, Sendable, Hashable
    case vocabulary(mode: StudyMode, task: VocabTask)
    case question(CombinedQuestionTask)
    public var mode: StudyMode
    public var vocabularyTask: VocabTask?
    public var questionTask: CombinedQuestionTask?
public struct CombinedAnswer: Codable, Sendable, Hashable
    public var value: String
    public var correct: Bool
    public var seconds: Double
    public var hinted: Bool
    public var spellingCorrect: Bool
    public var explanation: String
    public init(value: String, correct: Bool, seconds: Double, hinted: Bool = false, spellingCorrect: Bool = true, explanation: String = "")
public struct CombinedSession: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var modes: [StudyMode]
    public var random: Bool
    public var minutes: Int
    public var tasks: [CombinedTask]
    public var answers: [CombinedAnswer?]
    public var index: Int
    public var updatedAt: Timestamp
    public var completedAt: Timestamp?
    public init(id: String, modes: [StudyMode], random: Bool, minutes: Int, tasks: [CombinedTask], answers: [CombinedAnswer?]? = nil, index: Int = 0, updatedAt: Timestamp, completedAt: Timestamp? = nil)
    public var currentTask: CombinedTask?
    public var currentAnswer: CombinedAnswer?
    public var answeredCount: Int
    public var correctCount: Int

// Models/Enums.swift
public enum Skill: String, Codable, CaseIterable, Sendable, Hashable
    case recognition
    case recall
    case spelling
    case listening
    case usage
    case pronunciation
    public var namePl: String
    public static let masterySkills: [Skill]
public enum ExerciseType: Int, Codable, CaseIterable, Sendable, Hashable
    case flashcard = 0
    case recall = 1
    case cloze = 2
    case meaning = 3
    case dictation = 4
    public var namePl: String
    public var shortNamePl: String
    public var skill: Skill
    public var estimatedSeconds: Int
    public var slowSeconds: Double
    public var retryType: ExerciseType
    public var promptAudioAllowed: Bool
    public var scoresSpelling: Bool
public enum CEFR
    public static let levels: [String]
    public static func index(of level: String) -> Int?
    public static func isValid(_ level: String) -> Bool
    public static func next(after level: String) -> String
public enum LevelConfidence: String, Codable, CaseIterable, Sendable, Hashable
    case high
    case medium
    case low
public enum SpokenFrequency: String, Codable, CaseIterable, Sendable, Hashable
    case veryCommon = "very_common"
    case common
    case lessCommon = "less_common"
    case rare
    public var namePl: String
    public var rank: Int
public enum ContentSource: String, Codable, CaseIterable, Sendable, Hashable
    case ai
    case starter
public enum ReviewSource: String, Codable, CaseIterable, Sendable, Hashable
    case exercise
    case reading
public enum PracticeKind: String, Codable, CaseIterable, Sendable, Hashable
    case grammar
    case idioms
    case mixed
    public var namePl: String
public enum StudyMode: String, Codable, CaseIterable, Sendable, Hashable
    case mixed
    case mistakes
    case pairs
    case reading
    case grammar
    case idioms
    case production
    case languageMix = "language-mix"
    public var namePl: String
    public var isVocabulary: Bool
public enum WordStatus: String, Codable, CaseIterable, Sendable, Hashable
    case new = "Nowe"
    case learning = "Uczę się"
    case hard = "Trudne"
    case mastered = "Opanowane"
    case needsRefresh = "Do odświeżenia"
    case archived = "Archiwum"
    public var namePl: String

// Models/LearnerSettings.swift
public struct LearnerSettings: Codable, Sendable, Hashable
    public var goal: Int
    public var reminder: String
    public var accent: String
    public var slow: Bool
    public var voice: String?
    public var voiceRevision: Int?
    public static let goalRange: ClosedRange<Int>
    public static let defaultReminder
    public static let supportedAccents
    public init(goal: Int = 20, reminder: String = LearnerSettings.defaultReminder, accent: String = "en-US", slow: Bool = false, voice: String? = nil, voiceRevision: Int? = 2)
    public static func isValidReminder(_ value: String) -> Bool
    public var reminderComponents: (hour: Int, minute: Int)

// Models/LearnerState.swift
public struct ReadingHistoryEntry: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var at: Timestamp
    public var level: String
    public var correct: Int
    public var total: Int
    public var title: String?
    public init(id: String, at: Timestamp, level: String, correct: Int, total: Int, title: String? = nil)
public struct PracticeHistoryEntry: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var at: Timestamp
    public var kind: PracticeKind
    public var level: String
    public var correct: Int
    public var total: Int
    public var title: String
    public init(id: String, at: Timestamp, kind: PracticeKind, level: String, correct: Int, total: Int, title: String)
public struct ProductionHistoryEntry: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var at: Timestamp
    public var level: String
    public var correct: Int
    public var total: Int
    public var title: String
    public init(id: String, at: Timestamp, level: String, correct: Int, total: Int, title: String)
public struct LearnerState: Codable, Sendable, Hashable
    public var combined: CombinedSession?
    public var grammarSeen: [String: Double]
    public var words: [Word]
    public var collections: [String]
    public var reviews: [Review]
    public var reviewSummaries: [ReviewSummary]
    public var settings: LearnerSettings
    public var session: VocabSession?
    public var reading: ReadingSession?
    public var readingHistory: [ReadingHistoryEntry]
    public var practice: PracticeSession?
    public var production: ProductionSession?
    public var productionHistory: [ProductionHistoryEntry]
    public var practiceHistory: [PracticeHistoryEntry]
    public var demo: Bool
    public init(combined: CombinedSession? = nil, grammarSeen: [String: Double] = [:], words: [Word] = [], collections: [String] = [], reviews: [Review] = [], reviewSummaries: [ReviewSummary] = [], settings: LearnerSettings = LearnerSettings(), session: VocabSession? = nil, reading: ReadingSession? = nil, readingHistory: [ReadingHistoryEntry] = [], practice: PracticeSession? = nil, production: ProductionSession? = nil, productionHistory: [ProductionHistoryEntry] = [], practiceHistory: [PracticeHistoryEntry] = [], demo: Bool = false)
    public static let empty
    public func word(id: String) -> Word?
    public func wordAndMeaning(meaningID: String) -> (word: Word, meaning: Meaning)?
    public func wordIndex(id: String) -> Int?

// Models/Meaning.swift
public enum EnrichmentPhase: String, Codable, CaseIterable, Sendable, Hashable
    case details
    case examples
    case ready
public enum ExampleGroup: String, Codable, CaseIterable, Sendable, Hashable
    case affirmative
    case negative
    case question
public struct Enrichment: Codable, Sendable, Hashable
    public var round: Int?
    public var phase: EnrichmentPhase
    public var detailsPending: Bool?
    public var groups: [ExampleGroup]
    public var attempts: Int
    public var retryAt: Timestamp
    public var error: String?
    public init(round: Int? = nil, phase: EnrichmentPhase = .examples, detailsPending: Bool? = nil, groups: [ExampleGroup] = [], attempts: Int = 0, retryAt: Timestamp = 0, error: String? = nil)
public struct Meaning: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var topic: String?
    public var scene: String?
    public var usedExamples: [Int]?
    public var enrichment: Enrichment?
    public var exampleTranslations: [String]?
    public var exampleFocusEn: [String]?
    public var exampleFocusPl: [String]?
    public var acceptedAnswers: [String]?
    public var acceptedTranslations: [String]?
    public var level: String?
    public var levelConfidence: LevelConfidence?
    public var levelReason: String?
    public var spokenFrequency: SpokenFrequency?
    public var pos: String?
    public var translation: String
    public var definition: String
    public var examples: [String]
    public var context: String
    public var register: String
    public var natural: String
    public var scores: SkillScores
    public var contentRef: String?
    public init(id: String, topic: String? = nil, scene: String? = nil, usedExamples: [Int]? = nil, enrichment: Enrichment? = nil, exampleTranslations: [String]? = nil, exampleFocusEn: [String]? = nil, exampleFocusPl: [String]? = nil, acceptedAnswers: [String]? = nil, acceptedTranslations: [String]? = nil, level: String? = nil, levelConfidence: LevelConfidence? = nil, levelReason: String? = nil, spokenFrequency: SpokenFrequency? = nil, pos: String? = nil, translation: String, definition: String = "", examples: [String] = [], context: String = "", register: String = "neutralny", natural: String = "", scores: SkillScores = SkillScores(), contentRef: String? = nil)
    public func effectiveLevel(in word: Word) -> String
    public func effectivePos(in word: Word) -> String

// Models/Practice.swift
public enum PracticeCategory: String, Codable, CaseIterable, Sendable, Hashable
    case grammar
    case idiom
public enum PracticeFormat: String, Codable, CaseIterable, Sendable, Hashable
    case choice
    case input
public struct PracticeQuestion: Codable, Sendable, Hashable
    public var format: PracticeFormat?
    public var inputHint: String?
    public var acceptedAnswers: [String]?
    public var bankId: String?
    public var scenarioId: String?
    public var category: PracticeCategory
    public var prompt: String
    public var context: String
    public var options: [String]
    public var answer: Int
    public var explanation: String
    public var translation: String
    public init(format: PracticeFormat? = nil, inputHint: String? = nil, acceptedAnswers: [String]? = nil, bankId: String? = nil, scenarioId: String? = nil, category: PracticeCategory, prompt: String, context: String, options: [String], answer: Int, explanation: String = "", translation: String = "")
    public var isInput: Bool
    public var correctOption: String
public struct PracticeSet: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var title: String
    public var level: String
    public var kind: PracticeKind
    public var items: [PracticeQuestion]
    public var source: ContentSource
    public init(id: String, title: String, level: String, kind: PracticeKind, items: [PracticeQuestion], source: ContentSource = .starter)
public struct PracticeSession: Codable, Sendable, Hashable
    public var set: PracticeSet
    public var writtenAnswers: [String]?
    public var answers: [Int]
    public var index: Int
    public var completedAt: Timestamp?
    public init(set: PracticeSet, writtenAnswers: [String]? = nil, answers: [Int]? = nil, index: Int = 0, completedAt: Timestamp? = nil)

// Models/Production.swift
public enum ProductionDiagnosis: String, Codable, CaseIterable, Sendable, Hashable
    case wrongTense = "wrong_tense"
    case wrongAspect = "wrong_aspect"
    case wrongVoice = "wrong_voice"
    case wrongAgreement = "wrong_agreement"
    case wrongWord = "wrong_word"
public struct ProductionDistractor: Codable, Sendable, Hashable
    public var form: String
    public var diagnosis: ProductionDiagnosis
    public var explanation: String
    public init(form: String, diagnosis: ProductionDiagnosis, explanation: String)
public struct ProductionItem: Codable, Sendable, Hashable
    public var bankId: String?
    public var scenarioId: String?
    public var context: String
    public var hintPl: String
    public var answer: String
    public var acceptedAnswers: [String]
    public var distractors: [ProductionDistractor]
    public var rule: String
    public var explanation: String
    public var translation: String
    public init(bankId: String? = nil, scenarioId: String? = nil, context: String, hintPl: String = "", answer: String, acceptedAnswers: [String] = [], distractors: [ProductionDistractor] = [], rule: String, explanation: String = "", translation: String = "")
public struct ProductionSet: Codable, Sendable, Hashable
    public var title: String
    public var level: String
    public var items: [ProductionItem]
    public init(title: String, level: String, items: [ProductionItem])
public enum ProductionResultDiagnosis: String, Codable, CaseIterable, Sendable, Hashable
    case wrongTense = "wrong_tense"
    case wrongAspect = "wrong_aspect"
    case wrongVoice = "wrong_voice"
    case wrongAgreement = "wrong_agreement"
    case wrongWord = "wrong_word"
    case spelling
    case general
    public init(_ diagnosis: ProductionDiagnosis)
    public var namePl: String
public struct ProductionResult: Codable, Sendable, Hashable
    public var correct: Bool
    public var spellingCorrect: Bool
    public var diagnosis: ProductionResultDiagnosis?
    public var explanation: String
    public init(correct: Bool, spellingCorrect: Bool, diagnosis: ProductionResultDiagnosis?, explanation: String)
public struct ProductionSession: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var set: ProductionSet
    public var source: ContentSource
    public var index: Int
    public var answers: [String]
    public var results: [ProductionResult?]
    public var completedAt: Timestamp?
    public init(id: String, set: ProductionSet, source: ContentSource = .starter, index: Int = 0, answers: [String]? = nil, results: [ProductionResult?]? = nil, completedAt: Timestamp? = nil)

// Models/Reading.swift
public struct ReadingQuestion: Codable, Sendable, Hashable
    public var question: String
    public var options: [String]
    public var answer: Int
    public var explanation: String
    public var evidence: String
    public var meaningId: String?
    public init(question: String, options: [String], answer: Int, explanation: String = "", evidence: String = "", meaningId: String? = nil)
    public var correctOption: String
public struct Reading: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var title: String
    public var level: String
    public var paragraphs: [String]
    public var questions: [ReadingQuestion]
    public var source: ContentSource
    public var topic: String?
    public init(id: String, title: String, level: String, paragraphs: [String], questions: [ReadingQuestion], source: ContentSource = .starter, topic: String? = nil)
public struct ReadingSession: Codable, Sendable, Hashable
    public var reading: Reading
    public var answers: [Int]
    public var submitted: Bool
    public var completedAt: Timestamp?
    public init(reading: Reading, answers: [Int]? = nil, submitted: Bool = false, completedAt: Timestamp? = nil)
    public var correctCount: Int

// Models/Review.swift
public struct Review: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var wordId: String
    public var meaningId: String
    public var skill: Skill
    public var correct: Bool
    public var at: Timestamp
    public var seconds: Double
    public var confidence: Int
    public var hint: Bool
    public var error: String
    public var before: Int
    public var after: Int
    public var masteryVersion: Int?
    public var weight: Double
    public var source: ReviewSource
    public var demo: Bool
    public init(id: String, wordId: String, meaningId: String, skill: Skill, correct: Bool, at: Timestamp, seconds: Double, confidence: Int, hint: Bool, error: String = "", before: Int, after: Int, masteryVersion: Int? = 2, weight: Double = 1, source: ReviewSource = .exercise, demo: Bool = false)
public struct ReviewSummary: Codable, Sendable, Hashable
    public var day: String
    public var count: Int
    public var correct: Int
    public init(day: String, count: Int, correct: Int)

// Models/Score.swift
public struct Score: Codable, Sendable, Hashable
    public var value: Int
    public var interval: Double
    public var due: Timestamp
    public var correct: Int
    public var wrong: Int
    public var hinted: Int
    public var last: Timestamp
    public var slow: Int
    public init(value: Int = 0, interval: Double = 0, due: Timestamp = 0, correct: Int = 0, wrong: Int = 0, hinted: Int = 0, last: Timestamp = 0, slow: Int = 0)
    public static let empty
public struct SkillScores: Codable, Sendable, Hashable
    public init(_ scores: [Skill: Score] = [:])
    public subscript(skill: Skill) -> Score?
    public var isEmpty: Bool
    public var count: Int
    public var skills: [Skill]
    public var values: [Score]
    public var entries: [(skill: Skill, score: Score)]
    public var dictionary: [Skill: Score]

// Models/TutorTypes.swift
public struct ExamplePair: Codable, Sendable, Hashable
    public var en: String
    public var pl: String
    public var focusEn: String
    public var focusPl: String
    public init(en: String, pl: String, focusEn: String, focusPl: String)
public struct SenseSuggestion: Codable, Sendable, Hashable
    public var needsDetails: Bool?
    public var topic: String?
    public var scene: String?
    public var translation: String
    public var definition: String
    public var pos: String
    public var level: String
    public var levelConfidence: LevelConfidence?
    public var levelReason: String?
    public var spokenFrequency: SpokenFrequency?
    public var context: String
    public var register: String
    public var natural: String
    public var collection: String
    public var examples: [ExamplePair]
    public var acceptedTranslations: [String]?
    public var acceptedAnswers: [String]
    public var contentRef: String?
    public init(needsDetails: Bool? = nil, topic: String? = nil, scene: String? = nil, translation: String, definition: String = "", pos: String = "", level: String = "", levelConfidence: LevelConfidence? = nil, levelReason: String? = nil, spokenFrequency: SpokenFrequency? = nil, context: String = "", register: String = "neutralny", natural: String = "", collection: String = "", examples: [ExamplePair] = [], acceptedTranslations: [String]? = nil, acceptedAnswers: [String] = [], contentRef: String? = nil)
public struct Lookup: Codable, Sendable, Hashable
    public var exists: Bool
    public var term: String
    public var ipa: String
    public var forms: String
    public var collocations: String
    public var synonyms: String
    public var antonyms: String
    public var note: String
    public var alternatives: [String]
    public var meanings: [SenseSuggestion]
    public var source: ContentSource
    public init(exists: Bool = true, term: String, ipa: String = "", forms: String = "", collocations: String = "", synonyms: String = "", antonyms: String = "", note: String = "", alternatives: [String] = [], meanings: [SenseSuggestion] = [], source: ContentSource = .starter)
public enum GradeVerdict: String, Codable, CaseIterable, Sendable, Hashable
    case correct
    case incorrect
    case uncertain
public enum GradeSource: String, Codable, CaseIterable, Sendable, Hashable
    case ai
    case local
public struct Grade: Codable, Sendable, Hashable
    public var verdict: GradeVerdict
    public var explanation: String
    public var spellingCorrect: Bool
    public var source: GradeSource
    public var closestAnswer: String?
    public init(verdict: GradeVerdict, explanation: String, spellingCorrect: Bool, source: GradeSource = .local, closestAnswer: String? = nil)
    public var isFailure: Bool
    public var isCorrect: Bool
public struct Recommendation: Codable, Sendable, Hashable
    public var known: String
    public var term: String
    public var level: String
    public var translation: String
    public var difference: String
    public var example: String
    public var examplePl: String
    public var ipa: String?
    public var focusPl: String?
    public init(known: String, term: String, level: String, translation: String, difference: String, example: String, examplePl: String, ipa: String? = nil, focusPl: String? = nil)

// Models/VocabSession.swift
public struct VocabTask: Codable, Sendable, Hashable
    public var wordId: String
    public var meaningId: String
    public var type: ExerciseType
    public var example: Int
    public init(wordId: String, meaningId: String, type: ExerciseType, example: Int)
public struct VocabSession: Codable, Sendable, Hashable
    public var tasks: [VocabTask]
    public var index: Int
    public var correct: Int
    public var minutes: Int
    public var mode: String
    public init(tasks: [VocabTask], index: Int = 0, correct: Int = 0, minutes: Int, mode: String)
    public var currentTask: VocabTask?
    public var isFinished: Bool
    public var studyMode: StudyMode

// Models/Word.swift
public struct Word: Codable, Sendable, Hashable, Identifiable
    public var id: String
    public var en: String
    public var ipa: String
    public var pos: String
    public var level: String
    public var collection: String
    public var tags: [String]
    public var source: String
    public var note: String
    public var forms: String
    public var collocations: String
    public var synonyms: String
    public var antonyms: String
    public var important: Bool
    public var hard: Bool
    public var archived: Bool
    public var created: Timestamp
    public var updatedAt: Timestamp?
    public var meanings: [Meaning]
    public init(id: String, en: String, ipa: String = "", pos: String = "", level: String = "", collection: String, tags: [String] = [], source: String = "", note: String = "", forms: String = "", collocations: String = "", synonyms: String = "", antonyms: String = "", important: Bool = false, hard: Bool = false, archived: Bool = false, created: Timestamp, updatedAt: Timestamp? = nil, meanings: [Meaning] = [])
    public func meaning(id meaningID: String) -> Meaning?

// Scheduling/ExamplePool.swift
public enum ExamplePool
    public static let batchSize
    public static let limit
    public static let refillRemaining
    public static func availableCount(_ meaning: Meaning) -> Int
    public static func needsExpansion(_ meaning: Meaning) -> Bool
    public static func beginExpansion(_ meaning: Meaning) -> Meaning
    public static func nextUnusedExample(_ meaning: Meaning, fallback: Int = 0) -> Int
    public var availableExampleCount: Int

// Scheduling/Mastery.swift
public enum Mastery
    public static let masteredThreshold
    public static let hardValueThreshold
    public static let hardWrongCount
    public static func fromInterval(_ interval: Double) -> Int
    public static func of(_ meaning: Meaning) -> Int
    public static func of(_ word: Word) -> Int
    public static func due(_ meaning: Meaning) -> Timestamp
    public static func isNew(_ meaning: Meaning) -> Bool
    public static func status(of word: Word, now: Timestamp) -> WordStatus
    public static func isHardByScores(_ word: Word) -> Bool
    public var mastery: Int
    public var due: Timestamp
    public var isNew: Bool
    public var mastery: Int
    public func status(now: Timestamp) -> WordStatus

// Scheduling/Scheduler.swift
public enum Scheduler
    public static let readingWeight
    public static let maxSessionTasks
    public static func schedule(_ old: Score?, correct: Bool, seconds: Double, confidence: Int, hint: Bool, now: Timestamp, type: ExerciseType = .recall, weight: Double = 1) -> Score
    public static func recordAnswer(_ state: LearnerState, task: VocabTask, correct: Bool, seconds: Double, confidence: Int, hint: Bool, spellingCorrect: Bool? = nil, weight: Double = 1, source: ReviewSource = .exercise, now: Timestamp, reviewID: String = UUID().uuidString.lowercased()) -> LearnerState
    public static func applyReadingResults(_ state: LearnerState, reading: ReadingSession, now: Timestamp, makeID: () -> String =

// Sessions/CombinedSessionBuilder.swift
public enum CombinedSessionBuilder
    public static let tasksPerFiveMinutes
    public static func orderTasks<G: RandomNumberGenerator>(_ tasks: [CombinedTask], random: Bool, using rng: inout G) -> [CombinedTask]
    public static func makeSession<G: RandomNumberGenerator>(state: LearnerState, modes: [StudyMode], minutes: Int, random: Bool, content: PracticeContent, now: Timestamp, id: String = UUID().uuidString.lowercased(), using rng: inout G) -> CombinedSession
    public static func saveAnswer(_ state: LearnerState, answer: CombinedAnswer, now: Timestamp, reviewID: String = UUID().uuidString.lowercased()) -> LearnerState
    public static func advance(_ state: LearnerState, now: Timestamp) -> LearnerState

// Sessions/Confusable.swift
public struct WordMeaning: Sendable, Hashable
    public var word: Word
    public var meaning: Meaning
    public init(word: Word, meaning: Meaning)
public enum ConfusableDetector
    public static func confusable(_ a: WordMeaning, _ b: WordMeaning, answerIndex: PolishAnswerIndex = PolishAnswerIndex()) -> Bool
    public static func itemsWithPartners(_ items: [WordMeaning], answerIndex: PolishAnswerIndex = PolishAnswerIndex()) -> [WordMeaning]

// Sessions/GrammarSelection.swift
public enum GrammarSelector
    public static func taskID(bankId: String?, context: String) -> String
    public static func taskID(_ item: ProductionItem) -> String
    public static func taskID(_ question: PracticeQuestion) -> String
    public static func selectItems(_ pool: [ProductionItem], count: Int, seen: [String: Double] = [:], variant: Int = 0) -> [ProductionItem]
    public static func markSeen(_ state: LearnerState, bankId: String?, context: String, at: Timestamp) -> LearnerState
    public static func selectionSeen(_ state: LearnerState, now: Timestamp) -> [String: Double]

// Sessions/Interleave.swift
public enum TaskInterleaver
    public static func interleave(_ tasks: [VocabTask]) -> [VocabTask]

// Sessions/MeaningOptions.swift
public enum MeaningOptions
    public static func options(state: LearnerState, word: Word, meaning: Meaning, task: VocabTask, starterWords: [Word] = [], answerIndex: PolishAnswerIndex = PolishAnswerIndex()) -> [String]

// Sessions/PracticeBuilder.swift
public struct PracticeContent: Sendable, Hashable
    public var grammar: ProductionBank
    public var exercises: ProductionBank
    public var idioms: IdiomBank
    public var readings: ReadingBank
    public var rules: [String: [String]]
    public init(grammar: ProductionBank = ProductionBank(), exercises: ProductionBank = ProductionBank(), idioms: IdiomBank = IdiomBank(), readings: ReadingBank = ReadingBank(), rules: [String: [String]] = [:])
    public init(grammarFiles: [GrammarLevelFile], exercises: ProductionBank, idioms: IdiomBank, readings: ReadingBank)
    public static let empty
    public static func resolvedLevel(_ level: String) -> String
    public func productionPool(level: String) -> [ProductionItem]
    public func idiomPool(level: String, variant: Int = 0) -> [PracticeQuestion]
public enum PracticeBuilder
    public static func practiceQuestion(from item: ProductionItem) -> PracticeQuestion
    public static func starterPractice(kind: PracticeKind, level: String, variant: Int = 0, seen: [String: Double]? = nil, content: PracticeContent) -> PracticeSet
    public static func starterProduction(level: String, variant: Int = 0, count: Int = 4, seen: [String: Double]? = nil, content: PracticeContent) -> ProductionSet

// Sessions/PracticeFlow.swift
public enum PracticeFlow
    public static func startPractice(_ state: LearnerState, kind: PracticeKind, level: String, content: PracticeContent, now: Timestamp) -> LearnerState
    public static func answerPractice(_ state: LearnerState, choice: Int) -> LearnerState
    public static func answerPracticeWritten(_ state: LearnerState, text: String, variants: AnswerVariants = .builtIn) -> (state: LearnerState, correct: Bool)
    public static func advancePractice(_ state: LearnerState, now: Timestamp) -> LearnerState
    public static func startProduction(_ state: LearnerState, level: String, content: PracticeContent, now: Timestamp, id: String = UUID().uuidString.lowercased()) -> LearnerState
    public static func answerProduction(_ state: LearnerState, text: String) -> LearnerState
    public static func advanceProduction(_ state: LearnerState, now: Timestamp) -> LearnerState
    public static func startReading(_ state: LearnerState, topic: String = "", bank: ReadingBank) -> LearnerState
    public static func submitReading(_ state: LearnerState, now: Timestamp, makeID: () -> String =

// Sessions/ReadingSelection.swift
public struct ReadingMeaningCandidate: Sendable, Hashable
    public var en: String
    public var meaningId: String
    public var translation: String
    public var level: String
    public var topic: String?
    public var scene: String?
    public init(en: String, meaningId: String, translation: String, level: String, topic: String? = nil, scene: String? = nil)
public enum ReadingSelector
    public static func selectBankReading(level: String, history: [ReadingHistoryEntry] = [], topic: String = "", bank: ReadingBank) -> Reading?
    public static func selectReadingMeanings(_ state: LearnerState, targetLevel: String, limit: Int = 20, now: Timestamp) -> [ReadingMeaningCandidate]
public struct LevelEstimate: Sendable, Hashable
    public var level: String
    public var targetLevel: String
    public var count: Int
    public var confidence: LevelConfidence
    public init(level: String, targetLevel: String, count: Int, confidence: LevelConfidence)
public enum LevelEstimator
    public static func estimatedLevel(_ state: LearnerState) -> LevelEstimate
    public static func recommendations(_ state: LearnerState, candidates: [Recommendation]) -> [Recommendation]
    public static func lookup(for recommendation: Recommendation) -> Lookup

// Sessions/SessionBuilder.swift
public enum SessionBuilder
    public static let durations
    public static func allowedTaskTypes(_ meaning: Meaning) -> [ExerciseType]?
    public static func canCloze(word: Word, meaning: Meaning, exampleIndex index: Int) -> Bool
    public static func makeSession<G: RandomNumberGenerator>(state: LearnerState, minutes: Int, mode: StudyMode = .mixed, collection: String? = nil, using rng: inout G) -> VocabSession
    public static func makeSession(state: LearnerState, minutes: Int, mode: StudyMode = .mixed, collection: String? = nil) -> VocabSession

// Statistics/ProgressStatistics.swift
public struct DayActivity: Sendable, Hashable, Identifiable
    public var date: Date
    public var count: Int
    public var correct: Int
    public var id: Date
    public init(date: Date, count: Int, correct: Int)
public struct SkillAverage: Sendable, Hashable, Identifiable
    public var skill: Skill
    public var average: Int?
    public var count: Int
    public var id: Skill
    public init(skill: Skill, average: Int?, count: Int)
public struct LevelProgress: Sendable, Hashable, Identifiable
    public var level: String
    public var wordCount: Int
    public var meaningCount: Int
    public var average: Int
    public var mastered: Int
    public var id: String
    public init(level: String, wordCount: Int, meaningCount: Int, average: Int, mastered: Int)
public struct ForecastDay: Sendable, Hashable, Identifiable
    public var date: Date
    public var count: Int
    public var id: Date
    public init(date: Date, count: Int)
public struct WeeklyGain: Sendable, Hashable, Identifiable
    public var start: Date
    public var count: Int
    public var id: Date
    public init(start: Date, count: Int)
public struct DailyGoalProgress: Sendable, Hashable
    public var done: Int
    public var goal: Int
    public var fraction: Double
    public var isReached: Bool
    public init(done: Int, goal: Int)
public struct StatsOverview: Sendable, Hashable
    public var wordCount: Int
    public var meaningCount: Int
    public var masteredMeanings: Int
    public var dueMeanings: Int
    public var newMeanings: Int
    public var accuracy: Int
    public var totalAnswers: Int
    public var streak: Int
    public var missingLevels: Int
    public init(wordCount: Int, meaningCount: Int, masteredMeanings: Int, dueMeanings: Int, newMeanings: Int, accuracy: Int, totalAnswers: Int, streak: Int, missingLevels: Int)
public struct ExerciseTotals: Sendable, Hashable
    public var sets: Int
    public var correct: Int
    public var total: Int
    public init(sets: Int, correct: Int, total: Int)
public enum ProgressStatistics
    public static func activity(_ state: LearnerState, days: Int, now: Timestamp, calendar: Calendar = .current) -> [DayActivity]
    public static func week(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> [DayActivity]
    public static func activityCalendar(_ state: LearnerState, days: Int = 84, now: Timestamp, calendar: Calendar = .current) -> [DayActivity]
    public static func dailyGoal(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> DailyGoalProgress
    public static func streak(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> Int
    public static func skillAverages(_ state: LearnerState) -> [SkillAverage]
    public static func levelProgress(_ state: LearnerState) -> [LevelProgress]
    public static func reviewForecast(_ state: LearnerState, days: Int = 7, now: Timestamp, calendar: Calendar = .current) -> [ForecastDay]
    public static func masteryGains(_ state: LearnerState, from start: Timestamp, to end: Timestamp) -> Int
    public static func weeklyMasteryGains(_ state: LearnerState, weeks: Int = 1, now: Timestamp) -> [WeeklyGain]
    public static func hardWords(_ state: LearnerState, limit: Int = 5, now: Timestamp) -> [Word]
    public static func overview(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> StatsOverview
    public static func readingTotals(_ state: LearnerState) -> ExerciseTotals
    public static func practiceTotals(_ state: LearnerState) -> ExerciseTotals
    public static func collectionProgress(_ state: LearnerState, collection: String) -> (meanings: Int, average: Int)

// Support/Collections.swift


// Support/DecodingHelpers.swift


// Support/Random.swift
public struct SeededGenerator: RandomNumberGenerator, Sendable, Hashable
    public init(seed: UInt64)
    public init(seed text: String)
    public mutating func next() -> UInt64
    public mutating func nextUnit() -> Double

// Support/TextScanning.swift


// Support/Timestamp.swift
public typealias Timestamp = Double
public enum TimeConstants
    public static let dayMs: Double
    public static let hourMs: Double
public enum FluentClock
    public static func now() -> Timestamp
    public init(timestamp: Timestamp)
    public var timestamp: Timestamp

// Sync/StateSync.swift
public enum StateSync
    public static let reviewRetentionDays: Double
    public static func utcDay(_ timestamp: Timestamp) -> String
    public static func compactReviews(_ state: LearnerState, now: Timestamp) -> LearnerState
    public static func mergeWord(_ local: Word, _ remote: Word) -> Word
    public static func mergeDuplicateWords(_ words: [Word]) -> [Word]
    public static func mergeStates(local: LearnerState, remote: LearnerState) -> LearnerState
```
