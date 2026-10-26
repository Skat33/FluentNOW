import Foundation

/// An example sentence with its Polish translation and the highlighted parts (web `ExamplePair`).
/// `focusEn` / `focusPl` are exact substrings of `en` / `pl`.
public struct ExamplePair: Codable, Sendable, Hashable {
    public var en: String
    public var pl: String
    public var focusEn: String
    public var focusPl: String

    public init(en: String, pl: String, focusEn: String, focusPl: String) {
        self.en = en
        self.pl = pl
        self.focusEn = focusEn
        self.focusPl = focusPl
    }

    enum CodingKeys: String, CodingKey {
        case en, pl, focusEn, focusPl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        en = try c.decode(String.self, forKey: .en)
        pl = c.lenientString(.pl)
        focusEn = c.lenientString(.focusEn)
        focusPl = c.lenientString(.focusPl)
    }
}

/// A proposed meaning of a looked-up term (web `SenseSuggestion`).
public struct SenseSuggestion: Codable, Sendable, Hashable {
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
    /// Suggested collection name.
    public var collection: String
    public var examples: [ExamplePair]
    public var acceptedTranslations: [String]?
    public var acceptedAnswers: [String]
    /// iOS addition: built-in content reference (`<file>/<entry id>`).
    public var contentRef: String?
    /// iOS addition (FEEDBACK-8 M3): references of other built-in entries grouped into this
    /// sense (the same meaning in several topics / core) — kept on the created `Meaning`, so the
    /// grouped entries count as owned. `nil` when nothing was grouped.
    public var mergedContentRefs: [String]?

    public init(
        needsDetails: Bool? = nil,
        topic: String? = nil,
        scene: String? = nil,
        translation: String,
        definition: String = "",
        pos: String = "",
        level: String = "",
        levelConfidence: LevelConfidence? = nil,
        levelReason: String? = nil,
        spokenFrequency: SpokenFrequency? = nil,
        context: String = "",
        register: String = "neutralny",
        natural: String = "",
        collection: String = "",
        examples: [ExamplePair] = [],
        acceptedTranslations: [String]? = nil,
        acceptedAnswers: [String] = [],
        contentRef: String? = nil,
        mergedContentRefs: [String]? = nil
    ) {
        self.mergedContentRefs = mergedContentRefs
        self.needsDetails = needsDetails
        self.topic = topic
        self.scene = scene
        self.translation = translation
        self.definition = definition
        self.pos = pos
        self.level = level
        self.levelConfidence = levelConfidence
        self.levelReason = levelReason
        self.spokenFrequency = spokenFrequency
        self.context = context
        self.register = register
        self.natural = natural
        self.collection = collection
        self.examples = examples
        self.acceptedTranslations = acceptedTranslations
        self.acceptedAnswers = acceptedAnswers
        self.contentRef = contentRef
    }

    enum CodingKeys: String, CodingKey {
        case needsDetails, topic, scene, translation, definition, pos, level, levelConfidence, levelReason
        case spokenFrequency, context, register, natural, collection, examples, acceptedTranslations, acceptedAnswers, contentRef
        case mergedContentRefs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        needsDetails = (try? c.decodeIfPresent(Bool.self, forKey: .needsDetails)) ?? nil
        topic = c.lenientOptionalString(.topic)
        scene = c.lenientOptionalString(.scene)
        translation = try c.decode(String.self, forKey: .translation)
        definition = c.lenientString(.definition)
        pos = c.lenientString(.pos)
        level = c.lenientString(.level)
        levelConfidence = c.lenientOptionalString(.levelConfidence).flatMap { LevelConfidence(rawValue: $0) }
        levelReason = c.lenientOptionalString(.levelReason)
        spokenFrequency = c.lenientOptionalString(.spokenFrequency).flatMap { SpokenFrequency(rawValue: $0) }
        context = c.lenientString(.context)
        register = c.lenientString(.register, default: "neutralny")
        natural = c.lenientString(.natural)
        collection = c.lenientString(.collection)
        examples = c.lossyArray(ExamplePair.self, forKey: .examples)
        acceptedTranslations = c.lenientOptionalStrings(.acceptedTranslations)
        acceptedAnswers = c.lenientStrings(.acceptedAnswers)
        contentRef = c.lenientOptionalString(.contentRef)
        mergedContentRefs = c.lenientOptionalStrings(.mergedContentRefs)
    }
}

/// Result of looking up a term (web `Lookup`) — from built-in content or an AI assistant.
public struct Lookup: Codable, Sendable, Hashable {
    public var exists: Bool
    public var term: String
    public var ipa: String
    public var forms: String
    public var collocations: String
    public var synonyms: String
    public var antonyms: String
    public var note: String
    /// Spelling alternatives when the term does not exist.
    public var alternatives: [String]
    public var meanings: [SenseSuggestion]
    public var source: ContentSource

