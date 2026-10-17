import XCTest
@testable import FluentKit

final class LearnerProfileTests: XCTestCase {
    private func sampleProfile(updatedAt: Timestamp = testNow) -> LearnerProfile {
        LearnerProfile(
            goals: [.work, .travel],
            startLevel: "B1",
            levelSource: .placementTest,
            placementCorrect: 8,
            placementTotal: 12,
            interests: [.technology, .food],
            styles: [.reading, .flashcards, .grammar],
            dailyMinutes: 10,
            createdAt: testNow - day,
            updatedAt: updatedAt
        )
    }

    // MARK: Coding, migration, merging

    func testProfileRoundTripsInsideSettings() throws {
        var state = LearnerState()
        state.settings.profile = sampleProfile()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(LearnerState.self, from: data)
        XCTAssertEqual(decoded.settings.profile, sampleProfile())
    }

    func testOldSettingsWithoutProfileStillDecodeAndEncodeWithoutTheKey() throws {
        let json = #"{"goal":15,"reminder":"08:30","accent":"en-GB","slow":true}"#
        let settings = try JSONDecoder().decode(LearnerSettings.self, from: Data(json.utf8))
        XCTAssertNil(settings.profile)
        XCTAssertEqual(settings.goal, 15)
        let encoded = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
        XCTAssertFalse(encoded.contains("profile"))
    }

    func testUnknownValuesAndBrokenProfileAreTolerated() throws {
        let json = #"{"goal":20,"profile":{"goals":["work","space-travel",7],"startLevel":"Z9","interests":["music"],"styles":["telepathy","reading"],"dailyMinutes":"10","updatedAt":5}}"#
        let settings = try JSONDecoder().decode(LearnerSettings.self, from: Data(json.utf8))
        let profile = try XCTUnwrap(settings.profile)
        XCTAssertEqual(profile.goals, [.work])
        XCTAssertEqual(profile.interests, [.music])
        XCTAssertEqual(profile.styles, [.reading])
        let migrated = StateMigration.migrate(LearnerState(settings: settings))
        XCTAssertNil(migrated.settings.profile?.startLevel)

        let broken = #"{"goal":20,"profile":"oops"}"#
        let fallback = try JSONDecoder().decode(LearnerSettings.self, from: Data(broken.utf8))
        XCTAssertNil(fallback.profile)
        XCTAssertEqual(fallback.goal, 20)
    }

    func testNormalizationRemovesDuplicatesAndInvalidValues() {
        let profile = LearnerProfile(goals: [.work, .work], startLevel: "B2", placementCorrect: 20, placementTotal: 12, interests: [.food, .food], styles: [.grammar, .grammar], dailyMinutes: 500, updatedAt: -1)
        let normalized = profile.normalized()
        XCTAssertEqual(normalized.goals, [.work])
        XCTAssertEqual(normalized.interests, [.food])
        XCTAssertEqual(normalized.styles, [.grammar])
        XCTAssertNil(normalized.dailyMinutes)
        XCTAssertEqual(normalized.placementCorrect, 12)
        XCTAssertEqual(normalized.updatedAt, 0)
        XCTAssertEqual(normalized.normalized(), normalized)
    }

    func testMergeKeepsTheNewerProfileFromEitherDevice() {
        var local = LearnerState()
        var remote = LearnerState()
        remote.settings.profile = sampleProfile(updatedAt: testNow)
        XCTAssertEqual(StateSync.mergeStates(local: local, remote: remote).settings.profile, remote.settings.profile)

        var newer = sampleProfile(updatedAt: testNow + 1_000)
        newer.goals = [.exam]
        local.settings.profile = newer
        XCTAssertEqual(StateSync.mergeStates(local: local, remote: remote).settings.profile?.goals, [.exam])
        XCTAssertEqual(StateSync.mergeStates(local: remote, remote: local).settings.profile?.goals, [.exam])
    }

    // MARK: Derived preferences

    func testPreferencesAndStudyModes() {
        let profile = sampleProfile()
        let weights = profile.topicWeights()
        XCTAssertEqual(weights["office-work"], 10)
        XCTAssertGreaterThan(weights["restaurant"] ?? 0, weights["meetings"] ?? 0)   // travel + food
        XCTAssertEqual(profile.groupWeights()["work"], 4)
        let modes = profile.preferredStudyModes().map { $0.rawValue }
        XCTAssertEqual(modes.first, "mixed")
        XCTAssertTrue(modes.contains("reading"))
        XCTAssertTrue(modes.contains("grammar"))
        XCTAssertTrue(modes.contains("flashcards"))
        let mix = profile.dailyMixModes(limit: 3).map { $0.rawValue }
        XCTAssertEqual(mix.count, 3)
        XCTAssertFalse(mix.contains("flashcards"))
        XCTAssertEqual(LearnerProfile().preferredStudyModes(), [.mixed])
        XCTAssertEqual(LearnerProfile.dailyGoal(minutes: 10), 20)
        XCTAssertEqual(LearnerProfile.dailyGoal(minutes: 1), LearnerSettings.goalRange.lowerBound)
        XCTAssertEqual(profile.sessionMinutes, 10)
    }

