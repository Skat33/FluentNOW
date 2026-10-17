import Foundation

/// Why the learner studies English (onboarding question 1, multiple choice).
public enum LearningGoal: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case work
    case travel
    case relocation
    case exam
    case entertainment
    case conversation
    case selfGrowth = "self-growth"

    public var id: String { rawValue }

    public var namePl: String {
        switch self {
        case .work: return "Praca"
        case .travel: return "Podróże"
        case .relocation: return "Przeprowadzka za granicę"
        case .exam: return "Egzamin lub szkoła"
        case .entertainment: return "Filmy, seriale i gry"
        case .conversation: return "Rozmowy z ludźmi"
        case .selfGrowth: return "Rozwój osobisty"
        }
    }

    /// SF Symbol.
    public var systemImage: String {
        switch self {
        case .work: return "briefcase"
        case .travel: return "airplane"
        case .relocation: return "house.and.flag"
        case .exam: return "graduationcap"
        case .entertainment: return "tv"
        case .conversation: return "bubble.left.and.bubble.right"
        case .selfGrowth: return "leaf"
        }
    }

    /// Built-in topics (`topics/<id>.json`) that serve this goal, most important first.
    public var topicIDs: [String] {
        switch self {
        case .work:
            return ["office-work", "meetings", "business-email", "job-search", "coworkers", "phone-calls", "presentations", "customer-service", "remote-work"]
        case .travel:
            return ["airport", "hotel", "directions", "restaurant", "sightseeing", "public-transport", "flight", "train-travel", "car-rental"]
        case .relocation:
            return ["renting-apartment", "moving-house", "banking", "government-offices", "doctor-visit", "utilities-bills", "grocery-shopping", "neighbors-community", "post-office"]
        case .exam:
            return ["exams-tests", "school", "university", "opinions-agreeing", "describing-places", "language-learning", "storytelling"]
        case .entertainment:
            return ["movies-tv", "music", "video-games", "feelings-reactions-phrases", "everyday-phrasal-verbs", "books-reading", "concerts-festivals"]
        case .conversation:
            return ["small-talk", "greetings-introductions", "opinions-agreeing", "feelings-reactions-phrases", "requests-favors", "apologies-politeness", "friendship", "everyday-phrasal-verbs"]
        case .selfGrowth:
            return ["language-learning", "books-reading", "fitness-gym", "mental-health", "news-media", "science", "giving-advice"]
        }
    }

    /// Topic groups (`topics/index.json`) related to this goal.
    public var topicGroups: [String] {
        switch self {
        case .work: return ["work"]
        case .travel: return ["travel"]
        case .relocation: return ["home", "services"]
        case .exam: return ["education"]
        case .entertainment: return ["leisure"]
        case .conversation: return ["communication", "people"]
        case .selfGrowth: return ["education", "health"]
        }
    }
}

