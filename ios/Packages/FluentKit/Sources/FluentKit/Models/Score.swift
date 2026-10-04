import Foundation

/// Spaced-repetition state of one meaning × skill (web `Score`).
public struct Score: Codable, Sendable, Hashable {
    /// Displayed value 0–100, always `masteryFromInterval(interval)`.
    public var value: Int
    /// Current interval in days (0…90).
    public var interval: Double
    /// Next due time (ms since 1970).
    public var due: Timestamp
    /// Number of correct answers.
    public var correct: Int
    /// Current error weight (independent correct answers repair it).
    public var wrong: Int
    /// Number of answers given after a hint.
    public var hinted: Int
    /// Time of the last answer (ms), 0 when never answered.
    public var last: Timestamp
    /// Number of slow answers.
    public var slow: Int

    public init(
        value: Int = 0,
        interval: Double = 0,
        due: Timestamp = 0,
        correct: Int = 0,
        wrong: Int = 0,
        hinted: Int = 0,
        last: Timestamp = 0,
        slow: Int = 0
    ) {
        self.value = value
        self.interval = interval
        self.due = due
        self.correct = correct
        self.wrong = wrong
        self.hinted = hinted
        self.last = last
        self.slow = slow
    }

    /// Empty starting score used when a skill is answered for the first time.
    public static let empty = Score()

    enum CodingKeys: String, CodingKey {
        case value, interval, due, correct, wrong, hinted, last, slow
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = c.lenientInt(.value)
        interval = finiteNonNegative(c.lenientDouble(.interval))
        due = c.lenientDouble(.due)
        correct = max(0, c.lenientInt(.correct))
        wrong = max(0, c.lenientInt(.wrong))
        hinted = max(0, c.lenientInt(.hinted))
        last = c.lenientDouble(.last)
        slow = max(0, c.lenientInt(.slow))
    }
}

/// Scores of one meaning keyed by skill. Encodes as a JSON object
/// `{ "recognition": Score, ... }` exactly like the web `Partial<Record<Skill, Score>>`.
public struct SkillScores: Codable, Sendable, Hashable {
    private var storage: [Skill: Score]

    public init(_ scores: [Skill: Score] = [:]) {
        self.storage = scores
    }

    public subscript(skill: Skill) -> Score? {
        get { storage[skill] }
        set { storage[skill] = newValue }
    }

    /// `true` when no skill was ever answered (the meaning is new).
    public var isEmpty: Bool { storage.isEmpty }

    /// Number of scored skills.
    public var count: Int { storage.count }

    /// Practiced skills in a stable order (`Skill.allCases` order).
    public var skills: [Skill] {
        Skill.allCases.filter { storage[$0] != nil }
    }

    /// Scores in a stable order (`Skill.allCases` order).
    public var values: [Score] {
        Skill.allCases.compactMap { storage[$0] }
    }

    /// Pairs in a stable order.
    public var entries: [(skill: Skill, score: Score)] {
        Skill.allCases.compactMap { skill in
            storage[skill].map { (skill: skill, score: $0) }
        }
    }

    /// Dictionary view.
    public var dictionary: [Skill: Score] { storage }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyCodingKey.self)
        var result: [Skill: Score] = [:]
        for key in c.allKeys {
            guard let skill = Skill(rawValue: key.stringValue) else { continue }
            if let score = try? c.decodeIfPresent(Score.self, forKey: key) {
                result[skill] = score
            }
        }
        storage = result
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: AnyCodingKey.self)
        for skill in Skill.allCases {
            if let score = storage[skill] {
                try c.encode(score, forKey: AnyCodingKey(skill.rawValue))
            }
        }
    }
}