    public init(
        exists: Bool = true,
        term: String,
        ipa: String = "",
        forms: String = "",
        collocations: String = "",
        synonyms: String = "",
        antonyms: String = "",
        note: String = "",
        alternatives: [String] = [],
        meanings: [SenseSuggestion] = [],
        source: ContentSource = .starter
    ) {
        self.exists = exists
        self.term = term
        self.ipa = ipa
        self.forms = forms
        self.collocations = collocations
        self.synonyms = synonyms
        self.antonyms = antonyms
        self.note = note
        self.alternatives = alternatives
        self.meanings = meanings
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case exists, term, ipa, forms, collocations, synonyms, antonyms, note, alternatives, meanings, source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exists = c.lenientBool(.exists, default: true)
        term = try c.decode(String.self, forKey: .term)
        ipa = c.lenientString(.ipa)
        forms = c.lenientString(.forms)
        collocations = c.lenientString(.collocations)
        synonyms = c.lenientString(.synonyms)
        antonyms = c.lenientString(.antonyms)
        note = c.lenientString(.note)
        alternatives = c.lenientStrings(.alternatives)
        meanings = c.lossyArray(SenseSuggestion.self, forKey: .meanings)
        source = ContentSource(rawValue: c.lenientString(.source, default: "ai")) ?? .ai
    }
}

/// Verdict of grading a typed answer.
public enum GradeVerdict: String, Codable, CaseIterable, Sendable, Hashable {
    case correct
    case incorrect
    /// Ambiguous — must never be scored as a failure.
    case uncertain
}

/// Who graded the answer.
public enum GradeSource: String, Codable, CaseIterable, Sendable, Hashable {
    case ai
    case local
}

/// Grading result (web `Grade`).
public struct Grade: Codable, Sendable, Hashable {
    public var verdict: GradeVerdict
    /// Polish explanation.
    public var explanation: String
    public var spellingCorrect: Bool
    public var source: GradeSource
    /// iOS addition: the accepted answer the learner most likely meant when the answer looks
    /// like a typo (edit distance 1–2). The answer is still graded `incorrect` (web v38 policy);
    /// the UI may show „Literówka? Poprawnie: …” and let the learner accept it manually.
    public var closestAnswer: String?

    public init(verdict: GradeVerdict, explanation: String, spellingCorrect: Bool, source: GradeSource = .local, closestAnswer: String? = nil) {
        self.verdict = verdict
        self.explanation = explanation
        self.spellingCorrect = spellingCorrect
        self.source = source
        self.closestAnswer = closestAnswer
    }

    /// `true` only for `.incorrect`. Uncertain grades never count as a failure.
    public var isFailure: Bool { verdict == .incorrect }

    /// `true` for `.correct`.
    public var isCorrect: Bool { verdict == .correct }

    enum CodingKeys: String, CodingKey {
        case verdict, explanation, spellingCorrect, source, closestAnswer
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        verdict = GradeVerdict(rawValue: c.lenientString(.verdict, default: "uncertain")) ?? .uncertain
        explanation = c.lenientString(.explanation)
        spellingCorrect = c.lenientBool(.spellingCorrect, default: true)
        source = GradeSource(rawValue: c.lenientString(.source, default: "ai")) ?? .ai
        closestAnswer = c.lenientOptionalString(.closestAnswer)
    }
}

/// A harder related word suggested after mastering a known one (web `Recommendation`).
public struct Recommendation: Codable, Sendable, Hashable {
    /// The already known word.
    public var known: String
    public var term: String
    public var level: String
    public var translation: String
    /// Polish explanation of the difference.
    public var difference: String
    public var example: String
    public var examplePl: String
    /// Optional extras for the built-in bank (IPA and highlighted Polish fragment).
    public var ipa: String?
    public var focusPl: String?

    public init(known: String, term: String, level: String, translation: String, difference: String, example: String, examplePl: String, ipa: String? = nil, focusPl: String? = nil) {
        self.known = known
        self.term = term
        self.level = level
        self.translation = translation
        self.difference = difference
        self.example = example
        self.examplePl = examplePl
        self.ipa = ipa
        self.focusPl = focusPl
    }

    enum CodingKeys: String, CodingKey {
        case known, term, level, translation, difference, example, examplePl, ipa, focusPl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        known = try c.decode(String.self, forKey: .known)
        term = try c.decode(String.self, forKey: .term)
        level = c.lenientString(.level)
        translation = c.lenientString(.translation)
        difference = c.lenientString(.difference)
        example = c.lenientString(.example)
        examplePl = c.lenientString(.examplePl)
        ipa = c.lenientOptionalString(.ipa)
        focusPl = c.lenientOptionalString(.focusPl)
    }
}
