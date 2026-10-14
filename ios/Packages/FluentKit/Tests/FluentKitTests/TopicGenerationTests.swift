import XCTest
@testable import FluentKit

/// Validation of AI-generated topics (same rules as the built-in base) and the local topic memory.
final class TopicGenerationTests: XCTestCase {
    private let inventoryJSON = """
    {
      "topic": "jazda konna", "nameEn": "Horse riding", "summaryPl": "Stajnia, sprzęt i nauka jazdy.", "group": "leisure",
      "categories": [
        { "name": "W stajni", "scene": "Poranek w stajni przed pierwszą lekcją jazdy", "items": [
          { "term": "horse", "pl": "koń", "pos": "rzeczownik", "level": "A1", "spokenFrequency": "very_common" },
          { "term": "saddle", "pl": "siodło", "pos": "noun", "level": "b1", "spokenFrequency": "common" },
          { "term": "stable", "pl": "stajnia", "pos": "rzeczownik", "level": "B1", "spokenFrequency": "less common" },
          { "term": "horse", "pl": "koń", "pos": "rzeczownik", "level": "A1", "spokenFrequency": "very_common" },
          { "term": "bridle", "pl": "", "pos": "rzeczownik", "level": "B2", "spokenFrequency": "rare" },
          { "term": "hoof", "pl": "kopyto", "pos": "rzeczownik", "level": "D1", "spokenFrequency": "rare" },
          { "term": "groom", "pl": "czyścić konia", "pos": "magic", "level": "B2", "spokenFrequency": "rare" }
        ] },
        { "name": "Nauka jazdy", "scene": "Lekcja na ujeżdżalni z instruktorką", "items": [
          { "term": "ride", "pl": "jeździć konno", "pos": "czasownik", "level": "A2", "spokenFrequency": "common" },
          { "term": "gallop.", "pl": "galopować (AmE)", "pos": "verb", "level": "B2", "spokenFrequency": "less_common" },
          { "term": "fall off", "pl": "spaść", "pos": "phrasal verb", "level": "B1", "spokenFrequency": "common" }
        ] },
        { "name": "", "items": [ { "term": "rein", "pl": "wodza", "pos": "rzeczownik", "level": "B2", "spokenFrequency": "rare" } ] }
      ]
    }
    """

    private func buildDraftTopic() throws -> TopicBuildResult {
        let draft = try JSONDecoder().decode(TopicDraft.self, from: Data(inventoryJSON.utf8))
        return try XCTUnwrap(TopicGeneration.buildTopic(from: draft, query: "Jazda konna", existingTopicIDs: ["airport"]))
    }

    // MARK: Phase 1 — inventory

    func testInventoryKeepsValidEntriesAndRejectsBrokenOnes() throws {
        let result = try buildDraftTopic()
        let topic = result.topic
        XCTAssertEqual(topic.id, "ai-jazda-konna")
        XCTAssertEqual(topic.namePl, "Jazda konna")
        XCTAssertEqual(topic.group, "leisure")
        XCTAssertEqual(topic.symbol, "theatermasks")
        XCTAssertEqual(topic.categories.map { $0.namePl }, ["W stajni", "Nauka jazdy"])
        XCTAssertEqual(topic.categories.map { $0.id }, ["ai-jazda-konna.w-stajni", "ai-jazda-konna.nauka-jazdy"])
        XCTAssertEqual(topic.allEntries.map { $0.term }, ["horse", "saddle", "stable", "ride", "gallop", "fall off"])
        // duplicate horse, empty translation, level D1, unknown pos, category without a name
        XCTAssertEqual(result.rejectedCount, 5)
        let saddle = try XCTUnwrap(topic.allEntries.first { $0.term == "saddle" })
        XCTAssertEqual(saddle.pos, "rzeczownik", "English part of speech mapped")
        XCTAssertEqual(saddle.level, "B1")
        XCTAssertEqual(saddle.id, "ai-jazda-konna.saddle")
        XCTAssertEqual(topic.allEntries.first { $0.term == "stable" }?.frequency, .lessCommon)
        let gallop = try XCTUnwrap(topic.allEntries.first { $0.term == "gallop" })
        XCTAssertEqual(gallop.translation, "galopować", "(AmE) removed, trailing period removed from the term")
        XCTAssertEqual(topic.allEntries.first { $0.term == "fall off" }?.pos, "czasownik frazowy")
        XCTAssertTrue(topic.allEntries.allSatisfy { TopicGeneration.isDraft($0) })
        XCTAssertTrue(topic.aliases.contains("Jazda konna"))
        XCTAssertTrue(topic.aliases.contains("Horse riding"))
        XCTAssertEqual(topic.categories.first?.scenePl, "Poranek w stajni przed pierwszą lekcją jazdy")
    }

