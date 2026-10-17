import Foundation

/// A built-in meaning that may be recommended („Polecane słówka”). Built once from
/// `dictionary-index.json` + `topics/index.json` (`UsefulWordRecommender.candidates`).
public struct UsefulWordCandidate: Sendable, Hashable, Identifiable {
    /// `<file>/<entry id>` (dictionary `r`) — unique.
    public var reference: String
    public var term: String
    /// Normalised term (dictionary `k`).
    public var key: String
    public var translation: String
    public var level: String
    public var frequency: SpokenFrequency
    /// Topic file id (`starter` for starter words).
    public var topicID: String
    public var topicName: String
    /// Topic group id (`basics`, `food`, …).
    public var group: String
    public var id: String { reference }

    public init(reference: String, term: String, key: String? = nil, translation: String, level: String, frequency: SpokenFrequency, topicID: String, topicName: String, group: String) {
        self.reference = reference
        self.term = term
        self.key = key ?? TextNormalizer.searchKey(term)
        self.translation = translation
        self.level = level
        self.frequency = frequency
        self.topicID = topicID
        self.topicName = topicName
        self.group = group
    }
}

/// Why a word is recommended (short Polish justification).
public enum UsefulWordReason: Sendable, Hashable {
    case frequent(SpokenFrequency)
    /// At (or just below) the learner's level.
    case fitsLevel(String)
    /// One level above — the learner's next target.
    case nextLevel(String)
    /// From a topic the learner already studies (topic name).
    case learnedTopic(String)
    /// From an everyday topic group.
    case everyday
    /// From a topic that matches the learner's goals or interests (topic name) — G4 profile.
    case interest(String)

    /// Polish text, e.g. „z tematu Restauracja, którego się uczysz”.
    public var textPl: String {
        switch self {
        case .frequent(let frequency):
            return frequency == .veryCommon ? "bardzo często używane" : "często używane"
        case .fitsLevel(let level):
            return "pasuje do Twojego poziomu \(level)"
        case .nextLevel(let level):
            return "krok w stronę poziomu \(level)"
        case .learnedTopic(let name):
            return "z tematu \(name), którego się uczysz"
        case .everyday:
            return "przydatne na co dzień"
        case .interest(let name):
            return "z tematu \(name), który pasuje do Twoich celów"
        }
    }
}

/// A ranked recommendation.
public struct UsefulWordSuggestion: Sendable, Hashable, Identifiable {
    public var candidate: UsefulWordCandidate
    /// Relevance score (higher = better); only meaningful relative to other suggestions.
    public var score: Int
    /// Most personal reason first.
    public var reasons: [UsefulWordReason]
    public var id: String { candidate.reference }

    public init(candidate: UsefulWordCandidate, score: Int, reasons: [UsefulWordReason]) {
        self.candidate = candidate
        self.score = score
        self.reasons = reasons
    }

    /// The two most important reasons, e.g. „Z tematu Restauracja, którego się uczysz · często używane”.
    public var summaryPl: String {
        let text = reasons.prefix(2).map { $0.textPl }.joined(separator: " · ")
        guard let first = text.first else { return "" }
        return first.uppercased() + String(text.dropFirst())
    }
}

/// What the learner already has and studies — the input of the ranking.
public struct UsefulWordProfile: Sendable, Hashable {
    /// Estimated level and the target (estimated + 1).
    public var level: String
    public var targetLevel: String
    /// Normalised terms of all words (also archived — the learner has seen them).
    public var ownedKeys: Set<String>
    /// Content references of all meanings.
    public var ownedReferences: Set<String>
    /// Topic id → number of non-archived meanings added from that topic.
    public var topicCounts: [String: Int]
    /// Normalised collection names of non-archived words (fallback topic signal).
    public var collectionKeys: Set<String>
    /// Topic id → bonus from the learner's goals and interests (G4 `LearnerProfile.topicWeights`).
    public var topicPreferences: [String: Int]
    /// Topic group → bonus from goals and interests (`LearnerProfile.groupWeights`).
    public var groupPreferences: [String: Int]

    public init(level: String, targetLevel: String, ownedKeys: Set<String> = [], ownedReferences: Set<String> = [], topicCounts: [String: Int] = [:], collectionKeys: Set<String> = [], topicPreferences: [String: Int] = [:], groupPreferences: [String: Int] = [:]) {
        self.level = level
        self.targetLevel = targetLevel
        self.ownedKeys = ownedKeys
        self.ownedReferences = ownedReferences
        self.topicCounts = topicCounts
        self.collectionKeys = collectionKeys
        self.topicPreferences = topicPreferences
        self.groupPreferences = groupPreferences
    }

