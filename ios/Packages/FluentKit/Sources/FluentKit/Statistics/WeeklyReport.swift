import Foundation

/// Direction of a skill between two weeks.
public enum WeeklyTrend: String, Sendable, Hashable {
    /// Accuracy rose by at least `WeeklyReportBuilder.trendThreshold` points.
    case up
    /// Accuracy fell by at least the threshold.
    case down
    /// Practiced in both weeks, change below the threshold (or too few answers to tell).
    case steady
    /// Practiced this week, not in the previous one.
    case new
    /// Not practiced this week.
    case none
}

/// One skill in the weekly report: answers and accuracy this week vs the previous week.
public struct WeeklySkillTrend: Sendable, Hashable, Identifiable {
    public var skill: Skill
    public var answers: Int
    /// Independent correct answers in percent, `nil` without answers.
    public var accuracy: Int?
    public var previousAnswers: Int
    public var previousAccuracy: Int?
    public var trend: WeeklyTrend

    public var id: Skill { skill }

    /// Change of accuracy in points, `nil` when one of the weeks has no answers.
    public var change: Int? {
        guard let accuracy, let previousAccuracy else { return nil }
        return accuracy - previousAccuracy
    }

    public init(skill: Skill, answers: Int, accuracy: Int?, previousAnswers: Int, previousAccuracy: Int?, trend: WeeklyTrend) {
        self.skill = skill
        self.answers = answers
        self.accuracy = accuracy
        self.previousAnswers = previousAnswers
        self.previousAccuracy = previousAccuracy
        self.trend = trend
    }
}

/// A word that caused the most trouble in the week.
public struct WeeklyHardWord: Sendable, Hashable, Identifiable {
    public var wordId: String
    public var term: String
    /// Translations of the word's meanings joined with „ · ”.
    public var translation: String
    /// Wrong answers or answers only after a hint this week.
    public var mistakes: Int
    public var answers: Int
    public var mastery: Int

    public var id: String { wordId }

    public init(wordId: String, term: String, translation: String, mistakes: Int, answers: Int, mastery: Int) {
        self.wordId = wordId
        self.term = term
        self.translation = translation
        self.mistakes = mistakes
        self.answers = answers
        self.mastery = mastery
    }
}

/// Numbers of one 7-day period.
public struct WeeklyPeriodStats: Sendable, Hashable {
    /// Vocabulary answers (exercises and reading questions).
    public var answers: Int
    /// Independent correct answers (correct and without a hint).
    public var correct: Int
    /// Estimated study time in seconds (see `WeeklyReportBuilder` for the estimate).
    public var studySeconds: Int
    /// Meanings practiced for the first time.
    public var newMeanings: Int
    /// Words added to the dictionary.
    public var addedWords: Int
    /// Meanings that crossed the 85% mastery threshold.
    public var masteredMeanings: Int
    /// Days with at least one answer, reading or finished set.
    public var activeDays: Int
    /// Finished readings.
    public var readings: Int
    /// Finished grammar / idiom / mixed and production sets.
    public var practiceSets: Int
    /// XP earned (difference of the XP total at the period's end and start).
    public var xp: Int

    public init(answers: Int = 0, correct: Int = 0, studySeconds: Int = 0, newMeanings: Int = 0, addedWords: Int = 0,
                masteredMeanings: Int = 0, activeDays: Int = 0, readings: Int = 0, practiceSets: Int = 0, xp: Int = 0) {
        self.answers = answers
        self.correct = correct
        self.studySeconds = studySeconds
        self.newMeanings = newMeanings
        self.addedWords = addedWords
        self.masteredMeanings = masteredMeanings
        self.activeDays = activeDays
        self.readings = readings
        self.practiceSets = practiceSets
        self.xp = xp
    }

    public static let empty = WeeklyPeriodStats()

    /// Accuracy in percent, `nil` without answers.
    public var accuracy: Int? {
        guard answers > 0 else { return nil }
        return jsRoundInt(Double(correct) / Double(answers) * 100)
    }

    /// Rounded minutes (at least 1 when there was any activity).
    public var studyMinutes: Int {
        guard studySeconds > 0 else { return 0 }
        return max(1, (studySeconds + 30) / 60)
    }

    public var hasActivity: Bool {
        answers > 0 || readings > 0 || practiceSets > 0
    }
}

