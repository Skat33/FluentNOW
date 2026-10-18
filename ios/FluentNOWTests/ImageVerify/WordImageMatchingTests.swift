import XCTest
import FluentKit
@testable import FluentNOW

/// image-verify, layer 1: term profiles (senses, queries), title/tag matching, ranking, query
/// plans and the stricter eligibility list. Pure functions — no network, no Vision.
/// Cases come from live Openverse results checked on 2026-10-18.
final class WordImageMatchingTests: XCTestCase {
    private func record(
        _ id: String,
        title: String,
        tags: [String] = [],
        machineTags: [String] = [],
        provider: String = "flickr"
    ) -> WordImageRecord {
        WordImageRecord(
            id: id, title: title, thumbnailURL: "https://api.openverse.org/v1/images/\(id)/thumb/",
            originalURL: "", landingURL: "", creator: "", creatorURL: nil, license: "cc0",
            licenseVersion: "1.0", licenseURL: "", provider: provider, service: "openverse",
            tags: tags, machineTags: machineTags
        )
    }

    // MARK: Text

    func testFormsCoverPluralsAndIrregulars() {
        XCTAssertTrue(WordImageText.forms(of: "mouse").contains("mice"))
        XCTAssertTrue(WordImageText.forms(of: "mice").contains("mouse"))
        XCTAssertTrue(WordImageText.forms(of: "box").contains("boxes"))
        XCTAssertTrue(WordImageText.forms(of: "cherry").contains("cherries"))
        XCTAssertTrue(WordImageText.forms(of: "cherries").contains("cherry"))
        XCTAssertTrue(WordImageText.forms(of: "chairs").contains("chair"))
        XCTAssertTrue(WordImageText.forms(of: "knife").contains("knives"))
        XCTAssertEqual(WordImageText.foldPolish("Żuraw, dźwig, łódź"), "zuraw, dzwig, lodz")
    }

    func testCameraNotesAndParenthesesAreNotTheSubject() {
        // „2021-phone-favourites-089” is a fireplace photographed with a phone.
        let tokens = WordImageMetadataMatcher.cleanedTokens("2021-phone-favourites-089")
        XCTAssertFalse(WordImageMetadataMatcher.containsSubject(tokens, phrase: ["phone"]))
        let acadia = WordImageMetadataMatcher.cleanedTokens("Thunderhole (cell phone)")
        XCTAssertFalse(WordImageMetadataMatcher.containsSubject(acadia, phrase: ["phone"]))
        XCTAssertEqual(WordImageMetadataMatcher.withoutParentheses("Wood mouse (Apodemus)"), "Wood mouse ")
    }

    func testCompoundsAndCharactersAreNotTheSubject() {
        let match = { (title: String, phrase: [String]) -> Bool in
            WordImageMetadataMatcher.containsSubject(WordImageMetadataMatcher.cleanedTokens(title), phrase: phrase)
        }
        XCTAssertFalse(match("Apple tree", ["apple"]))
        XCTAssertFalse(match("Mickey Mouse fail", ["mouse"]))
        XCTAssertFalse(match("Hubble Sees Cosmic Flapping Bat Shadow", ["bat"]))
        XCTAssertFalse(match("Phone Booth", ["phone"]))
        XCTAssertTrue(match("Red apples on a table", ["apple"]))
        XCTAssertTrue(match("Mouse Computer", ["mouse"]))
        XCTAssertTrue(match("Wooden chair", ["chair"]))
        XCTAssertTrue(match("Old cellphone", ["cell", "phone"]), "joined form")
        XCTAssertFalse(match("Crane Bird", ["crane"]), "„bird” makes it a compound by default")
        let tokens = WordImageMetadataMatcher.cleanedTokens("Crane Bird")
        XCTAssertTrue(WordImageMetadataMatcher.containsSubject(tokens, phrase: ["crane"], allowedNext: ["crane", "bird"]))
    }

    func testTagsMatchWholeWordsOnly() {
        XCTAssertTrue(WordImageMetadataMatcher.tagMatches("bat animal", phrase: ["bat"]))
        XCTAssertTrue(WordImageMetadataMatcher.tagMatches("cellphone", phrase: ["cell", "phone"]))
        XCTAssertFalse(WordImageMetadataMatcher.tagMatches("batsdentists", phrase: ["bat"]))
        XCTAssertFalse(WordImageMetadataMatcher.tagMatches("phonebackground wallpaper blue", phrase: ["phone"]))
    }

    // MARK: Profiles

