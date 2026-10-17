import XCTest
@testable import FluentKit

final class WordFamilyTests: XCTestCase {
    private let translations: [String: [String]] = [
        "decide": ["zdecydować"],
        "decision": ["decyzja"],
        "decisive": ["zdecydowany"],
        "decisively": ["zdecydowanie"],
        "comfort": ["pocieszać"],
        "comfortable": ["wygodny"],
        "comfortably": ["wygodnie"],
        "happy": ["szczęśliwy"],
        "happiness": ["szczęście"],
        "happily": ["szczęśliwie"],
        "unhappy": ["nieszczęśliwy"],
        "run": ["biegać"],
        "runner": ["biegacz"],
        "corn": ["kukurydza"],
        "corner": ["róg"],
        "patient": ["cierpliwy"],
        "impatient": ["niecierpliwy"],
        "port": ["port"],
        "import": ["importować"],
        "heat": ["upał"],
        "reheat": ["odgrzać"],
        "apple": ["jabłko"],
        "apply": ["złożyć wniosek"],
        "part": ["część"],
        "party": ["impreza"],
        "use": ["używać"],
        "usefulness": ["użyteczność"],
        "agree": ["zgadzać się"],
        "agreement": ["porozumienie"],
        "disagree": ["nie zgadzać się"],
        "disagreement": ["różnica zdań"],
        "pronounce": ["wymawiać"],
        "mispronounce": ["źle wymawiać"]
    ]

    private var index: WordFamilyIndex { WordFamilyIndex(translations: translations) }

    // MARK: Heuristic

    func testSuffixRulesWithSpellingChanges() {
        let families = index
        XCTAssertEqual(families.relatives(of: "decide"), ["decision", "decisive"], "-ision / -sive from -ide")
        XCTAssertEqual(families.relatives(of: "decisive"), ["decide", "decisively"])
        XCTAssertEqual(families.relatives(of: "comfortable"), ["comfort", "comfortably"], "-able, -bly ← -ble")
        XCTAssertEqual(families.relatives(of: "happy"), ["happily", "happiness", "unhappy"], "y → i")
        XCTAssertEqual(families.relatives(of: "run"), ["runner"], "doubled consonant with a verb base")
        XCTAssertEqual(families.relatives(of: "agree"), ["agreement", "disagree"])
    }

    func testFamilyUpToTwoLinks() {
        let family = index.family(of: "decide")
        XCTAssertEqual(family, [
            WordFamilyMember(key: "decision", distance: 1),
            WordFamilyMember(key: "decisive", distance: 1),
            WordFamilyMember(key: "decisively", distance: 2)
        ])
        XCTAssertEqual(index.family(of: "comfort").map { $0.key }, ["comfortable", "comfortably"])
        XCTAssertEqual(index.family(of: "comfort", maxDistance: 1).map { $0.key }, ["comfortable"])
        XCTAssertTrue(index.family(of: "decide", maxDistance: 0).isEmpty)
        XCTAssertTrue(index.areRelated("agree", "disagreement"))
        XCTAssertFalse(index.areRelated("agree", "agree"))
    }

    func testFalsePairsAndConditionsAreRejected() {
        let families = index
        XCTAssertTrue(families.relatives(of: "corn").isEmpty, "-er needs a verb base (kukurydza is not a verb)")
        XCTAssertTrue(families.relatives(of: "apple").isEmpty, "apply/apple is a listed false pair")
        XCTAssertTrue(families.relatives(of: "part").isEmpty, "party/part is a listed false pair")
        XCTAssertFalse(families.areRelated("port", "import"), "im- needs a Polish negation; import/port is also listed")
        XCTAssertEqual(families.relatives(of: "patient"), ["impatient"], "„niecierpliwy” is a negation")
        XCTAssertEqual(families.relatives(of: "heat"), ["reheat"], "„odgrzać” means again")
        XCTAssertEqual(families.relatives(of: "pronounce"), ["mispronounce"], "„źle” means wrongly")
        XCTAssertTrue(WordFamily.falsePairs.contains("party|part"))
    }

