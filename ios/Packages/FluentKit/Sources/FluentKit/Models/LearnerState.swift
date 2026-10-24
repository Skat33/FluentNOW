import Foundation

/// A finished reading (web `readingHistory[n]`).
public struct ReadingHistoryEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var at: Timestamp
    public var level: String
    public var correct: Int
    public var total: Int
    public var title: String?

    public init(id: String, at: Timestamp, level: String, correct: Int, total: Int, title: String? = nil) {
        self.id = id
        self.at = at
        self.level = level
        self.correct = correct
        self.total = total
        self.title = title
    }

    enum CodingKeys: String, CodingKey {
        case id, at, level, correct, total, title
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        at = c.lenientDouble(.at)
        level = c.lenientString(.level)
        correct = max(0, c.lenientInt(.correct))
        total = max(0, c.lenientInt(.total))
        title = c.lenientOptionalString(.title)
    }
}

/// A finished grammar / idiom / mixed set (web `practiceHistory[n]`).
public struct PracticeHistoryEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var at: Timestamp
    public var kind: PracticeKind
    public var level: String
    public var correct: Int
    public var total: Int
    public var title: String

    public init(id: String, at: Timestamp, kind: PracticeKind, level: String, correct: Int, total: Int, title: String) {
        self.id = id
        self.at = at
        self.kind = kind
        self.level = level
        self.correct = correct
        self.total = total
        self.title = title
    }

    enum CodingKeys: String, CodingKey {
        case id, at, kind, level, correct, total, title
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        at = c.lenientDouble(.at)
        kind = PracticeKind(rawValue: c.lenientString(.kind, default: "grammar")) ?? .grammar
        level = c.lenientString(.level)
        correct = max(0, c.lenientInt(.correct))
        total = max(0, c.lenientInt(.total))
        title = c.lenientString(.title)
    }
}

/// A finished production set (web `productionHistory[n]`).
public struct ProductionHistoryEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var at: Timestamp
    public var level: String
    public var correct: Int
    public var total: Int
    public var title: String

    public init(id: String, at: Timestamp, level: String, correct: Int, total: Int, title: String) {
        self.id = id
        self.at = at
        self.level = level
        self.correct = correct
        self.total = total
        self.title = title
    }

    enum CodingKeys: String, CodingKey {
        case id, at, level, correct, total, title
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        at = c.lenientDouble(.at)
        level = c.lenientString(.level)
        correct = max(0, c.lenientInt(.correct))
        total = max(0, c.lenientInt(.total))
        title = c.lenientString(.title)
    }
}

/// The complete learner document (web `State`). This is what the web exports as
/// `{ "version": 1, "state": … }` and what FluentKit imports, merges and exports.
///
/// Decoding is tolerant: missing optional collections default to empty, malformed history
/// entries are skipped, and malformed *transient* sessions (vocabulary, reading, practice,
/// production, combined) are dropped instead of failing the whole document. Words and their
/// meanings are decoded strictly — a broken word fails the import with a readable error
/// rather than being silently lost. Always run `StateMigration.migrate` after decoding.
public struct LearnerState: Codable, Sendable, Hashable {
    public var combined: CombinedSession?
    /// Bank task id → last time it was shown (ms).
    public var grammarSeen: [String: Double]
    public var words: [Word]
    public var collections: [String]
    public var reviews: [Review]
    public var reviewSummaries: [ReviewSummary]
    public var settings: LearnerSettings
    public var session: VocabSession?
    public var reading: ReadingSession?
    public var readingHistory: [ReadingHistoryEntry]
    public var practice: PracticeSession?
    public var production: ProductionSession?
    public var productionHistory: [ProductionHistoryEntry]
    public var practiceHistory: [PracticeHistoryEntry]
    /// `true` for the web demo starter set.
    public var demo: Bool
    /// iOS (FEEDBACK-6 K4): the level test in progress, or finished until its result is closed.
    /// Optional in JSON — older states and the web export decode with `nil`.
    public var assessment: AssessmentSession?
    /// iOS: finished level tests (date, score, level). Optional in JSON (`[]`).
    public var assessmentHistory: [AssessmentHistoryEntry]

    public init(
        combined: CombinedSession? = nil,
        grammarSeen: [String: Double] = [:],
        words: [Word] = [],
        collections: [String] = [],
        reviews: [Review] = [],
        reviewSummaries: [ReviewSummary] = [],
        settings: LearnerSettings = LearnerSettings(),
        session: VocabSession? = nil,
        reading: ReadingSession? = nil,
        readingHistory: [ReadingHistoryEntry] = [],
        practice: PracticeSession? = nil,
        production: ProductionSession? = nil,
        productionHistory: [ProductionHistoryEntry] = [],
        practiceHistory: [PracticeHistoryEntry] = [],
        demo: Bool = false,
        assessment: AssessmentSession? = nil,
        assessmentHistory: [AssessmentHistoryEntry] = []
    ) {
        self.combined = combined
        self.grammarSeen = grammarSeen
        self.words = words
        self.collections = collections
        self.reviews = reviews
        self.reviewSummaries = reviewSummaries
        self.settings = settings
        self.session = session
        self.reading = reading
        self.readingHistory = readingHistory
        self.practice = practice
        self.production = production
        self.productionHistory = productionHistory
        self.practiceHistory = practiceHistory
        self.demo = demo
        self.assessment = assessment
        self.assessmentHistory = assessmentHistory
    }

