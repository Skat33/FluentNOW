import Foundation

/// One built-in vocabulary entry (CONTENT-SCHEMA §1 „Entry”; also used by `starter-words.json`).
public struct TopicEntry: Codable, Sendable, Hashable, Identifiable {
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

    public init(
        id: String,
        term: String,
        ipa: String = "",
        pos: String = "",
        level: String = "",
        frequency: SpokenFrequency? = nil,
        translation: String,
        definition: String = "",
        register: String = "neutralny",
        contextPl: String = "",
        natural: String = "",
        forms: String = "",
        collocations: String = "",
        synonyms: String = "",
        antonyms: String = "",
        notePl: String = "",
        examples: [ExamplePair] = [],
        acceptedAnswers: [String] = [],
        acceptedTranslations: [String] = []
    ) {
        self.id = id
        self.term = term
        self.ipa = ipa
        self.pos = pos
        self.level = level
        self.frequency = frequency
        self.translation = translation
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

    enum CodingKeys: String, CodingKey {
        case id, term, ipa, pos, level, frequency, translation, definition, register, contextPl, natural
        case forms, collocations, synonyms, antonyms, notePl, examples, acceptedAnswers, acceptedTranslations
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        term = try c.decode(String.self, forKey: .term)
        translation = try c.decode(String.self, forKey: .translation)
        ipa = c.lenientString(.ipa)
        pos = c.lenientString(.pos)
        level = c.lenientString(.level)
        frequency = c.lenientOptionalString(.frequency).flatMap { SpokenFrequency(rawValue: $0) }
        definition = c.lenientString(.definition)
        register = c.lenientString(.register, default: "neutralny")
        contextPl = c.lenientString(.contextPl)
        natural = c.lenientString(.natural)
        forms = c.lenientString(.forms)
        collocations = c.lenientString(.collocations)
        synonyms = c.lenientString(.synonyms)
        antonyms = c.lenientString(.antonyms)
        notePl = c.lenientString(.notePl)
        examples = c.lossyArray(ExamplePair.self, forKey: .examples)
        acceptedAnswers = c.lenientStrings(.acceptedAnswers)
        acceptedTranslations = c.lenientStrings(.acceptedTranslations)
    }
}

/// A category (situation) of a topic.
public struct TopicCategory: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var namePl: String
    public var scenePl: String
    public var entries: [TopicEntry]

    public init(id: String, namePl: String, scenePl: String = "", entries: [TopicEntry] = []) {
        self.id = id
        self.namePl = namePl
        self.scenePl = scenePl
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case id, namePl, scenePl, entries
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        namePl = c.lenientString(.namePl)
        scenePl = c.lenientString(.scenePl)
        entries = c.lossyArray(TopicEntry.self, forKey: .entries)
    }
}

/// A topic file `topics/<id>.json` (CONTENT-SCHEMA §1).
public struct TopicFile: Codable, Sendable, Hashable, Identifiable {
    public var schemaVersion: Int
    public var id: String
    public var namePl: String
    public var nameEn: String
    public var group: String
    public var symbol: String
    public var summaryPl: String
    public var aliases: [String]
    public var categories: [TopicCategory]

    public init(schemaVersion: Int = 1, id: String, namePl: String, nameEn: String = "", group: String = "", symbol: String = "", summaryPl: String = "", aliases: [String] = [], categories: [TopicCategory] = []) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.namePl = namePl
        self.nameEn = nameEn
        self.group = group
        self.symbol = symbol
        self.summaryPl = summaryPl
        self.aliases = aliases
        self.categories = categories
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, id, namePl, nameEn, group, symbol, summaryPl, aliases, categories
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        id = try c.decode(String.self, forKey: .id)
        namePl = c.lenientString(.namePl)
        nameEn = c.lenientString(.nameEn)
        group = c.lenientString(.group)
        symbol = c.lenientString(.symbol)
        summaryPl = c.lenientString(.summaryPl)
        aliases = c.lenientStrings(.aliases)
        categories = c.lossyArray(TopicCategory.self, forKey: .categories)
    }

    /// All entries in file order.
    public var allEntries: [TopicEntry] {
        categories.flatMap { $0.entries }
    }

    /// Number of entries.
    public var entryCount: Int {
        categories.reduce(0) { $0 + $1.entries.count }
    }

    /// Entry and its category by entry id.
    public func entry(id entryID: String) -> (entry: TopicEntry, category: TopicCategory)? {
        for category in categories {
            if let entry = category.entries.first(where: { $0.id == entryID }) {
                return (entry, category)
            }
        }
        return nil
    }
}

