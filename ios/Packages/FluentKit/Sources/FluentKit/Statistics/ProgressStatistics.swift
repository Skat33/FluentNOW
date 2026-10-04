import Foundation

/// Answers on one calendar day.
public struct DayActivity: Sendable, Hashable, Identifiable {
    /// Start of the day in the given calendar.
    public var date: Date
    public var count: Int
    /// Independent correct answers.
    public var correct: Int
    public var id: Date { date }

    public init(date: Date, count: Int, correct: Int) {
        self.date = date
        self.count = count
        self.correct = correct
    }
}

/// Average score of one skill over practiced meanings.
public struct SkillAverage: Sendable, Hashable, Identifiable {
    public var skill: Skill
    /// `nil` when no meaning practiced this skill („—”).
    public var average: Int?
    public var count: Int
    public var id: Skill { skill }

    public init(skill: Skill, average: Int?, count: Int) {
        self.skill = skill
        self.average = average
        self.count = count
    }
}

/// Progress of one CEFR level.
public struct LevelProgress: Sendable, Hashable, Identifiable {
    public var level: String
    public var wordCount: Int
    public var meaningCount: Int
    /// Average meaning mastery (0 when empty).
    public var average: Int
    public var mastered: Int
    public var id: String { level }

    public init(level: String, wordCount: Int, meaningCount: Int, average: Int, mastered: Int) {
        self.level = level
        self.wordCount = wordCount
        self.meaningCount = meaningCount
        self.average = average
        self.mastered = mastered
    }
}

/// Number of meanings due on a day of the forecast.
public struct ForecastDay: Sendable, Hashable, Identifiable {
    public var date: Date
    /// For day 0: everything overdue or due today.
    public var count: Int
    public var id: Date { date }

    public init(date: Date, count: Int) {
        self.date = date
        self.count = count
    }
}

/// Meanings that crossed the mastery threshold in one week.
public struct WeeklyGain: Sendable, Hashable, Identifiable {
    /// Start of the 7-day window.
    public var start: Date
    public var count: Int
    public var id: Date { start }

    public init(start: Date, count: Int) {
        self.start = start
        self.count = count
    }
}

/// Daily goal progress.
public struct DailyGoalProgress: Sendable, Hashable {
    public var done: Int
    public var goal: Int
    /// 0…1.
    public var fraction: Double
    public var isReached: Bool { done >= goal }

    public init(done: Int, goal: Int) {
        self.done = done
        self.goal = max(1, goal)
        self.fraction = min(1, Double(done) / Double(max(1, goal)))
    }
}

/// Headline numbers of the progress screen.
public struct StatsOverview: Sendable, Hashable {
    public var wordCount: Int
    public var meaningCount: Int
    public var masteredMeanings: Int
    /// Practiced meanings due now.
    public var dueMeanings: Int
    /// Meanings never practiced.
    public var newMeanings: Int
    /// Independent correct answers / all answers, in percent (incl. compacted history).
    public var accuracy: Int
    public var totalAnswers: Int
    public var streak: Int
    /// Meanings without a CEFR level.
    public var missingLevels: Int

    public init(wordCount: Int, meaningCount: Int, masteredMeanings: Int, dueMeanings: Int, newMeanings: Int, accuracy: Int, totalAnswers: Int, streak: Int, missingLevels: Int) {
        self.wordCount = wordCount
        self.meaningCount = meaningCount
        self.masteredMeanings = masteredMeanings
        self.dueMeanings = dueMeanings
        self.newMeanings = newMeanings
        self.accuracy = accuracy
        self.totalAnswers = totalAnswers
        self.streak = streak
        self.missingLevels = missingLevels
    }
}

/// Totals of finished readings or practice sets.
public struct ExerciseTotals: Sendable, Hashable {
    public var sets: Int
    public var correct: Int
    public var total: Int

    public init(sets: Int, correct: Int, total: Int) {
        self.sets = sets
        self.correct = correct
        self.total = total
    }
}

/// Pure statistics for the „Postępy” and „Dzisiaj” screens. Demo reviews are excluded.
/// Days are local calendar days of the injected `calendar`. Compute off the main thread for
/// large histories and cache the result.
public enum ProgressStatistics {
    private static func realReviews(_ state: LearnerState) -> [Review] {
        state.reviews.filter { !$0.demo }
    }

    private static func activeMeanings(_ state: LearnerState) -> [(word: Word, meaning: Meaning)] {
        var result: [(word: Word, meaning: Meaning)] = []
        for word in state.words where !word.archived {
            for meaning in word.meanings { result.append((word, meaning)) }
        }
        return result
    }

