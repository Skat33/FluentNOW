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

    /// `true` for an entry of the core vocabulary (`topicID` = shard `core-cNN`, CONTENT-SCHEMA §6).
    public var isCore: Bool { CoreVocabulary.isCoreFile(topicID) }

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
    /// From the word family of a word the learner has (that word's key) — H4, e.g. decide → decision.
    case wordFamily(String)
    /// From the core vocabulary — general English useful in many situations (FEEDBACK-7).
    case coreVocabulary

    /// Polish text, e.g. „z tematu Restauracja, którego się uczysz”.
    public var textPl: String {
        switch self {
        case .frequent(let frequency):
            switch frequency {
            case .veryCommon: return "bardzo często używane"
            case .common: return "często używane"
            case .lessCommon, .rare: return "rzadziej używane"
            }
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
        case .wordFamily(let word):
            return Self.wordFamilyPrefixPl + word + ", które znasz"
        case .coreVocabulary:
            return "słownictwo ogólne, przydatne w wielu sytuacjach"
        }
    }

    /// Text before the source word of `.wordFamily` (the app sets the word in italics).
    public static let wordFamilyPrefixPl = "z rodziny słowa "
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

    /// The learner's word whose family this suggestion comes from (H4), if any.
    public var familySource: String? {
        for reason in reasons {
            if case .wordFamily(let word) = reason { return word }
        }
        return nil
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
    /// Past participles from the `forms` of the learner's words → the word's key
    /// („broken” → „break”) — extra word-family members (H4).
    public var ownedForms: [String: String]

    public init(level: String, targetLevel: String, ownedKeys: Set<String> = [], ownedReferences: Set<String> = [], topicCounts: [String: Int] = [:], collectionKeys: Set<String> = [], topicPreferences: [String: Int] = [:], groupPreferences: [String: Int] = [:], ownedForms: [String: String] = [:]) {
        self.level = level
        self.targetLevel = targetLevel
        self.ownedKeys = ownedKeys
        self.ownedReferences = ownedReferences
        self.topicCounts = topicCounts
        self.collectionKeys = collectionKeys
        self.topicPreferences = topicPreferences
        self.groupPreferences = groupPreferences
        self.ownedForms = ownedForms
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
        var forms: [String: String] = [:]
        for word in state.words {
            let key = TextNormalizer.searchKey(word.en)
            if !key.isEmpty { keys.insert(key) }
            if WordFamily.isWordKey(key) {
                for form in WordFamily.participles(fromForms: word.forms, of: key) {
                    if let existing = forms[form], existing <= key { continue }
                    forms[form] = key
                }
            }
            for meaning in word.meanings {
                for reference in meaning.allContentRefs { references.insert(reference) }
            }
            guard !word.archived else { continue }
            let collection = TextNormalizer.searchKey(word.collection)
            if !collection.isEmpty { collections.insert(collection) }
            for meaning in word.meanings {
                // Starter and core are not topics (core shards are frequency bands).
                guard let raw = meaning.contentRef, let reference = ContentReference(raw), !reference.isStarter, !reference.isCore else { continue }
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
            groupPreferences: learner?.groupWeights() ?? [:],
            ownedForms: forms
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
    /// Word-family suggestions (H4) may be this many levels above the target (target + 1).
    public var familyLevelSlack: Int
    /// Maximum word-family suggestions; `nil` = derived from `limit` (20 → 5, 5 → 2).
    public var maxFamilySuggestions: Int?
    /// Maximum suggestions from the family of one word.
    public var maxPerFamily: Int

    public init(limit: Int = 20, maxPerTopic: Int? = nil, registers: [String: String] = [:], excludedReferences: Set<String> = [], seed: Int = 0, familyLevelSlack: Int = 1, maxFamilySuggestions: Int? = nil, maxPerFamily: Int = 2) {
        self.limit = limit
        self.maxPerTopic = maxPerTopic
        self.registers = registers
        self.excludedReferences = excludedReferences
        self.seed = seed
        self.familyLevelSlack = familyLevelSlack
        self.maxFamilySuggestions = maxFamilySuggestions
        self.maxPerFamily = maxPerFamily
    }
}

/// „Polecane słówka”: built-in words that are genuinely useful in everyday life.
///
/// Rules (FEEDBACK-1 F5): only `very_common` / `common`; level ≤ target (estimated + 1);
/// no slang, specialist register only for topics the learner studies; never words the learner
/// already has; topics the learner studies and everyday groups preferred; one meaning per term;
/// variety (a cap per topic and per group). Deterministic: the same input gives the same output
/// regardless of the candidate order.
///
/// Word families (FEEDBACK-3 H4, `WordFamilyIndex`): relatives of the learner's words
/// (decide → decision) are preferred with the reason „Z rodziny słowa decide, które znasz”;
/// they may also be `less_common` and one level above the target; capped per list and per word.
///
/// Core vocabulary (FEEDBACK-7, `CoreVocabulary`): entries of `core/core-cNN.json` are candidates
/// of the everyday group `basics` named „Słownictwo ogólne” (each shard counts as a „topic” for
/// the variety caps). Outside word families they must fit the learner's level ±1 (from one level
/// below the learner up to the target) — no A1 basics for a B2 learner — and they never count as
/// a topic the learner studies.
public enum UsefulWordRecommender {
    /// Everyday topic groups (podstawy, codzienność, komunikacja, jedzenie, podróże, zdrowie, zakupy).
    public static let everydayGroups: Set<String> = ["basics", "daily", "communication", "food", "travel", "health", "money"]
    /// Display name of `starter-words.json` entries.
    public static let starterTopicName = "Podstawowe słowa"
    /// Group of starter entries.
    public static let starterGroup = "basics"
    /// Group of core vocabulary entries (an everyday group).
    public static let coreGroup = "basics"
    /// Core entries (outside word families) may be at most this many levels below the learner.
    public static let coreLevelsBelow = 1

    // MARK: Candidates

    public static func candidates(index: DictionaryIndex, topics: TopicIndex, includeLessCommon: Bool = false) -> [UsefulWordCandidate] {
        candidates(entries: index.entries, topics: topics, includeLessCommon: includeLessCommon)
    }

    /// Frequent entries with a valid level and a known topic (topics missing from the index are skipped),
    /// starter words and core vocabulary entries (`core-cNN/core.<term>`, never in the topic index).
    /// `includeLessCommon`: also `less_common` entries — `recommend` uses them only as word-family
    /// suggestions (H4), never as plain recommendations.
    public static func candidates(entries: [DictionaryIndex.Entry], topics: TopicIndex, includeLessCommon: Bool = false) -> [UsefulWordCandidate] {
        var summaries: [String: TopicSummary] = [:]
        for topic in topics.topics where summaries[topic.id] == nil {
            summaries[topic.id] = topic
        }
        var result: [UsefulWordCandidate] = []
        result.reserveCapacity(entries.count)
        for entry in entries {
            guard let frequency = entry.spokenFrequency,
                  isFrequent(frequency) || (includeLessCommon && frequency == .lessCommon) else { continue }
            guard CEFR.isValid(entry.level), !TextScanning.trim(entry.translation).isEmpty else { continue }
            guard let reference = entry.contentReference else { continue }
            let name: String
            let group: String
            if reference.isStarter {
                name = starterTopicName
                group = starterGroup
            } else if reference.isCore {
                name = CoreVocabulary.collectionName
                group = coreGroup
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

    /// Frequent enough for a word-family suggestion: `very_common`, `common` or `less_common`.
    public static func isUsefulFamilyFrequency(_ frequency: SpokenFrequency) -> Bool {
        frequency != .rare
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
    ///
    /// `families` (H4): words from the word family of a word the learner has („Z rodziny słowa
    /// decide, które znasz”) are preferred, may be `less_common` and up to
    /// `options.familyLevelSlack` levels above the target; at most `options.maxFamilySuggestions`
    /// of them, `options.maxPerFamily` per source word. `nil` = no family suggestions.
    public static func recommend(_ candidates: [UsefulWordCandidate], profile: UsefulWordProfile, options: UsefulWordOptions = UsefulWordOptions(), families: WordFamilyIndex? = nil) -> [UsefulWordSuggestion] {
        let limit = max(0, options.limit)
        guard limit > 0, !candidates.isEmpty else { return [] }
        let maxIndex = CEFR.levels.count - 1
        let userIndex = CEFR.index(of: profile.level) ?? 0
        let targetIndex = max(userIndex, CEFR.index(of: profile.targetLevel) ?? min(maxIndex, userIndex + 1))
        let familyLevelIndex = min(maxIndex, targetIndex + max(0, options.familyLevelSlack))
        let sources: [String: FamilySource]
        if let families {
            sources = familySources(profile: profile, families: families)
        } else {
            sources = [:]
        }

        let coreMinIndex = max(0, userIndex - max(0, coreLevelsBelow))
        var learnedCache: [String: Int] = [:]
        func learnedCount(_ candidate: UsefulWordCandidate) -> Int {
            // Core is not a topic: its collection „Słownictwo ogólne” never counts as studying it.
            if candidate.isCore { return 0 }
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
            let family = sources[candidate.key]
            let frequent = family == nil ? isFrequent(candidate.frequency) : isUsefulFamilyFrequency(candidate.frequency)
            let levelLimit = family == nil ? targetIndex : familyLevelIndex
            guard frequent,
                  let levelIndex = CEFR.index(of: candidate.level), levelIndex <= levelLimit,
                  !profile.ownedKeys.contains(candidate.key),
                  !profile.ownedReferences.contains(candidate.reference),
                  !options.excludedReferences.contains(candidate.reference) else { continue }
            // Core outside word families: the learner's level ±1 (not far below the learner).
            if family == nil && candidate.isCore && levelIndex < coreMinIndex { continue }
            let learned = learnedCount(candidate)
            // A topic chosen by goals/interests counts like a learned one for the register rule
            // (e.g. „praca” allows office vocabulary marked as specialist).
            let preferred = profile.preferenceBonus(topicID: candidate.topicID, group: candidate.group).topic > 0
            if let register = options.registers[candidate.reference],
               !isAllowedRegister(register, learnedTopic: learned > 0 || preferred) {
                continue
            }
            let suggestion = evaluate(candidate, levelIndex: levelIndex, userIndex: userIndex, targetIndex: targetIndex, learned: learned, family: family, profile: profile)
            let ranked = Ranked(suggestion: suggestion, level: levelIndex, tie: tieBreak(candidate.key, seed: options.seed))
            if let existing = best[candidate.key], !ranksBefore(ranked, existing) { continue }
            best[candidate.key] = ranked
        }
        let pool = best.values.sorted { (lhs: Ranked, rhs: Ranked) -> Bool in
            ranksBefore(lhs, rhs)
        }
        let caps = DiversityCaps(
            limit: limit,
            maxPerTopic: options.maxPerTopic,
            maxFamily: options.maxFamilySuggestions ?? defaultMaxFamilySuggestions(limit: limit),
            maxPerFamily: options.maxPerFamily
        )
        return diversify(pool, caps: caps)
    }

    /// Default cap of word-family suggestions in a list of `limit` items (20 → 5, 5 → 2, 30 → 8).
    public static func defaultMaxFamilySuggestions(limit: Int) -> Int {
        max(1, (limit + 3) / 4)
    }

    /// The learner's word a family suggestion comes from (`distance` 1 = direct derivation).
    struct FamilySource: Sendable, Hashable {
        let word: String
        let distance: Int

        /// Closer first, then the shorter (more basic) word, then alphabetical.
        func isBetter(than other: FamilySource) -> Bool {
            if distance != other.distance { return distance < other.distance }
            if word.count != other.word.count { return word.count < other.word.count }
            return word < other.word
        }
    }

    /// Candidate key → the learner's word whose family it belongs to. Owned words are never
    /// targets. Past participles from the learner's `forms` (broken ← break) count as distance 1.
    static func familySources(profile: UsefulWordProfile, families: WordFamilyIndex) -> [String: FamilySource] {
        var result: [String: FamilySource] = [:]
        func offer(_ key: String, source: FamilySource) {
            guard key != source.word, !profile.ownedKeys.contains(key) else { return }
            if let existing = result[key], !source.isBetter(than: existing) { return }
            result[key] = source
        }
        for owned in profile.ownedKeys where WordFamily.isWordKey(owned) {
            for member in families.family(of: owned) {
                offer(member.key, source: FamilySource(word: owned, distance: member.distance))
            }
        }
        for (form, owner) in profile.ownedForms where WordFamily.isWordKey(form) {
            offer(form, source: FamilySource(word: owner, distance: 1))
            for member in families.family(of: form, maxDistance: 1) {
                offer(member.key, source: FamilySource(word: owner, distance: 2))
            }
        }
        return result
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

    /// Bonus of a word-family suggestion (direct derivation / through one other word).
    static func familyBonus(distance: Int) -> Int {
        distance <= 1 ? 26 : 20
    }

    private static func evaluate(_ candidate: UsefulWordCandidate, levelIndex: Int, userIndex: Int, targetIndex: Int, learned: Int, family: FamilySource?, profile: UsefulWordProfile) -> UsefulWordSuggestion {
        var score = 0
        var reasons: [UsefulWordReason] = []
        if let family {
            score += familyBonus(distance: family.distance)
            reasons.append(.wordFamily(family.word))
        }
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
        switch candidate.frequency {
        case .veryCommon:
            score += 40
            reasons.append(.frequent(.veryCommon))
        case .common:
            score += 26
            reasons.append(.frequent(.common))
        case .lessCommon, .rare:
            // Only word-family suggestions get here (`recommend` filters the rest).
            score += 14
        }
        if levelIndex == userIndex {
            score += 20
            reasons.append(.fitsLevel(profile.level))
        } else if levelIndex == targetIndex {
            score += 14
            reasons.append(.nextLevel(candidate.level))
        } else if levelIndex == userIndex - 1 {
            score += 10
            reasons.append(.fitsLevel(profile.level))
        } else if levelIndex <= targetIndex {
            score += 2
        }
        if everydayGroups.contains(candidate.group) {
            score += 12
            if learned == 0 { reasons.append(candidate.isCore ? .coreVocabulary : .everyday) }
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

    /// Hard caps of the greedy selection.
    struct DiversityCaps {
        let limit: Int
        let maxPerTopic: Int?
        let maxFamily: Int
        let maxPerFamily: Int
    }

    /// Greedy selection with penalties for repeated topics / groups and hard caps.
    /// `pool` must be sorted with `ranksBefore`.
    private static func diversify(_ ranked: [Ranked], caps: DiversityCaps) -> [UsefulWordSuggestion] {
        let pool = ranked.map { (item: Ranked) -> UsefulWordSuggestion in item.suggestion }
        let sources = pool.map { (item: UsefulWordSuggestion) -> String? in item.familySource }
        let limit = caps.limit
        let topicCap = max(1, caps.maxPerTopic ?? defaultMaxPerTopic(limit: limit))
        let groupCap = max(topicCap, (limit * 2 + 4) / 5)
        let familyCap = max(0, caps.maxFamily)
        let perFamilyCap = max(1, caps.maxPerFamily)
        var taken = [Bool](repeating: false, count: pool.count)
        var topicUsed: [String: Int] = [:]
        var groupUsed: [String: Int] = [:]
        var familyUsed = 0
        var perFamilyUsed: [String: Int] = [:]
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
                if let source = sources[index] {
                    if familyUsed >= familyCap || (perFamilyUsed[source] ?? 0) >= perFamilyCap { continue }
                }
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
            if let source = sources[chosen] {
                familyUsed += 1
                perFamilyUsed[source, default: 0] += 1
            }
            result.append(item)
        }
        return result
    }
}