    /// Profile of a learner state. Level: `estimate` if given, otherwise `ProfileLevel.estimate`
    /// (the interview's start level until there is practice history) — or plain
    /// `LevelEstimator.estimatedLevel` with `usesLearnerProfile: false`, which also ignores goals
    /// and interests.
    public static func make(_ state: LearnerState, estimate: LevelEstimate? = nil, usesLearnerProfile: Bool = true) -> UsefulWordProfile {
        let learner: LearnerProfile? = usesLearnerProfile ? state.settings.profile : nil
        let level = estimate ?? (usesLearnerProfile ? ProfileLevel.estimate(state) : LevelEstimator.estimatedLevel(state))
        var keys = Set<String>()
        var references = Set<String>()
        var counts: [String: Int] = [:]
        var collections = Set<String>()
        for word in state.words {
            let key = TextNormalizer.searchKey(word.en)
            if !key.isEmpty { keys.insert(key) }
            for meaning in word.meanings {
                if let reference = meaning.contentRef { references.insert(reference) }
            }
            guard !word.archived else { continue }
            let collection = TextNormalizer.searchKey(word.collection)
            if !collection.isEmpty { collections.insert(collection) }
            for meaning in word.meanings {
                guard let raw = meaning.contentRef, let reference = ContentReference(raw), !reference.isStarter else { continue }
                counts[reference.file, default: 0] += 1
            }
        }
        return UsefulWordProfile(
            level: level.level,
            targetLevel: level.targetLevel,
            ownedKeys: keys,
            ownedReferences: references,
            topicCounts: counts,
            collectionKeys: collections,
            topicPreferences: learner?.topicWeights() ?? [:],
            groupPreferences: learner?.groupWeights() ?? [:]
        )
    }

    /// Bonus of a candidate's topic: capped so goals/interests never outweigh frequency.
    func preferenceBonus(topicID: String, group: String) -> (topic: Int, group: Int) {
        let topic = min(14, topicPreferences[topicID] ?? 0)
        let groupBonus = min(6, groupPreferences[group] ?? 0)
        return (topic, groupBonus)
    }
}

/// Ranking options.
public struct UsefulWordOptions: Sendable, Hashable {
    public var limit: Int
    /// Maximum suggestions from one topic; `nil` = derived from `limit` (20 → 4).
    public var maxPerTopic: Int?
    /// Known registers (`reference` → `register` of the entry). Unknown = allowed; the app fills
    /// this lazily for the top results and ranks again (the dictionary index has no register).
    public var registers: [String: String]
    /// References that must not be suggested (e.g. entries that could not be loaded).
    public var excludedReferences: Set<String>
    /// Order of equally scored words (stable hash of `seed` + term, not alphabetical). The app
    /// passes the week number, so the list changes week to week but stays stable within a week.
    public var seed: Int

    public init(limit: Int = 20, maxPerTopic: Int? = nil, registers: [String: String] = [:], excludedReferences: Set<String> = [], seed: Int = 0) {
        self.limit = limit
        self.maxPerTopic = maxPerTopic
        self.registers = registers
        self.excludedReferences = excludedReferences
        self.seed = seed
    }
}

/// „Polecane słówka”: built-in words that are genuinely useful in everyday life.
///
/// Rules (FEEDBACK-1 F5): only `very_common` / `common`; level ≤ target (estimated + 1);
/// no slang, specialist register only for topics the learner studies; never words the learner
/// already has; topics the learner studies and everyday groups preferred; one meaning per term;
/// variety (a cap per topic and per group). Deterministic: the same input gives the same output
/// regardless of the candidate order.
public enum UsefulWordRecommender {
    /// Everyday topic groups (podstawy, codzienność, komunikacja, jedzenie, podróże, zdrowie, zakupy).
    public static let everydayGroups: Set<String> = ["basics", "daily", "communication", "food", "travel", "health", "money"]
    /// Display name of `starter-words.json` entries.
    public static let starterTopicName = "Podstawowe słowa"
    /// Group of starter entries.
    public static let starterGroup = "basics"

    // MARK: Candidates

    public static func candidates(index: DictionaryIndex, topics: TopicIndex) -> [UsefulWordCandidate] {
        candidates(entries: index.entries, topics: topics)
    }

