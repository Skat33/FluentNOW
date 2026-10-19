import Foundation

/// The learner's avatar and nickname shown in the profile panel (FEEDBACK-5 J3). Stored in
/// `LearnerSettings.avatar` — synced with iCloud like the rest of the settings; optional and
/// backward compatible (older exports and the web app do not have it). Two copies are merged by
/// `updatedAt` (`LearnerAvatar.newer`), independently of `LearnerProfile`, so changing the
/// avatar never touches the study profile (whose `updatedAt` re-applies study defaults).
///
/// Unknown symbol / colour ids (e.g. from a newer version) are kept as they are; the UI shows
/// them through `AvatarCatalog.resolved`, which falls back to the defaults.
public struct LearnerAvatar: Codable, Sendable, Hashable {
    /// SF Symbol name from `AvatarCatalog.symbols`.
    public var symbol: String
    /// Colour id from `AvatarCatalog.colors`.
    public var color: String
    /// Name shown in the profile (`nil` = the account name or „Uczeń”).
    public var nickname: String?
    public var updatedAt: Timestamp

    public static let maxNicknameLength = 40

    public init(
        symbol: String = AvatarCatalog.defaultSymbol,
        color: String = AvatarCatalog.defaultColor,
        nickname: String? = nil,
        updatedAt: Timestamp = 0
    ) {
        self.symbol = symbol
        self.color = color
        self.nickname = nickname
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case symbol, color, nickname, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            symbol: c.lenientString(.symbol, default: AvatarCatalog.defaultSymbol),
            color: c.lenientString(.color, default: AvatarCatalog.defaultColor),
            nickname: c.lenientOptionalString(.nickname),
            updatedAt: c.lenientDouble(.updatedAt)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(symbol, forKey: .symbol)
        try c.encode(color, forKey: .color)
        try c.encodeIfPresent(nickname, forKey: .nickname)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    /// Trimmed nickname (≤ 40 characters, empty → `nil`), non-empty ids, finite timestamp.
    public func normalized() -> LearnerAvatar {
        var copy = self
        copy.nickname = LearnerAvatar.cleanNickname(nickname)
        let symbolTrimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.symbol = symbolTrimmed.isEmpty ? AvatarCatalog.defaultSymbol : symbolTrimmed
        let colorTrimmed = color.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.color = colorTrimmed.isEmpty ? AvatarCatalog.defaultColor : colorTrimmed
        copy.updatedAt = updatedAt.isFinite ? max(0, updatedAt) : 0
        return copy
    }

    /// Nickname as stored: trimmed, single line, at most `maxNicknameLength` characters.
    public static func cleanNickname(_ value: String?) -> String? {
        guard let value else { return nil }
        let oneLine = value
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !oneLine.isEmpty else { return nil }
        return String(oneLine.prefix(maxNicknameLength))
    }

    /// The more recently edited of two avatars (ties keep `local`; `nil` loses).
    public static func newer(_ local: LearnerAvatar?, _ remote: LearnerAvatar?) -> LearnerAvatar? {
        guard let local else { return remote }
        guard let remote else { return local }
        return remote.updatedAt > local.updatedAt ? remote : local
    }
}
