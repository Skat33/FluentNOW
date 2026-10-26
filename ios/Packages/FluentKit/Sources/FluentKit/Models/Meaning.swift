import Foundation

/// Phase of AI example enrichment (web `Meaning.enrichment.phase`).
public enum EnrichmentPhase: String, Codable, CaseIterable, Sendable, Hashable {
    case details
    case examples
    case ready
}

/// Group of generated example sentences.
public enum ExampleGroup: String, Codable, CaseIterable, Sendable, Hashable {
    case affirmative
    case negative
    case question
}

/// State of the example pool generation for one meaning (web v34–v35).
/// Meanings without enrichment (built-in content, imports) use all their examples.
public struct Enrichment: Codable, Sendable, Hashable {
    public var round: Int?
    public var phase: EnrichmentPhase
    public var detailsPending: Bool?
    public var groups: [ExampleGroup]
    public var attempts: Int
    public var retryAt: Timestamp
    public var error: String?

    public init(
        round: Int? = nil,
        phase: EnrichmentPhase = .examples,
        detailsPending: Bool? = nil,
        groups: [ExampleGroup] = [],
        attempts: Int = 0,
        retryAt: Timestamp = 0,
        error: String? = nil
    ) {
        self.round = round
        self.phase = phase
        self.detailsPending = detailsPending
        self.groups = groups
        self.attempts = attempts
        self.retryAt = retryAt
        self.error = error
    }

    enum CodingKeys: String, CodingKey {
        case round, phase, detailsPending, groups, attempts, retryAt, error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        round = c.lenientOptionalInt(.round)
        phase = EnrichmentPhase(rawValue: c.lenientString(.phase, default: "ready")) ?? .ready
        detailsPending = (try? c.decodeIfPresent(Bool.self, forKey: .detailsPending)) ?? nil
        groups = c.lenientStrings(.groups).compactMap { ExampleGroup(rawValue: $0) }
        attempts = max(0, c.lenientInt(.attempts))
        retryAt = max(0, c.lenientDouble(.retryAt))
        error = c.lenientOptionalString(.error)
    }
}

