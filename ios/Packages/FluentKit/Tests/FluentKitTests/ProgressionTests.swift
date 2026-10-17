import XCTest
@testable import FluentKit

final class ProgressionTests: XCTestCase {
    // MARK: Helpers

    private func review(_ id: String, word: String = "w1", skill: Skill = .recall, correct: Bool = true, hint: Bool = false, error: String = "", at: Timestamp = testNow, source: ReviewSource = .exercise, demo: Bool = false) -> Review {
        Review(
            id: id,
            wordId: word,
            meaningId: "m-\(word)",
            skill: skill,
            correct: correct,
            at: at,
            seconds: 5,
            confidence: 2,
            hint: hint,
            error: error,
            before: 0,
            after: 10,
            source: source,
            demo: demo
        )
    }

    private func state(_ reviews: [Review], goal: Int = 20) -> LearnerState {
        LearnerState(reviews: reviews, settings: LearnerSettings(goal: goal))
    }

    /// Typical learner (same scenario as the Node port in the report): 26 answers a day (~12 min),
    /// 6 days a week, ~18% wrong, some hints and spelling slips, 16 words a day (a failed word
    /// comes back), a reading every 3rd day, a grammar set every 4th day.
    static func simulatedState(days: Int, answersPerDay: Int = 26) -> LearnerState {
        var reviews: [Review] = []
        var readings: [ReadingHistoryEntry] = []
        var practice: [PracticeHistoryEntry] = []
        for d in 0..<days where d % 7 != 6 {
            let start = testNow + Double(d) * day - 2 * 3_600_000
            for i in 0..<answersPerDay {
                let bucket = i % 10
                let skill: Skill = bucket < 4 ? .recognition : (bucket < 6 ? .recall : (bucket < 8 ? .usage : .listening))
                let m = (i * 7 + d * 3) % 11
                let correct = !(m == 0 || m == 5)
                let hint = correct && (i + d) % 13 == 0
                let spelling = correct && !hint && (skill == .recall || skill == .listening) && (i + 2 * d) % 9 == 0
                reviews.append(Review(
                    id: "r-\(d)-\(i)",
                    wordId: "w-\(d)-\(i % 16)",
                    meaningId: "m-\(d)-\(i % 16)",
                    skill: skill,
                    correct: correct,
                    at: start + Double(i) * 30_000,
                    seconds: 8,
                    confidence: 2,
                    hint: hint,
                    error: spelling ? "Pisownia" : "",
                    before: 0,
                    after: 0
                ))
            }
            if d % 3 == 0 {
                readings.append(ReadingHistoryEntry(id: "read-\(d)", at: start + 3_600_000, level: "B1", correct: 4, total: 5))
            }
            if d % 4 == 1 {
                practice.append(PracticeHistoryEntry(id: "gram-\(d)", at: start + 7_200_000, kind: .grammar, level: "B1", correct: 6, total: 8, title: "Gramatyka"))
            }
        }
        return LearnerState(reviews: reviews, settings: LearnerSettings(goal: 20), readingHistory: readings, practiceHistory: practice)
    }

    // MARK: Answers

    func testAnswerXPDependsOnSkillHintAndSpelling() {
        XCTAssertEqual(XPRules.answerCentiXP(skill: .recognition, correct: true, hint: false, spellingMistake: false, repetition: 0), 400)
        XCTAssertEqual(XPRules.answerCentiXP(skill: .recall, correct: true, hint: false, spellingMistake: false, repetition: 0), 800)
        XCTAssertEqual(XPRules.answerCentiXP(skill: .recall, correct: true, hint: true, spellingMistake: false, repetition: 0), 400)
        XCTAssertEqual(XPRules.answerCentiXP(skill: .recall, correct: true, hint: false, spellingMistake: true, repetition: 0), 560)
        XCTAssertEqual(XPRules.answerCentiXP(skill: .recall, correct: false, hint: false, spellingMistake: false, repetition: 0), 0)
        XCTAssertGreaterThan(XPRules.baseXP(for: .listening), XPRules.baseXP(for: .recognition))
    }

