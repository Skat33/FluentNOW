import Foundation

// MARK: - AI responses (lenient decoding)

/// One item of an AI topic inventory (phase 1: quick list, without details).
public struct TopicDraftItem: Sendable, Hashable {
    public var term: String
    public var translation: String
    public var pos: String
    public var level: String
    public var frequency: String

    public init(term: String, translation: String, pos: String, level: String, frequency: String) {
        self.term = term
        self.translation = translation
        self.pos = pos
        self.level = level
        self.frequency = frequency
    }
}

extension TopicDraftItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case term, pl, translation, pos, level, spokenFrequency, frequency
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = c.lenientString(.term)
        let pl = c.lenientString(.pl)
        translation = pl.isEmpty ? c.lenientString(.translation) : pl
        pos = c.lenientString(.pos)
        level = c.lenientString(.level)
        let spoken = c.lenientString(.spokenFrequency)
        frequency = spoken.isEmpty ? c.lenientString(.frequency) : spoken
    }
}

/// A category of an AI topic inventory.
public struct TopicDraftCategory: Sendable, Hashable {
    public var name: String
    public var scene: String
    public var items: [TopicDraftItem]

    public init(name: String, scene: String = "", items: [TopicDraftItem]) {
        self.name = name
        self.scene = scene
        self.items = items
    }
}

extension TopicDraftCategory: Decodable {
    enum CodingKeys: String, CodingKey {
        case name, scene, items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.lenientString(.name)
        scene = c.lenientString(.scene)
        items = c.lossyArray(TopicDraftItem.self, forKey: .items)
    }
}

/// AI topic inventory for a query (web `TopicSuggestion`, `TOPIC_PROMPT`).
public struct TopicDraft: Sendable, Hashable {
    /// Canonical Polish topic name (nominative).
    public var topic: String
    public var nameEn: String
    public var summaryPl: String
    public var group: String
    public var categories: [TopicDraftCategory]

    public init(topic: String, nameEn: String = "", summaryPl: String = "", group: String = "", categories: [TopicDraftCategory]) {
        self.topic = topic
        self.nameEn = nameEn
        self.summaryPl = summaryPl
        self.group = group
        self.categories = categories
    }
}

extension TopicDraft: Decodable {
    enum CodingKeys: String, CodingKey {
        case topic, nameEn, summaryPl, group, categories
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        topic = c.lenientString(.topic)
        nameEn = c.lenientString(.nameEn)
        summaryPl = c.lenientString(.summaryPl)
        group = c.lenientString(.group)
        categories = c.lossyArray(TopicDraftCategory.self, forKey: .categories)
    }
}

/// Details of one topic item from AI (phase 2: `TOPIC_HYDRATE_PROMPT`).
public struct TopicHydrationItem: Sendable, Hashable {
    public var term: String
    public var ipa: String
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

    public init(term: String, ipa: String = "", definition: String = "", register: String = "", contextPl: String = "", natural: String = "", forms: String = "", collocations: String = "", synonyms: String = "", antonyms: String = "", notePl: String = "", examples: [ExamplePair] = [], acceptedAnswers: [String] = [], acceptedTranslations: [String] = []) {
        self.term = term
        self.ipa = ipa
        self.definition = definition
        self.register = register
        self.contextPl = contextPl
        self.natural = natural
        self.forms = forms
        self.collocations = collocations
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.notePl = notePl
        self.examples = examples
        self.acceptedAnswers = acceptedAnswers
        self.acceptedTranslations = acceptedTranslations
    }
}

