import Foundation

/// Learner preferences stored with the state (web `State.settings`).
public struct LearnerSettings: Codable, Sendable, Hashable {
    /// Daily goal: number of answers (5–100).
    public var goal: Int
    /// Preferred study time `HH:MM` (used for local reminders on iOS).
    public var reminder: String
    /// `en-US` (default) or `en-GB`.
    public var accent: String
    /// Slow speech rate.
    public var slow: Bool
    /// Selected voice identifier, if any.
    public var voice: String?
    public var voiceRevision: Int?
    /// Study profile from the first-run interview (G4). Optional and backward compatible:
    /// older exports and the web app simply do not have it.
    public var profile: LearnerProfile?
    /// Desired retention of the FSRS scheduler (I1): `nil` = default 0.90. Optional and backward
    /// compatible (older exports and the web app do not have it). Values are clamped to
    /// `FSRS.retentionRange` when used.
    public var desiredRetention: Double?
    /// Avatar and nickname of the profile panel (FEEDBACK-5 J3). Optional and backward compatible;
    /// merged by its own `updatedAt` (`LearnerAvatar.newer`).
    public var avatar: LearnerAvatar?

    /// Retention used by the scheduler.
    public var effectiveRetention: Double {
        desiredRetention.map { FSRS.clampedRetention($0) } ?? FSRS.defaultRetention
    }

    public static let goalRange: ClosedRange<Int> = 5...100
    public static let defaultReminder = "19:00"
    public static let supportedAccents = ["en-US", "en-GB"]

    public init(
        goal: Int = 20,
        reminder: String = LearnerSettings.defaultReminder,
        accent: String = "en-US",
        slow: Bool = false,
        voice: String? = nil,
        voiceRevision: Int? = 2,
        profile: LearnerProfile? = nil,
        desiredRetention: Double? = nil,
        avatar: LearnerAvatar? = nil
    ) {
        self.goal = min(LearnerSettings.goalRange.upperBound, max(LearnerSettings.goalRange.lowerBound, goal))
        self.reminder = LearnerSettings.isValidReminder(reminder) ? reminder : LearnerSettings.defaultReminder
        self.accent = LearnerSettings.supportedAccents.contains(accent) ? accent : "en-US"
        self.slow = slow
        self.voice = voice
        self.voiceRevision = voiceRevision
        self.profile = profile
        self.desiredRetention = desiredRetention.flatMap { $0.isFinite ? FSRS.clampedRetention($0) : nil }
        self.avatar = avatar
    }

    enum CodingKeys: String, CodingKey {
        case goal, reminder, accent, slow, voice, voiceRevision, profile, desiredRetention, avatar
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            goal: c.lenientInt(.goal, default: 20),
            reminder: c.lenientString(.reminder, default: LearnerSettings.defaultReminder),
            accent: c.lenientString(.accent, default: "en-US"),
            slow: c.lenientBool(.slow),
            voice: c.lenientOptionalString(.voice),
            voiceRevision: c.lenientOptionalInt(.voiceRevision),
            profile: c.lenientOptional(LearnerProfile.self, forKey: .profile),
            desiredRetention: c.lenientOptionalDouble(.desiredRetention),
            avatar: c.lenientOptional(LearnerAvatar.self, forKey: .avatar)
        )
    }

    /// `true` for `HH:MM` with 00–23 hours and 00–59 minutes.
    public static func isValidReminder(_ value: String) -> Bool {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0].count == 2, parts[1].count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]) else { return false }
        return (0...23).contains(hour) && (0...59).contains(minute)
    }

    /// Reminder as hour and minute components.
    public var reminderComponents: (hour: Int, minute: Int) {
        let parts = reminder.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return (19, 0)
        }
        return (hour, minute)
    }
}
