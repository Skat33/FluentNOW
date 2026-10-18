import Foundation

/// A word + meaning reference (the other meanings of a „Dopasuj pary” task).
public struct VocabTaskRef: Codable, Sendable, Hashable {
    public var wordId: String
    public var meaningId: String

    public init(wordId: String, meaningId: String) {
        self.wordId = wordId
        self.meaningId = meaningId
    }
}

/// One vocabulary exercise in a session (web `Task`).
public struct VocabTask: Codable, Sendable, Hashable {
    public var wordId: String
    public var meaningId: String
    public var type: ExerciseType
    /// Index of the example sentence used by the task.
    public var example: Int
    /// „Dopasuj pary” (I2): the other meanings of the board (`wordId`/`meaningId` is the first
    /// pair). `nil` for every other type — then the key is not written, so the JSON of the old
    /// types is unchanged; old JSON without the key decodes as `nil`.
    public var partners: [VocabTaskRef]?

    public init(wordId: String, meaningId: String, type: ExerciseType, example: Int, partners: [VocabTaskRef]? = nil) {
        self.wordId = wordId
        self.meaningId = meaningId
        self.type = type
        self.example = example
        self.partners = partners
    }

    /// Every meaning of the task: the task's own meaning first, then the partners.
    public var allRefs: [VocabTaskRef] {
        [VocabTaskRef(wordId: wordId, meaningId: meaningId)] + (partners ?? [])
    }

    enum CodingKeys: String, CodingKey {
        case wordId, meaningId, type, example, partners
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wordId = try c.decode(String.self, forKey: .wordId)
        meaningId = try c.decode(String.self, forKey: .meaningId)
        let rawType = c.lenientInt(.type, default: -1)
        guard let parsed = ExerciseType(rawValue: rawType) else {
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: c,
                debugDescription: "Nieznany typ zadania: \(rawType)"
            )
        }
        type = parsed
        example = max(0, c.lenientInt(.example))
        // Tolerant: a damaged list only loses the partners (the board then falls back to the
        // meaning exercise of the first pair), never the session.
        partners = try? c.decodeIfPresent([VocabTaskRef].self, forKey: .partners)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(wordId, forKey: .wordId)
        try c.encode(meaningId, forKey: .meaningId)
        try c.encode(type, forKey: .type)
        try c.encode(example, forKey: .example)
        try c.encodeIfPresent(partners, forKey: .partners)
    }
}

/// A paused or running vocabulary session (web `Session`).
public struct VocabSession: Codable, Sendable, Hashable {
    public var tasks: [VocabTask]
    /// Index of the current task (== `tasks.count` when finished).
    public var index: Int
    /// Number of independent correct answers.
    public var correct: Int
    /// Planned length in minutes (5 / 10 / 15).
    public var minutes: Int
    /// Mode raw value (`mixed`, `mistakes`, `pairs`).
    public var mode: String

    public init(tasks: [VocabTask], index: Int = 0, correct: Int = 0, minutes: Int, mode: String) {
        self.tasks = tasks
        self.index = index
        self.correct = correct
        self.minutes = minutes
        self.mode = mode
    }

    /// The current task, or `nil` when the session is finished.
    public var currentTask: VocabTask? {
        tasks[safe: index]
    }

    /// `true` when every task was answered.
    public var isFinished: Bool {
        index >= tasks.count
    }

    /// Mode as a `StudyMode` (unknown modes map to `.mixed`).
    public var studyMode: StudyMode {
        StudyMode(rawValue: mode) ?? .mixed
    }

    enum CodingKeys: String, CodingKey {
        case tasks, index, correct, minutes, mode
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try c.decode([VocabTask].self, forKey: .tasks)
        index = max(0, c.lenientInt(.index))
        correct = max(0, c.lenientInt(.correct))
        minutes = c.lenientInt(.minutes, default: 10)
        mode = c.lenientString(.mode, default: "mixed")
    }
}
