import XCTest
import FluentKit
@testable import FluentNOW

/// FEEDBACK-3: H1 (one answer mechanism), H2 (photo prefetch, limits, diagnostics), H3 (flashcard faces).
/// Network is never used: the photo service gets a `URLSession` with a stub `URLProtocol`.
final class StudyPolishAppTests: XCTestCase {
    override func tearDown() {
        OpenverseStubProtocol.handler = nil
        OpenverseStubProtocol.requests = []
        super.tearDown()
    }

    // MARK: H1 — „Wybierz znaczenie”

    @MainActor
    private func meaningModel(practiced: Bool, options: [String]) throws -> VocabExerciseModel {
        var word = ServicesTestSupport.word("a", en: "chair", pl: "krzesło")
        if practiced {
            word.meanings[0].scores[.recognition] = Score(correct: 1)
        }
        let state = LearnerState(words: [word])
        let task = VocabTask(wordId: "a", meaningId: "a.m1", type: .meaning, example: 0)
        let content = try XCTUnwrap(VocabExerciseContent(task: task, mode: .mixed, state: state, variants: .builtIn))
        return VocabExerciseModel(content: content, key: "k", options: options, variants: .builtIn, assistant: nil)
    }

    @MainActor
    func testVisibleOptionsMeanChoiceOnly() throws {
        let model = try meaningModel(practiced: false, options: ["stół", "krzesło", "lampa", "okno"])
        XCTAssertEqual(model.inputStyle, .choice, "first contact: options at once, no text field")
        XCTAssertEqual(model.correctOption, 1)
        model.answer = "krzesło"
        model.check()
        XCTAssertEqual(model.phase, .answering, "typing is not an answer while options are shown")
        model.chooseOption(at: 0)
        XCTAssertEqual(model.phase, .retry)
        XCTAssertEqual(model.wrongOptions, [0])
        model.chooseOption(at: 0)
        XCTAssertEqual(model.wrongOptions, [0], "a wrong option is blocked in the second try")
        model.chooseOption(at: 1)
        XCTAssertEqual(model.phase, .finished)
        XCTAssertEqual(model.outcome?.correct, true)
        XCTAssertEqual(model.outcome?.value, "krzesło")
        XCTAssertEqual(model.outcome?.hinted, model.hintShown)
    }

    @MainActor
    func testShowingVariantsSwitchesFromTypingToChoice() throws {
        let model = try meaningModel(practiced: true, options: ["stół", "krzesło", "lampa", "okno"])
        XCTAssertEqual(model.inputStyle, .typing, "later contact: type from memory")
        model.answer = "krzes"
        model.showVariants()
        XCTAssertEqual(model.inputStyle, .choice)
        XCTAssertEqual(model.answer, "", "the typed text disappears with the field")
        model.chooseOption(at: 1)
        XCTAssertEqual(model.outcome?.correct, true)
        XCTAssertEqual(model.outcome?.hinted, true, "variants on request count as help")
    }

    @MainActor
    func testWrongOptionIsNeverATypo() throws {
        // „krzesła” is one letter away from „krzesło” — as a typed answer it might be a typo,
        // as a chosen option it is simply wrong.
        let model = try meaningModel(practiced: false, options: ["krzesła", "krzesło", "lampa", "okno"])
        model.chooseOption(at: 0)
        model.giveUp()
        XCTAssertEqual(model.outcome?.correct, false)
        XCTAssertNil(model.grade?.closestAnswer)
    }

    @MainActor
    func testSingleOptionFallsBackToTyping() throws {
        let model = try meaningModel(practiced: false, options: ["krzesło"])
        XCTAssertEqual(model.inputStyle, .typing)
    }

    // MARK: H3 — flashcard faces

