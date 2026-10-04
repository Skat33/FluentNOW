import Foundation

/// One answer in the learning history (web `Review`).
public struct Review: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var wordId: String
    public var meaningId: String
    public var skill: Skill
    public var correct: Bool
    /// Answer time (ms).
    public var at: Timestamp
    /// Answer duration in seconds.
    public var seconds: Double
    /// Self-reported confidence 1–3.
    public var confidence: Int
    public var hint: Bool
    /// Polish error category ("" when none).
    public var error: String
    /// Meaning mastery before / after the answer.
    public var before: Int
    public var after: Int
    /// `2` for measurements on the five-skill mastery scale; `nil` for historic values.
    public var masteryVersion: Int?
    /// Weight of the answer (1 = exercise, 0.35 = reading).
    public var weight: Double
    public var source: ReviewSource
    /// Demo history of the web starter set (excluded from statistics).
    public var demo: Bool

    public init(
        id: String,
        wordId: String,
        meaningId: String,
        skill: Skill,
        correct: Bool,
        at: Timestamp,
        seconds: Double,
        confidence: Int,
        hint: Bool,
        error: String = "",
        before: Int,
        after: Int,
        masteryVersion: Int? = 2,
        weight: Double = 1,
        source: ReviewSource = .exercise,
        demo: Bool = false
    ) {
        self.id = id
        self.wordId = wordId
        self.meaningId = meaningId
        self.skill = skill
        self.correct = correct
        self.at = at
        self.seconds = seconds
        self.confidence = confidence
        self.hint = hint
        self.error = error
        self.before = before
        self.after = after
        self.masteryVersion = masteryVersion
        self.weight = weight
        self.source = source
        self.demo = demo
    }

    enum CodingKeys: String, CodingKey {
        case id, wordId, meaningId, skill, correct, at, seconds, confidence, hint, error, before, after
        case masteryVersion, weight, source, demo
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        wordId = c.lenientString(.wordId)
        meaningId = c.lenientString(.meaningId)
        skill = try c.decode(Skill.self, forKey: .skill)
        correct = c.lenientBool(.correct)
        at = c.lenientDouble(.at)
        seconds = finiteNonNegative(c.lenientDouble(.seconds))
        confidence = min(3, max(1, c.lenientInt(.confidence, default: 2)))
        hint = c.lenientBool(.hint)
        error = c.lenientString(.error)
        before = c.lenientInt(.before)
        after = c.lenientInt(.after)
        masteryVersion = c.lenientOptionalInt(.masteryVersion)
        weight = min(1, max(0, c.lenientDouble(.weight, default: 1)))
        source = ReviewSource(rawValue: c.lenientString(.source, default: "exercise")) ?? .exercise
        demo = c.lenientBool(.demo)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(wordId, forKey: .wordId)
        try c.encode(meaningId, forKey: .meaningId)
        try c.encode(skill, forKey: .skill)
        try c.encode(correct, forKey: .correct)
        try c.encode(at, forKey: .at)
        try c.encode(seconds, forKey: .seconds)
        try c.encode(confidence, forKey: .confidence)
        try c.encode(hint, forKey: .hint)
        try c.encode(error, forKey: .error)
        try c.encode(before, forKey: .before)
        try c.encode(after, forKey: .after)
        try c.encodeIfPresent(masteryVersion, forKey: .masteryVersion)
        try c.encode(weight, forKey: .weight)
        try c.encode(source, forKey: .source)
        if demo {
            try c.encode(demo, forKey: .demo)
        }
    }
}

/// Daily aggregate of reviews older than 90 days (web `reviewSummaries`). `day` is `yyyy-MM-dd` in UTC.
public struct ReviewSummary: Codable, Sendable, Hashable {
    public var day: String
    public var count: Int
    public var correct: Int

    public init(day: String, count: Int, correct: Int) {
        self.day = day
        self.count = count
        self.correct = correct
    }

    enum CodingKeys: String, CodingKey {
        case day, count, correct
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(String.self, forKey: .day)
        count = max(0, c.lenientInt(.count))
        correct = max(0, c.lenientInt(.correct))
    }
}