    func testAmbiguousWordsFollowTopicAndTranslation() {
        let computerMouse = WordImageTermProfile.make(term: "mouse", context: WordImageContext(topic: "computers-internet", translation: "mysz"))
        XCTAssertEqual(computerMouse.query, "computer mouse")
        XCTAssertEqual(computerMouse.mappedLabels, ["computer_mouse"])
        XCTAssertEqual(computerMouse.subject, .object)
        let animalMouse = WordImageTermProfile.make(term: "mouse", context: WordImageContext(translation: "mysz"))
        XCTAssertEqual(animalMouse.subject, .animal)
        XCTAssertEqual(animalMouse.query, "mouse rodent")
        let laptopMouse = WordImageTermProfile.make(term: "mouse", context: WordImageContext(translation: "myszka komputerowa"))
        XCTAssertEqual(laptopMouse.query, "computer mouse")
        let bat = WordImageTermProfile.make(term: "bat", context: WordImageContext(translation: "nietoperz"))
        XCTAssertEqual(bat.subject, .animal)
        XCTAssertTrue(bat.avoidWords.contains("baseball"))
        let baseballBat = WordImageTermProfile.make(term: "bat", context: WordImageContext(topic: "sports", translation: "kij"))
        XCTAssertEqual(baseballBat.mappedLabels, ["baseball_bat"])
        let crane = WordImageTermProfile.make(term: "crane", context: WordImageContext(translation: "dźwig"))
        XCTAssertEqual(crane.query, "construction crane")
        let bird = WordImageTermProfile.make(term: "crane", context: WordImageContext(topic: "animals", translation: "żuraw"))
        XCTAssertEqual(bird.query, "crane bird")
        XCTAssertEqual(bird.subject, .animal)
        let apple = WordImageTermProfile.make(term: "an apple", context: nil)
        XCTAssertEqual(apple.term, "apple")
        XCTAssertEqual(apple.query, "apple fruit")
        XCTAssertTrue(apple.avoidWords.contains("macbook"))
        let color = WordImageTermProfile.make(term: "orange", context: WordImageContext(topic: "colors-shapes-sizes", translation: "pomarańczowy"))
        XCTAssertNotNil(color.excludedReason)
        let fruit = WordImageTermProfile.make(term: "orange", context: WordImageContext(translation: "pomarańcza"))
        XCTAssertNil(fruit.excludedReason)
        XCTAssertEqual(fruit.subject, .food)
    }

    func testPlainWordsGetLabelsSynonymsAndSubject() {
        let phone = WordImageTermProfile.make(term: "phone", context: nil)
        XCTAssertEqual(phone.query, "phone")
        XCTAssertEqual(phone.alternativeQuery, "telephone")
        XCTAssertTrue(phone.mappedLabels.contains("phone"))
        XCTAssertTrue(phone.synonyms.contains(["smartphone"]))
        let dog = WordImageTermProfile.make(term: "dog", context: nil)
        XCTAssertEqual(dog.subject, .animal, "a living identifier makes it an animal")
        let iceCream = WordImageTermProfile.make(term: "ice cream", context: nil)
        XCTAssertTrue(iceCream.expectedLabels.contains("ice_cream"))
        let sink = WordImageTermProfile.make(term: "kitchen sinks", context: nil)
        XCTAssertTrue(sink.expectedLabels.contains("kitchen_sink"), "singular of the joined form")
        let unknown = WordImageTermProfile.make(term: "trail marker", context: WordImageContext(topic: "camping-hiking"))
        XCTAssertTrue(unknown.mappedLabels.isEmpty)
        XCTAssertEqual(unknown.subject, .place)
    }

    // MARK: Metadata evaluation and ranking

    func testEvaluationOfLiveExamples() {
        let phone = WordImageTermProfile.make(term: "phone", context: nil)
        let favourites = record("fav", title: "2021-phone-favourites-089", tags: ["2021", "iphone", "phone"])
        XCTAssertEqual(WordImageMetadataMatcher.evaluate(favourites, profile: phone).match, .weak, "only the camera tags remain")
        let stock = record("stock", title: "Mobile Phone", tags: ["mobile", "phone", "technology"], provider: "stocksnap")
        let stockResult = WordImageMetadataMatcher.evaluate(stock, profile: phone)
        XCTAssertEqual(stockResult.match, .strong)
        let booth = record("booth", title: "Phone Booth", tags: ["phone"], machineTags: ["telephone", "business"])
        XCTAssertEqual(WordImageMetadataMatcher.evaluate(booth, profile: phone).match, .strong, "machine tag ≥ 90 %")
        let apple = WordImageTermProfile.make(term: "apple", context: nil)
        let mac = record("mac", title: "Apple Mac", tags: ["apple", "computer", "keyboard"], provider: "stocksnap")
        XCTAssertEqual(WordImageMetadataMatcher.evaluate(mac, profile: apple).note, "other-sense")
        let slices = record("slices", title: "Apple Slices", tags: ["apple", "food", "fruits"], provider: "stocksnap")
        XCTAssertEqual(WordImageMetadataMatcher.evaluate(slices, profile: apple).match, .strong)
        let bat = WordImageTermProfile.make(term: "bat", context: WordImageContext(topic: "animals"))
        let etching = record("etch", title: "flying short eared bat. Etching", tags: ["bat", "bat sketch"], provider: "rawpixel")
        XCTAssertEqual(WordImageMetadataMatcher.evaluate(etching, profile: bat).note, "drawing")
        let photo = record("roar", title: "bat roaring white background", tags: ["bat", "bat animal", "mouth"], provider: "rawpixel")
        XCTAssertEqual(WordImageMetadataMatcher.evaluate(photo, profile: bat).match, .strong)
    }

