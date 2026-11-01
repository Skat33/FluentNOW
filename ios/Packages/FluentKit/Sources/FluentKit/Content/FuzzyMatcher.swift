import Foundation

/// Approximate matching for search („Czy chodziło Ci o…?”, FEEDBACK-9 N3).
///
/// Distance = optimal string alignment (Damerau–Levenshtein with adjacent transpositions:
/// *recieve* → *receive* is one edit), computed in a band with an early exit, over the bytes of
/// search keys (`TextNormalizer.searchKey`: lowercase, no Polish diacritics — „zażółć” and
/// „zazolc” are the same key).
public enum FuzzyMatcher {
    /// Typos allowed for a query of `length` characters: none below 3, 1 for 3–5, 2 for 6+.
    public static func maxDistance(forLength length: Int) -> Int {
        if length < 3 { return 0 }
        return length <= 5 ? 1 : 2
    }

    /// Limit for „podobne słowa” (shown only when nothing else matched; searched without the
    /// first-letters pre-filter): about one edit per three letters — 1 for 4–5, 2 for 6–8,
    /// 3 for 9+ — and nothing below 4 characters (short words would match almost anything).
    public static func looseDistance(forLength length: Int) -> Int {
        guard length >= 4 else { return 0 }
        return Swift.min(3, Swift.max(1, length / 3))
    }

    /// Distance between two strings after `TextNormalizer.searchKey`; `nil` above `limit`.
    public static func distance(_ left: String, _ right: String, limit: Int) -> Int? {
        distance(Array(TextNormalizer.searchKey(left).utf8), Array(TextNormalizer.searchKey(right).utf8), limit: limit)
    }

    /// Bounded optimal string alignment distance over bytes; `nil` when it exceeds `limit`.
    public static func distance(_ a: [UInt8], _ b: [UInt8], limit: Int) -> Int? {
        var scratch: [Int] = []
        return distance(a, b, limit: limit, scratch: &scratch)
    }

    /// The same, reusing `scratch` for the three rows (no allocation per candidate in a scan).
    static func distance(_ a: [UInt8], _ b: [UInt8], limit: Int, scratch: inout [Int]) -> Int? {
        guard limit >= 0 else { return nil }
        let n = a.count
        let m = b.count
        if abs(n - m) > limit { return nil }
        if n == 0 { return m <= limit ? m : nil }
        if m == 0 { return n <= limit ? n : nil }
        let large = limit + 1
        let width = m + 1
        if scratch.count < width * 3 {
            scratch = [Int](repeating: large, count: width * 3)
        }
        // Row offsets inside `scratch`: two rows back, previous row, current row.
        var older = 0
        var previous = width
        var current = width * 2
        for column in 0...m {
            scratch[older + column] = large
            scratch[previous + column] = column <= limit ? column : large
        }
        for row in 1...n {
            for column in 0...m {
                scratch[current + column] = large
            }
            scratch[current] = row <= limit ? row : large
            var rowMinimum = scratch[current]
            let low = Swift.max(1, row - limit)
            let high = Swift.min(m, row + limit)
            if low <= high {
                for column in low...high {
                    let cost = a[row - 1] == b[column - 1] ? 0 : 1
                    var value = Swift.min(
                        scratch[previous + column] + 1,
                        scratch[current + column - 1] + 1,
                        scratch[previous + column - 1] + cost
                    )
                    if row > 1, column > 1, a[row - 1] == b[column - 2], a[row - 2] == b[column - 1] {
                        value = Swift.min(value, scratch[older + column - 2] + 1)
                    }
                    let bounded = Swift.min(value, large)
                    scratch[current + column] = bounded
                    if bounded < rowMinimum { rowMinimum = bounded }
                }
            }
            // Every later cell is ≥ some cell of this row (transpositions included), so stop early.
            if rowMinimum > limit { return nil }
            let recycled = older
            older = previous
            previous = current
            current = recycled
        }
        let result = scratch[previous + m]
        return result <= limit ? result : nil
    }

    /// Cheap pre-filter before the distance: with one or two edits the first two characters
    /// rarely both change, so a candidate passes when its first or second character lines up
    /// with the query's (also shifted by one — a missing or extra first letter, swapped letters).
    public static func sharesStart(_ query: [UInt8], _ candidate: [UInt8]) -> Bool {
        guard let q0 = query.first, let c0 = candidate.first else { return false }
        if q0 == c0 { return true }
        let q1: UInt8? = query.count > 1 ? query[1] : nil
        let c1: UInt8? = candidate.count > 1 ? candidate[1] : nil
        if let q1, let c1, q1 == c1 { return true }
        if let c1, c1 == q0 { return true }
        if let q1, q1 == c0 { return true }
        return false
    }