    func testFlashcardFacesSwapLanguages() {
        let word = ServicesTestSupport.word("a", en: "chair", pl: "krzesło")
        let english = FlashcardFaces(word: word, meaning: word.meanings[0], frontIsPolish: false)
        XCTAssertEqual(english.front, FlashcardFace(text: "chair", isEnglish: true))
        XCTAssertEqual(english.back, FlashcardFace(text: "krzesło", isEnglish: false))
        let polish = FlashcardFaces(word: word, meaning: word.meanings[0], frontIsPolish: true)
        XCTAssertEqual(polish.front.text, "krzesło")
        XCTAssertTrue(polish.back.isEnglish)
        XCTAssertEqual(polish.englishText, "chair")
    }

    // MARK: H2 — prefetch

    private func temporaryFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("study-polish-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func stubbedService(folder: URL) -> WordImageService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenverseStubProtocol.self]
        return WordImageService(
            networkEnabled: true,
            storeURL: folder.appendingPathComponent("word-images.json"),
            cacheDirectory: folder.appendingPathComponent("cache"),
            session: URLSession(configuration: configuration),
            searchInterval: 0
        )
    }

    private static let searchJSON = """
    {"result_count":1,"results":[{"id":"img-1","title":"Wooden chair","thumbnail":"https://api.openverse.org/v1/images/img-1/thumb/","license":"cc0","width":640,"height":480,"filetype":"jpg"}]}
    """

