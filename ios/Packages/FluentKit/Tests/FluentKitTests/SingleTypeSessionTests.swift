import XCTest
@testable import FluentKit

/// FEEDBACK-5 J1: „Ćwicz wybrany typ” — one-type sessions (`SingleTypeSession`).
final class SingleTypeSessionTests: XCTestCase {
    // MARK: Helpers

    private func word(_ id: String, sentence: String? = nil, translation: String? = nil) -> Word {
        var word = TestData.freshWord(id, "term\(id)", "sens \(id)")
        word.meanings[0].examples = [sentence ?? "We always use term\(id) on busy days."]
        word.meanings[0].exampleTranslations = [translation ?? "Zawsze używamy tego w pracowite dni \(id)."]
        return word
    }

    private func practiced(_ word: Word, due: Timestamp) -> Word {
        var copy = word
        copy.meanings[0].scores[.recognition] = Score(value: 20, interval: 2, due: due, correct: 2, last: testNow - 3 * day)
        return copy
    }

    // MARK: Tokens

    func testModeTokensRoundTripAndOldVersionsSeeTheDailyMix() {
        for type in SingleTypeSession.types {
            let mode = SingleTypeSession.mode(for: type)
            XCTAssertNotNil(mode, "\(type)")
            XCTAssertEqual(mode.flatMap { SingleTypeSession.type(ofMode: $0) }, type)
            // Deep links accept only lower-case letters and „-”.
            XCTAssertTrue(mode?.allSatisfy { (character: Character) -> Bool in character == "-" || (character >= "a" && character <= "z") } ?? false, "\(type)")
        }
        XCTAssertEqual(SingleTypeSession.mode(for: .scramble), "exercise-scramble")
        XCTAssertNil(SingleTypeSession.mode(for: .flashcard))
        XCTAssertNil(SingleTypeSession.mode(for: .picture))
        XCTAssertNil(SingleTypeSession.type(ofMode: "mixed"))
        XCTAssertNil(SingleTypeSession.type(ofMode: "exercise-picture"))
        XCTAssertEqual(SingleTypeSession.types.count, 7)
        XCTAssertEqual(VocabSession(tasks: [], minutes: 5, mode: "exercise-scramble").studyMode, .mixed)
    }

    // MARK: Building

    func testOnlyTheChosenTypeInDueKnownNewOrder() {
        var state = TestData.emptyState()
        let fresh = word("new")
        let known = practiced(word("known"), due: testNow + 2 * day)
        let dueLate = practiced(word("due-late"), due: testNow - day)
        let dueEarly = practiced(word("due-early"), due: testNow - 3 * day)
        var starredFresh = word("new-star")
        starredFresh.important = true
        state.words = [fresh, known, dueLate, starredFresh, dueEarly]
        for type in SingleTypeSession.types where type != .matchPairs {
            let session = SingleTypeSession.makeSession(state: state, type: type, minutes: 10, now: testNow)
            XCTAssertTrue(session.tasks.allSatisfy { $0.type == type }, "\(type)")
            XCTAssertEqual(session.mode, SingleTypeSession.mode(for: type))
            XCTAssertEqual(session.minutes, 10)
            if type == .recall || type == .meaning {
                XCTAssertEqual(session.tasks.map { $0.wordId }, ["due-early", "due-late", "known", "new-star", "new"], "\(type)")
            }
        }
    }

    func testMeaningsThatCannotCarryTheTypeAreLeftOut() {
        var state = TestData.emptyState()
        let short = word("short", sentence: "Go now.", translation: "")
        let untranslated = word("plain", sentence: "We always use termplain on busy days.", translation: "")
        state.words = [short, untranslated] + (0..<4).map { word("w\($0)") }
        let scramble = SingleTypeSession.makeSession(state: state, type: .scramble, minutes: 5, now: testNow)
        XCTAssertFalse(scramble.tasks.contains { $0.wordId == "short" }, "two words cannot be scrambled")
        XCTAssertTrue(scramble.tasks.contains { $0.wordId == "plain" })
        let listening = SingleTypeSession.makeSession(state: state, type: .listeningChoice, minutes: 5, now: testNow)
        XCTAssertFalse(listening.tasks.contains { $0.wordId == "short" || $0.wordId == "plain" }, "no translation, no listening choice")
        XCTAssertEqual(listening.tasks.count, 4)
        let cloze = SingleTypeSession.makeSession(state: state, type: .cloze, minutes: 5, now: testNow)
        XCTAssertFalse(cloze.tasks.contains { $0.wordId == "short" }, "the sentence does not contain the word")

        var lonely = TestData.emptyState()
        lonely.words = [word("only")]
        XCTAssertTrue(SingleTypeSession.makeSession(state: lonely, type: .listeningChoice, minutes: 5, now: testNow).tasks.isEmpty, "no distractor pool")
        XCTAssertTrue(SingleTypeSession.makeSession(state: TestData.emptyState(), type: .meaning, minutes: 5, now: testNow).tasks.isEmpty)
        XCTAssertTrue(SingleTypeSession.makeSession(state: state, type: .picture, minutes: 5, now: testNow).tasks.isEmpty, "not offered")
    }