extension TopicHydrationItem: Decodable {
    enum CodingKeys: String, CodingKey {
        case term, ipa, definition, register, contextPl, natural, forms, collocations, synonyms, antonyms
        case notePl, note, examples, acceptedAnswers, acceptedTranslations
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = c.lenientString(.term)
        ipa = c.lenientString(.ipa)
        definition = c.lenientString(.definition)
        register = c.lenientString(.register)
        contextPl = c.lenientString(.contextPl)
        natural = c.lenientString(.natural)
        forms = c.lenientString(.forms)
        collocations = c.lenientString(.collocations)
        synonyms = c.lenientString(.synonyms)
        antonyms = c.lenientString(.antonyms)
        let note = c.lenientString(.notePl)
        notePl = note.isEmpty ? c.lenientString(.note) : note
        examples = c.lossyArray(ExamplePair.self, forKey: .examples)
        acceptedAnswers = c.lenientStrings(.acceptedAnswers)
        acceptedTranslations = c.lenientStrings(.acceptedTranslations)
    }
}

/// `{ "items": [TopicHydrationItem] }`.
public struct TopicHydrationResponse: Sendable, Hashable, Decodable {
    public var items: [TopicHydrationItem]

    public init(items: [TopicHydrationItem]) {
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = c.lossyArray(TopicHydrationItem.self, forKey: .items)
    }
}

// MARK: - Results

/// A validated topic built from an AI inventory.
public struct TopicBuildResult: Sendable, Hashable {
    /// Topic in `TopicFile` format; every entry is a draft (no examples yet).
    public var topic: TopicFile
    /// Items dropped by validation (wrong level, part of speech, duplicates…).
    public var rejectedCount: Int

    public init(topic: TopicFile, rejectedCount: Int) {
        self.topic = topic
        self.rejectedCount = rejectedCount
    }
}

/// What is sent to AI to fill in details of a draft entry.
public struct TopicHydrationRequestItem: Sendable, Hashable, Identifiable {
    public var entryID: String
    public var term: String
    public var translation: String
    public var pos: String
    public var level: String
    public var category: String
    public var scene: String

    public init(entryID: String, term: String, translation: String, pos: String, level: String, category: String, scene: String) {
        self.entryID = entryID
        self.term = term
        self.translation = translation
        self.pos = pos
        self.level = level
        self.category = category
        self.scene = scene
    }

    public var id: String { entryID }
}

/// A topic after applying one batch of AI details.
public struct TopicHydrationResult: Sendable, Hashable {
    public var topic: TopicFile
    /// Entries that now have full details.
    public var hydratedIDs: [String]
    /// Requested entries whose details were missing or invalid (they stay drafts).
    public var rejectedIDs: [String]

    public init(topic: TopicFile, hydratedIDs: [String], rejectedIDs: [String]) {
        self.topic = topic
        self.hydratedIDs = hydratedIDs
        self.rejectedIDs = rejectedIDs
    }
}

// MARK: - Generation rules

/// Turning AI output into topic content of the same format and standard as the built-in base
/// (CONTENT-SCHEMA §1, `validate-content.mjs`). Invalid **entries** are dropped, never the whole
/// topic (unless too little is left).
public enum TopicGeneration {
    /// Ids of generated topics start with this prefix — they never collide with built-in ones.
    public static let idPrefix = "ai-"
    /// Fewer valid entries than this → the inventory is rejected.
    public static let minimumEntries = 5
    public static let maximumEntries = 150
    public static let maximumCategories = 9
    /// Details are requested in batches of this size (like the web's `prepareTopicItems`).
    public static let hydrationBatchSize = 5

    /// Group id → (Polish name, SF Symbol) — CONTENT-SCHEMA §2 / §5.8.
    public static let groups: [(id: String, namePl: String, symbol: String)] = [
        ("basics", "Podstawy", "textformat.abc"),
        ("travel", "Podróże", "airplane"),
        ("food", "Jedzenie i picie", "fork.knife"),
        ("home", "Dom", "house"),
        ("health", "Zdrowie", "heart.text.square"),
        ("work", "Praca i biznes", "briefcase"),
        ("education", "Nauka", "graduationcap"),
        ("technology", "Technologia", "desktopcomputer"),
        ("money", "Pieniądze i zakupy", "cart"),
        ("services", "Urzędy i usługi", "building.columns"),
        ("people", "Ludzie i relacje", "person.2"),
        ("daily", "Codzienność", "sun.max"),
        ("leisure", "Czas wolny", "theatermasks"),
        ("nature", "Przyroda", "leaf"),
        ("society", "Społeczeństwo", "globe"),
        ("communication", "Komunikacja", "bubble.left.and.bubble.right")
    ]

