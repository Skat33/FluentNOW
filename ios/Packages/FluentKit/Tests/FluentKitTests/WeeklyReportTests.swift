import XCTest
@testable import FluentKit

/// I3 — weekly report. `testNow` = Tuesday 2026-09-01 12:00 UTC (14:00 in Warsaw), so the current
/// week starts on Monday 2026-08-31 00:00 Warsaw time = 2026-08-30 22:00 UTC.
final class WeeklyReportTests: XCTestCase {
    private let hour: Double = 3_600_000

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? TimeZone(secondsFromGMT: 7200) ?? .current
        // Sunday-first on purpose: the report must still start weeks on Monday.
        calendar.firstWeekday = 1
        return calendar
    }

    private var monday: Timestamp { testNow - 38 * hour }

    private func review(_ id: String, at: Timestamp, word: String = "w1", meaning: String = "m-w1", skill: Skill = .recall,
                        correct: Bool = true, hint: Bool = false, seconds: Double = 5, demo: Bool = false,
                        before: Int = 0, after: Int = 10, source: ReviewSource = .exercise) -> Review {
        Review(id: id, wordId: word, meaningId: meaning, skill: skill, correct: correct, at: at, seconds: seconds,
               confidence: 3, hint: hint, before: before, after: after, source: source, demo: demo)
    }

    private func state(words: [String] = ["w1", "w2", "w3"]) -> LearnerState {
        var state = TestData.emptyState()
        state.words = words.map { TestData.freshWord($0, "term-\($0)", "tłumaczenie \($0)") }
        return state
    }

    func testWeekStartsOnMondayInLocalTime() {
        let start = WeeklyReportBuilder.weekStart(containing: Date(timestamp: testNow), calendar: calendar)
        XCTAssertEqual(start.timestamp, monday, accuracy: 1)
        // Sunday 2026-09-06 18:00 Warsaw belongs to the same week.
        let sunday = Date(timestamp: monday + 6 * day + 18 * hour)
        XCTAssertEqual(WeeklyReportBuilder.weekStart(containing: sunday, calendar: calendar).timestamp, monday, accuracy: 1)
        let report = WeeklyReportBuilder.report(state(), now: testNow, calendar: calendar)
        XCTAssertEqual(report.days.count, 7)
        XCTAssertEqual(report.start.timestamp, monday, accuracy: 1)
        XCTAssertEqual(report.end.timestamp, monday + 7 * day, accuracy: 1)
        XCTAssertTrue(report.isCurrentWeek)
        XCTAssertEqual(report.elapsedDays, 2, "Monday and Tuesday")
    }

    func testDaysFollowUserCalendarNotUTC() {
        var learner = state()
        // Both answers are on 2026-08-30 in UTC, but on different local days (and weeks) in Warsaw.
        learner.reviews = [
            review("late-sunday", at: monday - 0.5 * hour),
            review("early-monday", at: monday + 0.5 * hour)
        ]
        let report = WeeklyReportBuilder.report(learner, now: testNow, calendar: calendar)
        XCTAssertEqual(report.current.answers, 1)
        XCTAssertEqual(report.previous.answers, 1)
        XCTAssertEqual(report.days.first?.count, 1)
        XCTAssertEqual(report.current.activeDays, 1)
    }

    func testCountsAccuracyTimeAndDemo() {
        var learner = state()
        learner.reviews = [
            review("a", at: monday + 10 * hour, seconds: 6),
            review("b", at: monday + 11 * hour, correct: false, seconds: 4),
            review("c", at: monday + 30 * hour, hint: true, seconds: 500),
            review("d", at: monday + 31 * hour, demo: true),
            review("e", at: monday + 32 * hour, seconds: 7, source: .reading)
        ]
        learner.readingHistory = [ReadingHistoryEntry(id: "r1", at: monday + 33 * hour, level: "A2", correct: 3, total: 4)]
        learner.practiceHistory = [PracticeHistoryEntry(id: "p1", at: monday + 34 * hour, kind: .grammar, level: "A2", correct: 4, total: 6, title: "Czasy")]
        let report = WeeklyReportBuilder.report(learner, now: testNow, calendar: calendar)
        XCTAssertEqual(report.current.answers, 4, "demo answers are excluded")
        XCTAssertEqual(report.current.correct, 2, "hinted answers are not independent")
        XCTAssertEqual(report.current.accuracy, 50)
        XCTAssertEqual(report.current.readings, 1)
        XCTAssertEqual(report.current.practiceSets, 1)
        // 6 + 4 + 90 (capped) exercise seconds; reading answer not counted twice; reading 120 + 4·30; practice 6·25.
        XCTAssertEqual(report.current.studySeconds, 6 + 4 + 90 + 240 + 150)
        XCTAssertEqual(report.current.studyMinutes, 8)
        XCTAssertEqual(report.current.activeDays, 2)
        XCTAssertTrue(report.current.hasActivity)
        XCTAssertFalse(report.previous.hasActivity)
        XCTAssertNil(report.previous.accuracy)
    }

    func testNewMeaningsAddedWordsAndMastery() {
        var learner = state()
        learner.words[0].created = monday + hour
        learner.words[1].created = monday - 3 * day
        // w1: first answer this week → new. w2: answered last week → not new.
        // w3: scores say 5 answers but only one review is stored → older history was compacted → not new.
        learner.words[2].meanings[0].scores[.recall] = Score(value: 30, interval: 2, due: testNow, correct: 4, wrong: 1, last: testNow)
        learner.reviews = [
            review("a", at: monday + hour, word: "w1", meaning: "m-w1", before: 80, after: 86),
            review("b", at: monday - 2 * day, word: "w2", meaning: "m-w2"),
            review("c", at: monday + 2 * hour, word: "w2", meaning: "m-w2"),
            review("d", at: monday + 3 * hour, word: "w3", meaning: "m-w3")
        ]
        let report = WeeklyReportBuilder.report(learner, now: testNow, calendar: calendar)
        XCTAssertEqual(report.current.newMeanings, 1)
        XCTAssertEqual(report.previous.newMeanings, 1)
        XCTAssertEqual(report.current.addedWords, 1)
        XCTAssertEqual(report.previous.addedWords, 1)
        XCTAssertEqual(report.current.masteredMeanings, 1)
    }

    func testHardestWordsAndSkillTrends() {
        var learner = state()
        learner.words[2].archived = true
        var reviews: [Review] = []
        for index in 0..<3 {
            reviews.append(review("w2-\(index)", at: monday + Double(index + 1) * hour, word: "w2", meaning: "m-w2", correct: false))
        }
        reviews.append(review("w1-0", at: monday + 5 * hour, word: "w1", meaning: "m-w1", correct: false))
        reviews.append(review("w1-1", at: monday + 6 * hour, word: "w1", meaning: "m-w1"))
        reviews.append(review("w3-0", at: monday + 7 * hour, word: "w3", meaning: "m-w3", correct: false))
        // Recognition: 6/6 this week vs 3/6 last week → up.
        for index in 0..<6 {
            reviews.append(review("rec-now-\(index)", at: monday + 8 * hour + Double(index), skill: .recognition))
            reviews.append(review("rec-old-\(index)", at: monday - 3 * day + Double(index), skill: .recognition, correct: index < 3))
        }
        learner.reviews = reviews
        let report = WeeklyReportBuilder.report(learner, now: testNow, calendar: calendar)
        XCTAssertEqual(report.hardestWords.map { $0.wordId }, ["w2", "w1"], "archived words are skipped, most mistakes first")
        XCTAssertEqual(report.hardestWords.first?.mistakes, 3)
        XCTAssertEqual(report.hardestWords.first?.translation, "tłumaczenie w2")
        let recognition = report.skills.first { $0.skill == .recognition }
        XCTAssertEqual(recognition?.trend, .up)
        XCTAssertEqual(recognition?.change, 50)
        XCTAssertEqual(report.skills.first { $0.skill == .recall }?.trend, .new)
        XCTAssertEqual(report.skills.first { $0.skill == .spelling }?.trend, WeeklyTrend.none)
        XCTAssertEqual(report.skills.map { $0.skill }, Skill.masterySkills)
        XCTAssertEqual(report.strongestSkill?.skill, .recognition)
        XCTAssertTrue(report.summaryPl.contains("term-w2"), report.summaryPl)
    }

    func testTrendNeedsEnoughAnswers() {
        XCTAssertEqual(WeeklyReportBuilder.trend(answers: 2, accuracy: 100, previousAnswers: 2, previousAccuracy: 0), .steady)
        XCTAssertEqual(WeeklyReportBuilder.trend(answers: 10, accuracy: 60, previousAnswers: 10, previousAccuracy: 80), .down)
        XCTAssertEqual(WeeklyReportBuilder.trend(answers: 10, accuracy: 78, previousAnswers: 10, previousAccuracy: 80), .steady)
    }

    func testPastWeekStreakXPAndOffsets() {
        var learner = state()
        // Last week: Friday, Saturday, Sunday (local) → streak 3 at the end of that week.
        learner.reviews = [
            review("fri", at: monday - 3 * day + 10 * hour),
            review("sat", at: monday - 2 * day + 10 * hour),
            review("sun", at: monday - day + 10 * hour)
        ]
        let last = WeeklyReportBuilder.report(learner, weekOffset: 1, now: testNow, calendar: calendar)
        XCTAssertFalse(last.isCurrentWeek)
        XCTAssertEqual(last.elapsedDays, 7)
        XCTAssertEqual(last.current.answers, 3)
        XCTAssertEqual(last.streak, 3)
        XCTAssertGreaterThan(last.current.xp, 0)
        XCTAssertGreaterThanOrEqual(last.levelEnd.level, last.levelStart.level)
        let current = WeeklyReportBuilder.report(learner, now: testNow, calendar: calendar)
        XCTAssertEqual(current.current.xp, 0)
        XCTAssertEqual(current.previous.xp, last.current.xp)
        XCTAssertEqual(current.streak, 0, "Monday without answers ended the streak (today may still be empty)")
        XCTAssertEqual(WeeklyReportBuilder.availableWeeks(learner, now: testNow, calendar: calendar), 2)
        XCTAssertEqual(WeeklyReportBuilder.availableWeeks(state(), now: testNow, calendar: calendar), 1)
        let far = WeeklyReportBuilder.report(learner, weekOffset: 99, now: testNow, calendar: calendar)
        XCTAssertEqual(far.weekOffset, WeeklyReportBuilder.maxWeeksBack - 1)
    }

    func testTodayCardDays() {
        let sunday = monday + 6 * day + 12 * hour
        XCTAssertEqual(WeeklyReportBuilder.todayCardWeekOffset(now: sunday, calendar: calendar), 0)
        XCTAssertEqual(WeeklyReportBuilder.todayCardWeekOffset(now: monday + 12 * hour, calendar: calendar), 1)
        XCTAssertNil(WeeklyReportBuilder.todayCardWeekOffset(now: testNow, calendar: calendar))
    }

    func testSummaryTexts() {
        let empty = WeeklyReportBuilder.report(state(), now: testNow, calendar: calendar)
        XCTAssertFalse(empty.current.hasActivity)
        XCTAssertTrue(empty.summaryPl.hasPrefix("W tym tygodniu jeszcze nie było nauki"), empty.summaryPl)
        var learner = state()
        learner.reviews = [review("a", at: monday + hour), review("b", at: monday - 2 * day), review("c", at: monday - 2 * day + 1)]
        let report = WeeklyReportBuilder.report(learner, now: testNow, calendar: calendar)
        XCTAssertTrue(report.summaryPl.contains("1 dzień nauki z 2"), report.summaryPl)
        XCTAssertTrue(report.summaryPl.contains("Tydzień jeszcze trwa"), report.summaryPl)
        XCTAssertEqual(WeeklyReportText.answers(1), "1 odpowiedź")
        XCTAssertEqual(WeeklyReportText.answers(22), "22 odpowiedzi")
        XCTAssertEqual(WeeklyReportText.days(5), "5 dni")
    }
}
