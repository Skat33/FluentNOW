import XCTest
@testable import FluentKit

final class ContentTests: XCTestCase {
    private let topicJSON = """
    {
      "schemaVersion": 1, "id": "airport", "namePl": "Lotnisko", "nameEn": "Airport", "group": "travel",
      "symbol": "airplane.departure", "summaryPl": "Odprawa.", "aliases": ["lotnisko", "airport"],
      "categories": [
        { "id": "airport.check-in", "namePl": "Odprawa i bagaż", "scenePl": "Stanowisko odprawy",
          "entries": [
            { "id": "airport.boarding-pass", "term": "boarding pass", "ipa": "/ˈbɔːrdɪŋ ˌpæs/", "pos": "rzeczownik",
              "level": "A2", "frequency": "common", "translation": "karta pokładowa",
              "definition": "A document that allows a passenger to get on a plane.", "register": "neutralny",
              "contextPl": "Odprawa i wejście na pokład", "natural": "", "forms": "boarding passes",
              "collocations": "print a boarding pass", "synonyms": "boarding card", "antonyms": "", "notePl": "",
              "examples": [
                { "en": "Please have your boarding pass ready at the gate.", "pl": "Prosimy mieć kartę pokładową gotową przy bramce.", "focusEn": "boarding pass", "focusPl": "kartę pokładową" },
                { "en": "I downloaded my boarding pass to my phone last night.", "pl": "Wczoraj wieczorem pobrałem kartę pokładową na telefon.", "focusEn": "boarding pass", "focusPl": "kartę pokładową" }
              ],
              "acceptedAnswers": ["boarding pass", "boarding card"],
              "acceptedTranslations": ["karta pokładowa", "karta wejścia na pokład"] },
            { "id": "airport.gate", "term": "gate", "ipa": "/ɡeɪt/", "pos": "rzeczownik", "level": "A2", "frequency": "very_common",
              "translation": "bramka", "definition": "Where you board.", "register": "neutralny", "contextPl": "Wejście",
              "natural": "", "forms": "", "collocations": "", "synonyms": "", "antonyms": "", "notePl": "",
              "examples": [
                { "en": "Our gate changed at the last minute.", "pl": "Nasza bramka zmieniła się w ostatniej chwili.", "focusEn": "gate", "focusPl": "bramka" },
                { "en": "Go to gate twelve.", "pl": "Idź do bramki dwanaście.", "focusEn": "gate", "focusPl": "bramki" }
              ],
              "acceptedAnswers": ["gate"], "acceptedTranslations": ["bramka"] },
            { "id": "airport.gate-2", "term": "gate", "ipa": "/ɡeɪt/", "pos": "rzeczownik", "level": "B1", "frequency": "common",
              "translation": "wyjście do samolotu", "definition": "Exit to the plane.", "register": "neutralny", "contextPl": "Wejście",
              "natural": "", "forms": "", "collocations": "", "synonyms": "", "antonyms": "", "notePl": "",
              "examples": [
                { "en": "The gate closes soon.", "pl": "Wyjście do samolotu wkrótce się zamyka.", "focusEn": "gate", "focusPl": "Wyjście do samolotu" },
                { "en": "We waited at the gate.", "pl": "Czekaliśmy przy wyjściu do samolotu.", "focusEn": "gate", "focusPl": "wyjściu do samolotu" }
              ],
              "acceptedAnswers": ["gate"], "acceptedTranslations": ["wyjście do samolotu"] }
          ] }
      ]
    }
    """