/// One concrete sense of a word — the unit of learning (web `Meaning`).
public struct Meaning: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    /// Thematic context (e.g. topic or category name).
    public var topic: String?
    /// Concrete scene the examples are set in.
    public var scene: String?
    /// Indices of examples already used in exercises.
    public var usedExamples: [Int]?
    public var enrichment: Enrichment?
    /// Polish translations of `examples` (same indices).
    public var exampleTranslations: [String]?
    /// Exact English focus substring for each example.
    public var exampleFocusEn: [String]?
    /// Exact Polish focus substring for each example translation.
    public var exampleFocusPl: [String]?
    /// Extra English answers accepted in recall.
    public var acceptedAnswers: [String]?
    /// Extra Polish answers accepted in the meaning exercise.
    public var acceptedTranslations: [String]?
    /// CEFR level of this sense (falls back to `Word.level`).
    public var level: String?
    public var levelConfidence: LevelConfidence?
    public var levelReason: String?
    public var spokenFrequency: SpokenFrequency?
    /// Part of speech of this sense (falls back to `Word.pos`).
    public var pos: String?
    public var translation: String
    public var definition: String
    public var examples: [String]
    public var context: String
    public var register: String
    public var natural: String
    public var scores: SkillScores
    /// iOS addition: reference to the built-in content entry this meaning came from
    /// (`<topic file>/<entry id>`, see `ContentReference`). Ignored by the web app.
    public var contentRef: String?
    /// iOS addition (FEEDBACK-8 M3): references of other built-in entries with the same meaning
    /// that were grouped into this one when it was added (e.g. *catch up* „nadrobić zaległości”
    /// from three topics). They count as owned (`OwnedVocabulary`). Ignored by the web app;
    /// absent in older data (`nil`).
    public var mergedContentRefs: [String]?

    public init(
        id: String,
        topic: String? = nil,
        scene: String? = nil,
        usedExamples: [Int]? = nil,
        enrichment: Enrichment? = nil,
        exampleTranslations: [String]? = nil,
        exampleFocusEn: [String]? = nil,
        exampleFocusPl: [String]? = nil,
        acceptedAnswers: [String]? = nil,
        acceptedTranslations: [String]? = nil,
        level: String? = nil,
        levelConfidence: LevelConfidence? = nil,
        levelReason: String? = nil,
        spokenFrequency: SpokenFrequency? = nil,
        pos: String? = nil,
        translation: String,
        definition: String = "",
        examples: [String] = [],
        context: String = "",
        register: String = "neutralny",
        natural: String = "",
        scores: SkillScores = SkillScores(),
        contentRef: String? = nil,
        mergedContentRefs: [String]? = nil
    ) {
        self.mergedContentRefs = mergedContentRefs
        self.id = id
        self.topic = topic
        self.scene = scene
        self.usedExamples = usedExamples
        self.enrichment = enrichment
        self.exampleTranslations = exampleTranslations
        self.exampleFocusEn = exampleFocusEn
        self.exampleFocusPl = exampleFocusPl
        self.acceptedAnswers = acceptedAnswers
        self.acceptedTranslations = acceptedTranslations
        self.level = level
        self.levelConfidence = levelConfidence
        self.levelReason = levelReason
        self.spokenFrequency = spokenFrequency
        self.pos = pos
        self.translation = translation
        self.definition = definition
        self.examples = examples
        self.context = context
        self.register = register
        self.natural = natural
        self.scores = scores
        self.contentRef = contentRef
    }

    enum CodingKeys: String, CodingKey {
        case id, topic, scene, usedExamples, enrichment, exampleTranslations, exampleFocusEn, exampleFocusPl
        case acceptedAnswers, acceptedTranslations, level, levelConfidence, levelReason, spokenFrequency, pos
        case translation, definition, examples, context, register, natural, scores, contentRef
        case mergedContentRefs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        translation = try c.decode(String.self, forKey: .translation)
        topic = c.lenientOptionalString(.topic)
        scene = c.lenientOptionalString(.scene)
        usedExamples = c.lenientOptionalInts(.usedExamples)
        enrichment = c.lenientOptional(Enrichment.self, forKey: .enrichment)
        exampleTranslations = c.lenientOptionalStrings(.exampleTranslations)
        exampleFocusEn = c.lenientOptionalStrings(.exampleFocusEn)
        exampleFocusPl = c.lenientOptionalStrings(.exampleFocusPl)
        acceptedAnswers = c.lenientOptionalStrings(.acceptedAnswers)
        acceptedTranslations = c.lenientOptionalStrings(.acceptedTranslations)
        level = c.lenientOptionalString(.level)
        levelConfidence = c.lenientOptionalString(.levelConfidence).flatMap { LevelConfidence(rawValue: $0) }
        levelReason = c.lenientOptionalString(.levelReason)
        spokenFrequency = c.lenientOptionalString(.spokenFrequency).flatMap { SpokenFrequency(rawValue: $0) }
        pos = c.lenientOptionalString(.pos)
        definition = c.lenientString(.definition)
        examples = c.lenientStrings(.examples)
        context = c.lenientString(.context)
        register = c.lenientString(.register)
        natural = c.lenientString(.natural)
        scores = c.lenientOptional(SkillScores.self, forKey: .scores) ?? SkillScores()
        contentRef = c.lenientOptionalString(.contentRef)
        mergedContentRefs = c.lenientOptionalStrings(.mergedContentRefs)
    }

    /// `contentRef` and `mergedContentRefs` (built-in entries this meaning stands for).
    public var allContentRefs: [String] {
        var result: [String] = []
        if let contentRef, !contentRef.isEmpty { result.append(contentRef) }
        for reference in mergedContentRefs ?? [] where !reference.isEmpty && !result.contains(reference) {
            result.append(reference)
        }
        return result
    }

    /// CEFR level of this sense, falling back to the word level.
    public func effectiveLevel(in word: Word) -> String {
        if let level, !level.isEmpty { return level }
        return word.level
    }

    /// Part of speech of this sense, falling back to the word.
    public func effectivePos(in word: Word) -> String {
        if let pos, !pos.isEmpty { return pos }
        return word.pos
    }
}
