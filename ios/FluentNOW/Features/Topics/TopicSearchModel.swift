import Foundation
import Observation
import FluentKit

/// Etap ekranu „Szukaj tematu”.
enum TopicSearchPhase: Equatable {
    /// Puste pole — przykładowe zapytania.
    case idle
    /// Pierwsze wyszukiwanie w toku (bez wcześniejszych wyników).
    case searching
    /// Wyniki: sekcje tematu.
    case results
    /// Brak dobrego dopasowania w bazie — najbliższe propozycje + AI (jeśli włączone).
    case noMatch
    /// AI układa listę słów tematu (etap 1).
    case generating
    /// Błąd (np. AI) — komunikat po polsku.
    case failed(String)
}

/// Błędy wyszukiwania tematu.
enum TopicSearchError: Error, LocalizedError {
    case tooFewEntries

    var errorDescription: String? {
        switch self {
        case .tooFewEntries:
            return "Asystent nie przygotował wystarczającej listy poprawnych słów. Spróbuj opisać sytuację inaczej."
        }
    }
}

/// Stan i logika ekranu „Szukaj tematu” (F1): wyszukiwanie w bazie (`TopicSearch` w `ContentLibrary`),
/// generowanie tematu przez AI (lista → szczegóły w partiach po 5 z postępem i przerwaniem),
/// zapis do lokalnej pamięci tematów i dodawanie zaznaczonych słów do nauki (`TopicAdder`).
@MainActor
@Observable
final class TopicSearchModel {
    var query: String = ""
    private(set) var phase: TopicSearchPhase = .idle
    private(set) var isSearching = false
    private(set) var matches: [TopicMatch] = []
    private(set) var suggestions: [TopicSuggestion] = []
    /// Temat pokazywany w wynikach.
    private(set) var primary: TopicSuggestion?
    private(set) var sections: [TopicResultSection] = []
    /// Uwaga pod wynikami (np. ile haseł AI odrzucono).
    private(set) var notice: String?

    /// Zaznaczone wpisy (referencje `temat/wpis`).
    var selection: Set<String> = []
    /// Widoczne poziomy CEFR.
    var levels: Set<String> = Set(CEFR.levels)
    /// Wpisy już dodane do nauki (`Meaning.contentRef`).
    var added: Set<String> = []

    private(set) var isAdding = false
    private(set) var progress: Double = 0
    private(set) var progressLabel = ""
    private(set) var outcome: TopicAddOutcome?
    private(set) var addError: String?
    private(set) var addedTrigger = 0

    @ObservationIgnored private let content: ContentLibrary
    @ObservationIgnored private let store: LearningStore
    @ObservationIgnored private let assistant: AssistantService
    @ObservationIgnored private var topicFiles: [String: TopicFile] = [:]
    @ObservationIgnored private var generateTask: Task<Void, Never>?
    @ObservationIgnored private var addTask: Task<Void, Never>?
    /// Zapytanie, dla którego pokazano wyniki (do zapamiętania przy dodaniu).
    @ObservationIgnored private var shownQuery = ""
    /// Temat otwarty bezpośrednio (deep link) — puste pole go nie czyści.
    @ObservationIgnored private var openedDirectly = false

    /// Przykładowe zapytania (skróty na pustym ekranie i w onboardingu).
    static let exampleQueries = [
        "przedstawianie się", "w restauracji", "w sklepie", "na lotnisku",
        "u lekarza", "rozmowa o pracę", "w hotelu", "pytanie o drogę"
    ]

    init(content: ContentLibrary, store: LearningStore, assistant: AssistantService) {
        self.content = content
        self.store = store
        self.assistant = assistant
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canGenerate: Bool { assistant.canGenerateTopics }

    /// Coś trwa i zamknięcie arkusza przerwałoby pracę.
    var isBusy: Bool { isAdding || phase == .generating }

    var isGeneratedTopic: Bool { primary?.match.isGenerated ?? false }

    /// Sekcje po filtrze poziomów (puste pominięte).
    var visibleSections: [TopicResultSection] {
        sections.compactMap { (section: TopicResultSection) -> TopicResultSection? in
            var copy = section
            copy.entries = section.entries.filter { $0.level.isEmpty || levels.contains($0.level) }
            return copy.entries.isEmpty ? nil : copy
        }
    }

    /// Liczba zaznaczonych, jeszcze niedodanych wpisów.
    var selectedCount: Int { selection.subtracting(added).count }

    /// Liczba wpisów każdego poziomu w wynikach.
    var levelCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for section in sections {
            for entry in section.entries { counts[entry.level, default: 0] += 1 }
        }
        return counts
    }

