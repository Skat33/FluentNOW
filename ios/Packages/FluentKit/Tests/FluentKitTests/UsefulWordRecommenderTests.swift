import XCTest
@testable import FluentKit

final class UsefulWordRecommenderTests: XCTestCase {
    private let topicNames: [String: (name: String, group: String)] = [
        "restaurant": ("Restauracja", "food"),
        "airport": ("Lotnisko", "travel"),
        "weather": ("Pogoda", "daily"),
        "small-talk": ("Small talk", "communication"),
        "programming-it": ("Programowanie i IT", "technology"),
        "dentist": ("Dentysta", "health"),
        "online-shopping": ("Zakupy w internecie", "money")
    ]

    private func candidate(_ term: String, _ level: String = "B1", _ frequency: SpokenFrequency = .veryCommon, topic: String = "restaurant") -> UsefulWordCandidate {
        let info = topicNames[topic] ?? (name: topic, group: "")
        return UsefulWordCandidate(
            reference: "\(topic)/\(topic).\(term.replacingOccurrences(of: " ", with: "-"))",
            term: term,
            translation: "tłumaczenie \(term)",
            level: level,
            frequency: frequency,
            topicID: topic,
            topicName: info.name,
            group: info.group
        )
    }

    private func profile(_ level: String = "B1", topics: [String: Int] = [:], owned: Set<String> = [], references: Set<String> = []) -> UsefulWordProfile {
        UsefulWordProfile(level: level, targetLevel: CEFR.next(after: level), ownedKeys: owned, ownedReferences: references, topicCounts: topics)
    }

    // MARK: Filters

    func testFiltersFrequencyLevelAndOwnedWords() {
        let candidates = [
            candidate("order", "A1"),
            candidate("rare thing", "A1", .rare),
            candidate("fancy", "A2", .lessCommon),
            candidate("advanced", "C1"),
            candidate("menu", "A1"),
            candidate("tip", "A2", .common)
        ]
        let result = UsefulWordRecommender.recommend(
            candidates,
            profile: profile("A1", owned: ["menu"], references: ["restaurant/restaurant.tip"]),
            options: UsefulWordOptions(limit: 10)
        )
        XCTAssertEqual(result.map { $0.candidate.term }, ["order"])
        XCTAssertTrue(UsefulWordRecommender.recommend(candidates, profile: profile(), options: UsefulWordOptions(limit: 0)).isEmpty)
    }

    func testRegisterRules() {
        let candidates = [candidate("plaque", topic: "dentist"), candidate("dope", topic: "dentist"), candidate("tooth", topic: "dentist")]
        let registers = [
            "dentist/dentist.plaque": "specjalistyczny",
            "dentist/dentist.dope": "slangowy",
            "dentist/dentist.tooth": "neutralny"
        ]
        let options = UsefulWordOptions(limit: 10, registers: registers)
        let stranger = UsefulWordRecommender.recommend(candidates, profile: profile(), options: options)
        XCTAssertEqual(stranger.map { $0.candidate.term }, ["tooth"])
        let learner = UsefulWordRecommender.recommend(candidates, profile: profile(topics: ["dentist": 3]), options: options)
        XCTAssertEqual(Set(learner.map { $0.candidate.term }), ["tooth", "plaque"], "specialist words only for a topic the learner studies, slang never")
        XCTAssertTrue(UsefulWordRecommender.isAllowedRegister("potoczny", learnedTopic: false))
        XCTAssertTrue(UsefulWordRecommender.isAllowedRegister("formalny", learnedTopic: false))
        let excluded = UsefulWordRecommender.recommend(candidates, profile: profile(), options: UsefulWordOptions(limit: 10, excludedReferences: ["dentist/dentist.tooth"]))
        XCTAssertFalse(excluded.contains { $0.candidate.term == "tooth" })
    }

    // MARK: Ranking and reasons

