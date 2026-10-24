import XCTest
import SwiftUI
import FluentKit
@testable import FluentNOW

/// FEEDBACK-6 K1–K3: okno „Kontynuuj / Zacznij od nowa”, przerwana talia fiszek, strony
/// polecanych bez przewijania, dwie warstwy podświetleń w czytance.
/// `@MainActor`: część funkcji to statyczne metody widoków (jak w `FeaturePureFunctionTests`).
@MainActor
final class StudyLayoutTests: XCTestCase {
    private let suiteName = "StudyLayoutTests"

    /// Czysty, osobny magazyn `UserDefaults` dla testu.
    private func freshDefaults() -> UserDefaults? {
        UserDefaults().removePersistentDomain(forName: suiteName)
        return UserDefaults(suiteName: suiteName)
    }

    // MARK: K1 — okno wyboru

    func testPromptOnlyForTheSameSingleType() {
        var state = LearnerState()
        state.session = VocabSession(tasks: [
            VocabTask(wordId: "a", meaningId: "a.m1", type: .scramble, example: 0),
            VocabTask(wordId: "b", meaningId: "b.m1", type: .scramble, example: 0)
        ], index: 1, minutes: 5, mode: "exercise-scramble")
        let prompt = StudyResumePrompt.make(for: .singleType(.scramble), state: state, pausedDeck: nil)
        XCTAssertNotNil(prompt)
        XCTAssertEqual(prompt?.detail, "Ukończono 1 z 2 ćwiczenia.")
        XCTAssertNil(StudyResumePrompt.make(for: .singleType(.cloze), state: state, pausedDeck: nil), "another type starts at once")

        state.session?.index = 2
        XCTAssertNil(StudyResumePrompt.make(for: .singleType(.scramble), state: state, pausedDeck: nil), "a finished session is not paused")

        state.session = VocabSession(tasks: [VocabTask(wordId: "a", meaningId: "a.m1", type: .recall, example: 0)], minutes: 10, mode: "mixed")
        XCTAssertNil(StudyResumePrompt.make(for: .singleType(.recall), state: state, pausedDeck: nil), "the daily mix is not a one-type session")
    }

    func testPromptForFlashcardsNeedsAPausedDeck() {
        XCTAssertNil(StudyResumePrompt.make(for: .flashcards, state: LearnerState(), pausedDeck: nil))
        var run = FlashcardRun(cards: [
            FlashcardCard(wordId: "a", meaningId: "a.m1", example: 0, group: .due),
            FlashcardCard(wordId: "b", meaningId: "b.m1", example: 0, group: .new)
        ])
        run.answer(remembered: true)
        let paused = FlashcardPausedDeck(run: run, collection: nil, seconds: 12, savedAt: 1)
        let prompt = StudyResumePrompt.make(for: .flashcards, state: LearnerState(), pausedDeck: paused)
        XCTAssertEqual(prompt?.title, "Masz przerwaną talię fiszek")
        XCTAssertEqual(paused.positionText, "Karta 2 z 2")
    }

    func testActivitiesFromLaunchModes() {
        XCTAssertEqual(StudyHomeView.activity(for: .flashcards), .flashcards)
        XCTAssertEqual(StudyHomeView.activity(for: .reading), .reading)
        XCTAssertEqual(StudyHomeView.activity(for: .languageMix), .practice(.mixed))
        XCTAssertNil(StudyHomeView.activity(for: .mixed), "the daily mix starts directly")
        XCTAssertEqual(StudyMoreActivity.all.count, 5)
    }

    // MARK: K1 — przerwana talia fiszek

    func testPausedDeckRoundTripAndAbandon() {
        let defaults = freshDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        var run = FlashcardRun(cards: [
            FlashcardCard(wordId: "a", meaningId: "a.m1", example: 2, group: .due),
            FlashcardCard(wordId: "b", meaningId: "b.m1", example: 0, group: .new)
        ])
        XCTAssertNil(FlashcardPauseStore.load(defaults), "nothing saved yet")
        FlashcardPauseStore.save(FlashcardPausedDeck(run: run, collection: "Lotnisko", seconds: 3, savedAt: 1), defaults)
        XCTAssertNil(FlashcardPauseStore.load(defaults), "a deck without a decision is not offered for resuming")
        run.answer(remembered: false)
        FlashcardPauseStore.save(FlashcardPausedDeck(run: run, collection: "Lotnisko", seconds: 3, savedAt: 1), defaults)
        let loaded = FlashcardPauseStore.load(defaults)
        XCTAssertEqual(loaded?.run, run)
        XCTAssertEqual(loaded?.collection, "Lotnisko")

        FlashcardPauseStore.abandon(defaults)
        XCTAssertNil(FlashcardPauseStore.load(defaults))
        let avoided = FlashcardPauseStore.takeAvoidedExamples(defaults)
        XCTAssertEqual(avoided["a.m1"], [2])
        XCTAssertEqual(avoided["b.m1"], [0])
        XCTAssertTrue(FlashcardPauseStore.takeAvoidedExamples(defaults).isEmpty, "read once")
    }