    func testTopicFileDecodesAndConvertsToWords() throws {
        let topic = try ContentDecoder.topicFile(from: Data(topicJSON.utf8))
        XCTAssertEqual(topic.entryCount, 3)
        XCTAssertEqual(topic.entry(id: "airport.gate")?.category.namePl, "Odprawa i bagaż")
        XCTAssertEqual(topic.allEntries.first?.frequency, .common)

        let ids = IDGenerator()
        let result = VocabularyMerger.addTopicEntries(TestData.emptyState(), topic: topic, now: testNow, makeID: ids.next)
        XCTAssertEqual(result.addedMeaningIDs.count, 3)
        XCTAssertEqual(result.state.words.count, 2, "two senses of gate become one word")
        XCTAssertEqual(result.state.words.first?.en, "boarding pass", "topic order is kept")
        XCTAssertEqual(result.state.collections, ["Lotnisko"])
        guard let gate = result.state.word(en: "gate") else { return XCTFail("missing gate") }
        XCTAssertEqual(gate.meanings.count, 2)
        let meaning = gate.meanings[0]
        XCTAssertNil(meaning.enrichment, "built-in meanings are usable offline")
        XCTAssertEqual(meaning.availableExampleCount, 2)
        XCTAssertEqual(meaning.topic, "Odprawa i bagaż")
        XCTAssertEqual(meaning.scene, "Stanowisko odprawy")
        XCTAssertEqual(meaning.exampleFocusPl ?? [], ["bramka", "bramki"])
        XCTAssertEqual(meaning.contentRef, "airport/airport.gate")
        XCTAssertTrue(meaning.scores.isEmpty)
        XCTAssertEqual(VocabularyMerger.addedContentReferences(result.state).count, 3)

        // Practice, then re-add: progress must survive.
        var practiced = result.state
        let task = VocabTask(wordId: gate.id, meaningId: meaning.id, type: .flashcard, example: 0)
        practiced = Scheduler.recordAnswer(practiced, task: task, correct: true, seconds: 3, confidence: 3, hint: false, now: testNow, reviewID: "r")
        let again = VocabularyMerger.addTopicEntries(practiced, topic: topic, now: testNow + day, makeID: ids.next)
        XCTAssertEqual(again.addedMeaningIDs, [])
        XCTAssertEqual(again.skippedExisting, 3)
        XCTAssertEqual(again.state, practiced)
    }

    func testAddSelectedEntriesOnly() throws {
        let topic = try ContentDecoder.topicFile(from: Data(topicJSON.utf8))
        let result = VocabularyMerger.addTopicEntries(TestData.emptyState(), topic: topic, entryIDs: ["airport.gate-2"], collectionOverride: "Moje", now: testNow, makeID: IDGenerator().next)
        XCTAssertEqual(result.state.words.count, 1)
        XCTAssertEqual(result.state.words[0].meanings.map { $0.translation }, ["wyjście do samolotu"])
        XCTAssertEqual(result.state.words[0].collection, "Moje")
    }

    func testMergeSuggestionsKeepsExistingSenseAndProgress() {
        let state = TestData.seed()
        let before = state.word(en: "lend")
        let lookup = Lookup(term: "lend", meanings: [SenseSuggestion(translation: "pożyczyć komuś", collection: "Inna kolekcja")])
        let result = VocabularyMerger.mergeSuggestions(state, lookup: lookup, indices: [0], now: testNow, makeID: IDGenerator().next)
        XCTAssertEqual(result.state.word(en: "lend"), before)
        XCTAssertEqual(result.state.words.count, state.words.count)
        XCTAssertEqual(result.state.reviews, state.reviews)
        XCTAssertEqual(result.skippedExisting, 1)
        // Out-of-range indices are ignored.
        XCTAssertEqual(VocabularyMerger.mergeSuggestions(state, lookup: lookup, indices: [5], now: testNow).state, state)
    }

    func testResolveExistingCollection() {
        XCTAssertEqual(VocabularyMerger.resolveExistingCollection(["W restauracji", "Restauracja", "Podróże"], suggested: "Restauracja", topic: "Restauracja"), "W restauracji")
        XCTAssertEqual(VocabularyMerger.resolveExistingCollection(["W podróży"], suggested: "Podróż", topic: "Podróż"), "W podróży")
        XCTAssertNil(VocabularyMerger.resolveExistingCollection(["Lotnictwo"], suggested: "Lotnisko", topic: "Lotnisko"))
        let lookup = Lookup(term: "reservation", meanings: [SenseSuggestion(topic: "Restauracja", translation: "rezerwacja", collection: "Restauracja")])
        var state = TestData.emptyState()
        state.collections = ["W restauracji"]
        let automatic = VocabularyMerger.mergeSuggestions(state, lookup: lookup, indices: [0], now: testNow, makeID: IDGenerator().next)
        XCTAssertEqual(automatic.state.collections, ["W restauracji"])
        XCTAssertEqual(automatic.state.words.first?.collection, "W restauracji")
        let manual = VocabularyMerger.mergeSuggestions(state, lookup: lookup, indices: [0], collectionOverride: "Moja restauracja", now: testNow, makeID: IDGenerator().next)
        XCTAssertTrue(manual.state.collections.contains("Moja restauracja"))
        XCTAssertEqual(manual.state.words.first?.collection, "Moja restauracja")
    }