    var totalEntries: Int { sections.reduce(0) { $0 + $1.entries.count } }

    /// Alternatywy dla pokazanego tematu („Nie o to chodziło?”).
    var alternatives: [TopicSuggestion] {
        suggestions.filter { $0.match.topicID != primary?.match.topicID }
    }

    // MARK: Wyszukiwanie

    /// Wyszukiwanie w bazie (z opóźnieniem przy pisaniu). Woła widok w `.task(id: query)`.
    func search(debounced: Bool) async {
        let text = trimmedQuery
        guard !text.isEmpty else {
            if !openedDirectly { reset() }
            return
        }
        openedDirectly = false
        if debounced {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
        }
        guard phase != .generating, !isAdding else { return }
        isSearching = true
        defer { if text == trimmedQuery { isSearching = false } }
        if phase != .results { phase = .searching }
        let ranked = await content.rankTopics(text, limit: 8)
        guard !Task.isCancelled, text == trimmedQuery else { return }
        let display = await content.topicSuggestions(for: ranked)
        guard !Task.isCancelled, text == trimmedQuery else { return }
        matches = ranked
        suggestions = display
        isSearching = false
        if let best = ranked.first, best.confidence.isGood {
            await show(best, query: text)
        } else {
            phase = .noMatch
            primary = nil
            sections = []
        }
    }

    /// Enter w polu: wyszukanie od razu; bez dobrego dopasowania i z AI — generowanie tematu.
    func submit() async {
        guard !trimmedQuery.isEmpty else { return }
        await search(debounced: false)
        if phase == .noMatch && canGenerate {
            generate()
        }
    }

    /// Przykładowe zapytanie (chip).
    func useExample(_ text: String) {
        query = text
    }

    /// Wybrana propozycja z listy.
    func choose(_ suggestion: TopicSuggestion) async {
        await show(suggestion.match, query: trimmedQuery)
    }

    /// Otwiera konkretny temat (deep link `fluentnow://topics/<id>`).
    func open(topicID: String) async {
        let match = TopicMatch(topicID: topicID, score: 1.5, confidence: .high, reason: .name)
        openedDirectly = true
        matches = [match]
        suggestions = await content.topicSuggestions(for: [match])
        await show(match, query: "")
    }

    /// „To nie ten temat”: zapomina zapamiętane zapytanie i szuka ponownie.
    func rejectMatch() async {
        let text = trimmedQuery
        guard !text.isEmpty else { return }
        await content.forgetQuery(text)
        await search(debounced: false)
    }

    private func show(_ match: TopicMatch, query text: String) async {
        do {
            let loaded = try await content.topicResultSections(primary: match, matches: matches)
            var files: [String: TopicFile] = [:]
            for topicID in Set(loaded.map { $0.topicID }) {
                if let file = try? await content.topic(id: topicID) { files[topicID] = file }
            }
            guard text.isEmpty || text == trimmedQuery else { return }
            if primary?.match.topicID != match.topicID {
                selection = []
                outcome = nil
                addError = nil
                notice = nil
            }
            topicFiles = files
            sections = loaded
            var shown = suggestions.first { $0.match.topicID == match.topicID }
            if shown == nil {
                let fallback = await content.topicSuggestions(for: [match])
                shown = fallback.first
            }
            primary = shown
            shownQuery = text
            phase = .results
        } catch {
            phase = .failed("Nie udało się wczytać tematu. \(error.localizedDescription)")
        }
    }

    private func reset() {
        generateTask?.cancel()
        isSearching = false
        phase = .idle
        matches = []
        suggestions = []
        primary = nil
        sections = []
        notice = nil
        if !isAdding { selection = [] }
    }

    // MARK: Generowanie (AI, etap 1)

    func generate() {
        let text = trimmedQuery
        guard !text.isEmpty, canGenerate, phase != .generating else { return }
        generateTask?.cancel()
        phase = .generating
        notice = nil
        generateTask = Task { [weak self] in
            await self?.runGeneration(text)
        }
    }

    func cancelGeneration() {
        generateTask?.cancel()
        generateTask = nil
        if phase == .generating { phase = suggestions.isEmpty ? .idle : .noMatch }
    }

