import Foundation

/// One row of „Dodaj słowo” (FEEDBACK-8 M3): senses of a term that mean the same thing, shown
/// and added as one meaning.
public struct SenseGroup: Sendable, Hashable {
    /// The merged sense: fields of the best entry (core first, then the most frequent), examples
    /// of every grouped entry without repeated sentences, the other entries in
    /// `mergedContentRefs`.
    public var sense: SenseSuggestion
    /// Indices of the grouped senses in the original list (the representative first).
    public var memberIndices: [Int]

    public init(sense: SenseSuggestion, memberIndices: [Int]) {
        self.sense = sense
        self.memberIndices = memberIndices
    }

    /// Number of example sentences the meaning gets when added.
    public var exampleCount: Int { sense.examples.count }
}

/// Grouping of duplicate senses of one term (the same meaning in several topics and in core).
///
/// Two senses are grouped when
/// - their translations are equal after normalisation (`OwnedVocabulary.translationKey`), or
/// - (carefully) each translation is an accepted translation of the other, the part of speech is
///   the same and the English definitions overlap strongly (`definitionSimilarity ≥ 0.5`) —
///   „ważyć” / „zważyć”, but never *mouse* „mysz” / „myszka” (an animal vs a device).
/// Different meanings („dogonić” vs „nadrobić zaległości”) stay separate rows.
public enum SenseGrouping {
    /// Minimal word overlap of two definitions for senses with different translations.
    public static let definitionThreshold = 0.5

    /// Groups in the order of their first sense in `senses` (relevance order of the lookup).
    public static func groups(_ senses: [SenseSuggestion]) -> [SenseGroup] {
        guard !senses.isEmpty else { return [] }
        var parent: [Int] = Array(senses.indices)
        func root(_ index: Int) -> Int {
            var current = index
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }
        func join(_ a: Int, _ b: Int) {
            let ra = root(a)
            let rb = root(b)
            guard ra != rb else { return }
            if ra < rb { parent[rb] = ra } else { parent[ra] = rb }
        }
        let keys: [String] = senses.map { (sense: SenseSuggestion) -> String in translationKey(sense.translation) }
        for i in senses.indices {
            for j in senses.indices where j > i {
                if !keys[i].isEmpty && keys[i] == keys[j] {
                    join(i, j)
                } else if sameMeaning(senses[i], senses[j]) {
                    join(i, j)
                }
            }
        }
        var order: [Int] = []
        var members: [Int: [Int]] = [:]
        for index in senses.indices {
            let key = root(index)
            if members[key] == nil { order.append(key) }
            members[key, default: []].append(index)
        }
        return order.compactMap { (key: Int) -> SenseGroup? in
            guard let indices = members[key], !indices.isEmpty else { return nil }
            let ranked = indices.sorted { (a: Int, b: Int) -> Bool in
                isBetterRepresentative(senses[a], at: a, than: senses[b], at: b)
            }
            return SenseGroup(sense: merged(ranked.map { senses[$0] }), memberIndices: ranked)
        }
    }

    /// The lookup with one meaning per group (same order as `groups`), plus the groups.
    public static func grouped(_ lookup: Lookup) -> (lookup: Lookup, groups: [SenseGroup]) {
        let result = groups(lookup.meanings)
        var copy = lookup
        copy.meanings = result.map { (group: SenseGroup) -> SenseSuggestion in group.sense }
        return (copy, result)
    }

    // MARK: Rules

    public static func translationKey(_ translation: String) -> String {
        OwnedVocabulary.translationKey(translation)
    }

    /// Different translations of the same meaning: mutual accepted translations, the same part of
    /// speech (or one unknown) and similar definitions.
    public static func sameMeaning(_ a: SenseSuggestion, _ b: SenseSuggestion) -> Bool {
        let keyA = translationKey(a.translation)
        let keyB = translationKey(b.translation)
        guard !keyA.isEmpty, !keyB.isEmpty else { return false }
        let acceptedA = Set((a.acceptedTranslations ?? []).map { (value: String) -> String in translationKey(value) })
        let acceptedB = Set((b.acceptedTranslations ?? []).map { (value: String) -> String in translationKey(value) })
        guard acceptedA.contains(keyB), acceptedB.contains(keyA) else { return false }
        let posA = TextNormalizer.normalize(a.pos)
        let posB = TextNormalizer.normalize(b.pos)
        guard posA.isEmpty || posB.isEmpty || posA == posB else { return false }
        return definitionSimilarity(a.definition, b.definition) >= definitionThreshold
    }

