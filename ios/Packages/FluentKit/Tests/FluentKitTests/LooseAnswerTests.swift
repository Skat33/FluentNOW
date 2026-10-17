import XCTest
@testable import FluentKit

/// Accepted variants with notes in parentheses, `;`-glued alternatives or inner punctuation
/// (found by english-qa in the topic content) must still accept the natural typed answer.
final class LooseAnswerTests: XCTestCase {
    func testParentheticalNoteAndGluedVariantsAreSplit() {
        let keys = TextNormalizer.looseKeys("zerwać się (o połączeniu); rozłączyć się", using: TextNormalizer.answerKey)
        XCTAssertTrue(keys.contains("zerwac sie"), "\(keys)")
        XCTAssertTrue(keys.contains("rozlaczyc sie"), "\(keys)")
    }

    func testInnerCommaDoesNotMatter() {
        let typed = TextNormalizer.stripInnerPunctuation(TextNormalizer.answerKey("było minęło"))
        let keys = TextNormalizer.looseKeys("było, minęło", using: TextNormalizer.answerKey)
        XCTAssertTrue(keys.contains(typed), "\(keys) vs \(typed)")
    }

    func testEnglishCommaVariant() {
        let typed = TextNormalizer.stripInnerPunctuation(TextNormalizer.englishAnswerKey("Sorry I didn't catch that"))
        let keys = TextNormalizer.looseKeys("sorry, I didn't catch that", using: TextNormalizer.englishAnswerKey)
        XCTAssertTrue(keys.contains(typed), "\(keys) vs \(typed)")
    }

    func testHyphenAndApostropheAreKept() {
        XCTAssertEqual(TextNormalizer.stripInnerPunctuation("e-mail"), "e-mail")
        XCTAssertEqual(TextNormalizer.stripInnerPunctuation("don't"), "don't")
    }

    func testRemovingParentheticals() {
        XCTAssertEqual(TextNormalizer.removingParentheticals("fiskus (Wujek Sam)"), "fiskus ")
        XCTAssertEqual(TextNormalizer.removingParentheticals("a (b (c)) d"), "a  d")
    }
}
