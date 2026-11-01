import Foundation

/// How a search hit matched the query (FEEDBACK-9 N3 order: exact, English prefix, Polish
/// prefix, a word inside a phrase, typos).
public enum SearchMatchKind: Int, Sendable, Hashable, Comparable {
    /// The whole English term equals the query.
    case exact = 0
    /// The whole Polish translation (or one of its `;`/`,`/`/` alternatives) equals the query.
    case polishExact = 1
    /// The English term starts with the query.
    case prefix = 2
    /// The Polish translation (or one of its words) starts with the query.
    case polish = 3
    /// A word inside a multi-word English term starts with the query.
    case wordPrefix = 4
    /// The English term or a Polish word is within a small edit distance (typo).
    case fuzzy = 5

    public static func < (lhs: SearchMatchKind, rhs: SearchMatchKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Matched through the Polish translation.
    public var isPolish: Bool {
        switch self {
        case .polishExact, .polish: return true
        case .exact, .prefix, .wordPrefix, .fuzzy: return false
        }
    }
}

/// One search result.
public struct SearchHit: Sendable, Hashable {
    public var entry: DictionaryIndex.Entry
    public var match: SearchMatchKind
    /// Edit distance for fuzzy hits, 0 otherwise.
    public var distance: Int

    public init(entry: DictionaryIndex.Entry, match: SearchMatchKind, distance: Int = 0) {
        self.entry = entry
        self.match = match
        self.distance = distance
    }
}

/// In-memory search over `dictionary-index.json` for quick-add and suggestions while typing.
///
/// Build once (O(n log n), call off the main thread), then queries are fast: binary searches
/// for exact / prefix matches over sorted English keys and sorted Polish tokens, token indexes
/// for words inside phrases, and `FuzzyIndex` (keys bucketed by length + a first-letters
/// pre-filter + banded Damerau–Levenshtein) for typos. Results are ordered by match kind, then
/// spoken frequency, then key length and key; several meanings of one term are all returned.
public struct ContentSearch: Sendable {
    private let entries: [DictionaryIndex.Entry]
    /// Entry indices sorted by English key.
    private let byKey: [Int]
    private let keys: [String]
    /// (token, entry index) sorted by token — words of multi-word English terms (not the first).
    private let englishTokens: [(token: String, entry: Int)]
    /// (token, entry index) sorted by token — whole Polish translations and their alternatives.
    private let polishWholes: [(token: String, entry: Int)]
    /// (token, entry index) sorted by token — single words of Polish translations.
    private let polishWords: [(token: String, entry: Int)]
    /// Rank of every entry for ordering within a match kind: spoken frequency, then key length.
    private let frequencyRanks: [Int]
    /// Typos in English keys and in Polish words / translations.
    private let englishFuzzy: FuzzyIndex
    private let polishFuzzy: FuzzyIndex

    public init(index: DictionaryIndex) {
        self.init(entries: index.entries)
    }

    public init(entries: [DictionaryIndex.Entry]) {
        self.entries = entries
        let sortedIndices = entries.indices.sorted { (a: Int, b: Int) -> Bool in
            if entries[a].key != entries[b].key { return entries[a].key < entries[b].key }
            return a < b
        }
        byKey = sortedIndices
        keys = sortedIndices.map { (index: Int) -> String in entries[index].key }
        frequencyRanks = entries.map { (entry: DictionaryIndex.Entry) -> Int in entry.spokenFrequency?.rank ?? 4 }

        var english: [(token: String, entry: Int)] = []
        var wholes: [(token: String, entry: Int)] = []
        var words: [(token: String, entry: Int)] = []
        var englishKeys: [(key: String, payload: Int)] = []
        var polishKeys: [(key: String, payload: Int)] = []
        for (index, entry) in entries.enumerated() {
            englishKeys.append((entry.key, index))
            let parts = entry.key.split(separator: " ").map(String.init)
            if parts.count > 1 {
                for word in Set(parts.dropFirst()) where !word.isEmpty {
                    english.append((word, index))
                }
            }
            let alternatives = ContentSearch.polishAlternatives(entry.translation)
            for alternative in alternatives {
                wholes.append((alternative, index))
                polishKeys.append((alternative, index))
            }
            var tokens = Set<String>()
            for alternative in alternatives {
                for part in alternative.split(whereSeparator: { (c: Character) -> Bool in !c.isLetter && !c.isNumber }) {
                    tokens.insert(String(part))
                }
            }
            for token in tokens where !token.isEmpty && !alternatives.contains(token) {
                words.append((token, index))
                if token.count >= 3 { polishKeys.append((token, index)) }
            }
        }
        let byToken: ((token: String, entry: Int), (token: String, entry: Int)) -> Bool = { a, b in
            a.token != b.token ? a.token < b.token : a.entry < b.entry
        }
        englishTokens = english.sorted(by: byToken)
        polishWholes = wholes.sorted(by: byToken)
        polishWords = words.sorted(by: byToken)
        englishFuzzy = FuzzyIndex(keys: englishKeys)
        polishFuzzy = FuzzyIndex(keys: polishKeys)
    }

