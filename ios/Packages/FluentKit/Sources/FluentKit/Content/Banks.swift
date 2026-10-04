import Foundation

/// `dictionary-index.json` (CONTENT-SCHEMA §3).
public struct DictionaryIndex: Codable, Sendable, Hashable {
    /// One record = one meaning of one term.
    public struct Entry: Codable, Sendable, Hashable {
        /// Term as written (`t`).
        public var term: String
        /// Normalised key (`k`).
        public var key: String
        /// Polish translation (`p`).
        public var translation: String
        /// CEFR level (`l`).
        public var level: String
        /// Frequency raw value (`f`).
        public var frequency: String
        /// Reference `<file>/<entry id>` (`r`).
        public var reference: String

        public init(term: String, key: String? = nil, translation: String, level: String = "", frequency: String = "", reference: String) {
            self.term = term
            self.key = key ?? TextNormalizer.searchKey(term)
            self.translation = translation
            self.level = level
            self.frequency = frequency
            self.reference = reference
        }

        enum CodingKeys: String, CodingKey {
            case term = "t"
            case key = "k"
            case translation = "p"
            case level = "l"
            case frequency = "f"
            case reference = "r"
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            term = try c.decode(String.self, forKey: .term)
            let rawKey = c.lenientString(.key)
            key = rawKey.isEmpty ? TextNormalizer.searchKey(term) : rawKey
            translation = c.lenientString(.translation)
            level = c.lenientString(.level)
            frequency = c.lenientString(.frequency)
            reference = c.lenientString(.reference)
        }

        /// Parsed reference.
        public var contentReference: ContentReference? { ContentReference(reference) }

        /// Parsed frequency.
        public var spokenFrequency: SpokenFrequency? { SpokenFrequency(rawValue: frequency) }
    }

    public var schemaVersion: Int
    public var entries: [Entry]

    public init(schemaVersion: Int = 1, entries: [Entry] = []) {
        self.schemaVersion = schemaVersion
        self.entries = entries
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, entries
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        entries = c.lossyArray(Entry.self, forKey: .entries)
    }
}

/// One CEFR level of the grammar bank: `grammar/<level>.json` (CONTENT-SCHEMA §5.1).
public struct GrammarLevelFile: Codable, Sendable, Hashable {
    public var schemaVersion: Int
    public var version: Int
    public var level: String
    /// Constructions allowed at this level (`productionRules[level]`).
    public var rules: [String]
    public var items: [ProductionItem]

    public init(schemaVersion: Int = 1, version: Int = 36, level: String, rules: [String] = [], items: [ProductionItem] = []) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.level = level
        self.rules = rules
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, version, level, rules, items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        version = c.lenientInt(.version, default: 36)
        level = try c.decode(String.self, forKey: .level)
        rules = c.lenientStrings(.rules)
        items = c.lossyArray(ProductionItem.self, forKey: .items)
    }
}

/// Production items per level: `exercises.json` (§5.2). Also used to hold the merged grammar bank.
public struct ProductionBank: Codable, Sendable, Hashable {
    public var schemaVersion: Int
    public var version: Int
    public var levels: [String: [ProductionItem]]

    public init(schemaVersion: Int = 1, version: Int = 1, levels: [String: [ProductionItem]] = [:]) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.levels = levels
    }

    /// Builds a bank from the per-level grammar files.
    public init(grammarFiles: [GrammarLevelFile]) {
        var levels: [String: [ProductionItem]] = [:]
        var version = 36
        for file in grammarFiles {
            levels[file.level, default: []].append(contentsOf: file.items)
            version = file.version
        }
        self.init(schemaVersion: 1, version: version, levels: levels)
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, version, levels
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        version = c.lenientInt(.version, default: 1)
        levels = ProductionBank.decodeLevels(c, key: .levels)
    }

    static func decodeLevels(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> [String: [ProductionItem]] {
        guard let raw = try? c.decodeIfPresent([String: [FailableDecodable<ProductionItem>]].self, forKey: key) else {
            return [:]
        }
        var result: [String: [ProductionItem]] = [:]
        for (level, boxes) in raw {
            result[level] = boxes.compactMap { $0.value }
        }
        return result
    }

    /// Items of a level (empty when missing).
    public func items(level: String) -> [ProductionItem] {
        levels[level] ?? []
    }
}

/// Idiom questions per level: `idioms.json` (§5.3). `answer` is always 0 in the file.
public struct IdiomBank: Codable, Sendable, Hashable {
    public var schemaVersion: Int
    public var levels: [String: [PracticeQuestion]]

    public init(schemaVersion: Int = 1, levels: [String: [PracticeQuestion]] = [:]) {
        self.schemaVersion = schemaVersion
        self.levels = levels
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, levels
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        var result: [String: [PracticeQuestion]] = [:]
        if let raw = try? c.decodeIfPresent([String: [FailableDecodable<PracticeQuestion>]].self, forKey: .levels) {
            for (level, boxes) in raw {
                result[level] = boxes.compactMap { $0.value }
            }
        }
        levels = result
    }

    public func items(level: String) -> [PracticeQuestion] {
        levels[level] ?? []
    }
}

/// `readings.json` (§5.4).
public struct ReadingBank: Codable, Sendable, Hashable {
    public var schemaVersion: Int
    public var readings: [Reading]

    public init(schemaVersion: Int = 1, readings: [Reading] = []) {
        self.schemaVersion = schemaVersion
        self.readings = readings
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, readings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        readings = c.lossyArray(Reading.self, forKey: .readings)
    }
}

/// `starter-words.json` (§5.5).
public struct StarterWords: Codable, Sendable, Hashable {
    public var schemaVersion: Int
    public var words: [TopicEntry]

    public init(schemaVersion: Int = 1, words: [TopicEntry] = []) {
        self.schemaVersion = schemaVersion
        self.words = words
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, words
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        words = c.lossyArray(TopicEntry.self, forKey: .words)
    }
}

/// `recommendations.json` (§5.6).
public struct RecommendationBank: Codable, Sendable, Hashable {
    public var schemaVersion: Int
    public var items: [Recommendation]

    public init(schemaVersion: Int = 1, items: [Recommendation] = []) {
        self.schemaVersion = schemaVersion
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = c.lenientInt(.schemaVersion, default: 1)
        items = c.lossyArray(Recommendation.self, forKey: .items)
    }
}