    func testDictionaryIndexAndReference() throws {
        let json = """
        { "schemaVersion": 1, "entries": [
          {"t":"à la carte","k":"a la carte","p":"z karty","l":"C1","f":"less_common","r":"restaurant/restaurant.a-la-carte"},
          {"t":"boarding pass","k":"boarding pass","p":"karta pokładowa","l":"A2","f":"common","r":"airport/airport.boarding-pass"}
        ] }
        """
        let index = try ContentDecoder.dictionaryIndex(from: Data(json.utf8))
        XCTAssertEqual(index.entries.count, 2)
        XCTAssertEqual(index.entries[1].contentReference, ContentReference(file: "airport", entryID: "airport.boarding-pass"))
        XCTAssertEqual(index.entries[0].spokenFrequency, .lessCommon)
        XCTAssertNil(ContentReference("no-slash"))
        XCTAssertTrue(ContentReference("starter/starter.borrow")?.isStarter ?? false)
    }

    func testContentSearchKinds() {
        let entries = [
            DictionaryIndex.Entry(term: "boarding pass", translation: "karta pokładowa", level: "A2", frequency: "common", reference: "airport/a"),
            DictionaryIndex.Entry(term: "board", translation: "deska", level: "A2", frequency: "common", reference: "home/b"),
            DictionaryIndex.Entry(term: "board", translation: "wejść na pokład", level: "B1", frequency: "common", reference: "airport/c"),
            DictionaryIndex.Entry(term: "pass", translation: "zdać", level: "A2", frequency: "very_common", reference: "school/d"),
            DictionaryIndex.Entry(term: "luggage", translation: "bagaż", level: "A2", frequency: "common", reference: "airport/e")
        ]
        let search = ContentSearch(entries: entries)
        let board = search.search("Board")
        XCTAssertEqual(board.prefix(2).map { $0.match }, [.exact, .exact])
        XCTAssertEqual(board.first(where: { $0.entry.term == "boarding pass" })?.match, .prefix)
        XCTAssertEqual(search.meanings(of: "board").count, 2)
        XCTAssertEqual(search.search("pass").first?.entry.term, "pass")
        XCTAssertTrue(search.search("pass").contains { $0.entry.term == "boarding pass" && $0.match == .wordPrefix })
        XCTAssertEqual(search.search("bagaz").first?.entry.term, "luggage")
        XCTAssertEqual(search.search("pokład").first?.match, .polish)
        let typo = search.search("lugage")
        XCTAssertEqual(typo.first?.entry.term, "luggage")
        XCTAssertEqual(typo.first?.match, .fuzzy)
        XCTAssertTrue(search.search("   ").isEmpty)
        XCTAssertTrue(search.search("zzzzzz").isEmpty)
        XCTAssertTrue(ContentSearch(entries: []).search("a").isEmpty)
    }

    func testContentSearchPerformanceOn20000Records() {
        var entries: [DictionaryIndex.Entry] = []
        let syllables = ["ka", "lo", "mi", "ter", "pas", "bor", "gan", "die", "son", "rel", "vu", "nex"]
        for index in 0..<20_000 {
            var term = ""
            var value = index
            for _ in 0..<3 {
                term += syllables[value % syllables.count]
                value /= syllables.count
            }
            if index % 4 == 0 { term += " " + syllables[(index / 7) % syllables.count] + "s" }
            entries.append(DictionaryIndex.Entry(term: term, translation: "tłumaczenie \(index)", level: "B1", frequency: "common", reference: "t/\(index)"))
        }
        let start = Date()
        let search = ContentSearch(entries: entries)
        XCTAssertLessThan(Date().timeIntervalSince(start), 5.0)
        let queries = ["kalo", "borpas", "tlumaczenie 1234", "kalomi", "terpasgan", "pas", "zzz", "kalomx"]
        let queryStart = Date()
        for query in queries { _ = search.search(query) }
        let perQuery = Date().timeIntervalSince(queryStart) / Double(queries.count)
        // Target < 5 ms in release builds; generous margin for unoptimised debug test builds.
        XCTAssertLessThan(perQuery, 0.1)
    }

