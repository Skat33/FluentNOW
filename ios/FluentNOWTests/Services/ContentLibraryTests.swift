import XCTest
import FluentKit
@testable import FluentNOW

/// Integralność treści wbudowanej i API `ContentLibrary` (repozytorium oraz bundle aplikacji).
final class ContentLibraryTests: XCTestCase {

    private func repositoryLibrary() throws -> ContentLibrary {
        let root = ServicesTestSupport.contentRoot
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("topics/index.json").path) else {
            throw XCTSkip("Brak treści w \(root.path)")
        }
        return ContentLibrary(rootURL: root)
    }

    func testEveryContentFileDecodes() async throws {
        let library = try repositoryLibrary()
        let problems = await library.validateAll()
        XCTAssertEqual(problems, [], problems.joined(separator: "\n"))
    }

    /// Treść faktycznie trafia do bundla (referencja folderowa `Content/`).
    func testBundleContainsContent() async throws {
        let library = ContentLibrary(bundle: .main)
        let available = await library.isAvailable
        XCTAssertTrue(available, "Brak katalogu Content/ w bundlu aplikacji — sprawdź project.yml (type: folder)")
        guard available else { return }
        let problems = await library.validateAll()
        XCTAssertEqual(problems, [], problems.joined(separator: "\n"))
    }

    func testTopicsLoadAndEntriesResolve() async throws {
        let library = try repositoryLibrary()
        let index = try await library.topicIndex()
        XCTAssertFalse(index.topics.isEmpty)
        let first = try XCTUnwrap(index.topics.first)
        let topic = try await library.topic(id: first.id)
        XCTAssertEqual(topic.id, first.id)
        XCTAssertEqual(topic.entryCount, first.entryCount)
        let entry = try XCTUnwrap(topic.allEntries.first)
        let resolved = try await library.entry(reference: "\(topic.id)/\(entry.id)")
        XCTAssertEqual(resolved.id, entry.id)
    }

    func testMissingAndUnsafeFilesGiveContentError() async throws {
        let library = try repositoryLibrary()
        do {
            _ = try await library.topic(id: "no-such-topic")
            XCTFail("Oczekiwano błędu")
        } catch let error as ContentError {
            XCTAssertNotNil(error.errorDescription)
        }
        do {
            _ = try await library.topic(id: "../answer-variants")
            XCTFail("Oczekiwano błędu")
        } catch is ContentError {
        }
        XCTAssertFalse(ContentLibrary.isSafeFileName("../x"))
        XCTAssertTrue(ContentLibrary.isSafeFileName("airport"))
    }

    func testMissingRootDoesNotCrash() async {
        let library = ContentLibrary(rootURL: nil)
        let hits = await library.search("gate", limit: 5)
        XCTAssertTrue(hits.isEmpty)
        let lookup = await library.lookup(term: "gate")
        XCTAssertNil(lookup)
        let variants = await library.answerVariants()
        XCTAssertEqual(variants, .builtIn)
        let starter = await library.starterWords()
        XCTAssertTrue(starter.isEmpty)
        do {
            _ = try await library.topicIndex()
            XCTFail("Oczekiwano błędu")
        } catch {
            XCTAssertTrue(error is ContentError)
        }
    }

    func testSearchAndLookupAfterWarmUp() async throws {
        let library = try repositoryLibrary()
        await library.warmUp()
        let ready = await library.isSearchReady
        XCTAssertTrue(ready)
        let hits = await library.search("boarding pass", limit: 10)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertEqual(hits.first?.entry.term, "boarding pass")

        let found = await library.lookup(term: "boarding pass")
        let lookup = try XCTUnwrap(found)
        XCTAssertTrue(lookup.exists)
        XCTAssertFalse(lookup.meanings.isEmpty)
        XCTAssertTrue(lookup.meanings.allSatisfy { $0.contentRef != nil })

        let polish = await library.search("karta pokładowa", limit: 10)
        XCTAssertTrue(polish.contains { $0.entry.term == "boarding pass" })
    }

    func testPracticeContentAndStarter() async throws {
        let library = try repositoryLibrary()
        let content = try await library.practiceContent(level: "B1")
        XCTAssertFalse(content.productionPool(level: "B1").isEmpty)
        XCTAssertFalse(content.idiomPool(level: "B1").isEmpty)
        XCTAssertFalse(content.readings.readings.isEmpty)
        let fallback = try await library.practiceContent(level: "zły poziom")
        XCTAssertFalse(fallback.productionPool(level: "A2").isEmpty)

        let starter = await library.starterWords()
        XCTAssertFalse(starter.isEmpty)
        let recommendations = await library.recommendations()
        XCTAssertFalse(recommendations.isEmpty)
        let variants = await library.answerVariants()
        XCTAssertFalse(variants.polishSenseVariants.isEmpty)
    }

    func testAddingTopicThroughStore() async throws {
        let library = try repositoryLibrary()
        let index = try await library.topicIndex()
        let summary = try XCTUnwrap(index.topics.first)
        let topic = try await library.topic(id: summary.id)
        let store = await ServicesTestSupport.makeStore(initial: LearnerState())
        let added = await MainActor.run { () -> Int in
            let now = store.now()
            let result = store.update(.bulk) { (state: inout LearnerState) -> MergeResult in
                let merged = VocabularyMerger.addTopicEntries(state, topic: topic, now: now)
                state = merged.state
                return merged
            }
            return result.addedMeaningIDs.count
        }
        XCTAssertGreaterThan(added, 0)
        XCTAssertLessThanOrEqual(added, topic.entryCount)
    }
}