    private static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x11, count: 2_000)

    func testPrefetchSearchesDownloadsAndCountsTowardTheDailyLimit() async {
        OpenverseStubProtocol.handler = { (request: URLRequest) -> (Int, [String: String], Data) in
            // `URL.path` drops the trailing slash — compare the whole address.
            let address = request.url?.absoluteString ?? ""
            if address.contains("/thumb") {
                return (200, ["Content-Type": "image/jpeg"], StudyPolishAppTests.jpeg)
            }
            return (200, ["Content-Type": "application/json"], Data(StudyPolishAppTests.searchJSON.utf8))
        }
        let service = stubbedService(folder: temporaryFolder())
        let candidate = PictureCandidate(wordId: "w", meaningId: "m", term: "chair", query: "chair")
        let report = await service.prefetch([candidate])
        XCTAssertEqual(report.stop, .finished)
        XCTAssertEqual(report.searches, 1)
        XCTAssertEqual(report.downloads, 1)
        let cached = await service.cachedMeaningIDs()
        XCTAssertEqual(cached, ["m"])
        let diagnostics = await service.diagnostics()
        XCTAssertEqual(diagnostics.cachedCount, 1)
        XCTAssertEqual(diagnostics.searchesToday, 1)
        XCTAssertEqual(diagnostics.downloadsToday, 1)
        XCTAssertNil(diagnostics.lastError)
        XCTAssertGreaterThan(diagnostics.lastRunAt, 0)
        let again = await service.prefetch([candidate])
        XCTAssertEqual(again.searches, 0, "a cached photo is never searched again")
        XCTAssertTrue(OpenverseStubProtocol.requests.contains { $0.contains("license=cc0,by,by-sa") })
    }

    func testRateLimitStopsTheRunAndBlocksFurtherSearches() async {
        OpenverseStubProtocol.handler = { (_: URLRequest) -> (Int, [String: String], Data) in
            (429, ["Retry-After": "120"], Data())
        }
        let service = stubbedService(folder: temporaryFolder())
        let candidates = [
            PictureCandidate(wordId: "w1", meaningId: "m1", term: "chair", query: "chair"),
            PictureCandidate(wordId: "w2", meaningId: "m2", term: "lamp", query: "lamp")
        ]
        let report = await service.prefetch(candidates)
        XCTAssertEqual(report.stop, .rateLimited)
        XCTAssertEqual(report.searches, 1, "the second word is not searched after HTTP 429")
        let diagnostics = await service.diagnostics()
        XCTAssertGreaterThan(diagnostics.blockedUntil, FluentClock.now())
        XCTAssertNotNil(diagnostics.lastError)
        OpenverseStubProtocol.requests = []
        let blocked = await service.prefetch(candidates)
        XCTAssertEqual(blocked.stop, .rateLimited)
        XCTAssertTrue(OpenverseStubProtocol.requests.isEmpty, "no request at all until Retry-After")
    }

    func testOfflineServiceReportsDisabled() async {
        let folder = temporaryFolder()
        let service = WordImageService(networkEnabled: false, storeURL: folder.appendingPathComponent("w.json"), cacheDirectory: folder)
        let report = await service.prefetch([PictureCandidate(wordId: "w", meaningId: "m", term: "chair", query: "chair")])
        XCTAssertEqual(report.stop, .disabled)
        let diagnostics = await service.diagnostics()
        XCTAssertFalse(diagnostics.networkEnabled)
    }

    func testOldStoreFileDecodesWithEmptyCounters() throws {
        let json = """
        {"version":1,"blockedUntil":0,"assignments":[]}
        """
        let file = try JSONDecoder().decode(WordImageStoreFile.self, from: Data(json.utf8))
        XCTAssertEqual(file.searchesToday, 0)
        XCTAssertEqual(file.downloadsToday, 0)
        XCTAssertNil(file.lastError)
        let encoded = try JSONEncoder().encode(WordImageStoreFile(searchesToday: 3, lastError: "x"))
        let decoded = try JSONDecoder().decode(WordImageStoreFile.self, from: encoded)
        XCTAssertEqual(decoded.searchesToday, 3)
        XCTAssertEqual(decoded.lastError, "x")
    }

    @MainActor
    func testPrefetcherContinuesOnlyWhileThereIsProgressAndWork() {
        var report = WordImagePrefetchReport(searches: 12, downloads: 10, stop: .runLimit)
        XCTAssertEqual(WordImagePrefetcher.pause(after: report, candidateCount: 24, limit: 24, rerun: false), WordImagePrefetcher.pauseNanoseconds)
        report = WordImagePrefetchReport(searches: 3, downloads: 3, stop: .finished)
        XCTAssertNil(WordImagePrefetcher.pause(after: report, candidateCount: 3, limit: 24, rerun: false), "everything done")
        XCTAssertNotNil(WordImagePrefetcher.pause(after: report, candidateCount: 3, limit: 24, rerun: true), "words were added meanwhile")
        report = WordImagePrefetchReport(searches: 0, downloads: 0, stop: .finished)
        XCTAssertNil(WordImagePrefetcher.pause(after: report, candidateCount: 24, limit: 24, rerun: true), "no progress — no loop")
        for stop in [WordImagePrefetchReport.Stop.offline, .rateLimited, .dailyLimit, .cancelled, .disabled] {
            XCTAssertNil(WordImagePrefetcher.pause(after: WordImagePrefetchReport(searches: 1, downloads: 1, stop: stop), candidateCount: 24, limit: 24, rerun: true))
        }
        XCTAssertEqual(WordImagePrefetcher.pause(after: WordImagePrefetchReport(stop: .busy), candidateCount: 1, limit: 24, rerun: false), WordImagePrefetcher.busyPauseNanoseconds)
        XCTAssertEqual(WordImagePrefetcher.statusAfter(.offline), .offline)
        XCTAssertEqual(WordImagePrefetcher.statusAfter(.dailyLimit), .waiting)
        // ≥ 3.5 s between searches and 12 per run: never more than 20 per minute.
        XCTAssertLessThanOrEqual(60 / WordImageService.defaultSearchInterval, 20)
        XCTAssertLessThan(WordImageService.maxSearchesPerDay, 200)
    }
}

/// Answers requests of the photo service without network.
final class OpenverseStubProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, [String: String], Data))?
    static var requests: [String] = []

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url, let handler = OpenverseStubProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        OpenverseStubProtocol.requests.append(url.absoluteString)
        let (status, headers, data) = handler(request)
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
