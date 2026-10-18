import XCTest
import FluentKit
@testable import FluentNOW

/// image-verify: the photo service with a stub classifier (fixed Vision labels per photo) and a
/// stub `URLProtocol` (no network): rejected photos never reach the exercise, the next candidate
/// is tried, old cache entries are re-verified and removed, words without a verified photo end as
/// „bez zdjęcia”.
final class WordImageVerificationServiceTests: XCTestCase {
    override func tearDown() {
        OpenverseStubProtocol.handler = nil
        OpenverseStubProtocol.requests = []
        super.tearDown()
    }

    /// Labels per photo ID; the photo ID is written at the end of each stub JPEG.
    struct StubClassifier: WordImageClassifying {
        var labelsByImage: [String: [WordImageLabel]]
        var identifiers: Set<String> = ["phone", "payphone", "insect", "animal", "people", "chair", "fireplace"]

        func labels(for imageData: Data) async -> [WordImageLabel]? {
            let tail = String(decoding: imageData.suffix(64), as: UTF8.self)
            for (imageID, labels) in labelsByImage where tail.hasSuffix("ID:" + imageID) {
                return labels
            }
            return []
        }

        func taxonomy() async -> Set<String>? {
            identifiers
        }
    }

    private static let phoneLabels = [WordImageLabel(identifier: "phone", confidence: 0.8)]
    private static let insectLabels = [
        WordImageLabel(identifier: "insect", confidence: 0.91),
        WordImageLabel(identifier: "animal", confidence: 0.9)
    ]

    private func temporaryFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("image-verify-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func jpeg(_ imageID: String) -> Data {
        Data([0xFF, 0xD8, 0xFF, 0xE0]) + Data(repeating: 0x11, count: 1_000) + Data("ID:\(imageID)".utf8)
    }

    private static func searchJSON(_ items: [(id: String, title: String, provider: String)]) -> Data {
        let results = items.map { (item: (id: String, title: String, provider: String)) -> String in
            "{\"id\":\"\(item.id)\",\"title\":\"\(item.title)\",\"thumbnail\":\"https://api.openverse.org/v1/images/\(item.id)/thumb/\",\"license\":\"cc0\",\"width\":800,\"height\":600,\"filetype\":\"jpg\",\"provider\":\"\(item.provider)\"}"
        }
        return Data("{\"result_count\":\(items.count),\"results\":[\(results.joined(separator: ","))]}".utf8)
    }

    /// Search → `json`; thumbnail → stub JPEG carrying the photo ID.
    private func stubNetwork(search json: Data) {
        OpenverseStubProtocol.handler = { (request: URLRequest) -> (Int, [String: String], Data) in
            let address = request.url?.absoluteString ?? ""
            if address.contains("/thumb") {
                let parts = request.url?.pathComponents ?? []
                let imageID = parts.count >= 2 ? parts[parts.count - 2] : ""
                return (200, ["Content-Type": "image/jpeg"], WordImageVerificationServiceTests.jpeg(imageID))
            }
            return (200, ["Content-Type": "application/json"], json)
        }
    }