    /// Answers per day for the last `days` days ending today (oldest first).
    public static func activity(_ state: LearnerState, days: Int, now: Timestamp, calendar: Calendar = .current) -> [DayActivity] {
        let count = max(1, days)
        let today = calendar.startOfDay(for: Date(timestamp: now))
        guard let first = calendar.date(byAdding: .day, value: -(count - 1), to: today) else { return [] }
        var counts: [Date: (count: Int, correct: Int)] = [:]
        for review in realReviews(state) {
            let day = calendar.startOfDay(for: Date(timestamp: review.at))
            guard day >= first && day <= today else { continue }
            var value = counts[day] ?? (count: 0, correct: 0)
            value.count += 1
            if review.correct && !review.hint { value.correct += 1 }
            counts[day] = value
        }
        var result: [DayActivity] = []
        for offset in 0..<count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
            let value = counts[date] ?? (count: 0, correct: 0)
            result.append(DayActivity(date: date, count: value.count, correct: value.correct))
        }
        return result
    }

    /// The week histogram (7 days).
    public static func week(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> [DayActivity] {
        activity(state, days: 7, now: now, calendar: calendar)
    }

    /// The activity calendar (84 days = 12 weeks).
    public static func activityCalendar(_ state: LearnerState, days: Int = 84, now: Timestamp, calendar: Calendar = .current) -> [DayActivity] {
        activity(state, days: days, now: now, calendar: calendar)
    }

    /// Answers given today and the daily goal.
    public static func dailyGoal(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> DailyGoalProgress {
        let today = calendar.startOfDay(for: Date(timestamp: now))
        let done = realReviews(state).filter { calendar.startOfDay(for: Date(timestamp: $0.at)) == today }.count
        return DailyGoalProgress(done: done, goal: state.settings.goal)
    }

    /// Consecutive days with at least one answer, ending today (or yesterday if nothing yet today).
    public static func streak(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> Int {
        var days = Set<Date>()
        for review in realReviews(state) {
            days.insert(calendar.startOfDay(for: Date(timestamp: review.at)))
        }
        let today = calendar.startOfDay(for: Date(timestamp: now))
        var streak = 0
        for offset in 0..<3650 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            if days.contains(day) {
                streak += 1
            } else if offset > 0 {
                break
            }
        }
        return streak
    }

    /// Average score of each skill over meanings that practiced it.
    public static func skillAverages(_ state: LearnerState) -> [SkillAverage] {
        let meanings = activeMeanings(state).map { $0.meaning }
        return Skill.allCases.map { (skill: Skill) -> SkillAverage in
            let scores = meanings.compactMap { $0.scores[skill] }
            guard !scores.isEmpty else { return SkillAverage(skill: skill, average: nil, count: 0) }
            let sum = scores.reduce(0) { $0 + $1.value }
            return SkillAverage(skill: skill, average: jsRoundInt(Double(sum) / Double(scores.count)), count: scores.count)
        }
    }

    /// Progress per CEFR level (meaning level, falling back to the word level).
    public static func levelProgress(_ state: LearnerState) -> [LevelProgress] {
        let items = activeMeanings(state)
        return CEFR.levels.map { (level: String) -> LevelProgress in
            let matching = items.filter { $0.meaning.effectiveLevel(in: $0.word) == level }
            let words = Set(matching.map { $0.word.id }).count
            let masteries = matching.map { Mastery.of($0.meaning) }
            let average = masteries.isEmpty ? 0 : jsRoundInt(Double(masteries.reduce(0, +)) / Double(masteries.count))
            let mastered = masteries.filter { $0 >= Mastery.masteredThreshold }.count
            return LevelProgress(level: level, wordCount: words, meaningCount: matching.count, average: average, mastered: mastered)
        }
    }

    /// Practiced meanings due in each of the next `days` days; day 0 includes everything overdue.
    public static func reviewForecast(_ state: LearnerState, days: Int = 7, now: Timestamp, calendar: Calendar = .current) -> [ForecastDay] {
        let today = calendar.startOfDay(for: Date(timestamp: now))
        let dueDates = activeMeanings(state).filter { !$0.meaning.scores.isEmpty }.map { Mastery.due($0.meaning) }
        var result: [ForecastDay] = []
        for offset in 0..<max(1, days) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let count: Int
            if offset == 0 {
                count = dueDates.filter { $0 <= now }.count
            } else {
                count = dueDates.filter { $0 > now && calendar.startOfDay(for: Date(timestamp: $0)) == date }.count
            }
            result.append(ForecastDay(date: date, count: count))
        }
        return result
    }

    /// Unique meanings whose mastery rose from below to at least 85% between `start` and `end`
    /// (only reviews on the five-skill scale, `masteryVersion == 2`).
    public static func masteryGains(_ state: LearnerState, from start: Timestamp, to end: Timestamp) -> Int {
        var meanings = Set<String>()
        for review in state.reviews where !review.demo && review.masteryVersion == 2 && review.at > start && review.at <= end {
            if review.before < Mastery.masteredThreshold && review.after >= Mastery.masteredThreshold {
                meanings.insert(review.meaningId)
            }
        }
        return meanings.count
    }

    /// Weekly gains for the last `weeks` 7-day windows (oldest first); the last one ends now.
    public static func weeklyMasteryGains(_ state: LearnerState, weeks: Int = 1, now: Timestamp) -> [WeeklyGain] {
        let windows = max(1, weeks)
        return (0..<windows).reversed().map { (index: Int) -> WeeklyGain in
            let end = now - Double(index) * 7 * TimeConstants.dayMs
            let start = end - 7 * TimeConstants.dayMs
            return WeeklyGain(start: Date(timestamp: start), count: masteryGains(state, from: start, to: end))
        }
    }

    /// Words that need extra practice: „Trudne” or with errors / slow answers, weakest first.
    public static func hardWords(_ state: LearnerState, limit: Int = 5, now: Timestamp) -> [Word] {
        let candidates = state.words.filter { word in
            !word.archived && (Mastery.status(of: word, now: now) == .hard
                || word.meanings.contains { $0.scores.values.contains { $0.wrong > 0 || $0.slow > 0 } })
        }
        return Array(candidates.stableSorted { Mastery.of($0) < Mastery.of($1) }.prefix(max(0, limit)))
    }

    /// Headline numbers.
    public static func overview(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> StatsOverview {
        let items = activeMeanings(state)
        let words = state.words.filter { !$0.archived }
        let reviews = realReviews(state)
        let summaryCount = state.reviewSummaries.reduce(0) { $0 + $1.count }
        let summaryCorrect = state.reviewSummaries.reduce(0) { $0 + $1.correct }
        let total = reviews.count + summaryCount
        let correct = reviews.filter { $0.correct && !$0.hint }.count + summaryCorrect
        return StatsOverview(
            wordCount: words.count,
            meaningCount: items.count,
            masteredMeanings: items.filter { Mastery.of($0.meaning) >= Mastery.masteredThreshold }.count,
            dueMeanings: items.filter { !$0.meaning.scores.isEmpty && Mastery.due($0.meaning) <= now }.count,
            newMeanings: items.filter { $0.meaning.scores.isEmpty }.count,
            accuracy: total > 0 ? jsRoundInt(Double(correct) / Double(total) * 100) : 0,
            totalAnswers: total,
            streak: streak(state, now: now, calendar: calendar),
            missingLevels: items.filter { !CEFR.isValid($0.meaning.effectiveLevel(in: $0.word)) }.count
        )
    }

    /// Totals of finished readings.
    public static func readingTotals(_ state: LearnerState) -> ExerciseTotals {
        ExerciseTotals(
            sets: state.readingHistory.count,
            correct: state.readingHistory.reduce(0) { $0 + $1.correct },
            total: state.readingHistory.reduce(0) { $0 + $1.total }
        )
    }

    /// Totals of finished grammar / idiom / mixed sets and production sets.
    public static func practiceTotals(_ state: LearnerState) -> ExerciseTotals {
        ExerciseTotals(
            sets: state.practiceHistory.count + state.productionHistory.count,
            correct: state.practiceHistory.reduce(0) { $0 + $1.correct } + state.productionHistory.reduce(0) { $0 + $1.correct },
            total: state.practiceHistory.reduce(0) { $0 + $1.total } + state.productionHistory.reduce(0) { $0 + $1.total }
        )
    }

    /// Progress of a collection: number of meanings and average mastery.
    public static func collectionProgress(_ state: LearnerState, collection: String) -> (meanings: Int, average: Int) {
        let masteries = state.words.filter { !$0.archived && $0.collection == collection }.flatMap { $0.meanings }.map { Mastery.of($0) }
        guard !masteries.isEmpty else { return (0, 0) }
        return (masteries.count, jsRoundInt(Double(masteries.reduce(0, +)) / Double(masteries.count)))
    }
}