    func testEveryProfileTopicExistsInTheContent() throws {
        let data = try TestData.contentData("topics/index.json")
        let index = try ContentDecoder.topicIndex(from: data)
        let ids = Set(index.topics.map { $0.id })
        let groups = Set(index.groups.map { $0.id })
        for goal in LearningGoal.allCases {
            for topic in goal.topicIDs { XCTAssertTrue(ids.contains(topic), "\(goal.rawValue): \(topic)") }
            for group in goal.topicGroups { XCTAssertTrue(groups.contains(group), "\(goal.rawValue): \(group)") }
        }
        for interest in LearningInterest.allCases {
            for topic in interest.topicIDs { XCTAssertTrue(ids.contains(topic), "\(interest.rawValue): \(topic)") }
            for group in interest.topicGroups { XCTAssertTrue(groups.contains(group), "\(interest.rawValue): \(group)") }
        }
        for topic in OnboardingPlan.defaultTopicIDs { XCTAssertTrue(ids.contains(topic), topic) }
    }

    // MARK: Start level

    func testProfileStartLevelIsUsedUntilThereIsPracticeHistory() {
        var state = LearnerState()
        state.words = [TestData.freshWord("w1", "borrow", "pożyczyć")]
        state.settings.profile = LearnerProfile(startLevel: "B2", levelSource: .selfAssessment)
        XCTAssertEqual(ProfileLevel.estimate(state).level, "B2")
        XCTAssertEqual(ProfileLevel.estimate(state).targetLevel, "C1")

        // Practiced meanings (mastery ≥ 40) → the real estimate wins.
        var practiced = state
        var scores: [Skill: Score] = [:]
        for skill in Skill.masterySkills {
            scores[skill] = Score(value: 80, interval: 30, due: testNow + day, correct: 5, last: testNow)
        }
        practiced.words[0].meanings[0].scores = SkillScores(scores)
        practiced = StateMigration.migrate(practiced)
        XCTAssertEqual(LevelEstimator.estimatedLevel(practiced).confidence, .high)
        XCTAssertEqual(ProfileLevel.estimate(practiced), LevelEstimator.estimatedLevel(practiced))
    }

    // MARK: Onboarding plan

    func testStarterTopicsFollowGoalsAndInterests() {
        let profile = LearnerProfile(goals: [.work], interests: [.technology])
        let topics = OnboardingPlan.starterTopicIDs(for: profile)
        XCTAssertEqual(topics.first, "office-work")
        XCTAssertEqual(topics.count, 3)
        XCTAssertEqual(OnboardingPlan.starterTopicIDs(for: LearnerProfile()), OnboardingPlan.defaultTopicIDs)
        let beginner = LearnerProfile(goals: [.travel], startLevel: "A1")
        XCTAssertEqual(OnboardingPlan.starterTopicIDs(for: beginner).first, OnboardingPlan.beginnerTopicID)
        let limited = OnboardingPlan.starterTopicIDs(for: profile, available: ["meetings", "restaurant"], limit: 3)
        XCTAssertEqual(limited, ["meetings", "restaurant"])
    }

    func testStarterEntriesMatchTheLevel() {
        let entries = ["A1", "A2", "B1", "B2", "C1", "A1", "B1"].enumerated().map { (offset: Int, level: String) -> TopicEntry in
            TopicEntry(id: "e\(offset)", term: "term\(offset)", level: level, translation: "t\(offset)")
        }
        let b1 = OnboardingPlan.starterEntries(entries, level: "B1", limit: 4).map { $0.id }
        XCTAssertEqual(b1, ["e1", "e2", "e3", "e6"])
        let filled = OnboardingPlan.starterEntries(entries, level: "B1", limit: 6).map { $0.id }
        XCTAssertEqual(filled, ["e1", "e2", "e3", "e6", "e0", "e5"])
        let a1 = OnboardingPlan.starterEntries(entries, level: "A1", limit: 10).map { $0.level }
        XCTAssertFalse(a1.contains("B1"))
        XCTAssertEqual(OnboardingPlan.wordsPerTopic(total: 24, topics: 3), [8, 8, 8])
        XCTAssertEqual(OnboardingPlan.wordsPerTopic(total: 10, topics: 3), [4, 3, 3])
        XCTAssertEqual(OnboardingPlan.starterWordCount(minutes: 5), 15)
        XCTAssertEqual(OnboardingPlan.starterWordCount(minutes: 20), 36)
    }

