import Foundation

/// Category of a practice question.
public enum PracticeCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case grammar
    case idiom
}

/// Answer format of a practice question.
public enum PracticeFormat: String, Codable, CaseIterable, Sendable, Hashable {
    /// Multiple choice (A–D).
    case choice
    /// Typed answer graded against the key and accepted answers.
    case input
}

/// A grammar or idiom question (web `PracticeQuestion`).
public struct PracticeQuestion: Codable, Sendable, Hashable {
    /// `nil` means multiple choice (legacy sessions).
    public var format: PracticeFormat?
    public var inputHint: String?
    public var acceptedAnswers: [String]?
    public var bankId: String?
    public var scenarioId: String?
    public var category: PracticeCategory
    public var prompt: String
    public var context: String
    public var options: [String]
    public var answer: Int
    public var explanation: String
    public var translation: String

    public init(
        format: PracticeFormat? = nil,
        inputHint: String? = nil,
        acceptedAnswers: [String]? = nil,
        bankId: String? = nil,
        scenarioId: String? = nil,
        category: PracticeCategory,
        prompt: String,
        context: String,
        options: [String],
        answer: Int,
        explanation: String = "",
        translation: String = ""
    ) {
        self.format = format
        self.inputHint = inputHint
        self.acceptedAnswers = acceptedAnswers
        self.bankId = bankId
        self.scenarioId = scenarioId
        self.category = category
        self.prompt = prompt
        self.context = context
        self.options = options
        self.answer = answer
        self.explanation = explanation
        self.translation = translation
    }

    /// `true` when the learner types the answer.
    public var isInput: Bool { format == .input }

    /// The correct option text ("" if the key is out of range).
    public var correctOption: String {
        options[safe: answer] ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case format, inputHint, acceptedAnswers, bankId, scenarioId, category, prompt, context, options, answer, explanation, translation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = c.lenientOptionalString(.format).flatMap { PracticeFormat(rawValue: $0) }
        inputHint = c.lenientOptionalString(.inputHint)
        acceptedAnswers = c.lenientOptionalStrings(.acceptedAnswers)
        bankId = c.lenientOptionalString(.bankId)
        scenarioId = c.lenientOptionalString(.scenarioId)
        category = PracticeCategory(rawValue: c.lenientString(.category, default: "grammar")) ?? .grammar
        prompt = c.lenientString(.prompt)
        context = c.lenientString(.context)
        options = try c.decode([String].self, forKey: .options)
        answer = c.lenientInt(.answer)
        explanation = c.lenientString(.explanation)
        translation = c.lenientString(.translation)
    }
}

/// A set of practice questions (web `PracticeSet`).
public struct PracticeSet: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var level: String
    public var kind: PracticeKind
    public var items: [PracticeQuestion]
    public var source: ContentSource

    public init(id: String, title: String, level: String, kind: PracticeKind, items: [PracticeQuestion], source: ContentSource = .starter) {
        self.id = id
        self.title = title
        self.level = level
        self.kind = kind
        self.items = items
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case id, title, level, kind, items, source
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id)
        title = c.lenientString(.title)
        level = c.lenientString(.level)
        kind = PracticeKind(rawValue: c.lenientString(.kind, default: "grammar")) ?? .grammar
        items = try c.decode([PracticeQuestion].self, forKey: .items)
        source = ContentSource(rawValue: c.lenientString(.source, default: "starter")) ?? .starter
    }
}

/// A practice set in progress (web `PracticeSession`). `answers[i] == -1` = unanswered.
public struct PracticeSession: Codable, Sendable, Hashable {
    public var set: PracticeSet
    /// Typed answers (one per item, "" when none).
    public var writtenAnswers: [String]?
    public var answers: [Int]
    public var index: Int
    public var completedAt: Timestamp?

    public init(set: PracticeSet, writtenAnswers: [String]? = nil, answers: [Int]? = nil, index: Int = 0, completedAt: Timestamp? = nil) {
        self.set = set
        self.writtenAnswers = writtenAnswers ?? Array(repeating: "", count: set.items.count)
        self.answers = answers ?? Array(repeating: -1, count: set.items.count)
        self.index = index
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case set, writtenAnswers, answers, index, completedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        set = try c.decode(PracticeSet.self, forKey: .set)
        writtenAnswers = c.lenientOptionalStrings(.writtenAnswers)
        answers = c.lenientOptionalInts(.answers) ?? []
        index = max(0, c.lenientInt(.index))
        completedAt = c.lenientOptionalDouble(.completedAt)
    }
}