    /// Polish name of a group id (empty for unknown ids).
    public static func groupName(_ id: String) -> String {
        groups.first { $0.id == id }?.namePl ?? ""
    }

    public static let partsOfSpeech = [
        "rzeczownik", "czasownik", "czasownik frazowy", "przymiotnik", "przysłówek", "zwrot", "idiom",
        "przyimek", "spójnik", "zaimek", "wykrzyknik", "liczebnik"
    ]

    public static let registers = ["neutralny", "potoczny", "formalny", "specjalistyczny", "slangowy"]

    private static let englishPartsOfSpeech: [String: String] = [
        "noun": "rzeczownik", "verb": "czasownik", "phrasal verb": "czasownik frazowy",
        "adjective": "przymiotnik", "adverb": "przysłówek", "phrase": "zwrot", "expression": "zwrot",
        "fixed phrase": "zwrot", "collocation": "zwrot", "idiom": "idiom", "preposition": "przyimek",
        "conjunction": "spójnik", "pronoun": "zaimek", "interjection": "wykrzyknik", "numeral": "liczebnik",
        "number": "liczebnik", "wyrażenie": "zwrot", "fraza": "zwrot", "związek frazeologiczny": "idiom"
    ]

    // MARK: Phase 1 — inventory

    /// Validates an AI inventory and turns it into a topic of draft entries.
    /// Returns `nil` when fewer than `minimumEntries` valid entries remain.
    public static func buildTopic(from draft: TopicDraft, query: String, existingTopicIDs: Set<String>) -> TopicBuildResult? {
        let cleanQuery = clean(query)
        var name = capitalizedFirst(clean(draft.topic))
        if name.isEmpty { name = capitalizedFirst(cleanQuery) }
        guard !name.isEmpty else { return nil }
        let topicID = makeTopicID(name: name, existing: existingTopicIDs)
        let groupID = clean(draft.group).lowercased()
        let group = groups.first { $0.id == groupID } ?? groups[11]

        var categories: [TopicCategory] = []
        var categoryIDs = Set<String>()
        var entryIDs = Set<String>()
        var seen = Set<String>()
        var rejected = 0
        var total = 0
        for (offset, draftCategory) in draft.categories.enumerated() {
            guard offset < maximumCategories else {
                rejected += draftCategory.items.count
                continue
            }
            let categoryName = capitalizedFirst(clean(draftCategory.name))
            guard !categoryName.isEmpty else {
                rejected += draftCategory.items.count
                continue
            }
            var entries: [TopicEntry] = []
            for item in draftCategory.items {
                guard total < maximumEntries,
                      let entry = draftEntry(item, topicID: topicID, usedIDs: &entryIDs, seen: &seen) else {
                    rejected += 1
                    continue
                }
                entries.append(entry)
                total += 1
            }
            guard !entries.isEmpty else { continue }
            let categoryID = uniqueID(base: "\(topicID).\(slug(categoryName, maxLength: 40, fallback: "kategoria"))", used: &categoryIDs)
            categories.append(TopicCategory(
                id: categoryID,
                namePl: categoryName,
                scenePl: String(clean(draftCategory.scene).prefix(200)),
                entries: entries
            ))
        }
        guard total >= minimumEntries else { return nil }
        var aliases: [String] = []
        var aliasKeys = Set<String>()
        for candidate in [cleanQuery, name, clean(draft.nameEn)] where !candidate.isEmpty {
            if aliasKeys.insert(TextNormalizer.searchKey(candidate)).inserted {
                aliases.append(candidate)
            }
        }
        let topic = TopicFile(
            id: topicID,
            namePl: name,
            nameEn: clean(draft.nameEn),
            group: group.id,
            symbol: group.symbol,
            summaryPl: String(clean(draft.summaryPl).prefix(200)),
            aliases: aliases,
            categories: categories
        )
        return TopicBuildResult(topic: topic, rejectedCount: rejected)
    }

