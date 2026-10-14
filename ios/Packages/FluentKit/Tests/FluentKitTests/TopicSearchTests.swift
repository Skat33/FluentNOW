import XCTest
@testable import FluentKit

/// Topic search on the real topic files (`ios/FluentNOW/Resources/Content/topics`, read through
/// `#filePath`). Skipped when the content is not available.
final class TopicSearchTests: XCTestCase {
    private struct LoadedContent {
        let catalog: TopicSearchCatalog
        let files: [String: URL]
    }

    private static var cache: LoadedContent?

    private static func load() throws -> LoadedContent {
        if let cache { return cache }
        let directory = TestData.contentDirectory.appendingPathComponent("topics")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            throw XCTSkip("Brak katalogu tematów")
        }
        var documents: [TopicSearchDocument] = []
        var files: [String: URL] = [:]
        for name in names.sorted() where name.hasSuffix(".json") && name != "index.json" {
            let url = directory.appendingPathComponent(name)
            let document = try ContentDecoder.topicSearchDocument(from: Data(contentsOf: url))
            documents.append(document)
            files[document.id] = url
        }
        guard documents.count >= 50 else { throw XCTSkip("Za mało plików tematów (\(documents.count))") }
        let loaded = LoadedContent(catalog: TopicSearchCatalog(documents: documents), files: files)
        cache = loaded
        return loaded
    }

    private func catalog() throws -> TopicSearchCatalog {
        try Self.load().catalog
    }

    private func topic(_ id: String) throws -> TopicFile {
        let files = try Self.load().files
        let url = try XCTUnwrap(files[id], "Brak tematu \(id)")
        return try ContentDecoder.topicFile(from: Data(contentsOf: url))
    }

    private func best(_ query: String, file: StaticString = #filePath, line: UInt = #line) throws -> TopicMatch {
        let loaded = try catalog()
        let first = TopicSearch.rank(query, in: loaded).first
        return try XCTUnwrap(first, "Brak wyniku dla „\(query)”", file: file, line: line)
    }

    // MARK: Text

    func testNormalizationAndKeywords() {
        XCTAssertEqual(TopicSearch.normalize("  Na LOTNISKU! "), "na lotnisku")
        XCTAssertEqual(TopicSearch.normalize("Zażółć gęślą jaźń"), "zazolc gesla jazn")
        XCTAssertEqual(TopicSearch.keywords("Na lotnisku"), ["lotnisku"])
        XCTAssertEqual(TopicSearch.keywords("rozmowa o pracę"), ["rozmowa", "prace"])
        XCTAssertEqual(TopicSearch.keywords("at the airport"), ["airport"])
        XCTAssertEqual(TopicSearch.keywords("doctor's appointment"), ["doctor", "appointment"])
        XCTAssertEqual(TopicSearch.keywords("w"), [], "Same stopwords shorter than 2 letters give nothing")
        XCTAssertEqual(TopicSearch.keywords("na"), ["na"], "Only stopwords → kept")
        XCTAssertEqual(TopicSearch.queryKey("Rozmowa o pracę"), TopicSearch.queryKey("rozmowa  o  prace"))
    }

    func testSimilarityStemsTyposAndFalseFriends() {
        func token(_ text: String) -> [UInt8] { Array(text.utf8) }
        func similarity(_ a: String, _ b: String, fuzzy: Bool = true) -> Double {
            TopicSearch.similarity(token(a), token(b), fuzzy: fuzzy)
        }
        XCTAssertEqual(similarity("lotnisko", "lotnisko"), 1)
        XCTAssertEqual(similarity("lotnisku", "lotnisko"), 0.85)
        XCTAssertEqual(similarity("restauracji", "restauracja"), 0.85)
        XCTAssertEqual(similarity("dentysty", "dentysta"), 0.85)
        XCTAssertEqual(similarity("prace", "praca"), 0.85)
        XCTAssertEqual(similarity("ordering", "order"), 0.85)
        XCTAssertEqual(similarity("sklepie", "sklep"), 0.85)
        XCTAssertEqual(similarity("pogoda", "pogodzic"), 0, "Shared prefix without an inflectional ending is not a stem match")
        XCTAssertEqual(similarity("lot", "lotnisko"), 0, "Too short for a prefix match")
        XCTAssertEqual(similarity("lotn", "lotnisko"), 0.7, "Typed prefix")
        XCTAssertEqual(similarity("lotnsko", "lotnisko"), 0.75, "One typo")
        XCTAssertEqual(similarity("restauarcji", "restauracja"), 0.7, "Transposition + ending")
        XCTAssertEqual(similarity("lotnsko", "lotnisko", fuzzy: false), 0)
        XCTAssertEqual(TopicSearch.osaDistance(token("abcd"), token("abdc"), limit: 2), 1)
        XCTAssertNil(TopicSearch.osaDistance(token("abcdef"), token("uvwxyz"), limit: 2))
    }

    // MARK: Ranking on real content

    func testPolishSituationQueriesFindTheRightTopic() throws {
        let cases: [(query: String, topic: String)] = [
            ("zamawianie w restauracji", "restaurant"),
            ("na lotnisku", "airport"),
            ("rozmowa o pracę", "job-search"),
            ("u dentysty", "dentist"),
            ("w aptece", "pharmacy"),
            ("u fryzjera", "beauty-hairdresser"),
            ("wizyta u lekarza", "doctor-visit"),
            ("zameldowanie w hotelu", "hotel"),
            ("kupowanie biletu na pociąg", "train-travel"),
            ("przedstawianie się", "greetings-introductions"),
            ("na poczcie", "post-office"),
            ("w banku", "banking"),
            ("pogoda", "weather")
        ]
        for item in cases {
            let match = try best(item.query)
            XCTAssertEqual(match.topicID, item.topic, item.query)
            XCTAssertEqual(match.confidence, .high, item.query)
        }
    }

    /// Skróty z onboardingu (`TodayOnboardingView.situations`) i przykłady z „Szukaj tematu”
    /// (`TopicSearchModel.exampleQueries`) muszą trafiać w temat bazy bez AI.
    func testShortcutQueriesAlwaysHitTheBase() throws {
        let catalog = try catalog()
        let shortcuts = [
            "przedstawianie się", "small talk", "w sklepie", "zakupy spożywcze", "w restauracji", "w kawiarni",
            "na lotnisku", "w hotelu", "pytanie o drogę", "u lekarza", "rozmowa o pracę", "rodzina"
        ]
        for query in shortcuts {
            XCTAssertNotNil(TopicSearch.bestMatch(query, in: catalog), query)
        }
    }

    func testEnglishQueries() throws {
        XCTAssertEqual(try best("at the airport").topicID, "airport")
        XCTAssertEqual(try best("job interview").topicID, "job-search")
        XCTAssertEqual(try best("ordering food at a restaurant").topicID, "restaurant")
        XCTAssertEqual(try best("check in at the hotel").topicID, "hotel")
        XCTAssertTrue(try best("ordering food at a restaurant").confidence.isGood)
    }

    func testTyposStillMatch() throws {
        let airport = try best("lotnsko")
        XCTAssertEqual(airport.topicID, "airport")
        XCTAssertTrue(airport.confidence.isGood)
        let restaurant = try best("restauarcji")
        XCTAssertEqual(restaurant.topicID, "restaurant")
        XCTAssertTrue(restaurant.confidence.isGood)
        XCTAssertEqual(try best("dentyssty").topicID, "dentist")
    }

    func testFocusCategory() throws {
        XCTAssertEqual(try best("zamawianie w restauracji").focusCategoryIDs.first, "restaurant.ordering")
        XCTAssertEqual(try best("płacenie rachunku w restauracji").focusCategoryIDs.first, "restaurant.bill-tip")
        XCTAssertEqual(try best("odprawa").focusCategoryIDs.first, "airport.check-in")
        XCTAssertEqual(try best("kontrola bezpieczeństwa na lotnisku").focusCategoryIDs.first, "airport.security")
        XCTAssertEqual(try best("zameldowanie w hotelu").focusCategoryIDs.first, "hotel.check-in-out")
        XCTAssertEqual(try best("airport security").focusCategoryIDs.first, "airport.security", "English words matched through entries")
        XCTAssertEqual(try best("na lotnisku").focusCategoryIDs, [], "The whole topic — no single category")
        XCTAssertEqual(try best("restauracja").focusCategoryIDs, [])
    }

    func testUnknownSituationHasNoGoodMatch() throws {
        let catalog = try catalog()
        XCTAssertNil(TopicSearch.bestMatch("jazda konna", in: catalog))
        XCTAssertNil(TopicSearch.bestMatch("qwrtpz", in: catalog))
        XCTAssertTrue(TopicSearch.rank("", in: catalog).isEmpty)
        XCTAssertTrue(TopicSearch.rank("   ", in: catalog).isEmpty)
        XCTAssertNotNil(TopicSearch.bestMatch("u dentysty", in: catalog))
    }

    func testFalseStemDoesNotWin() throws {
        let matches = TopicSearch.rank("pogoda", in: try catalog())
        XCTAssertEqual(matches.first?.topicID, "weather")
        let conflict = matches.first { $0.topicID == "arguments-conflict" }
        XCTAssertTrue(conflict == nil || conflict?.confidence == .low, "„pogodzić się” is not „pogoda”")
    }

    func testRankingIsFast() throws {
        let catalog = try catalog()
        let queries = ["zamawianie w restauracji", "na lotnisku", "rozmowa o pracę", "u dentysty", "lotnsko",
                       "job interview", "ordering food at a restaurant", "kupowanie biletu na pociąg", "jazda konna", "w sklepie"]
        let start = Date()
        for query in queries {
            _ = TopicSearch.rank(query, in: catalog)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0, "10 queries (debug build)")
    }

    // MARK: Saved queries and generated topics

    func testSavedQueryWinsAndKeepsCategory() throws {
        let base = try catalog()
        let alias = TopicQueryAlias(query: TopicSearch.queryKey("nocleg na weekend z walizką"), topicID: "hotel", categoryID: "hotel.check-in-out", updatedAt: testNow)
        let catalog = TopicSearchCatalog(documents: base.documents, savedQueries: [alias])
        let match = try XCTUnwrap(TopicSearch.rank("Nocleg na weekend z walizką", in: catalog).first)
        XCTAssertEqual(match.topicID, "hotel")
        XCTAssertEqual(match.reason, .savedQuery)
        XCTAssertEqual(match.confidence, .high)
        XCTAssertEqual(match.focusCategoryIDs.first, "hotel.check-in-out")
    }

    func testGeneratedTopicIsSearchable() throws {
        let base = try catalog()
        let generated = TopicSearchDocument(
            id: "ai-jazda-konna",
            namePl: "Jazda konna",
            nameEn: "Horse riding",
            group: "leisure",
            aliases: ["jazda konna", "konie"],
            categories: [TopicSearchDocument.Category(id: "ai-jazda-konna.stajnia", namePl: "W stajni", entries: [
                TopicSearchDocument.Entry(id: "ai-jazda-konna.saddle", term: "saddle", translation: "siodło")
            ])],
            isGenerated: true
        )
        let catalog = TopicSearchCatalog(documents: base.documents + [generated])
        let match = try XCTUnwrap(TopicSearch.bestMatch("jazda konna", in: catalog))
        XCTAssertEqual(match.topicID, "ai-jazda-konna")
        XCTAssertTrue(match.isGenerated)
        XCTAssertEqual(TopicSearch.bestMatch("na koniach", in: catalog)?.topicID, "ai-jazda-konna")
        let suggestion = try XCTUnwrap(catalog.suggestions(for: [match]).first)
        XCTAssertEqual(suggestion.namePl, "Jazda konna")
        XCTAssertEqual(suggestion.entryCount, 1)
    }

    // MARK: Result sections

    func testSectionsOrderFocusThenTopicThenRelated() throws {
        let catalog = try catalog()
        let matches = TopicSearch.rank("zamawianie w restauracji", in: catalog)
        let primary = try XCTUnwrap(matches.first)
        let restaurant = try topic("restaurant")
        let sections = TopicSearch.sections(primary: primary, topic: restaurant)
        let first = try XCTUnwrap(sections.first)
        XCTAssertEqual(first.kind, .focus)
        XCTAssertEqual(first.categoryID, "restaurant.ordering")
        XCTAssertTrue(sections.dropFirst().allSatisfy { $0.kind == .topic })
        // Every entry of the topic is offered exactly once (duplicates of term + translation once).
        let shown = sections.flatMap { $0.entries.map { $0.id } }
        XCTAssertEqual(Set(shown).count, shown.count)
        let uniqueEntries = Set(restaurant.allEntries.map { TopicSearch.duplicateKey($0) })
        XCTAssertEqual(shown.count, uniqueEntries.count)
        // Inside a section: frequency first, then CEFR.
        for section in sections {
            for (left, right) in zip(section.entries, section.entries.dropFirst()) {
                let lf = left.frequency?.rank ?? 4
                let rf = right.frequency?.rank ?? 4
                XCTAssertLessThanOrEqual(lf, rf, "\(section.title): \(left.term) / \(right.term)")
                if lf == rf {
                    XCTAssertLessThanOrEqual(CEFR.index(of: left.level) ?? 6, CEFR.index(of: right.level) ?? 6,
                                             "\(section.title): \(left.term) / \(right.term)")
                }
            }
        }
        XCTAssertEqual(first.reference(of: first.entries[0]), "restaurant/\(first.entries[0].id)")
    }

    func testRelatedTopicsAreConfidentAndFocused() throws {
        let catalog = try catalog()
        let matches = TopicSearch.rank("odprawa", in: catalog)
        let primary = try XCTUnwrap(matches.first)
        XCTAssertEqual(primary.topicID, "airport")
        let related = TopicSearch.relatedMatches(matches, primary: primary)
        XCTAssertLessThanOrEqual(related.count, 2)
        for match in related {
            XCTAssertNotEqual(match.topicID, primary.topicID)
            XCTAssertTrue(match.confidence.isGood)
            XCTAssertGreaterThanOrEqual(match.focus.first?.score ?? 0, 0.75)
        }
        let pairs = try related.map { (match: $0, topic: try topic($0.topicID)) }
        let sections = TopicSearch.sections(primary: primary, topic: try topic("airport"), related: pairs, relatedEntryLimit: 5)
        XCTAssertEqual(sections.first?.categoryID, "airport.check-in")
        let relatedSections = sections.filter { $0.kind == .related }
        XCTAssertEqual(relatedSections.isEmpty, related.isEmpty)
        XCTAssertTrue(relatedSections.allSatisfy { $0.entries.count <= 5 })
        if let last = sections.last, !relatedSections.isEmpty {
            XCTAssertEqual(last.kind, .related, "Related topics come last")
        }
    }

    func testUsefulnessOrderIsStable() {
        let entries = [
            TopicEntry(id: "t.a", term: "a", level: "B1", frequency: .common, translation: "a"),
            TopicEntry(id: "t.b", term: "b", level: "A1", frequency: .rare, translation: "b"),
            TopicEntry(id: "t.c", term: "c", level: "A2", frequency: .common, translation: "c"),
            TopicEntry(id: "t.d", term: "d", level: "A1", frequency: .veryCommon, translation: "d"),
            TopicEntry(id: "t.e", term: "e", level: "A2", frequency: .common, translation: "e"),
            TopicEntry(id: "t.f", term: "f", level: "", frequency: nil, translation: "f")
        ]
        XCTAssertEqual(TopicSearch.usefulnessOrder(entries).map { $0.id }, ["t.d", "t.c", "t.e", "t.a", "t.b", "t.f"])
    }
}