/// Interests (onboarding question 3, a grid of tiles).
public enum LearningInterest: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case sport
    case food
    case technology
    case travel
    case health
    case music
    case movies
    case business
    case nature
    case science
    case fashion
    case games
    case art
    case family

    public var id: String { rawValue }

    public var namePl: String {
        switch self {
        case .sport: return "Sport"
        case .food: return "Jedzenie"
        case .technology: return "Technologia"
        case .travel: return "Podróże"
        case .health: return "Zdrowie"
        case .music: return "Muzyka"
        case .movies: return "Filmy i seriale"
        case .business: return "Biznes"
        case .nature: return "Natura"
        case .science: return "Nauka"
        case .fashion: return "Moda i uroda"
        case .games: return "Gry"
        case .art: return "Sztuka i kultura"
        case .family: return "Rodzina i relacje"
        }
    }

    public var systemImage: String {
        switch self {
        case .sport: return "figure.run"
        case .food: return "fork.knife"
        case .technology: return "desktopcomputer"
        case .travel: return "suitcase"
        case .health: return "heart"
        case .music: return "music.note"
        case .movies: return "film"
        case .business: return "chart.line.uptrend.xyaxis"
        case .nature: return "leaf"
        case .science: return "atom"
        case .fashion: return "tshirt"
        case .games: return "gamecontroller"
        case .art: return "paintpalette"
        case .family: return "person.2"
        }
    }

    /// Built-in topics for this interest, most important first.
    public var topicIDs: [String] {
        switch self {
        case .sport: return ["sports", "fitness-gym", "football", "cycling"]
        case .food: return ["cooking", "restaurant", "cafe-bakery", "diet-nutrition", "grocery-shopping"]
        case .technology: return ["smartphones-apps", "computers-internet", "artificial-intelligence", "social-media", "programming-it"]
        case .travel: return ["sightseeing", "beach-vacation", "hotel", "airport", "camping-hiking"]
        case .health: return ["fitness-gym", "diet-nutrition", "sleep", "doctor-visit", "mental-health"]
        case .music: return ["music", "concerts-festivals"]
        case .movies: return ["movies-tv", "theater", "books-reading"]
        case .business: return ["entrepreneurship", "marketing-sales", "negotiations", "finance-accounting", "economy"]
        case .nature: return ["nature-landscape", "animals", "pets", "environment-climate", "garden-plants"]
        case .science: return ["science", "space-astronomy", "math", "history"]
        case .fashion: return ["clothes-fashion", "shopping-clothes", "beauty-hairdresser"]
        case .games: return ["video-games", "board-games-puzzles"]
        case .art: return ["art-museum", "photography", "books-reading", "history"]
        case .family: return ["family", "friendship", "dating-relationships", "parenting"]
        }
    }

    public var topicGroups: [String] {
        switch self {
        case .sport, .music, .movies, .games, .art: return ["leisure"]
        case .food: return ["food"]
        case .technology: return ["technology"]
        case .travel: return ["travel"]
        case .health: return ["health"]
        case .business: return ["work"]
        case .nature: return ["nature"]
        case .science: return ["education"]
        case .fashion: return ["daily"]
        case .family: return ["people"]
        }
    }
}

/// How the learner likes to study (onboarding question 4, multiple choice).
public enum LearningStyle: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case writing
    case listening
    case pictures
    case reading
    case flashcards
    case grammar

    public var id: String { rawValue }

    public var namePl: String {
        switch self {
        case .writing: return "Pisanie"
        case .listening: return "Słuchanie"
        case .pictures: return "Obrazki"
        case .reading: return "Czytanie tekstów"
        case .flashcards: return "Fiszki"
        case .grammar: return "Gramatyka"
        }
    }

    public var detailPl: String {
        switch self {
        case .writing: return "Wpisuję słowa i zdania"
        case .listening: return "Słucham i zapisuję"
        case .pictures: return "Łączę słowa ze zdjęciami"
        case .reading: return "Krótkie teksty z pytaniami"
        case .flashcards: return "Szybkie powtórki kartami"
        case .grammar: return "Formy i konstrukcje"
        }
    }

    public var systemImage: String {
        switch self {
        case .writing: return "pencil"
        case .listening: return "headphones"
        case .pictures: return "photo"
        case .reading: return "book"
        case .flashcards: return "rectangle.on.rectangle"
        case .grammar: return "text.badge.checkmark"
        }
    }
}

/// How the start level was set.
public enum LevelSource: String, Codable, CaseIterable, Sendable, Hashable {
    /// Self-assessment („rozumiem proste zdania…”).
    case selfAssessment = "self"
    /// The quick placement test.
    case placementTest = "test"
}

/// The learner's study profile from the first-run interview (G4). Stored in
/// `LearnerSettings.profile` (synced with iCloud, exported with the state; optional and
/// backward compatible). Two copies are merged by `updatedAt` (`LearnerProfile.newer`).
public struct LearnerProfile: Codable, Sendable, Hashable {
    public var goals: [LearningGoal]
    /// CEFR level from the self-assessment or the placement test (`nil` = skipped).
    public var startLevel: String?
    public var levelSource: LevelSource?
    /// Placement test result (correct of total), when taken.
    public var placementCorrect: Int?
    public var placementTotal: Int?
    public var interests: [LearningInterest]
    public var styles: [LearningStyle]
    /// Planned minutes per day (5, 10, 15 or 20).
    public var dailyMinutes: Int?
    public var createdAt: Timestamp
    public var updatedAt: Timestamp

    public static let minuteOptions = [5, 10, 15, 20]