    /// A draft entry from an inventory item, or `nil` when the item breaks a schema rule.
    static func draftEntry(_ item: TopicDraftItem, topicID: String, usedIDs: inout Set<String>, seen: inout Set<String>) -> TopicEntry? {
        let term = cleanTerm(item.term)
        guard !term.isEmpty, term.count <= 80 else { return nil }
        let translation = TextNormalizer.withoutDialectLabel(clean(item.translation))
        guard !translation.isEmpty, translation.count <= 120 else { return nil }
        guard let pos = normalizedPartOfSpeech(item.pos) else { return nil }
        let level = clean(item.level).uppercased()
        guard CEFR.isValid(level) else { return nil }
        guard let frequency = normalizedFrequency(item.frequency) else { return nil }
        let key = TextNormalizer.normalize(term) + "|" + TextNormalizer.normalize(translation)
        guard seen.insert(key).inserted else { return nil }
        let id = uniqueID(base: "\(topicID).\(slug(term, maxLength: 60, fallback: "haslo"))", used: &usedIDs)
        return TopicEntry(
            id: id,
            term: term,
            pos: pos,
            level: level,
            frequency: frequency,
            translation: translation,
            register: "neutralny",
            acceptedAnswers: [term],
            acceptedTranslations: [translation]
        )
    }

    /// Polish part of speech from the schema list (English names are mapped), `nil` when unknown.
    public static func normalizedPartOfSpeech(_ raw: String) -> String? {
        let value = TextScanning.collapseWhitespace(clean(raw).lowercased())
        if partsOfSpeech.contains(value) { return value }
        return englishPartsOfSpeech[value]
    }

    /// `very_common` / `common` / `less_common` / `rare` (also „very common”, „less-common”).
    public static func normalizedFrequency(_ raw: String) -> SpokenFrequency? {
        let value = clean(raw).lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
        return SpokenFrequency(rawValue: value)
    }

    // MARK: Phase 2 — details

    /// `true` while an entry has no details yet (fewer than 2 examples).
    public static func isDraft(_ entry: TopicEntry) -> Bool {
        entry.examples.count < 2
    }

    /// Requests for the draft entries among `entryIDs` (in topic order).
    public static func hydrationRequests(topic: TopicFile, entryIDs: [String]) -> [TopicHydrationRequestItem] {
        let wanted = Set(entryIDs)
        var result: [TopicHydrationRequestItem] = []
        for category in topic.categories {
            for entry in category.entries where wanted.contains(entry.id) && isDraft(entry) {
                result.append(TopicHydrationRequestItem(
                    entryID: entry.id,
                    term: entry.term,
                    translation: entry.translation,
                    pos: entry.pos,
                    level: entry.level,
                    category: category.namePl,
                    scene: category.scenePl.isEmpty ? "\(topic.namePl): \(category.namePl)" : category.scenePl
                ))
            }
        }
        return result
    }

    /// Applies one batch of AI details. Items are matched to requests by term; an entry without a
    /// valid item stays a draft and is reported in `rejectedIDs`.
    public static func applyHydration(topic: TopicFile, requests: [TopicHydrationRequestItem], items: [TopicHydrationItem]) -> TopicHydrationResult {
        var updated = topic
        var available = items
        var hydrated: [String] = []
        var rejected: [String] = []
        for request in requests {
            let key = TextNormalizer.normalize(request.term)
            let itemIndex = available.firstIndex { TextNormalizer.normalize($0.term) == key }
            guard let location = position(of: request.entryID, in: updated) else { continue }
            guard let itemIndex,
                  let draft = updated.categories[safe: location.category]?.entries[safe: location.entry],
                  let entry = hydratedEntry(draft: draft, item: available[itemIndex]) else {
                rejected.append(request.entryID)
                continue
            }
            available.remove(at: itemIndex)
            updated.categories[location.category].entries[location.entry] = entry
            hydrated.append(request.entryID)
        }
        return TopicHydrationResult(topic: updated, hydratedIDs: hydrated, rejectedIDs: rejected)
    }

