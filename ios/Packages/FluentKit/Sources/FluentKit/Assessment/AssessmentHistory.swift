import Foundation

/// A finished test in „Postępy” (date, score, level). Stored in `LearnerState.assessmentHistory`,
/// one SwiftData history record per entry, merged by `id` like the other histories.
public struct AssessmentHistoryEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    /// Completion time (ms).
    public var at: Timestamp
    /// Level the test was built for.
    public var baseLevel: String
    /// Level estimated from the answers (`AssessmentScoring`).
    public var level: String
    /// Score 0–100.
    public var percent: Int
    /// Points (a board counts its share of right pairs).
    public var points: Double
    /// Questions answered.
    public var total: Int
    /// Time spent on the questions (seconds).
    public var seconds: Double
    /// Reading used in the test (the next test picks another one).
    public var readingId: String?
    /// Score 0–100 per `AssessmentSkill` raw value (skills with no question are missing).
    public var skills: [String: Int]

    public init(id: String, at: Timestamp, baseLevel: String, level: String, percent: Int, points: Double, total: Int, seconds: Double, readingId: String? = nil, skills: [String: Int] = [:]) {
        self.id = id
        self.at = at
        self.baseLevel = baseLevel
        self.level = level
        self.percent = min(100, max(0, percent))
        self.points = finiteNonNegative(points)
        self.total = max(0, total)
        self.seconds = finiteNonNegative(seconds)
        self.readingId = readingId
        self.skills = skills
    }

    enum CodingKeys: String, CodingKey {
        case id, at, baseLevel, level, percent, points, total, seconds, readingId, skills
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        at = c.lenientDouble(.at)
        baseLevel = c.lenientString(.baseLevel)
        level = c.lenientString(.level)
        percent = min(100, max(0, c.lenientInt(.percent)))
        points = finiteNonNegative(c.lenientDouble(.points))
        total = max(0, c.lenientInt(.total))
        seconds = finiteNonNegative(c.lenientDouble(.seconds))
        readingId = c.lenientOptionalString(.readingId)
        skills = (try? c.decodeIfPresent([String: Int].self, forKey: .skills)) ?? [:]
    }

    /// Score of one skill, `nil` when the test had no question for it.
    public func score(for skill: AssessmentSkill) -> Int? {
        skills[skill.rawValue]
    }
}
