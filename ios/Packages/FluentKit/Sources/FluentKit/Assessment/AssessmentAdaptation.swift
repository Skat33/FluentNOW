import Foundation

/// Light adaptation during the test (pure functions over the answers so far):
/// three right answers in a row → the next questions come from the upper part of the band (the
/// base level); two wrong in a row → from the lower part. The choice sticks until the opposite
/// streak. Before any streak the tiers alternate, starting with the lower one (warm-up). A longer
/// good streak (`stretchStreak`) on the upper part allows a question one level above the band,
/// at most `stretchCap` of them. Never outside the band ±1.
public enum AssessmentAdaptation {
    /// Right answers in a row that move the test to the upper part.
    public static let upStreak = 3
    /// Wrong answers in a row that move it to the lower part.
    public static let downStreak = 2
    /// Right answers in a row (while on the upper part) that allow one stretch question.
    public static let stretchStreak = 4
    /// Maximum share of stretch questions among the vocabulary questions.
    public static let stretchShare = 0.15

    /// Direction chosen by the streaks so far.
    public enum Cursor: String, Sendable, Hashable {
        case neutral
        case upper
        case lower
    }

    /// Cursor and current streak after `outcomes` (oldest first).
    public static func cursor(after outcomes: [Bool]) -> (cursor: Cursor, rightStreak: Int, wrongStreak: Int) {
        var cursor = Cursor.neutral
        var right = 0
        var wrong = 0
        for outcome in outcomes {
            if outcome {
                right += 1
                wrong = 0
            } else {
                wrong += 1
                right = 0
            }
            if right >= upStreak { cursor = .upper }
            if wrong >= downStreak { cursor = .lower }
        }
        return (cursor, right, wrong)
    }

    /// Stretch questions allowed in a test with `vocabularyCount` vocabulary questions (15 %,
    /// none in very short tests).
    public static func stretchCap(vocabularyCount: Int) -> Int {
        guard vocabularyCount >= 7 else { return 0 }
        return Int((Double(vocabularyCount) * stretchShare).rounded(.down))
    }

    /// Tier wanted for the next vocabulary question. `position` is the number of vocabulary
    /// questions already drawn (alternation before the first streak). Stretch questions never come
    /// two in a row (`lastWasStretch`) — a small admixture, not a block.
    public static func preferredTier(outcomes: [Bool], position: Int, stretchUsed: Int, stretchCap: Int, hasStretchLevel: Bool, lastWasStretch: Bool = false) -> AssessmentTier {
        let state = cursor(after: outcomes)
        switch state.cursor {
        case .upper:
            if hasStretchLevel && !lastWasStretch && stretchUsed < stretchCap && state.rightStreak >= stretchStreak {
                return .stretch
            }
            return .upper
        case .lower:
            return .lower
        case .neutral:
            return position % 2 == 0 ? .lower : .upper
        }
    }

    /// Tiers to try in order (the wanted one first; the stretch tier is never a fallback).
    public static func tierOrder(_ preferred: AssessmentTier) -> [AssessmentTier] {
        switch preferred {
        case .lower: return [.lower, .upper]
        case .upper: return [.upper, .lower]
        case .stretch: return [.stretch, .upper, .lower]
        }
    }
}
