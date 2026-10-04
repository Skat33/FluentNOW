import Foundation

/// Example-sentence pool rules (example-pool.ts). Meanings without `enrichment`
/// (built-in content, imports, legacy exports) use all their examples.
public enum ExamplePool {
    public static let batchSize = 15
    public static let limit = 90
    public static let refillRemaining = 3

    /// Number of published (usable) examples. Only whole batches are published.
    public static func availableCount(_ meaning: Meaning) -> Int {
        guard let enrichment = meaning.enrichment else { return meaning.examples.count }
        let completed = (enrichment.round ?? 0) + (Set(enrichment.groups).count == 3 ? 1 : 0)
        let wholeBatches = (meaning.examples.count / batchSize) * batchSize
        return max(0, min(wholeBatches, completed * batchSize, limit))
    }

    /// `true` when an AI assistant should generate the next batch of examples.
    public static func needsExpansion(_ meaning: Meaning) -> Bool {
        guard let enrichment = meaning.enrichment, enrichment.phase == .ready else { return false }
        let count = availableCount(meaning)
        let used = Set((meaning.usedExamples ?? []).filter { $0 >= 0 && $0 < count })
        return count >= batchSize && count < limit && count - used.count <= refillRemaining
    }

    /// Queues the next generation round (idempotent).
    public static func beginExpansion(_ meaning: Meaning) -> Meaning {
        guard needsExpansion(meaning), let enrichment = meaning.enrichment else { return meaning }
        var next = meaning
        next.enrichment = Enrichment(
            round: (enrichment.round ?? 0) + 1,
            phase: .examples,
            detailsPending: enrichment.detailsPending,
            groups: [],
            attempts: 0,
            retryAt: 0,
            error: nil
        )
        return next
    }

    /// First unused published example; when all were used, `fallback % count`.
    public static func nextUnusedExample(_ meaning: Meaning, fallback: Int = 0) -> Int {
        let count = availableCount(meaning)
        let used = Set(meaning.usedExamples ?? [])
        var index = 0
        while index < count {
            if !used.contains(index) { return index }
            index += 1
        }
        guard count > 0 else { return 0 }
        return ((fallback % count) + count) % count
    }
}

extension Meaning {
    /// Number of usable example sentences (`availableExampleCount`).
    public var availableExampleCount: Int { ExamplePool.availableCount(self) }
}
