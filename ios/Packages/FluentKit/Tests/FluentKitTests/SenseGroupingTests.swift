import XCTest
@testable import FluentKit

/// FEEDBACK-8 M3: „Dodaj słowo” shows one row per meaning — duplicate entries of the same term
/// (several topics + core) are grouped (`SenseGrouping`) and added as one meaning with all
/// examples; grouped entries count as owned.
final class SenseGroupingTests: XCTestCase {
    private func sense(
        _ translation: String,
        ref: String,
        examples: [String],
        pos: String = "czasownik frazowy",
        definition: String = "To talk with someone you have not seen for a while.",
        level: String = "B1",
        frequency: SpokenFrequency? = .common,
        accepted: [String]? = nil
    ) -> SenseSuggestion {
        SenseSuggestion(
            topic: "Kategoria \(ref)",
            translation: translation,
            definition: definition,
            pos: pos,
            level: level,
            spokenFrequency: frequency,
            collection: "Temat \(ref)",
            examples: examples.map { (en: String) -> ExamplePair in ExamplePair(en: en, pl: "PL: \(en)", focusEn: "catch up", focusPl: "") },
            acceptedTranslations: accepted,
            acceptedAnswers: ["catch up"],
            contentRef: ref
        )
    }

    private var catchUp: Lookup {
        Lookup(term: "catch up", meanings: [
            sense("nadrobić zaległości", ref: "cafe-bakery/cafe.catch-up", examples: ["Let's catch up over coffee.", "We should catch up soon."]),
            sense("dogonić", ref: "sports/sports.catch-up", examples: ["Run faster to catch up with them."], definition: "To reach someone who is ahead of you."),
            sense("Nadrobić zaległości.", ref: "friendship/friendship.catch-up", examples: ["We should catch up soon!", "It was great to catch up last night."], frequency: .veryCommon),
            sense("nadrobić zaległości", ref: "core-c03/core.catch-up", examples: ["I need to catch up on my emails.", "Let's catch up over coffee."], level: "B2", frequency: .lessCommon)
        ])
    }

    func testSameTranslationIsOneRowWithAllExamples() {
        let result = SenseGrouping.grouped(catchUp)
        XCTAssertEqual(result.lookup.meanings.map { $0.translation }, ["nadrobić zaległości", "dogonić"], "one row per meaning, in lookup order")
        let group = result.groups[0]
        XCTAssertEqual(group.memberIndices, [3, 2, 0], "core first, then the most frequent")
        XCTAssertEqual(group.sense.contentRef, "core-c03/core.catch-up")
        XCTAssertEqual(group.sense.level, "B2", "fields of the representative")
        XCTAssertEqual(group.sense.mergedContentRefs, ["friendship/friendship.catch-up", "cafe-bakery/cafe.catch-up"])
        XCTAssertEqual(group.sense.examples.map { $0.en }, [
            "I need to catch up on my emails.",
            "Let's catch up over coffee.",
            "We should catch up soon!",
            "It was great to catch up last night."
        ], "no repeated sentences (also after normalisation)")
        XCTAssertEqual(group.exampleCount, 4)
        XCTAssertEqual(group.sense.acceptedAnswers, ["catch up"])
        XCTAssertEqual(result.groups[1].memberIndices, [1])
        XCTAssertNil(result.groups[1].sense.mergedContentRefs, "a single entry is unchanged")
        XCTAssertEqual(result.groups[1].sense, catchUp.meanings[1])
    }

