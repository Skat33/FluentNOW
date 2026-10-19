import Foundation

/// An avatar icon (SF Symbol) unlocked at an XP level.
public struct AvatarSymbolOption: Sendable, Hashable, Identifiable {
    /// SF Symbol name (available on iOS 17).
    public var id: String
    public var namePl: String
    public var unlockLevel: Int

    public init(id: String, namePl: String, unlockLevel: Int) {
        self.id = id
        self.namePl = namePl
        self.unlockLevel = unlockLevel
    }
}

/// An avatar colour: one stop = solid colour, two or more = gradient (higher levels).
public struct AvatarColorOption: Sendable, Hashable, Identifiable {
    public var id: String
    public var namePl: String
    public var unlockLevel: Int
    /// sRGB colours as `0xRRGGBB`, from the top-leading corner. White symbols are drawn on top,
    /// so every stop is dark enough for a 3:1 contrast with white (icons are non-text content).
    public var stops: [UInt32]

    public init(id: String, namePl: String, unlockLevel: Int, stops: [UInt32]) {
        self.id = id
        self.namePl = namePl
        self.unlockLevel = unlockLevel
        self.stops = stops
    }

    public var isGradient: Bool { stops.count > 1 }
}

/// What is available at a level, plus the next thing to unlock.
public struct AvatarUnlocks: Sendable, Hashable {
    public var level: Int
    public var symbols: [AvatarSymbolOption]
    public var colors: [AvatarColorOption]
    /// The next locked icon / colour (`nil` when everything is unlocked).
    public var nextSymbol: AvatarSymbolOption?
    public var nextColor: AvatarColorOption?

    public init(level: Int, symbols: [AvatarSymbolOption], colors: [AvatarColorOption], nextSymbol: AvatarSymbolOption?, nextColor: AvatarColorOption?) {
        self.level = level
        self.symbols = symbols
        self.colors = colors
        self.nextSymbol = nextSymbol
        self.nextColor = nextColor
    }

    /// The nearest level that unlocks anything new (`nil` = everything unlocked).
    public var nextUnlockLevel: Int? {
        let levels = [nextSymbol?.unlockLevel, nextColor?.unlockLevel].compactMap { $0 }
        return levels.min()
    }
}

/// Icons and colours unlocked between two levels (e.g. after a level-up).
public struct AvatarUnlockDelta: Sendable, Hashable {
    public var symbols: [AvatarSymbolOption]
    public var colors: [AvatarColorOption]

    public init(symbols: [AvatarSymbolOption] = [], colors: [AvatarColorOption] = []) {
        self.symbols = symbols
        self.colors = colors
    }

    public var isEmpty: Bool { symbols.isEmpty && colors.isEmpty }
}

/// Avatar personalisation unlocked by XP level (FEEDBACK-5 J3): 30 icons (one new every
/// 1–3 levels up to level 40) and 13 colours (gradients from level 15). Pure functions.
public enum AvatarCatalog {
    public static let defaultSymbol = "person.fill"
    public static let defaultColor = "violet"

    /// Sorted by `unlockLevel`. Only symbols that exist in SF Symbols 5 (iOS 17).
    public static let symbols: [AvatarSymbolOption] = [
        AvatarSymbolOption(id: "person.fill", namePl: "Postać", unlockLevel: 1),
        AvatarSymbolOption(id: "face.smiling", namePl: "Uśmiech", unlockLevel: 1),
        AvatarSymbolOption(id: "star.fill", namePl: "Gwiazda", unlockLevel: 1),
        AvatarSymbolOption(id: "leaf.fill", namePl: "Liść", unlockLevel: 1),
        AvatarSymbolOption(id: "book.fill", namePl: "Książka", unlockLevel: 2),
        AvatarSymbolOption(id: "pawprint.fill", namePl: "Łapka", unlockLevel: 3),
        AvatarSymbolOption(id: "heart.fill", namePl: "Serce", unlockLevel: 4),
        AvatarSymbolOption(id: "airplane", namePl: "Samolot", unlockLevel: 5),
        AvatarSymbolOption(id: "music.note", namePl: "Nuta", unlockLevel: 6),
        AvatarSymbolOption(id: "bolt.fill", namePl: "Błyskawica", unlockLevel: 7),
        AvatarSymbolOption(id: "cat.fill", namePl: "Kot", unlockLevel: 8),
        AvatarSymbolOption(id: "dog.fill", namePl: "Pies", unlockLevel: 9),
        AvatarSymbolOption(id: "graduationcap.fill", namePl: "Biret", unlockLevel: 10),
        AvatarSymbolOption(id: "globe.europe.africa.fill", namePl: "Globus", unlockLevel: 12),
        AvatarSymbolOption(id: "lightbulb.fill", namePl: "Żarówka", unlockLevel: 13),
        AvatarSymbolOption(id: "bird.fill", namePl: "Ptak", unlockLevel: 14),
        AvatarSymbolOption(id: "tortoise.fill", namePl: "Żółw", unlockLevel: 16),
        AvatarSymbolOption(id: "hare.fill", namePl: "Zając", unlockLevel: 17),
        AvatarSymbolOption(id: "gamecontroller.fill", namePl: "Pad", unlockLevel: 18),
        AvatarSymbolOption(id: "mountain.2.fill", namePl: "Góry", unlockLevel: 20),
        AvatarSymbolOption(id: "paintpalette.fill", namePl: "Paleta", unlockLevel: 22),
        AvatarSymbolOption(id: "theatermasks.fill", namePl: "Maski", unlockLevel: 24),
        AvatarSymbolOption(id: "brain.head.profile", namePl: "Umysł", unlockLevel: 25),
        AvatarSymbolOption(id: "sailboat.fill", namePl: "Żaglówka", unlockLevel: 27),
        AvatarSymbolOption(id: "flame.fill", namePl: "Płomień", unlockLevel: 30),
        AvatarSymbolOption(id: "moon.stars.fill", namePl: "Księżyc", unlockLevel: 32),
        AvatarSymbolOption(id: "atom", namePl: "Atom", unlockLevel: 34),
        AvatarSymbolOption(id: "sparkles", namePl: "Iskry", unlockLevel: 36),
        AvatarSymbolOption(id: "trophy.fill", namePl: "Puchar", unlockLevel: 38),
        AvatarSymbolOption(id: "crown.fill", namePl: "Korona", unlockLevel: 40)
    ]