    private static func position(of entryID: String, in topic: TopicFile) -> (category: Int, entry: Int)? {
        for (categoryIndex, category) in topic.categories.enumerated() {
            if let entryIndex = category.entries.firstIndex(where: { $0.id == entryID }) {
                return (categoryIndex, entryIndex)
            }
        }
        return nil
    }

    /// The draft completed with AI details, or `nil` when the result would break the schema
    /// (fewer than 2 valid examples, missing or too long definition…). Small problems are repaired:
    /// a wrong IPA format or register is dropped / defaulted, a too long `contextPl` is cleared,
    /// the term and translation are always among the accepted answers.
    public static func hydratedEntry(draft: TopicEntry, item: TopicHydrationItem) -> TopicEntry? {
        var entry = draft
        var examples: [ExamplePair] = []
        for pair in item.examples {
            guard let clean = cleanExample(pair), !examples.contains(where: { $0.en == clean.en }) else { continue }
            examples.append(clean)
            if examples.count == 2 { break }
        }
        guard examples.count == 2 else { return nil }
        entry.examples = examples

        var definition = clean(item.definition)
        if definition.count > 140, let end = definition.range(of: ". ") {
            definition = String(definition[definition.startIndex..<end.lowerBound]) + "."
        }
        guard !definition.isEmpty, definition.count <= 140 else { return nil }
        entry.definition = definition

        let ipa = clean(item.ipa)
        entry.ipa = isValidIPA(ipa) ? ipa : ""
        let register = clean(item.register).lowercased()
        entry.register = registers.contains(register) ? register : "neutralny"
        let context = TextNormalizer.withoutDialectLabel(clean(item.contextPl))
        entry.contextPl = context.count <= 80 ? context : ""
        entry.natural = clean(item.natural)
        entry.forms = clean(item.forms)
        entry.collocations = clean(item.collocations)
        entry.synonyms = clean(item.synonyms)
        entry.antonyms = clean(item.antonyms)
        entry.notePl = TextNormalizer.withoutDialectLabel(clean(item.notePl))
        entry.acceptedAnswers = uniqueTexts([entry.term] + item.acceptedAnswers.map(clean), limit: 12)
        let translations = item.acceptedTranslations.map { TextNormalizer.withoutDialectLabel(clean($0)) }
        entry.acceptedTranslations = uniqueTexts([entry.translation] + translations, limit: 8)
        return TopicEntryValidator.issues(entry).isEmpty ? entry : nil
    }

    /// A schema-valid example or `nil` (exact focus substrings, `en` ends with . ? !, capital start).
    public static func cleanExample(_ pair: ExamplePair) -> ExamplePair? {
        let result = ExamplePair(en: clean(pair.en), pl: clean(pair.pl), focusEn: clean(pair.focusEn), focusPl: clean(pair.focusPl))
        return TopicEntryValidator.exampleIssues(result).isEmpty ? result : nil
    }

    // MARK: Ids and text

    /// Topic id for a generated topic: `ai-<kebab name>`, unique among `existing`.
    public static func makeTopicID(name: String, existing: Set<String>) -> String {
        var used = existing
        return uniqueID(base: idPrefix + slug(name, maxLength: 40, fallback: "temat"), used: &used)
    }

    /// Kebab-case ASCII slug (`Zamawianie w restauracji` → `zamawianie-w-restauracji`).
    public static func slug(_ text: String, maxLength: Int = 60, fallback: String = "") -> String {
        let parts = TopicSearch.normalize(text).split(separator: " ")
        var result = ""
        for part in parts {
            let candidate = result.isEmpty ? String(part) : result + "-" + part
            if candidate.count > maxLength { break }
            result = candidate
        }
        if result.isEmpty, let first = parts.first {
            result = String(first.prefix(maxLength))
        }
        return result.isEmpty ? fallback : result
    }