    func testDamagedPausedDeckIsIgnored() {
        let defaults = freshDefaults()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        defaults?.set(Data("{oops".utf8), forKey: FlashcardPauseStore.runKey)
        XCTAssertNil(FlashcardPauseStore.load(defaults))
        FlashcardPauseStore.save(FlashcardPausedDeck(run: FlashcardRun(cards: []), collection: nil, seconds: 0, savedAt: 0), defaults)
        XCTAssertNil(defaults?.data(forKey: FlashcardPauseStore.runKey), "a finished deck removes the saved one")
    }

    // MARK: K2 — strony polecanych

    func testPageSizeFollowsTheAvailableHeight() {
        XCTAssertEqual(UsefulWordsPaging.pageSize(forHeight: 400, rowHeight: 78), 5)
        XCTAssertEqual(UsefulWordsPaging.pageSize(forHeight: 1000, rowHeight: 78), 6, "at most 6")
        XCTAssertEqual(UsefulWordsPaging.pageSize(forHeight: 240, rowHeight: 78), 3)
        XCTAssertNil(UsefulWordsPaging.pageSize(forHeight: 200, rowHeight: 78), "fewer than 3 — the page scrolls")
        XCTAssertNil(UsefulWordsPaging.pageSize(forHeight: .infinity, rowHeight: 78))
        XCTAssertNil(UsefulWordsPaging.pageSize(forHeight: 400, rowHeight: 0))
    }

    func testPagesWithAnyPageSize() {
        let items = (0..<UsefulWordsPaging.setSize).map { (index: Int) -> UsefulWordSuggestion in suggestion("w\(index)") }
        XCTAssertEqual(UsefulWordsPaging.pages(items).count, 3)
        XCTAssertEqual(UsefulWordsPaging.pages(items, size: 4).map { $0.count }, [4, 4, 4, 4, 2])
        XCTAssertEqual(UsefulWordsPaging.pages(items, size: 1).first?.count, UsefulWordsPaging.minPageSize, "clamped to the minimum")
        XCTAssertEqual(UsefulWordsPaging.pages(items, size: 20).first?.count, UsefulWordsPaging.pageSize, "clamped to the maximum")
        XCTAssertEqual(UsefulWordsPaging.page(containing: 6, size: 4), 1, "the first visible word stays visible")
        XCTAssertEqual(UsefulWordsPaging.page(containing: 0, size: 3), 0)
    }

    private func suggestion(_ id: String) -> UsefulWordSuggestion {
        UsefulWordSuggestion(
            candidate: UsefulWordCandidate(reference: "t/\(id)", term: id, translation: "tłumaczenie \(id)", level: "A2", frequency: .veryCommon, topicID: "t", topicName: "Temat", group: "g"),
            score: 1,
            reasons: []
        )
    }

    // MARK: K3 — podświetlenia

    func testDisplayLayerHasNoLinksAndLinkLayerMatchesTheText() {
        let tokens = [
            ReadingToken(text: "I "),
            ReadingToken(text: "board", wordId: "w1"),
            ReadingToken(text: " the "),
            ReadingToken(text: "plane", glossaryIndex: 0),
            ReadingToken(text: ".")
        ]
        let display = ReadingHighlightStyle.attributed(tokens: tokens, paragraph: 0, evidence: [0..<5])
        let links = ReadingHighlightStyle.attributed(tokens: tokens, paragraph: 0, evidence: [], layer: .links)
        XCTAssertEqual(String(display.characters), "I board the plane.")
        XCTAssertEqual(String(links.characters), String(display.characters), "both layers wrap the same way")
        XCTAssertTrue(display.runs.allSatisfy { $0.link == nil }, "colours of the display layer are not repainted with the tint")
        let linked = links.runs.compactMap { (run: AttributedString.Runs.Run) -> String? in
            run.link == nil ? nil : String(links[run.range].characters)
        }
        XCTAssertEqual(linked, ["board", "plane"])
        for layer in [display, links] {
            let bold = layer.runs.compactMap { (run: AttributedString.Runs.Run) -> String? in
                run.inlinePresentationIntent == .stronglyEmphasized ? String(layer[run.range].characters) : nil
            }
            XCTAssertEqual(bold, ["plane"], "useful words are bold in both layers (same line breaks)")
        }
    }

    func testLegendDescribesBothKinds() {
        XCTAssertTrue(ReadingHighlightStyle.legendText(.useful).contains("pogrubione"))
        XCTAssertTrue(ReadingHighlightStyle.legendText(.own).contains("słownika"))
    }
}
