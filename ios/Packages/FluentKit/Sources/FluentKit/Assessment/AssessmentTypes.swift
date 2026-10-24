import Foundation

/// A block of the level test („Test”, FEEDBACK-6 K4). Blocks always come in this order; inside a
/// vocabulary block the questions mix words and levels. Raw values are stored in JSON.
public enum AssessmentBlock: String, Codable, CaseIterable, Sendable, Hashable {
    case meaning
    case recall
    case cloze
    case scramble
    case matchPairs = "match-pairs"
    case listening
    case dictation
    case grammar
    case reading

    /// Questions planned for the block (pairs: one board of five pairs; reading: one text with
    /// three questions). About 30 questions, roughly 18–20 minutes.
    public var plannedCount: Int {
        switch self {
        case .meaning, .recall, .cloze, .listening, .grammar: return 4
        case .scramble, .dictation, .reading: return 3
        case .matchPairs: return 1
        }
    }

    /// The vocabulary exercise of the block; `nil` for grammar and reading.
    public var exerciseType: ExerciseType? {
        switch self {
        case .meaning: return .meaning
        case .recall: return .recall
        case .cloze: return .cloze
        case .scramble: return .scramble
        case .matchPairs: return .matchPairs
        case .listening: return .listeningChoice
        case .dictation: return .dictation
        case .grammar, .reading: return nil
        }
    }

    /// `true` for the blocks built from words (the learner's own or from the base).
    public var isVocabulary: Bool { exerciseType != nil }

    /// Skill measured by the block (for the result „per umiejętność”).
    public var skill: AssessmentSkill {
        switch self {
        case .meaning, .matchPairs: return .recognition
        case .recall, .dictation: return .recall
        case .cloze, .scramble: return .usage
        case .listening: return .listening
        case .grammar: return .grammar
        case .reading: return .reading
        }
    }

    /// Polish block name (exercise names of the study screen).
    public var namePl: String {
        switch self {
        case .grammar: return "Gramatyka"
        case .reading: return "Czytanie ze zrozumieniem"
        default: return exerciseType?.namePl ?? rawValue
        }
    }

    /// Planned time of one question in seconds (the reading includes the passage).
    public var estimatedSeconds: Int {
        switch self {
        case .grammar: return 40
        case .reading: return 75
        default: return exerciseType?.estimatedSeconds ?? 30
        }
    }
}

/// Skills reported by the test. Dictation counts as recall (typed from memory) — it is scored by
/// FSRS as listening + spelling, but in the test it measures writing the word down.
public enum AssessmentSkill: String, Codable, CaseIterable, Sendable, Hashable {
    case recognition
    case recall
    case usage
    case listening
    case grammar
    case reading

    public var namePl: String {
        switch self {
        case .recognition: return "Rozpoznawanie słów"
        case .recall: return "Przypominanie i pisownia"
        case .usage: return "Użycie w zdaniu"
        case .listening: return "Rozumienie ze słuchu"
        case .grammar: return "Gramatyka"
        case .reading: return "Czytanie"
        }
    }
}

/// Part of the level band a vocabulary question was drawn from.
public enum AssessmentTier: String, Codable, CaseIterable, Sendable, Hashable {
    /// One level below the base level.
    case lower
    /// The base level.
    case upper
    /// One level above the base level (at most 15 %, only after a good streak).
    case stretch
}

/// The level band of a test: words only from `[base − 1, base]`, plus a small share of `base + 1`.
public struct AssessmentBand: Codable, Sendable, Hashable {
    public var base: String
    public var lower: String
    public var stretch: String?

    public init(base: String) {
        let index = CEFR.index(of: base) ?? 1
        let safe = CEFR.levels[min(CEFR.levels.count - 1, max(0, index))]
        self.base = safe
        self.lower = CEFR.levels[max(0, index - 1)]
        self.stretch = index + 1 < CEFR.levels.count ? CEFR.levels[index + 1] : nil
    }

    /// The upper end of the band (the base level).
    public var upper: String { base }

    /// Tier of a level, `nil` outside the band. On A1 the band is a single level (upper).
    public func tier(of level: String) -> AssessmentTier? {
        guard CEFR.isValid(level) else { return nil }
        if level == base { return .upper }
        if level == lower { return .lower }
        if let stretch, level == stretch { return .stretch }
        return nil
    }

    /// Level of a tier (the base level for the lower tier on A1).
    public func level(of tier: AssessmentTier) -> String {
        switch tier {
        case .lower: return lower
        case .upper: return base
        case .stretch: return stretch ?? base
        }
    }

    /// „A2–B1” (or „A1”).
    public var rangeText: String {
        lower == base ? base : "\(lower)–\(base)"
    }
}
