import XCTest
@testable import FluentKit

final class LearnerAnalysisTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    /// recognition 91, recall/usage/listening 67, spelling 24 → mastery 63.
    private let mixedIntervals: [Skill: Double] = [.recognition: 60, .recall: 20, .usage: 20, .listening: 20, .spelling: 2]

    private func word(_ id: String, level: String = "B1", intervals: [Skill: Double], contentRef: String? = nil, collection: String = "Własne", archived: Bool = false) -> Word {
        var scores = SkillScores()
        for (skill, interval) in intervals {
            scores[skill] = Score(value: Mastery.fromInterval(interval), interval: interval, due: testNow + day, correct: 3, last: testNow - day)
        }
        return Word(
            id: id,
            en: "word \(id)",
            level: level,
            collection: collection,
            archived: archived,
            created: 1,
            meanings: [Meaning(id: "m-\(id)", translation: "tłumaczenie \(id)", examples: ["Example \(id)."], scores: scores, contentRef: contentRef)]
        )
    }

    private func review(_ id: String, meaning: String, at: Timestamp, skill: Skill = .recall, correct: Bool = true, before: Int = 0, demo: Bool = false) -> Review {
        Review(id: id, wordId: "w", meaningId: meaning, skill: skill, correct: correct, at: at, seconds: 4, confidence: 2, hint: false, before: before, after: before + 10, demo: demo)
    }

    /// 40 practiced B1 words and 160 correct recall answers over 10 days.
    private func experiencedState() -> LearnerState {
        var state = TestData.emptyState()
        state.words = (0..<40).map { word("w\($0)", intervals: mixedIntervals) }
        state.reviews = (0..<160).map { index in
            review("r\(index)", meaning: "m-w\(index % 40)", at: testNow - Double(index % 10) * day - Double(index) * 1000)
        }
        return state
    }

    // MARK: Level

    func testEmptyStateHasNoEstimate() {
        let analysis = LearnerAnalyzer.analyze(TestData.emptyState(), now: testNow, calendar: calendar)
        XCTAssertEqual(analysis.level.confidence, .insufficient)
        XCTAssertEqual(analysis.level.rangeText, "—")
        XCTAssertFalse(analysis.hasData)
        XCTAssertTrue(analysis.skills.isEmpty)
        XCTAssertTrue(analysis.untestedSkills.isEmpty)
        XCTAssertEqual(analysis.pace.regularity, .inactive)
        XCTAssertNil(analysis.skillsSummaryPl)
        XCTAssertTrue(analysis.pace.summaryPl.hasPrefix("Brak nauki"))
    }

    func testDemoHistoryGivesOnlyLowConfidence() {
        let state = TestData.seed()
        let assessment = LearnerAnalyzer.assessLevel(state)
        let estimate = LevelEstimator.estimatedLevel(state)
        XCTAssertEqual(assessment.level, estimate.level, "the level is exactly LevelEstimator's")
        XCTAssertEqual(assessment.totalAnswers, 0, "demo answers do not count")
        XCTAssertEqual(assessment.confidence, .low)
        let lower = CEFR.index(of: assessment.lowerLevel) ?? -1
        let upper = CEFR.index(of: assessment.upperLevel) ?? -1
        let level = CEFR.index(of: assessment.level) ?? -1
        XCTAssertTrue(lower <= level && level <= upper)
        XCTAssertFalse(assessment.descriptionPl.isEmpty)
    }

    func testOnlyDeclaredLevelsAreHonestlyDescribed() {
        var state = TestData.emptyState()
        state.words = [TestData.freshWord("a", "borrow", "pożyczyć")]
        let assessment = LearnerAnalyzer.assessLevel(state)
        XCTAssertEqual(assessment.confidence, .low)
        XCTAssertEqual(assessment.practicedMeanings, 0)
        XCTAssertTrue(assessment.descriptionPl.contains("bez Twoich wyników"))
        XCTAssertNotEqual(assessment.lowerLevel, assessment.upperLevel, "low confidence shows a range")
    }

    func testMediumAndHighConfidence() {
        var medium = TestData.emptyState()
        medium.words = (0..<15).map { word("w\($0)", intervals: mixedIntervals) }
        medium.reviews = (0..<60).map { review("r\($0)", meaning: "m-w\($0 % 15)", at: testNow - Double($0) * 60_000) }
        XCTAssertEqual(LearnerAnalyzer.assessLevel(medium).confidence, .medium)

        let high = LearnerAnalyzer.assessLevel(experiencedState())
        XCTAssertEqual(high.confidence, .high)
        XCTAssertEqual(high.level, "B1")
        XCTAssertEqual(high.rangeText, "B1")
        XCTAssertEqual(high.targetLevel, "B2")
        XCTAssertEqual(high.practicedMeanings, 40)
        XCTAssertEqual(high.totalAnswers, 160)
        XCTAssertTrue(high.descriptionPl.contains("40 znaczeń"))
    }

    // MARK: Skills

    func testStrongAndWeakSkills() {
        let analysis = LearnerAnalyzer.analyze(experiencedState(), now: testNow, calendar: calendar)
        XCTAssertEqual(analysis.skills.map { $0.skill }, Skill.masterySkills)
        XCTAssertEqual(analysis.skills.first { $0.skill == .recall }?.recentAccuracy, 100)
        XCTAssertNil(analysis.skills.first { $0.skill == .spelling }?.recentAccuracy, "too few answers for accuracy")
        XCTAssertEqual(analysis.strongSkills.map { $0.skill }, [.recognition, .recall])
        XCTAssertEqual(analysis.weakSkills.map { $0.skill }, [.spelling])
        XCTAssertEqual(analysis.skillsSummaryPl, "Mocna strona: Rozpoznawanie · Do poprawy: Pisownia")
    }

    func testSkillsNeedEnoughDataAndUntestedAreListed() {
        var state = TestData.emptyState()
        state.words = (0..<2).map { word("w\($0)", intervals: [.recognition: 10, .spelling: 1]) }
        XCTAssertTrue(LearnerAnalyzer.skillInsights(state, now: testNow).isEmpty, "2 meanings are not enough to compare")
        state.words = (0..<4).map { word("w\($0)", intervals: [.recognition: 10]) }
        let analysis = LearnerAnalyzer.analyze(state, now: testNow, calendar: calendar)
        XCTAssertEqual(analysis.skills.count, 1)
        XCTAssertTrue(analysis.strongSkills.isEmpty, "one skill cannot be compared")
        XCTAssertEqual(analysis.untestedSkills, [.recall, .usage, .listening, .spelling])
        XCTAssertEqual(analysis.skillsSummaryPl, "Jeszcze nie ćwiczone: Przypominanie")
    }

    // MARK: Pace

    func testPaceCountsOnlyFirstAnswersOfNewMeanings() {
        var state = TestData.emptyState()
        state.reviews = [
            review("a", meaning: "A", at: testNow - 1 * day),
            review("b", meaning: "B", at: testNow - 8 * day),
            review("c1", meaning: "C", at: testNow - 20 * day, before: 30),
            review("c2", meaning: "C", at: testNow - 1 * day, before: 40),
            review("d", meaning: "D", at: testNow - 40 * day),
            review("demo", meaning: "E", at: testNow - 1 * day, demo: true)
        ]
        let pace = LearnerAnalyzer.pace(state, now: testNow, calendar: calendar)
        XCTAssertEqual(pace.newMeaningsByWeek, [0, 0, 1, 1])
        XCTAssertEqual(pace.newMeaningsPerWeek, 0.5, accuracy: 0.0001)
        XCTAssertEqual(pace.answersPerWeek, 1.0, accuracy: 0.0001)
        XCTAssertEqual(pace.activeDays, 2)
        XCTAssertEqual(pace.regularity, .occasional)
        XCTAssertEqual(pace.summaryPl, "mniej niż 1 nowe znaczenie tygodniowo · nauka w 2 z 14 dni")
    }

    func testPaceOfRegularLearner() {
        let pace = LearnerAnalyzer.pace(experiencedState(), now: testNow, calendar: calendar)
        XCTAssertEqual(pace.newMeaningsByWeek.reduce(0, +), 40)
        XCTAssertEqual(pace.roundedNewPerWeek, 10)
        XCTAssertEqual(pace.activeDays, 10)
        XCTAssertEqual(pace.regularity, .regular)
        XCTAssertEqual(pace.summaryPl, "≈ 10 nowych znaczeń tygodniowo · nauka w 10 z 14 dni")
    }

    // MARK: Topic areas

    func testTopicAreasUseTopicNamesAndCollections() {
        var state = TestData.emptyState()
        let topics = TopicIndex(topics: [TopicSummary(id: "restaurant", namePl: "Restauracja", group: "food")])
        let strong: [Skill: Double] = [.recognition: 60, .recall: 60, .usage: 60, .listening: 60, .spelling: 60]
        var words: [Word] = []
        for index in 0..<6 {
            words.append(word("r\(index)", intervals: strong, contentRef: "restaurant/restaurant.e\(index)"))
        }
        for index in 0..<5 {
            words.append(word("p\(index)", intervals: [.recognition: 1], collection: "Praca"))
        }
        words.append(word("x", intervals: [:], contentRef: "restaurant/restaurant.archived", archived: true))
        state.words = words
        let areas = LearnerAnalyzer.topicAreas(state, topics: topics)
        XCTAssertEqual(areas.map { $0.id }, ["restaurant", "collection:Praca"])
        XCTAssertEqual(areas.first?.name, "Restauracja")
        XCTAssertEqual(areas.first?.group, "food")
        XCTAssertEqual(areas.first?.meanings, 6, "archived words are not counted")
        XCTAssertEqual(areas.first?.mastered, 6)

        let analysis = LearnerAnalyzer.analyze(state, topics: topics, now: testNow, calendar: calendar)
        XCTAssertEqual(analysis.strongestArea?.id, "restaurant")
        XCTAssertEqual(analysis.weakestArea?.id, "collection:Praca")

        let withoutIndex = LearnerAnalyzer.topicAreas(state, topics: nil)
        XCTAssertEqual(withoutIndex.first?.name, "Własne", "without the index the collection is used")
    }

    func testPolishPlurals() {
        XCTAssertEqual(AnalysisText.meanings(1), "1 znaczenie")
        XCTAssertEqual(AnalysisText.meanings(3), "3 znaczenia")
        XCTAssertEqual(AnalysisText.meanings(12), "12 znaczeń")
        XCTAssertEqual(AnalysisText.meanings(22), "22 znaczenia")
        XCTAssertEqual(AnalysisText.answers(1), "1 odpowiedź")
        XCTAssertEqual(AnalysisText.answers(5), "5 odpowiedzi")
    }
}