    func testMutualAcceptedTranslationsWithSimilarDefinitionsAreGrouped() {
        let weigh = Lookup(term: "weigh", meanings: [
            sense("ważyć", ref: "a/a.weigh", examples: ["Can you weigh this bag?"], pos: "czasownik", definition: "To measure how heavy something is.", accepted: ["zważyć"]),
            sense("zważyć", ref: "b/b.weigh", examples: ["She weighed the flour."], pos: "czasownik", definition: "To measure how heavy someone or something is.", accepted: ["ważyć"])
        ])
        let groups = SenseGrouping.groups(weigh.meanings)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].sense.translation, "ważyć")
        XCTAssertEqual(groups[0].sense.acceptedTranslations, ["zważyć"], "the other translation is accepted once")
        XCTAssertEqual(groups[0].exampleCount, 2)
    }

    func testDifferentMeaningsStaySeparateEvenWithMutualAcceptance() {
        let mouse = [
            sense("mysz", ref: "animals/animals.mouse", examples: ["A mouse ran under the table."], pos: "rzeczownik", definition: "A small animal with a long tail.", accepted: ["myszka"]),
            sense("myszka", ref: "computer/computer.mouse", examples: ["Click with the mouse."], pos: "rzeczownik", definition: "A small device you move with your hand to control the pointer on a screen.", accepted: ["mysz"])
        ]
        XCTAssertEqual(SenseGrouping.groups(mouse).count, 2, "definitions differ — an animal vs a device")
        let oneWay = [
            sense("ważyć", ref: "a/a.weigh", examples: ["x"], pos: "czasownik", definition: "To measure how heavy something is.", accepted: ["zważyć"]),
            sense("zważyć", ref: "b/b.weigh", examples: ["y"], pos: "czasownik", definition: "To measure how heavy something is.")
        ]
        XCTAssertEqual(SenseGrouping.groups(oneWay).count, 2, "acceptance must be mutual")
        let otherPos = [
            sense("handlowy", ref: "a/a.x", examples: ["x"], pos: "przymiotnik", definition: "Related to buying and selling.", accepted: ["reklama"]),
            sense("reklama", ref: "b/b.x", examples: ["y"], pos: "rzeczownik", definition: "Related to buying and selling.", accepted: ["handlowy"])
        ]
        XCTAssertEqual(SenseGrouping.groups(otherPos).count, 2, "different part of speech")
    }

    func testDefinitionSimilarity() {
        XCTAssertEqual(SenseGrouping.definitionSimilarity("A storm with thunder and lightning.", "A storm with thunder and lightning."), 1)
        XCTAssertLessThan(SenseGrouping.definitionSimilarity("A small animal with a long tail.", "A small device you move with your hand."), 0.5)
        XCTAssertEqual(SenseGrouping.definitionSimilarity("", "Anything"), 0)
        XCTAssertTrue(SenseGrouping.groups([]).isEmpty)
    }

    func testAddingAGroupCreatesOneMeaningThatOwnsEveryEntry() {
        let grouped = SenseGrouping.grouped(catchUp).lookup
        var ids = 0
        let result = VocabularyMerger.mergeSuggestions(TestData.emptyState(), lookup: grouped, indices: [0], now: testNow) { () -> String in
            ids += 1
            return "id\(ids)"
        }
        XCTAssertEqual(result.addedMeaningIDs.count, 1)
        guard let meaning = result.state.words.first?.meanings.first else { return XCTFail("no meaning") }
        XCTAssertEqual(meaning.examples.count, 4)
        XCTAssertEqual(meaning.exampleTranslations?.count, 4, "translations stay aligned with examples")
        XCTAssertEqual(meaning.contentRef, "core-c03/core.catch-up")
        XCTAssertEqual(Set(meaning.allContentRefs), ["core-c03/core.catch-up", "friendship/friendship.catch-up", "cafe-bakery/cafe.catch-up"])
        let added = VocabularyMerger.addedContentReferences(result.state)
        XCTAssertTrue(added.contains("cafe-bakery/cafe.catch-up"), "grouped entries count as added (topic search, reading)")
        let owned = OwnedVocabulary(result.state)
        XCTAssertTrue(owned.contains(reference: "friendship/friendship.catch-up", term: "x", translation: "y"))
        XCTAssertFalse(owned.contains(reference: "sports/sports.catch-up", term: "catch up", translation: "dogonić"), "the other meaning is still free")
    }

    func testMergedReferencesRoundTripAndOldDataDecodes() throws {
        var meaning = Meaning(id: "m1", translation: "nadrobić zaległości", contentRef: "a/a.x", mergedContentRefs: ["b/b.x"])
        let data = try JSONEncoder().encode(meaning)
        XCTAssertEqual(try JSONDecoder().decode(Meaning.self, from: data), meaning)
        meaning.mergedContentRefs = nil
        let plain = try JSONEncoder().encode(meaning)
        XCTAssertFalse(String(decoding: plain, as: UTF8.self).contains("mergedContentRefs"), "absent when nothing was grouped")
        let old = Data(#"{"id":"m2","translation":"lotnisko","contentRef":"airport/airport.airport"}"#.utf8)
        let decoded = try JSONDecoder().decode(Meaning.self, from: old)
        XCTAssertNil(decoded.mergedContentRefs)
        XCTAssertEqual(decoded.allContentRefs, ["airport/airport.airport"])
        let suggestion = try JSONDecoder().decode(SenseSuggestion.self, from: Data(#"{"translation":"x","mergedContentRefs":["a/b"]}"#.utf8))
        XCTAssertEqual(suggestion.mergedContentRefs, ["a/b"])
    }
}
