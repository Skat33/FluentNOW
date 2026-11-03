import Foundation

/// Kind of a learner's mistake („Twoje typowe błędy”, FEEDBACK-10 P1). Raw values are stored in
/// JSON (unknown values decode as `.otherWord`). The order is the priority used when one answer
/// shows several kinds (a wrong verb form is more telling than another word next to it).
public enum MistakeKind: String, Codable, CaseIterable, Sendable, Hashable {
    /// Another form of the right verb (went ↔ gone, make ↔ made).
    case verbForm
    /// A confused preposition (in / on / at, depend on → from).
    case preposition
    /// A confused article (a / an / the).
    case article
    /// The right word with a spelling slip (recieve → receive), within `FuzzyMatcher` thresholds.
    case typo
    /// Another word than the right one.
    case otherWord
    /// The right words in the wrong order („Ułóż zdanie”).
    case wordOrder
    /// A wrong meaning chosen or typed (choice of translation, photo, pairs, listening).
    case meaning

    /// Polish name.
    public var namePl: String {
        switch self {
        case .verbForm: return "Forma czasownika"
        case .preposition: return "Przyimek"
        case .article: return "Przedimek"
        case .typo: return "Literówka"
        case .otherWord: return "Inne słowo"
        case .wordOrder: return "Kolejność słów"
        case .meaning: return "Znaczenie"
        }
    }

    /// A short explanation in Polish with an example (shown in „Twoje typowe błędy”).
    public var explanationPl: String {
        switch self {
        case .verbForm:
            return "Po have/has/had używamy trzeciej formy (has gone, have taken), w czasie przeszłym prostym — drugiej (went, took), a po „to” i czasownikach modalnych — formy podstawowej (to go, can take)."
        case .preposition:
            return "Przyimków nie tłumacz dosłownie z polskiego — ucz się ich w całych połączeniach: depend on, interested in, at night, on Monday, in July."
        case .article:
            return "„an” stawiamy przed samogłoską w wymowie (an hour, an apple), „a” przed spółgłoską (a university), a „the”, gdy wiadomo, o którą rzecz chodzi."
        case .typo:
            return "Znasz słowo, ale zgubiła się litera. Przepisz je powoli i powiedz na głos — pisownia utrwala się szybciej, gdy ją słyszysz."
        case .otherWord:
            return "Wpisane słowo istnieje, ale nie pasuje do tego znaczenia. Przeczytaj zdanie przykładowe — kontekst podpowiada właściwe słowo."
        case .wordOrder:
            return "Angielskie zdanie ma stały szyk: kto? → co robi? → co? → gdzie? → kiedy? (She bought a car in May). Pytania zaczynają się od czasownika posiłkowego (Do you…?)."
        case .meaning:
            return "Mylisz znaczenia podobnych słów. Przy powtórce czytaj całe zdanie — znaczenie zależy od kontekstu."
        }
    }

    /// The decoy kind of „Ułóż zdanie” that trains this mistake (adaptive decoys); `nil` for kinds
    /// without a matching decoy.
    public var decoyKind: ScrambleDecoyKind? {
        switch self {
        case .verbForm: return .verbForm
        case .preposition: return .preposition
        case .article: return .article
        case .typo, .otherWord, .wordOrder, .meaning: return nil
        }
    }

    /// Position in `allCases` (priority, stable tie-breaker).
    var rank: Int {
        MistakeKind.allCases.firstIndex(of: self) ?? MistakeKind.allCases.count
    }
}

