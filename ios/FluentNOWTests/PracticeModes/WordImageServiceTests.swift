import XCTest
import FluentKit
@testable import FluentNOW

/// G2: parsing Openverse results, image signature check, tolerant assignment file, reports.
/// No network: the service is created with `networkEnabled: false` and temporary folders.
final class WordImageServiceTests: XCTestCase {
    private func temporaryFolder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("word-images-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private let sampleJSON = """
    {"result_count":5,"results":[
      {"id":"a1","title":"Red apple on a table","url":"https://live.staticflickr.com/1/a.jpg","thumbnail":"https://api.openverse.org/v1/images/a1/thumb/","foreign_landing_url":"https://www.flickr.com/photos/x/1","creator":"Jan","creator_url":"https://www.flickr.com/photos/x","license":"by","license_version":"2.0","license_url":"https://creativecommons.org/licenses/by/2.0/","provider":"flickr","source":"flickr","width":800,"height":600,"filetype":"jpg","mature":false,"tags":[]},
      {"id":"nc","title":"apple","thumbnail":"https://api.openverse.org/v1/images/nc/thumb/","license":"by-nc","width":800,"height":600},
      {"id":"m","title":"apple","thumbnail":"https://api.openverse.org/v1/images/m/thumb/","license":"cc0","mature":true},
      {"id":"thin","title":"apple panorama","thumbnail":"https://api.openverse.org/v1/images/thin/thumb/","license":"cc0","width":3000,"height":300},
      {"id":"b2","title":"Orchard","thumbnail":"https://api.openverse.org/v1/images/b2/thumb/","license":"by-sa","license_version":"4.0","width":640,"height":640,"tags":[{"name":"fruit"}]},
      {"id":"c3","title":"Fruit bowl","thumbnail":"https://api.openverse.org/v1/images/c3/thumb/","license":"cc0","width":640,"height":480,"tags":[{"name":"apple"}]},
      {"id":"gif","title":"apple","thumbnail":"https://api.openverse.org/v1/images/gif/thumb/","license":"cc0","filetype":"gif"}
    ]}
    """

    func testParseKeepsAllowedLicensesAndPutsMentionedFirst() throws {
        let records = try OpenverseClient.parseSearch(Data(sampleJSON.utf8), query: "apple")
        XCTAssertEqual(records.map { $0.id }, ["a1", "c3", "b2"], "NC, mature, panorama and GIF are dropped; title/tag matches first")
        XCTAssertEqual(records.first?.licenseLabel, "CC BY 2.0")
        XCTAssertEqual(records.first?.attributionLine, "Fot. Jan · CC BY 2.0")
        XCTAssertTrue(records.first?.requiresAttribution ?? false)
        XCTAssertEqual(records[1].licenseLabel, "CC0")
        XCTAssertFalse(records[1].requiresAttribution)
        XCTAssertEqual(records[2].licenseLabel, "CC BY-SA 4.0")
        XCTAssertThrowsError(try OpenverseClient.parseSearch(Data("not json".utf8), query: "apple"))
    }

    func testSearchURLUsesLicenseAndPhotoFilters() throws {
        let url = try XCTUnwrap(OpenverseClient.searchURL(query: "boarding pass"))
        let text = url.absoluteString
        XCTAssertTrue(text.hasPrefix("https://api.openverse.org/v1/images/"))
        XCTAssertTrue(text.contains("license=cc0,by,by-sa"))
        XCTAssertTrue(text.contains("category=photograph"))
        XCTAssertTrue(text.contains("mature=false"))
        XCTAssertTrue(text.contains("q=boarding%20pass"))
    }

    func testImageSignature() {
        XCTAssertTrue(OpenverseClient.isImageData(Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00])))
        XCTAssertTrue(OpenverseClient.isImageData(Data([0x89, 0x50, 0x4E, 0x47, 0x0D])))
        XCTAssertFalse(OpenverseClient.isImageData(Data("<html>".utf8)))
        XCTAssertFalse(OpenverseClient.isImageData(Data()))
    }

    func testStoreFileSkipsDamagedAssignments() throws {
        let json = """
        {"version":1,"blockedUntil":5,"assignments":[
          {"meaningId":"m1","wordId":"w1","term":"apple","query":"apple","candidates":[],"chosenID":null,"rejectedIDs":[],"searchedAt":1},
          {"meaningId":42}
        ]}
        """
        let file = try JSONDecoder().decode(WordImageStoreFile.self, from: Data(json.utf8))
        XCTAssertEqual(file.assignments.map { $0.meaningId }, ["m1"])
        XCTAssertEqual(file.blockedUntil, 5)
    }

    func testOfflineServiceHasNoPhotosAndNeverFails() async {
        let folder = temporaryFolder()
        let service = WordImageService(networkEnabled: false, storeURL: folder.appendingPathComponent("word-images.json"), cacheDirectory: folder.appendingPathComponent("cache"))
        let candidate = PictureCandidate(wordId: "w", meaningId: "m", term: "apple", query: "apple")
        await service.prefetch([candidate])
        let cached = await service.cachedMeaningIDs()
        XCTAssertTrue(cached.isEmpty)
        let image = await service.image(for: "m")
        XCTAssertNil(image)
        let images = await service.images(for: ["m"])
        XCTAssertNil(images)
        await service.reject(meaningID: "m", imageID: "x")
        await service.removeAll()
    }

    @MainActor
    func testImageReportsAreStoredSeparatelyAndExported() throws {
        let folder = temporaryFolder()
        let fileURL = folder.appendingPathComponent("image-reports.json")
        let store = ImageReportStore(fileURL: fileURL)
        let record = WordImageRecord(
            id: "a1", title: "Apple", thumbnailURL: "https://api.openverse.org/v1/images/a1/thumb/",
            originalURL: "https://example.org/a.jpg", landingURL: "https://example.org/a", creator: "Jan",
            creatorURL: nil, license: "by", licenseVersion: "2.0", licenseURL: "https://creativecommons.org/licenses/by/2.0/",
            provider: "flickr", service: "openverse"
        )
        store.add(ImageReport(term: "apple", meaning: "jabłko", wordId: "w", meaningId: "m", record: record, comment: "To gruszka"))
        XCTAssertEqual(store.reports.count, 1)
        XCTAssertEqual(store.reports.first?.source, "openverse/flickr")
        XCTAssertEqual(store.reports.first?.imageURL, record.thumbnailURL)
        let exported = try store.exportFile()
        let data = try Data(contentsOf: exported)
        let decoded = try JSONDecoder().decode([ImageReport].self, from: data)
        XCTAssertEqual(decoded.first?.comment, "To gruszka")
        XCTAssertTrue(exported.lastPathComponent.hasPrefix("FluentNOW-zdjecia-zgloszenia-"))
        store.removeAll()
        XCTAssertTrue(store.reports.isEmpty)
    }

    func testAssignmentPrefersNextUnreportedCandidate() {
        let first = WordImageRecord(id: "1", title: "", thumbnailURL: "https://a/1", originalURL: "", landingURL: "", creator: "", creatorURL: nil, license: "cc0", licenseVersion: "1.0", licenseURL: "", provider: "", service: "openverse")
        var second = first
        second.id = "2"
        let assignment = WordImageAssignment(meaningId: "m", wordId: "w", term: "t", query: "t", candidates: [first, second], chosenID: "1", rejectedIDs: ["1"], searchedAt: 0)
        XCTAssertEqual(assignment.chosen?.id, "1")
        XCTAssertEqual(assignment.nextCandidate?.id, "2")
        XCTAssertEqual(first.fileName, "1.jpg")
    }
}