    public init(
        goals: [LearningGoal] = [],
        startLevel: String? = nil,
        levelSource: LevelSource? = nil,
        placementCorrect: Int? = nil,
        placementTotal: Int? = nil,
        interests: [LearningInterest] = [],
        styles: [LearningStyle] = [],
        dailyMinutes: Int? = nil,
        createdAt: Timestamp = 0,
        updatedAt: Timestamp = 0
    ) {
        self.goals = goals
        self.startLevel = startLevel
        self.levelSource = levelSource
        self.placementCorrect = placementCorrect
        self.placementTotal = placementTotal
        self.interests = interests
        self.styles = styles
        self.dailyMinutes = dailyMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case goals, startLevel, levelSource, placementCorrect, placementTotal, interests, styles, dailyMinutes, createdAt, updatedAt
    }

    /// Tolerant: unknown goals / interests / styles (e.g. from a newer version) are skipped.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let goals = c.lenientStrings(.goals).compactMap { (raw: String) -> LearningGoal? in LearningGoal(rawValue: raw) }
        let interests = c.lenientStrings(.interests).compactMap { (raw: String) -> LearningInterest? in LearningInterest(rawValue: raw) }
        let styles = c.lenientStrings(.styles).compactMap { (raw: String) -> LearningStyle? in LearningStyle(rawValue: raw) }
        let source = c.lenientOptionalString(.levelSource).flatMap { (raw: String) -> LevelSource? in LevelSource(rawValue: raw) }
        self.init(
            goals: goals,
            startLevel: c.lenientOptionalString(.startLevel),
            levelSource: source,
            placementCorrect: c.lenientOptionalInt(.placementCorrect),
            placementTotal: c.lenientOptionalInt(.placementTotal),
            interests: interests,
            styles: styles,
            dailyMinutes: c.lenientOptionalInt(.dailyMinutes),
            createdAt: c.lenientDouble(.createdAt),
            updatedAt: c.lenientDouble(.updatedAt)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(goals.map { $0.rawValue }, forKey: .goals)
        try c.encodeIfPresent(startLevel, forKey: .startLevel)
        try c.encodeIfPresent(levelSource?.rawValue, forKey: .levelSource)
        try c.encodeIfPresent(placementCorrect, forKey: .placementCorrect)
        try c.encodeIfPresent(placementTotal, forKey: .placementTotal)
        try c.encode(interests.map { $0.rawValue }, forKey: .interests)
        try c.encode(styles.map { $0.rawValue }, forKey: .styles)
        try c.encodeIfPresent(dailyMinutes, forKey: .dailyMinutes)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
    }

    // MARK: - Normalisation and merging

    /// Valid values only: unique choices, a CEFR start level, minutes 5…60, non-negative counts.
    public func normalized() -> LearnerProfile {
        var copy = self
        copy.goals = goals.uniqued()
        copy.interests = interests.uniqued()
        copy.styles = styles.uniqued()
        if let level = startLevel, !CEFR.isValid(level) {
            copy.startLevel = nil
            copy.levelSource = nil
        }
        if let minutes = dailyMinutes {
            copy.dailyMinutes = (5...60).contains(minutes) ? minutes : nil
        }
        if let total = placementTotal, total <= 0 {
            copy.placementTotal = nil
            copy.placementCorrect = nil
        }
        if let correct = placementCorrect {
            let total = copy.placementTotal ?? correct
            copy.placementCorrect = min(max(0, correct), max(0, total))
        }
        copy.createdAt = createdAt.isFinite ? max(0, createdAt) : 0
        copy.updatedAt = updatedAt.isFinite ? max(0, updatedAt) : 0
        return copy
    }

    /// The more recently edited of two profiles (ties keep `local`; `nil` loses).
    public static func newer(_ local: LearnerProfile?, _ remote: LearnerProfile?) -> LearnerProfile? {
        guard let local else { return remote }
        guard let remote else { return local }
        return remote.updatedAt > local.updatedAt ? remote : local
    }

    /// `true` when nothing was answered.
    public var isEmpty: Bool {
        goals.isEmpty && startLevel == nil && interests.isEmpty && styles.isEmpty && dailyMinutes == nil
    }

    // MARK: - Derived preferences (pure)

