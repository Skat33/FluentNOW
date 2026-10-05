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

    private var searchIndex: ContentSearch?
    private var searchBuild: Task<ContentSearch?, Never>?
    private var searchBuildFailed = false

    private static let log = Logger(subsystem: "pl.fluentnow.app", category: "ContentLibrary")

    /// Treść z bundla aplikacji (`Content/` jako referencja folderowa).
    init(bundle: Bundle = .main) {
        root = bundle.url(forResource: "Content", withExtension: nil)
    }

    /// Treść z dowolnego katalogu (testy). `nil` = brak treści (podgląd bez bundla).
    init(rootURL: URL?) {
        root = rootURL
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

    func topic(id: String) async throws -> TopicFile {
        if let cached = topicCache[id] { return cached }
        guard Self.isSafeFileName(id) else { throw ContentError.unreadable(file: "topics/\(id).json") }
        let data = try read("topics/\(id).json")
        let topic = try ContentDecoder.topicFile(from: data)
        topicCache[id] = topic
        return topic
    }

    /// Wpis po referencji `plik/id`, np. `airport/airport.boarding-pass` lub `starter/starter.do`.
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
        let file = try await topic(id: ref.file)
        guard let found = file.entry(id: ref.entryID) else {
            throw ContentError.unreadable(file: reference)
        }
        return found.entry
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
        guard let file = try? await topic(id: ref.file),
              let found = file.entry(id: ref.entryID) else { return nil }
        let suggestion = VocabularyMerger.suggestion(
            from: found.entry,
            topicName: file.namePl,
            categoryName: found.category.namePl,
            scene: found.category.scenePl.isEmpty ? nil : found.category.scenePl,
            reference: ref.rawValue
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
        let build = Task.detached(priority: .utility) { () -> ContentSearch? in
            guard let url, let data = try? Data(contentsOf: url) else { return nil }
            guard let index = try? ContentDecoder.dictionaryIndex(from: data) else { return nil }
            return ContentSearch(index: index)
        }
        searchBuild = build
        Task { [weak self] in
            let built = await build.value
            await self?.install(built)
        }
    }

    private func install(_ built: ContentSearch?) {
        guard searchIndex == nil else { return }
        if let built {
            searchIndex = built
        } else if !searchBuildFailed {
            searchBuildFailed = true
            Self.log.error("dictionary-index.json missing or invalid — search disabled")
        }
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
