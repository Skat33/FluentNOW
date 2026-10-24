import XCTest
@testable import FluentKit

/// Core vocabulary (CONTENT-SCHEMA §6): ids, paths, decoding, validator, adding with all examples.
final class CoreVocabularyTests: XCTestCase {

    // MARK: Helpers

    private func example(_ index: Int, term: String) -> ExamplePair {
        ExamplePair(
            en: "Example number \(index) uses the word \(term) in a sentence.",
            pl: "Przykład numer \(index) używa słowa w zdaniu.",
            focusEn: term,
            focusPl: "słowa"
        )
    }

    private func coreEntry(id: String = "core.attain", term: String = "attain", translation: String = "osiągnąć", examples: Int = 4) -> TopicEntry {
        TopicEntry(
            id: id,
            term: term,
            ipa: "/əˈteɪn/",
            pos: "czasownik",
            level: "C1",
            frequency: .lessCommon,
            translation: translation,
            definition: "To succeed in reaching a goal or level.",
            register: "formalny",
            contextPl: "Formalnie o osiąganiu celu",
            forms: "attain – attained – attained",
            examples: (0..<examples).map { (index: Int) -> ExamplePair in example(index + 1, term: term) },
            acceptedAnswers: [term],
            acceptedTranslations: [translation]
        )
    }

    private func coreTopic(_ entries: [TopicEntry], id: String = "core-c01") -> TopicFile {
        TopicFile(
            id: id,
            namePl: CoreVocabulary.collectionName,
            nameEn: "Core vocabulary",
            group: CoreVocabulary.group,
            symbol: "character.book.closed",
            summaryPl: "Słownik rdzeniowy.",
            categories: [TopicCategory(id: "\(id).c1", namePl: "Słownictwo ogólne C1", scenePl: "", entries: entries)]
        )
    }

    // MARK: Ids and paths

    func testCoreFileIDsAndReferences() {
        XCTAssertTrue(CoreVocabulary.isCoreFile("core-c01"))
        XCTAssertTrue(CoreVocabulary.isCoreFile("core-c12"))
        XCTAssertFalse(CoreVocabulary.isCoreFile("core-c"))
        XCTAssertFalse(CoreVocabulary.isCoreFile("core-cx1"))
        XCTAssertFalse(CoreVocabulary.isCoreFile("core"))
        XCTAssertFalse(CoreVocabulary.isCoreFile("airport"))
        XCTAssertTrue(CoreVocabulary.isCoreEntryID("core.maintain-2"))
        XCTAssertFalse(CoreVocabulary.isCoreEntryID("core."))
        XCTAssertFalse(CoreVocabulary.isCoreEntryID("airport.gate"))

        let core = ContentReference("core-c01/core.attain")
        XCTAssertEqual(core?.isCore, true)
        XCTAssertEqual(core?.isStarter, false)
        XCTAssertEqual(core?.entryID, "core.attain")
        XCTAssertEqual(core?.relativePath, "core/core-c01.json")
        XCTAssertEqual(ContentReference("airport/airport.gate")?.isCore, false)
        XCTAssertEqual(ContentReference("airport/airport.gate")?.relativePath, "topics/airport.json")
        XCTAssertEqual(ContentReference("starter/starter.do")?.relativePath, "starter-words.json")

        XCTAssertEqual(
            CoreVocabulary.fileIDs(fromFileNames: ["core-c02.json", "notes.md", "core-c01.json", "core-x.json", "core-c03.txt"]),
            ["core-c01", "core-c02"]
        )
        XCTAssertTrue(CoreVocabulary.isCore(coreTopic([])))
        XCTAssertFalse(CoreVocabulary.isCore(TopicFile(id: "airport", namePl: "Lotnisko", group: "travel")))
    }

    // MARK: Validator

    func testValidatorAcceptsThreeToFiveExamplesForCore() {
        for count in 3...5 {
            XCTAssertEqual(CoreVocabulary.entryIssues(coreEntry(examples: count)), [], "\(count) examples")
        }
        XCTAssertTrue(CoreVocabulary.entryIssues(coreEntry(examples: 2)).contains("Wymagane 3–5 przykładów."))
        XCTAssertTrue(CoreVocabulary.entryIssues(coreEntry(examples: 6)).contains("Wymagane 3–5 przykładów."))
        XCTAssertFalse(CoreVocabulary.entryIssues(coreEntry(id: "airport.attain")).isEmpty, "core entries need the core. prefix")
        // Topic entries keep the exact-2 rule.
        XCTAssertTrue(TopicEntryValidator.issues(coreEntry(examples: 4)).contains("Wymagane dokładnie 2 przykłady."))
        XCTAssertEqual(TopicEntryValidator.issues(coreEntry(examples: 2)), [])

        var repeated = coreEntry(examples: 3)
        repeated.examples[2] = repeated.examples[0]
        XCTAssertTrue(CoreVocabulary.entryIssues(repeated).contains("Przykłady się powtarzają."))
    }

    // MARK: Adding