    // MARK: Placement test

    private func syntheticDictionary() -> [DictionaryIndex.Entry] {
        let names: [String: String] = ["A1": "alpha", "A2": "bravo", "B1": "charlie", "B2": "delta", "C1": "echo", "C2": "foxtrot"]
        let letters = Array("abcdefghijkl").map { String($0) }
        var entries: [DictionaryIndex.Entry] = []
        for level in CEFR.levels {
            for index in 0..<12 {
                entries.append(DictionaryIndex.Entry(
                    term: "word" + (names[level] ?? "x") + letters[index],
                    translation: "słowo\(level.lowercased())\(index) znaczenie",
                    level: level,
                    frequency: "common",
                    reference: "topic/topic.\(level)-\(index)"
                ))
            }
        }
        return entries
    }

    private func syntheticGrammar() -> [String: [ProductionItem]] {
        var result: [String: [ProductionItem]] = [:]
        for level in PlacementTest.grammarLevels {
            result[level] = [ProductionItem(
                bankId: "g-\(level)",
                context: "She ________ (iść) home yesterday.",
                answer: "went",
                distractors: [
                    ProductionDistractor(form: "goes", diagnosis: .wrongTense, explanation: ""),
                    ProductionDistractor(form: "has gone", diagnosis: .wrongTense, explanation: ""),
                    ProductionDistractor(form: "going", diagnosis: .wrongWord, explanation: "")
                ],
                rule: "past simple",
                translation: "Wczoraj poszła do domu."
            )]
        }
        return result
    }

    func testPlacementQuestionsAreWellFormedAndDeterministic() {
        let questions = PlacementTest.makeQuestions(dictionary: syntheticDictionary(), grammar: syntheticGrammar(), seed: 42)
        XCTAssertEqual(questions.count, 12)
        XCTAssertEqual(questions.filter { $0.kind == .grammar }.count, 3)
        XCTAssertEqual(Set(questions.map { $0.id }).count, 12)
        for question in questions {
            XCTAssertEqual(question.options.last, PlacementTest.dontKnow)
            XCTAssertTrue(question.answer >= 0 && question.answer < question.options.count - 1)
            XCTAssertEqual(Set(question.options).count, question.options.count, question.prompt)
        }
        XCTAssertEqual(PlacementTest.makeQuestions(dictionary: syntheticDictionary(), grammar: syntheticGrammar(), seed: 42), questions)
        XCTAssertEqual(Set(questions.filter { $0.kind == .vocabulary }.map { $0.level }), Set(["A1", "A2", "B1", "B2", "C1", "C2"]))
    }

    func testPlacementScoring() {
        let questions = PlacementTest.makeQuestions(dictionary: syntheticDictionary(), grammar: syntheticGrammar(), seed: 1)
        let perfect = questions.map { Optional($0.answer) }
        XCTAssertEqual(PlacementTest.result(questions: questions, answers: perfect).level, "C2")
        let none = questions.map { _ in Optional<Int>.none }
        XCTAssertEqual(PlacementTest.result(questions: questions, answers: none).level, "A1")
        // Correct up to B1, then „Nie wiem”.
        let upToB1 = questions.map { (question: PlacementQuestion) -> Int? in
            (CEFR.index(of: question.level) ?? 0) <= 2 ? question.answer : question.options.count - 1
        }
        let result = PlacementTest.result(questions: questions, answers: upToB1)
        XCTAssertEqual(result.level, "B1")
        XCTAssertEqual(result.total, 12)
        // A lucky C2 guess after failing B2 and C1 does not count.
        let lucky = questions.map { (question: PlacementQuestion) -> Int? in
            let index = CEFR.index(of: question.level) ?? 0
            return index <= 2 || index == 5 ? question.answer : nil
        }
        XCTAssertEqual(PlacementTest.result(questions: questions, answers: lucky).level, "B1")
        // One slip on the A1 word does not cap the result.
        let slip = questions.map { (question: PlacementQuestion) -> Int? in
            question.level == "A1" ? nil : question.answer
        }
        XCTAssertEqual(PlacementTest.result(questions: questions, answers: slip).level, "C2")
    }