    /// Number of indexed records.
    public var count: Int { entries.count }

    /// Normalised whole translations: the translation, and — when it lists several — each
    /// alternative (`;`, `,`, `/`), without parenthetical notes and `(AmE)` labels.
    static func polishAlternatives(_ translation: String) -> [String] {
        let cleaned = TextNormalizer.withoutDialectLabel(translation)
        var result: [String] = []
        func add(_ text: String) {
            let key = TextNormalizer.searchKey(text)
            if !key.isEmpty && !result.contains(key) { result.append(key) }
        }
        add(cleaned)
        let withoutNotes = TextNormalizer.removingParentheticals(cleaned)
        add(withoutNotes)
        for part in withoutNotes.split(whereSeparator: { (c: Character) -> Bool in c == ";" || c == "," || c == "/" }) {
            add(String(part))
        }
        return result
    }

    // MARK: Search

    /// Searches English terms (exact, prefix, word prefix), Polish translations and typos.
    public func search(_ query: String, limit: Int = 30) -> [SearchHit] {
        let key = TextNormalizer.searchKey(query)
        guard !key.isEmpty, limit > 0 else { return [] }
        var collector = HitCollector()
        collectDirect(key, cap: limit * 4, into: &collector)
        if collector.hits.count < limit {
            collectFuzzy(key, maxDistance: FuzzyMatcher.maxDistance(forLength: key.utf8.count), loose: false, into: &collector)
        }
        return Array(ordered(collector.hits).prefix(limit))
    }

    /// All records whose English key equals the normalised term (every meaning of the term).
    public func meanings(of term: String) -> [DictionaryIndex.Entry] {
        let key = TextNormalizer.searchKey(term)
        guard !key.isEmpty else { return [] }
        var position = lowerBound(keys, key)
        var result: [DictionaryIndex.Entry] = []
        while position < keys.count, keys[position] == key {
            result.append(entries[byKey[position]])
            position += 1
        }
        return result
    }

    // MARK: Suggestions while typing (FEEDBACK-9 N3)

    /// Suggestions for a search field: grouped terms in the order exact → English prefix →
    /// Polish → word inside a phrase; „Czy chodziło Ci o…?” corrections when nothing matched
    /// exactly or by prefix; looser similar words when nothing matched at all.
    public func suggestions(_ query: String, limit: Int = 8) -> SearchSuggestionResult {
        let key = TextNormalizer.searchKey(query)
        guard !key.isEmpty, limit > 0 else { return SearchSuggestionResult(query: key) }
        var direct = HitCollector()
        collectDirect(key, cap: limit * 4, into: &direct)
        let directHits = ordered(direct.hits)
        var result = SearchSuggestionResult(query: key)
        result.matches = Array(SearchSuggestion.group(directHits).prefix(limit))
        let strong = directHits.contains { (hit: SearchHit) -> Bool in hit.match < .wordPrefix }
        let length = key.utf8.count
        if !strong {
            var fuzzy = HitCollector(excluding: direct.used)
            collectFuzzy(key, maxDistance: FuzzyMatcher.maxDistance(forLength: length), loose: false, into: &fuzzy)
            let shown = Set(result.matches.map { (item: SearchSuggestion) -> String in item.key })
            result.corrections = Array(SearchSuggestion.group(ordered(fuzzy.hits))
                .filter { (item: SearchSuggestion) -> Bool in !shown.contains(item.key) }
                .prefix(Swift.min(limit, 5)))
        }
        if result.matches.isEmpty && result.corrections.isEmpty {
            var loose = HitCollector()
            collectFuzzy(key, maxDistance: FuzzyMatcher.looseDistance(forLength: length), loose: true, into: &loose)
            result.similar = Array(SearchSuggestion.group(ordered(loose.hits)).prefix(Swift.min(limit, 5)))
        }
        return result
    }

    // MARK: Collection

    private struct HitCollector {
        var hits: [SearchHit] = []
        var used = Set<Int>()

        init(excluding: Set<Int> = []) {
            used = excluding
        }
    }

