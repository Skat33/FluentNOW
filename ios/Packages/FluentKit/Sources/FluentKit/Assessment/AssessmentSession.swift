import Foundation

/// A word meaning the test may ask about: one of the learner's own words, or a word from the
/// built-in base (`owned == false`, kept in `AssessmentSession.bankWords` until the learner adds it).
public struct AssessmentCandidate: Codable, Sendable, Hashable {
    public var wordId: String
    public var meaningId: String
    public var level: String
    public var owned: Bool
    /// Content reference `<topic>/<entry>` of a base word (used by „Dodaj nowe słowa do nauki”).
    public var contentRef: String?

    public init(wordId: String, meaningId: String, level: String, owned: Bool, contentRef: String? = nil) {
        self.wordId = wordId
        self.meaningId = meaningId
        self.level = level
        self.owned = owned
        self.contentRef = contentRef
    }

    enum CodingKeys: String, CodingKey {
        case wordId, meaningId, level, owned, contentRef
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wordId = try c.decode(String.self, forKey: .wordId)
        meaningId = try c.decode(String.self, forKey: .meaningId)
        level = c.lenientString(.level)
        owned = c.lenientBool(.owned)
        contentRef = c.lenientOptionalString(.contentRef)
    }
}

/// A vocabulary question (one meaning; „Dopasuj pary” — a board with partners).
public struct AssessmentVocabQuestion: Codable, Sendable, Hashable {
    public var block: AssessmentBlock
    public var task: VocabTask
    public var tier: AssessmentTier
    public var level: String

    public init(block: AssessmentBlock, task: VocabTask, tier: AssessmentTier, level: String) {
        self.block = block
        self.task = task
        self.tier = tier
        self.level = level
    }
}

/// A grammar question or one question of the test reading (multiple choice).
public struct AssessmentTextQuestion: Codable, Sendable, Hashable {
    public var block: AssessmentBlock
    public var question: PracticeQuestion
    public var level: String
    /// Reading: index of the question in `AssessmentSession.reading.questions`.
    public var readingIndex: Int?

    public init(block: AssessmentBlock, question: PracticeQuestion, level: String, readingIndex: Int? = nil) {
        self.block = block
        self.question = question
        self.level = level
        self.readingIndex = readingIndex
    }
}

/// One question of the test (discriminated by `kind` in JSON).
public enum AssessmentQuestion: Codable, Sendable, Hashable {
    case vocabulary(AssessmentVocabQuestion)
    case text(AssessmentTextQuestion)

    public var block: AssessmentBlock {
        switch self {
        case .vocabulary(let question): return question.block
        case .text(let question): return question.block
        }
    }

    public var level: String {
        switch self {
        case .vocabulary(let question): return question.level
        case .text(let question): return question.level
        }
    }

    /// Tier of the band (text questions are always on the base level).
    public var tier: AssessmentTier {
        switch self {
        case .vocabulary(let question): return question.tier
        case .text: return .upper
        }
    }

    public var vocabulary: AssessmentVocabQuestion? {
        if case .vocabulary(let question) = self { return question }
        return nil
    }

    public var text: AssessmentTextQuestion? {
        if case .text(let question) = self { return question }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case kind, vocabulary, text
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(String.self, forKey: .kind)
        switch kind {
        case "vocabulary":
            self = .vocabulary(try c.decode(AssessmentVocabQuestion.self, forKey: .vocabulary))
        case "text":
            self = .text(try c.decode(AssessmentTextQuestion.self, forKey: .text))
        default:
            throw DecodingError.dataCorruptedError(forKey: .kind, in: c, debugDescription: "Nieznany rodzaj pytania testu: \(kind)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .vocabulary(let question):
            try c.encode("vocabulary", forKey: .kind)
            try c.encode(question, forKey: .vocabulary)
        case .text(let question):
            try c.encode("text", forKey: .kind)
            try c.encode(question, forKey: .text)
        }
    }
}

/// Result of one meaning in an answer (a board has several).
public struct AssessmentItemResult: Codable, Sendable, Hashable {
    public var wordId: String
    public var meaningId: String
    public var owned: Bool
    public var contentRef: String?
    public var correct: Bool
    /// What was asked (word, translation, sentence…).
    public var prompt: String
    /// The correct answer.
    public var expected: String