    func testWordsMissingFromTheDictionary() {
        // A learner's own word: its dictionary base and the dictionary words derived from it.
        XCTAssertEqual(index.relatives(of: "useful"), ["use", "usefulness"])
        XCTAssertTrue(index.relatives(of: "boarding pass").isEmpty, "phrases have no family")
        XCTAssertTrue(index.relatives(of: "zz").isEmpty)
        XCTAssertFalse(index.contains("useful"))
        XCTAssertTrue(index.contains("use"))
    }

    func testKeysAndPolishHints() {
        XCTAssertTrue(WordFamily.isWordKey("decide"))
        XCTAssertFalse(WordFamily.isWordKey("go"))
        XCTAssertFalse(WordFamily.isWordKey("check-in"))
        XCTAssertFalse(WordFamily.isWordKey("Decide"))
        XCTAssertTrue(WordFamily.isPolishVerb("zdecydować (się)"))
        XCTAssertTrue(WordFamily.isPolishVerb("się zgadzać"))
        XCTAssertTrue(WordFamily.isPolishVerb("biec"))
        XCTAssertFalse(WordFamily.isPolishVerb("noc"))
        XCTAssertFalse(WordFamily.isPolishVerb("decyzja"))
        XCTAssertTrue(WordFamily.isPolishNegative("nie zgadzać się"))
        XCTAssertTrue(WordFamily.isPolishNegative("bez motywacji"))
        XCTAssertFalse(WordFamily.isPolishNegative("niebo"))
        XCTAssertTrue(WordFamily.isPolishRepetition("ponownie podłączyć"))
        XCTAssertTrue(WordFamily.isPolishWrongly("wprowadzać w błąd"))
        XCTAssertEqual(WordFamily.polishTokens("prosty (o włosach), gładki"), ["prosty", "gładki"])
        XCTAssertEqual(WordFamily.possibleBases(of: "winner"), ["winn", "winne", "win"])
    }

    func testParticiplesFromForms() {
        XCTAssertEqual(WordFamily.participles(fromForms: "break – broke – broken", of: "break"), ["broken"])
        XCTAssertEqual(WordFamily.participles(fromForms: "freeze - froze - frozen", of: "freeze"), ["frozen"])
        XCTAssertTrue(WordFamily.participles(fromForms: "go – went – gone", of: "go").isEmpty)
        XCTAssertTrue(WordFamily.participles(fromForms: "", of: "run").isEmpty)
        XCTAssertTrue(WordFamily.participles(fromForms: "boarding passes", of: "boarding pass").isEmpty)
    }

    // MARK: Recommendations

    private func candidate(_ term: String, _ level: String = "B1", _ frequency: SpokenFrequency = .veryCommon, topic: String = "meetings", group: String = "work") -> UsefulWordCandidate {
        UsefulWordCandidate(
            reference: "\(topic)/\(topic).\(term)",
            term: term,
            translation: "tłumaczenie \(term)",
            level: level,
            frequency: frequency,
            topicID: topic,
            topicName: "Spotkania",
            group: group
        )
    }

    private func profile(owned: Set<String>, forms: [String: String] = [:]) -> UsefulWordProfile {
        UsefulWordProfile(level: "B1", targetLevel: "B2", ownedKeys: owned, ownedForms: forms)
    }

    func testFamilySuggestionsWithReason() {
        let candidates = [
            candidate("decision"),
            candidate("decisive", "C1", .lessCommon),
            candidate("decisively", "C2", .common),
            candidate("comfortable", "B1", .common, topic: "furniture", group: "home"),
            candidate("weather", "B1", .veryCommon, topic: "weather", group: "daily")
        ]
        let families = index
        let result = UsefulWordRecommender.recommend(candidates, profile: profile(owned: ["decide"]), options: UsefulWordOptions(limit: 10), families: families)
        XCTAssertEqual(result.first?.candidate.term, "decision")
        XCTAssertEqual(result.first?.reasons.first, .wordFamily("decide"))
        XCTAssertEqual(result.first?.familySource, "decide")
        XCTAssertEqual(result.first?.summaryPl, "Z rodziny słowa decide, które znasz · bardzo często używane")
        let terms = result.map { $0.candidate.term }
        XCTAssertTrue(terms.contains("decisive"), "family words may be less common and one level above the target")
        XCTAssertFalse(terms.contains("decisively"), "C2 is more than one level above the target B2")
        XCTAssertTrue(terms.contains("weather"))
        XCTAssertTrue(terms.contains("comfortable"))
        XCTAssertNil(result.first(where: { $0.candidate.term == "comfortable" })?.familySource, "comfort is not owned")

        let plain = UsefulWordRecommender.recommend(candidates, profile: profile(owned: ["decide"]), options: UsefulWordOptions(limit: 10))
        XCTAssertFalse(plain.map { $0.candidate.term }.contains("decisive"), "without families the old rules apply")
        XCTAssertTrue(plain.allSatisfy { $0.familySource == nil })
        XCTAssertEqual(UsefulWordReason.wordFamily("decide").textPl, "z rodziny słowa decide, które znasz")
    }