    func testPrefersLearnedTopicThenEverydayTopics() {
        let candidates = [
            candidate("algorithm", "B1", .common, topic: "programming-it"),
            candidate("forecast", "B1", .common, topic: "weather"),
            candidate("waiter", "B1", .common, topic: "restaurant")
        ]
        let result = UsefulWordRecommender.recommend(candidates, profile: profile("B1", topics: ["restaurant": 4]), options: UsefulWordOptions(limit: 10))
        XCTAssertEqual(result.map { $0.candidate.term }, ["waiter", "forecast", "algorithm"])
        XCTAssertEqual(result.first?.reasons.first, .learnedTopic("Restauracja"))
        XCTAssertEqual(result.first?.summaryPl, "Z tematu Restauracja, którego się uczysz · często używane")
        XCTAssertEqual(result[1].reasons, [.frequent(.common), .fitsLevel("B1"), .everyday])
        XCTAssertEqual(result[1].summaryPl, "Często używane · pasuje do Twojego poziomu B1")
        XCTAssertEqual(result[2].reasons, [.frequent(.common), .fitsLevel("B1")])
    }

    func testLevelPreferenceAndReasons() {
        let candidates = [candidate("next", "B2"), candidate("same", "B1"), candidate("below", "A2"), candidate("basic", "A1")]
        let result = UsefulWordRecommender.recommend(candidates, profile: profile("B1"), options: UsefulWordOptions(limit: 10, maxPerTopic: 10))
        XCTAssertEqual(result.map { $0.candidate.term }, ["same", "next", "below", "basic"])
        XCTAssertTrue(result[1].reasons.contains(.nextLevel("B2")))
        XCTAssertEqual(UsefulWordReason.nextLevel("B2").textPl, "krok w stronę poziomu B2")
        XCTAssertEqual(UsefulWordReason.frequent(.veryCommon).textPl, "bardzo często używane")
    }