    /// Frequent entries with a valid level and a known topic (topics missing from the index are skipped).
    public static func candidates(entries: [DictionaryIndex.Entry], topics: TopicIndex) -> [UsefulWordCandidate] {
        var summaries: [String: TopicSummary] = [:]
        for topic in topics.topics where summaries[topic.id] == nil {
            summaries[topic.id] = topic
        }
        var result: [UsefulWordCandidate] = []
        result.reserveCapacity(entries.count)
        for entry in entries {
            guard let frequency = entry.spokenFrequency, isFrequent(frequency) else { continue }
            guard CEFR.isValid(entry.level), !TextScanning.trim(entry.translation).isEmpty else { continue }
            guard let reference = entry.contentReference else { continue }
            let name: String
            let group: String
            if reference.isStarter {
                name = starterTopicName
                group = starterGroup
            } else if let summary = summaries[reference.file] {
                name = summary.namePl
                group = summary.group
            } else {
                continue
            }
            result.append(UsefulWordCandidate(
                reference: reference.rawValue,
                term: entry.term,
                key: entry.key.isEmpty ? TextNormalizer.searchKey(entry.term) : entry.key,
                translation: entry.translation,
                level: entry.level,
                frequency: frequency,
                topicID: reference.file,
                topicName: name,
                group: group
            ))
        }
        return result
    }

    /// `very_common` or `common`.
    public static func isFrequent(_ frequency: SpokenFrequency) -> Bool {
        frequency == .veryCommon || frequency == .common
    }

    /// Slang never; specialist register only for a topic the learner studies.
    public static func isAllowedRegister(_ register: String, learnedTopic: Bool) -> Bool {
        switch TextNormalizer.searchKey(register) {
        case "slangowy": return false
        case "specjalistyczny": return learnedTopic
        default: return true
        }
    }

    // MARK: Ranking

    /// Ranked, varied suggestions (at most `options.limit`).
    public static func recommend(_ candidates: [UsefulWordCandidate], profile: UsefulWordProfile, options: UsefulWordOptions = UsefulWordOptions()) -> [UsefulWordSuggestion] {
        let limit = max(0, options.limit)
        guard limit > 0, !candidates.isEmpty else { return [] }
        let maxIndex = CEFR.levels.count - 1
        let userIndex = CEFR.index(of: profile.level) ?? 0
        let targetIndex = max(userIndex, CEFR.index(of: profile.targetLevel) ?? min(maxIndex, userIndex + 1))

        var learnedCache: [String: Int] = [:]
        func learnedCount(_ candidate: UsefulWordCandidate) -> Int {
            if let cached = learnedCache[candidate.topicID] { return cached }
            var value = profile.topicCounts[candidate.topicID] ?? 0
            if value == 0 && profile.collectionKeys.contains(TextNormalizer.searchKey(candidate.topicName)) {
                value = 1
            }
            learnedCache[candidate.topicID] = value
            return value
        }

        var best: [String: Ranked] = [:]
        for candidate in candidates {
            guard isFrequent(candidate.frequency),
                  let levelIndex = CEFR.index(of: candidate.level), levelIndex <= targetIndex,
                  !profile.ownedKeys.contains(candidate.key),
                  !profile.ownedReferences.contains(candidate.reference),
                  !options.excludedReferences.contains(candidate.reference) else { continue }
            let learned = learnedCount(candidate)
            // A topic chosen by goals/interests counts like a learned one for the register rule
            // (e.g. „praca” allows office vocabulary marked as specialist).
            let preferred = profile.preferenceBonus(topicID: candidate.topicID, group: candidate.group).topic > 0
            if let register = options.registers[candidate.reference],
               !isAllowedRegister(register, learnedTopic: learned > 0 || preferred) {
                continue
            }
            let suggestion = evaluate(candidate, levelIndex: levelIndex, userIndex: userIndex, targetIndex: targetIndex, learned: learned, profile: profile)
            let ranked = Ranked(suggestion: suggestion, level: levelIndex, tie: tieBreak(candidate.key, seed: options.seed))
            if let existing = best[candidate.key], !ranksBefore(ranked, existing) { continue }
            best[candidate.key] = ranked
        }
        let pool = best.values.sorted { (lhs: Ranked, rhs: Ranked) -> Bool in
            ranksBefore(lhs, rhs)
        }
        return diversify(pool, limit: limit, maxPerTopic: options.maxPerTopic)
    }