    func testRankingKeepsMatchesBestFirst() {
        let phone = WordImageTermProfile.make(term: "phone", context: nil)
        let records = [
            record("fav", title: "2021-phone-favourites-089", tags: ["iphone", "phone"]),
            record("crisis", title: "two phone crisis", tags: ["cellphone", "girls", "headache"]),
            record("stock", title: "Mobile Phone", tags: ["phone"], provider: "stocksnap"),
            record("cats", title: "Of cats and spreadsheets", tags: ["cat"]),
            record("stock", title: "Mobile Phone duplicate id", provider: "stocksnap")
        ]
        let ranked = WordImageCandidateFilter.rank(records, profile: phone, requireStrong: false)
        XCTAssertEqual(ranked.map { $0.id }, ["stock", "crisis", "fav"], "stock title first, unrelated dropped, duplicates once")
        let strongOnly = WordImageCandidateFilter.rank(records, profile: phone, requireStrong: true)
        XCTAssertFalse(strongOnly.contains { $0.id == "fav" }, "a camera tag alone is not enough without Vision")
    }

    func testQueryPlanUsesCuratedSourcesThenAllThenSynonym() throws {
        let phone = WordImageTermProfile.make(term: "phone", context: nil)
        let first = try XCTUnwrap(WordImageQueryPlanner.plan(attempt: 0, profile: phone))
        XCTAssertEqual(first.sources, ["rawpixel", "stocksnap", "wikimedia"])
        XCTAssertNil(WordImageQueryPlanner.plan(attempt: 1, profile: phone)?.sources)
        XCTAssertEqual(WordImageQueryPlanner.plan(attempt: 2, profile: phone)?.query, "telephone")
        XCTAssertNil(WordImageQueryPlanner.plan(attempt: 3, profile: phone))
        let trail = WordImageTermProfile.make(term: "trail marker", context: nil)
        XCTAssertNil(WordImageQueryPlanner.plan(attempt: 2, profile: trail), "no synonym → only two attempts")
        let url = try XCTUnwrap(OpenverseClient.searchURL(query: "phone", sources: first.sources))
        XCTAssertTrue(url.absoluteString.contains("source=rawpixel,stocksnap,wikimedia"))
        XCTAssertFalse(try XCTUnwrap(OpenverseClient.searchURL(query: "phone")).absoluteString.contains("source="))
    }

    func testParsingSplitsUserAndMachineTags() throws {
        let json = """
        {"results":[{"id":"p1","title":"Phone Booth","thumbnail":"https://api.openverse.org/v1/images/p1/thumb/","license":"by","width":676,"height":1024,
        "tags":[{"name":"phone","accuracy":null},{"name":"telephone","accuracy":0.94},{"name":"money","accuracy":0.5}]}]}
        """
        let records = try OpenverseClient.parseSearch(Data(json.utf8), query: "phone")
        XCTAssertEqual(records.first?.tags, ["phone"])
        XCTAssertEqual(records.first?.machineTags, ["telephone"], "machine tags below 90 % are dropped")
    }

    // MARK: Eligibility

    func testStricterEligibilityList() {
        for term in ["voucher", "spreadsheet", "birthday", "cashier", "bus driver", "camping", "flight attendant", "garage sale", "rain check", "dose", "florist"] {
            XCTAssertNotNil(WordImageEligibility.exclusionReason(term: term), term)
        }
        for term in ["phone", "chair", "boarding pass", "record player", "baby carrier", "earring", "building", "ceiling fan", "power drill", "apple"] {
            XCTAssertNil(WordImageEligibility.exclusionReason(term: term), term)
        }
    }
}
