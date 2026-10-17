import Foundation

/// XP balance (G5). All amounts are whole XP; per-answer amounts are computed in hundredths
/// (centi-XP) with integer arithmetic, so the result is identical on every device.
public enum XPRules {
    // MARK: Answers

    /// XP for a correct, unaided, first answer of the day for a word, by the skill the task trains.
    /// Recognition (choose a meaning, flashcard, picture) is the easiest; typing the word (recall,
    /// cloze → usage, dictation → listening) is worth about twice as much.
    public static func baseXP(for skill: Skill) -> Int {
        switch skill {
        case .recognition: return 4
        case .listening: return 7
        case .recall: return 8
        case .usage: return 8
        case .spelling: return 8
        case .pronunciation: return 2
        }
    }

    /// Correct only after a hint: 50%.
    public static let hintPercent = 50
    /// Correct meaning but a spelling mistake (review error „Pisownia”): 70%.
    public static let spellingMistakePercent = 70
    /// Error label stored by `Scheduler.recordAnswer` for a correct answer with a spelling mistake.
    public static let spellingErrorLabel = "Pisownia"

    /// The n-th answer (0-based) for the same word on the same day earns this share (no farming):
    /// 100%, 60%, 35%, 20%, then 10% for every further repetition.
    public static let repetitionPercents = [100, 60, 35, 20]
    public static let repetitionFloorPercent = 10

    public static func repetitionPercent(_ index: Int) -> Int {
        guard index >= 0 else { return 100 }
        return index < repetitionPercents.count ? repetitionPercents[index] : repetitionFloorPercent
    }

    /// Centi-XP of one answer. Wrong answers earn nothing.
    public static func answerCentiXP(skill: Skill, correct: Bool, hint: Bool, spellingMistake: Bool, repetition: Int) -> Int {
        guard correct else { return 0 }
        var percent = 100
        if hint {
            percent = hintPercent
        } else if spellingMistake {
            percent = spellingMistakePercent
        }
        return baseXP(for: skill) * percent * repetitionPercent(repetition) / 100
    }

    /// Days older than the review history (compacted into per-day summaries without details):
    /// XP per correct answer — close to the average of a typical mix.
    public static let compactedXPPerCorrect = 6

    // MARK: Sets

    /// Reading: per correct question + for finishing a text.
    public static let readingXPPerCorrect = 3
    public static let readingCompletionXP = 10
    /// Grammar / idioms / mixed practice: per correct item + for a finished set of at least `setMinimumItems`.
    public static let practiceXPPerCorrect = 3
    public static let practiceCompletionXP = 8
    public static let setMinimumItems = 5
    /// Production (writing forms): per correct item + for a finished set of at least `productionMinimumItems`.
    public static let productionXPPerCorrect = 5
    public static let productionCompletionXP = 8
    public static let productionMinimumItems = 4
    /// At most this many finished sets of each kind are rewarded per day.
    public static let maxRewardedSetsPerDay = 6

    // MARK: Daily bonuses (moderate)

    /// Daily goal reached.
    public static let goalBonusXP = 20
    /// The goal bonus needs `min(goal, goalBonusCap)` answers, so raising the goal above the cap
    /// never takes XP away from past days.
    public static let goalBonusCap = 20
    /// Streak: +3 XP per consecutive day before today, at most +15 per day.
    public static let streakXPPerDay = 3
    public static let streakBonusCapDays = 5

    public static func goalThreshold(goal: Int) -> Int {
        max(1, min(goal, goalBonusCap))
    }

    /// Bonus for a day that is the `length`-th day of a streak (1 = first day → 0).
    public static func streakBonus(length: Int) -> Int {
        streakXPPerDay * min(max(0, length - 1), streakBonusCapDays)
    }

    // MARK: Levels

    public static let maxLevel = 100
    /// Total XP needed to reach `level`: 120 · (level − 1)^1.75 (level 1 = 0 XP). With 10–15 minutes
    /// a day (~145 XP) level 2 comes on day 1, levels 3–5 after 3, 6 and 11 days, then about one
    /// level a week and slower later (level 8 after a month, 14 after three — simulation test).
    public static let levelBase: Double = 120
    public static let levelExponent: Double = 1.75

    public static func threshold(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        let capped = min(level, maxLevel)
        return Int((levelBase * pow(Double(capped - 1), levelExponent)).rounded())
    }
}