/// The weekly report (I3): one calendar week (Monday–Sunday in the user's time zone) compared with
/// the week before. Pure value, computed by `WeeklyReportBuilder.report` off the main thread.
public struct WeeklyReport: Sendable, Hashable {
    /// 0 = the current week, 1 = last week, …
    public var weekOffset: Int
    /// Monday 00:00 of the week (local).
    public var start: Date
    /// Monday 00:00 of the next week (exclusive).
    public var end: Date
    /// `true` when the week is still in progress.
    public var isCurrentWeek: Bool
    /// Days of the week up to and including today (7 for finished weeks).
    public var elapsedDays: Int
    public var current: WeeklyPeriodStats
    public var previous: WeeklyPeriodStats
    /// Answers per day, Monday first (7 entries).
    public var days: [DayActivity]
    /// Streak of study days at the end of the week (today for the current week).
    public var streak: Int
    /// XP level at the start and at the end of the week.
    public var levelStart: XPLevel
    public var levelEnd: XPLevel
    /// The five mastery skills, in `Skill.masterySkills` order.
    public var skills: [WeeklySkillTrend]
    /// Words with the most mistakes this week, worst first.
    public var hardestWords: [WeeklyHardWord]
    /// Short, honest Polish summary.
    public var summaryPl: String

    public init(weekOffset: Int, start: Date, end: Date, isCurrentWeek: Bool, elapsedDays: Int, current: WeeklyPeriodStats,
                previous: WeeklyPeriodStats, days: [DayActivity], streak: Int, levelStart: XPLevel, levelEnd: XPLevel,
                skills: [WeeklySkillTrend], hardestWords: [WeeklyHardWord], summaryPl: String) {
        self.weekOffset = weekOffset
        self.start = start
        self.end = end
        self.isCurrentWeek = isCurrentWeek
        self.elapsedDays = elapsedDays
        self.current = current
        self.previous = previous
        self.days = days
        self.streak = streak
        self.levelStart = levelStart
        self.levelEnd = levelEnd
        self.skills = skills
        self.hardestWords = hardestWords
        self.summaryPl = summaryPl
    }

    public var levelsGained: Int { max(0, levelEnd.level - levelStart.level) }

    /// Start of the week's last day (Sunday).
    public var lastDay: Date { days.last?.date ?? start }

    /// The best and the weakest skill practiced this week (at least `WeeklyReportBuilder.minimumSkillAnswers` answers).
    public var strongestSkill: WeeklySkillTrend? {
        rankedSkills.first
    }

    public var weakestSkill: WeeklySkillTrend? {
        let ranked = rankedSkills
        guard ranked.count >= 2 else { return nil }
        return ranked.last
    }

    private var rankedSkills: [WeeklySkillTrend] {
        skills
            .filter { $0.answers >= WeeklyReportBuilder.minimumSkillAnswers && $0.accuracy != nil }
            .stableSorted { (lhs: WeeklySkillTrend, rhs: WeeklySkillTrend) -> Bool in
                (lhs.accuracy ?? 0) > (rhs.accuracy ?? 0)
            }
    }
}

/// Builds `WeeklyReport`s. Days follow the injected `calendar` (time zone of the user, never UTC);
/// weeks always start on Monday (Polish convention), regardless of `calendar.firstWeekday`.
///
/// Study time is an estimate: every vocabulary exercise answer counts its measured duration capped
/// at `answerSecondsCap` (`defaultAnswerSeconds` when unknown), a finished reading
/// `readingBaseSeconds` + `readingSecondsPerQuestion` per question, a grammar / production set
/// `practiceSecondsPerItem` per item. Reading questions are not counted twice.
///
/// XP of a week = XP total of the history before the week's end minus before its start
/// (`Progression` counts days in UTC, so a bonus earned around midnight may land in the
/// neighbouring week — a deliberate, small approximation).
public enum WeeklyReportBuilder {
    /// How many weeks back the report can go (older answers are compacted after 90 days).
    public static let maxWeeksBack = 12
    public static let hardWordLimit = 5
    public static let trendThreshold = 5
    /// Fewer answers than this in either week → the trend is `.steady` (not enough data).
    public static let minimumSkillAnswers = 5
    public static let answerSecondsCap: Double = 90
    public static let defaultAnswerSeconds: Double = 8
    public static let readingBaseSeconds = 120
    public static let readingSecondsPerQuestion = 30
    public static let practiceSecondsPerItem = 25

    // MARK: Calendar