    /// Jaccard overlap of the content words of two English definitions (0…1; 0 when either is empty).
    public static func definitionSimilarity(_ a: String, _ b: String) -> Double {
        let left = contentWords(a)
        let right = contentWords(b)
        guard !left.isEmpty, !right.isEmpty else { return 0 }
        let shared = left.intersection(right).count
        let union = left.union(right).count
        return union == 0 ? 0 : Double(shared) / Double(union)
    }

    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "from", "that", "this", "your", "you", "are", "its", "into",
        "than", "more", "very", "not", "about", "when", "which", "who", "someone", "something",
        "somebody", "used", "use", "can", "has", "have", "was", "were", "been", "being", "or", "of",
        "to", "in", "on", "at", "by", "as", "is", "be", "it", "an", "a"
    ]

    static func contentWords(_ text: String) -> Set<String> {
        var words = Set<String>()
        var current = ""
        func flush() {
            if current.count > 2 && !stopWords.contains(current) { words.insert(current) }
            current = ""
        }
        for character in text.lowercased() {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else {
                flush()
            }
        }
        flush()
        return words
    }

    // MARK: Representative and merge

    /// Core entry first, then the higher spoken frequency, then the sense with a definition and
    /// a level, then the earlier one.
    static func isBetterRepresentative(_ a: SenseSuggestion, at indexA: Int, than b: SenseSuggestion, at indexB: Int) -> Bool {
        let coreA = isCore(a)
        let coreB = isCore(b)
        if coreA != coreB { return coreA }
        let rankA = frequencyRank(a.spokenFrequency)
        let rankB = frequencyRank(b.spokenFrequency)
        if rankA != rankB { return rankA > rankB }
        let detailA = (a.definition.isEmpty ? 0 : 1) + (a.level.isEmpty ? 0 : 1)
        let detailB = (b.definition.isEmpty ? 0 : 1) + (b.level.isEmpty ? 0 : 1)
        if detailA != detailB { return detailA > detailB }
        return indexA < indexB
    }

    static func isCore(_ sense: SenseSuggestion) -> Bool {
        guard let raw = sense.contentRef, let reference = ContentReference(raw) else { return false }
        return reference.isCore
    }

    static func frequencyRank(_ frequency: SpokenFrequency?) -> Int {
        switch frequency {
        case .veryCommon: return 4
        case .common: return 3
        case .lessCommon: return 2
        case .rare: return 1
        case nil: return 0
        }
    }

    /// The representative (first) with examples, accepted answers and translations of all
    /// senses (no repeated sentences); other entries in `mergedContentRefs`.
    static func merged(_ ranked: [SenseSuggestion]) -> SenseSuggestion {
        guard var result = ranked.first else { return SenseSuggestion(translation: "") }
        guard ranked.count > 1 else { return result }
        let ownKey = translationKey(result.translation)
        var sentenceKeys = Set(result.examples.map { (pair: ExamplePair) -> String in TextNormalizer.normalize(pair.en) })
        // The representative's own list stays as it is; other senses only add what is new.
        var accepted: [String] = result.acceptedTranslations ?? []
        var translationKeys: Set<String> = [ownKey]
        for value in accepted {
            translationKeys.insert(translationKey(value))
        }
        var answerKeys = Set(result.acceptedAnswers.map { (value: String) -> String in TextNormalizer.normalize(value) })
        var references: [String] = []
        let ownReference = result.contentRef ?? ""
        for other in ranked.dropFirst() {
            for pair in other.examples where !TextScanning.trim(pair.en).isEmpty {
                if sentenceKeys.insert(TextNormalizer.normalize(pair.en)).inserted {
                    result.examples.append(pair)
                }
            }
            let otherKey = translationKey(other.translation)
            if !otherKey.isEmpty && translationKeys.insert(otherKey).inserted {
                accepted.append(TextNormalizer.withoutDialectLabel(other.translation))
            }
            for value in other.acceptedTranslations ?? [] where translationKeys.insert(translationKey(value)).inserted {
                accepted.append(value)
            }
            for value in other.acceptedAnswers where answerKeys.insert(TextNormalizer.normalize(value)).inserted {
                result.acceptedAnswers.append(value)
            }
            if let reference = other.contentRef, !reference.isEmpty, reference != ownReference, !references.contains(reference) {
                references.append(reference)
            }
            for reference in other.mergedContentRefs ?? [] where reference != ownReference && !references.contains(reference) {
                references.append(reference)
            }
            if result.definition.isEmpty { result.definition = other.definition }
            if result.level.isEmpty { result.level = other.level }
            if result.pos.isEmpty { result.pos = other.pos }
        }
        result.acceptedTranslations = accepted.isEmpty ? nil : accepted
        let existing = result.mergedContentRefs ?? []
        let combined = existing + references.filter { (reference: String) -> Bool in !existing.contains(reference) }
        result.mergedContentRefs = combined.isEmpty ? nil : combined
        return result
    }
}
