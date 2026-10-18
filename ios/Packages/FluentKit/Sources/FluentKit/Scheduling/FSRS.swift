import Foundation

/// FSRS-6 memory model (Free Spaced Repetition Scheduler, open-spaced-repetition).
///
/// Port of the formulas of `ts-fsrs` (FSRS-6.0, `packages/fsrs/src/algorithm.ts`) and `py-fsrs`
/// (`fsrs/scheduler.py`) with their default parameters. Pure math only: no learning steps,
/// no fuzz, no clock — `Scheduler` decides when a rating happens and what the interval means
/// in the app. Elapsed time is measured in whole days, like the reference implementations.
public enum FSRS {
    /// FSRS rating of one answer.
    public enum Rating: Int, CaseIterable, Sendable, Hashable {
        case again = 1
        case hard = 2
        case good = 3
        case easy = 4
    }

    /// Memory state of one meaning × skill.
    public struct MemoryState: Sendable, Hashable {
        /// Days after which the probability of recall falls to 90%.
        public var stability: Double
        /// 1 (easy) … 10 (hard).
        public var difficulty: Double

        public init(stability: Double, difficulty: Double) {
            self.stability = stability
            self.difficulty = difficulty
        }
    }

    /// FSRS-6 default parameters w0…w20 (ts-fsrs `default_w`, py-fsrs `DEFAULT_PARAMETERS`).
    public static let defaultParameters: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666,
        0.796, 1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658,
        0.1542
    ]
    /// Default desired retention (probability of recall at the moment of the review).
    public static let defaultRetention = 0.9
    /// Retention values offered in the settings.
    public static let retentionChoices: [Double] = [0.85, 0.9, 0.95]
    /// Accepted range of a desired retention (out-of-range values are clamped).
    public static let retentionRange: ClosedRange<Double> = 0.7...0.97
    /// Stability bounds (`S_MIN`, `S_MAX` of ts-fsrs).
    public static let minimumStability = 0.001
    public static let maximumStability = 36_500.0
    /// Difficulty bounds.
    public static let difficultyRange: ClosedRange<Double> = 1...10

    private static let w = defaultParameters

    /// `w` value with a safe fallback (the array is a constant with 21 entries).
    private static func p(_ index: Int) -> Double {
        index >= 0 && index < w.count ? w[index] : 0
    }

    /// Decay of the forgetting curve (`-w20`).
    public static var decay: Double { -p(20) }

    /// Factor chosen so that R(S, S) = 0.9.
    public static var factor: Double { pow(0.9, 1 / decay) - 1 }

    // MARK: Forgetting curve and interval

    /// Probability of recall `elapsedDays` after the last review.
    public static func retrievability(elapsedDays: Double, stability: Double) -> Double {
        guard stability > 0, stability.isFinite else { return 0 }
        let t = elapsedDays.isFinite ? max(0, elapsedDays) : 0
        return pow(1 + factor * t / stability, decay)
    }

    /// Interval (in days, unrounded) after which recall probability falls to `retention`.
    public static func rawInterval(stability: Double, retention: Double = defaultRetention) -> Double {
        let r = clampedRetention(retention)
        let s = stability.isFinite ? max(minimumStability, stability) : minimumStability
        return s / factor * (pow(r, 1 / decay) - 1)
    }

    /// Whole-day interval like ts-fsrs `next_interval` (rounded, 1 … `maximum`).
    public static func interval(stability: Double, retention: Double = defaultRetention, maximum: Double = 36_500) -> Double {
        let upper = maximum.isFinite ? max(1, maximum) : 36_500
        let raw = rawInterval(stability: stability, retention: retention)
        guard raw.isFinite else { return upper }
        return min(max(1, raw.rounded()), upper)
    }

    /// Retention clamped to `retentionRange`; NaN → default.
    public static func clampedRetention(_ retention: Double) -> Double {
        guard retention.isFinite else { return defaultRetention }
        return min(retentionRange.upperBound, max(retentionRange.lowerBound, retention))
    }

    // MARK: Initial state

    /// `init_stability`: S0(G) = w[G-1] (at least 0.1).
    public static func initialStability(_ rating: Rating) -> Double {
        max(p(rating.rawValue - 1), 0.1)
    }

    /// `init_difficulty` without clamping: D0(G) = w4 − e^(w5·(G−1)) + 1.
    public static func initialDifficulty(_ rating: Rating) -> Double {
        p(4) - exp(p(5) * Double(rating.rawValue - 1)) + 1
    }

    // MARK: Updates

    /// `next_difficulty`: linear damping and mean reversion towards D0(Easy), clamped to 1…10.
    public static func nextDifficulty(_ difficulty: Double, rating: Rating) -> Double {
        let delta = -p(6) * (Double(rating.rawValue) - 3)
        let damped = difficulty + delta * (10 - difficulty) / 9
        let reverted = p(7) * initialDifficulty(.easy) + (1 - p(7)) * damped
        return clampDifficulty(reverted)
    }

    /// `next_recall_stability` (Hard / Good / Easy after at least one day).
    public static func nextRecallStability(difficulty: Double, stability: Double, retrievability: Double, rating: Rating) -> Double {
        let hardPenalty = rating == .hard ? p(15) : 1
        let easyBonus = rating == .easy ? p(16) : 1
        let growth = exp(p(8)) * (11 - difficulty) * pow(stability, -p(9))
            * (exp((1 - retrievability) * p(10)) - 1) * hardPenalty * easyBonus
        return clampStability(stability * (1 + growth))
    }

    /// `next_forget_stability` (Again after at least one day), including the FSRS-6 short-term
    /// ceiling S / e^(w17·w18).
    public static func nextForgetStability(difficulty: Double, stability: Double, retrievability: Double) -> Double {
        let longTerm = p(11) * pow(difficulty, -p(12)) * (pow(stability + 1, p(13)) - 1)
            * exp((1 - retrievability) * p(14))
        let shortTerm = stability / exp(p(17) * p(18))
        return clampStability(min(clampStability(longTerm), shortTerm))
    }

    /// `next_short_term_stability` (a review on the same day). Hard, Good and Easy never
    /// lower stability.
    public static func nextShortTermStability(stability: Double, rating: Rating) -> Double {
        var increase = pow(stability, -p(19)) * exp(p(17) * (Double(rating.rawValue) - 3 + p(18)))
        if rating != .again { increase = max(increase, 1) }
        return clampStability(stability * increase)
    }

    /// `next_state`: memory state after a rating given `elapsedDays` whole days after the
    /// previous review (`nil` = first review).
    public static func nextState(_ memory: MemoryState?, elapsedDays: Double, rating: Rating) -> MemoryState {
        guard let memory, let valid = validated(memory) else {
            return MemoryState(
                stability: initialStability(rating),
                difficulty: clampDifficulty(initialDifficulty(rating))
            )
        }
        let t = elapsedDays.isFinite ? max(0, elapsedDays.rounded(.down)) : 0
        let stability: Double
        if t < 1 {
            stability = nextShortTermStability(stability: valid.stability, rating: rating)
        } else {
            let r = retrievability(elapsedDays: t, stability: valid.stability)
            if rating == .again {
                stability = nextForgetStability(difficulty: valid.difficulty, stability: valid.stability, retrievability: r)
            } else {
                stability = nextRecallStability(difficulty: valid.difficulty, stability: valid.stability, retrievability: r, rating: rating)
            }
        }
        return MemoryState(stability: stability, difficulty: nextDifficulty(valid.difficulty, rating: rating))
    }

    /// The state with finite, in-range values (`nil` when it cannot be repaired).
    public static func validated(_ memory: MemoryState) -> MemoryState? {
        guard memory.stability.isFinite, memory.difficulty.isFinite, memory.stability > 0 else { return nil }
        return MemoryState(stability: clampStability(memory.stability), difficulty: clampDifficulty(memory.difficulty))
    }

    static func clampStability(_ value: Double) -> Double {
        guard value.isFinite else { return value > 0 ? maximumStability : minimumStability }
        return min(maximumStability, max(minimumStability, value))
    }

    static func clampDifficulty(_ value: Double) -> Double {
        guard value.isFinite else { return 5 }
        return min(difficultyRange.upperBound, max(difficultyRange.lowerBound, value))
    }
}
