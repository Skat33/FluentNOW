import XCTest
import FluentKit
@testable import FluentNOW

/// Testy regresji poprawek code-qa-9 (FEEDBACK-9 N5) po stronie aplikacji.
@MainActor
final class CodeQA9Tests: XCTestCase {

    // MARK: „Powtórz je” w raporcie tygodniowym — sesja tylko z tych słów

    func testScopedStateKeepsOnlyRequestedWords() {
        var state = LearnerState()
        state.words = [
            ServicesTestSupport.word("a", en: "gate", pl: "bramka"),
            ServicesTestSupport.word("b", en: "luggage", pl: "bagaż"),
            ServicesTestSupport.word("c", en: "delay", pl: "opóźnienie")
        ]
        XCTAssertEqual(StudyStarter.scoped(state, to: []).words.map { $0.id }, ["a", "b", "c"], "pusty zbiór — bez ograniczenia")
        let scoped = StudyStarter.scoped(state, to: ["c", "a", "missing"])
        XCTAssertEqual(scoped.words.map { $0.id }, ["a", "c"])
        let session = SessionBuilder.makeSession(state: scoped, minutes: 10, mode: .mixed)
        XCTAssertFalse(session.tasks.isEmpty)
        XCTAssertTrue(session.tasks.allSatisfy { ["a", "c"].contains($0.wordId) }, "tylko słowa z raportu")
    }

    func testLaunchRequestCarriesWordIDs() {
        let request = StudyLaunchRequest(modes: ["mixed"], wordIDs: ["a", "b"])
        XCTAssertEqual(request.wordIDs, ["a", "b"])
        XCTAssertTrue(StudyLaunchRequest.daily.wordIDs.isEmpty)
        XCTAssertNotEqual(request, StudyLaunchRequest(modes: ["mixed"]))
    }
}