    /// A scored suggestion with precomputed sort keys.
    struct Ranked {
        let suggestion: UsefulWordSuggestion
        let level: Int
        let tie: UInt32
    }

    /// Stable pseudo-random order of equally scored terms (FNV-1a of seed + key).
    static func tieBreak(_ key: String, seed: Int) -> UInt32 {
        FNV1a.hash32("\(seed)|\(key)")
    }

    private static func evaluate(_ candidate: UsefulWordCandidate, levelIndex: Int, userIndex: Int, targetIndex: Int, learned: Int, profile: UsefulWordProfile) -> UsefulWordSuggestion {
        var score = 0
        var reasons: [UsefulWordReason] = []
        if learned > 0 {
            score += 18 + min(12, learned / 2)
            reasons.append(.learnedTopic(candidate.topicName))
        }
        let preference = profile.preferenceBonus(topicID: candidate.topicID, group: candidate.group)
        if preference.topic > 0 {
            score += preference.topic
            if learned == 0 { reasons.append(.interest(candidate.topicName)) }
        }
        score += preference.group
        score += candidate.frequency == .veryCommon ? 40 : 26
        reasons.append(.frequent(candidate.frequency))
        if levelIndex == userIndex {
            score += 20
            reasons.append(.fitsLevel(profile.level))
        } else if levelIndex == targetIndex {
            score += 14
            reasons.append(.nextLevel(candidate.level))
        } else if levelIndex == userIndex - 1 {
            score += 10
            reasons.append(.fitsLevel(profile.level))
        } else {
            score += 2
        }
        if everydayGroups.contains(candidate.group) {
            score += 12
            if learned == 0 { reasons.append(.everyday) }
        }
        return UsefulWordSuggestion(candidate: candidate, score: score, reasons: reasons)
    }

    /// Total order: score, frequency, level, tie-break hash, key, reference.
    static func ranksBefore(_ lhs: Ranked, _ rhs: Ranked) -> Bool {
        let left = lhs.suggestion
        let right = rhs.suggestion
        if left.score != right.score { return left.score > right.score }
        let lf = left.candidate.frequency.rank
        let rf = right.candidate.frequency.rank
        if lf != rf { return lf < rf }
        if lhs.level != rhs.level { return lhs.level < rhs.level }
        if lhs.tie != rhs.tie { return lhs.tie < rhs.tie }
        if left.candidate.key != right.candidate.key { return left.candidate.key < right.candidate.key }
        return left.candidate.reference < right.candidate.reference
    }

    /// Default cap per topic for a list of `limit` items (20 → 4, 5 → 2).
    public static func defaultMaxPerTopic(limit: Int) -> Int {
        max(2, (limit + 4) / 5)
    }

    /// Greedy selection with penalties for repeated topics / groups and hard caps.
    /// `pool` must be sorted with `ranksBefore`.
    private static func diversify(_ ranked: [Ranked], limit: Int, maxPerTopic: Int?) -> [UsefulWordSuggestion] {
        let pool = ranked.map { $0.suggestion }
        let topicCap = max(1, maxPerTopic ?? defaultMaxPerTopic(limit: limit))
        let groupCap = max(topicCap, (limit * 2 + 4) / 5)
        var taken = [Bool](repeating: false, count: pool.count)
        var topicUsed: [String: Int] = [:]
        var groupUsed: [String: Int] = [:]
        var result: [UsefulWordSuggestion] = []
        while result.count < limit {
            var bestIndex: Int?
            var bestValue = Int.min
            for index in pool.indices {
                if taken[index] { continue }
                let item = pool[index]
                // Penalties only lower the score, so nothing further down can win any more.
                if item.score <= bestValue { break }
                let topicCount = topicUsed[item.candidate.topicID] ?? 0
                if topicCount >= topicCap { continue }
                let groupCount = groupUsed[item.candidate.group] ?? 0
                if groupCount >= groupCap { continue }
                let adjusted = item.score - 6 * topicCount - 3 * groupCount
                if adjusted > bestValue {
                    bestValue = adjusted
                    bestIndex = index
                }
            }
            guard let chosen = bestIndex else { break }
            taken[chosen] = true
            let item = pool[chosen]
            topicUsed[item.candidate.topicID, default: 0] += 1
            groupUsed[item.candidate.group, default: 0] += 1
            result.append(item)
        }
        return result
    }
}
