import Foundation

/// A learnable skill of one meaning. Raw values match the web JSON keys.
public enum Skill: String, Codable, CaseIterable, Sendable, Hashable {
    case recognition
    case recall
    case spelling
    case listening
    case usage
    case pronunciation

    /// Polish label (`skillNames` on the web).
    public var namePl: String {
        switch self {
        case .recognition: return "Rozpoznawanie"
        case .recall: return "Przypominanie"
        case .spelling: return "Pisownia"
        case .listening: return "Słuchanie"
        case .usage: return "Użycie w zdaniu"
        case .pronunciation: return "Wymowa"
        }
    }

    /// The five skills averaged by `mastery` (pronunciation never counts).
    public static let masterySkills: [Skill] = [.recognition, .recall, .usage, .listening, .spelling]
}

/// The five vocabulary exercise types. Raw values are the web `Task.type` numbers.
public enum ExerciseType: Int, Codable, CaseIterable, Sendable, Hashable {
    /// 0 — „Fiszka w kontekście”.
    case flashcard = 0
    /// 1 — „Przypomnij sobie słowo” (Polish → English, typed).
    case recall = 1
    /// 2 — „Uzupełnij zdanie” (cloze).
    case cloze = 2
    /// 3 — „Wybierz znaczenie” (meaning in context).
    case meaning = 3
    /// 4 — „Posłuchaj i zapisz” (dictation).
    case dictation = 4

    /// Polish exercise name (`exerciseNames`).
    public var namePl: String {
        switch self {
        case .flashcard: return "Fiszka w kontekście"
        case .recall: return "Przypomnij sobie słowo"
        case .cloze: return "Uzupełnij zdanie"
        case .meaning: return "Wybierz znaczenie"
        case .dictation: return "Posłuchaj i zapisz"
        }
    }

    /// Short Polish label used in the exercise-kind banner.
    public var shortNamePl: String {
        switch self {
        case .flashcard: return "Fiszka"
        case .recall: return "Tłumaczenie na angielski"
        case .cloze: return "Uzupełnianie zdania"
        case .meaning: return "Rozpoznawanie znaczenia"
        case .dictation: return "Dyktando"
        }
    }

    /// The skill scored by this exercise (`taskSkills`).
    public var skill: Skill {
        switch self {
        case .flashcard: return .recognition
        case .recall: return .recall
        case .cloze: return .usage
        case .meaning: return .recognition
        case .dictation: return .listening
        }
    }

    /// Estimated duration in seconds used for session budgets (`taskSeconds`).
    public var estimatedSeconds: Int {
        switch self {
        case .flashcard: return 18
        case .recall: return 32
        case .cloze: return 42
        case .meaning: return 24
        case .dictation: return 48
        }
    }

    /// Answers slower than this count as slow (`slowSeconds`).
    public var slowSeconds: Double {
        switch self {
        case .flashcard: return 10
        case .recall: return 15
        case .cloze: return 24
        case .meaning: return 12
        case .dictation: return 25
        }
    }

    /// Format used when a failed task returns at the end of a session (`nextExerciseType`).
    public var retryType: ExerciseType {
        switch self {
        case .flashcard: return .meaning
        case .recall: return .cloze
        case .cloze: return .recall
        case .meaning: return .dictation
        case .dictation: return .flashcard
        }
    }

    /// Whether the prompt may be read aloud before answering (`exercisePromptAudioAllowed`).
    /// Recall and cloze hide the English target, so no audio before checking.
    public var promptAudioAllowed: Bool {
        switch self {
        case .flashcard, .meaning, .dictation: return true
        case .recall, .cloze: return false
        }
    }

    /// Whether this exercise also scores spelling.
    public var scoresSpelling: Bool {
        self == .recall || self == .dictation
    }
}

/// CEFR helpers. Levels are stored as plain strings for JSON compatibility.
public enum CEFR {
    /// `["A1", "A2", "B1", "B2", "C1", "C2"]`.
    public static let levels: [String] = ["A1", "A2", "B1", "B2", "C1", "C2"]

    /// Index of a level, or `nil` for unknown / empty levels.
    public static func index(of level: String) -> Int? {
        levels.firstIndex(of: level)
    }

    /// JS `indexOf` semantics (`-1` for unknown) — used to port comparators exactly.
    static func jsIndex(of level: String) -> Int {
        levels.firstIndex(of: level) ?? -1
    }

    /// `true` for A1…C2.
    public static func isValid(_ level: String) -> Bool {
        levels.contains(level)
    }

    /// The next level (C2 stays C2). Unknown levels map to A2 like the web fallback.
    public static func next(after level: String) -> String {
        guard let index = index(of: level) else { return "A2" }
        return levels[Swift.min(levels.count - 1, index + 1)]
    }
}

/// Confidence of an AI CEFR estimate.
public enum LevelConfidence: String, Codable, CaseIterable, Sendable, Hashable {
    case high
    case medium
    case low
}

/// Frequency of a meaning in everyday spoken American English.
public enum SpokenFrequency: String, Codable, CaseIterable, Sendable, Hashable {
    case veryCommon = "very_common"
    case common
    case lessCommon = "less_common"
    case rare

    /// Polish label.
    public var namePl: String {
        switch self {
        case .veryCommon: return "bardzo częste"
        case .common: return "częste"
        case .lessCommon: return "rzadsze"
        case .rare: return "rzadkie"
        }
    }

    /// Sort rank (0 = most frequent).
    public var rank: Int {
        switch self {
        case .veryCommon: return 0
        case .common: return 1
        case .lessCommon: return 2
        case .rare: return 3
        }
    }
}

/// Origin of generated content.
public enum ContentSource: String, Codable, CaseIterable, Sendable, Hashable {
    case ai
    case starter
}

/// Where a review came from. Reading reviews have a lower weight.
public enum ReviewSource: String, Codable, CaseIterable, Sendable, Hashable {
    case exercise
    case reading
}

/// Kind of a grammar / idiom practice set.
public enum PracticeKind: String, Codable, CaseIterable, Sendable, Hashable {
    case grammar
    case idioms
    case mixed

    public var namePl: String {
        switch self {
        case .grammar: return "Gramatyka w kontekście"
        case .idioms: return "Zwroty i idiomy w kontekście"
        case .mixed: return "Miks językowy"
        }
    }
}

/// The eight study modes of the exercise picker / combined sessions.
public enum StudyMode: String, Codable, CaseIterable, Sendable, Hashable {
    case mixed
    case mistakes
    case pairs
    case reading
    case grammar
    case idioms
    case production
    case languageMix = "language-mix"

    /// Polish label (`studyLabels`).
    public var namePl: String {
        switch self {
        case .mixed: return "Codzienna mieszanka"
        case .mistakes: return "Tryb pomyłek"
        case .pairs: return "Słowa w parach"
        case .reading: return "Czytanie"
        case .grammar: return "Gramatyka"
        case .idioms: return "Idiomy"
        case .production: return "Produkcja gramatyczna"
        case .languageMix: return "Miks językowy"
        }
    }

    /// Modes built from the learner's own vocabulary (`makeSession`).
    public var isVocabulary: Bool {
        self == .mixed || self == .mistakes || self == .pairs
    }
}

/// Learning status of a word (labels identical to the web).
public enum WordStatus: String, Codable, CaseIterable, Sendable, Hashable {
    case new = "Nowe"
    case learning = "Uczę się"
    case hard = "Trudne"
    case mastered = "Opanowane"
    case needsRefresh = "Do odświeżenia"
    case archived = "Archiwum"

    /// Polish label shown in the UI.
    public var namePl: String { rawValue }
}
