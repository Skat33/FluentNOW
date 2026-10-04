import Foundation

/// Known grammar error categories of a distractor (web `ProductionDiagnosis`).
public enum ProductionDiagnosis: String, Codable, CaseIterable, Sendable, Hashable {
    case wrongTense = "wrong_tense"
    case wrongAspect = "wrong_aspect"
    case wrongVoice = "wrong_voice"
    case wrongAgreement = "wrong_agreement"
    case wrongWord = "wrong_word"
}

/// A known wrong form with its explanation.
public struct ProductionDistractor: Codable, Sendable, Hashable {
    public var form: String
    public var diagnosis: ProductionDiagnosis
    public var explanation: String

    public init(form: String, diagnosis: ProductionDiagnosis, explanation: String) {
        self.form = form
        self.diagnosis = diagnosis
        self.explanation = explanation
    }

    enum CodingKeys: String, CodingKey {
        case form, diagnosis, explanation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        form = try c.decode(String.self, forKey: .form)
        diagnosis = ProductionDiagnosis(rawValue: c.lenientString(.diagnosis, default: "wrong_word")) ?? .wrongWord
        explanation = c.lenientString(.explanation)
    }
}

/// A gap-fill grammar task (web `ProductionItem`). `context` contains `________ (hint)`.
public struct ProductionItem: Codable, Sendable, Hashable {
    public var bankId: String?
    public var scenarioId: String?
    public var context: String
    /// Polish infinitive shown in the gap.
    public var hintPl: String
    public var answer: String
    public var acceptedAnswers: [String]
    public var distractors: [ProductionDistractor]
    /// Grammar construction (e.g. "present perfect").
    public var rule: String
    public var explanation: String
    public var translation: String

    public init(
        bankId: String? = nil,
        scenarioId: String? = nil,
        context: String,
        hintPl: String = "",
        answer: String,
        acceptedAnswers: [String] = [],
        distractors: [ProductionDistractor] = [],
        rule: String,
        explanation: String = "",
        translation: String = ""
    ) {
        self.bankId = bankId
        self.scenarioId = scenarioId
        self.context = context
        self.hintPl = hintPl
        self.answer = answer
        self.acceptedAnswers = acceptedAnswers
        self.distractors = distractors
        self.rule = rule
        self.explanation = explanation
        self.translation = translation
    }

    enum CodingKeys: String, CodingKey {
        case bankId, scenarioId, context, hintPl, answer, acceptedAnswers, distractors, rule, explanation, translation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bankId = c.lenientOptionalString(.bankId)
        scenarioId = c.lenientOptionalString(.scenarioId)
        context = try c.decode(String.self, forKey: .context)
        hintPl = c.lenientString(.hintPl)
        answer = try c.decode(String.self, forKey: .answer)
        acceptedAnswers = c.lenientStrings(.acceptedAnswers)
        distractors = c.lossyArray(ProductionDistractor.self, forKey: .distractors)
        rule = c.lenientString(.rule)
        explanation = c.lenientString(.explanation)
        translation = c.lenientString(.translation)
    }
}

/// A set of production tasks (web `ProductionSet`).
public struct ProductionSet: Codable, Sendable, Hashable {
    public var title: String
    public var level: String
    public var items: [ProductionItem]

    public init(title: String, level: String, items: [ProductionItem]) {
        self.title = title
        self.level = level
        self.items = items
    }
}

/// Diagnosis of a graded production answer: a known error, `spelling`, `general`.
public enum ProductionResultDiagnosis: String, Codable, CaseIterable, Sendable, Hashable {
    case wrongTense = "wrong_tense"
    case wrongAspect = "wrong_aspect"
    case wrongVoice = "wrong_voice"
    case wrongAgreement = "wrong_agreement"
    case wrongWord = "wrong_word"
    case spelling
    case general

    public init(_ diagnosis: ProductionDiagnosis) {
        switch diagnosis {
        case .wrongTense: self = .wrongTense
        case .wrongAspect: self = .wrongAspect
        case .wrongVoice: self = .wrongVoice
        case .wrongAgreement: self = .wrongAgreement
        case .wrongWord: self = .wrongWord
        }
    }

    /// Polish label for the result screen.
    public var namePl: String {
        switch self {
        case .wrongTense: return "Zły czas"
        case .wrongAspect: return "Zły aspekt"
        case .wrongVoice: return "Zła strona"
        case .wrongAgreement: return "Brak zgodności"
        case .wrongWord: return "Zła forma"
        case .spelling: return "Pisownia"
        case .general: return "Błąd"
        }
    }
}

/// Result of `gradeProduction` (web `ProductionResult`).
public struct ProductionResult: Codable, Sendable, Hashable {
    public var correct: Bool
    public var spellingCorrect: Bool
    public var diagnosis: ProductionResultDiagnosis?
    public var explanation: String

    public init(correct: Bool, spellingCorrect: Bool, diagnosis: ProductionResultDiagnosis?, explanation: String) {
        self.correct = correct
        self.spellingCorrect = spellingCorrect
        self.diagnosis = diagnosis
        self.explanation = explanation
    }

    enum CodingKeys: String, CodingKey {
        case correct, spellingCorrect, diagnosis, explanation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        correct = c.lenientBool(.correct)
        spellingCorrect = c.lenientBool(.spellingCorrect, default: true)
        diagnosis = c.lenientOptionalString(.diagnosis).flatMap { ProductionResultDiagnosis(rawValue: $0) }
        explanation = c.lenientString(.explanation)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(correct, forKey: .correct)
        try c.encode(spellingCorrect, forKey: .spellingCorrect)
        // The web schema requires the key (nullable).
        if let diagnosis {
            try c.encode(diagnosis, forKey: .diagnosis)
        } else {
            try c.encodeNil(forKey: .diagnosis)
        }
        try c.encode(explanation, forKey: .explanation)
    }
}

/// A production set in progress (web `ProductionSession`).
public struct ProductionSession: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var set: ProductionSet
    public var source: ContentSource
    public var index: Int
    public var answers: [String]
    public var results: [ProductionResult?]
    public var completedAt: Timestamp?

    public init(
        id: String,
        set: ProductionSet,
        source: ContentSource = .starter,
        index: Int = 0,
        answers: [String]? = nil,
        results: [ProductionResult?]? = nil,
        completedAt: Timestamp? = nil
    ) {
        self.id = id
        self.set = set
        self.source = source
        self.index = index
        self.answers = answers ?? Array(repeating: "", count: set.items.count)
        self.results = results ?? Array(repeating: nil, count: set.items.count)
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case id, set, source, index, answers, results, completedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id)
        set = try c.decode(ProductionSet.self, forKey: .set)
        source = ContentSource(rawValue: c.lenientString(.source, default: "starter")) ?? .starter
        index = max(0, c.lenientInt(.index))
        answers = c.lenientStrings(.answers)
        results = (try? c.decodeIfPresent([ProductionResult?].self, forKey: .results)) ?? []
        completedAt = c.lenientOptionalDouble(.completedAt)
    }
}