/// A topic group of the index (CONTENT-SCHEMA §2).
public struct TopicGroup: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var namePl: String
    public var symbol: String

    public init(id: String, namePl: String, symbol: String) {
        self.id = id
        self.namePl = namePl
        self.symbol = symbol
    }
}

/// Category summary inside the topic index.
public struct TopicCategorySummary: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var namePl: String
    public var entryCount: Int

    public init(id: String, namePl: String, entryCount: Int) {
        self.id = id
        self.namePl = namePl
        self.entryCount = entryCount
    }
}

/// Topic summary inside the topic index.
public struct TopicSummary: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var namePl: String
    public var nameEn: String
    public var group: String
    public var symbol: String
    public var summaryPl: String
    public var aliases: [String]
    public var entryCount: Int
    /// Number of entries per CEFR level ("A1"…"C2").
    public var levels: [String: Int]
    public var categories: [TopicCategorySummary]

    public init(id: String, namePl: String, nameEn: String = "", group: String = "", symbol: String = "", summaryPl: String = "", aliases: [String] = [], entryCount: Int = 0, levels: [String: Int] = [:], categories: [TopicCategorySummary] = []) {
        self.id = id
        self.namePl = namePl
        self.nameEn = nameEn
        self.group = group
        self.symbol = symbol
        self.summaryPl = summaryPl
        self.aliases = aliases
        self.entryCount = entryCount
        self.levels = levels
        self.categories = categories
    }

    enum CodingKeys: String, CodingKey {
        case id, namePl, nameEn, group, symbol, summaryPl, aliases, entryCount, levels, categories
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        namePl = c.lenientString(.namePl)
        nameEn = c.lenientString(.nameEn)
        group = c.lenientString(.group)
        symbol = c.lenientString(.symbol)
        summaryPl = c.lenientString(.summaryPl)
        aliases = c.lenientStrings(.aliases)
        entryCount = c.lenientInt(.entryCount)
        levels = (try? c.decodeIfPresent([String: Int].self, forKey: .levels)) ?? [:]
        categories = c.lossyArray(TopicCategorySummary.self, forKey: .categories)
    }

    /// Matches a free-text query against names and aliases (diacritics- and case-insensitive).
    public func matches(_ query: String) -> Bool {
        let key = TextNormalizer.searchKey(query)
        guard !key.isEmpty else { return true }
        return ([namePl, nameEn, summaryPl] + aliases).contains { TextNormalizer.searchKey($0).contains(key) }
    }
}

/// `topics/index.json` (CONTENT-SCHEMA §2).
public struct TopicIndex: Codable, Sendable, Hashable {
    public var schemaVersion: Int
    public var generatedAt: String
    public var groups: [TopicGroup]
    public var topics: [TopicSummary]

    public init(schemaVersion: Int = 1, generatedAt: String = "", groups: [TopicGroup] = [], topics: [TopicSummary] = []) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.groups = groups
        self.topics = topics
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, groups, topics
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        generatedAt = c.lenientString(.generatedAt)
        groups = c.lossyArray(TopicGroup.self, forKey: .groups)
        topics = c.lossyArray(TopicSummary.self, forKey: .topics)
    }

    /// Topics of one group in index order.
    public func topics(inGroup groupID: String) -> [TopicSummary] {
        topics.filter { $0.group == groupID }
    }
}

/// Reference to a built-in entry: `r` of the dictionary index (`<file>/<entry id>`).
public struct ContentReference: Sendable, Hashable {
    /// Topic file name without `.json`, or `starter` for `starter-words.json`.
    public var file: String
    public var entryID: String

    public init(file: String, entryID: String) {
        self.file = file
        self.entryID = entryID
    }

    /// Parses `airport/airport.boarding-pass`.
    public init?(_ raw: String) {
        guard let slash = raw.firstIndex(of: "/") else { return nil }
        let file = String(raw[raw.startIndex..<slash])
        let entry = String(raw[raw.index(after: slash)...])
        guard !file.isEmpty, !entry.isEmpty else { return nil }
        self.file = file
        self.entryID = entry
    }

    /// `true` for entries of `starter-words.json`.
    public var isStarter: Bool { file == "starter" }

    /// Raw form `file/entryID`.
    public var rawValue: String { "\(file)/\(entryID)" }
}