/// One wrong answer in the mistake log (FEEDBACK-10 P1). Entries are immutable once written —
/// two devices never edit the same entry, so the log merges as a union by `id`.
///
/// Decoding is tolerant: unknown kinds become `.otherWord`, missing texts are empty; an entry with
/// an unknown exercise type is dropped by the lossy array of `LearnerState`.
public struct MistakeEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    /// Answer time (ms).
    public var at: Timestamp
    /// The exercise shown (after display fallbacks, e.g. a scramble shown as a cloze).
    public var exercise: ExerciseType
    public var kind: MistakeKind
    /// The expected answer (word, translation or the whole sentence).
    public var expected: String
    /// The learner's answer.
    public var given: String
    /// The part that differs („gone”); empty when the whole answer differs or only the order is wrong.
    public var expectedPart: String
    /// The learner's version of that part („went”).
    public var givenPart: String
    public var wordId: String
    public var meaningId: String
    /// Example index of the task (practice uses the same sentence).
    public var example: Int
    /// The example sentence or the Polish prompt of the task (may be empty).
    public var context: String

    public init(
        id: String,
        at: Timestamp,
        exercise: ExerciseType,
        kind: MistakeKind,
        expected: String,
        given: String,
        expectedPart: String = "",
        givenPart: String = "",
        wordId: String,
        meaningId: String,
        example: Int = 0,
        context: String = ""
    ) {
        self.id = id
        self.at = at
        self.exercise = exercise
        self.kind = kind
        self.expected = expected
        self.given = given
        self.expectedPart = expectedPart
        self.givenPart = givenPart
        self.wordId = wordId
        self.meaningId = meaningId
        self.example = example
        self.context = context
    }

    enum CodingKeys: String, CodingKey {
        case id, at, exercise, kind, expected, given, expectedPart, givenPart, wordId, meaningId, example, context
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        at = c.lenientDouble(.at)
        let rawExercise = c.lenientInt(.exercise, default: -1)
        guard let parsed = ExerciseType(rawValue: rawExercise) else {
            throw DecodingError.dataCorruptedError(forKey: .exercise, in: c, debugDescription: "Nieznany typ zadania: \(rawExercise)")
        }
        exercise = parsed
        kind = MistakeKind(rawValue: c.lenientString(.kind)) ?? .otherWord
        expected = c.lenientString(.expected)
        given = c.lenientString(.given)
        expectedPart = c.lenientString(.expectedPart)
        givenPart = c.lenientString(.givenPart)
        wordId = c.lenientString(.wordId)
        meaningId = c.lenientString(.meaningId)
        example = max(0, c.lenientInt(.example))
        context = c.lenientString(.context)
    }
}

/// A pair of confused words with its count („in” → „on”, 4×).
public struct MistakePair: Sendable, Hashable {
    public var expected: String
    public var given: String
    public var count: Int

    public init(expected: String, given: String, count: Int) {
        self.expected = expected
        self.given = given
        self.count = count
    }
}

/// One group of „Twoje typowe błędy”: all mistakes of one kind.
public struct MistakePattern: Sendable, Hashable, Identifiable {
    public var kind: MistakeKind
    public var count: Int
    /// Time of the newest mistake of this kind.
    public var lastAt: Timestamp
    /// The most frequent confused pairs (at most three, most frequent first).
    public var pairs: [MistakePair]
    /// The newest mistakes (newest first).
    public var examples: [MistakeEntry]
    /// Distinct meanings with this kind of mistake.
    public var meaningCount: Int

    public var id: String { kind.rawValue }

    public init(kind: MistakeKind, count: Int, lastAt: Timestamp, pairs: [MistakePair], examples: [MistakeEntry], meaningCount: Int) {
        self.kind = kind
        self.count = count
        self.lastAt = lastAt
        self.pairs = pairs
        self.examples = examples
        self.meaningCount = meaningCount
    }

    /// The confused words of the most frequent pairs, e.g. `["in", "on", "at"]` (at most four).
    public var confusedWords: [String] {
        var words: [String] = []
        for pair in pairs {
            for word in [pair.expected, pair.given] where !word.isEmpty && !words.contains(word) {
                words.append(word)
            }
        }
        return Array(words.prefix(4))
    }