    /// Monday 00:00 of the week containing `date`.
    public static func weekStart(containing date: Date, calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)  // 1 = Sunday … 7 = Saturday
        let sinceMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -sinceMonday, to: day) ?? day
    }

    /// Which week the Today card shows: the current week on Sunday, last week on Monday,
    /// `nil` on other days.
    public static func todayCardWeekOffset(now: Timestamp, calendar: Calendar = .current) -> Int? {
        let weekday = calendar.component(.weekday, from: Date(timestamp: now))
        switch weekday {
        case 1: return 0
        case 2: return 1
        default: return nil
        }
    }

    /// Number of weeks with any history, counting back from the current one (at least 1,
    /// at most `maxWeeksBack`) — the range of the week picker.
    public static func availableWeeks(_ state: LearnerState, now: Timestamp, calendar: Calendar = .current) -> Int {
        guard let earliest = earliestActivity(state) else { return 1 }
        let currentStart = weekStart(containing: Date(timestamp: now), calendar: calendar)
        let firstStart = weekStart(containing: Date(timestamp: earliest), calendar: calendar)
        let days = calendar.dateComponents([.day], from: firstStart, to: currentStart).day ?? 0
        let weeks = days / 7 + 1
        return min(maxWeeksBack, max(1, weeks))
    }

    // MARK: Report

    public static func report(_ state: LearnerState, weekOffset: Int = 0, now: Timestamp, calendar: Calendar = .current) -> WeeklyReport {
        let offset = min(max(0, weekOffset), maxWeeksBack - 1)
        let nowDate = Date(timestamp: now)
        let currentStart = weekStart(containing: nowDate, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -7 * offset, to: currentStart) ?? currentStart
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86_400)
        let previousStart = calendar.date(byAdding: .day, value: -7, to: start) ?? start.addingTimeInterval(-7 * 86_400)
        let isCurrent = offset == 0

        let context = Context(state)
        let days = dayActivity(context, start: start, calendar: calendar)
        var current = period(context, state: state, from: start.timestamp, to: end.timestamp, calendar: calendar)
        var previous = period(context, state: state, from: previousStart.timestamp, to: start.timestamp, calendar: calendar)

        let xpBeforePrevious = xpTotal(state, before: previousStart.timestamp)
        let xpBeforeStart = xpTotal(state, before: start.timestamp)
        let xpBeforeEnd = xpTotal(state, before: end.timestamp)
        current.xp = max(0, xpBeforeEnd - xpBeforeStart)
        previous.xp = max(0, xpBeforeStart - xpBeforePrevious)

        let elapsed: Int
        if isCurrent {
            let today = calendar.startOfDay(for: nowDate)
            let passed = calendar.dateComponents([.day], from: start, to: today).day ?? 0
            elapsed = min(7, max(1, passed + 1))
        } else {
            elapsed = 7
        }
        let streakEnd = isCurrent ? now : end.timestamp - 1
        let skills = skillTrends(context, current: (start.timestamp, end.timestamp), previous: (previousStart.timestamp, start.timestamp))
        let hard = hardestWords(context, state: state, from: start.timestamp, to: end.timestamp)

        var report = WeeklyReport(
            weekOffset: offset,
            start: start,
            end: end,
            isCurrentWeek: isCurrent,
            elapsedDays: elapsed,
            current: current,
            previous: previous,
            days: days,
            streak: ProgressStatistics.streak(state, now: streakEnd, calendar: calendar),
            levelStart: Progression.level(forXP: xpBeforeStart),
            levelEnd: Progression.level(forXP: xpBeforeEnd),
            skills: skills,
            hardestWords: hard,
            summaryPl: ""
        )
        report.summaryPl = WeeklyReportText.summary(report)
        return report
    }

    // MARK: Implementation

    /// Data derived once per report.
    private struct Context {
        /// Non-demo reviews with finite times.
        let reviews: [Review]
        /// First (non-demo) answer of every meaning.
        let firstAnswer: [String: Timestamp]
        /// Meanings whose score counters exceed their stored reviews — older answers were
        /// compacted, so their first remaining review is not really the first one.
        let compacted: Set<String>
        /// Meanings of non-archived words.
        let activeMeanings: Set<String>

        init(_ state: LearnerState) {
            let real = state.reviews.filter { !$0.demo && $0.at.isFinite }
            var first: [String: Timestamp] = [:]
            for review in real {
                if let existing = first[review.meaningId], existing <= review.at { continue }
                first[review.meaningId] = review.at
            }
            reviews = real
            firstAnswer = first
            var stored: [String: Int] = [:]
            for review in state.reviews {
                stored[review.meaningId, default: 0] += 1
            }
            var compactedSet = Set<String>()
            var active = Set<String>()
            for word in state.words {
                for meaning in word.meanings {
                    if !word.archived { active.insert(meaning.id) }
                    let counted = meaning.scores.values.reduce(0) { $0 + max(0, $1.correct) + max(0, $1.wrong) }
                    if counted > (stored[meaning.id] ?? 0) { compactedSet.insert(meaning.id) }
                }
            }
            compacted = compactedSet
            activeMeanings = active
        }
    }

    private static func dayActivity(_ context: Context, start: Date, calendar: Calendar) -> [DayActivity] {
        var dates: [Date] = []
        for offset in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: offset, to: start) { dates.append(date) }
        }
        var counts: [Date: (count: Int, correct: Int)] = [:]
        let set = Set(dates)
        for review in context.reviews {
            let day = calendar.startOfDay(for: Date(timestamp: review.at))
            guard set.contains(day) else { continue }
            var value = counts[day] ?? (count: 0, correct: 0)
            value.count += 1
            if review.correct && !review.hint { value.correct += 1 }
            counts[day] = value
        }
        return dates.map { (date: Date) -> DayActivity in
            let value = counts[date] ?? (count: 0, correct: 0)
            return DayActivity(date: date, count: value.count, correct: value.correct)
        }
    }

    private static func period(_ context: Context, state: LearnerState, from start: Timestamp, to end: Timestamp, calendar: Calendar) -> WeeklyPeriodStats {
        var stats = WeeklyPeriodStats()
        var activeDays = Set<Date>()
        var seconds: Double = 0
        for review in context.reviews where review.at >= start && review.at < end {
            stats.answers += 1
            if review.correct && !review.hint { stats.correct += 1 }
            activeDays.insert(calendar.startOfDay(for: Date(timestamp: review.at)))
            if review.source == .exercise {
                let measured = review.seconds.isFinite && review.seconds > 0 ? review.seconds : defaultAnswerSeconds
                seconds += min(answerSecondsCap, measured)
            }
        }
        for entry in state.readingHistory where entry.at.isFinite && entry.at >= start && entry.at < end {
            stats.readings += 1
            seconds += Double(readingBaseSeconds + readingSecondsPerQuestion * max(0, entry.total))
            activeDays.insert(calendar.startOfDay(for: Date(timestamp: entry.at)))
        }
        for entry in state.practiceHistory where entry.at.isFinite && entry.at >= start && entry.at < end {
            stats.practiceSets += 1
            seconds += Double(practiceSecondsPerItem * max(0, entry.total))
            activeDays.insert(calendar.startOfDay(for: Date(timestamp: entry.at)))
        }
        for entry in state.productionHistory where entry.at.isFinite && entry.at >= start && entry.at < end {
            stats.practiceSets += 1
            seconds += Double(practiceSecondsPerItem * max(0, entry.total))
            activeDays.insert(calendar.startOfDay(for: Date(timestamp: entry.at)))
        }
        stats.studySeconds = seconds.isFinite ? Int(seconds.rounded()) : 0
        stats.activeDays = activeDays.count
        var started = 0
        for (meaningID, first) in context.firstAnswer where first >= start && first < end {
            if context.activeMeanings.contains(meaningID) && !context.compacted.contains(meaningID) {
                started += 1
            }
        }
        stats.newMeanings = started
        stats.addedWords = state.words.filter { !$0.archived && $0.created >= start && $0.created < end }.count
        // `masteryGains` uses (start, end]; shift by 1 ms to get [start, end).
        stats.masteredMeanings = ProgressStatistics.masteryGains(state, from: start - 1, to: end - 1)
        return stats
    }

    /// XP total of the history strictly before `cutoff`.
    static func xpTotal(_ state: LearnerState, before cutoff: Timestamp) -> Int {
        var past = state
        past.reviews = state.reviews.filter { $0.at < cutoff }
        past.reviewSummaries = state.reviewSummaries.filter { (summary: ReviewSummary) -> Bool in
            guard let day = Progression.dayNumber(utcDay: summary.day) else { return false }
            return Double(day) * TimeConstants.dayMs < cutoff
        }
        past.readingHistory = state.readingHistory.filter { $0.at < cutoff }
        past.practiceHistory = state.practiceHistory.filter { $0.at < cutoff }
        past.productionHistory = state.productionHistory.filter { $0.at < cutoff }
        return Progression.totalXP(past)
    }

    private static func skillTrends(_ context: Context, current: (Timestamp, Timestamp), previous: (Timestamp, Timestamp)) -> [WeeklySkillTrend] {
        var now: [Skill: (answers: Int, correct: Int)] = [:]
        var before: [Skill: (answers: Int, correct: Int)] = [:]
        for review in context.reviews {
            let independent = review.correct && !review.hint
            if review.at >= current.0 && review.at < current.1 {
                var value = now[review.skill] ?? (answers: 0, correct: 0)
                value.answers += 1
                if independent { value.correct += 1 }
                now[review.skill] = value
            } else if review.at >= previous.0 && review.at < previous.1 {
                var value = before[review.skill] ?? (answers: 0, correct: 0)
                value.answers += 1
                if independent { value.correct += 1 }
                before[review.skill] = value
            }
        }
        return Skill.masterySkills.map { (skill: Skill) -> WeeklySkillTrend in
            let a = now[skill] ?? (answers: 0, correct: 0)
            let b = before[skill] ?? (answers: 0, correct: 0)
            let accuracy: Int? = a.answers > 0 ? jsRoundInt(Double(a.correct) / Double(a.answers) * 100) : nil
            let previousAccuracy: Int? = b.answers > 0 ? jsRoundInt(Double(b.correct) / Double(b.answers) * 100) : nil
            return WeeklySkillTrend(
                skill: skill,
                answers: a.answers,
                accuracy: accuracy,
                previousAnswers: b.answers,
                previousAccuracy: previousAccuracy,
                trend: trend(answers: a.answers, accuracy: accuracy, previousAnswers: b.answers, previousAccuracy: previousAccuracy)
            )
        }
    }

    static func trend(answers: Int, accuracy: Int?, previousAnswers: Int, previousAccuracy: Int?) -> WeeklyTrend {
        guard answers > 0, let accuracy else { return .none }
        guard previousAnswers > 0, let previousAccuracy else { return .new }
        guard answers >= minimumSkillAnswers, previousAnswers >= minimumSkillAnswers else { return .steady }
        let change = accuracy - previousAccuracy
        if change >= trendThreshold { return .up }
        if change <= -trendThreshold { return .down }
        return .steady
    }

    private static func hardestWords(_ context: Context, state: LearnerState, from start: Timestamp, to end: Timestamp) -> [WeeklyHardWord] {
        var tally: [String: (mistakes: Int, answers: Int)] = [:]
        for review in context.reviews where review.at >= start && review.at < end {
            var value = tally[review.wordId] ?? (mistakes: 0, answers: 0)
            value.answers += 1
            if !review.correct || review.hint { value.mistakes += 1 }
            tally[review.wordId] = value
        }
        var rows: [WeeklyHardWord] = []
        for word in state.words where !word.archived {
            guard let value = tally[word.id], value.mistakes > 0 else { continue }
            rows.append(WeeklyHardWord(
                wordId: word.id,
                term: word.en,
                translation: word.meanings.map { $0.translation }.filter { !$0.isEmpty }.joined(separator: " · "),
                mistakes: value.mistakes,
                answers: value.answers,
                mastery: Mastery.of(word)
            ))
        }
        let sorted = rows.sorted { (lhs: WeeklyHardWord, rhs: WeeklyHardWord) -> Bool in
            if lhs.mistakes != rhs.mistakes { return lhs.mistakes > rhs.mistakes }
            let lhsRate = Double(lhs.mistakes) / Double(max(1, lhs.answers))
            let rhsRate = Double(rhs.mistakes) / Double(max(1, rhs.answers))
            if lhsRate != rhsRate { return lhsRate > rhsRate }
            if lhs.term != rhs.term { return lhs.term < rhs.term }
            return lhs.wordId < rhs.wordId
        }
        return Array(sorted.prefix(hardWordLimit))
    }

    private static func earliestActivity(_ state: LearnerState) -> Timestamp? {
        var earliest: Timestamp?
        func consider(_ value: Timestamp) {
            guard value.isFinite, value > 0 else { return }
            if let current = earliest, current <= value { return }
            earliest = value
        }
        for review in state.reviews where !review.demo { consider(review.at) }
        for entry in state.readingHistory { consider(entry.at) }
        for entry in state.practiceHistory { consider(entry.at) }
        for entry in state.productionHistory { consider(entry.at) }
        return earliest
    }
}

