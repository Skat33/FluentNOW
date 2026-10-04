import Foundation

/// Deterministic interleaving of exercise types (learning.ts `interleaveTasks`, RAPORT-A-E §A1).
public enum TaskInterleaver {
    private struct Entry {
        let task: VocabTask
        let position: Int
    }

    /// Reorders tasks so that equal exercise types do not follow each other whenever possible.
    /// No task is lost; the order inside one type is preserved. When one type holds more than
    /// half of the tasks, its surplus is spread evenly across the gaps between other tasks.
    public static func interleave(_ tasks: [VocabTask]) -> [VocabTask] {
        guard tasks.count > 1 else { return tasks }
        // Buckets in order of first appearance of each type.
        var bucketTypes: [ExerciseType] = []
        var buckets: [[Entry]] = []
        for (position, task) in tasks.enumerated() {
            if let index = bucketTypes.firstIndex(of: task.type) {
                buckets[index].append(Entry(task: task, position: position))
            } else {
                bucketTypes.append(task.type)
                buckets.append([Entry(task: task, position: position)])
            }
        }
        let half = (tasks.count + 1) / 2 // Math.ceil(n / 2)
        if let dominantIndex = buckets.firstIndex(where: { $0.count > half }) {
            let dominant = buckets[dominantIndex]
            var others: [Entry] = []
            for (index, bucket) in buckets.enumerated() where index != dominantIndex {
                others.append(contentsOf: bucket)
            }
            others.sort { $0.position < $1.position }
            let gaps = others.count + 1
            let size = dominant.count / gaps
            let extra = dominant.count % gaps
            var balanced: [VocabTask] = []
            balanced.reserveCapacity(tasks.count)
            var at = 0
            for gap in 0..<gaps {
                let take = size + (gap < extra ? 1 : 0)
                for _ in 0..<take where at < dominant.count {
                    balanced.append(dominant[at].task)
                    at += 1
                }
                if gap < others.count {
                    balanced.append(others[gap].task)
                }
            }
            return balanced
        }

        var heads = Array(repeating: 0, count: buckets.count)
        func remainingCount(_ index: Int) -> Int { buckets[index].count - heads[index] }

        var result: [VocabTask] = []
        result.reserveCapacity(tasks.count)
        while result.count < tasks.count {
            let remaining = buckets.indices.filter { remainingCount($0) > 0 }
            if remaining.isEmpty { break }
            let last = result.last?.type
            let different = remaining.filter { buckets[$0][heads[$0]].task.type != last }
            let candidates = different.isEmpty ? remaining : different
            let count = tasks.count - result.count - 1
            let safe = candidates.filter { candidate in
                remaining.allSatisfy { bucket in
                    let left = remainingCount(bucket) - (bucket == candidate ? 1 : 0)
                    let allowed = bucket == candidate ? count / 2 : (count + 1) / 2
                    return left <= allowed
                }
            }
            let pool = safe.isEmpty ? candidates : safe
            let useSize = safe.isEmpty
            let chosen = pool.stableSorted { a, b in
                if useSize {
                    let sizeA = remainingCount(a)
                    let sizeB = remainingCount(b)
                    if sizeA != sizeB { return sizeA > sizeB }
                }
                return buckets[a][heads[a]].position < buckets[b][heads[b]].position
            }
            guard let pick = chosen.first else { break }
            result.append(buckets[pick][heads[pick]].task)
            heads[pick] += 1
        }
        return result
    }
}