    func testFamilyDoesNotChangeOtherSuggestions() {
        let candidates = [candidate("weather", topic: "weather", group: "daily"), candidate("meeting"), candidate("agenda", "B2", .common)]
        let owned = profile(owned: ["table"])
        let withFamilies = UsefulWordRecommender.recommend(candidates, profile: owned, options: UsefulWordOptions(limit: 10), families: index)
        let without = UsefulWordRecommender.recommend(candidates, profile: owned, options: UsefulWordOptions(limit: 10))
        XCTAssertEqual(withFamilies, without)
    }

    func testFamilyCaps() {
        let candidates = [
            candidate("agreement"), candidate("disagree"), candidate("disagreement", "B2", .common),
            candidate("decision"), candidate("decisive", "B2", .common),
            candidate("happiness", "A2", topic: "emotions", group: "people"), candidate("unhappy", "A2", topic: "emotions", group: "people"),
            candidate("weather", topic: "weather", group: "daily"), candidate("rain", "A1", topic: "weather", group: "daily")
        ]
        let owned = profile(owned: ["agree", "decide", "happy"])
        let options = UsefulWordOptions(limit: 20, maxPerTopic: 10, maxFamilySuggestions: 4, maxPerFamily: 2)
        let result = UsefulWordRecommender.recommend(candidates, profile: owned, options: options, families: index)
        let family = result.filter { $0.familySource != nil }
        XCTAssertEqual(family.count, 4)
        var perSource: [String: Int] = [:]
        for item in family {
            perSource[item.familySource ?? "", default: 0] += 1
        }
        XCTAssertTrue(perSource.values.allSatisfy { $0 <= 2 }, "\(perSource)")
        XCTAssertFalse(result.map { $0.candidate.term }.contains("disagreement"), "distance 2 loses to direct relatives under the cap")
        XCTAssertEqual(UsefulWordRecommender.defaultMaxFamilySuggestions(limit: 20), 5)
        XCTAssertEqual(UsefulWordRecommender.defaultMaxFamilySuggestions(limit: 5), 2)
    }

    func testOwnedWordsAreNeverFamilySuggestions() {
        let sources = UsefulWordRecommender.familySources(profile: profile(owned: ["decide", "decision"]), families: index)
        XCTAssertNil(sources["decision"])
        XCTAssertEqual(sources["decisive"]?.word, "decide", "the closest owned word wins")
        XCTAssertEqual(sources["decisive"]?.distance, 1)
        XCTAssertEqual(sources["decisively"]?.distance, 2)
    }

    func testFormsAddParticiples() {
        let candidates = [candidate("broken", "A2", topic: "hotel", group: "travel")]
        let families = WordFamilyIndex(translations: ["broken": ["zepsuty"]])
        let result = UsefulWordRecommender.recommend(candidates, profile: profile(owned: ["break"], forms: ["broken": "break"]), options: UsefulWordOptions(limit: 5), families: families)
        XCTAssertEqual(result.first?.reasons.first, .wordFamily("break"))

        var state = TestData.emptyState()
        state.words = [Word(id: "w1", en: "Break", collection: "Test", forms: "break – broke – broken", created: 1, meanings: [])]
        XCTAssertEqual(UsefulWordProfile.make(state).ownedForms, ["broken": "break"])
    }

    // MARK: Real dictionary