    static func uniqueID(base: String, used: inout Set<String>) -> String {
        var candidate = base
        var suffix = 2
        while used.contains(candidate) {
            candidate = "\(base)-\(suffix)"
            suffix += 1
        }
        used.insert(candidate)
        return candidate
    }

    static func clean(_ value: String) -> String {
        TextScanning.trim(TextScanning.collapseWhitespace(value))
    }

    static func cleanTerm(_ value: String) -> String {
        var term = clean(value)
        while term.hasSuffix(".") && !TopicEntryValidator.isAbbreviation(term) {
            term.removeLast()
            term = TextScanning.trim(term)
        }
        return term
    }

    static func capitalizedFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.uppercased() + value.dropFirst()
    }

    static func isValidIPA(_ value: String) -> Bool {
        guard value.count >= 3, value.hasPrefix("/"), value.hasSuffix("/") else { return false }
        let inner = value.dropFirst().dropLast()
        return !inner.isEmpty && !inner.contains("/")
    }

    static func uniqueTexts(_ values: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values where !value.isEmpty {
            guard seen.insert(TextNormalizer.searchKey(value)).inserted else { continue }
            result.append(value)
            if result.count >= limit { break }
        }
        return result
    }
}

// MARK: - Validation

/// Hard schema rules of a topic entry (the error level of `validate-content.mjs` that can be
/// checked without the English heuristics). Messages in Polish; empty list = valid.
public enum TopicEntryValidator {
    public static func issues(_ entry: TopicEntry) -> [String] {
        var result: [String] = []
        if !isValidEntryID(entry.id) { result.append("Niepoprawny identyfikator „\(entry.id)”.") }
        if TextScanning.trim(entry.term).isEmpty { result.append("Puste hasło.") }
        if entry.term.hasSuffix(".") && !isAbbreviation(entry.term) { result.append("Hasło kończy się kropką.") }
        if !entry.ipa.isEmpty && !TopicGeneration.isValidIPA(entry.ipa) { result.append("Wymowa musi być w ukośnikach /…/.") }
        if !TopicGeneration.partsOfSpeech.contains(entry.pos) { result.append("Nieznana część mowy „\(entry.pos)”.") }
        if !CEFR.isValid(entry.level) { result.append("Niepoprawny poziom „\(entry.level)”.") }
        if entry.frequency == nil { result.append("Brak częstości użycia.") }
        if !TopicGeneration.registers.contains(entry.register) { result.append("Nieznany rejestr „\(entry.register)”.") }
        if TextScanning.trim(entry.translation).isEmpty { result.append("Puste tłumaczenie.") }
        if hasDialectTag(entry.translation) || hasDialectTag(entry.contextPl) { result.append("Tekst zawiera (AmE)/(BrE).") }
        if TextScanning.trim(entry.definition).isEmpty { result.append("Pusta definicja.") }
        if entry.definition.count > 140 { result.append("Definicja dłuższa niż 140 znaków.") }
        if entry.contextPl.count > 80 { result.append("Kontekst dłuższy niż 80 znaków.") }
        if entry.examples.count != 2 {
            result.append("Wymagane dokładnie 2 przykłady.")
        }
        for pair in entry.examples {
            result.append(contentsOf: exampleIssues(pair))
        }
        if entry.examples.count == 2, entry.examples[0].en == entry.examples[1].en {
            result.append("Oba przykłady są identyczne.")
        }
        let termKey = TextNormalizer.searchKey(entry.term)
        if entry.acceptedAnswers.isEmpty || entry.acceptedAnswers.contains(where: { TextScanning.trim($0).isEmpty }) {
            result.append("Lista akceptowanych odpowiedzi jest pusta lub ma puste elementy.")
        } else if !entry.acceptedAnswers.contains(where: { TextNormalizer.searchKey($0) == termKey }) {
            result.append("Akceptowane odpowiedzi nie zawierają hasła.")
        }
        if entry.acceptedTranslations.isEmpty || entry.acceptedTranslations.count > 8
            || entry.acceptedTranslations.contains(where: { TextScanning.trim($0).isEmpty }) {
            result.append("Wymagane 1–8 akceptowanych tłumaczeń.")
        }
        if entry.acceptedTranslations.contains(where: { hasDialectTag($0) }) { result.append("Tłumaczenie zawiera (AmE)/(BrE).") }
        return result
    }