    public init(wordId: String, meaningId: String, owned: Bool, contentRef: String? = nil, correct: Bool, prompt: String, expected: String) {
        self.wordId = wordId
        self.meaningId = meaningId
        self.owned = owned
        self.contentRef = contentRef
        self.correct = correct
        self.prompt = prompt
        self.expected = expected
    }

    enum CodingKeys: String, CodingKey {
        case wordId, meaningId, owned, contentRef, correct, prompt, expected
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wordId = c.lenientString(.wordId)
        meaningId = c.lenientString(.meaningId)
        owned = c.lenientBool(.owned)
        contentRef = c.lenientOptionalString(.contentRef)
        correct = c.lenientBool(.correct)
        prompt = c.lenientString(.prompt)
        expected = c.lenientString(.expected)
    }
}

/// A graded answer. The test shows no feedback; everything is revealed on the result screen.
public struct AssessmentAnswer: Codable, Sendable, Hashable {
    /// What the learner gave (typed text, chosen option, „4/5” for a board).
    public var value: String
    public var correct: Bool
    /// 0…1 — a board scores the share of pairs matched without a mistake.
    public var points: Double
    /// Answer time (seconds).
    public var seconds: Double
    public var prompt: String
    public var expected: String
    /// Meanings of a vocabulary answer (empty for grammar and reading).
    public var items: [AssessmentItemResult]

    public init(value: String, correct: Bool, points: Double, seconds: Double, prompt: String, expected: String, items: [AssessmentItemResult] = []) {
        self.value = value
        self.correct = correct
        self.points = min(1, max(0, points.isFinite ? points : 0))
        self.seconds = finiteNonNegative(seconds)
        self.prompt = prompt
        self.expected = expected
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case value, correct, points, seconds, prompt, expected, items
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = c.lenientString(.value)
        correct = c.lenientBool(.correct)
        let rawPoints = c.lenientDouble(.points, default: correct ? 1 : 0)
        points = min(1, max(0, rawPoints.isFinite ? rawPoints : 0))
        seconds = finiteNonNegative(c.lenientDouble(.seconds))
        prompt = c.lenientString(.prompt)
        expected = c.lenientString(.expected)
        items = c.lossyArray(AssessmentItemResult.self, forKey: .items)
    }
}

/// The level test in progress (or finished, until the result is closed). Questions are drawn one
/// at a time (light adaptation), there is no way back: `answers` only grows, `index` only moves on.
///
/// Invariants (kept by `AssessmentEngine`): `answers.count == index`; `questions[i].block ==
/// slots[i]`; while not finished `questions.count == index + 1` (the current question is ready).
public struct AssessmentSession: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var band: AssessmentBand
    public var startedAt: Timestamp
    public var updatedAt: Timestamp
    public var completedAt: Timestamp?
    /// Time spent on the questions (seconds, orientational clock — no hard limit).
    public var activeSeconds: Double
    /// Planned blocks per question (a slot that cannot be filled is removed).
    public var slots: [AssessmentBlock]
    public var questions: [AssessmentQuestion]
    public var answers: [AssessmentAnswer]
    public var index: Int
    /// Ordered pool of meanings for the vocabulary blocks (own words first).
    public var candidates: [AssessmentCandidate]
    /// Base words used by the test (never saved to the vocabulary unless the learner adds them).
    public var bankWords: [Word]
    /// Grammar questions of the base level (drawn in order).
    public var grammar: [PracticeQuestion]
    /// The test reading (only the questions asked are used).
    public var reading: Reading?