    /// A clean state for a new learner.
    public static let empty = LearnerState()

    enum CodingKeys: String, CodingKey {
        case combined, grammarSeen, words, collections, reviews, reviewSummaries, settings, session, reading
        case readingHistory, practice, production, productionHistory, practiceHistory, demo
        case assessment, assessmentHistory
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        words = try c.decode([Word].self, forKey: .words)
        combined = c.lenientOptional(CombinedSession.self, forKey: .combined)
        grammarSeen = LearnerState.decodeGrammarSeen(c)
        collections = c.lenientStrings(.collections)
        reviews = c.lossyArray(Review.self, forKey: .reviews)
        reviewSummaries = c.lossyArray(ReviewSummary.self, forKey: .reviewSummaries)
        settings = c.lenientOptional(LearnerSettings.self, forKey: .settings) ?? LearnerSettings()
        session = c.lenientOptional(VocabSession.self, forKey: .session)
        reading = c.lenientOptional(ReadingSession.self, forKey: .reading)
        readingHistory = c.lossyArray(ReadingHistoryEntry.self, forKey: .readingHistory)
        practice = c.lenientOptional(PracticeSession.self, forKey: .practice)
        production = c.lenientOptional(ProductionSession.self, forKey: .production)
        productionHistory = c.lossyArray(ProductionHistoryEntry.self, forKey: .productionHistory)
        practiceHistory = c.lossyArray(PracticeHistoryEntry.self, forKey: .practiceHistory)
        demo = c.lenientBool(.demo)
        // A damaged test is dropped (like the other transient sessions), never the document.
        assessment = c.lenientOptional(AssessmentSession.self, forKey: .assessment)
        assessmentHistory = c.lossyArray(AssessmentHistoryEntry.self, forKey: .assessmentHistory)
    }

    private static func decodeGrammarSeen(_ c: KeyedDecodingContainer<CodingKeys>) -> [String: Double] {
        guard let raw = try? c.decodeIfPresent([String: FailableDecodable<Double>].self, forKey: .grammarSeen) else {
            return [:]
        }
        var result: [String: Double] = [:]
        for (key, box) in raw {
            if let value = box.value, value.isFinite, value >= 0 {
                result[key] = value
            }
        }
        return result
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(combined, forKey: .combined)
        if combined == nil { try c.encodeNil(forKey: .combined) }
        try c.encode(grammarSeen, forKey: .grammarSeen)
        try c.encode(words, forKey: .words)
        try c.encode(collections, forKey: .collections)
        try c.encode(reviews, forKey: .reviews)
        try c.encode(reviewSummaries, forKey: .reviewSummaries)
        try c.encode(settings, forKey: .settings)
        // `session` is required (nullable) by the web schema.
        if let session {
            try c.encode(session, forKey: .session)
        } else {
            try c.encodeNil(forKey: .session)
        }
        if let reading {
            try c.encode(reading, forKey: .reading)
        } else {
            try c.encodeNil(forKey: .reading)
        }
        try c.encode(readingHistory, forKey: .readingHistory)
        if let practice {
            try c.encode(practice, forKey: .practice)
        } else {
            try c.encodeNil(forKey: .practice)
        }
        if let production {
            try c.encode(production, forKey: .production)
        } else {
            try c.encodeNil(forKey: .production)
        }
        try c.encode(productionHistory, forKey: .productionHistory)
        try c.encode(practiceHistory, forKey: .practiceHistory)
        try c.encode(demo, forKey: .demo)
        // Nullable like `combined`: always written, `null` when there is no test.
        if let assessment {
            try c.encode(assessment, forKey: .assessment)
        } else {
            try c.encodeNil(forKey: .assessment)
        }
        try c.encode(assessmentHistory, forKey: .assessmentHistory)
    }

    // MARK: - Lookup helpers

    /// Word by id.
    public func word(id: String) -> Word? {
        words.first { $0.id == id }
    }

    /// Word and meaning for a meaning id.
    public func wordAndMeaning(meaningID: String) -> (word: Word, meaning: Meaning)? {
        for word in words {
            if let meaning = word.meanings.first(where: { $0.id == meaningID }) {
                return (word, meaning)
            }
        }
        return nil
    }

    /// Index of a word by id.
    public func wordIndex(id: String) -> Int? {
        words.firstIndex { $0.id == id }
    }
}
