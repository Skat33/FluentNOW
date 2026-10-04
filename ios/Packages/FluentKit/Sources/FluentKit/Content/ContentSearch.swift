import Foundation

/// How a search hit matched the query.
public enum SearchMatchKind: Int, Sendable, Hashable, Comparable {
    /// The whole English term equals the query.
    case exact = 0
    /// The English term starts with the query.
    case prefix = 1
    /// A word inside a multi-word English term starts with the query.
    case wordPrefix = 2
    /// The Polish translation (or one of its words) starts with the query.
    case polish = 3
    /// The English term is within a small edit distance (typo).
    case fuzzy = 4

    public static func < (lhs: SearchMatchKind, rhs: SearchMatchKind) -> Bool {
        lhs.rawValue < rhs.rawValue
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

/// In-memory search over `dictionary-index.json` for quick-add.
///
/// Build once (O(n log n), call off the main thread), then `search` is fast:
/// binary searches for exact / prefix matches over sorted keys, token indexes for
/// multi-word terms and Polish translations, and a bounded Levenshtein scan over keys of
/// similar length sharing the first letter for typos. Results are ordered by match kind,
/// then frequency, then key; several meanings of one term are all returned.
public struct ContentSearch: Sendable {
    private let entries: [DictionaryIndex.Entry]
    /// Entry indices sorted by English key.
    private let byKey: [Int]
    private let keys: [String]
    /// (token, entry index) sorted by token — words of multi-word English terms.
    private let englishTokens: [(token: String, entry: Int)]
    /// (token, entry index) sorted by token — whole Polish key and its words.
    private let polishTokens: [(token: String, entry: Int)]
    /// Fuzzy buckets: first byte → unique keys (as bytes) with the entry indices sharing that key.
    private let fuzzyBuckets: [UInt8: [(key: [UInt8], entries: [Int])]]

    public init(index: DictionaryIndex) {
        self.init(entries: index.entries)
    }

    public init(entries: [DictionaryIndex.Entry]) {
        self.entries = entries
        let sortedIndices = entries.indices.sorted { a, b in
            if entries[a].key != entries[b].key { return entries[a].key < entries[b].key }
            return a < b
        }
        byKey = sortedIndices
        keys = sortedIndices.map { entries[$0].key }

        var english: [(token: String, entry: Int)] = []
        var polish: [(token: String, entry: Int)] = []
        var buckets: [UInt8: [String: [Int]]] = [:]
        for (index, entry) in entries.enumerated() {
            let words = entry.key.split(separator: " ").map(String.init)
            if words.count > 1 {
                for word in Set(words.dropFirst()) where !word.isEmpty {
                    english.append((word, index))
                }
            }
            let polishKey = TextNormalizer.searchKey(entry.translation)
            if !polishKey.isEmpty {
                var tokens: Set<String> = [polishKey]
                for part in polishKey.split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
                    tokens.insert(String(part))
                }
                for token in tokens where !token.isEmpty {
                    polish.append((token, index))
                }
            }
            if let first = entry.key.utf8.first {
                buckets[first, default: [:]][entry.key, default: []].append(index)
            }
        }
        englishTokens = english.sorted { $0.token != $1.token ? $0.token < $1.token : $0.entry < $1.entry }
        polishTokens = polish.sorted { $0.token != $1.token ? $0.token < $1.token : $0.entry < $1.entry }
        var fuzzy: [UInt8: [(key: [UInt8], entries: [Int])]] = [:]
        for (first, map) in buckets {
            fuzzy[first] = map.keys.sorted().map { key in (key: Array(key.utf8), entries: map[key] ?? []) }
        }
        fuzzyBuckets = fuzzy
    }

    /// Number of indexed records.
    public var count: Int { entries.count }

    /// Searches English terms (exact, prefix, word prefix), Polish translations and typos.
    public func search(_ query: String, limit: Int = 30) -> [SearchHit] {
        let key = TextNormalizer.searchKey(query)
        guard !key.isEmpty, limit > 0 else { return [] }
        var hits: [SearchHit] = []
        var used = Set<Int>()

        func add(_ entryIndex: Int, _ kind: SearchMatchKind, _ distance: Int = 0) {
            guard used.insert(entryIndex).inserted else { return }
            hits.append(SearchHit(entry: entries[entryIndex], match: kind, distance: distance))
        }

        // Exact and prefix over sorted English keys.
        var position = lowerBound(keys, key)
        var prefixCount = 0
        while position < keys.count, keys[position].hasPrefix(key), prefixCount < limit * 4 {
            let entryIndex = byKey[position]
            add(entryIndex, keys[position] == key ? .exact : .prefix)
            position += 1
            prefixCount += 1
        }
        // Words inside multi-word terms.
        collectPrefix(englishTokens, key, kind: .wordPrefix, cap: limit * 2, add: add)
        // Polish translations.
        collectPrefix(polishTokens, key, kind: .polish, cap: limit * 2, add: add)
        // Typos, only when there are few results.
        if hits.count < limit, key.utf8.count >= 3 {
            let bytes = Array(key.utf8)
            let maxDistance = bytes.count <= 4 ? 1 : 2
            if let first = bytes.first, let bucket = fuzzyBuckets[first] {
                var fuzzy: [(entries: [Int], distance: Int)] = []
                for candidate in bucket {
                    if abs(candidate.key.count - bytes.count) > maxDistance { continue }
                    if let distance = TextNormalizer.boundedLevenshtein(bytes, candidate.key, limit: maxDistance), distance > 0 {
                        fuzzy.append((candidate.entries, distance))
                    }
                }
                fuzzy.sort { $0.distance < $1.distance }
                for item in fuzzy {
                    for entryIndex in item.entries { add(entryIndex, .fuzzy, item.distance) }
                    if hits.count >= limit * 2 { break }
                }
            }
        }
        let sorted = hits.stableSorted { a, b in
            if a.match != b.match { return a.match < b.match }
            if a.distance != b.distance { return a.distance < b.distance }
            let fa = a.entry.spokenFrequency?.rank ?? 4
            let fb = b.entry.spokenFrequency?.rank ?? 4
            if fa != fb { return fa < fb }
            if a.entry.key.count != b.entry.key.count { return a.entry.key.count < b.entry.key.count }
            return a.entry.key < b.entry.key
        }
        return Array(sorted.prefix(limit))
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

    private func collectPrefix(_ tokens: [(token: String, entry: Int)], _ key: String, kind: SearchMatchKind, cap: Int, add: (Int, SearchMatchKind, Int) -> Void) {
        var low = 0
        var high = tokens.count
        while low < high {
            let mid = (low + high) / 2
            if tokens[mid].token < key { low = mid + 1 } else { high = mid }
        }
        var position = low
        var taken = 0
        while position < tokens.count, tokens[position].token.hasPrefix(key), taken < cap {
            add(tokens[position].entry, kind, 0)
            position += 1
            taken += 1
        }
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
