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

    /// Słownik rdzeniowy (CONTENT-SCHEMA §6): `core-cNN/core.<hasło>` rozwiązuje się przez istniejące API,
    /// także gdy wpis trafił do innego sharda; core nie jest tematem wyszukiwania.
    func testCoreReferencesResolveAndCoreIsNotATopic() async throws {
        let library = try repositoryLibrary()
        let ids = await library.coreFileIDs()
        guard let firstID = ids.first else { throw XCTSkip("Brak plików core/") }
        let core = try await library.topic(id: firstID)
        XCTAssertEqual(core.group, CoreVocabulary.group)
        let entry = try XCTUnwrap(core.allEntries.first)

        let resolved = try await library.entry(reference: "\(core.id)/\(entry.id)")
        XCTAssertEqual(resolved.id, entry.id)
        XCTAssertEqual(resolved.examples.count, entry.examples.count)
        // Stara referencja do innego sharda: wpis odnajdywany po id.
        let moved = try await library.entry(reference: "core-c99/\(entry.id)")
        XCTAssertEqual(moved.id, entry.id)
        do {
            _ = try await library.entry(reference: "\(core.id)/core.no-such-word")
            XCTFail("Oczekiwano błędu")
        } catch is ContentError {
        }

        await library.warmUp()
        let found = await library.lookup(term: entry.term)
        let lookup = try XCTUnwrap(found)
        let sense = try XCTUnwrap(lookup.meanings.first { $0.contentRef == "\(core.id)/\(entry.id)" })
        XCTAssertEqual(sense.collection, CoreVocabulary.collectionName)
        XCTAssertEqual(sense.examples.count, entry.examples.count)
        XCTAssertNil(sense.topic)

        let catalog = await library.topicCatalog()
        XCTAssertNil(catalog.document(id: core.id))
        let matches = await library.rankTopics("słownictwo ogólne")
        XCTAssertFalse(matches.contains { CoreVocabulary.isCoreFile($0.topicID) })
    }

    /// Shardy core dekodowane równolegle, poza aktorem, z cache; indeks core bez dekodowania shardów.
    func testCoreFilesLoadOnceAndCoreDictionaryEntries() async throws {
        let library = try repositoryLibrary()
        let ids = await library.coreFileIDs()
        guard let firstID = ids.first else { throw XCTSkip("Brak plików core/") }
        let wanted = Array(ids.prefix(3))
        async let single: TopicFile = library.topic(id: firstID)
        async let many: [TopicFile] = library.coreFiles(ids: wanted + ["core-c99", "airport"])
        let (one, files) = try await (single, many)
        XCTAssertEqual(files.map { $0.id }, wanted, "missing shards and topics are skipped")
        XCTAssertEqual(files.first, one)
        let again = await library.coreFiles(ids: wanted)
        XCTAssertEqual(again, files)

        let records = await library.coreDictionaryEntries()
        XCTAssertFalse(records.isEmpty)
        XCTAssertTrue(records.allSatisfy { $0.contentReference?.isCore == true })
        let band = AssessmentBand(base: "B1")
        let chosen = AssessmentBuilder.coreFileIDs(entries: records, band: band, available: ids)
        XCTAssertEqual(chosen.count, min(AssessmentBuilder.coreFileLimit, ids.count))
        XCTAssertTrue(chosen.allSatisfy { ids.contains($0) })
    }

    /// Polecane (FEEDBACK-7): wpisy core w puli rankingu, szczegóły z `core/`, dodanie ze wszystkimi przykładami.
    func testCoreRecommendationsHaveDetailsAndAddAllExamples() async throws {
        let library = try repositoryLibrary()
        guard !(await library.coreFileIDs()).isEmpty else { throw XCTSkip("Brak plików core/") }
        let catalog = UsefulWordsCatalog(rootURL: ServicesTestSupport.contentRoot)
        let profile = UsefulWordProfile(level: "B1", targetLevel: "B2")
        let result = await catalog.recommendations(profile: profile, limit: UsefulWordsPaging.poolLimit, seed: 1, content: library)
        let core = result.suggestions.filter { $0.candidate.isCore }
        XCTAssertFalse(core.isEmpty, "core is a source of recommendations")
        for item in core {
            let detail = try XCTUnwrap(result.details[item.id], item.id)
            XCTAssertNotNil(detail.example, item.id)
            XCTAssertNotEqual(detail.register, "slangowy")
        }

        let pick = try XCTUnwrap(core.first)
        let entry = try await library.entry(reference: pick.id)
        let store = await ServicesTestSupport.makeStore(initial: LearnerState())
        let outcome = await UsefulWordsAdder.add([pick.candidate], store: store, content: library)
        XCTAssertEqual(outcome.failed, 0)
        XCTAssertEqual(outcome.addedMeanings, 1)
        let added = await MainActor.run { () -> (collection: String, examples: Int)? in
            for word in store.state.words {
                if let meaning = word.meanings.first(where: { $0.contentRef == pick.id }) {
                    return (collection: word.collection, examples: meaning.examples.count)
                }
            }
            return nil
        }
        let found = try XCTUnwrap(added)
        XCTAssertEqual(found.collection, CoreVocabulary.collectionName)
        XCTAssertEqual(found.examples, entry.examples.count, "all 3–5 examples of the core entry")
        XCTAssertGreaterThanOrEqual(found.examples, CoreVocabulary.exampleRange.lowerBound)
    }

    /// Test poziomujący (FEEDBACK-7): słowa z bazy pochodzą także ze słownika rdzeniowego, tylko z pasma.
    func testLevelTestDrawsBaseWordsFromCore() async throws {
        let library = try repositoryLibrary()
        guard !(await library.coreFileIDs()).isEmpty else { throw XCTSkip("Brak plików core/") }
        var state = LearnerState()
        state.settings.profile = LearnerProfile(startLevel: "B1", levelSource: .selfAssessment)
        let store = await ServicesTestSupport.makeStore(initial: state)
        let built = await TestLoader.makeSession(store: store, content: library)
        guard case .success(let session) = built else { return XCTFail("no test built") }
        XCTAssertEqual(session.band.base, "B1")
        let coreWords = session.bankWords.filter { (word: Word) -> Bool in
            ContentReference(word.meanings.first?.contentRef ?? "")?.isCore == true
        }
        XCTAssertFalse(coreWords.isEmpty, "base words include core vocabulary")
        XCTAssertTrue(coreWords.allSatisfy { $0.collection == CoreVocabulary.collectionName && $0.meanings.first?.topic == nil })
        XCTAssertTrue(session.candidates.allSatisfy { ["A2", "B1", "B2"].contains($0.level) })
        XCTAssertEqual(Set(session.slots), Set(AssessmentBlock.allCases), "every task type")
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