    func testInventoryWithTooFewEntriesIsRejected() {
        let draft = TopicDraft(topic: "Coś", categories: [TopicDraftCategory(name: "A", items: [
            TopicDraftItem(term: "one", translation: "jeden", pos: "liczebnik", level: "A1", frequency: "very_common")
        ])])
        XCTAssertNil(TopicGeneration.buildTopic(from: draft, query: "coś", existingTopicIDs: []))
    }

    func testTopicIDsAreUniqueAndPrefixed() {
        XCTAssertEqual(TopicGeneration.makeTopicID(name: "Zamawianie w restauracji", existing: []), "ai-zamawianie-w-restauracji")
        XCTAssertEqual(TopicGeneration.makeTopicID(name: "Jazda konna", existing: ["ai-jazda-konna"]), "ai-jazda-konna-2")
        XCTAssertEqual(TopicGeneration.makeTopicID(name: "!!!", existing: []), "ai-temat")
        XCTAssertEqual(TopicGeneration.slug("Łódź — żeglarstwo"), "lodz-zeglarstwo")
        XCTAssertLessThanOrEqual(TopicGeneration.slug(String(repeating: "słowo ", count: 30), maxLength: 40).count, 40)
    }

    func testNormalizers() {
        XCTAssertEqual(TopicGeneration.normalizedPartOfSpeech(" Phrasal  verb "), "czasownik frazowy")
        XCTAssertEqual(TopicGeneration.normalizedPartOfSpeech("przysłówek"), "przysłówek")
        XCTAssertNil(TopicGeneration.normalizedPartOfSpeech("thing"))
        XCTAssertEqual(TopicGeneration.normalizedFrequency("Very common"), .veryCommon)
        XCTAssertEqual(TopicGeneration.normalizedFrequency("less-common"), .lessCommon)
        XCTAssertNil(TopicGeneration.normalizedFrequency("often"))
    }

    // MARK: Phase 2 — details

    private func validItem(_ term: String, focusPl: String, pl: String) -> TopicHydrationItem {
        TopicHydrationItem(
            term: term,
            ipa: "/ˈsædəl/",
            definition: "A leather seat that you put on a horse's back.",
            register: "neutralny",
            contextPl: "Przygotowanie konia do jazdy",
            forms: "saddles",
            notePl: "Wymowa (AmE) jak w słowniku.",
            examples: [
                ExamplePair(en: "Put the \(term) on the horse before the lesson.", pl: pl, focusEn: term, focusPl: focusPl),
                ExamplePair(en: "This \(term) is too small for me.", pl: "To \(focusPl) jest dla mnie za małe.", focusEn: term, focusPl: focusPl)
            ],
            acceptedAnswers: ["riding \(term)"],
            acceptedTranslations: ["siodło", "siodło", "kulbaka"]
        )
    }

    func testHydrationCompletesValidEntriesAndKeepsInvalidOnesAsDrafts() throws {
        let topic = try buildDraftTopic().topic
        let saddle = try XCTUnwrap(topic.allEntries.first { $0.term == "saddle" })
        let horse = try XCTUnwrap(topic.allEntries.first { $0.term == "horse" })
        let stable = try XCTUnwrap(topic.allEntries.first { $0.term == "stable" })
        let requests = TopicGeneration.hydrationRequests(topic: topic, entryIDs: [stable.id, saddle.id, horse.id])
        XCTAssertEqual(requests.map { $0.term }, ["horse", "saddle", "stable"], "Topic order")
        XCTAssertEqual(requests.first?.category, "W stajni")
        XCTAssertEqual(requests.first?.scene, "Poranek w stajni przed pierwszą lekcją jazdy")

        let saddleItem = validItem("saddle", focusPl: "siodło", pl: "Załóż siodło na konia przed lekcją.")
        // focusPl is not a substring of pl → rejected entry (not the whole batch)
        let horseItem = validItem("horse", focusPl: "koń", pl: "Załóż siodło przed lekcją.")
        let result = TopicGeneration.applyHydration(topic: topic, requests: requests, items: [saddleItem, horseItem])
        XCTAssertEqual(result.hydratedIDs, [saddle.id])
        XCTAssertEqual(Set(result.rejectedIDs), Set([horse.id, stable.id]))

        let hydrated = try XCTUnwrap(result.topic.allEntries.first { $0.id == saddle.id })
        XCTAssertFalse(TopicGeneration.isDraft(hydrated))
        XCTAssertEqual(hydrated.examples.count, 2)
        XCTAssertEqual(hydrated.acceptedAnswers, ["saddle", "riding saddle"])
        XCTAssertEqual(hydrated.acceptedTranslations, ["siodło", "kulbaka"])
        XCTAssertEqual(hydrated.notePl, "Wymowa jak w słowniku.")
        XCTAssertEqual(hydrated.level, "B1", "Level from the inventory is kept")
        XCTAssertTrue(TopicEntryValidator.issues(hydrated).isEmpty)
        XCTAssertTrue(TopicGeneration.isDraft(try XCTUnwrap(result.topic.allEntries.first { $0.id == horse.id })))
        // Applying again does not request completed entries.
        XCTAssertFalse(TopicGeneration.hydrationRequests(topic: result.topic, entryIDs: [saddle.id]).contains { $0.entryID == saddle.id })
    }

