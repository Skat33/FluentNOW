import Foundation

/// A question task of a combined session (grammar, idioms, reading, production, language mix).
public struct CombinedQuestionTask: Codable, Sendable, Hashable {
    public var mode: StudyMode
    public var question: PracticeQuestion
    public var level: String
    /// Passage of a reading question.
    public var reading: Reading?
    /// Index of the question within `reading.questions`.
    public var readingIndex: Int?
    /// Original production item (graded with `gradeProduction`).
    public var production: ProductionItem?

    public init(mode: StudyMode, question: PracticeQuestion, level: String, reading: Reading? = nil, readingIndex: Int? = nil, production: ProductionItem? = nil) {
        self.mode = mode
        self.question = question
        self.level = level
        self.reading = reading
        self.readingIndex = readingIndex
        self.production = production
    }
}

/// One task of a combined session (web `CombinedTask`, discriminated by `kind`).
public enum CombinedTask: Codable, Sendable, Hashable {
    case vocabulary(mode: StudyMode, task: VocabTask)
    case question(CombinedQuestionTask)

    /// Study mode the task belongs to.
    public var mode: StudyMode {
        switch self {
        case .vocabulary(let mode, _): return mode
        case .question(let question): return question.mode
        }
    }

    /// The vocabulary task, if any.
    public var vocabularyTask: VocabTask? {
        if case .vocabulary(_, let task) = self { return task }
        return nil
    }

    /// The question task, if any.
    public var questionTask: CombinedQuestionTask? {
        if case .question(let question) = self { return question }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case kind, mode, task, question, level, reading, readingIndex, production
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        let modeRaw = try c.decode(String.self, forKey: .mode)
        guard let mode = StudyMode(rawValue: modeRaw) else {
            throw DecodingError.dataCorruptedError(forKey: .mode, in: c, debugDescription: "Nieznany tryb: \(modeRaw)")
        }
        switch kind {
        case "vocabulary":
            let task = try c.decode(VocabTask.self, forKey: .task)
            self = .vocabulary(mode: mode, task: task)
        case "question":
            let question = try c.decode(PracticeQuestion.self, forKey: .question)
            let level = c.lenientString(.level, default: "A2")
            let reading = c.lenientOptional(Reading.self, forKey: .reading)
            let readingIndex = c.lenientOptionalInt(.readingIndex)
            let production = c.lenientOptional(ProductionItem.self, forKey: .production)
            self = .question(CombinedQuestionTask(mode: mode, question: question, level: level, reading: reading, readingIndex: readingIndex, production: production))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Nieznany rodzaj zadania: \(kind)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .vocabulary(let mode, let task):
            try c.encode("vocabulary", forKey: .kind)
            try c.encode(mode, forKey: .mode)
            try c.encode(task, forKey: .task)
        case .question(let item):
            try c.encode("question", forKey: .kind)
            try c.encode(item.mode, forKey: .mode)
            try c.encode(item.question, forKey: .question)
            try c.encode(item.level, forKey: .level)
            try c.encodeIfPresent(item.reading, forKey: .reading)
            try c.encodeIfPresent(item.readingIndex, forKey: .readingIndex)
            try c.encodeIfPresent(item.production, forKey: .production)
        }
    }
}

/// A graded answer of a combined session (web `CombinedAnswer`).
public struct CombinedAnswer: Codable, Sendable, Hashable {
    /// The typed text, or the chosen option index as text for multiple choice.
    public var value: String
    public var correct: Bool
    public var seconds: Double
    public var hinted: Bool
    public var spellingCorrect: Bool
    public var explanation: String

    public init(value: String, correct: Bool, seconds: Double, hinted: Bool = false, spellingCorrect: Bool = true, explanation: String = "") {
        self.value = value
        self.correct = correct
        self.seconds = seconds
        self.hinted = hinted
        self.spellingCorrect = spellingCorrect
        self.explanation = explanation
    }

    enum CodingKeys: String, CodingKey {
        case value, correct, seconds, hinted, spellingCorrect, explanation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = c.lenientString(.value)
        correct = c.lenientBool(.correct)
        seconds = finiteNonNegative(c.lenientDouble(.seconds))
        hinted = c.lenientBool(.hinted)
        spellingCorrect = c.lenientBool(.spellingCorrect, default: true)
        explanation = c.lenientString(.explanation)
    }
}

/// A multi-mode session (web `CombinedSession`, v40).
public struct CombinedSession: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var modes: [StudyMode]
    /// `true` when modes are interleaved randomly, `false` when grouped by mode.
    public var random: Bool
    public var minutes: Int
    public var tasks: [CombinedTask]
    /// One slot per task; `nil` until answered.
    public var answers: [CombinedAnswer?]
    public var index: Int
    public var updatedAt: Timestamp
    public var completedAt: Timestamp?

    public init(
        id: String,
        modes: [StudyMode],
        random: Bool,
        minutes: Int,
        tasks: [CombinedTask],
        answers: [CombinedAnswer?]? = nil,
        index: Int = 0,
        updatedAt: Timestamp,
        completedAt: Timestamp? = nil
    ) {
        self.id = id
        self.modes = modes
        self.random = random
        self.minutes = minutes
        self.tasks = tasks
        self.answers = answers ?? Array(repeating: nil, count: tasks.count)
        self.index = index
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    /// The current task, or `nil` when finished.
    public var currentTask: CombinedTask? {
        tasks[safe: index]
    }

    /// The answer of the current task, if already checked.
    public var currentAnswer: CombinedAnswer? {
        guard let slot = answers[safe: index] else { return nil }
        return slot
    }

    /// Number of answered tasks.
    public var answeredCount: Int {
        answers.reduce(0) { $0 + ($1 == nil ? 0 : 1) }
    }

    /// Number of correct answers.
    public var correctCount: Int {
        answers.reduce(0) { $0 + (($1?.correct ?? false) ? 1 : 0) }
    }

    enum CodingKeys: String, CodingKey {
        case id, modes, random, minutes, tasks, answers, index, updatedAt, completedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        modes = c.lenientStrings(.modes).compactMap { StudyMode(rawValue: $0) }
        random = c.lenientBool(.random)
        minutes = c.lenientInt(.minutes, default: 10)
        tasks = try c.decode([CombinedTask].self, forKey: .tasks)
        var decodedAnswers = (try? c.decodeIfPresent([CombinedAnswer?].self, forKey: .answers)) ?? []
        if decodedAnswers.count > tasks.count {
            decodedAnswers = Array(decodedAnswers.prefix(tasks.count))
        }
        while decodedAnswers.count < tasks.count { decodedAnswers.append(nil) }
        answers = decodedAnswers
        index = min(max(0, c.lenientInt(.index)), tasks.count)
        updatedAt = c.lenientDouble(.updatedAt)
        completedAt = c.lenientOptionalDouble(.completedAt)
    }
}