    /// The closest strings to `query` among `candidates` (typos within `maxDistance(forLength:)`),
    /// nearest first, then in the input order. Exact matches (distance 0) are left out.
    /// Meant for small lists (the learner's own words); the dictionary uses `FuzzyIndex`.
    public static func closest(to query: String, in candidates: [String], limit: Int = 3) -> [String] {
        let key = Array(TextNormalizer.searchKey(query).utf8)
        let allowed = maxDistance(forLength: key.count)
        guard allowed > 0, limit > 0 else { return [] }
        var found: [(value: String, distance: Int, order: Int)] = []
        var seen = Set<String>()
        var scratch: [Int] = []
        for (order, candidate) in candidates.enumerated() {
            let candidateKey = TextNormalizer.searchKey(candidate)
            guard !candidateKey.isEmpty, seen.insert(candidateKey).inserted else { continue }
            let bytes = Array(candidateKey.utf8)
            guard sharesStart(key, bytes), let value = distance(key, bytes, limit: allowed, scratch: &scratch), value > 0 else { continue }
            found.append((candidate, value, order))
        }
        found.sort { (a: (value: String, distance: Int, order: Int), b: (value: String, distance: Int, order: Int)) -> Bool in
            a.distance != b.distance ? a.distance < b.distance : a.order < b.order
        }
        return Array(found.prefix(limit).map { (item: (value: String, distance: Int, order: Int)) -> String in item.value })
    }
}

/// In-memory index of unique keys for approximate search: keys bucketed by length, so a query
/// only looks at keys whose length can be within the allowed distance. Build once (off the main
/// thread); `matches` is read-only and thread-safe.
public struct FuzzyIndex: Sendable {
    /// One unique key with the payload indices (e.g. dictionary records) sharing it.
    public struct Candidate: Sendable, Hashable {
        public var key: [UInt8]
        public var payload: [Int]
        /// Position of the key in sorted order (stable tie-breaker).
        public var order: Int
    }

    /// One approximate match.
    public struct Match: Sendable, Hashable {
        public var payload: [Int]
        public var distance: Int
        /// Position of the key in the index's (sorted) order — a stable tie-breaker.
        public var order: Int
    }

    private let byLength: [Int: [Candidate]]

    /// Number of unique keys.
    public let count: Int

    /// - Parameter keys: (normalised key, payload index); repeated keys are merged.
    public init(keys: [(key: String, payload: Int)]) {
        var map: [String: [Int]] = [:]
        for item in keys where !item.key.isEmpty {
            map[item.key, default: []].append(item.payload)
        }
        var buckets: [Int: [Candidate]] = [:]
        for (position, key) in map.keys.sorted().enumerated() {
            let bytes = Array(key.utf8)
            buckets[bytes.count, default: []].append(Candidate(key: bytes, payload: map[key] ?? [], order: position))
        }
        byLength = buckets
        count = map.count
    }

    /// Keys within `maxDistance` of `query` (exact key excluded), nearest first.
    /// - Parameter requireSharedStart: apply `FuzzyMatcher.sharesStart` (fast path for typos);
    ///   `false` for the looser „podobne słowa”.
    public func matches(_ query: [UInt8], maxDistance: Int, requireSharedStart: Bool = true, limit: Int = 40) -> [Match] {
        guard maxDistance > 0, !query.isEmpty, limit > 0 else { return [] }
        var found: [Match] = []
        var scratch: [Int] = []
        let low = Swift.max(1, query.count - maxDistance)
        let high = query.count + maxDistance
        for length in low...high {
            guard let bucket = byLength[length] else { continue }
            for candidate in bucket {
                if requireSharedStart && !FuzzyMatcher.sharesStart(query, candidate.key) { continue }
                guard let distance = FuzzyMatcher.distance(query, candidate.key, limit: maxDistance, scratch: &scratch), distance > 0 else { continue }
                found.append(Match(payload: candidate.payload, distance: distance, order: candidate.order))
            }
        }
        found.sort { (a: Match, b: Match) -> Bool in
            a.distance != b.distance ? a.distance < b.distance : a.order < b.order
        }
        return Array(found.prefix(limit))
    }
}
