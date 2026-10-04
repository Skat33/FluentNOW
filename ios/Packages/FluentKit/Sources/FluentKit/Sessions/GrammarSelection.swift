import Foundation

/// Grammar bank exposure tracking and selection (grammar-bank.ts).
public enum GrammarSelector {
    /// Stable id of a bank task: its `bankId`, or `legacy-grammar-<fnv1a(context)>`
    /// (bit-identical to the web, so imported `grammarSeen` keeps working).
    public static func taskID(bankId: String?, context: String) -> String {
        if let bankId, !bankId.isEmpty { return bankId }
        return "legacy-grammar-\(FNV1a.hash32(context))"
    }

    public static func taskID(_ item: ProductionItem) -> String {
        taskID(bankId: item.bankId, context: item.context)
    }

    public static func taskID(_ question: PracticeQuestion) -> String {
        taskID(bankId: question.bankId, context: question.context)
    }

    /// `selectGrammarItems`: unseen tasks first; inside a set, constructions and scenarios are
    /// spread (penalty for repeats); after the level is exhausted, the least recently shown tasks
    /// repeat (the 12 most recent are avoided). Deterministic for a given `variant`.
    public static func selectItems(_ pool: [ProductionItem], count: Int, seen: [String: Double] = [:], variant: Int = 0) -> [ProductionItem] {
        var candidates = pool.map { item -> ProductionItem in
            var copy = item
            copy.bankId = taskID(item)
            return copy
        }
        let recent = Set(
            seen.sorted { a, b in a.value != b.value ? a.value > b.value : a.key < b.key }
                .prefix(12)
                .map { $0.key }
        )
        func seenValue(_ item: ProductionItem) -> Double {
            let value = seen[item.bankId ?? ""] ?? 0
            return value.isFinite ? value : 0
        }
        func tieHash(_ item: ProductionItem) -> UInt32 {
            FNV1a.hash32((item.bankId ?? "") + String(variant))
        }
        var result: [ProductionItem] = []
        let target = min(max(0, count), pool.count)
        while result.count < target && !candidates.isEmpty {
            let current = result
            func penalty(_ item: ProductionItem) -> Int {
                var value = 0
                for chosen in current {
                    if chosen.rule == item.rule { value += 2 }
                    if let scenario = item.scenarioId, !scenario.isEmpty, chosen.scenarioId == scenario { value += 3 }
                }
                return value
            }
            func compare(_ a: ProductionItem, _ b: ProductionItem) -> Int {
                let sa = seenValue(a)
                let sb = seenValue(b)
                let seenA = sa != 0
                let seenB = sb != 0
                if seenA != seenB { return seenA ? 1 : -1 }
                if seenA && seenB {
                    let recentA = recent.contains(a.bankId ?? "") ? 1 : 0
                    let recentB = recent.contains(b.bankId ?? "") ? 1 : 0
                    if recentA != recentB { return recentA - recentB }
                    if sa != sb { return sa < sb ? -1 : 1 }
                    return compareValues(tieHash(a), tieHash(b))
                }
                let pa = penalty(a)
                let pb = penalty(b)
                if pa != pb { return pa - pb }
                return compareValues(tieHash(a), tieHash(b))
            }
            candidates = candidates.stableSorted { compare($0, $1) < 0 }
            result.append(candidates.removeFirst())
        }
        return result
    }

    /// `markGrammarSeen`: records that a bank task was shown.
    public static func markSeen(_ state: LearnerState, bankId: String?, context: String, at: Timestamp) -> LearnerState {
        var next = state
        next.grammarSeen[taskID(bankId: bankId, context: context)] = at
        return next
    }

    /// `grammarSelectionSeen`: exposures plus the unshown tail of paused sessions (reserved, so a
    /// new set never repeats them; not persisted).
    public static func selectionSeen(_ state: LearnerState, now: Timestamp) -> [String: Double] {
        var seen = state.grammarSeen
        var reserved: [String] = []
        if let combined = state.combined, combined.completedAt == nil {
            for task in combined.tasks.dropFirst(min(combined.index, combined.tasks.count)) {
                if let question = task.questionTask?.question, let bankId = question.bankId, !bankId.isEmpty {
                    reserved.append(bankId)
                }
            }
        }
        if let production = state.production, production.completedAt == nil {
            for item in production.set.items.dropFirst(min(production.index, production.set.items.count)) {
                if let bankId = item.bankId, !bankId.isEmpty { reserved.append(bankId) }
            }
        }
        if let practice = state.practice, practice.completedAt == nil {
            for item in practice.set.items.dropFirst(min(practice.index, practice.set.items.count)) where item.category == .grammar {
                if let bankId = item.bankId, !bankId.isEmpty { reserved.append(bankId) }
            }
        }
        for id in reserved {
            seen[id] = max(seen[id] ?? 0, now)
        }
        return seen
    }
}
