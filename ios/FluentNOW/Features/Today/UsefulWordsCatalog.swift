import Foundation
import FluentKit

/// Szczegóły wpisu bazy potrzebne liście „Polecane słówka” (rejestr do filtra, przykład, wymowa).
struct UsefulWordDetail: Sendable, Hashable {
    let register: String
    let pos: String
    let ipa: String
    let example: ExamplePair?
}

/// Gotowa lista poleceń dla ekranu.
struct UsefulWordsResult: Sendable, Hashable {
    var suggestions: [UsefulWordSuggestion]
    var details: [String: UsefulWordDetail]
    var level: String
    var targetLevel: String

    static let empty = UsefulWordsResult(suggestions: [], details: [:], level: "A1", targetLevel: "A2")
}

/// Kandydaci i szczegóły „Polecanych słówek” — wszystko poza głównym wątkiem, z cache.
///
/// `dictionary-index.json` nie ma rejestru wpisu, więc ranking (FluentKit `UsefulWordRecommender`)
/// liczony jest w kilku przebiegach: po każdym czytane są szczegóły (rejestr) tylko dla wyników,
/// a słowa slangowe / specjalistyczne spoza tematów użytkownika odpadają. Szczegóły zostają w cache,
/// więc kolejne przeliczenia są natychmiastowe. Pliki tematów czytane są bezpośrednio (bez cache
/// `ContentLibrary`), żeby nie trzymać w pamięci całych tematów tylko dla rejestru.
///
/// Słownik rdzeniowy (FEEDBACK-7): kandydaci core przychodzą z `dictionary-index.json` (bez
/// dekodowania shardów); szczegóły czytane są dopiero dla wyników rankingu, z `core/core-cNN.json`
/// (`ContentReference.relativePath` + `ContentDecoder.coreFile`), pliki równolegle w tle.
actor UsefulWordsCatalog {
    static let shared = UsefulWordsCatalog()

    private struct CachedResult {
        let profile: UsefulWordProfile
        let seed: Int
        let result: UsefulWordsResult
    }

    /// Kandydaci (z `less_common` — tylko dla rodzin wyrazów) i indeks rodzin wyrazów (H4).
    private struct Pool: Sendable {
        let candidates: [UsefulWordCandidate]
        let families: WordFamilyIndex?

        static let empty = Pool(candidates: [], families: nil)
    }

    private let root: URL?
    private var pool: Pool?
    private var poolTask: Task<Pool, Never>?
    private var details: [String: UsefulWordDetail] = [:]
    private var unavailable: Set<String> = []
    private var cachedResults: [Int: CachedResult] = [:]

    /// Ile przebiegów rankingu z doczytywaniem rejestrów (zwykle wystarczają 2).
    private static let maxPasses = 4

    init(bundle: Bundle = .main) {
        root = bundle.url(forResource: "Content", withExtension: nil)
    }

    /// Treść z dowolnego katalogu (testy).
    init(rootURL: URL?) {
        root = rootURL
    }

    /// Polecane słówka dla profilu. `seed` = numer tygodnia (lista zmienia się co tydzień).
    func recommendations(profile: UsefulWordProfile, limit: Int, seed: Int, content: ContentLibrary) async -> UsefulWordsResult {
        if let cached = cachedResults[limit], cached.seed == seed, cached.profile == profile {
            return cached.result
        }
        let loaded = await loadPool(content: content)
        let candidates = loaded.candidates
        guard !candidates.isEmpty else {
            return UsefulWordsResult(suggestions: [], details: [:], level: profile.level, targetLevel: profile.targetLevel)
        }
        var registers: [String: String] = [:]
        var suggestions: [UsefulWordSuggestion] = []
        for _ in 0..<Self.maxPasses {
            for (reference, detail) in details {
                registers[reference] = detail.register
            }
            let options = UsefulWordOptions(limit: limit, registers: registers, excludedReferences: unavailable, seed: seed)
            suggestions = UsefulWordRecommender.recommend(candidates, profile: profile, options: options, families: loaded.families)
            let unknown = suggestions.map { $0.id }.filter { details[$0] == nil && !unavailable.contains($0) }
            if unknown.isEmpty { break }
            await loadDetails(unknown)
        }
        // Po ostatnim przebiegu: nic, co okazało się niedostępne albo nie przechodzi filtra rejestru.
        let accepted = suggestions.filter { (item: UsefulWordSuggestion) -> Bool in
            if unavailable.contains(item.id) { return false }
            guard let detail = details[item.id] else { return true }
            return UsefulWordRecommender.isAllowedRegister(detail.register, learnedTopic: Self.isFromLearnedTopic(item))
        }
        var subset: [String: UsefulWordDetail] = [:]
        for item in accepted {
            if let detail = details[item.id] { subset[item.id] = detail }
        }
        let result = UsefulWordsResult(suggestions: accepted, details: subset, level: profile.level, targetLevel: profile.targetLevel)
        cachedResults[limit] = CachedResult(profile: profile, seed: seed, result: result)
        return result
    }

    private static func isFromLearnedTopic(_ item: UsefulWordSuggestion) -> Bool {
        item.reasons.contains { (reason: UsefulWordReason) -> Bool in
            switch reason {
            case .learnedTopic, .interest: return true
            case .frequent, .fitsLevel, .nextLevel, .everyday, .wordFamily, .coreVocabulary: return false
            }
        }
    }

    // MARK: - Kandydaci

    /// Kandydaci i indeks rodzin wyrazów — budowane raz, w tle (`Task.detached`).
    private func loadPool(content: ContentLibrary) async -> Pool {
        if let pool { return pool }
        if let running = poolTask { return await running.value }
        guard let root else { return .empty }
        let topics: TopicIndex
        do {
            topics = try await content.topicIndex()
        } catch {
            return .empty
        }
        // Po `await` inny wywołujący mógł już zacząć budowę.
        if let pool { return pool }
        if let running = poolTask { return await running.value }
        let url = root.appendingPathComponent("dictionary-index.json")
        let task = Task.detached(priority: .utility) { () -> Pool in
            guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]),
                  let index = try? ContentDecoder.dictionaryIndex(from: data) else { return .empty }
            let candidates = UsefulWordRecommender.candidates(index: index, topics: topics, includeLessCommon: true)
            return Pool(candidates: candidates, families: WordFamilyIndex(entries: index.entries))
        }
        poolTask = task
        let built = await task.value
        poolTask = nil
        if !built.candidates.isEmpty { pool = built }
        return built
    }

    // MARK: - Szczegóły wpisów

    private func loadDetails(_ references: [String]) async {
        guard let root else {
            unavailable.formUnion(references)
            return
        }
        var byFile: [String: [String]] = [:]
        for raw in references {
            guard let reference = ContentReference(raw), ContentLibrary.isSafeFileName(reference.file) else { continue }
            byFile[reference.file, default: []].append(reference.entryID)
        }
        let request = byFile
        let loaded = await Task.detached(priority: .utility) { () async -> [String: UsefulWordDetail] in
            await UsefulWordsCatalog.readDetails(root: root, byFile: request)
        }.value
        // Shard core daje szczegóły wszystkich swoich wpisów — zostają w cache na kolejne przebiegi.
        for (reference, detail) in loaded where details[reference] == nil {
            details[reference] = detail
        }
        for raw in references where details[raw] == nil {
            unavailable.insert(raw)
        }
    }

    /// Szczegóły wpisów z wielu plików — każdy plik dekodowany równolegle, poza aktorem.
    private static func readDetails(root: URL, byFile: [String: [String]]) async -> [String: UsefulWordDetail] {
        await withTaskGroup(of: [String: UsefulWordDetail].self, returning: [String: UsefulWordDetail].self) { (group: inout TaskGroup<[String: UsefulWordDetail]>) async -> [String: UsefulWordDetail] in
            for (file, ids) in byFile {
                let wanted = Set(ids)
                group.addTask { () -> [String: UsefulWordDetail] in
                    UsefulWordsCatalog.readFileDetails(root: root, file: file, wanted: wanted)
                }
            }
            var result: [String: UsefulWordDetail] = [:]
            for await partial in group {
                result.merge(partial) { (current: UsefulWordDetail, _: UsefulWordDetail) -> UsefulWordDetail in current }
            }
            return result
        }
    }

    /// Szczegóły wpisów jednego pliku: `starter-words.json`, `topics/<id>.json` albo — dla
    /// słownika rdzeniowego — `core/core-cNN.json` (ścieżka z `ContentReference.relativePath`).
    /// Shard core (~0,8 MB) zwraca szczegóły **wszystkich** swoich wpisów (są małe), żeby kolejne
    /// przebiegi rankingu i „Odśwież propozycje” nie dekodowały go ponownie.
    private static func readFileDetails(root: URL, file: String, wanted: Set<String>) -> [String: UsefulWordDetail] {
        let location = ContentReference(file: file, entryID: wanted.first ?? "")
        guard let data = try? Data(contentsOf: root.appendingPathComponent(location.relativePath), options: [.mappedIfSafe]) else { return [:] }
        let entries: [TopicEntry]
        if location.isStarter {
            guard let starter = try? ContentDecoder.starterWords(from: data) else { return [:] }
            entries = starter.words
        } else if location.isCore {
            guard let core = try? ContentDecoder.coreFile(from: data) else { return [:] }
            entries = core.allEntries
        } else {
            guard let topic = try? ContentDecoder.topicFile(from: data) else { return [:] }
            entries = topic.allEntries
        }
        let keepAll = location.isCore
        var result: [String: UsefulWordDetail] = [:]
        for entry in entries where keepAll || wanted.contains(entry.id) {
            let reference = ContentReference(file: file, entryID: entry.id).rawValue
            result[reference] = UsefulWordDetail(register: entry.register, pos: entry.pos, ipa: entry.ipa, example: entry.examples.first)
        }
        return result
    }
}