    private func runGeneration(_ text: String) async {
        do {
            let draft = try await assistant.generateTopicDraft(query: text)
            guard !Task.isCancelled else { return }
            let knownIDs = await content.knownTopicIDs()
            guard let built = TopicGeneration.buildTopic(from: draft, query: text, existingTopicIDs: knownIDs) else {
                throw TopicSearchError.tooFewEntries
            }
            let now = store.now()
            let record = GeneratedTopicRecord(
                topic: built.topic,
                query: text,
                provider: assistant.activeProvider.rawValue,
                createdAt: now,
                updatedAt: now
            )
            var warning: String?
            do {
                try await content.saveGeneratedTopic(record)
            } catch {
                warning = error.localizedDescription
            }
            await content.rememberQuery(text, topicID: built.topic.id, categoryID: nil, now: now)
            guard !Task.isCancelled else { return }
            let match = TopicMatch(topicID: built.topic.id, score: 1.5, confidence: .high, reason: .savedQuery, isGenerated: true)
            matches = [match] + matches.filter { $0.topicID != match.topicID }
            suggestions = await content.topicSuggestions(for: matches)
            await show(match, query: text)
            notice = Self.generationNotice(rejected: built.rejectedCount, warning: warning)
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    private static func generationNotice(rejected: Int, warning: String?) -> String {
        var parts = ["Temat przygotowany przez AI — to propozycja. Szczegóły (wymowa, przykłady) AI uzupełni przy dodawaniu zaznaczonych słów."]
        if rejected > 0 {
            parts.append("Pominięto \(LibraryText.count(rejected, one: "hasło", few: "hasła", many: "haseł")), które nie spełniały zasad bazy.")
        }
        if let warning { parts.append(warning) }
        return parts.joined(separator: " ")
    }

    // MARK: Zaznaczanie

    func isAdded(_ reference: String) -> Bool { added.contains(reference) }

    func toggle(_ reference: String) {
        guard !isAdded(reference) else { return }
        if selection.contains(reference) { selection.remove(reference) } else { selection.insert(reference) }
    }

    func selectVisible() {
        for section in visibleSections {
            for entry in section.entries {
                let reference = section.reference(of: entry)
                if !isAdded(reference) { selection.insert(reference) }
            }
        }
    }

    func toggleSection(_ section: TopicResultSection) {
        let references = section.entries.map { section.reference(of: $0) }.filter { !isAdded($0) }
        if references.allSatisfy({ selection.contains($0) }) {
            selection.subtract(references)
        } else {
            selection.formUnion(references)
        }
    }

    func toggleLevel(_ level: String) {
        if levels.contains(level) {
            if levels.count > 1 { levels.remove(level) }
        } else {
            levels.insert(level)
        }
    }

    func dismissOutcome() {
        outcome = nil
        addError = nil
    }

    /// Wpis jest szkicem AI (szczegóły zostaną uzupełnione przy dodawaniu).
    func isDraft(_ entry: TopicEntry) -> Bool {
        TopicGeneration.isDraft(entry)
    }

    // MARK: Dodawanie (AI etap 2 + zapis)

    func addSelected() {
        guard !isAdding, selectedCount > 0 else { return }
        addTask = Task { [weak self] in
            await self?.runAdd()
        }
    }

    func cancelAdding() {
        addTask?.cancel()
    }

    private func runAdd() async {
        let references = selection.subtracting(added)
        let grouped = groupedByTopic(references)
        guard !grouped.isEmpty else { return }
        isAdding = true
        outcome = nil
        addError = nil
        progress = 0
        defer {
            isAdding = false
            addTask = nil
        }
        let hydrationFailed = await hydrateDrafts(grouped)
        if Task.isCancelled {
            addError = "Przerwano. Gotowe szczegóły zapisano na urządzeniu — następnym razem pójdzie szybciej."
            return
        }
        progressLabel = "Dodawanie słów…"
        progress = 0
        var total = TopicAddOutcome(collection: primary?.namePl ?? "")
        var addedReferences: [String] = []
        for (offset, group) in grouped.enumerated() {
            guard let topic = topicFiles[group.topicID] else { continue }
            let ready = group.entryIDs.filter { id in
                topic.entry(id: id).map { !TopicGeneration.isDraft($0.entry) } ?? false
            }
            guard !ready.isEmpty else { continue }
            let count = Double(grouped.count)
            let result = await TopicAdder.add(topic: topic, entryIDs: ready, store: store) { [weak self] value in
                self?.progress = (Double(offset) + value) / count
            }
            total.addedMeanings += result.addedMeanings
            total.skippedExisting += result.skippedExisting
            if total.collection.isEmpty { total.collection = result.collection }
            addedReferences.append(contentsOf: ready.map { ContentReference(file: group.topicID, entryID: $0).rawValue })
        }
        selection.subtract(addedReferences)
        added.formUnion(addedReferences)
        if let hydrationFailed {
            addError = hydrationFailed
        }
        if total.addedMeanings > 0 || total.skippedExisting > 0 {
            outcome = total
            addedTrigger += 1
            await rememberShownQuery()
        }
    }

    /// Uzupełnia szczegóły szkiców AI partiami po 5. Każda ukończona partia jest od razu zapisywana
    /// w pamięci tematów. Zwraca komunikat błędu (część słów została szkicami) albo `nil`.
    private func hydrateDrafts(_ grouped: [(topicID: String, entryIDs: [String])]) async -> String? {
        var requestsByTopic: [(topicID: String, requests: [TopicHydrationRequestItem])] = []
        for group in grouped {
            guard let topic = topicFiles[group.topicID] else { continue }
            let requests = TopicGeneration.hydrationRequests(topic: topic, entryIDs: group.entryIDs)
            if !requests.isEmpty { requestsByTopic.append((topicID: group.topicID, requests: requests)) }
        }
        let total = requestsByTopic.reduce(0) { $0 + $1.requests.count }
        guard total > 0 else { return nil }
        var done = 0
        var rejected = 0
        progressLabel = "AI przygotowuje szczegóły słów… 0/\(total)"
        for item in requestsByTopic {
            let batchSize = TopicGeneration.hydrationBatchSize
            for start in stride(from: 0, to: item.requests.count, by: batchSize) {
                if Task.isCancelled { return nil }
                guard let topic = topicFiles[item.topicID] else { break }
                let batch = Array(item.requests[start..<min(start + batchSize, item.requests.count)])
                do {
                    let details = try await assistant.generateTopicDetails(topicName: topic.namePl, items: batch)
                    let result = TopicGeneration.applyHydration(topic: topic, requests: batch, items: details)
                    rejected += result.rejectedIDs.count
                    await storeHydrated(result.topic)
                } catch {
                    if Task.isCancelled { return nil }
                    return "Nie udało się przygotować części słów: \(error.localizedDescription) Gotowe słowa dodano, pozostałe zostały zaznaczone — spróbuj ponownie."
                }
                done += batch.count
                progress = Double(done) / Double(total)
                progressLabel = "AI przygotowuje szczegóły słów… \(done)/\(total)"
            }
        }
        if rejected > 0 {
            return "AI nie przygotowało poprawnych przykładów dla \(LibraryText.words(rejected)) — zostały zaznaczone, spróbuj ponownie."
        }
        return nil
    }

    /// Zapisuje temat po partii szczegółów i odświeża wpisy w wynikach.
    private func storeHydrated(_ topic: TopicFile) async {
        topicFiles[topic.id] = topic
        sections = sections.map { (section: TopicResultSection) -> TopicResultSection in
            guard section.topicID == topic.id else { return section }
            var copy = section
            copy.entries = section.entries.map { entry in topic.entry(id: entry.id)?.entry ?? entry }
            return copy
        }
        guard var record = await content.generatedTopic(id: topic.id) else { return }
        record.topic = topic
        record.updatedAt = store.now()
        do {
            try await content.saveGeneratedTopic(record)
        } catch {
            notice = error.localizedDescription
        }
    }

    /// Zaznaczone referencje pogrupowane po temacie, w kolejności sekcji wyników.
    private func groupedByTopic(_ references: Set<String>) -> [(topicID: String, entryIDs: [String])] {
        var order: [String] = []
        var groups: [String: [String]] = [:]
        for section in sections {
            for entry in section.entries {
                let reference = section.reference(of: entry)
                guard references.contains(reference) else { continue }
                if groups[section.topicID] == nil { order.append(section.topicID) }
                groups[section.topicID, default: []].append(entry.id)
            }
        }
        return order.map { (topicID: $0, entryIDs: groups[$0] ?? []) }
    }

    /// Zapytanie, które dało dodane słowa, zapamiętujemy jako alias tematu (następnym razem
    /// natychmiast i offline).
    private func rememberShownQuery() async {
        guard let primary, !shownQuery.isEmpty else { return }
        await content.rememberQuery(shownQuery, topicID: primary.match.topicID,
                                    categoryID: primary.match.focusCategoryIDs.first, now: store.now())
    }
}