    /// Sorted by `unlockLevel`.
    public static let colors: [AvatarColorOption] = [
        AvatarColorOption(id: "violet", namePl: "Fiolet", unlockLevel: 1, stops: [0x7451D8]),
        AvatarColorOption(id: "ocean", namePl: "Ocean", unlockLevel: 1, stops: [0x2F6BC9]),
        AvatarColorOption(id: "mint", namePl: "Mięta", unlockLevel: 3, stops: [0x23826A]),
        AvatarColorOption(id: "sunset", namePl: "Pomarańcz", unlockLevel: 5, stops: [0xC2571F]),
        AvatarColorOption(id: "rose", namePl: "Róż", unlockLevel: 7, stops: [0xC23A6E]),
        AvatarColorOption(id: "graphite", namePl: "Grafit", unlockLevel: 9, stops: [0x4A4E5C]),
        AvatarColorOption(id: "teal", namePl: "Morski", unlockLevel: 11, stops: [0x137886]),
        AvatarColorOption(id: "amber", namePl: "Bursztyn", unlockLevel: 13, stops: [0x9A6A06]),
        AvatarColorOption(id: "aurora", namePl: "Zorza", unlockLevel: 15, stops: [0x6A46CF, 0x1E8EA8]),
        AvatarColorOption(id: "dusk", namePl: "Zmierzch", unlockLevel: 20, stops: [0xC2571F, 0xB2306A]),
        AvatarColorOption(id: "forest", namePl: "Las", unlockLevel: 25, stops: [0x1F6F52, 0x4E8A1E]),
        AvatarColorOption(id: "galaxy", namePl: "Galaktyka", unlockLevel: 30, stops: [0x2B2D7A, 0x7B3BB0, 0xB0306E]),
        AvatarColorOption(id: "gold", namePl: "Złoto", unlockLevel: 40, stops: [0xA87508, 0x8A4A0C])
    ]

    public static func symbol(id: String) -> AvatarSymbolOption? {
        symbols.first { $0.id == id }
    }

    public static func color(id: String) -> AvatarColorOption? {
        colors.first { $0.id == id }
    }

    /// Everything unlocked at `level` (levels below 1 count as 1).
    public static func unlocked(atLevel level: Int) -> AvatarUnlocks {
        let current = max(1, level)
        return AvatarUnlocks(
            level: current,
            symbols: symbols.filter { $0.unlockLevel <= current },
            colors: colors.filter { $0.unlockLevel <= current },
            nextSymbol: symbols.first { $0.unlockLevel > current },
            nextColor: colors.first { $0.unlockLevel > current }
        )
    }

    /// `false` for unknown ids.
    public static func isUnlocked(symbol id: String, atLevel level: Int) -> Bool {
        guard let option = symbol(id: id) else { return false }
        return option.unlockLevel <= max(1, level)
    }

    /// `false` for unknown ids.
    public static func isUnlocked(color id: String, atLevel level: Int) -> Bool {
        guard let option = color(id: id) else { return false }
        return option.unlockLevel <= max(1, level)
    }

    /// Unlocked after `oldLevel`, up to and including `newLevel` (empty when the level did not grow).
    public static func newlyUnlocked(fromLevel oldLevel: Int, toLevel newLevel: Int) -> AvatarUnlockDelta {
        let low = max(1, oldLevel)
        let high = max(1, newLevel)
        guard high > low else { return AvatarUnlockDelta() }
        return AvatarUnlockDelta(
            symbols: symbols.filter { $0.unlockLevel > low && $0.unlockLevel <= high },
            colors: colors.filter { $0.unlockLevel > low && $0.unlockLevel <= high }
        )
    }

    /// The avatar to display: a locked or unknown icon / colour falls back to the default one
    /// (the stored choice is kept — it shows again once the level allows it). Nickname unchanged.
    public static func resolved(_ avatar: LearnerAvatar?, level: Int) -> LearnerAvatar {
        var result = avatar ?? LearnerAvatar()
        if !isUnlocked(symbol: result.symbol, atLevel: level) {
            result.symbol = defaultSymbol
        }
        if !isUnlocked(color: result.color, atLevel: level) {
            result.color = defaultColor
        }
        return result
    }

    /// Colour stops for display (default colour for unknown ids).
    public static func stops(forColor id: String) -> [UInt32] {
        if let option = color(id: id), !option.stops.isEmpty { return option.stops }
        return colors.first?.stops ?? [0x7451D8]
    }
}
