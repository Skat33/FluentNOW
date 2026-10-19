import Foundation

/// Numbers the profile badges are computed from (all derived from the history — nothing stored).
public struct AchievementInput: Sendable, Hashable {
    public var wordCount: Int
    public var masteredMeanings: Int
    /// Longest run of consecutive active UTC days.
    public var longestStreak: Int
    public var level: Int
    public var readingsCompleted: Int

    public init(wordCount: Int = 0, masteredMeanings: Int = 0, longestStreak: Int = 0, level: Int = 1, readingsCompleted: Int = 0) {
        self.wordCount = wordCount
        self.masteredMeanings = masteredMeanings
        self.longestStreak = longestStreak
        self.level = level
        self.readingsCompleted = readingsCompleted
    }
}

/// One badge in the profile panel.
public struct ProfileAchievement: Sendable, Hashable, Identifiable {
    public var id: String
    public var titlePl: String
    public var detailPl: String
    public var systemImage: String
    public var current: Int
    public var target: Int

    public init(id: String, titlePl: String, detailPl: String, systemImage: String, current: Int, target: Int) {
        self.id = id
        self.titlePl = titlePl
        self.detailPl = detailPl
        self.systemImage = systemImage
        self.current = current
        self.target = target
    }

    public var isEarned: Bool { current >= target }

    /// 0…1.
    public var progress: Double {
        guard target > 0 else { return 1 }
        return min(1, max(0, Double(current) / Double(target)))
    }
}

/// Badges for milestones (FEEDBACK-5 J3, optional): computed from the history, so they cannot be
/// lost or conflict between devices. Earned badges stay earned (longest streak, not the current one).
public enum ProfileAchievements {
    private enum Metric: Sendable {
        case words, streak, mastered, readings, level
    }

    private struct Definition: Sendable {
        let id: String
        let title: String
        let detail: String
        let image: String
        let target: Int
        let metric: Metric
    }

    private static let definitions: [Definition] = [
        Definition(id: "first-word", title: "Pierwsze słowo", detail: "Dodaj pierwsze słowo", image: "text.badge.plus", target: 1, metric: .words),
        Definition(id: "words-100", title: "Setka", detail: "100 słów w słowniku", image: "books.vertical.fill", target: 100, metric: .words),
        Definition(id: "words-500", title: "Bogaty słownik", detail: "500 słów w słowniku", image: "building.columns.fill", target: 500, metric: .words),
        Definition(id: "streak-7", title: "Tydzień z rzędu", detail: "7 dni nauki bez przerwy", image: "flame.fill", target: 7, metric: .streak),
        Definition(id: "streak-30", title: "Miesiąc z rzędu", detail: "30 dni nauki bez przerwy", image: "calendar.badge.checkmark", target: 30, metric: .streak),
        Definition(id: "mastered-50", title: "Opanowane 50", detail: "50 opanowanych znaczeń", image: "checkmark.seal.fill", target: 50, metric: .mastered),
        Definition(id: "mastered-250", title: "Opanowane 250", detail: "250 opanowanych znaczeń", image: "rosette", target: 250, metric: .mastered),
        Definition(id: "reader-10", title: "Czytelnik", detail: "10 ukończonych czytanek", image: "book.pages.fill", target: 10, metric: .readings),
        Definition(id: "level-10", title: "Poziom 10", detail: "Zdobądź poziom 10", image: "star.circle.fill", target: 10, metric: .level)
    ]

    private static func value(_ metric: Metric, in input: AchievementInput) -> Int {
        switch metric {
        case .words: return input.wordCount
        case .streak: return input.longestStreak
        case .mastered: return input.masteredMeanings
        case .readings: return input.readingsCompleted
        case .level: return input.level
        }
    }

    /// All badges in a fixed order (earned and not yet earned, with progress).
    public static func evaluate(_ input: AchievementInput) -> [ProfileAchievement] {
        definitions.map { (definition: Definition) -> ProfileAchievement in
            ProfileAchievement(
                id: definition.id,
                titlePl: definition.title,
                detailPl: definition.detail,
                systemImage: definition.image,
                current: max(0, value(definition.metric, in: input)),
                target: definition.target
            )
        }
    }

    /// Input computed from the state (one pass over the XP ledger).
    public static func input(from state: LearnerState) -> AchievementInput {
        let ledger = Progression.ledger(state)
        let activeDays = ledger.days
            .filter { (day: XPDay) -> Bool in day.answers > 0 || day.total > 0 }
            .map { (day: XPDay) -> Int in day.day }
        return AchievementInput(
            wordCount: state.words.filter { !$0.archived }.count,
            masteredMeanings: Progression.masteredMeanings(state),
            longestStreak: longestStreak(days: activeDays),
            level: Progression.level(forXP: ledger.total).level,
            readingsCompleted: state.readingHistory.count
        )
    }

    /// Longest run of consecutive day numbers (order and duplicates do not matter).
    public static func longestStreak(days: [Int]) -> Int {
        let sorted = Array(Set(days)).sorted()
        guard var previous = sorted.first else { return 0 }
        var best = 1
        var run = 1
        for day in sorted.dropFirst() {
            run = day == previous + 1 ? run + 1 : 1
            best = max(best, run)
            previous = day
        }
        return best
    }
}