    private func realIndex() throws -> (DictionaryIndex, WordFamilyIndex) {
        let dictionary = try ContentDecoder.dictionaryIndex(from: TestData.contentData("dictionary-index.json"))
        return (dictionary, WordFamilyIndex(entries: dictionary.entries))
    }

    func testRealDictionaryFamilies() throws {
        let (_, families) = try realIndex()
        XCTAssertGreaterThan(families.wordCount, 3000)
        XCTAssertGreaterThan(families.linkCount, 300)
        let expected: [(String, String)] = [
            ("decide", "decision"), ("comfort", "comfortable"), ("agree", "agreement"), ("agree", "disagree"),
            ("translate", "translation"), ("translate", "translator"), ("responsible", "responsibility"),
            ("responsible", "irresponsible"), ("happy", "unhappy"), ("safe", "safety"), ("meet", "meeting"),
            ("pay", "payment"), ("friend", "friendship")
        ]
        for (base, derived) in expected where families.contains(base) && families.contains(derived) {
            XCTAssertTrue(families.areRelated(base, derived, maxDistance: 1), "\(base) → \(derived)")
        }
        let unrelated: [(String, String)] = [
            ("apple", "apply"), ("part", "party"), ("corn", "corner"), ("store", "story"), ("car", "carry"),
            ("ear", "early"), ("port", "report"), ("view", "review"), ("count", "discount"), ("mess", "message")
        ]
        for (first, second) in unrelated {
            XCTAssertFalse(families.areRelated(first, second), "\(first) / \(second)")
        }
    }

    func testRealDictionaryRecommendations() throws {
        let (dictionary, families) = try realIndex()
        let topics = try ContentDecoder.topicIndex(from: TestData.contentData("topics/index.json"))
        let candidates = UsefulWordRecommender.candidates(index: dictionary, topics: topics, includeLessCommon: true)
        XCTAssertTrue(candidates.contains { $0.frequency == .lessCommon })
        let owned: Set<String> = ["decide", "agree", "translate", "responsible", "pay", "deliver", "connect", "happy"]
        let result = UsefulWordRecommender.recommend(candidates, profile: profile(owned: owned), options: UsefulWordOptions(limit: 20), families: families)
        XCTAssertEqual(result.count, 20)
        let family = result.filter { $0.familySource != nil }
        // Dokładna liczba zależy od treści (korekty english-qa ją zmieniają) — sprawdzamy zakres i limit ⌈20/4⌉.
        XCTAssertGreaterThanOrEqual(family.count, 1)
        XCTAssertLessThanOrEqual(family.count, 5)
        for item in family {
            XCTAssertTrue(item.summaryPl.hasPrefix("Z rodziny słowa "), item.summaryPl)
            XCTAssertTrue(owned.contains(item.familySource ?? ""))
            XCTAssertNotEqual(item.candidate.frequency, .rare)
            XCTAssertLessThanOrEqual(CEFR.index(of: item.candidate.level) ?? 9, 4, "≤ target + 1 (C1)")
        }
        for item in result where item.familySource == nil {
            XCTAssertTrue(UsefulWordRecommender.isFrequent(item.candidate.frequency), item.candidate.term)
            XCTAssertLessThanOrEqual(CEFR.index(of: item.candidate.level) ?? 9, 3, item.candidate.term)
        }
        XCTAssertTrue(result.allSatisfy { !owned.contains($0.candidate.key) })
    }

    func testRealDictionaryPerformance() throws {
        let dictionary = try ContentDecoder.dictionaryIndex(from: TestData.contentData("dictionary-index.json"))
        let buildStart = Date()
        let families = WordFamilyIndex(entries: dictionary.entries)
        XCTAssertLessThan(Date().timeIntervalSince(buildStart), 3.0, "debug build margin; built once off the main thread")
        let keys = Array(Set(dictionary.entries.map { $0.key }).prefix(1000)) + ["useful", "unknownword"]
        let lookupStart = Date()
        var total = 0
        for key in keys {
            total += families.family(of: key).count
        }
        let perLookup = Date().timeIntervalSince(lookupStart) / Double(keys.count)
        XCTAssertGreaterThanOrEqual(total, 0)
        XCTAssertLessThan(perLookup, 0.001, "family lookup < 1 ms")
    }
}