    // MARK: Real content files (skipped when the app resources are not next to the package)

    func testDecodesAllBankFiles() throws {
        let exercises = try ContentDecoder.exercises(from: try TestData.contentData("exercises.json"))
        XCTAssertEqual(Set(exercises.levels.keys), Set(CEFR.levels))
        let idioms = try ContentDecoder.idioms(from: try TestData.contentData("idioms.json"))
        for level in CEFR.levels {
            XCTAssertEqual(idioms.items(level: level).count, 18, level)
            XCTAssertTrue(idioms.items(level: level).allSatisfy { $0.answer == 0 && $0.options.count == 4 })
        }
        let readings = try ContentDecoder.readings(from: try TestData.contentData("readings.json"))
        XCTAssertGreaterThanOrEqual(readings.readings.count, 30)
        XCTAssertTrue(readings.readings.allSatisfy { reading in reading.questions.allSatisfy { $0.answer >= 0 && $0.answer < $0.options.count } })
        let starter = try ContentDecoder.starterWords(from: try TestData.contentData("starter-words.json"))
        XCTAssertFalse(starter.words.isEmpty)
        XCTAssertTrue(starter.words.allSatisfy { $0.examples.count == 2 })
        let recommendations = try ContentDecoder.recommendations(from: try TestData.contentData("recommendations.json"))
        XCTAssertFalse(recommendations.items.isEmpty)
        var total = 0
        for level in CEFR.levels {
            let file = try ContentDecoder.grammarLevel(from: try TestData.contentData("grammar/\(level).json"))
            XCTAssertEqual(file.level, level)
            XCTAssertFalse(file.rules.isEmpty)
            total += file.items.count
        }
        XCTAssertEqual(total, 1_800)
    }

    func testEveryBankItemGradesItsOwnKey() throws {
        let content = try TestData.practiceContent()
        var checked = 0
        for level in CEFR.levels {
            for item in content.productionPool(level: level) {
                XCTAssertTrue(ProductionGrader.grade(item.answer, item: item).correct, "\(level): \(item.answer)")
                for accepted in item.acceptedAnswers {
                    XCTAssertTrue(ProductionGrader.grade(accepted, item: item).correct, "\(level): \(accepted)")
                }
                for wrong in item.distractors {
                    XCTAssertFalse(ProductionGrader.grade(wrong.form, item: item).correct, "\(level): \(item.answer) vs \(wrong.form)")
                }
                let question = PracticeQuestion(acceptedAnswers: item.acceptedAnswers, category: .grammar, prompt: "", context: item.context, options: [item.answer] + item.distractors.map { $0.form }, answer: 0)
                XCTAssertTrue(ProductionGrader.checkPracticeInput(question, value: item.answer + "!").correct, "\(level): \(item.answer)")
                for wrong in item.distractors {
                    XCTAssertFalse(ProductionGrader.checkPracticeInput(question, value: wrong.form).correct, "\(level): \(item.answer) vs \(wrong.form)")
                }
                checked += 1
            }
        }
        XCTAssertGreaterThanOrEqual(checked, 1_800)
    }

    func testIndexAndTopicFilesDecodeWhenPresent() throws {
        let indexData = try TestData.contentData("topics/index.json")
        let index = try ContentDecoder.topicIndex(from: indexData)
        XCTAssertEqual(index.groups.count, 16)
        let dictionary = try ContentDecoder.dictionaryIndex(from: try TestData.contentData("dictionary-index.json"))
        let search = ContentSearch(index: dictionary)
        XCTAssertEqual(search.count, dictionary.entries.count)
        for summary in index.topics.prefix(10) {
            let topic = try ContentDecoder.topicFile(from: try TestData.contentData("topics/\(summary.id).json"))
            XCTAssertEqual(topic.id, summary.id)
            XCTAssertGreaterThan(topic.entryCount, 0)
        }
    }

    func testUnsupportedSchemaVersion() {
        let json = #"{ "schemaVersion": 2, "entries": [] }"#
        XCTAssertThrowsError(try ContentDecoder.dictionaryIndex(from: Data(json.utf8))) { error in
            XCTAssertEqual(error as? ContentError, .unsupportedVersion(file: "dictionary-index.json", version: 2))
        }
        XCTAssertThrowsError(try ContentDecoder.topicFile(from: Data("nope".utf8)))
    }
}
