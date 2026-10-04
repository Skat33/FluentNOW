import XCTest
@testable import FluentKit

final class ModelCodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        try JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
    }

    func testSettingsAreClampedAndDefaulted() throws {
        let settings = try decode(LearnerSettings.self, #"{"goal": 500, "reminder": "25:99", "accent": "fr-FR", "slow": "yes"}"#)
        XCTAssertEqual(settings.goal, 100)
        XCTAssertEqual(settings.reminder, "19:00")
        XCTAssertEqual(settings.accent, "en-US")
        XCTAssertFalse(settings.slow)
        XCTAssertEqual(LearnerSettings(goal: 1).goal, 5)
        XCTAssertTrue(LearnerSettings.isValidReminder("07:30"))
        XCTAssertFalse(LearnerSettings.isValidReminder("7:30"))
        XCTAssertEqual(LearnerSettings(reminder: "07:45").reminderComponents.hour, 7)
    }

    func testScoresEncodeAsObjectAndIgnoreUnknownSkills() throws {
        let meaning = try decode(Meaning.self, #"{"id":"m","translation":"t","scores":{"recall":{"value":3,"interval":1,"due":5,"correct":1,"wrong":0,"last":4,"slow":0},"telepathy":{"value":1}}}"#)
        XCTAssertEqual(meaning.scores.count, 1)
        XCTAssertEqual(meaning.scores[.recall]?.hinted, 0)
        XCTAssertEqual(meaning.examples, [])
        XCTAssertEqual(meaning.register, "")
        let data = try JSONEncoder().encode(meaning.scores)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(object?["recall"])
        XCTAssertEqual(try roundTrip(meaning), meaning)
    }

    func testLenientNumbersAndStrings() throws {
        let word = try decode(Word.self, #"{"id":"w","en":"x","level":5,"created":"oops","important":1,"meanings":[{"id":"m","translation":"t","usedExamples":[0,1.0,"a",2]}]}"#)
        XCTAssertEqual(word.level, "5")
        XCTAssertEqual(word.created, 0)
        XCTAssertFalse(word.important)
        XCTAssertEqual(word.collection, "")
        XCTAssertEqual(word.meanings[0].usedExamples, [0, 1, 2])
        XCTAssertThrowsError(try decode(Word.self, #"{"id":"w"}"#), "en is required")
    }

    func testVocabTaskRejectsUnknownType() {
        XCTAssertThrowsError(try decode(VocabTask.self, #"{"wordId":"w","meaningId":"m","type":7,"example":0}"#))
        XCTAssertEqual(try? decode(VocabTask.self, #"{"wordId":"w","meaningId":"m","type":2,"example":-3}"#), VocabTask(wordId: "w", meaningId: "m", type: .cloze, example: 0))
    }

    func testCombinedTaskRoundTrip() throws {
        let vocabulary = CombinedTask.vocabulary(mode: .pairs, task: VocabTask(wordId: "w", meaningId: "m", type: .cloze, example: 1))
        let reading = Reading(id: "r", title: "T", level: "A2", paragraphs: ["P"], questions: [ReadingQuestion(question: "Q", options: ["a", "b", "c", "d"], answer: 1)])
        let question = CombinedTask.question(CombinedQuestionTask(mode: .reading, question: PracticeQuestion(category: .grammar, prompt: "Q", context: "", options: ["a", "b", "c", "d"], answer: 1), level: "A2", reading: reading, readingIndex: 0))
        for task in [vocabulary, question] {
            XCTAssertEqual(try roundTrip(task), task)
        }
        let data = try JSONEncoder().encode(vocabulary)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["kind"] as? String, "vocabulary")
        XCTAssertEqual(object?["mode"] as? String, "pairs")
        XCTAssertThrowsError(try decode(CombinedTask.self, #"{"kind":"other","mode":"mixed"}"#))
        let session = CombinedSession(id: "c", modes: [.pairs, .reading], random: true, minutes: 10, tasks: [vocabulary, question], updatedAt: 1)
        XCTAssertEqual(try roundTrip(session), session)
        let padded = try decode(CombinedSession.self, #"{"id":"c","modes":["mixed","bogus"],"random":false,"minutes":5,"tasks":[],"answers":[null,null],"index":9,"updatedAt":1}"#)
        XCTAssertEqual(padded.modes, [.mixed])
        XCTAssertEqual(padded.answers.count, 0)
        XCTAssertEqual(padded.index, 0)
    }

    func testProductionSessionAndResultEncoding() throws {
        let item = ProductionItem(context: "I ________ (być) here.", hintPl: "być", answer: "am", rule: "to be")
        var session = ProductionSession(id: "p", set: ProductionSet(title: "t", level: "A1", items: [item, item]))
        session.results[0] = ProductionResult(correct: true, spellingCorrect: true, diagnosis: nil, explanation: "ok")
        XCTAssertEqual(try roundTrip(session), session)
        let data = try JSONEncoder().encode(session.results[0])
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"diagnosis\":null"))
        let result = try decode(ProductionResult.self, #"{"correct":false,"spellingCorrect":true,"diagnosis":"wrong_tense","explanation":"x"}"#)
        XCTAssertEqual(result.diagnosis, .wrongTense)
    }

    func testAIPayloadsDecodeLeniently() throws {
        let grade = try decode(Grade.self, #"{"verdict":"maybe","explanation":"?"}"#)
        XCTAssertEqual(grade.verdict, .uncertain)
        XCTAssertFalse(grade.isFailure)
        let lookup = try decode(Lookup.self, #"{"term":"bank","meanings":[{"translation":"bank","examples":[{"en":"The bank is closed.","pl":"Bank jest zamknięty.","focusEn":"bank","focusPl":"Bank"}],"acceptedAnswers":["bank"]},{"definition":"no translation"}]}"#)
        XCTAssertEqual(lookup.meanings.count, 1, "malformed senses are skipped")
        XCTAssertEqual(lookup.meanings[0].register, "neutralny")
        XCTAssertTrue(lookup.exists)
    }

    func testPracticeAndReadingSessionsPadAnswers() throws {
        let reading = try decode(ReadingSession.self, #"{"reading":{"id":"r","title":"T","level":"A1","paragraphs":["p"],"questions":[{"question":"q","options":["a","b"],"answer":0},{"question":"q2","options":["a","b"],"answer":1}]},"answers":[1],"submitted":false}"#)
        XCTAssertEqual(reading.answers, [1, -1])
        XCTAssertEqual(reading.correctCount, 0)
        XCTAssertEqual(reading.reading.source, .starter)
        let question = try decode(PracticeQuestion.self, #"{"category":"idiom","prompt":"p","context":"c","options":["a","b","c","d"],"answer":2}"#)
        XCTAssertNil(question.format)
        XCTAssertFalse(question.isInput)
        XCTAssertEqual(question.correctOption, "c")
    }

    func testStateEncodingContainsRequiredNullableKeys() throws {
        let data = try JSONEncoder().encode(LearnerState.empty)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        for key in ["session", "combined", "reading", "practice", "production"] {
            XCTAssertTrue(object?[key] is NSNull, key)
        }
        XCTAssertEqual(try roundTrip(LearnerState.empty), LearnerState.empty)
    }

    func testDateHelpersAndRounding() {
        XCTAssertEqual(Date(timestamp: 1_000).timeIntervalSince1970, 1)
        XCTAssertEqual(Date(timeIntervalSince1970: 2).timestamp, 2_000)
        XCTAssertEqual(jsRoundInt(2.5), 3)
        XCTAssertEqual(jsRoundInt(-2.5), -2)
        XCTAssertEqual(jsRoundInt(.nan), 0)
        var generator = SeededGenerator(seed: 42)
        var other = SeededGenerator(seed: 42)
        XCTAssertEqual(generator.next(), other.next())
        let unit = generator.nextUnit()
        XCTAssertTrue(unit >= 0 && unit < 1)
        XCTAssertEqual(SeededGenerator(seed: "abc"), SeededGenerator(seed: "abc"))
    }
}
