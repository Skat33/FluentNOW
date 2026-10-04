import Foundation

/// One vocabulary exercise in a session (web `Task`).
public struct VocabTask: Codable, Sendable, Hashable {
    public var wordId: String
    public var meaningId: String
    public var type: ExerciseType
    /// Index of the example sentence used by the task.
    public var example: Int

    public init(wordId: String, meaningId: String, type: ExerciseType, example: Int) {
        self.wordId = wordId
        self.meaningId = meaningId
        self.type = type
        self.example = example
    }

    enum CodingKeys: String, CodingKey {
        case wordId, meaningId, type, example
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