    func testAddingCoreEntryKeepsAllExamplesAndUsesCoreCollection() throws {
        let topic = coreTopic([coreEntry(examples: 5)])
        let result = VocabularyMerger.addTopicEntries(TestData.emptyState(), topic: topic, now: testNow, makeID: IDGenerator().next)
        XCTAssertEqual(result.addedMeaningIDs.count, 1)
        XCTAssertEqual(result.state.collections, [CoreVocabulary.collectionName])
        let word = try XCTUnwrap(result.state.words.first)
        XCTAssertEqual(word.en, "attain")
        XCTAssertEqual(word.collection, CoreVocabulary.collectionName)
        let meaning = try XCTUnwrap(word.meanings.first)
        XCTAssertEqual(meaning.examples.count, 5)
        XCTAssertEqual(meaning.exampleTranslations?.count, 5)
        XCTAssertEqual(meaning.exampleFocusEn?.count, 5)
        XCTAssertNil(meaning.enrichment, "built-in meanings are usable offline")
        XCTAssertEqual(meaning.availableExampleCount, 5, "ExamplePool uses every example of a core meaning")
        XCTAssertEqual(meaning.contentRef, "core-c01/core.attain")
        XCTAssertNil(meaning.topic, "core categories are CEFR bands, not situations")
        XCTAssertNil(meaning.scene)

        // Unused examples rotate through all five.
        var used = meaning
        var seen: [Int] = []
        for _ in 0..<5 {
            let next = ExamplePool.nextUnusedExample(used)
            seen.append(next)
            used.usedExamples = (used.usedExamples ?? []) + [next]
        }
        XCTAssertEqual(seen, [0, 1, 2, 3, 4])
    }

    func testCoreSuggestionAndLookupKeepEveryExample() {
        let entry = coreEntry(examples: 4)
        let suggestion = VocabularyMerger.suggestion(from: entry, topicName: CoreVocabulary.collectionName, reference: "core-c01/core.attain")
        XCTAssertEqual(suggestion.examples.count, 4)
        XCTAssertEqual(suggestion.collection, CoreVocabulary.collectionName)
        let lookup = VocabularyMerger.lookup(term: "attain", entries: [(entry: entry, suggestion: suggestion)])
        let merged = VocabularyMerger.mergeSuggestions(TestData.emptyState(), lookup: lookup, indices: [0], now: testNow, makeID: IDGenerator().next)
        XCTAssertEqual(merged.state.words.first?.meanings.first?.examples.count, 4)
    }

    // MARK: Real content

    private func coreFiles() throws -> [(name: String, topic: TopicFile)] {
        let directory = TestData.contentDirectory.appendingPathComponent(CoreVocabulary.directory)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            throw XCTSkip("Brak katalogu core/")
        }
        var files: [(name: String, topic: TopicFile)] = []
        for id in CoreVocabulary.fileIDs(fromFileNames: names) {
            let data = try Data(contentsOf: directory.appendingPathComponent("\(id).json"))
            files.append((name: id, topic: try ContentDecoder.coreFile(from: data)))
        }
        guard !files.isEmpty else { throw XCTSkip("Brak plików core") }
        return files
    }

    func testEveryCoreFileDecodesAndPassesTheValidator() throws {
        var ids = Set<String>()
        var problems: [String] = []
        for (name, topic) in try coreFiles() {
            XCTAssertEqual(topic.id, name)
            XCTAssertEqual(topic.group, CoreVocabulary.group)
            XCTAssertEqual(topic.namePl, CoreVocabulary.collectionName)
            XCTAssertTrue(CoreVocabulary.isCore(topic))
            for entry in topic.allEntries {
                XCTAssertTrue(ids.insert(entry.id).inserted, "duplicate core id \(entry.id)")
                XCTAssertTrue(CoreVocabulary.exampleRange.contains(entry.examples.count), entry.id)
                let issues = CoreVocabulary.entryIssues(entry)
                if !issues.isEmpty && problems.count < 20 {
                    problems.append("\(entry.id): \(issues.joined(separator: " "))")
                }
            }
        }
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "\n"))
    }

    func testCoreEntriesAreInTheDictionaryIndexButNotInTheTopicIndex() throws {
        let files = try coreFiles()
        let dictionary = try ContentDecoder.dictionaryIndex(from: TestData.contentData("dictionary-index.json"))
        let references = Set(dictionary.entries.map { $0.reference })
        for (name, topic) in files {
            for entry in topic.allEntries {
                XCTAssertTrue(references.contains("\(name)/\(entry.id)"), "\(name)/\(entry.id) missing from dictionary-index.json")
            }
        }
        let search = ContentSearch(index: dictionary)
        XCTAssertTrue(search.meanings(of: "attain").contains { $0.contentReference?.isCore == true })

        let topics = try ContentDecoder.topicIndex(from: TestData.contentData("topics/index.json"))
        XCTAssertFalse(topics.topics.contains { CoreVocabulary.isCoreFile($0.id) || $0.group == CoreVocabulary.group })
    }
}
