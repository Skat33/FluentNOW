import Foundation

/// A multiple-choice comprehension question (web `Reading.questions[n]`).
public struct ReadingQuestion: Codable, Sendable, Hashable {
    public var question: String
    public var options: [String]
    /// Index of the correct option.
    public var answer: Int
    /// Polish explanation.
    public var explanation: String
    /// Sentence from the text that supports the answer.
    public var evidence: String
    /// Meaning practiced by this question (word-in-context questions only).
    public var meaningId: String?

    public init(question: String, options: [String], answer: Int, explanation: String = "", evidence: String = "", meaningId: String? = nil) {
        self.question = question
        self.options = options
        self.answer = answer
        self.explanation = explanation
        self.evidence = evidence
        self.meaningId = meaningId
    }

    /// The correct option text ("" if the key is out of range).
    public var correctOption: String {
        options[safe: answer] ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case question, options, answer, explanation, evidence, meaningId
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        question = try c.decode(String.self, forKey: .question)
        options = try c.decode([String].self, forKey: .options)
        answer = c.lenientInt(.answer)
        explanation = c.lenientString(.explanation)
        evidence = c.lenientString(.evidence)
        meaningId = c.lenientOptionalString(.meaningId)
    }
}

/// A reading passage with questions (web `Reading`; `topic` is only set for bank readings).
public struct Reading: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public var level: String
    public var paragraphs: [String]
    public var questions: [ReadingQuestion]
    public var source: ContentSource
    /// Topic keywords of a bank reading (used for topical selection; stripped when selected).
    public var topic: String?

    public init(
        id: String,
        title: String,
        level: String,
        paragraphs: [String],
        questions: [ReadingQuestion],
        source: ContentSource = .starter,
        topic: String? = nil
    ) {
        self.id = id
        self.title = title
        self.level = level
        self.paragraphs = paragraphs
        self.questions = questions
        self.source = source
        self.topic = topic
    }

    enum CodingKeys: String, CodingKey {
        case id, title, level, paragraphs, questions, source, topic
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = c.lenientString(.title)
        level = c.lenientString(.level)
        paragraphs = c.lenientStrings(.paragraphs)
        questions = try c.decode([ReadingQuestion].self, forKey: .questions, default: [])
        source = ContentSource(rawValue: c.lenientString(.source, default: "starter")) ?? .starter
        topic = c.lenientOptionalString(.topic)
    }
}

/// A reading in progress or finished (web `ReadingSession`). `answers[i] == -1` = unanswered.
public struct ReadingSession: Codable, Sendable, Hashable {
    public var reading: Reading
    public var answers: [Int]
    public var submitted: Bool
    public var completedAt: Timestamp?

    public init(reading: Reading, answers: [Int]? = nil, submitted: Bool = false, completedAt: Timestamp? = nil) {
        self.reading = reading
        self.answers = answers ?? Array(repeating: -1, count: reading.questions.count)
        self.submitted = submitted
        self.completedAt = completedAt
    }

    enum CodingKeys: String, CodingKey {
        case reading, answers, submitted, completedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reading = try c.decode(Reading.self, forKey: .reading)
        let decodedAnswers = c.lenientOptionalInts(.answers) ?? []
        // Keep one answer slot per question even if an old export is inconsistent.
        var fixed = Array(decodedAnswers.prefix(reading.questions.count))
        while fixed.count < reading.questions.count { fixed.append(-1) }
        answers = fixed
        submitted = c.lenientBool(.submitted)
        completedAt = c.lenientOptionalDouble(.completedAt)
    }

    /// Number of correctly answered questions.
    public var correctCount: Int {
        var count = 0
        for (index, question) in reading.questions.enumerated() where answers[safe: index] == question.answer {
            count += 1
        }
        return count
    }
}