    private func add(_ entryIndex: Int, _ kind: SearchMatchKind, _ distance: Int, into collector: inout HitCollector) {
        guard collector.used.insert(entryIndex).inserted else { return }
        collector.hits.append(SearchHit(entry: entries[entryIndex], match: kind, distance: distance))
    }

    /// Exact, prefix, Polish and in-phrase matches. Every range is ranked (frequency, length)
    /// before the cap, so a one-letter query still shows the most common words.
    private func collectDirect(_ key: String, cap: Int, into collector: inout HitCollector) {
        // English keys: exact, then prefix.
        var position = lowerBound(keys, key)
        var prefixed: [Int] = []
        while position < keys.count, keys[position].hasPrefix(key) {
            if keys[position] == key {
                add(byKey[position], .exact, 0, into: &collector)
            } else {
                prefixed.append(byKey[position])
            }
            position += 1
        }
        // Whole Polish translations: exact, then prefix.
        let wholes = prefixRange(polishWholes, key)
        var polishPrefixed: [Int] = []
        for item in wholes {
            if item.token == key {
                add(item.entry, .polishExact, 0, into: &collector)
            } else {
                polishPrefixed.append(item.entry)
            }
        }
        for entryIndex in best(prefixed, cap: cap) { add(entryIndex, .prefix, 0, into: &collector) }
        for entryIndex in best(polishPrefixed, cap: cap) { add(entryIndex, .polish, 0, into: &collector) }
        let polishWordHits = prefixRange(polishWords, key).map { (item: (token: String, entry: Int)) -> Int in item.entry }
        for entryIndex in best(polishWordHits, cap: cap) { add(entryIndex, .polish, 0, into: &collector) }
        let phraseHits = prefixRange(englishTokens, key).map { (item: (token: String, entry: Int)) -> Int in item.entry }
        for entryIndex in best(phraseHits, cap: cap) { add(entryIndex, .wordPrefix, 0, into: &collector) }
    }

    /// Typos in English keys and Polish words (English first on equal distance).
    private func collectFuzzy(_ key: String, maxDistance: Int, loose: Bool, into collector: inout HitCollector) {
        guard maxDistance > 0 else { return }
        let bytes = Array(key.utf8)
        let english = englishFuzzy.matches(bytes, maxDistance: maxDistance, requireSharedStart: !loose)
        let polish = polishFuzzy.matches(bytes, maxDistance: maxDistance, requireSharedStart: !loose)
        for distance in 1...maxDistance {
            for match in english where match.distance == distance {
                for entryIndex in match.payload { add(entryIndex, .fuzzy, distance, into: &collector) }
            }
            for match in polish where match.distance == distance {
                for entryIndex in match.payload { add(entryIndex, .fuzzy, distance, into: &collector) }
            }
        }
    }

    /// Up to `cap` entries, most frequent and shortest first (stable on ties).
    private func best(_ indices: [Int], cap: Int) -> [Int] {
        guard indices.count > 1 else { return indices }
        let ranked = indices.enumerated().sorted { (a: (offset: Int, element: Int), b: (offset: Int, element: Int)) -> Bool in
            let ra = frequencyRanks[a.element]
            let rb = frequencyRanks[b.element]
            if ra != rb { return ra < rb }
            let la = entries[a.element].key.utf8.count
            let lb = entries[b.element].key.utf8.count
            if la != lb { return la < lb }
            return a.offset < b.offset
        }
        return ranked.prefix(cap).map { (item: (offset: Int, element: Int)) -> Int in item.element }
    }

    private func ordered(_ hits: [SearchHit]) -> [SearchHit] {
        hits.stableSorted { (a: SearchHit, b: SearchHit) -> Bool in
            if a.match != b.match { return a.match < b.match }
            if a.distance != b.distance { return a.distance < b.distance }
            let fa = a.entry.spokenFrequency?.rank ?? 4
            let fb = b.entry.spokenFrequency?.rank ?? 4
            if fa != fb { return fa < fb }
            if a.entry.key.count != b.entry.key.count { return a.entry.key.count < b.entry.key.count }
            return a.entry.key < b.entry.key
        }
    }

    /// The slice of a token list whose tokens start with `key`.
    private func prefixRange(_ tokens: [(token: String, entry: Int)], _ key: String) -> ArraySlice<(token: String, entry: Int)> {
        var low = 0
        var high = tokens.count
        while low < high {
            let mid = (low + high) / 2
            if tokens[mid].token < key { low = mid + 1 } else { high = mid }
        }
        var end = low
        while end < tokens.count, tokens[end].token.hasPrefix(key) {
            end += 1
        }
        return tokens[low..<end]
    }

