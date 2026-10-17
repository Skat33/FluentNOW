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
    /// Contextual glossary (8–20 useful words with the translation used in this passage).
    /// Optional in JSON — older content and saved sessions decode with `[]`.
    public var glossary: [ReadingGlossaryEntry]

    public init(
        id: String,
        title: String,
        level: String,
        paragraphs: [String],
        questions: [ReadingQuestion],
        source: ContentSource = .starter,
        topic: String? = nil,
        glossary: [ReadingGlossaryEntry] = []
    ) {
        self.id = id
        self.title = title
        self.level = level
        self.paragraphs = paragraphs
        self.questions = questions
        self.source = source
        self.topic = topic
        self.glossary = glossary
    }

    enum CodingKeys: String, CodingKey {
        case id, title, level, paragraphs, questions, source, topic, glossary
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
        glossary = c.lossyArray(ReadingGlossaryEntry.self, forKey: .glossary)
    }
}

/// Stage of a reading: the passage alone, then questions answered from memory (passage hidden),
/// then results with the passage and its evidence visible again.
public enum ReadingStage: String, Sendable, Hashable {
    case reading
    case questions
    case results
}

/// A reading in progress or finished (web `ReadingSession`). `answers[i] == -1` = unanswered.
public struct ReadingSession: Codable, Sendable, Hashable {
    public var reading: Reading
    public var answers: [Int]
    public var submitted: Bool
    public var completedAt: Timestamp?
    /// When the learner finished reading and moved on to the questions (the passage is hidden
    /// from then until submission). `nil` = still reading (iOS only; absent in web exports).
    public var questionsStartedAt: Timestamp?

    public init(reading: Reading, answers: [Int]? = nil, submitted: Bool = false, completedAt: Timestamp? = nil, questionsStartedAt: Timestamp? = nil) {
        self.reading = reading
        self.answers = answers ?? Array(repeating: -1, count: reading.questions.count)
        self.submitted = submitted
        self.completedAt = completedAt
        self.questionsStartedAt = questionsStartedAt
    }

    enum CodingKeys: String, CodingKey {
        case reading, answers, submitted, completedAt, questionsStartedAt
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
        questionsStartedAt = c.lenientOptionalDouble(.questionsStartedAt)
    }

    /// Stage of the read-then-answer flow (FEEDBACK-2 G1).
    public var stage: ReadingStage {
        if submitted { return .results }
        if questionsStartedAt != nil || answers.contains(where: { $0 >= 0 }) { return .questions }
        return .reading
    }

    /// Hides the passage and starts the questions (idempotent; ignored after submission).
    public mutating func beginQuestions(at now: Timestamp) {
        guard !submitted, questionsStartedAt == nil else { return }
        questionsStartedAt = now
    }

    /// Records the answer of question `index` (`-1` clears it). Ignored after submission or out of range.
    public mutating func answer(question index: Int, choice: Int) {
        guard !submitted, index >= 0, index < reading.questions.count else { return }
        while answers.count < reading.questions.count { answers.append(-1) }
        answers[index] = choice
    }

    /// Number of questions still without an answer.
    public var unansweredCount: Int {
        reading.questions.indices.filter { (answers[safe: $0] ?? -1) < 0 }.count
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
