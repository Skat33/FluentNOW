import Foundation
import os
import FluentKit

/// Wbudowana treść offline (`Content/` w bundlu): tematy, słownik szybkiego dodawania,
/// gramatyka, idiomy, czytanki, starter, rekomendacje, warianty odpowiedzi.
///
/// Wszystko ładowane leniwie, poza głównym wątkiem, z cache w pamięci. Brakujący lub
/// uszkodzony plik daje czytelny `ContentError` — reszta treści działa dalej.
/// Indeks wyszukiwania budowany jest raz, w tle (`warmUp()` po pierwszej klatce UI).
actor ContentLibrary {
    private let root: URL?

    private var topicIndexCache: TopicIndex?
    private var topicCache: [String: TopicFile] = [:]
    private var starterCache: StarterWords?
    private var starterWordsCache: [Word]?
    private var variantsCache: AnswerVariants?
    private var polishIndexCache: PolishAnswerIndex?
    private var recommendationsCache: [Recommendation]?
    private var grammarCache: [String: GrammarLevelFile] = [:]
    private var exercisesCache: ProductionBank?
    private var idiomsCache: IdiomBank?
    private var readingsCache: ReadingBank?
    private var practiceCache: [String: PracticeContent] = [:]
    /// Identyfikatory plików `core/core-cNN.json` (słownik rdzeniowy).
    private var coreIDsCache: [String]?
    /// Trwające dekodowania shardów core (~0,8 MB każdy) — poza aktorem, bez dublowania pracy.
    private var coreLoads: [String: Task<TopicFile, Error>] = [:]
    /// Rekordy słownika rdzeniowego z `dictionary-index.json`.
    private var coreDictionaryCache: [DictionaryIndex.Entry]?

    private var searchIndex: ContentSearch?
    private var searchBuild: Task<[DictionaryIndex.Entry]?, Never>?
    private var searchBuildFailed = false
    /// Rekordy `dictionary-index.json` (baza do przebudowy indeksu po zapisaniu tematu AI).
    private var baseDictionary: [DictionaryIndex.Entry]?

    // Wyszukiwanie tematów i lokalna pamięć tematów (F1)
    private let localStore: LocalTopicStore?
    private var generatedCache: [String: GeneratedTopicRecord]?
    private var aliasCache: TopicAliasBook?
    private var baseTopicDocuments: [TopicSearchDocument]?
    private var baseTopicDocumentsBuild: Task<[TopicSearchDocument], Never>?
    private var catalogCache: TopicSearchCatalog?

    private static let log = Logger(subsystem: "pl.fluentnow.app", category: "ContentLibrary")

    /// Treść z bundla aplikacji (`Content/` jako referencja folderowa).
    /// - Parameter localTopics: pamięć tematów AI i zapytań (`nil` = tylko w pamięci, np. podgląd).
    init(bundle: Bundle = .main, localTopics: LocalTopicStore? = nil) {
        root = bundle.url(forResource: "Content", withExtension: nil)
        localStore = localTopics
    }

    /// Treść z dowolnego katalogu (testy). `nil` = brak treści (podgląd bez bundla).
    init(rootURL: URL?, localTopics: LocalTopicStore? = nil) {
        root = rootURL
        localStore = localTopics
    }

    /// Czy katalog treści istnieje.
    var isAvailable: Bool { root != nil }

    // MARK: - Tematy

    func topicIndex() async throws -> TopicIndex {
        if let topicIndexCache { return topicIndexCache }
        let data = try read("topics/index.json")
        let index = try ContentDecoder.topicIndex(from: data)
        topicIndexCache = index
        return index
    }

    /// Plik tematu `topics/<id>.json` albo — dla `core-cNN` — plik słownika rdzeniowego
    /// `core/<id>.json` (ten sam format `TopicFile`, CONTENT-SCHEMA §6).
    func topic(id: String) async throws -> TopicFile {
        if let generated = loadGenerated()[id] { return generated.topic }
        if let cached = topicCache[id] { return cached }
        if CoreVocabulary.isCoreFile(id) {
            return try await coreFile(id: id)
        }
        let path = "topics/\(id).json"
        guard Self.isSafeFileName(id) else { throw ContentError.unreadable(file: path) }
        let data = try read(path)
        let topic = try ContentDecoder.topicFile(from: data)
        topicCache[id] = topic
        return topic
    }

    /// Shardy słownika rdzeniowego (`core-cNN`) — dekodowane **równolegle** i poza aktorem
    /// (inne zapytania do treści nie czekają), potem w cache. Pomija pliki, których nie da się
    /// wczytać; kolejność jak w `ids`.
    func coreFiles(ids: [String]) async -> [TopicFile] {
        var pending: [(id: String, task: Task<TopicFile, Error>)] = []
        for id in ids where CoreVocabulary.isCoreFile(id) && topicCache[id] == nil {
            if let task = coreLoadTask(id: id) {
                pending.append((id: id, task: task))
            }
        }
        for item in pending {
            do {
                let file = try await item.task.value
                finishCoreLoad(id: item.id, file: file)
            } catch {
                coreLoads[item.id] = nil
                let message = "\(CoreVocabulary.relativePath(file: item.id)): \(Self.describe(error))"
                Self.log.error("\(message, privacy: .public)")
            }
        }
        return ids.compactMap { (id: String) -> TopicFile? in topicCache[id] }
    }

    /// Jeden shard core (z cache albo dekodowany w tle).
    private func coreFile(id: String) async throws -> TopicFile {
        if let cached = topicCache[id] { return cached }
        guard let task = coreLoadTask(id: id) else {
            throw ContentError.unreadable(file: CoreVocabulary.relativePath(file: id))
        }
        do {
            let file = try await task.value
            finishCoreLoad(id: id, file: file)
            return file
        } catch {
            coreLoads[id] = nil
            throw error
        }
    }

    /// Trwające albo nowe dekodowanie shardu (`nil` — brak katalogu treści).
    private func coreLoadTask(id: String) -> Task<TopicFile, Error>? {
        if let running = coreLoads[id] { return running }
        let path = CoreVocabulary.relativePath(file: id)
        guard Self.isSafeFileName(id), let url = fileURL(path) else { return nil }
        let task = Task.detached(priority: .userInitiated) { () throws -> TopicFile in
            let data: Data
            do {
                data = try Data(contentsOf: url, options: [.mappedIfSafe])
            } catch {
                throw ContentError.unreadable(file: path)
            }
            return try ContentDecoder.coreFile(from: data)
        }
        coreLoads[id] = task
        return task
    }

    private func finishCoreLoad(id: String, file: TopicFile) {
        if topicCache[id] == nil { topicCache[id] = file }
        coreLoads[id] = nil
    }

    /// Rekordy słownika rdzeniowego z `dictionary-index.json` (poziom, częstość, referencja) —
    /// bez dekodowania shardów. Pusta lista, gdy indeksu nie ma.
    func coreDictionaryEntries() async -> [DictionaryIndex.Entry] {
        if let coreDictionaryCache { return coreDictionaryCache }
        _ = await readySearchIndex()
        if let coreDictionaryCache { return coreDictionaryCache }
        guard let base = baseDictionary else { return [] }
        let entries = base.filter { (entry: DictionaryIndex.Entry) -> Bool in entry.contentReference?.isCore == true }
        coreDictionaryCache = entries
        return entries
    }

    /// Wpis po referencji `plik/id`, np. `airport/airport.boarding-pass`, `starter/starter.do`
    /// lub `core-c01/core.attain`.
    func entry(reference: String) async throws -> TopicEntry {
        guard let ref = ContentReference(reference) else {
            throw ContentError.unreadable(file: reference)
        }
        if ref.isStarter {
            let starter = try loadStarter()
            guard let entry = starter.words.first(where: { $0.id == ref.entryID }) else {
                throw ContentError.unreadable(file: reference)
            }
            return entry
        }
        if !ref.isCore {
            // Tematy: błąd odczytu pliku przekazujemy dalej bez zmian.
            let file = try await topic(id: ref.file)
            guard let found = file.entry(id: ref.entryID) else {
                throw ContentError.unreadable(file: reference)
            }
            return found.entry
        }
        guard let found = await locate(ref) else {
            throw ContentError.unreadable(file: reference)
        }
        return found.entry
    }

    /// Identyfikatory plików słownika rdzeniowego (`core-c01`, …), posortowane. Pusta lista,
    /// gdy katalogu `core/` nie ma.
    func coreFileIDs() -> [String] {
        if let coreIDsCache { return coreIDsCache }
        var ids: [String] = []
        if let directory = fileURL(CoreVocabulary.directory),
           let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) {
            ids = CoreVocabulary.fileIDs(fromFileNames: names)
        }
        coreIDsCache = ids
        return ids
    }

    /// Wpis tematu lub core wraz z kategorią i plikiem. Wpis core przeniesiony do innego sharda
    /// odnajdujemy po id (`core.<hasło>` nie zależy od sharda), więc stare `contentRef` działają.
    private func locate(_ ref: ContentReference) async -> (entry: TopicEntry, category: TopicCategory, file: TopicFile)? {
        if let file = try? await topic(id: ref.file), let found = file.entry(id: ref.entryID) {
            return (found.entry, found.category, file)
        }
        guard ref.isCore, CoreVocabulary.isCoreEntryID(ref.entryID) else { return nil }
        for id in coreFileIDs() where id != ref.file {
            guard let file = try? await topic(id: id), let found = file.entry(id: ref.entryID) else { continue }
            return (found.entry, found.category, file)
        }
        return nil
    }

    // MARK: - Wyszukiwanie i słownik

    /// Wyszukiwanie w słowniku szybkiego dodawania. Pusty wynik, jeśli indeks się jeszcze buduje.
    func search(_ query: String, limit: Int) async -> [SearchHit] {
        guard let searchIndex else {
            startSearchBuild()
            return []
        }
        return searchIndex.search(query, limit: limit)
    }

    /// Czy indeks wyszukiwania jest gotowy.
    var isSearchReady: Bool { searchIndex != nil }

    /// Wszystkie znaczenia hasła z bazy (`VocabularyMerger.lookup`), `nil` gdy brak.
    func lookup(term: String) async -> Lookup? {
        guard let index = await readySearchIndex() else { return nil }
        let entries = index.meanings(of: term)
        guard !entries.isEmpty else { return nil }
        var pairs: [(entry: TopicEntry, suggestion: SenseSuggestion)] = []
        for indexEntry in entries {
            guard let pair = await suggestionPair(for: indexEntry.reference) else { continue }
            pairs.append(pair)
        }
        guard !pairs.isEmpty else { return nil }
        return VocabularyMerger.lookup(term: term, entries: pairs)
    }

    private func suggestionPair(for reference: String) async -> (entry: TopicEntry, suggestion: SenseSuggestion)? {
        guard let ref = ContentReference(reference) else { return nil }
        if ref.isStarter {
            guard let starter = try? loadStarter(),
                  let entry = starter.words.first(where: { $0.id == ref.entryID }) else { return nil }
            let suggestion = VocabularyMerger.suggestion(
                from: entry,
                topicName: VocabularyMerger.defaultCollection,
                reference: ref.rawValue
            )
            return (entry, suggestion)
        }
        guard let found = await locate(ref) else { return nil }
        // Core: kolekcja „Słownictwo ogólne”, bez kategorii/sceny (to pasma CEFR, nie sytuacje).
        let isCore = CoreVocabulary.isCore(found.file)
        let suggestion = VocabularyMerger.suggestion(
            from: found.entry,
            topicName: found.file.namePl,
            categoryName: isCore ? nil : found.category.namePl,
            scene: isCore || found.category.scenePl.isEmpty ? nil : found.category.scenePl,
            reference: ContentReference(file: found.file.id, entryID: found.entry.id).rawValue
        )
        return (found.entry, suggestion)
    }

    private func readySearchIndex() async -> ContentSearch? {
        if let searchIndex { return searchIndex }
        startSearchBuild()
        guard let build = searchBuild else { return nil }
        let built = await build.value
        install(built)
        return searchIndex
    }

    private func startSearchBuild() {
        guard searchBuild == nil, !searchBuildFailed else { return }
        let url = fileURL("dictionary-index.json")
        let build = Task.detached(priority: .utility) { () -> [DictionaryIndex.Entry]? in
            guard let url, let data = try? Data(contentsOf: url) else { return nil }
            guard let index = try? ContentDecoder.dictionaryIndex(from: data) else { return nil }
            return index.entries
        }
        searchBuild = build
        Task { [weak self] in
            let built = await build.value
            await self?.install(built)
        }
    }

    private func install(_ entries: [DictionaryIndex.Entry]?) {
        guard searchIndex == nil else { return }
        if let entries {
            baseDictionary = entries
        } else if !searchBuildFailed {
            searchBuildFailed = true
            baseDictionary = []
            Self.log.error("dictionary-index.json missing or invalid — built-in search disabled")
        }
        rebuildSearchIndex()
    }

    /// Indeks szybkiego dodawania = słownik wbudowany + kompletne wpisy tematów AI.
    private func rebuildSearchIndex() {
        guard let base = baseDictionary else { return }
        let local = loadGenerated().values
            .sorted { $0.createdAt < $1.createdAt }
            .flatMap { $0.dictionaryEntries }
        if base.isEmpty && local.isEmpty { return }
        searchIndex = local.isEmpty ? ContentSearch(entries: base) : ContentSearch(entries: base + local)
    }

    // MARK: - Wyszukiwanie tematów (F1)

    /// Katalog wyszukiwania tematów: wszystkie pliki `topics/*.json` z bundla (bez polegania na
    /// `index.json`) + tematy AI z pamięci lokalnej + zapamiętane zapytania. Budowany raz, w tle;
    /// po zapisie tematu lub zapytania przebudowywana jest tylko część lokalna.
    func topicCatalog() async -> TopicSearchCatalog {
        if let catalogCache { return catalogCache }
        let base = await loadBaseTopicDocuments()
        if let catalogCache { return catalogCache }
        let generated = loadGenerated().values
            .sorted { $0.createdAt < $1.createdAt }
            .map { TopicSearchDocument(topic: $0.topic, isGenerated: true) }
        let saved = loadAliases().aliases
        let documents = base + generated
        let catalog = await Task.detached(priority: .userInitiated) { () -> TopicSearchCatalog in
            TopicSearchCatalog(documents: documents, savedQueries: saved)
        }.value
        catalogCache = catalog
        return catalog
    }

    /// Tematy dla zapytania (najlepszy pierwszy).
    func rankTopics(_ query: String, limit: Int = 8) async -> [TopicMatch] {
        let catalog = await topicCatalog()
        return TopicSearch.rank(query, in: catalog, limit: limit)
    }

    /// Dane do wyświetlenia propozycji tematów.
    func topicSuggestions(for matches: [TopicMatch]) async -> [TopicSuggestion] {
        await topicCatalog().suggestions(for: matches)
    }

    /// Sekcje wyniku: najlepsza kategoria tematu → reszta tematu → powiązane tematy.
    func topicResultSections(primary: TopicMatch, matches: [TopicMatch]) async throws -> [TopicResultSection] {
        let primaryTopic = try await self.topic(id: primary.topicID)
        var related: [(match: TopicMatch, topic: TopicFile)] = []
        for match in TopicSearch.relatedMatches(matches, primary: primary) {
            guard let file = try? await self.topic(id: match.topicID) else { continue }
            related.append((match: match, topic: file))
        }
        return TopicSearch.sections(primary: primary, topic: primaryTopic, related: related)
    }

    /// Identyfikatory wszystkich znanych tematów (do nadania unikalnego id tematowi AI).
    func knownTopicIDs() async -> Set<String> {
        let base = await loadBaseTopicDocuments()
        return Set(base.map { $0.id }).union(loadGenerated().keys)
    }

    /// Zapisany temat AI (z pamięci lokalnej).
    func generatedTopic(id: String) async -> GeneratedTopicRecord? {
        loadGenerated()[id]
    }

    /// Zapisuje temat AI (nowy lub po uzupełnieniu kolejnej partii szczegółów). Zapis atomowy;
    /// bez pamięci na dysku (podgląd) temat zostaje tylko w pamięci.
    func saveGeneratedTopic(_ record: GeneratedTopicRecord) async throws {
        var records = loadGenerated()
        records[record.topic.id] = record
        generatedCache = records
        topicCache[record.topic.id] = nil
        catalogCache = nil
        rebuildSearchIndex()
        try localStore?.save(record)
    }

    /// Zapamiętuje, że zapytanie oznacza dany temat (kolejne wyszukiwanie jest natychmiastowe).
    func rememberQuery(_ query: String, topicID: String, categoryID: String?, now: Timestamp) async {
        var book = loadAliases()
        guard book.record(query: query, topicID: topicID, categoryID: categoryID, now: now) else { return }
        aliasCache = book
        catalogCache = nil
        do {
            try localStore?.saveAliases(book)
        } catch {
            Self.log.error("aliases.json: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Zapomina zapytanie („To nie ten temat”).
    func forgetQuery(_ query: String) async {
        var book = loadAliases()
        guard book.remove(query: query) else { return }
        aliasCache = book
        catalogCache = nil
        try? localStore?.saveAliases(book)
    }

    /// Usuwa wszystkie tematy AI i zapamiętane zapytania („Usuń wszystkie dane”).
    func removeGeneratedTopics() async {
        localStore?.removeAll()
        let hadGenerated = !(generatedCache ?? [:]).isEmpty
        generatedCache = [:]
        aliasCache = TopicAliasBook()
        catalogCache = nil
        if hadGenerated { rebuildSearchIndex() }
    }

    private func loadGenerated() -> [String: GeneratedTopicRecord] {
        if let generatedCache { return generatedCache }
        var records: [String: GeneratedTopicRecord] = [:]
        for record in localStore?.loadRecords() ?? [] {
            records[record.topic.id] = record
        }
        generatedCache = records
        return records
    }

    private func loadAliases() -> TopicAliasBook {
        if let aliasCache { return aliasCache }
        let book = localStore?.loadAliases() ?? TopicAliasBook()
        aliasCache = book
        return book
    }

    private func loadBaseTopicDocuments() async -> [TopicSearchDocument] {
        if let baseTopicDocuments { return baseTopicDocuments }
        let build: Task<[TopicSearchDocument], Never>
        if let existing = baseTopicDocumentsBuild {
            build = existing
        } else {
            let directory = fileURL("topics")
            build = Task.detached(priority: .userInitiated) { () -> [TopicSearchDocument] in
                ContentLibrary.decodeTopicDocuments(in: directory)
            }
            baseTopicDocumentsBuild = build
        }
        let documents = await build.value
        baseTopicDocuments = documents
        return documents
    }

    /// Dekoduje lekką wersję każdego pliku tematu (uszkodzone pliki pomija).
    nonisolated static func decodeTopicDocuments(in directory: URL?) -> [TopicSearchDocument] {
        guard let directory,
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        var documents: [TopicSearchDocument] = []
        for name in names.sorted() where name.hasSuffix(".json") && name != "index.json" {
            let url = directory.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { continue }
            do {
                let document = try ContentDecoder.topicSearchDocument(from: data)
                // Słownik rdzeniowy nie jest tematem (leży w core/, ale na wszelki wypadek też tutaj).
                guard name == "\(document.id).json", !CoreVocabulary.isCoreFile(document.id) else { continue }
                documents.append(document)
            } catch {
                log.error("topics/\(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return documents
    }

    // MARK: - Ocenianie

    func answerVariants() async -> AnswerVariants {
        if let variantsCache { return variantsCache }
        let variants: AnswerVariants
        do {
            variants = try ContentDecoder.answerVariants(from: read("answer-variants.json"))
        } catch {
            Self.log.error("answer-variants.json: \(error.localizedDescription, privacy: .public) — using built-in")
            variants = .builtIn
        }
        variantsCache = variants
        return variants
    }

    func polishAnswerIndex() async -> PolishAnswerIndex {
        if let polishIndexCache { return polishIndexCache }
        let index = PolishAnswerIndex(await answerVariants())
        polishIndexCache = index
        return index
    }

    // MARK: - Ćwiczenia

    /// Treść ćwiczeń dla poziomu: `grammar/<poziom>.json` (+ A2 jako zapas, jak `productionPool`),
    /// ćwiczenia, idiomy, czytanki. Ładowane leniwie i cache'owane.
    func practiceContent(level: String) async throws -> PracticeContent {
        let resolved = PracticeContent.resolvedLevel(level)
        if let cached = practiceCache[resolved] { return cached }
        var levels = [resolved]
        if resolved != "A2" { levels.append("A2") }
        var grammarFiles: [GrammarLevelFile] = []
        for item in levels {
            grammarFiles.append(try grammarLevel(item))
        }
        let content = PracticeContent(
            grammarFiles: grammarFiles,
            exercises: try exercises(),
            idioms: try idioms(),
            readings: try readings()
        )
        practiceCache[resolved] = content
        return content
    }

    func readingBank() async throws -> ReadingBank {
        try readings()
    }

    private func grammarLevel(_ level: String) throws -> GrammarLevelFile {
        if let cached = grammarCache[level] { return cached }
        let file = try ContentDecoder.grammarLevel(from: read("grammar/\(level).json"))
        grammarCache[level] = file
        return file
    }

    private func exercises() throws -> ProductionBank {
        if let exercisesCache { return exercisesCache }
        let bank = try ContentDecoder.exercises(from: read("exercises.json"))
        exercisesCache = bank
        return bank
    }

    private func idioms() throws -> IdiomBank {
        if let idiomsCache { return idiomsCache }
        let bank = try ContentDecoder.idioms(from: read("idioms.json"))
        idiomsCache = bank
        return bank
    }

    private func readings() throws -> ReadingBank {
        if let readingsCache { return readingsCache }
        let bank = try ContentDecoder.readings(from: read("readings.json"))
        readingsCache = bank
        return bank
    }

    // MARK: - Starter i rekomendacje

    /// Pula dystraktorów (`MeaningOptions`) — słowa startowe.
    func starterWords() async -> [Word] {
        if let starterWordsCache { return starterWordsCache }
        let words = (try? loadStarter()).map { VocabularyMerger.starterWords($0.words) } ?? []
        starterWordsCache = words
        return words
    }

    /// Wpisy startowe (np. propozycje na pustym ekranie Dzisiaj).
    func starterEntries() async -> [TopicEntry] {
        (try? loadStarter())?.words ?? []
    }

    func recommendations() async -> [Recommendation] {
        if let recommendationsCache { return recommendationsCache }
        let items: [Recommendation]
        do {
            items = try ContentDecoder.recommendations(from: read("recommendations.json")).items
        } catch {
            Self.log.error("recommendations.json: \(error.localizedDescription, privacy: .public)")
            items = []
        }
        recommendationsCache = items
        return items
    }

    private func loadStarter() throws -> StarterWords {
        if let starterCache { return starterCache }
        let starter = try ContentDecoder.starterWords(from: read("starter-words.json"))
        starterCache = starter
        return starter
    }

    // MARK: - Rozgrzewanie i integralność

    /// Rozgrzewa najczęściej potrzebne dane w tle (po pierwszej klatce UI).
    func warmUp() async {
        startSearchBuild()
        _ = try? await topicIndex()
        _ = await polishAnswerIndex()
        _ = await starterWords()
        if let build = searchBuild {
            install(await build.value)
        }
        // Katalog wyszukiwania tematów (~130 plików, lekkie dekodowanie) — po słowniku.
        _ = await topicCatalog()
    }

    /// Sprawdza, że każdy plik treści da się zdekodować. Zwraca listę błędów (pusta = OK).
    /// Używane w testach integralności treści.
    func validateAll() async -> [String] {
        var problems: [String] = []
        func check(_ name: String, _ body: () throws -> Void) {
            do { try body() } catch { problems.append("\(name): \(Self.describe(error))") }
        }
        check("topics/index.json") { _ = try ContentDecoder.topicIndex(from: read("topics/index.json")) }
        if let index = try? ContentDecoder.topicIndex(from: read("topics/index.json")) {
            for summary in index.topics {
                check("topics/\(summary.id).json") {
                    let topic = try ContentDecoder.topicFile(from: read("topics/\(summary.id).json"))
                    if topic.id != summary.id {
                        throw ContentError.invalidJSON(file: "topics/\(summary.id).json", detail: "id \(topic.id) ≠ \(summary.id)")
                    }
                }
            }
        }
        for id in coreFileIDs() {
            let path = CoreVocabulary.relativePath(file: id)
            check(path) {
                let core = try ContentDecoder.coreFile(from: read(path))
                if core.id != id || core.group != CoreVocabulary.group {
                    throw ContentError.invalidJSON(file: path, detail: "id \(core.id) / group \(core.group) ≠ \(id) / \(CoreVocabulary.group)")
                }
            }
        }
        check("dictionary-index.json") { _ = try ContentDecoder.dictionaryIndex(from: read("dictionary-index.json")) }
        for level in CEFR.levels {
            check("grammar/\(level).json") { _ = try ContentDecoder.grammarLevel(from: read("grammar/\(level).json")) }
        }
        check("exercises.json") { _ = try ContentDecoder.exercises(from: read("exercises.json")) }
        check("idioms.json") { _ = try ContentDecoder.idioms(from: read("idioms.json")) }
        check("readings.json") { _ = try ContentDecoder.readings(from: read("readings.json")) }
        check("starter-words.json") { _ = try ContentDecoder.starterWords(from: read("starter-words.json")) }
        check("recommendations.json") { _ = try ContentDecoder.recommendations(from: read("recommendations.json")) }
        check("answer-variants.json") { _ = try ContentDecoder.answerVariants(from: read("answer-variants.json")) }
        return problems
    }

    // MARK: - Pliki

    private func fileURL(_ relativePath: String) -> URL? {
        root?.appendingPathComponent(relativePath)
    }

    private func read(_ relativePath: String) throws -> Data {
        guard let url = fileURL(relativePath) else {
            throw ContentError.unreadable(file: relativePath)
        }
        do {
            return try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw ContentError.unreadable(file: relativePath)
        }
    }

    /// Identyfikator tematu nie może wyjść poza katalog treści.
    static func isSafeFileName(_ id: String) -> Bool {
        !id.isEmpty && !id.contains("/") && !id.contains("\\") && !id.contains("..")
    }

    private static func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