    /// Topic id → preference weight for recommendations and the starter set. Goals weigh more
    /// than interests; earlier topics of a goal / interest weigh more than later ones.
    public func topicWeights() -> [String: Int] {
        var weights: [String: Int] = [:]
        for goal in goals {
            for (index, topic) in goal.topicIDs.enumerated() {
                weights[topic, default: 0] += max(4, 10 - index)
            }
        }
        for interest in interests {
            for (index, topic) in interest.topicIDs.enumerated() {
                weights[topic, default: 0] += max(4, 8 - index)
            }
        }
        return weights
    }

    /// Topic group → preference weight (smaller signal than topics).
    public func groupWeights() -> [String: Int] {
        var weights: [String: Int] = [:]
        for goal in goals {
            for group in goal.topicGroups { weights[group, default: 0] += 4 }
        }
        for interest in interests {
            for group in interest.topicGroups { weights[group, default: 0] += 3 }
        }
        return weights
    }

    /// Study modes to show first on the Study screen, ordered by the learner's styles.
    /// Always starts with the daily mix (`.mixed`); unknown modes of older builds are skipped.
    public func preferredStudyModes() -> [StudyMode] {
        var raw: [String] = [StudyMode.mixed.rawValue]
        for style in styles {
            switch style {
            case .writing: raw.append(StudyMode.production.rawValue)
            case .listening: raw.append(StudyMode.mixed.rawValue)
            // Osobny tryb „Słowa i obrazki” (nie łączy się z innymi — `dailyMixModes` go pomija).
            case .pictures: raw.append(StudyMode.pictures.rawValue)
            case .reading: raw.append(StudyMode.reading.rawValue)
            case .flashcards: raw.append(StudyMode.flashcards.rawValue)
            case .grammar:
                raw.append(StudyMode.grammar.rawValue)
                raw.append(StudyMode.production.rawValue)
            }
        }
        return raw.uniqued().compactMap { (value: String) -> StudyMode? in StudyMode(rawValue: value) }
    }

    /// Modes for a combined daily mix (only modes allowed in combined sessions): vocabulary
    /// always, plus up to `limit - 1` modes the learner likes (reading, grammar, idioms…).
    public func dailyMixModes(limit: Int = 3) -> [StudyMode] {
        var result: [StudyMode] = [.mixed]
        for mode in preferredStudyModes() where mode.isCombinable && !result.contains(mode) {
            guard result.count < max(1, limit) else { break }
            result.append(mode)
        }
        return result
    }

    /// Exercise types the learner prefers (to weigh within vocabulary sessions). Empty = no preference.
    public func preferredExerciseTypes() -> [ExerciseType] {
        var raw: [Int] = []
        for style in styles {
            switch style {
            case .writing: raw += [ExerciseType.recall.rawValue, ExerciseType.cloze.rawValue]
            case .listening: raw += [ExerciseType.dictation.rawValue]
            case .pictures: raw += [ExerciseType.picture.rawValue]
            case .reading: raw += [ExerciseType.cloze.rawValue, ExerciseType.meaning.rawValue]
            case .flashcards: raw += [ExerciseType.flashcard.rawValue]
            case .grammar: raw += [ExerciseType.cloze.rawValue]
            }
        }
        return raw.uniqued().compactMap { (value: Int) -> ExerciseType? in ExerciseType(rawValue: value) }
    }

    /// Daily goal (answers) for the planned minutes: about two short tasks per minute.
    public static func dailyGoal(minutes: Int) -> Int {
        let goal = max(1, minutes) * 2
        return min(LearnerSettings.goalRange.upperBound, max(LearnerSettings.goalRange.lowerBound, goal))
    }

    /// Default session length (minutes) for the Study screen — the planned daily time, capped at 15.
    public var sessionMinutes: Int {
        guard let minutes = dailyMinutes else { return 10 }
        return min(15, max(5, minutes))
    }
}

/// Start level of the profile, used until the learner has real answer history.
public enum ProfileLevel {
    /// `LevelEstimator.estimatedLevel`, but while it is only a guess (no practiced meanings —
    /// `confidence == .low`) the profile's start level (self-assessment / placement test) wins.
    public static func estimate(_ state: LearnerState) -> LevelEstimate {
        let base = LevelEstimator.estimatedLevel(state)
        guard base.confidence != .high,
              let start = state.settings.profile?.startLevel, CEFR.isValid(start) else { return base }
        return LevelEstimate(level: start, targetLevel: CEFR.next(after: start), count: base.count, confidence: .low)
    }
}