    private func lowerBound(_ sorted: [String], _ key: String) -> Int {
        var low = 0
        var high = sorted.count
        while low < high {
            let mid = (low + high) / 2
            if sorted[mid] < key { low = mid + 1 } else { high = mid }
        }
        return low
    }
}

/// One suggested term: the records of one English key that matched, with the translations
/// listed once each (the same normalised translation as in `SenseGrouping` — duplicates from
/// several topics and core collapse into one).
public struct SearchSuggestion: Sendable, Hashable, Identifiable {
    /// Term as written (best-ranked record).
    public var term: String
    /// Normalised English key (`id`).
    public var key: String
    /// Unique translations in relevance order.
    public var translations: [String]
    /// CEFR level of the best-ranked record (may be empty).
    public var level: String
    /// Best match kind among the records.
    public var match: SearchMatchKind
    /// Edit distance of a correction (0 for direct matches).
    public var distance: Int
    /// Matched records (all meanings that matched, duplicates included).
    public var entries: [DictionaryIndex.Entry]

    public var id: String { key }

    public init(term: String, key: String, translations: [String], level: String, match: SearchMatchKind, distance: Int, entries: [DictionaryIndex.Entry]) {
        self.term = term
        self.key = key
        self.translations = translations
        self.level = level
        self.match = match
        self.distance = distance
        self.entries = entries
    }

    /// Groups sorted hits by English key, keeping the order of the first hit of every key.
    public static func group(_ hits: [SearchHit]) -> [SearchSuggestion] {
        var order: [String] = []
        var grouped: [String: [SearchHit]] = [:]
        for hit in hits {
            let key = hit.entry.key.isEmpty ? TextNormalizer.searchKey(hit.entry.term) : hit.entry.key
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(hit)
        }
        return order.compactMap { (key: String) -> SearchSuggestion? in
            guard let group = grouped[key], let first = group.first else { return nil }
            var translations: [String] = []
            var seen = Set<String>()
            for hit in group {
                let translationKey = SenseGrouping.translationKey(hit.entry.translation)
                guard !translationKey.isEmpty, seen.insert(translationKey).inserted else { continue }
                translations.append(TextNormalizer.withoutDialectLabel(hit.entry.translation))
            }
            return SearchSuggestion(
                term: first.entry.term,
                key: key,
                translations: translations,
                level: first.entry.level,
                match: first.match,
                distance: first.distance,
                entries: group.map { (hit: SearchHit) -> DictionaryIndex.Entry in hit.entry }
            )
        }
    }
}

/// Suggestions for one query (`ContentSearch.suggestions`).
public struct SearchSuggestionResult: Sendable, Hashable {
    /// Normalised query the result belongs to.
    public var query: String
    /// Direct matches: exact → English prefix → Polish → word inside a phrase.
    public var matches: [SearchSuggestion]
    /// „Czy chodziło Ci o…?” — typos (1 edit for 3–5 letters, 2 for 6+), when there was no
    /// exact or prefix match.
    public var corrections: [SearchSuggestion]
    /// Looser similar words, only when there were neither matches nor corrections.
    public var similar: [SearchSuggestion]

    public init(query: String = "", matches: [SearchSuggestion] = [], corrections: [SearchSuggestion] = [], similar: [SearchSuggestion] = []) {
        self.query = query
        self.matches = matches
        self.corrections = corrections
        self.similar = similar
    }

    public static let empty = SearchSuggestionResult()

    /// Nothing to show.
    public var isEmpty: Bool { matches.isEmpty && corrections.isEmpty && similar.isEmpty }
}

extension SearchSuggestion {
    /// How many of the suggestion's translations the learner already has (an owned translation
    /// counts once, however many grouped records share it) — `OwnedVocabulary` rules (G6).
    public func ownedTranslationCount(in owned: OwnedVocabulary) -> Int {
        var ownedKeys = Set<String>()
        for entry in entries where owned.contains(reference: entry.reference, term: entry.term, translation: entry.translation) {
            ownedKeys.insert(SenseGrouping.translationKey(entry.translation))
        }
        let shown = Set(translations.map { (translation: String) -> String in SenseGrouping.translationKey(translation) })
        return ownedKeys.intersection(shown).count
    }

    /// Every shown translation is already in the learner's dictionary („Masz już”).
    public func isFullyOwned(in owned: OwnedVocabulary) -> Bool {
        !translations.isEmpty && ownedTranslationCount(in: owned) >= translations.count
    }
}
