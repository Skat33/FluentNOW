import XCTest
import FluentKit
@testable import FluentNOW

/// FEEDBACK-10 P1–P3 (practice-plus): mistakes captured from exercises, the pronunciation stage
/// rule, the preference and the meaning-options cache.
final class PracticePlusTests: XCTestCase {
    @MainActor
    private func model(type: ExerciseType, en: String, sentence: String) throws -> VocabExerciseModel {
        var word = ServicesTestSupport.word("a", en: en, pl: "tłumaczenie")
        word.meanings[0].examples = [sentence]
        word.meanings[0].exampleTranslations = ["Polskie zdanie."]
        let state = LearnerState(words: [word])
        let task = VocabTask(wordId: "a", meaningId: "a.m1", type: type, example: 0)
        let content = try XCTUnwrap(VocabExerciseContent(task: task, mode: .mixed, state: state, variants: .builtIn))
        return VocabExerciseModel(content: content, key: "k", options: [], variants: .builtIn, assistant: nil)
    }

    @MainActor
    private func place(_ texts: [String], on model: VocabExerciseModel) {
        var free = model.content.scramble?.tiles ?? []
        for text in texts {
            guard let index = free.firstIndex(where: { (tile: ScrambleTile) -> Bool in tile.text == text }) else { continue }
            model.placeTile(free[index].id)
            free.remove(at: index)
        }
    }

    @MainActor
    func testScrambleVerbFormIsLogged() throws {
        let exercise = try model(type: .scramble, en: "go", sentence: "She has gone to bed at night.")
        let board = try XCTUnwrap(exercise.content.scramble)
        XCTAssertEqual(board.tiles.filter { $0.isDecoy }.map { $0.text }, ["went"])
        place(["she", "has", "went", "to", "bed", "at", "night"], on: exercise)
        exercise.checkScramble()
        XCTAssertEqual(exercise.phase, .retry)
        let entries = StudyMistakeCapture.entries(from: exercise, now: 10, idBase: "r1")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.kind, .verbForm)
        XCTAssertEqual(entries.first?.expectedPart, "gone")
        XCTAssertEqual(entries.first?.givenPart, "went")
        XCTAssertEqual(entries.first?.exercise, .scramble)
        XCTAssertEqual(entries.first?.id, "r1-m0")
    }

    @MainActor
    func testTypedRecallAndCorrectAnswers() throws {
        let recall = try model(type: .recall, en: "make", sentence: "Let's make a plan.")
        recall.answer = "made"
        recall.check()
        XCTAssertEqual(recall.firstWrongAnswer, "made")
        XCTAssertEqual(StudyMistakeCapture.entries(from: recall, now: 1, idBase: "r").first?.kind, .verbForm)

        let right = try model(type: .scramble, en: "go", sentence: "She has gone to bed at night.")
        place(["she", "has", "gone", "to", "bed", "at", "night"], on: right)
        right.checkScramble()
        XCTAssertEqual(right.outcome?.correct, true)
        XCTAssertTrue(StudyMistakeCapture.entries(from: right, now: 1, idBase: "r").isEmpty, "a correct first answer is not a mistake")

        // P2: the stage follows a correct scramble only, and only when switched on.
        XCTAssertTrue(VocabPronunciationSlot.applies(to: right, enabled: true))
        XCTAssertFalse(VocabPronunciationSlot.applies(to: right, enabled: false))
        XCTAssertFalse(VocabPronunciationSlot.applies(to: recall, enabled: true))
    }

    @MainActor
    func testPronunciationPreferenceDefaultsToOn() {
        let preferences = AppPreferences(defaults: nil)
        XCTAssertTrue(preferences.pronunciationPracticeEnabled)
        preferences.pronunciationPracticeEnabled = false
        preferences.resetToDefaults()
        XCTAssertTrue(preferences.pronunciationPracticeEnabled)
    }

    @MainActor
    func testOptionsCacheMatchesDirectOptions() throws {
        let exercise = try model(type: .meaning, en: "chair", sentence: "Sit on the chair.")
        let state = LearnerState(words: [exercise.content.word, ServicesTestSupport.word("b", en: "table", pl: "stół")])
        let cache = StudyMeaningOptionsCache()
        let options = cache.options(for: exercise.content, state: state, resources: .fallback, sessionIndex: -1)
        XCTAssertEqual(options, MeaningOptions.options(state: state, word: exercise.content.word, meaning: exercise.content.meaning, task: exercise.content.task))
        XCTAssertEqual(cache.options(for: exercise.content, state: state, resources: .fallback, sessionIndex: -1), options, "cached")
    }
}
