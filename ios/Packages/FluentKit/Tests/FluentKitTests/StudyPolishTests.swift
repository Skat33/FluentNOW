import XCTest
@testable import FluentKit

/// FEEDBACK-3 H2: „Słowa i obrazki” mode, readiness of photo tasks, queue counter.
final class StudyPolishTests: XCTestCase {
    private func noun(_ id: String, _ en: String, _ translation: String, topic: String? = nil) -> Word {
        var word = TestData.freshWord(id, en, translation)
        word.pos = "rzeczownik"
        word.collection = "Rzeczy"
        word.meanings[0].topic = topic
        return word
    }

    private func practiced(_ word: Word, due: Timestamp) -> Word {
        var copy = word
        copy.meanings[0].scores[.recognition] = Score(value: 20, interval: 2, due: due, correct: 1, last: testNow - day)
        return copy
    }

    private func objectsState() -> LearnerState {
        var state = TestData.emptyState()
        state.words = [
            noun("apple", "apple", "jabłko"),
            practiced(noun("chair", "chair", "krzesło"), due: testNow - 5_000),
            practiced(noun("car", "car", "samochód"), due: testNow - 50_000),
            noun("lamp", "lamp", "lampa"),
            noun("idea", "idea", "pomysł")
        ]
        return state
    }

    // MARK: Mode

    func testPicturesModeIsVocabularyButNeverCombined() {
        XCTAssertTrue(StudyMode.pictures.isVocabulary)
        XCTAssertFalse(StudyMode.pictures.isCombinable)
        XCTAssertEqual(StudyMode.pictures.namePl, "Słowa i obrazki")
        XCTAssertEqual(StudyMode(rawValue: "pictures"), .pictures)
        XCTAssertEqual(VocabSession(tasks: [], minutes: 5, mode: "pictures").studyMode, .pictures)
        var generator = SeededGenerator(seed: 3)
        let combined = CombinedSessionBuilder.makeSession(state: TestData.seed(), modes: [.pictures, .mixed], minutes: 5, random: false, content: .empty, now: testNow, id: "c", using: &generator)
        XCTAssertEqual(combined.modes, [.mixed])
    }

    func testPictureSessionHasOnlyPictureTasksForReadyMeanings() {
        let state = objectsState()
        let ready: Set<String> = ["m-apple", "m-chair", "m-car", "m-lamp"]
        var generator = SeededGenerator(seed: 7)
        // FEEDBACK-4 I2: the mode is „W budowie” — `makeSession(mode: .pictures)` builds nothing
        // while disabled; the builder itself stays and is tested directly.
        var disabledGenerator = SeededGenerator(seed: 7)
        let viaMode = SessionBuilder.makeSession(state: state, minutes: 5, mode: .pictures, pictureMeaningIDs: ready, using: &disabledGenerator)
        XCTAssertEqual(viaMode.mode, "pictures")
        if !PictureExercise.isEnabled {
            XCTAssertTrue(viaMode.tasks.isEmpty)
        }
        let session = SessionBuilder.makePictureSession(state: state, minutes: 5, pictureMeaningIDs: ready, using: &generator)
        XCTAssertEqual(session.mode, "pictures")
        XCTAssertEqual(session.tasks.count, 4)
        XCTAssertTrue(session.tasks.allSatisfy { $0.type == .picture })
        XCTAssertEqual(Set(session.tasks.map { $0.meaningId }), ready, "new meanings take part too — the mode was chosen on purpose")
        XCTAssertFalse(session.tasks.contains { $0.meaningId == "m-idea" })
    }

    func testPictureSessionPrefersPracticedMeaningsAndRespectsTheBudget() {
        var state = TestData.emptyState()
        var ready = Set<String>()
        for index in 0..<40 {
            var word = noun("w\(index)", "object\(index)", "przedmiot \(index)")
            if index < 5 {
                word = practiced(word, due: testNow - Double(index) * 1_000)
            }
            state.words.append(word)
            ready.insert("m-w\(index)")
        }
        var generator = SeededGenerator(seed: 1)
        let session = SessionBuilder.makePictureSession(state: state, minutes: 5, pictureMeaningIDs: ready, using: &generator)
        XCTAssertEqual(session.tasks.count, 5 * 60 / ExerciseType.picture.estimatedSeconds)
        let ids = Set(session.tasks.map { $0.meaningId })
        for index in 0..<5 {
            XCTAssertTrue(ids.contains("m-w\(index)"), "practiced meaning \(index) comes first")
        }
    }

    func testPictureSessionIsEmptyWithoutPhotos() {
        var generator = SeededGenerator(seed: 1)
        let session = SessionBuilder.makeSession(state: objectsState(), minutes: 10, mode: .pictures, using: &generator)
        XCTAssertTrue(session.tasks.isEmpty)
    }

    func testPictureSessionHonorsCollection() {
        var state = objectsState()
        state.words[0].collection = "Kuchnia"
        var generator = SeededGenerator(seed: 1)
        let session = SessionBuilder.makePictureSession(state: state, minutes: 10, collection: "Kuchnia", pictureMeaningIDs: ["m-apple", "m-chair"], using: &generator)
        XCTAssertEqual(session.tasks.map { $0.meaningId }, ["m-apple"])
    }

    // MARK: Readiness

    func testReadyNeedsThreeMutuallyDifferentDistractors() {
        var state = TestData.emptyState()
        state.words = [
            noun("car", "car", "samochód"),
            noun("apple", "apple", "jabłko"),
            noun("pie", "apple pie", "szarlotka"),
            noun("tree", "apple tree", "jabłoń")
        ]
        let cached: Set<String> = ["m-car", "m-apple", "m-pie", "m-tree"]
        // „car” has three photos different from itself, but the three apples are not different
        // from each other — the task could never be shown, so it is not ready.
        XCTAssertEqual(PictureExercise.readyMeaningIDs(state: state, cached: cached), [])
        state.words.append(noun("lamp", "lamp", "lampa"))
        state.words.append(noun("bed", "bed", "łóżko"))
        let more = cached.union(["m-lamp", "m-bed"])
        let ready = PictureExercise.readyMeaningIDs(state: state, cached: more)
        XCTAssertTrue(ready.contains("m-car"))
        XCTAssertTrue(ready.contains("m-apple"))
    }

    func testGreedyDistractorsAreMutuallyDifferent() {
        let state = objectsState()
        let items = state.words.flatMap { (word: Word) -> [WordMeaning] in word.meanings.map { WordMeaning(word: word, meaning: $0) } }
        guard let apple = items.first else { return XCTFail("apple") }
        let chosen = PictureExercise.greedyDistractors(for: apple, pool: items)
        XCTAssertEqual(chosen.count, 3)
        XCTAssertFalse(chosen.contains { $0.word.id == "apple" })
        for (index, item) in chosen.enumerated() {
            for other in chosen[(index + 1)...] {
                XCTAssertTrue(PictureExercise.isClearlyDifferent(item, other))
            }
        }
    }

    func testPendingCountSkipsAbstractArchivedAndSettled() {
        var state = objectsState()
        XCTAssertEqual(PictureExercise.pendingCount(state: state, excluding: []), 4, "idea is abstract")
        state.words[3].archived = true
        XCTAssertEqual(PictureExercise.pendingCount(state: state, excluding: ["m-apple"]), 2)
    }
}