/// Polish texts of the weekly report. Present tense and nouns only (no gendered past forms).
public enum WeeklyReportText {
    public static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        ProgressionText.plural(count, one: one, few: few, many: many)
    }

    public static func answers(_ count: Int) -> String {
        "\(count) " + plural(count, one: "odpowiedź", few: "odpowiedzi", many: "odpowiedzi")
    }

    public static func days(_ count: Int) -> String {
        "\(count) " + plural(count, one: "dzień", few: "dni", many: "dni")
    }

    public static func meanings(_ count: Int) -> String {
        "\(count) " + plural(count, one: "znaczenie", few: "znaczenia", many: "znaczeń")
    }

    public static func minutes(_ count: Int) -> String {
        "\(count) min"
    }

    /// Two to four short sentences: what happened, the comparison, one highlight, one tip.
    public static func summary(_ report: WeeklyReport) -> String {
        let current = report.current
        let previous = report.previous
        guard current.hasActivity else {
            if report.isCurrentWeek {
                return previous.hasActivity
                    ? "W tym tygodniu jeszcze nie było nauki. Krótka sesja dziś pomoże utrzymać rytm z poprzedniego tygodnia."
                    : "W tym tygodniu jeszcze nie było nauki. Wystarczy 5 minut dziennie, żeby słowa zostały w pamięci."
            }
            return "W tym tygodniu nie było nauki. Nic straconego — jedna krótka sesja wystarczy, żeby wrócić do rytmu."
        }
        var sentences: [String] = []
        sentences.append(opening(report))
        if let comparison = comparison(report) { sentences.append(comparison) }
        if let highlight = highlight(report) { sentences.append(highlight) }
        if let tip = tip(report) { sentences.append(tip) }
        return sentences.joined(separator: " ")
    }

    private static func opening(_ report: WeeklyReport) -> String {
        let current = report.current
        let dayPart = "\(days(current.activeDays)) nauki z \(report.elapsedDays)"
        var text = "W tym tygodniu: \(dayPart)"
        if current.answers > 0 {
            text += ", \(answers(current.answers))"
            if let accuracy = current.accuracy { text += " i \(accuracy)% poprawnych" }
        }
        if current.studyMinutes > 0 { text += " (ok. \(minutes(current.studyMinutes)))" }
        return text + "."
    }

    private static func comparison(_ report: WeeklyReport) -> String? {
        let current = report.current
        let previous = report.previous
        guard previous.hasActivity else {
            return "Dobry start — tydzień wcześniej nie było nauki."
        }
        let difference = current.answers - previous.answers
        if difference > 0 {
            return "To o \(answers(difference)) więcej niż tydzień wcześniej."
        }
        if difference < 0 {
            if report.isCurrentWeek { return "Tydzień jeszcze trwa — do wyniku z poprzedniego brakuje \(answers(-difference))." }
            if current.activeDays >= previous.activeDays {
                return "Mniej odpowiedzi niż tydzień wcześniej, ale tyle samo lub więcej dni nauki — regularność się liczy."
            }
            return "Trochę mniej niż tydzień wcześniej. Krótkie, codzienne sesje pomogą wrócić do formy."
        }
        return "Tyle samo odpowiedzi co tydzień wcześniej — równe tempo."
    }

    private static func highlight(_ report: WeeklyReport) -> String? {
        let current = report.current
        if current.masteredMeanings > 0 {
            return "Nowo opanowane znaczenia: \(current.masteredMeanings)."
        }
        if report.levelsGained > 0 {
            return "Awans na poziom \(report.levelEnd.level)."
        }
        if let best = report.strongestSkill, let accuracy = best.accuracy, accuracy >= 80 {
            return "Najlepiej idzie Ci \(best.skill.namePl.lowercased()) (\(accuracy)%)."
        }
        if current.newMeanings > 0 {
            return "Nowe znaczenia w nauce: \(current.newMeanings)."
        }
        return nil
    }

    private static func tip(_ report: WeeklyReport) -> String? {
        if let first = report.hardestWords.first, first.mistakes >= 2 {
            return "Najwięcej trudności sprawia „\(first.term)” — warto je powtórzyć w trybie pomyłek."
        }
        if let weak = report.weakestSkill, let accuracy = weak.accuracy, accuracy < 70 {
            return "Warto popracować nad umiejętnością „\(weak.skill.namePl)” (\(accuracy)%)."
        }
        return nil
    }
}