    func testOneMeaningPerTerm() {
        let candidates = [candidate("order", "A2", topic: "online-shopping"), candidate("order", "A2", topic: "restaurant")]
        let result = UsefulWordRecommender.recommend(candidates, profile: profile("A2", topics: ["restaurant": 2]), options: UsefulWordOptions(limit: 10))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.candidate.topicID, "restaurant", "the sense from the studied topic wins")
    }

    // MARK: Variety and determinism

    func testVarietyCapsPerTopic() {
        var candidates = (0..<30).map { candidate("food \($0)", topic: "restaurant") }
        candidates += (0..<5).map { candidate("travel \($0)", topic: "airport") }
        candidates += (0..<5).map { candidate("sky \($0)", topic: "weather") }
        candidates += (0..<5).map { candidate("chat \($0)", topic: "small-talk") }
        let result = UsefulWordRecommender.recommend(candidates, profile: profile("B1", topics: ["restaurant": 20]), options: UsefulWordOptions(limit: 20))
        XCTAssertEqual(UsefulWordRecommender.defaultMaxPerTopic(limit: 20), 4)
        var perTopic: [String: Int] = [:]
        for item in result { perTopic[item.candidate.topicID, default: 0] += 1 }
        XCTAssertEqual(result.count, 16, "never 20 words from one topic — fewer results instead")
        XCTAssertTrue(perTopic.values.allSatisfy { $0 <= 4 })
        XCTAssertEqual(perTopic.count, 4)
        XCTAssertEqual(result.first?.candidate.topicID, "restaurant")
    }

    func testDeterministicRegardlessOfInputOrder() {
        let topics = Array(topicNames.keys).sorted()
        var candidates: [UsefulWordCandidate] = []
        for index in 0..<200 {
            let level = CEFR.levels[index % 4]
            let frequency: SpokenFrequency = index % 3 == 0 ? .common : .veryCommon
            candidates.append(candidate("term \(index)", level, frequency, topic: topics[index % topics.count]))
        }
        let learner = profile("A2", topics: ["airport": 5])
        let options = UsefulWordOptions(limit: 20, seed: 42)
        let first = UsefulWordRecommender.recommend(candidates, profile: learner, options: options)
        var generator = SeededGenerator(seed: 7)
        let shuffled = candidates.shuffled(using: &generator)
        let second = UsefulWordRecommender.recommend(shuffled, profile: learner, options: options)
        XCTAssertEqual(first.count, 20)
        XCTAssertEqual(first.map { $0.id }, second.map { $0.id })
        XCTAssertEqual(first, UsefulWordRecommender.recommend(candidates.reversed(), profile: learner, options: options))
        XCTAssertTrue(first.allSatisfy { (CEFR.index(of: $0.candidate.level) ?? 9) <= 2 })
    }

    // MARK: Candidates and profile

    func testCandidatesFromDictionaryIndex() {
        let topics = TopicIndex(topics: [TopicSummary(id: "restaurant", namePl: "Restauracja", group: "food")])
        let entries = [
            DictionaryIndex.Entry(term: "menu", translation: "menu", level: "A1", frequency: "very_common", reference: "restaurant/restaurant.menu"),
            DictionaryIndex.Entry(term: "amuse-bouche", translation: "przystawka", level: "C1", frequency: "rare", reference: "restaurant/restaurant.amuse-bouche"),
            DictionaryIndex.Entry(term: "ghost", translation: "duch", level: "A2", frequency: "common", reference: "ghost/ghost.ghost"),
            DictionaryIndex.Entry(term: "do", translation: "robić", level: "A1", frequency: "very_common", reference: "starter/starter.do"),
            DictionaryIndex.Entry(term: "nolevel", translation: "brak", level: "", frequency: "common", reference: "restaurant/restaurant.nolevel"),
            DictionaryIndex.Entry(term: "broken", translation: "zepsuty", level: "A2", frequency: "common", reference: "no-slash")
        ]
        let candidates = UsefulWordRecommender.candidates(entries: entries, topics: topics)
        XCTAssertEqual(candidates.map { $0.reference }, ["restaurant/restaurant.menu", "starter/starter.do"])
        XCTAssertEqual(candidates.first?.topicName, "Restauracja")
        XCTAssertEqual(candidates.first?.group, "food")
        XCTAssertEqual(candidates.last?.topicName, UsefulWordRecommender.starterTopicName)
        XCTAssertEqual(candidates.last?.group, "basics")
    }

    func testProfileFromState() {
        var state = TestData.emptyState()
        var archived = TestData.freshWord("a", "Borrow", "pożyczyć")
        archived.archived = true
        var fromTopic = TestData.freshWord("b", "waiter", "kelner")
        fromTopic.meanings[0].contentRef = "restaurant/restaurant.waiter"
        var manual = TestData.freshWord("c", "gate", "bramka")
        manual.collection = "Lotnisko"
        state.words = [archived, fromTopic, manual]
        let made = UsefulWordProfile.make(state)
        XCTAssertTrue(made.ownedKeys.contains("borrow"), "archived words are owned too")
        XCTAssertTrue(made.ownedReferences.contains("restaurant/restaurant.waiter"))
        XCTAssertEqual(made.topicCounts, ["restaurant": 1])
        XCTAssertTrue(made.collectionKeys.contains("lotnisko"))

        let result = UsefulWordRecommender.recommend([candidate("boarding pass", "A2", topic: "airport"), candidate("borrow", "A2", topic: "small-talk")], profile: made, options: UsefulWordOptions(limit: 5))
        XCTAssertEqual(result.map { $0.candidate.term }, ["boarding pass"])
        XCTAssertEqual(result.first?.reasons.first, .learnedTopic("Lotnisko"), "a collection named like the topic counts as studying it")
    }

    // MARK: Core vocabulary (FEEDBACK-7)

    private func coreCandidate(_ term: String, _ level: String = "B1", _ frequency: SpokenFrequency = .common, shard: String = "core-c01") -> UsefulWordCandidate {
        UsefulWordCandidate(
            reference: "\(shard)/core.\(term.replacingOccurrences(of: " ", with: "-"))",
            term: term,
            translation: "ogólne \(term)",
            level: level,
            frequency: frequency,
            topicID: shard,
            topicName: CoreVocabulary.collectionName,
            group: UsefulWordRecommender.coreGroup
        )
    }

    func testCoreEntriesAreCandidates() {
        let topics = TopicIndex(topics: [TopicSummary(id: "restaurant", namePl: "Restauracja", group: "food")])
        let entries = [
            DictionaryIndex.Entry(term: "attain", translation: "osiągnąć", level: "C1", frequency: "common", reference: "core-c06/core.attain"),
            DictionaryIndex.Entry(term: "despite", translation: "pomimo", level: "B1", frequency: "very_common", reference: "core-c01/core.despite"),
            DictionaryIndex.Entry(term: "thorough", translation: "dokładny", level: "B2", frequency: "less_common", reference: "core-c03/core.thorough"),
            DictionaryIndex.Entry(term: "menu", translation: "menu", level: "A1", frequency: "very_common", reference: "restaurant/restaurant.menu"),
            DictionaryIndex.Entry(term: "core", translation: "rdzeń", level: "B2", frequency: "common", reference: "core/core.core")
        ]
        let candidates = UsefulWordRecommender.candidates(entries: entries, topics: topics)
        XCTAssertEqual(candidates.map { $0.reference }, ["core-c06/core.attain", "core-c01/core.despite", "restaurant/restaurant.menu"],
                       "core shards are candidates although they are not topics; `core` alone is not a shard")
        let attain = candidates[0]
        XCTAssertTrue(attain.isCore)
        XCTAssertEqual(attain.topicID, "core-c06")
        XCTAssertEqual(attain.topicName, CoreVocabulary.collectionName)
        XCTAssertEqual(attain.group, "basics")
        XCTAssertFalse(candidates[2].isCore)
        let withLessCommon = UsefulWordRecommender.candidates(entries: entries, topics: topics, includeLessCommon: true)
        XCTAssertTrue(withLessCommon.contains { $0.reference == "core-c03/core.thorough" }, "less_common core words feed word families")
    }

    func testCoreFollowsTheLearnersLevelPlusMinusOne() {
        let candidates = [
            coreCandidate("basic", "A1"),
            coreCandidate("simple", "A2"),
            coreCandidate("despite", "B1"),
            coreCandidate("ensure", "B2", .veryCommon),
            coreCandidate("attain", "C1"),
            coreCandidate("esoteric", "C2"),
            candidate("menu", "A1", .common)
        ]
        let result = UsefulWordRecommender.recommend(candidates, profile: profile("B2"), options: UsefulWordOptions(limit: 10, maxPerTopic: 10))
        let terms = Set(result.map { $0.candidate.term })
        XCTAssertEqual(terms, ["despite", "ensure", "attain", "menu"], "core: B1–C1 for a B2 learner; topic words keep the old rule")
        XCTAssertEqual(result.first?.candidate.term, "ensure", "the learner's level and the higher frequency first")
        let newcomer = UsefulWordRecommender.recommend(candidates, profile: profile("A1"), options: UsefulWordOptions(limit: 10, maxPerTopic: 10))
        XCTAssertEqual(Set(newcomer.map { $0.candidate.term }), ["basic", "simple", "menu"])
    }

    func testCoreSkipsOwnedWordsAndHasItsOwnReason() {
        var state = TestData.emptyState()
        var owned = TestData.freshWord("w1", "despite", "pomimo")
        owned.collection = CoreVocabulary.collectionName
        owned.meanings[0].contentRef = "core-c01/core.despite"
        var ownedSense = TestData.freshWord("w2", "require", "wymagać")
        ownedSense.collection = CoreVocabulary.collectionName
        ownedSense.meanings[0].contentRef = "core-c02/core.require-2"
        state.words = [owned, ownedSense]
        let made = UsefulWordProfile.make(state, estimate: LevelEstimate(level: "B1", targetLevel: "B2", count: 40, confidence: .high))
        XCTAssertTrue(made.topicCounts.isEmpty, "core shards are not topics the learner studies")

        let candidates = [
            coreCandidate("despite", "B1", .veryCommon),
            coreCandidate("require", "B1", .veryCommon, shard: "core-c02"),
            coreCandidate("whereas", "B1", .common),
            coreCandidate("achieve", "B2", .common)
        ]
        let result = UsefulWordRecommender.recommend(candidates, profile: made, options: UsefulWordOptions(limit: 10))
        XCTAssertEqual(result.map { $0.candidate.term }, ["whereas", "achieve"])
        guard let first = result.first else { return XCTFail("no core suggestion") }
        XCTAssertEqual(first.reasons, [.frequent(.common), .fitsLevel("B1"), .coreVocabulary])
        XCTAssertFalse(first.reasons.contains(.learnedTopic(CoreVocabulary.collectionName)), "the collection „Słownictwo ogólne” is not a topic")
        XCTAssertEqual(UsefulWordReason.coreVocabulary.textPl, "słownictwo ogólne, przydatne w wielu sytuacjach")
    }

    func testCoreWordFamilyIgnoresTheLowerLevelLimit() {
        let families = WordFamilyIndex(translations: ["happy": ["szczęśliwy"], "happiness": ["szczęście"], "basic": ["podstawowy"]])
        let candidates = [
            coreCandidate("happiness", "A2"),
            coreCandidate("basic", "A2"),
            coreCandidate("attain", "C1")
        ]
        let learner = UsefulWordProfile(level: "C1", targetLevel: "C2", ownedKeys: ["happy"])
        let result = UsefulWordRecommender.recommend(candidates, profile: learner, options: UsefulWordOptions(limit: 10), families: families)
        XCTAssertEqual(Set(result.map { $0.candidate.term }), ["happiness", "attain"], "a family member may be below the core level window")
        XCTAssertEqual(result.first(where: { $0.candidate.term == "happiness" })?.familySource, "happy")
    }

    // MARK: Real content

    /// Registers of the given references read from the real topic and core files (the app does the
    /// same lazily, `UsefulWordsCatalog`).
    private func registers(for references: [String], cache: inout [String: TopicFile], starter: [TopicEntry]) throws -> [String: String] {
        var result: [String: String] = [:]
        for raw in references {
            guard let reference = ContentReference(raw) else { continue }
            if reference.isStarter {
                if let entry = starter.first(where: { $0.id == reference.entryID }) { result[raw] = entry.register }
                continue
            }
            if cache[reference.file] == nil {
                let data = try TestData.contentData(reference.relativePath)
                if reference.isCore {
                    cache[reference.file] = try ContentDecoder.coreFile(from: data)
                } else {
                    cache[reference.file] = try ContentDecoder.topicFile(from: data)
                }
            }
            if let found = cache[reference.file]?.entry(id: reference.entryID) {
                result[raw] = found.entry.register
            }
        }
        return result
    }

    func testRealDictionaryRecommendationsAreUsefulAndVaried() throws {
        let index = try ContentDecoder.dictionaryIndex(from: TestData.contentData("dictionary-index.json"))
        let topics = try ContentDecoder.topicIndex(from: TestData.contentData("topics/index.json"))
        let starter = try ContentDecoder.starterWords(from: TestData.contentData("starter-words.json")).words
        let candidates = UsefulWordRecommender.candidates(index: index, topics: topics)
        XCTAssertGreaterThan(candidates.count, 1000)
        XCTAssertTrue(candidates.allSatisfy { UsefulWordRecommender.isFrequent($0.frequency) })

        let restaurantEntries = Array(index.entries.filter { $0.reference.hasPrefix("restaurant/") && CEFR.isValid($0.level) }.prefix(12))
        guard restaurantEntries.count >= 6, let restaurantName = topics.topics.first(where: { $0.id == "restaurant" })?.namePl else {
            throw XCTSkip("Brak tematu restaurant w treści")
        }
        var scores = SkillScores()
        for skill in Skill.masterySkills {
            scores[skill] = Score(value: Mastery.fromInterval(10), interval: 10, due: testNow + day, correct: 3, last: testNow - day)
        }
        var state = TestData.emptyState()
        var words: [Word] = []
        for (offset, entry) in restaurantEntries.enumerated() {
            words.append(Word(id: "r\(offset)", en: entry.term, level: "B1", collection: restaurantName, created: 1, meanings: [
                Meaning(id: "rm\(offset)", level: "B1", translation: entry.translation, examples: ["Example."], scores: scores, contentRef: entry.reference)
            ]))
        }
        state.words = words
        let profile = UsefulWordProfile.make(state)
        XCTAssertEqual(profile.level, "B1")
        XCTAssertEqual(profile.targetLevel, "B2")

        // Two-pass ranking like the app: rank, read registers of the results, rank again.
        var known: [String: String] = [:]
        var cache: [String: TopicFile] = [:]
        var result: [UsefulWordSuggestion] = []
        for _ in 0..<4 {
            result = UsefulWordRecommender.recommend(candidates, profile: profile, options: UsefulWordOptions(limit: 20, registers: known))
            let unknown = result.map { $0.id }.filter { known[$0] == nil }
            if unknown.isEmpty { break }
            for (reference, register) in try registers(for: unknown, cache: &cache, starter: starter) {
                known[reference] = register
            }
        }

        XCTAssertEqual(result.count, 20)
        let ownedKeys = Set(state.words.map { TextNormalizer.searchKey($0.en) })
        var perTopic: [String: Int] = [:]
        var keys = Set<String>()
        for item in result {
            let candidate = item.candidate
            XCTAssertTrue(UsefulWordRecommender.isFrequent(candidate.frequency), candidate.term)
            XCTAssertLessThanOrEqual(CEFR.index(of: candidate.level) ?? 9, 3, candidate.term)
            XCTAssertFalse(ownedKeys.contains(candidate.key), candidate.term)
            XCTAssertTrue(keys.insert(candidate.key).inserted, "one meaning per term: \(candidate.term)")
            XCTAssertFalse(item.summaryPl.isEmpty)
            let register = known[item.id] ?? "neutralny"
            XCTAssertNotEqual(register, "slangowy", candidate.term)
            if candidate.topicID != "restaurant" {
                XCTAssertNotEqual(register, "specjalistyczny", candidate.term)
            }
            perTopic[candidate.topicID, default: 0] += 1
        }
        XCTAssertTrue(perTopic.values.allSatisfy { $0 <= 4 }, "variety: \(perTopic)")
        XCTAssertGreaterThanOrEqual(perTopic.count, 5)
        XCTAssertGreaterThanOrEqual(Set(result.map { $0.candidate.group }).count, 3)
        XCTAssertGreaterThanOrEqual(result.filter { UsefulWordRecommender.everydayGroups.contains($0.candidate.group) }.count, 12)
        XCTAssertTrue(result.contains { $0.reasons.contains(.learnedTopic(restaurantName)) })

        let again = UsefulWordRecommender.recommend(candidates.reversed(), profile: profile, options: UsefulWordOptions(limit: 20, registers: known))
        XCTAssertEqual(again.map { $0.id }, result.map { $0.id }, "deterministic")
    }

    func testRealDictionaryForNewcomer() throws {
        let index = try ContentDecoder.dictionaryIndex(from: TestData.contentData("dictionary-index.json"))
        let topics = try ContentDecoder.topicIndex(from: TestData.contentData("topics/index.json"))
        let candidates = UsefulWordRecommender.candidates(index: index, topics: topics)
        let profile = UsefulWordProfile.make(TestData.emptyState())
        XCTAssertEqual(profile.level, "A1")
        let result = UsefulWordRecommender.recommend(candidates, profile: profile, options: UsefulWordOptions(limit: 10))
        XCTAssertEqual(result.count, 10)
        XCTAssertTrue(result.allSatisfy { $0.candidate.level == "A1" || $0.candidate.level == "A2" })
        XCTAssertTrue(result.allSatisfy { UsefulWordRecommender.everydayGroups.contains($0.candidate.group) })
    }

    func testRankingPerformance() throws {
        let index = try ContentDecoder.dictionaryIndex(from: TestData.contentData("dictionary-index.json"))
        let topics = try ContentDecoder.topicIndex(from: TestData.contentData("topics/index.json"))
        let candidates = UsefulWordRecommender.candidates(index: index, topics: topics)
        let profile = UsefulWordProfile(level: "B2", targetLevel: "C1")
        let start = Date()
        _ = UsefulWordRecommender.recommend(candidates, profile: profile, options: UsefulWordOptions(limit: 60))
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0, "debug build margin; release target < 50 ms")
    }

    /// Core vocabulary is an important source of the real pool (the app ranks 72 for the pager).
    func testRealCoreVocabularyIsRecommendedAtTheLearnersLevel() throws {
        let index = try ContentDecoder.dictionaryIndex(from: TestData.contentData("dictionary-index.json"))
        let topics = try ContentDecoder.topicIndex(from: TestData.contentData("topics/index.json"))
        let candidates = UsefulWordRecommender.candidates(index: index, topics: topics, includeLessCommon: true)
        let core = candidates.filter { $0.isCore }
        guard core.count > 1000 else { throw XCTSkip("Słownik rdzeniowy jeszcze niekompletny") }
        XCTAssertTrue(core.allSatisfy { $0.group == UsefulWordRecommender.coreGroup && $0.topicName == CoreVocabulary.collectionName })
        let families = WordFamilyIndex(entries: index.entries)
        for level in ["A2", "B1", "B2", "C1"] {
            let learner = UsefulWordProfile(level: level, targetLevel: CEFR.next(after: level))
            let result = UsefulWordRecommender.recommend(candidates, profile: learner, options: UsefulWordOptions(limit: 72, seed: 3), families: families)
            let fromCore = result.filter { $0.candidate.isCore }
            XCTAssertGreaterThanOrEqual(fromCore.count, 10, "core in the pool for \(level)")
            let user = CEFR.index(of: level) ?? 0
            for item in fromCore where item.familySource == nil {
                let index = CEFR.index(of: item.candidate.level) ?? -1
                XCTAssertTrue(index >= user - 1 && index <= user + 1, "\(item.candidate.term) \(item.candidate.level) for \(level)")
                XCTAssertTrue(UsefulWordRecommender.isFrequent(item.candidate.frequency), item.candidate.term)
            }
        }
    }
}