    func testRepeatingTheSameWordOnTheSameDayEarnsLess() {
        let reviews = (0..<6).map { review("r\($0)", word: "w1", at: testNow + Double($0) * 1_000) }
        let ledger = Progression.ledger(state(reviews, goal: 100))
        // 8 · (100 + 60 + 35 + 20 + 10 + 10)% = 18.8 → 19
        XCTAssertEqual(ledger.days.first?.vocabulary, 19)
        // Next day the same word is worth the full amount again.
        let nextDay = reviews + [review("r-next", word: "w1", at: testNow + day)]
        let days = Progression.ledger(state(nextDay, goal: 100)).days
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days.last?.vocabulary, 8)
    }

    func testDemoAndReadingReviewsEarnNoAnswerXP() {
        let reviews = [
            review("demo", demo: true),
            review("reading", word: "w2", source: .reading)
        ]
        let ledger = Progression.ledger(state(reviews))
        XCTAssertEqual(ledger.days.count, 1)
        XCTAssertEqual(ledger.days.first?.vocabulary, 0)
        // The reading answer still counts as activity (answers), the demo one does not.
        XCTAssertEqual(ledger.days.first?.answers, 1)
    }

    func testDailyGoalAndStreakBonuses() {
        var reviews: [Review] = []
        for d in 0..<3 {
            for i in 0..<5 {
                reviews.append(review("r\(d)-\(i)", word: "w\(i)", skill: .recognition, at: testNow + Double(d) * day + Double(i) * 1_000))
            }
        }
        let days = Progression.ledger(state(reviews, goal: 5)).days
        XCTAssertEqual(days.map { $0.dailyGoal }, [20, 20, 20])
        XCTAssertEqual(days.map { $0.streak }, [0, 3, 6])
        // Goal not reached → no goal bonus.
        let short = Progression.ledger(state(Array(reviews.prefix(4)), goal: 5)).days
        XCTAssertEqual(short.first?.dailyGoal, 0)
        // A gap resets the streak.
        let gap = reviews.filter { !$0.id.hasPrefix("r1-") }
        XCTAssertEqual(Progression.ledger(state(gap, goal: 5)).days.map { $0.streak }, [0, 0])
    }

    func testGoalBonusThresholdIsCappedSoHighGoalsDoNotRemoveXP() {
        let reviews = (0..<20).map { review("r\($0)", word: "w\($0)", skill: .recognition, at: testNow + Double($0) * 1_000) }
        XCTAssertEqual(Progression.ledger(state(reviews, goal: 20)).days.first?.dailyGoal, 20)
        XCTAssertEqual(Progression.ledger(state(reviews, goal: 50)).days.first?.dailyGoal, 20)
    }

    func testSetsAndCompactedHistory() {
        var learner = LearnerState(settings: LearnerSettings(goal: 100))
        learner.readingHistory = [ReadingHistoryEntry(id: "r", at: testNow, level: "B1", correct: 4, total: 5)]
        learner.practiceHistory = [
            PracticeHistoryEntry(id: "p", at: testNow, kind: .grammar, level: "B1", correct: 6, total: 8, title: "G"),
            PracticeHistoryEntry(id: "small", at: testNow, kind: .idioms, level: "B1", correct: 2, total: 2, title: "Mix")
        ]
        learner.productionHistory = [ProductionHistoryEntry(id: "pr", at: testNow, level: "B1", correct: 5, total: 6, title: "P")]
        learner.reviewSummaries = [ReviewSummary(day: "2026-01-10", count: 30, correct: 25)]
        let ledger = Progression.ledger(learner)
        XCTAssertEqual(ledger.total(from: .reading), 4 * 3 + 10)
        XCTAssertEqual(ledger.total(from: .practice), 6 * 3 + 8 + 2 * 3)
        XCTAssertEqual(ledger.total(from: .production), 5 * 5 + 8)
        XCTAssertEqual(ledger.total(from: .history), 25 * XPRules.compactedXPPerCorrect)
        XCTAssertEqual(Progression.dayNumber(utcDay: "2026-01-10"), Progression.dayNumber(1_768_003_200_000))
        XCTAssertEqual(Progression.dayNumber(utcDay: "1970-01-01"), 0)
        XCTAssertNil(Progression.dayNumber(utcDay: "2026-13-01"))
    }

    // MARK: Determinism / sync

    func testLedgerIsIndependentOfOrderAndMergeDirection() {
        let full = ProgressionTests.simulatedState(days: 20)
        var shuffled = full
        var rng = SeededGenerator(seed: 7)
        shuffled.reviews.shuffle(using: &rng)
        shuffled.readingHistory.reverse()
        XCTAssertEqual(Progression.totalXP(full), Progression.totalXP(shuffled))

        // Two devices with different halves of the history: merged in either direction → same XP.
        var a = full
        var b = full
        a.reviews = full.reviews.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
        b.reviews = full.reviews.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element }
        a.readingHistory = []
        let ab = StateSync.mergeStates(local: a, remote: b)
        let ba = StateSync.mergeStates(local: b, remote: a)
        XCTAssertEqual(Progression.totalXP(ab), Progression.totalXP(full))
        XCTAssertEqual(Progression.totalXP(ba), Progression.totalXP(full))
    }

    func testSessionGainCountsOnlyTheSessionAndDetectsLevelUp() {
        let earlier = (0..<10).map { review("old\($0)", word: "o\($0)", at: testNow - day + Double($0) * 1_000) }
        let session = (0..<10).map { review("new\($0)", word: "n\($0)", at: testNow + Double($0) * 1_000) }
        let learner = state(earlier + session, goal: 10)
        let gain = Progression.sessionGain(learner, reviewIDs: session.map { $0.id })
        // 10 × 8 XP + goal bonus 20 + streak (day 2) 3.
        XCTAssertEqual(gain.xp, 103)
        XCTAssertEqual(gain.levelAfter, Progression.level(forXP: Progression.totalXP(learner)).level)
        XCTAssertTrue(gain.leveledUp)

        var combined = learner
        combined.practiceHistory = [PracticeHistoryEntry(id: "abc:grammar", at: testNow, kind: .grammar, level: "B1", correct: 3, total: 4, title: "Sesja łączona")]
        let combinedGain = Progression.sessionGain(combined, reviewIDs: [], historyIDPrefix: "abc:")
        XCTAssertEqual(combinedGain.xp, 9)
    }

    // MARK: Levels

    func testLevelCurveGrowsAndRanksChangeEveryFiveLevels() {
        XCTAssertEqual(Progression.threshold(forLevel: 1), 0)
        XCTAssertEqual(Progression.threshold(forLevel: 2), 120)
        var previousStep = 0
        for level in 2...40 {
            let step = Progression.threshold(forLevel: level + 1) - Progression.threshold(forLevel: level)
            XCTAssertGreaterThan(step, previousStep, "poziom \(level)")
            previousStep = step
        }
        let start = Progression.level(forXP: 0)
        XCTAssertEqual(start.level, 1)
        XCTAssertEqual(start.rank, .firstSteps)
        let mid = Progression.level(forXP: Progression.threshold(forLevel: 7) + 10)
        XCTAssertEqual(mid.level, 7)
        XCTAssertEqual(mid.xpIntoLevel, 10)
        XCTAssertEqual(mid.rank, .explorer)
        XCTAssertEqual(XPRank.rank(forLevel: 10), .traveler)
        XCTAssertEqual(XPRank.rank(forLevel: 39), .master)
        XCTAssertEqual(XPRank.rank(forLevel: 41), .legend)
        let top = Progression.level(forXP: Int.max / 4)
        XCTAssertEqual(top.level, XPRules.maxLevel)
        XCTAssertEqual(top.fraction, 1)
    }

    func testSummaryTodayWeekAndMeaning() {
        let learner = ProgressionTests.simulatedState(days: 14)
        let now = testNow + 12 * day
        let summary = Progression.summary(learner, now: now)
        XCTAssertEqual(summary.recentDays.count, 14)
        XCTAssertEqual(summary.recentDays.last?.day, Progression.dayNumber(now))
        XCTAssertEqual(summary.todayXP, Progression.ledger(learner).xp(onDay: Progression.dayNumber(now)))
        XCTAssertGreaterThan(summary.weekXP, summary.todayXP)
        XCTAssertEqual(summary.studyDays, 12)
        XCTAssertEqual(summary.sources.first?.source, .vocabulary)
        XCTAssertTrue(summary.meaningPl.contains("12 dni nauki"))
        XCTAssertEqual(ProgressionSummary.empty.level.level, 1)
    }

    // MARK: Balance simulation (results in docs/reports/onboarding-progress.md)

    func testBalanceSimulationThirtyAndNinetyDays() {
        let week = Progression.totalXP(ProgressionTests.simulatedState(days: 7))
        let month = Progression.totalXP(ProgressionTests.simulatedState(days: 30))
        let quarter = Progression.totalXP(ProgressionTests.simulatedState(days: 90))
        let monthLevel = Progression.level(forXP: month).level
        let quarterLevel = Progression.level(forXP: quarter).level
        print("XP symulacja: 7 dni \(week) XP (poziom \(Progression.level(forXP: week).level)), 30 dni \(month) XP (poziom \(monthLevel)), 90 dni \(quarter) XP (poziom \(quarterLevel))")
        // Exact values of the Node port (integer arithmetic → identical).
        XCTAssertEqual(week, 882)
        XCTAssertEqual(month, 3712)
        XCTAssertEqual(quarter, 11163)
        XCTAssertEqual(monthLevel, 8)
        XCTAssertEqual(quarterLevel, 14)

        // Level-up pace: first levels within days, later about one a week or slower.
        let ledger = Progression.ledger(ProgressionTests.simulatedState(days: 90))
        var cumulative = 0
        var levelDays: [Int: Int] = [:]
        var current = 1
        let firstDay = ledger.days.first?.day ?? 0
        for item in ledger.days {
            cumulative += item.total
            let reached = Progression.level(forXP: cumulative).level
            if reached > current {
                current = reached
                levelDays[reached] = item.day - firstDay + 1
            }
        }
        XCTAssertLessThanOrEqual(levelDays[2] ?? 99, 2)
        XCTAssertLessThanOrEqual(levelDays[5] ?? 99, 14)
        let late = (levelDays[14] ?? 0) - (levelDays[13] ?? 0)
        let early = (levelDays[4] ?? 0) - (levelDays[3] ?? 0)
        XCTAssertGreaterThan(late, early)
    }

    func testFarmingTheSameWordsIsNotWorthIt() {
        var reviews: [Review] = []
        for i in 0..<200 {
            reviews.append(review("f\(i)", word: "w\(i % 10)", skill: .recognition, at: testNow + Double(i) * 10_000))
        }
        let farm = Progression.ledger(state(reviews)).total
        let typical = Progression.totalXP(ProgressionTests.simulatedState(days: 1))
        XCTAssertLessThan(Double(farm) / 200, Double(typical) / 26 / 4)
        XCTAssertLessThan(farm, typical * 2)
    }

    func testPerformanceOfNinetyDays() {
        let learner = ProgressionTests.simulatedState(days: 90, answersPerDay: 120)
        let start = Date()
        _ = Progression.summary(learner, now: testNow + 90 * day)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }
}
