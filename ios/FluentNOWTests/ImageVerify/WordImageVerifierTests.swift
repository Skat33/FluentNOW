import XCTest
import FluentKit
@testable import FluentNOW

/// image-verify, layer 2: accept / reject from Vision labels and the title/tag match (pure).
final class WordImageVerifierTests: XCTestCase {
    private let taxonomy: Set<String> = [
        "phone", "payphone", "insect", "animal", "mammal", "people", "adult", "fireplace", "fire",
        "chair", "table", "furniture", "baseball", "baseball_bat", "bee", "computer_mouse", "rodent",
        "outdoor", "sky", "document", "food", "fruit", "apple"
    ]

    private func labels(_ pairs: [(String, Double)]) -> [WordImageLabel] {
        pairs.map { (pair: (String, Double)) -> WordImageLabel in WordImageLabel(identifier: pair.0, confidence: pair.1) }
    }

    private func decide(
        _ term: String,
        context: WordImageContext? = nil,
        metadata: WordImageMetadataMatch = .strong,
        _ pairs: [(String, Double)]?
    ) -> WordImageDecision {
        let profile = WordImageTermProfile.make(term: term, context: context)
        return WordImageVerifier.decide(profile: profile, metadata: metadata, labels: pairs.map { labels($0) }, taxonomy: taxonomy)
    }

    func testInsectAtPhoneIsRejected() {
        let decision = decide("phone", [("insect", 0.91), ("animal", 0.88), ("phone", 0.02)])
        XCTAssertFalse(decision.accepted)
        XCTAssertEqual(decision.code, "vision-conflict")
        XCTAssertTrue(decision.reason.contains("insect"))
    }

    func testFireplaceAtPhoneIsRejected() {
        let decision = decide("phone", metadata: .weak, [("fireplace", 0.82), ("fire", 0.8)])
        XCTAssertFalse(decision.accepted)
        XCTAssertEqual(decision.code, "vision-conflict")
    }

    func testRecognisedPhoneIsAccepted() {
        XCTAssertEqual(decide("phone", [("phone", 0.74), ("people", 0.9)]).code, "vision-match")
        XCTAssertEqual(decide("phone", [("phone", 0.3), ("table", 0.4)]).code, "vision-weak-match")
        XCTAssertEqual(decide("smartphone", [("phone", 0.6)]).code, "vision-match", "synonym → same identifier")
    }

    func testPersonDominatingAWeakMatchIsRejected() {
        let decision = decide("phone", [("phone", 0.25), ("people", 0.96), ("adult", 0.93)])
        XCTAssertFalse(decision.accepted, "a portrait is not a photo of a phone")
    }

    func testMissingLabelOfAKnownWordIsRejected() {
        let decision = decide("chair", [("table", 0.6), ("furniture", 0.7)])
        XCTAssertFalse(decision.accepted)
        XCTAssertEqual(decision.code, "vision-missing")
    }

    func testWordWithoutVisionLabelNeedsTitleAndNoConflict() {
        XCTAssertEqual(decide("trail marker", [("outdoor", 0.9), ("sky", 0.6)]).code, "metadata-only")
        XCTAssertFalse(decide("trail marker", metadata: .weak, [("outdoor", 0.9)]).accepted)
        XCTAssertFalse(decide("trail marker", [("insect", 0.8)]).accepted)
    }

    func testAnimalSenseNeedsAnAnimal() {
        let animal = WordImageContext(topic: "animals", translation: "nietoperz")
        XCTAssertEqual(decide("bat", context: animal, [("mammal", 0.8), ("animal", 0.9)]).code, "vision-related")
        let baseball = decide("bat", context: animal, [("baseball", 0.9), ("people", 0.95)])
        XCTAssertFalse(baseball.accepted)
        let nothing = decide("bat", context: animal, [("sky", 0.5)])
        XCTAssertEqual(nothing.code, "vision-wrong-kind")
        let sports = WordImageContext(topic: "sports", translation: "kij")
        XCTAssertEqual(decide("bat", context: sports, [("baseball_bat", 0.55)]).code, "vision-match")
    }

    func testOwnClassIsNeverAConflict() {
        // A bee is an insect: the living group does not contradict an animal word.
        XCTAssertTrue(decide("bee", [("insect", 0.9), ("bee", 0.3)]).accepted)
        let mouse = WordImageContext(translation: "mysz")
        XCTAssertTrue(decide("mouse", context: mouse, [("rodent", 0.6), ("animal", 0.9)]).accepted)
    }

    func testWithoutVisionOnlyAStrongTitleCounts() {
        XCTAssertEqual(decide("chair", nil).code, "metadata-no-vision")
        XCTAssertFalse(decide("chair", metadata: .weak, nil).accepted)
    }

    func testTaxonomyLimitsExpectedLabels() {
        let profile = WordImageTermProfile.make(term: "phone", context: nil)
        XCTAssertTrue(WordImageVerifier.hasVisionEquivalent(profile, taxonomy: taxonomy))
        XCTAssertFalse(WordImageVerifier.hasVisionEquivalent(profile, taxonomy: ["insect"]))
        XCTAssertTrue(WordImageVerifier.hasVisionEquivalent(profile, taxonomy: nil), "hand-mapped labels without taxonomy")
        let guessed = WordImageTermProfile.make(term: "kitchen sink", context: nil)
        XCTAssertFalse(WordImageVerifier.hasVisionEquivalent(guessed, taxonomy: nil), "guessed identifiers need the taxonomy")
    }

    func testConflictThresholdsDependOnSubject() {
        let objectRules = WordImageVerifier.conflictRules(for: .object)
        XCTAssertTrue(objectRules.contains { $0.labels.contains("insect") })
        let animalRules = WordImageVerifier.conflictRules(for: .animal)
        XCTAssertFalse(animalRules.contains { $0.labels.contains("insect") }, "animals may look like animals")
        let wearableRules = WordImageVerifier.conflictRules(for: .wearable)
        XCTAssertFalse(wearableRules.contains { $0.labels.contains("people") }, "clothes are worn by people")
    }
}