    func testPlacementOnRealContent() throws {
        let dictionary = try ContentDecoder.dictionaryIndex(from: try TestData.contentData("dictionary-index.json"))
        var grammar: [String: [ProductionItem]] = [:]
        for level in PlacementTest.grammarLevels {
            grammar[level] = try ContentDecoder.grammarLevel(from: try TestData.contentData("grammar/\(level).json")).items
        }
        for seed in UInt64(1)...UInt64(20) {
            let questions = PlacementTest.makeQuestions(dictionary: dictionary.entries, grammar: grammar, seed: seed)
            XCTAssertEqual(questions.count, 12, "seed \(seed)")
            for question in questions {
                XCTAssertEqual(Set(question.options).count, question.options.count, question.prompt)
                if question.kind == .grammar {
                    XCTAssertTrue(question.prompt.contains("___"))
                }
            }
        }
    }

    // MARK: Owned vocabulary (G6)

    func testOwnedVocabularyMatchesReferenceOrTermAndTranslation() {
        var state = LearnerState()
        var word = TestData.freshWord("w1", "Borrow", "pożyczyć")
        word.meanings[0].contentRef = "money/money.borrow"
        var archived = TestData.freshWord("w2", "lend", "pożyczyć komuś")
        archived.archived = true
        state.words = [word, archived]
        let owned = OwnedVocabulary(state)
        XCTAssertTrue(owned.contains(reference: "money/money.borrow", term: "x", translation: "y"))
        XCTAssertTrue(owned.contains(reference: "other/other.borrow", term: "borrow", translation: "Pożyczyć"))
        XCTAssertFalse(owned.contains(reference: nil, term: "borrow", translation: "zapożyczyć"))
        XCTAssertFalse(owned.contains(reference: nil, term: "lend", translation: "pożyczyć komuś"))
        XCTAssertTrue(owned.containsTerm("BORROW"))

        // The rule matches the merger: an owned entry would be skipped when added again.
        let topic = TopicFile(id: "money", namePl: "Pieniądze", categories: [TopicCategory(id: "c", namePl: "C", entries: [
            TopicEntry(id: "money.borrow-2", term: "borrow", level: "A2", translation: "pożyczyć", examples: [ExamplePair(en: "Can I borrow it?", pl: "Mogę pożyczyć?", focusEn: "borrow", focusPl: "pożyczyć")])
        ])])
        let merged = VocabularyMerger.addTopicEntries(state, topic: topic, now: testNow)
        XCTAssertEqual(merged.addedMeaningIDs.count, 0)
        XCTAssertEqual(owned.ownedReferences([(reference: "money/money.borrow-2", entry: topic.allEntries[0])]), ["money/money.borrow-2"])
    }

    // MARK: Recommendations with a profile

    func testRecommendationsPreferTopicsOfTheProfile() {
        let candidates = [
            UsefulWordCandidate(reference: "office-work/office-work.deadline", term: "deadline", translation: "termin", level: "A2", frequency: .common, topicID: "office-work", topicName: "Praca w biurze", group: "work"),
            UsefulWordCandidate(reference: "weather/weather.sunny", term: "sunny", translation: "słoneczny", level: "A2", frequency: .common, topicID: "weather", topicName: "Pogoda", group: "daily")
        ]
        var state = LearnerState()
        let plain = UsefulWordRecommender.recommend(candidates, profile: UsefulWordProfile.make(state))
        XCTAssertEqual(plain.first?.candidate.term, "sunny")   // everyday group wins without a profile

        state.settings.profile = LearnerProfile(goals: [.work], startLevel: "B1", levelSource: .selfAssessment)
        let profile = UsefulWordProfile.make(state)
        XCTAssertEqual(profile.level, "B1")
        let ranked = UsefulWordRecommender.recommend(candidates, profile: profile)
        XCTAssertEqual(ranked.first?.candidate.term, "deadline")
        XCTAssertEqual(ranked.first?.reasons.first, UsefulWordReason.interest("Praca w biurze"))
        XCTAssertTrue(ranked.first?.summaryPl.hasPrefix("Z tematu Praca w biurze") ?? false)

        // Specialist register is allowed for a topic chosen by goals.
        let options = UsefulWordOptions(registers: ["office-work/office-work.deadline": "specjalistyczny"])
        XCTAssertTrue(UsefulWordRecommender.recommend(candidates, profile: profile, options: options).contains { $0.candidate.term == "deadline" })
        // …and still ignored without the profile.
        let withoutProfile = UsefulWordProfile.make(state, usesLearnerProfile: false)
        XCTAssertFalse(UsefulWordRecommender.recommend(candidates, profile: withoutProfile, options: options).contains { $0.candidate.term == "deadline" })
    }
}