/// Pobranie listy dla ekranu: profil liczony na migawce stanu (`store.compute`), ranking w aktorze.
@MainActor
enum UsefulWordsLoader {
    static func load(store: LearningStore, content: ContentLibrary, limit: Int) async -> UsefulWordsResult {
        let now: Timestamp = store.now()
        let profile: UsefulWordProfile = await store.compute { (state: LearnerState) -> UsefulWordProfile in
            UsefulWordProfile.make(state)
        }
        let week = now.isFinite ? Int(max(0, now) / (7 * TimeConstants.dayMs)) : 0
        return await UsefulWordsCatalog.shared.recommendations(profile: profile, limit: limit, seed: week, content: content)
    }
}

/// Wynik dodania polecanych słówek.
struct UsefulWordsAddOutcome: Equatable {
    var addedMeanings: Int
    var failed: Int
}

/// Dodawanie polecanych słówek: wpisy tematów i słownika rdzeniowego przez
/// `VocabularyMerger.addTopicEntries` (kolekcja = nazwa tematu, dla core „Słownictwo ogólne”;
/// z pełnego pliku, więc znaczenie dostaje **wszystkie** przykłady wpisu — core 3–5), słowa
/// startowe przez `mergeSuggestions`.
/// Wszystko w jednej zmianie `store.update(.bulk)`; znane znaczenia zachowują postęp.
@MainActor
enum UsefulWordsAdder {
    static func add(_ items: [UsefulWordCandidate], store: LearningStore, content: ContentLibrary) async -> UsefulWordsAddOutcome {
        var topicFiles: [String: TopicFile] = [:]
        var entryIDs: [String: [String]] = [:]
        var order: [String] = []
        var starterEntries: [TopicEntry] = []
        var starterReferences: [String] = []
        var failed = 0
        for item in items {
            guard let reference = ContentReference(item.reference) else {
                failed += 1
                continue
            }
            if reference.isStarter {
                do {
                    let entry = try await content.entry(reference: reference.rawValue)
                    starterEntries.append(entry)
                    starterReferences.append(reference.rawValue)
                } catch {
                    failed += 1
                }
                continue
            }
            if topicFiles[reference.file] == nil {
                do {
                    topicFiles[reference.file] = try await content.topic(id: reference.file)
                    order.append(reference.file)
                } catch {
                    failed += 1
                    continue
                }
            }
            // Wpis, którego nie ma w pliku (np. przeniesiony do innego sharda core), to błąd — nie cisza.
            guard topicFiles[reference.file]?.entry(id: reference.entryID) != nil else {
                failed += 1
                continue
            }
            entryIDs[reference.file, default: []].append(reference.entryID)
        }
        let now: Timestamp = store.now()
        let added: Int = store.update(.bulk) { (state: inout LearnerState) -> Int in
            var count = 0
            for file in order {
                guard let topic = topicFiles[file], let ids = entryIDs[file] else { continue }
                let result = VocabularyMerger.addTopicEntries(state, topic: topic, entryIDs: ids, now: now)
                state = result.state
                count += result.addedMeaningIDs.count
            }
            for (index, entry) in starterEntries.enumerated() {
                let reference = starterReferences.indices.contains(index) ? starterReferences[index] : nil
                let suggestion = VocabularyMerger.suggestion(from: entry, topicName: VocabularyMerger.defaultCollection, reference: reference)
                let lookup = VocabularyMerger.lookup(term: entry.term, entries: [(entry: entry, suggestion: suggestion)])
                let result = VocabularyMerger.mergeSuggestions(state, lookup: lookup, indices: [0], now: now)
                state = result.state
                count += result.addedMeaningIDs.count
            }
            return count
        }
        return UsefulWordsAddOutcome(addedMeanings: added, failed: failed)
    }
}