    /// Problems of one example pair.
    public static func exampleIssues(_ pair: ExamplePair) -> [String] {
        var result: [String] = []
        if TextScanning.trim(pair.en).isEmpty || TextScanning.trim(pair.pl).isEmpty
            || TextScanning.trim(pair.focusEn).isEmpty || TextScanning.trim(pair.focusPl).isEmpty {
            result.append("Przykład ma puste pole.")
            return result
        }
        if !pair.en.contains(pair.focusEn) { result.append("Fragment „\(pair.focusEn)” nie występuje w zdaniu angielskim.") }
        if !pair.pl.contains(pair.focusPl) { result.append("Fragment „\(pair.focusPl)” nie występuje w zdaniu polskim.") }
        if !endsWithSentencePunctuation(pair.en) { result.append("Zdanie angielskie musi kończyć się . ? lub !.") }
        if !startsWithCapital(pair.en) || !startsWithCapital(pair.pl) { result.append("Zdanie musi zaczynać się wielką literą.") }
        if TextScanning.trim(pair.en) == TextScanning.trim(pair.pl) { result.append("Zdanie nie jest przetłumaczone.") }
        if hasDialectTag(pair.pl) { result.append("Przykład zawiera (AmE)/(BrE).") }
        if pair.en.count > 300 || pair.pl.count > 300 { result.append("Przykład jest za długi.") }
        return result
    }

    /// `<topic>.<entry>` with kebab-case parts (`airport.boarding-pass`).
    static func isValidEntryID(_ id: String) -> Bool {
        let parts = id.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        return parts.allSatisfy { isKebab(String($0)) }
    }

    static func isKebab(_ value: String) -> Bool {
        guard !value.isEmpty, !value.hasPrefix("-"), !value.hasSuffix("-"), !value.contains("--") else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            (97...122).contains(scalar.value) || (48...57).contains(scalar.value) || scalar.value == 45
        }
    }

    /// `a.m.`, `p.m.`, `U.S.` — allowed to end with a period.
    static func isAbbreviation(_ term: String) -> Bool {
        let characters = Array(term)
        guard characters.count >= 4 else { return false }
        let tail = characters.suffix(4)
        let a = tail[tail.startIndex]
        let b = tail[tail.startIndex + 1]
        let c = tail[tail.startIndex + 2]
        let d = tail[tail.startIndex + 3]
        guard a.isLetter, b == ".", c.isLetter, d == "." else { return false }
        if characters.count > 4 {
            let before = characters[characters.count - 5]
            return !before.isLetter
        }
        return true
    }

    static func endsWithSentencePunctuation(_ text: String) -> Bool {
        let closing: Set<Character> = ["\"", "'", "”", "’", ")", "]", "»"]
        var characters = Array(TextScanning.trim(text))
        while let last = characters.last, closing.contains(last) {
            characters.removeLast()
        }
        guard let last = characters.last else { return false }
        return last == "." || last == "?" || last == "!"
    }

    static func startsWithCapital(_ text: String) -> Bool {
        guard let first = text.first(where: { $0.isLetter || $0.isNumber }) else { return true }
        return !first.isLowercase
    }

    static func hasDialectTag(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("(ame)") || lower.contains("(bre)")
    }
}
