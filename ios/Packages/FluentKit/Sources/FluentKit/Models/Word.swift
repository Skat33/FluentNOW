import Foundation

/// A saved English word or phrase with one or more meanings (web `Word`).
public struct Word: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var en: String
    public var ipa: String
    /// Polish part of speech (e.g. „czasownik”).
    public var pos: String
    /// CEFR level ("" when unknown).
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
    /// Creation time (ms).
    public var created: Timestamp
    /// Last edit / answer time (ms); used to resolve sync conflicts.
    public var updatedAt: Timestamp?
    public var meanings: [Meaning]

    public init(
        id: String,
        en: String,
        ipa: String = "",
        pos: String = "",
        level: String = "",
        collection: String,
        tags: [String] = [],
        source: String = "",
        note: String = "",
        forms: String = "",
        collocations: String = "",
        synonyms: String = "",
        antonyms: String = "",
        important: Bool = false,
        hard: Bool = false,
        archived: Bool = false,
        created: Timestamp,
        updatedAt: Timestamp? = nil,
        meanings: [Meaning] = []
    ) {
        self.id = id
        self.en = en
        self.ipa = ipa
        self.pos = pos
        self.level = level
        self.collection = collection
        self.tags = tags
        self.source = source
        self.note = note
        self.forms = forms
        self.collocations = collocations
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.important = important
        self.hard = hard
        self.archived = archived
        self.created = created
        self.updatedAt = updatedAt
        self.meanings = meanings
    }

    enum CodingKeys: String, CodingKey {
        case id, en, ipa, pos, level, collection, tags, source, note, forms, collocations, synonyms, antonyms
        case important, hard, archived, created, updatedAt, meanings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        en = try c.decode(String.self, forKey: .en)
        meanings = try c.decode([Meaning].self, forKey: .meanings, default: [])
        ipa = c.lenientString(.ipa)
        pos = c.lenientString(.pos)
        level = c.lenientString(.level)
        collection = c.lenientString(.collection)
        tags = c.lenientStrings(.tags)
        source = c.lenientString(.source)
        note = c.lenientString(.note)
        forms = c.lenientString(.forms)
        collocations = c.lenientString(.collocations)
        synonyms = c.lenientString(.synonyms)
        antonyms = c.lenientString(.antonyms)
        important = c.lenientBool(.important)
        hard = c.lenientBool(.hard)
        archived = c.lenientBool(.archived)
        created = c.lenientDouble(.created)
        updatedAt = c.lenientOptionalDouble(.updatedAt)
    }

    /// Finds a meaning by id.
    public func meaning(id meaningID: String) -> Meaning? {
        meanings.first { $0.id == meaningID }
    }
}