    private func service(folder: URL, classifier: StubClassifier) -> WordImageService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenverseStubProtocol.self]
        return WordImageService(
            networkEnabled: true,
            storeURL: folder.appendingPathComponent("word-images.json"),
            cacheDirectory: folder.appendingPathComponent("cache"),
            session: URLSession(configuration: configuration),
            searchInterval: 0,
            classifier: classifier
        )
    }

    private let phoneCandidate = PictureCandidate(wordId: "w", meaningId: "m", term: "phone", query: "phone")

    func testRejectedPhotoIsReplacedByTheNextVerifiedOne() async throws {
        stubNetwork(search: Self.searchJSON([
            (id: "bug", title: "Phone Hand", provider: "stocksnap"),
            (id: "good", title: "Mobile Phone", provider: "stocksnap")
        ]))
        let folder = temporaryFolder()
        let images = service(folder: folder, classifier: StubClassifier(labelsByImage: ["bug": Self.insectLabels, "good": Self.phoneLabels]))
        let report = await images.prefetch([phoneCandidate])
        XCTAssertEqual(report.searches, 1)
        XCTAssertEqual(report.downloads, 2)
        XCTAssertEqual(report.rejected, 1)
        XCTAssertEqual(report.checks, 2)
        let cached = await images.cachedMeaningIDs()
        XCTAssertEqual(cached, ["m"])
        let image = await images.image(for: "m")
        XCTAssertEqual(image?.record.id, "good")
        XCTAssertEqual(image?.verification?.code, "vision-match")
        XCTAssertEqual(image?.verification?.labels.first?.identifier, "phone")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("cache/bug.jpg").path), "the insect is never stored")
        let diagnostics = await images.diagnostics()
        XCTAssertEqual(diagnostics.verificationRejections, 1)
        XCTAssertEqual(diagnostics.cachedCount, 1)
        XCTAssertTrue(OpenverseStubProtocol.requests.contains { $0.contains("source=rawpixel,stocksnap,wikimedia") }, "first attempt on curated sources")
    }

    func testOldCacheIsHiddenReverifiedAndCleaned() async throws {
        let folder = temporaryFolder()
        let cache = folder.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let old = WordImageRecord(id: "old", title: "phone", thumbnailURL: "https://api.openverse.org/v1/images/old/thumb/", originalURL: "", landingURL: "", creator: "", creatorURL: nil, license: "cc0", licenseVersion: "", licenseURL: "", provider: "flickr", service: "openverse")
        var next = old
        next.id = "next"
        next.title = "Telephone on a desk"
        next.thumbnailURL = "https://api.openverse.org/v1/images/next/thumb/"
        // Assignment written by the previous version: no tags, no verdicts, no attempts.
        let legacy = WordImageAssignment(meaningId: "m", wordId: "w", term: "phone", query: "phone", candidates: [old, next], chosenID: "old", rejectedIDs: [], searchedAt: 1)
        let file = WordImageStoreFile(version: 2, assignments: [legacy])
        try JSONEncoder().encode(file).write(to: folder.appendingPathComponent("word-images.json"))
        try Self.jpeg("old").write(to: cache.appendingPathComponent("old.jpg"))
        stubNetwork(search: Self.searchJSON([]))
        let images = service(folder: folder, classifier: StubClassifier(labelsByImage: ["old": Self.insectLabels, "next": Self.phoneLabels]))
        let before = await images.cachedMeaningIDs()
        XCTAssertTrue(before.isEmpty, "an unverified photo is never shown")
        let awaiting = await images.diagnostics().awaitingCheckCount
        XCTAssertEqual(awaiting, 1)
        let report = await images.prefetch([phoneCandidate])
        XCTAssertEqual(report.searches, 0, "the next candidate is used, no new search")
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.appendingPathComponent("old.jpg").path), "the wrong photo is deleted")
        let after = await images.image(for: "m")
        XCTAssertEqual(after?.record.id, "next")
        XCTAssertEqual(after?.verification?.rulesVersion, WordImageVerifier.rulesVersion)
    }

    func testOldCacheIsCleanedEvenOffline() async throws {
        let folder = temporaryFolder()
        let cache = folder.appendingPathComponent("cache", isDirectory: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let old = WordImageRecord(id: "old", title: "phone", thumbnailURL: "https://api.openverse.org/v1/images/old/thumb/", originalURL: "", landingURL: "", creator: "", creatorURL: nil, license: "cc0", licenseVersion: "", licenseURL: "", provider: "flickr", service: "openverse")
        let legacy = WordImageAssignment(meaningId: "m", wordId: "w", term: "phone", query: "phone", candidates: [old], chosenID: "old", rejectedIDs: [], searchedAt: 1)
        try JSONEncoder().encode(WordImageStoreFile(version: 2, assignments: [legacy])).write(to: folder.appendingPathComponent("word-images.json"))
        try Self.jpeg("old").write(to: cache.appendingPathComponent("old.jpg"))
        // No handler: every request fails as „offline”.
        let images = service(folder: folder, classifier: StubClassifier(labelsByImage: ["old": Self.insectLabels]))
        let report = await images.prefetch([phoneCandidate])
        XCTAssertEqual(report.stop, .offline)
        XCTAssertEqual(report.rejected, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cache.appendingPathComponent("old.jpg").path))
    }

    func testExcludedWordIsNeverSearched() async {
        stubNetwork(search: Self.searchJSON([(id: "v", title: "Voucher", provider: "rawpixel")]))
        let images = service(folder: temporaryFolder(), classifier: StubClassifier(labelsByImage: [:]))
        let voucher = PictureCandidate(wordId: "w", meaningId: "v", term: "voucher", query: "voucher")
        let report = await images.prefetch([voucher])
        XCTAssertEqual(report.searches, 0)
        XCTAssertTrue(OpenverseStubProtocol.requests.isEmpty)
        let unavailable = await images.unavailableMeaningIDs()
        XCTAssertEqual(unavailable, ["v"])
        let settled = await images.settledMeaningIDs()
        XCTAssertTrue(settled.contains("v"))
        let diagnostics = await images.diagnostics()
        XCTAssertEqual(diagnostics.noPhotoCount, 1)
    }

    func testNoVerifiedPhotoAfterAllAttemptsMeansNoPhotoForGood() async {
        stubNetwork(search: Self.searchJSON([(id: "x", title: "Phone", provider: "flickr")]))
        let images = service(folder: temporaryFolder(), classifier: StubClassifier(labelsByImage: ["x": Self.insectLabels]))
        for _ in 0..<3 {
            await images.prefetch([phoneCandidate])
        }
        let searches = OpenverseStubProtocol.requests.filter { !$0.contains("/thumb") }
        XCTAssertEqual(searches.count, 3)
        XCTAssertTrue(searches[2].contains("q=telephone"), "the last attempt uses the synonym")
        let downloads = OpenverseStubProtocol.requests.filter { $0.contains("/thumb") }
        XCTAssertEqual(downloads.count, 1, "a rejected photo is never downloaded again")
        let unavailable = await images.unavailableMeaningIDs()
        XCTAssertEqual(unavailable, ["m"])
        OpenverseStubProtocol.requests = []
        let again = await images.prefetch([phoneCandidate])
        XCTAssertEqual(again.searches, 0, "no more searches for this meaning")
    }

    func testReportCarriesVisionLabelsAndReason() {
        let record = WordImageRecord(id: "a1", title: "Mobile Phone", thumbnailURL: "https://api.openverse.org/v1/images/a1/thumb/", originalURL: "", landingURL: "", creator: "", creatorURL: nil, license: "cc0", licenseVersion: "", licenseURL: "", provider: "stocksnap", service: "openverse")
        let verdict = WordImageVerification(
            imageID: "a1", accepted: true, code: "vision-match", reason: "Vision rozpoznał „phone” (80%).",
            labels: [WordImageLabel(identifier: "phone", confidence: 0.8)], metadataMatch: 2, usedVision: true,
            rulesVersion: WordImageVerifier.rulesVersion, checkedAt: 1
        )
        let report = ImageReport(term: "phone", meaning: "telefon", wordId: "w", meaningId: "m", record: record, verification: verdict, comment: "owad")
        XCTAssertEqual(report.visionLabels, ["phone 80%"])
        XCTAssertEqual(report.verificationCode, "vision-match")
        XCTAssertEqual(report.verifiedWithVision, true)
        XCTAssertEqual(report.imageTitle, "Mobile Phone")
        let plain = ImageReport(term: "phone", meaning: "telefon", wordId: "w", meaningId: "m", record: record)
        XCTAssertNil(plain.visionLabels)
    }

    func testOldFilesDecodeWithTheNewFields() throws {
        let json = """
        {"version":2,"blockedUntil":0,"assignments":[
          {"meaningId":"m1","wordId":"w1","term":"apple","query":"apple","candidates":[
            {"id":"a","title":"Apple","thumbnailURL":"https://a","originalURL":"","landingURL":"","creator":"","license":"cc0","licenseVersion":"","licenseURL":"","provider":"flickr","service":"openverse"}
          ],"chosenID":"a","rejectedIDs":[],"searchedAt":1}
        ]}
        """
        let file = try JSONDecoder().decode(WordImageStoreFile.self, from: Data(json.utf8))
        XCTAssertEqual(file.verificationRejections, 0)
        let assignment = try XCTUnwrap(file.assignments.first)
        XCTAssertNil(assignment.candidates.first?.tags)
        XCTAssertNil(assignment.searchAttempts)
        XCTAssertFalse(assignment.hasVerifiedChoice, "saved before verification → must be checked again")
        let reports = """
        [{"id":"r","createdAt":1,"term":"apple","meaning":"jabłko","wordId":"w","meaningId":"m","imageID":"a","imageURL":"","originalURL":"","landingURL":"","source":"openverse/flickr","license":"CC0","comment":""}]
        """
        let decoded = try JSONDecoder().decode([ImageReport].self, from: Data(reports.utf8))
        XCTAssertNil(decoded.first?.visionLabels)
    }
}
