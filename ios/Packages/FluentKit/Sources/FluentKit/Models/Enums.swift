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

/// The vocabulary exercise types. Raw values 0–4 are the web `Task.type` numbers; 5 is iOS-only.
///
/// Flashcards (0) are no longer drawn into sessions (FEEDBACK-2 G3) — they live in the separate
/// „Fiszki” mode; the case stays so that paused sessions and old exports still decode and play.
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
    /// 5 — „Słowo i zdjęcie”: the English word, four photos, pick the right one (iOS only,
    /// concrete nouns with a cached internet photo).
    case picture = 5

    /// Types that a session may draw (everything except flashcards).
    public static let sessionTypes: [ExerciseType] = [.recall, .cloze, .meaning, .dictation, .picture]

    /// Polish exercise name (`exerciseNames`).
    public var namePl: String {
        switch self {
        case .flashcard: return "Fiszka w kontekście"
        case .recall: return "Przypomnij sobie słowo"
        case .cloze: return "Uzupełnij zdanie"
        case .meaning: return "Wybierz znaczenie"
        case .dictation: return "Posłuchaj i zapisz"
        case .picture: return "Słowo i zdjęcie"
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
        case .picture: return "Rozpoznawanie ze zdjęcia"
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
        case .picture: return .recognition
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
        case .picture: return 20
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
        case .picture: return 10
        }
    }

    /// Format used when a failed task returns at the end of a session (`nextExerciseType`).
    /// Never a flashcard (G3): dictation falls back to the meaning exercise.
    public var retryType: ExerciseType {
        switch self {
        case .flashcard: return .meaning
        case .recall: return .cloze
        case .cloze: return .recall
        case .meaning: return .dictation
        case .dictation: return .meaning
        case .picture: return .meaning
        }
    }

    /// Whether the prompt may be read aloud before answering (`exercisePromptAudioAllowed`).
    /// Recall and cloze hide the English target, so no audio before checking.
    public var promptAudioAllowed: Bool {
        switch self {
        case .flashcard, .meaning, .dictation, .picture: return true
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

/// The study modes of the exercise picker / combined sessions (the web's eight) plus the
/// iOS-only flashcard deck (G3) and picture mode (FEEDBACK-3 H2).
///
/// Decoding stays tolerant: `CombinedSession.modes` drops unknown raw values, `VocabSession.mode`
/// is a plain string (unknown → `.mixed`), and a combined task with an unknown mode only discards
/// that paused session (never the import).
public enum StudyMode: String, Codable, CaseIterable, Sendable, Hashable {
    case mixed
    case mistakes
    case pairs
    case reading
    case grammar
    case idioms
    case production
    case languageMix = "language-mix"
    /// „Fiszki”: separate deck mode (due → new → hard, swipe to answer). Never part of a
    /// combined session.
    case flashcards
    /// „Słowa i obrazki” (FEEDBACK-3 H2): only „Słowo i zdjęcie” tasks for meanings whose photos
    /// are already cached. Its own card on the study screen, never part of a combined session.
    /// Old app versions decode the stored session mode as `.mixed` (plain string, see `VocabSession`).
    case pictures

    /// Modes offered in the multi-select picker and combined sessions (everything except
    /// flashcards and pictures).
    public static let combinableModes: [StudyMode] = allCases.filter { $0.isCombinable }

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
        case .flashcards: return "Fiszki"
        case .pictures: return "Słowa i obrazki"
        }
    }

    /// Modes built from the learner's own vocabulary (`makeSession`).
    public var isVocabulary: Bool {
        self == .mixed || self == .mistakes || self == .pairs || self == .pictures
    }

    /// `false` for the flashcard deck and the picture mode, which have their own cards on the
    /// study screen and never join a combined session.
    public var isCombinable: Bool {
        self != .flashcards && self != .pictures
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
