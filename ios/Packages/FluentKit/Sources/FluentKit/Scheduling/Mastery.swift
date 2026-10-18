import Foundation

/// Mastery, due dates and word status (learning.ts).
public enum Mastery {
    /// Mastery threshold for „Opanowane” (85%).
    public static let masteredThreshold = 85
    /// A skill score below this with ≥ `hardWrongCount` errors marks the word as „Trudne”.
    public static let hardValueThreshold = 65
    public static let hardWrongCount = 3

    /// `masteryFromInterval`: 0–100 on a logarithmic scale where 90 days = 100.
    /// FSRS (I1): `interval` is the FSRS interval at the desired retention (≈ stability at 90%),
    /// so 85% ≈ 45 days of stability; intervals above 90 days stay at 100.
    public static func fromInterval(_ interval: Double) -> Int {
        let safe = interval.isFinite ? Swift.max(0, interval) : 0
        let value = log1p(safe) / log(91.0) * 100
        return jsRoundInt(Swift.min(100, Swift.max(0, value)))
    }

    /// `mastery(m)`: average of the five mastery skills; unpracticed skills count as 0,
    /// pronunciation never counts.
    public static func of(_ meaning: Meaning) -> Int {
        var sum = 0
        for skill in Skill.masterySkills {
            sum += fromInterval(meaning.scores[skill]?.interval ?? 0)
        }
        return jsRoundInt(Double(sum) / Double(Skill.masterySkills.count))
    }

    /// `wordMastery(w)`: average meaning mastery (0 for a word without meanings).
    public static func of(_ word: Word) -> Int {
        guard !word.meanings.isEmpty else { return 0 }
        let sum = word.meanings.reduce(0) { $0 + of($1) }
        return jsRoundInt(Double(sum) / Double(word.meanings.count))
    }

    /// `due(m)`: the earliest due time of any scored skill; 0 for a new meaning.
    public static func due(_ meaning: Meaning) -> Timestamp {
        let values = meaning.scores.values
        guard let first = values.first else { return 0 }
        return values.reduce(first.due) { Swift.min($0, $1.due) }
    }

    /// `true` when the meaning was never answered.
    public static func isNew(_ meaning: Meaning) -> Bool {
        meaning.scores.isEmpty
    }

    /// `status(w)` with an injected clock.
    public static func status(of word: Word, now: Timestamp) -> WordStatus {
        if word.archived { return .archived }
        if word.hard || isHardByScores(word) { return .hard }
        if !word.meanings.contains(where: { !$0.scores.isEmpty }) { return .new }
        if of(word) >= masteredThreshold {
            return word.meanings.contains(where: { due($0) < now }) ? .needsRefresh : .mastered
        }
        return .learning
    }

    /// Some skill has ≥ 3 errors and mastery below 65.
    public static func isHardByScores(_ word: Word) -> Bool {
        word.meanings.contains { meaning in
            meaning.scores.values.contains { score in
                score.wrong >= hardWrongCount && fromInterval(score.interval) < hardValueThreshold
            }
        }
    }
}

extension Meaning {
    /// `mastery(m)` (0–100).
    public var mastery: Int { Mastery.of(self) }
    /// `due(m)` (ms, 0 for new meanings).
    public var due: Timestamp { Mastery.due(self) }
    /// `true` when never answered.
    public var isNew: Bool { scores.isEmpty }
}

extension Word {
    /// `wordMastery(w)` (0–100).
    public var mastery: Int { Mastery.of(self) }

    /// `status(w)` at `now`.
    public func status(now: Timestamp) -> WordStatus {
        Mastery.status(of: self, now: now)
    }
}