    func testHydrationRepairsSmallProblems() throws {
        let topic = try buildDraftTopic().topic
        let saddle = try XCTUnwrap(topic.allEntries.first { $0.term == "saddle" })
        var item = validItem("saddle", focusPl: "siodło", pl: "Załóż siodło na konia przed lekcją.")
        item.ipa = "ˈsædəl"
        item.register = "casual"
        item.contextPl = String(repeating: "długi kontekst ", count: 10)
        item.definition = "A leather seat that you put on a horse's back so that you can ride it comfortably for a long time. It has stirrups and a girth that keeps it in place."
        let entry = try XCTUnwrap(TopicGeneration.hydratedEntry(draft: saddle, item: item))
        XCTAssertEqual(entry.ipa, "")
        XCTAssertEqual(entry.register, "neutralny")
        XCTAssertEqual(entry.contextPl, "")
        XCTAssertLessThanOrEqual(entry.definition.count, 140)
        XCTAssertTrue(entry.definition.hasSuffix("."))
    }

    func testHydrationRejectsMissingExamplesOrDefinition() throws {
        let topic = try buildDraftTopic().topic
        let saddle = try XCTUnwrap(topic.allEntries.first { $0.term == "saddle" })
        var oneExample = validItem("saddle", focusPl: "siodło", pl: "Załóż siodło na konia przed lekcją.")
        oneExample.examples = Array(oneExample.examples.prefix(1))
        XCTAssertNil(TopicGeneration.hydratedEntry(draft: saddle, item: oneExample))
        var noDefinition = validItem("saddle", focusPl: "siodło", pl: "Załóż siodło na konia przed lekcją.")
        noDefinition.definition = " "
        XCTAssertNil(TopicGeneration.hydratedEntry(draft: saddle, item: noDefinition))
        var noPunctuation = validItem("saddle", focusPl: "siodło", pl: "Załóż siodło na konia przed lekcją.")
        noPunctuation.examples[0].en = "Put the saddle on the horse"
        XCTAssertNil(TopicGeneration.hydratedEntry(draft: saddle, item: noPunctuation))
    }

