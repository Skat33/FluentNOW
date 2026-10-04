import XCTest
@testable import FluentKit

final class StatisticsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? TimeZone(secondsFromGMT: 7200) ?? .current
        return calendar
    }

    private func review(_ id: String, at: Timestamp, correct: Bool = true, hint: Bool = false, demo: Bool = false, before: Int = 0, after: Int = 10, version: Int? = 2, meaning: String = "m") -> Review {
        Review(id: id, wordId: "w", meaningId: meaning, skill: .recall, correct: correct, at: at, seconds: 3, confidence: 3, hint: hint, before: before, after: after, masteryVersion: version, demo: demo)
    }

    func testWeekAndCalendarExcludeDemo() {
        var state = TestData.seed()
        state.reviews += [review("a", at: testNow), review("b", at: testNow - day, correct: false), review("c", at: testNow - 3 * day)]
        let week = ProgressStatistics.week(state, now: testNow, calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.last?.count, 1)
        XCTAssertEqual(week.last?.correct, 1)
        XCTAssertEqual(week[5].count, 1)
        XCTAssertEqual(week[5].correct, 0)
        XCTAssertEqual(week.reduce(0) { $0 + $1.count }, 3)
        let grid = ProgressStatistics.activityCalendar(state, now: testNow, calendar: calendar)
        XCTAssertEqual(grid.count, 84)
        XCTAssertEqual(grid.reduce(0) { $0 + $1.count }, 3)
        XCTAssertTrue(ProgressStatistics.week(TestData.emptyState(), now: testNow, calendar: calendar).allSatisfy { $0.count == 0 })
    }

    func testStreakAndDailyGoal() {
        var state = TestData.emptyState()
        XCTAssertEqual(ProgressStatistics.streak(state, now: testNow, calendar: calendar), 0)
        state.reviews = [review("a", at: testNow - day), review("b", at: testNow - 2 * day), review("c", at: testNow - 4 * day)]
        XCTAssertEqual(ProgressStatistics.streak(state, now: testNow, calendar: calendar), 2, "today without answers does not break the streak")
        state.reviews.append(review("d", at: testNow))
        XCTAssertEqual(ProgressStatistics.streak(state, now: testNow, calendar: calendar), 3)
        state.settings.goal = 4
        let goal = ProgressStatistics.dailyGoal(state, now: testNow, calendar: calendar)
        XCTAssertEqual(goal.done, 1)
        XCTAssertEqual(goal.fraction, 0.25, accuracy: 1e-9)
        XCTAssertFalse(goal.isReached)
        XCTAssertEqual(DailyGoalProgress(done: 10, goal: 0).fraction, 1)
    }

    func testSkillAveragesAndLevels() {
        let state = TestData.seed()
        let skills = ProgressStatistics.skillAverages(state)
        XCTAssertEqual(skills.count, Skill.allCases.count)
        XCTAssertNil(skills.first { $0.skill == .usage }?.average)
        XCTAssertNotNil(skills.first { $0.skill == .recall }?.average)
        let levels = ProgressStatistics.levelProgress(state)
        XCTAssertEqual(levels.map { $0.level }, CEFR.levels)
        XCTAssertEqual(levels.reduce(0) { $0 + $1.meaningCount }, 19, "18 starter meanings + the second sense of bank")
        XCTAssertEqual(levels.first { $0.level == "C2" }?.meaningCount, 0)
        XCTAssertEqual(levels.first { $0.level == "C2" }?.average, 0)
    }

    func testForecastAndOverview() {
        var state = TestData.emptyState()
        var word = TestData.freshWord("a", "a", "a")
        word.meanings.append(Meaning(id: "m2", translation: "b", examples: ["b"]))
        word.meanings.append(Meaning(id: "m3", translation: "c", examples: ["c"]))
        word.meanings[0].scores[.recall] = Score(value: 10, interval: 1, due: testNow - day, correct: 1, last: 1)
        word.meanings[1].scores[.recall] = Score(value: 10, interval: 2, due: testNow + 2 * day, correct: 1, last: 1)
        state.words = [word]
        state.reviews = [review("a", at: testNow, correct: true), review("b", at: testNow, correct: true, hint: true)]
        state.reviewSummaries = [ReviewSummary(day: "2025-01-01", count: 2, correct: 1)]
        let forecast = ProgressStatistics.reviewForecast(state, now: testNow, calendar: calendar)
        XCTAssertEqual(forecast.count, 7)
        XCTAssertEqual(forecast[0].count, 1)
        XCTAssertEqual(forecast[2].count, 1)
        XCTAssertEqual(forecast.reduce(0) { $0 + $1.count }, 2, "new meanings are not forecast reviews")
        let overview = ProgressStatistics.overview(state, now: testNow, calendar: calendar)
        XCTAssertEqual(overview.wordCount, 1)
        XCTAssertEqual(overview.meaningCount, 3)
        XCTAssertEqual(overview.newMeanings, 1)
        XCTAssertEqual(overview.dueMeanings, 1)
        XCTAssertEqual(overview.totalAnswers, 4)
        XCTAssertEqual(overview.accuracy, 50)
        XCTAssertEqual(overview.streak, 1)
        XCTAssertEqual(overview.missingLevels, 0)
        XCTAssertEqual(ProgressStatistics.overview(TestData.emptyState(), now: testNow).accuracy, 0)
    }

    func testWeeklyMasteryGainsUseFiveSkillScaleOnly() {
        var state = TestData.emptyState()
        state.reviews = [
            review("a", at: testNow - day, before: 80, after: 86, meaning: "m1"),
            review("b", at: testNow - 2 * day, before: 70, after: 90, meaning: "m1"),
            review("c", at: testNow - day, before: 80, after: 86, version: nil, meaning: "m2"),
            review("d", at: testNow - 10 * day, before: 80, after: 86, meaning: "m3"),
            review("e", at: testNow - day, before: 86, after: 90, meaning: "m4")
        ]
        XCTAssertEqual(ProgressStatistics.masteryGains(state, from: testNow - 7 * day, to: testNow), 1)
        let weeks = ProgressStatistics.weeklyMasteryGains(state, weeks: 2, now: testNow)
        XCTAssertEqual(weeks.map { $0.count }, [1, 1])
    }

    func testHardWordsAndTotals() {
        var state = TestData.seed()
        state.readingHistory = [ReadingHistoryEntry(id: "r", at: 1, level: "A2", correct: 2, total: 3)]
        state.practiceHistory = [PracticeHistoryEntry(id: "p", at: 1, kind: .grammar, level: "B1", correct: 4, total: 6, title: "t")]
        state.productionHistory = [ProductionHistoryEntry(id: "q", at: 1, level: "B1", correct: 5, total: 6, title: "t")]
        let hard = ProgressStatistics.hardWords(state, now: testNow)
        XCTAssertLessThanOrEqual(hard.count, 5)
        XCTAssertTrue(hard.contains { $0.en == "borrow" })
        XCTAssertEqual(hard.map { $0.mastery }, hard.map { $0.mastery }.sorted())
        XCTAssertEqual(ProgressStatistics.readingTotals(state), ExerciseTotals(sets: 1, correct: 2, total: 3))
        XCTAssertEqual(ProgressStatistics.practiceTotals(state), ExerciseTotals(sets: 2, correct: 9, total: 12))
        let collection = ProgressStatistics.collectionProgress(state, collection: "W pracy")
        XCTAssertEqual(collection.meanings, 3)
        XCTAssertEqual(ProgressStatistics.collectionProgress(state, collection: "nope").meanings, 0)
    }
}