    func testAnotherSentenceIsUsedWhenTheFirstCannotCarryTheType() throws {
        var state = TestData.emptyState()
        var item = word("multi")
        item.meanings[0].examples = ["Go now.", "We always use termmulti on busy days."]
        item.meanings[0].exampleTranslations = ["Idź.", "Zawsze go używamy."]
        state.words = [item]
        let session = SingleTypeSession.makeSession(state: state, type: .scramble, minutes: 5, now: testNow)
        XCTAssertEqual(try XCTUnwrap(session.tasks.first).example, 1)
    }

    func testLengthFollowsTheMinutes() {
        var state = TestData.emptyState()
        state.words = (0..<60).map { word("w\($0)") }
        XCTAssertEqual(SingleTypeSession.makeSession(state: state, type: .meaning, minutes: 5, now: testNow).tasks.count, 300 / ExerciseType.meaning.estimatedSeconds)
        XCTAssertEqual(SingleTypeSession.makeSession(state: state, type: .meaning, minutes: 10, now: testNow).tasks.count, 600 / ExerciseType.meaning.estimatedSeconds)
        XCTAssertEqual(SingleTypeSession.makeSession(state: state, type: .dictation, minutes: 5, now: testNow).tasks.count, 300 / ExerciseType.dictation.estimatedSeconds)
        XCTAssertEqual(SingleTypeSession.taskLimit(for: .matchPairs, minutes: 5), 6)
    }

    func testPairsSessionIsMadeOfDistinctBoards() throws {
        var state = TestData.emptyState()
        state.words = (0..<12).map { word("w\($0)") }
        let session = SingleTypeSession.makeSession(state: state, type: .matchPairs, minutes: 5, now: testNow)
        XCTAssertEqual(session.tasks.count, 2, "12 meanings: two boards of five, two left over")
        XCTAssertTrue(session.tasks.allSatisfy { $0.type == .matchPairs && $0.allRefs.count == MatchPairsExercise.pairCount })
        let ids = session.tasks.flatMap { $0.allRefs.map { $0.meaningId } }
        XCTAssertEqual(Set(ids).count, ids.count, "every meaning on one board only")
        for board in session.tasks {
            XCTAssertEqual(MatchPairsExercise.items(for: board, state: state).count, MatchPairsExercise.pairCount)
        }
        var small = TestData.emptyState()
        small.words = (0..<2).map { word("s\($0)") }
        XCTAssertTrue(SingleTypeSession.makeSession(state: small, type: .matchPairs, minutes: 5, now: testNow).tasks.isEmpty)
        XCTAssertEqual(SingleTypeSession.availability(state: small).count(for: .matchPairs), 0)
    }

    func testAvailabilityCountsBuildableMeanings() {
        var state = TestData.emptyState()
        var archived = word("old")
        archived.archived = true
        state.words = [word("short", sentence: "Go now.", translation: ""), archived] + (0..<4).map { word("w\($0)") }
        let availability = SingleTypeSession.availability(state: state)
        XCTAssertEqual(availability.count(for: .meaning), 5)
        XCTAssertEqual(availability.count(for: .recall), 5)
        XCTAssertEqual(availability.count(for: .scramble), 4)
        XCTAssertEqual(availability.count(for: .listeningChoice), 4)
        XCTAssertEqual(availability.count(for: .matchPairs), 5)
        XCTAssertEqual(SingleTypeSession.availability(state: state, collection: "Inna").count(for: .meaning), 0)
    }

    // MARK: Retries

    func testRetriesStayInTheChosenType() throws {
        var state = TestData.emptyState()
        state.words = (0..<5).map { practiced(word("w\($0)"), due: testNow - day) }
        state.words[0].meanings[0].scores[.recall] = Score(interval: 2, due: testNow - day, correct: 1, last: testNow - 3 * day)
        let session = SingleTypeSession.makeSession(state: state, type: .scramble, minutes: 5, now: testNow)
        state.session = session
        let task = try XCTUnwrap(session.tasks.first { $0.wordId == "w0" })
        let before = session.tasks.count
        let answered = Scheduler.recordAnswer(state, task: task, correct: false, seconds: 9, confidence: 2, hint: false, now: testNow, reviewID: "r")
        XCTAssertEqual(answered.session?.tasks.count, before + 1)
        XCTAssertNotEqual(answered.session?.tasks.last?.type, .scramble, "recordAnswer rotates the format of a retry")
        let aligned = SingleTypeSession.alignRetries(answered, from: before)
        XCTAssertEqual(aligned.session?.tasks.last?.type, .scramble)
        XCTAssertEqual(aligned.session?.tasks.last?.wordId, "w0")
        XCTAssertEqual(Array(aligned.session?.tasks.prefix(before) ?? []), session.tasks, "earlier tasks untouched")

        var mixed = answered
        mixed.session?.mode = StudyMode.mixed.rawValue
        XCTAssertEqual(SingleTypeSession.alignRetries(mixed, from: before), mixed, "other sessions are unchanged")
        XCTAssertEqual(SingleTypeSession.alignRetries(answered, from: before + 5), answered)
    }
}