    func testHydrationResponseDecodesLeniently() throws {
        let json = """
        { "items": [ { "term": "saddle", "note": "uwaga", "examples": [ { "en": "A.", "pl": "B.", "focusEn": "A", "focusPl": "B" }, { "pl": "bez en" } ], "acceptedAnswers": ["saddle", 3] }, "zepsute" ] }
        """
        let response = try JSONDecoder().decode(TopicHydrationResponse.self, from: Data(json.utf8))
        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.items[0].notePl, "uwaga")
        XCTAssertEqual(response.items[0].examples.count, 1)
        XCTAssertEqual(response.items[0].acceptedAnswers, ["saddle"])
    }

    // MARK: Validator vs the built-in base

    func testEveryBuiltInEntryPassesTheValidator() throws {
        let directory = TestData.contentDirectory.appendingPathComponent("topics")
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            throw XCTSkip("Brak katalogu tematów")
        }
        var checked = 0
        var problems: [String] = []
        for name in names.sorted() where name.hasSuffix(".json") && name != "index.json" {
            let topic = try ContentDecoder.topicFile(from: Data(contentsOf: directory.appendingPathComponent(name)))
            for entry in topic.allEntries {
                checked += 1
                let issues = TopicEntryValidator.issues(entry)
                if !issues.isEmpty && problems.count < 20 {
                    problems.append("\(entry.id): \(issues.joined(separator: " "))")
                }
            }
        }
        guard checked > 0 else { throw XCTSkip("Brak wpisów") }
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    func testValidatorFindsSchemaErrors() {
        let entry = TopicEntry(id: "Bad Id", term: "word.", ipa: "wɜrd", pos: "noun", level: "X1", translation: "",
                               register: "casual", examples: [], acceptedAnswers: [], acceptedTranslations: [])
        let issues = TopicEntryValidator.issues(entry)
        XCTAssertGreaterThanOrEqual(issues.count, 10)
        XCTAssertTrue(TopicEntryValidator.isAbbreviation("a.m."))
        XCTAssertFalse(TopicEntryValidator.isAbbreviation("word."))
        XCTAssertTrue(TopicEntryValidator.endsWithSentencePunctuation("He said “yes.”"))
        XCTAssertFalse(TopicEntryValidator.endsWithSentencePunctuation("No period"))
    }

    // MARK: Memory

    func testAliasBookRecordsUpdatesAndTrims() {
        var book = TopicAliasBook()
        XCTAssertTrue(book.record(query: "Na lotnisku", topicID: "airport", now: 1))
        XCTAssertTrue(book.record(query: "na  lotnisku!", topicID: "airport", categoryID: "airport.check-in", now: 2))
        XCTAssertEqual(book.aliases.count, 1)
        XCTAssertEqual(book.alias(for: "NA LOTNISKU")?.hits, 2)
        XCTAssertEqual(book.alias(for: "na lotnisku")?.categoryID, "airport.check-in")
        XCTAssertFalse(book.record(query: "w", topicID: "airport", now: 3), "Too short")
        XCTAssertTrue(book.remove(query: "na lotnisku"))
        XCTAssertNil(book.alias(for: "na lotnisku"))
        for index in 0..<(TopicAliasBook.maxAliases + 20) {
            book.record(query: "zapytanie numer \(index)", topicID: "t", now: Double(index))
        }
        XCTAssertEqual(book.aliases.count, TopicAliasBook.maxAliases)
        book.removeTopic("t")
        XCTAssertTrue(book.aliases.isEmpty)
    }

    func testGeneratedTopicRecordRoundTrip() throws {
        let topic = try buildDraftTopic().topic
        let record = GeneratedTopicRecord(topic: topic, query: "jazda konna", provider: "gemini", createdAt: testNow, updatedAt: testNow)
        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(GeneratedTopicRecord.self, from: data)
        XCTAssertEqual(decoded, record)
        XCTAssertTrue(decoded.completeEntries.isEmpty, "Drafts are not complete")
        XCTAssertTrue(decoded.dictionaryEntries.isEmpty)
        // The stored topic is a normal topic file (decodes with the content decoder).
        let topicData = try JSONEncoder().encode(topic)
        XCTAssertEqual(try ContentDecoder.topicFile(from: topicData), topic)
        let book = try JSONDecoder().decode(TopicAliasBook.self, from: Data(#"{"aliases":[{"query":"a b c","topicID":"x"},{"broken":1}]}"#.utf8))
        XCTAssertEqual(book.aliases.count, 1)
        XCTAssertEqual(book.aliases.first?.hits, 1)
    }

    func testGeneratedTopicAddsToVocabularyWithContentReferences() throws {
        let topic = try buildDraftTopic().topic
        let saddle = try XCTUnwrap(topic.allEntries.first { $0.term == "saddle" })
        let requests = TopicGeneration.hydrationRequests(topic: topic, entryIDs: [saddle.id])
        let hydrated = TopicGeneration.applyHydration(topic: topic, requests: requests,
                                                      items: [validItem("saddle", focusPl: "siodło", pl: "Załóż siodło na konia przed lekcją.")]).topic
        let ids = IDGenerator()
        let merged = VocabularyMerger.addTopicEntries(LearnerState(), topic: hydrated, entryIDs: [saddle.id], now: testNow, makeID: ids.next)
        XCTAssertEqual(merged.addedMeaningIDs.count, 1)
        let word = try XCTUnwrap(merged.state.words.first)
        XCTAssertEqual(word.collection, "Jazda konna")
        XCTAssertEqual(word.meanings.first?.contentRef, "ai-jazda-konna/\(saddle.id)")
        XCTAssertEqual(word.meanings.first?.examples.count, 2)
    }
}