    public init(
        id: String,
        band: AssessmentBand,
        startedAt: Timestamp,
        updatedAt: Timestamp? = nil,
        completedAt: Timestamp? = nil,
        activeSeconds: Double = 0,
        slots: [AssessmentBlock],
        questions: [AssessmentQuestion] = [],
        answers: [AssessmentAnswer] = [],
        index: Int = 0,
        candidates: [AssessmentCandidate] = [],
        bankWords: [Word] = [],
        grammar: [PracticeQuestion] = [],
        reading: Reading? = nil
    ) {
        self.id = id
        self.band = band
        self.startedAt = startedAt
        self.updatedAt = updatedAt ?? startedAt
        self.completedAt = completedAt
        self.activeSeconds = finiteNonNegative(activeSeconds)
        self.slots = slots
        self.questions = questions
        self.answers = answers
        self.index = index
        self.candidates = candidates
        self.bankWords = bankWords
        self.grammar = grammar
        self.reading = reading
    }

    /// Base level of the test.
    public var baseLevel: String { band.base }

    /// Every question answered.
    public var isFinished: Bool { index >= slots.count }

    /// The current question (`nil` when finished or not prepared yet).
    public var currentQuestion: AssessmentQuestion? {
        guard index < slots.count else { return nil }
        return questions[safe: index]
    }

    /// Number of questions in the test (planned slots that are still possible).
    public var total: Int { slots.count }

    /// Planned duration in seconds (sum of the blocks' estimates).
    public var plannedSeconds: Int {
        slots.reduce(0) { (sum: Int, block: AssessmentBlock) -> Int in sum + block.estimatedSeconds }
    }

    /// Answers so far as right / wrong (a board is right only without any mistake).
    public var outcomes: [Bool] {
        answers.map { (answer: AssessmentAnswer) -> Bool in answer.correct }
    }

    /// Reading question index of a question (`nil` for other questions).
    public func readingIndex(at position: Int) -> Int? {
        questions[safe: position]?.text?.readingIndex
    }

    /// `true` for the first reading question (the passage is shown before it).
    public var opensReading: Bool {
        guard let question = currentQuestion, question.block == .reading else { return false }
        return !questions.prefix(index).contains { (other: AssessmentQuestion) -> Bool in other.block == .reading }
    }

    enum CodingKeys: String, CodingKey {
        case id, band, startedAt, updatedAt, completedAt, activeSeconds, slots, questions, answers, index
        case candidates, bankWords, grammar, reading
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        band = c.lenientOptional(AssessmentBand.self, forKey: .band) ?? AssessmentBand(base: "A2")
        let started = c.lenientDouble(.startedAt)
        startedAt = started
        updatedAt = c.lenientDouble(.updatedAt, default: started)
        completedAt = c.lenientOptionalDouble(.completedAt)
        activeSeconds = finiteNonNegative(c.lenientDouble(.activeSeconds))
        slots = c.lenientStrings(.slots).compactMap { (raw: String) -> AssessmentBlock? in AssessmentBlock(rawValue: raw) }
        // A damaged question list cannot be resumed safely — fail, so the caller drops the test.
        questions = try c.decode([AssessmentQuestion].self, forKey: .questions, default: [])
        answers = c.lossyArray(AssessmentAnswer.self, forKey: .answers)
        index = max(0, c.lenientInt(.index))
        candidates = c.lossyArray(AssessmentCandidate.self, forKey: .candidates)
        bankWords = c.lossyArray(Word.self, forKey: .bankWords)
        grammar = c.lossyArray(PracticeQuestion.self, forKey: .grammar)
        reading = c.lenientOptional(Reading.self, forKey: .reading)
        repair()
    }

    /// Restores the invariants after decoding / merging (never crashes on odd data).
    mutating func repair() {
        // Questions must follow the slots; anything after the first mismatch is dropped.
        var validQuestions: [AssessmentQuestion] = []
        for (position, question) in questions.enumerated() {
            guard let slot = slots[safe: position], slot == question.block else { break }
            validQuestions.append(question)
        }
        questions = validQuestions
        if answers.count > questions.count {
            answers = Array(answers.prefix(questions.count))
        }
        index = min(answers.count, slots.count)
        if questions.count > index + 1 {
            questions = Array(questions.prefix(index + 1))
        }
    }
}