    /// „Mylisz in / on / at”, „Literówki”…
    public var headlinePl: String {
        let words = confusedWords.joined(separator: " / ")
        switch kind {
        case .verbForm:
            return words.isEmpty ? "Mylisz formy czasowników" : "Mylisz formy czasowników (\(words))"
        case .preposition:
            return words.isEmpty ? "Mylisz przyimki" : "Mylisz \(words)"
        case .article:
            return words.isEmpty ? "Mylisz przedimki" : "Mylisz \(words)"
        case .typo:
            return "Literówki"
        case .otherWord:
            return "Inne słowo zamiast właściwego"
        case .wordOrder:
            return "Kolejność słów w zdaniu"
        case .meaning:
            return "Mylisz znaczenia słów"
        }
    }

    /// „7 razy”, „1 raz”.
    public var countPl: String {
        count == 1 ? "1 raz" : "\(count) razy"
    }

    /// „Mylisz in / on / at — 7 razy”.
    public var summaryPl: String {
        "\(headlinePl) — \(countPl)"
    }
}

/// The mistake log of `LearnerState.mistakes` (FEEDBACK-10 P1): the latest `limit` wrong answers,
/// oldest first. Pure functions — order, merge and statistics are deterministic.
public enum MistakeLog {
    /// Entries kept (the oldest are dropped).
    public static let limit = 500
    /// Texts are clipped to this many characters (a pasted essay must not bloat the log).
    static let maxTextLength = 240
    /// Adaptive decoys look at this many newest sentence mistakes…
    public static let decoyWindow = 100
    /// …and need at least this many of one kind.
    public static let decoyMinimum = 2

    // MARK: Order, merge, limit

    /// Unique by `id` (first occurrence wins), sorted by time then id, the newest `limit` kept.
    /// Idempotent; the result does not depend on the input order (except which duplicate wins).
    public static func normalized(_ entries: [MistakeEntry]) -> [MistakeEntry] {
        var seen = Set<String>()
        var unique: [MistakeEntry] = []
        unique.reserveCapacity(entries.count)
        for entry in entries where !entry.id.isEmpty && seen.insert(entry.id).inserted {
            unique.append(entry)
        }
        unique.sort { (a: MistakeEntry, b: MistakeEntry) -> Bool in
            a.at != b.at ? a.at < b.at : a.id < b.id
        }
        return unique.count > limit ? Array(unique.suffix(limit)) : unique
    }

    /// Union of two logs (`local` wins duplicates), same order and limit as `normalized` — both
    /// devices keep exactly the same entries after syncing.
    public static func merge(local: [MistakeEntry], remote: [MistakeEntry]) -> [MistakeEntry] {
        normalized(local + remote)
    }

    /// The state with `entries` added to its log.
    public static func recording(_ entries: [MistakeEntry], in state: LearnerState) -> LearnerState {
        guard !entries.isEmpty else { return state }
        var next = state
        next.mistakes = normalized(state.mistakes + entries)
        return next
    }

    /// A new entry with texts clipped to `maxTextLength`.
    public static func entry(
        id: String,
        at: Timestamp,
        exercise: ExerciseType,
        analysis: MistakeAnalysis,
        expected: String,
        given: String,
        wordId: String,
        meaningId: String,
        example: Int,
        context: String
    ) -> MistakeEntry {
        MistakeEntry(
            id: id,
            at: at,
            exercise: exercise,
            kind: analysis.kind,
            expected: clipped(expected),
            given: clipped(given),
            expectedPart: clipped(analysis.expectedPart),
            givenPart: clipped(analysis.givenPart),
            wordId: wordId,
            meaningId: meaningId,
            example: max(0, example),
            context: clipped(context)
        )
    }

    static func clipped(_ text: String) -> String {
        let trimmed = TextScanning.trim(text)
        return trimmed.count > maxTextLength ? String(trimmed.prefix(maxTextLength)) : trimmed
    }

    // MARK: Adaptive decoys

