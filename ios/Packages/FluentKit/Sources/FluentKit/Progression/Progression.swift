import Foundation

/// Where XP comes from.
public enum XPSource: String, CaseIterable, Sendable, Hashable, Identifiable {
    case vocabulary
    case reading
    case practice
    case production
    case dailyGoal
    case streak
    /// Older days kept only as per-day summaries.
    case history

    public var id: String { rawValue }

    public var namePl: String {
        switch self {
        case .vocabulary: return "Ćwiczenia słówek"
        case .reading: return "Czytanie"
        case .practice: return "Gramatyka i idiomy"
        case .production: return "Pisanie form"
        case .dailyGoal: return "Dzienny cel"
        case .streak: return "Seria dni"
        case .history: return "Starsza historia"
        }
    }

    public var systemImage: String {
        switch self {
        case .vocabulary: return "character.book.closed"
        case .reading: return "book"
        case .practice: return "text.badge.checkmark"
        case .production: return "pencil"
        case .dailyGoal: return "target"
        case .streak: return "flame"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

/// XP earned on one UTC day.
public struct XPDay: Sendable, Hashable, Identifiable {
    /// Days since 1970-01-01 (UTC).
    public var day: Int
    public var vocabulary: Int
    public var reading: Int
    public var practice: Int
    public var production: Int
    public var dailyGoal: Int
    public var streak: Int
    public var history: Int
    /// Answers on that day (exercises and reading questions, also compacted ones).
    public var answers: Int

    public init(day: Int, vocabulary: Int = 0, reading: Int = 0, practice: Int = 0, production: Int = 0, dailyGoal: Int = 0, streak: Int = 0, history: Int = 0, answers: Int = 0) {
        self.day = day
        self.vocabulary = vocabulary
        self.reading = reading
        self.practice = practice
        self.production = production
        self.dailyGoal = dailyGoal
        self.streak = streak
        self.history = history
        self.answers = answers
    }

    public var id: Int { day }

    public var total: Int {
        vocabulary + reading + practice + production + dailyGoal + streak + history
    }

    /// Midnight UTC of the day.
    public var date: Date {
        Date(timeIntervalSince1970: Double(day) * 86_400)
    }

    public func xp(from source: XPSource) -> Int {
        switch source {
        case .vocabulary: return vocabulary
        case .reading: return reading
        case .practice: return practice
        case .production: return production
        case .dailyGoal: return dailyGoal
        case .streak: return streak
        case .history: return history
        }
    }
}

/// All XP, day by day — computed from history, never stored (no sync conflicts, nothing to lose).
public struct XPLedger: Sendable, Hashable {
    /// Active days, oldest first.
    public var days: [XPDay]

    public init(days: [XPDay] = []) {
        self.days = days
    }

    public var total: Int {
        days.reduce(0) { $0 + $1.total }
    }

    public func total(from source: XPSource) -> Int {
        days.reduce(0) { $0 + $1.xp(from: source) }
    }

    /// XP of one UTC day (0 when inactive).
    public func xp(onDay day: Int) -> Int {
        days.first { $0.day == day }?.total ?? 0
    }

    /// XP of the last `count` days ending at `day` (inclusive).
    public func xp(lastDays count: Int, endingAt day: Int) -> Int {
        let start = day - max(1, count) + 1
        return days.filter { $0.day >= start && $0.day <= day }.reduce(0) { $0 + $1.total }
    }
}

/// Rank names, one per 5 levels (then wider).
public enum XPRank: Int, CaseIterable, Sendable, Hashable {
    case firstSteps = 1
    case explorer = 5
    case traveler = 10
    case conversationalist = 15
    case connoisseur = 20
    case scholar = 25
    case master = 30
    case legend = 40

    /// First level of the rank.
    public var firstLevel: Int { rawValue }

    public var namePl: String {
        switch self {
        case .firstSteps: return "Pierwsze kroki"
        case .explorer: return "Odkrywca"
        case .traveler: return "Podróżnik"
        case .conversationalist: return "Rozmówca"
        case .connoisseur: return "Znawca"
        case .scholar: return "Erudyta"
        case .master: return "Mistrz"
        case .legend: return "Legenda"
        }
    }

    public var descriptionPl: String {
        switch self {
        case .firstSteps: return "Budujesz nawyk i pierwsze słownictwo."
        case .explorer: return "Codzienne słowa przestają być obce."
        case .traveler: return "Radzisz sobie w coraz większej liczbie sytuacji."
        case .conversationalist: return "Twoje słownictwo pozwala na swobodniejsze rozmowy."
        case .connoisseur: return "Regularna nauka to już Twój rytm."
        case .scholar: return "Szeroki zasób słów i mnóstwo ćwiczeń za Tobą."
        case .master: return "Należysz do najwytrwalszych uczniów."
        case .legend: return "Angielski to Twoja codzienność."
        }
    }

    public var systemImage: String {
        switch self {
        case .firstSteps: return "figure.walk"
        case .explorer: return "binoculars"
        case .traveler: return "map"
        case .conversationalist: return "bubble.left.and.bubble.right"
        case .connoisseur: return "star"
        case .scholar: return "books.vertical"
        case .master: return "crown"
        case .legend: return "sparkles"
        }
    }

    public static func rank(forLevel level: Int) -> XPRank {
        var result: XPRank = .firstSteps
        for rank in allCases where level >= rank.firstLevel {
            result = rank
        }
        return result
    }

    /// The next rank, `nil` for the last one.
    public var next: XPRank? {
        let ranks = XPRank.allCases
        guard let index = ranks.firstIndex(of: self), index + 1 < ranks.count else { return nil }
        return ranks[index + 1]
    }
}

/// Level for an amount of XP.
public struct XPLevel: Sendable, Hashable {
    public var level: Int
    public var totalXP: Int
    /// XP at which this level started / the next one starts.
    public var levelStartXP: Int
    public var nextLevelXP: Int

    public init(level: Int, totalXP: Int, levelStartXP: Int, nextLevelXP: Int) {
        self.level = level
        self.totalXP = totalXP
        self.levelStartXP = levelStartXP
        self.nextLevelXP = nextLevelXP
    }

    public var isMaxLevel: Bool { level >= XPRules.maxLevel }
    public var xpIntoLevel: Int { max(0, totalXP - levelStartXP) }
    public var xpForLevel: Int { max(1, nextLevelXP - levelStartXP) }
    public var xpToNextLevel: Int { isMaxLevel ? 0 : max(0, nextLevelXP - totalXP) }

    /// Progress within the level, 0…1.
    public var fraction: Double {
        guard !isMaxLevel else { return 1 }
        return min(1, max(0, Double(xpIntoLevel) / Double(xpForLevel)))
    }

    public var rank: XPRank { XPRank.rank(forLevel: level) }
}

/// XP of one finished session.
public struct XPSessionGain: Sendable, Hashable {
    public var xp: Int
    public var levelBefore: Int
    public var levelAfter: Int

    public init(xp: Int, levelBefore: Int, levelAfter: Int) {
        self.xp = xp
        self.levelBefore = levelBefore
        self.levelAfter = levelAfter
    }

    public var leveledUp: Bool { levelAfter > levelBefore }
}

/// XP total by source.
public struct XPSourceTotal: Sendable, Hashable, Identifiable {
    public var source: XPSource
    public var xp: Int

    public init(source: XPSource, xp: Int) {
        self.source = source
        self.xp = xp
    }

    public var id: XPSource { source }
}

/// Everything the Today / Progress screens show about XP.
public struct ProgressionSummary: Sendable, Hashable {
    public var level: XPLevel
    public var todayXP: Int
    public var weekXP: Int
    /// The last 14 days, oldest first (inactive days with 0 XP).
    public var recentDays: [XPDay]
    /// Non-zero sources, largest first.
    public var sources: [XPSourceTotal]
    public var masteredMeanings: Int
    public var studyDays: Int

    public init(level: XPLevel, todayXP: Int, weekXP: Int, recentDays: [XPDay], sources: [XPSourceTotal], masteredMeanings: Int, studyDays: Int) {
        self.level = level
        self.todayXP = todayXP
        self.weekXP = weekXP
        self.recentDays = recentDays
        self.sources = sources
        self.masteredMeanings = masteredMeanings
        self.studyDays = studyDays
    }

    public static let empty = ProgressionSummary(
        level: Progression.level(forXP: 0),
        todayXP: 0,
        weekXP: 0,
        recentDays: [],
        sources: [],
        masteredMeanings: 0,
        studyDays: 0
    )

    /// „Masz 42 opanowane znaczenia i 18 dni nauki.”
    public var meaningPl: String {
        let mastered = ProgressionText.plural(masteredMeanings, one: "opanowane znaczenie", few: "opanowane znaczenia", many: "opanowanych znaczeń")
        let days = ProgressionText.plural(studyDays, one: "dzień nauki", few: "dni nauki", many: "dni nauki")
        return "Masz \(masteredMeanings) \(mastered) i \(studyDays) \(days)."
    }
}

/// XP and levels (G5), computed deterministically from the history: vocabulary `reviews`,
/// compacted `reviewSummaries`, and reading / practice / production histories. No counter is
/// stored, so iCloud merges cannot conflict and nothing can be lost. Days are UTC days (the same
/// keys as `reviewSummaries`), so every device computes the same total.
public enum Progression {
    /// Days since 1970-01-01 in UTC.
    public static func dayNumber(_ timestamp: Timestamp) -> Int {
        let days = (timestamp / TimeConstants.dayMs).rounded(.down)
        guard days.isFinite, abs(days) < 1_000_000_000 else { return 0 }
        return Int(days)
    }

    /// Day number of a `yyyy-MM-dd` summary key, `nil` when malformed.
    public static func dayNumber(utcDay text: String) -> Int? {
        let parts = text.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let dayOfMonth = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(dayOfMonth) else { return nil }
        return daysFromCivil(year: year, month: month, day: dayOfMonth)
    }

    /// Days from 1970-01-01 of a proleptic Gregorian date (H. Hinnant's algorithm).
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400
        let shiftedMonth = (month + 9) % 12
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }

    // MARK: Ledger

    private struct DayTotals {
        var vocabularyCenti = 0
        var reading = 0
        var practice = 0
        var production = 0
        var history = 0
        var answers = 0
        var readingSets = 0
        var practiceSets = 0
        var productionSets = 0
    }

    /// XP of every active day.
    public static func ledger(_ state: LearnerState) -> XPLedger {
        var totals: [Int: DayTotals] = [:]
        addReviews(state.reviews, to: &totals)
        addSummaries(state.reviewSummaries, to: &totals)
        addReadings(state.readingHistory, to: &totals)
        addPractice(state.practiceHistory, to: &totals)
        addProduction(state.productionHistory, to: &totals)

        let goalThreshold = XPRules.goalThreshold(goal: state.settings.goal)
        var days: [XPDay] = []
        var streak = 0
        var previous: Int?
        for day in totals.keys.sorted() {
            guard let value = totals[day] else { continue }
            streak = previous == day - 1 ? streak + 1 : 1
            previous = day
            days.append(XPDay(
                day: day,
                vocabulary: (value.vocabularyCenti + 50) / 100,
                reading: value.reading,
                practice: value.practice,
                production: value.production,
                dailyGoal: value.answers >= goalThreshold ? XPRules.goalBonusXP : 0,
                streak: XPRules.streakBonus(length: streak),
                history: value.history,
                answers: value.answers
            ))
        }
        return XPLedger(days: days)
    }

    private static func addReviews(_ reviews: [Review], to totals: inout [Int: DayTotals]) {
        let ordered = reviews
            .filter { !$0.demo && $0.at.isFinite }
            .sorted { (lhs: Review, rhs: Review) -> Bool in
                lhs.at != rhs.at ? lhs.at < rhs.at : lhs.id < rhs.id
            }
        var repetitions: [String: Int] = [:]
        for review in ordered {
            let day = dayNumber(review.at)
            totals[day, default: DayTotals()].answers += 1
            // Reading questions are rewarded with the reading itself.
            guard review.source == .exercise else { continue }
            let key = "\(day)|\(review.wordId)"
            let repetition = repetitions[key] ?? 0
            repetitions[key] = repetition + 1
            totals[day, default: DayTotals()].vocabularyCenti += XPRules.answerCentiXP(
                skill: review.skill,
                correct: review.correct,
                hint: review.hint,
                spellingMistake: review.error == XPRules.spellingErrorLabel,
                repetition: repetition
            )
        }
    }

    private static func addSummaries(_ summaries: [ReviewSummary], to totals: inout [Int: DayTotals]) {
        for summary in summaries {
            guard let day = dayNumber(utcDay: summary.day), summary.count > 0 else { continue }
            let correct = min(max(0, summary.correct), summary.count)
            totals[day, default: DayTotals()].answers += summary.count
            totals[day, default: DayTotals()].history += correct * XPRules.compactedXPPerCorrect
        }
    }

    private static func addReadings(_ entries: [ReadingHistoryEntry], to totals: inout [Int: DayTotals]) {
        let ordered = entries.sorted { (lhs: ReadingHistoryEntry, rhs: ReadingHistoryEntry) -> Bool in
            lhs.at != rhs.at ? lhs.at < rhs.at : lhs.id < rhs.id
        }
        for entry in ordered where entry.at.isFinite && entry.at > 0 {
            let day = dayNumber(entry.at)
            var value = totals[day] ?? DayTotals()
            if value.readingSets < XPRules.maxRewardedSetsPerDay {
                let correct = min(max(0, entry.correct), max(0, entry.total))
                value.reading += correct * XPRules.readingXPPerCorrect
                    + (entry.total > 0 ? XPRules.readingCompletionXP : 0)
            }
            value.readingSets += 1
            totals[day] = value
        }
    }

    private static func addPractice(_ entries: [PracticeHistoryEntry], to totals: inout [Int: DayTotals]) {
        let ordered = entries.sorted { (lhs: PracticeHistoryEntry, rhs: PracticeHistoryEntry) -> Bool in
            lhs.at != rhs.at ? lhs.at < rhs.at : lhs.id < rhs.id
        }
        for entry in ordered where entry.at.isFinite && entry.at > 0 {
            let day = dayNumber(entry.at)
            var value = totals[day] ?? DayTotals()
            if value.practiceSets < XPRules.maxRewardedSetsPerDay {
                let correct = min(max(0, entry.correct), max(0, entry.total))
                value.practice += correct * XPRules.practiceXPPerCorrect
                    + (entry.total >= XPRules.setMinimumItems ? XPRules.practiceCompletionXP : 0)
            }
            value.practiceSets += 1
            totals[day] = value
        }
    }

    private static func addProduction(_ entries: [ProductionHistoryEntry], to totals: inout [Int: DayTotals]) {
        let ordered = entries.sorted { (lhs: ProductionHistoryEntry, rhs: ProductionHistoryEntry) -> Bool in
            lhs.at != rhs.at ? lhs.at < rhs.at : lhs.id < rhs.id
        }
        for entry in ordered where entry.at.isFinite && entry.at > 0 {
            let day = dayNumber(entry.at)
            var value = totals[day] ?? DayTotals()
            if value.productionSets < XPRules.maxRewardedSetsPerDay {
                let correct = min(max(0, entry.correct), max(0, entry.total))
                value.production += correct * XPRules.productionXPPerCorrect
                    + (entry.total >= XPRules.productionMinimumItems ? XPRules.productionCompletionXP : 0)
            }
            value.productionSets += 1
            totals[day] = value
        }
    }

    // MARK: Totals and levels

    public static func totalXP(_ state: LearnerState) -> Int {
        ledger(state).total
    }

    /// Total XP needed to reach `level` (level 1 = 0).
    public static func threshold(forLevel level: Int) -> Int {
        XPRules.threshold(forLevel: level)
    }

    public static func level(forXP xp: Int) -> XPLevel {
        let total = max(0, xp)
        var level = 1
        while level < XPRules.maxLevel && XPRules.threshold(forLevel: level + 1) <= total {
            level += 1
        }
        let start = XPRules.threshold(forLevel: level)
        let next = level < XPRules.maxLevel ? XPRules.threshold(forLevel: level + 1) : start
        return XPLevel(level: level, totalXP: total, levelStartXP: start, nextLevelXP: next)
    }

    public static func level(_ state: LearnerState) -> XPLevel {
        level(forXP: totalXP(state))
    }

    /// XP earned by a session: the total with the session's answers minus the total without them
    /// (so repetition discounts and the daily goal bonus are counted exactly). `historyIDPrefix`
    /// also removes history entries written by that session (combined sessions use
    /// `"<session id>:"`).
    public static func sessionGain(_ state: LearnerState, reviewIDs: [String], historyIDPrefix: String? = nil) -> XPSessionGain {
        let after = totalXP(state)
        var before = state
        let removed = Set(reviewIDs)
        before.reviews = state.reviews.filter { !removed.contains($0.id) }
        if let prefix = historyIDPrefix, !prefix.isEmpty {
            before.practiceHistory = state.practiceHistory.filter { !$0.id.hasPrefix(prefix) }
            before.productionHistory = state.productionHistory.filter { !$0.id.hasPrefix(prefix) }
        }
        let previous = totalXP(before)
        return XPSessionGain(
            xp: max(0, after - previous),
            levelBefore: level(forXP: previous).level,
            levelAfter: level(forXP: after).level
        )
    }

    /// Summary for Today and Progress.
    public static func summary(_ state: LearnerState, now: Timestamp) -> ProgressionSummary {
        let book: XPLedger = ledger(state)
        let today = dayNumber(now)
        var byDay: [Int: XPDay] = [:]
        for item in book.days { byDay[item.day] = item }
        let recent = (0..<14).map { (offset: Int) -> XPDay in
            let day = today - 13 + offset
            return byDay[day] ?? XPDay(day: day)
        }
        let sources = XPSource.allCases
            .map { (source: XPSource) -> XPSourceTotal in XPSourceTotal(source: source, xp: book.total(from: source)) }
            .filter { $0.xp > 0 }
            .sorted { (lhs: XPSourceTotal, rhs: XPSourceTotal) -> Bool in lhs.xp > rhs.xp }
        let mastered = masteredMeanings(state)
        return ProgressionSummary(
            level: level(forXP: book.total),
            todayXP: book.xp(onDay: today),
            weekXP: book.xp(lastDays: 7, endingAt: today),
            recentDays: recent,
            sources: sources,
            masteredMeanings: mastered,
            studyDays: book.days.count
        )
    }

    /// Non-archived meanings with mastery ≥ `Mastery.masteredThreshold`.
    public static func masteredMeanings(_ state: LearnerState) -> Int {
        var count = 0
        for word in state.words where !word.archived {
            for meaning in word.meanings where Mastery.of(meaning) >= Mastery.masteredThreshold {
                count += 1
            }
        }
        return count
    }
}

/// Polish plural forms (1 / 2–4 / 5+).
enum ProgressionText {
    static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let value = abs(count)
        if value == 1 { return one }
        let lastTwo = value % 100
        let last = value % 10
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return few }
        return many
    }
}