    /// The grammar kind (verb form, preposition, article) the learner confused most often among
    /// the newest `decoyWindow` mistakes with a matching decoy kind; at least `decoyMinimum` of
    /// them. Ties → `MistakeKind` order. `nil` = the usual decoy priority.
    public static func decoyFocus(_ entries: [MistakeEntry]) -> MistakeKind? {
        var counts: [MistakeKind: Int] = [:]
        var looked = 0
        for entry in entries.reversed() where entry.kind.decoyKind != nil {
            counts[entry.kind, default: 0] += 1
            looked += 1
            if looked >= decoyWindow { break }
        }
        var best: MistakeKind?
        var bestCount = 0
        for kind in MistakeKind.allCases {
            let count = counts[kind] ?? 0
            if count >= decoyMinimum && count > bestCount {
                best = kind
                bestCount = count
            }
        }
        return best
    }

    /// The session with its decoy focus taken from the state's log. Stored in the session, so a
    /// resumed task shows the same tiles even after new mistakes were logged.
    public static func withDecoyFocus(_ session: VocabSession, state: LearnerState) -> VocabSession {
        var copy = session
        copy.decoyFocus = decoyFocus(state.mistakes)
        return copy
    }

    // MARK: Patterns

    /// „Twoje typowe błędy”: one group per kind, the most frequent first (then the newest, then
    /// `MistakeKind` order). `exampleLimit` newest mistakes per group.
    public static func patterns(_ entries: [MistakeEntry], exampleLimit: Int = 4) -> [MistakePattern] {
        var byKind: [MistakeKind: [MistakeEntry]] = [:]
        for entry in entries {
            byKind[entry.kind, default: []].append(entry)
        }
        var result: [MistakePattern] = []
        for kind in MistakeKind.allCases {
            guard let items = byKind[kind], !items.isEmpty else { continue }
            let newestFirst = items.sorted { (a: MistakeEntry, b: MistakeEntry) -> Bool in
                a.at != b.at ? a.at > b.at : a.id > b.id
            }
            result.append(MistakePattern(
                kind: kind,
                count: items.count,
                lastAt: newestFirst.first?.at ?? 0,
                pairs: pairs(items),
                examples: Array(newestFirst.prefix(max(0, exampleLimit))),
                meaningCount: Set(items.map { (entry: MistakeEntry) -> String in entry.meaningId }).count
            ))
        }
        result.sort { (a: MistakePattern, b: MistakePattern) -> Bool in
            if a.count != b.count { return a.count > b.count }
            if a.lastAt != b.lastAt { return a.lastAt > b.lastAt }
            return a.kind.rank < b.kind.rank
        }
        return result
    }

    /// The most frequent confused pairs (single words only, lower case), at most three.
    static func pairs(_ entries: [MistakeEntry]) -> [MistakePair] {
        var counts: [String: (pair: MistakePair, last: Timestamp)] = [:]
        for entry in entries {
            let expected = entry.expectedPart.lowercased()
            let given = entry.givenPart.lowercased()
            guard !expected.isEmpty, !given.isEmpty, expected != given else { continue }
            let key = expected + "\u{1F}" + given
            if var saved = counts[key] {
                saved.pair.count += 1
                saved.last = max(saved.last, entry.at)
                counts[key] = saved
            } else {
                counts[key] = (pair: MistakePair(expected: expected, given: given, count: 1), last: entry.at)
            }
        }
        let sorted = counts.values.sorted { (a: (pair: MistakePair, last: Timestamp), b: (pair: MistakePair, last: Timestamp)) -> Bool in
            if a.pair.count != b.pair.count { return a.pair.count > b.pair.count }
            if a.last != b.last { return a.last > b.last }
            if a.pair.expected != b.pair.expected { return a.pair.expected < b.pair.expected }
            return a.pair.given < b.pair.given
        }
        return Array(sorted.prefix(3).map { (item: (pair: MistakePair, last: Timestamp)) -> MistakePair in item.pair })
    }
}
