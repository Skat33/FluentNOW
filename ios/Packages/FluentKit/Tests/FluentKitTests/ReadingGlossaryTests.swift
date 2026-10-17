import Foundation
import XCTest
@testable import FluentKit

/// FEEDBACK-2 G1: contextual glossary, highlights, read-then-answer flow.
final class ReadingGlossaryTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    private func sampleReading(glossary: [ReadingGlossaryEntry] = []) -> Reading {
        Reading(
            id: "r",
            title: "Table",
            level: "A2",
            paragraphs: [
                "Ruby booked a table by the window. The waiter checked the booking and apologized.",
                "They took a photo by the river.",
            ],
            questions: [
                ReadingQuestion(question: "Q1", options: ["a", "b", "c", "d"], answer: 0, evidence: "Ruby booked a table"),
                ReadingQuestion(question: "Q2", options: ["a", "b", "c", "d"], answer: 1, evidence: "checked the booking … apologized"),
            ],
            glossary: glossary
        )
    }

    // MARK: Decoding

    func testGlossaryDecodingIsOptionalAndLenient() throws {
        let old = try decode(Reading.self, #"{"id":"r","title":"T","level":"A1","paragraphs":["P"],"questions":[]}"#)
        XCTAssertEqual(old.glossary, [])

        let json = #"""
        {"id":"r","title":"T","level":"A1","paragraphs":["Ruby booked a table."],"questions":[],
         "glossary":[{"form":"booked","lemma":"book","translation":"zarezerwować","ipa":"/bʊk/","ref":"restaurant/restaurant.book"},
                     {"form":"table","translation":"stolik"},
                     {"form":"","lemma":"x","translation":"y"},
                     {"lemma":"x"},
                     7]}
        """#
        let reading = try decode(Reading.self, json)
        XCTAssertEqual(reading.glossary.count, 2)
        XCTAssertEqual(reading.glossary[0], ReadingGlossaryEntry(form: "booked", lemma: "book", translation: "zarezerwować", ipa: "/bʊk/", ref: "restaurant/restaurant.book"))
        XCTAssertEqual(reading.glossary[0].contentReference?.file, "restaurant")
        XCTAssertEqual(reading.glossary[1].lemma, "table", "brak lematu → forma")
        XCTAssertNil(reading.glossary[1].ref)
        XCTAssertNil(reading.glossaryEntry(at: 5))

        let data = try JSONEncoder().encode(reading)
        XCTAssertEqual(try JSONDecoder().decode(Reading.self, from: data), reading)
    }

    func testBankReadingsHaveValidGlossaries() throws {
        let bank = try ContentDecoder.readings(from: try TestData.contentData("readings.json"))
        XCTAssertFalse(bank.readings.isEmpty)
        for reading in bank.readings {
            XCTAssertTrue((8...20).contains(reading.glossary.count), "\(reading.id): \(reading.glossary.count) pozycji")
            var forms = Set<String>()
            for entry in reading.glossary {
                XCTAssertTrue(forms.insert(entry.form.lowercased()).inserted, "\(reading.id): duplikat \(entry.form)")
                XCTAssertTrue(reading.paragraphs.contains { $0.contains(entry.form) }, "\(reading.id): brak „\(entry.form)” w tekście")
            }
            // Każda pozycja słowniczka jest podświetlana w tekście.
            let highlighted = Set(reading.paragraphs.flatMap { paragraph in
                ReadingTokenizer.tokens(text: paragraph, words: [], glossary: reading.glossary).compactMap { $0.glossaryIndex }
            })
            XCTAssertEqual(highlighted.count, reading.glossary.count, "\(reading.id): nie wszystkie formy są podświetlone")
        }
    }

    // MARK: Tokenizer

    func testTokensCombineSavedWordsAndGlossary() {
        let glossary = [
            ReadingGlossaryEntry(form: "booked", lemma: "book", translation: "zarezerwować"),
            ReadingGlossaryEntry(form: "booking", lemma: "booking", translation: "rezerwacja"),
            ReadingGlossaryEntry(form: "took a photo", lemma: "take a photo", translation: "zrobić zdjęcie"),
            ReadingGlossaryEntry(form: "window", lemma: "window", translation: "okno"),
        ]
        let reading = sampleReading(glossary: glossary)
        let words = [
            TestData.freshWord("w-book", "book", "zarezerwować"),
            TestData.freshWord("w-window", "window", "okno"),
            TestData.freshWord("w-river", "river", "rzeka"),
        ]
        let first = ReadingTokenizer.tokens(text: reading.paragraphs[0], words: words, glossary: glossary)
        XCTAssertEqual(first.map(\.text).joined(), reading.paragraphs[0])
        let booked = first.first { $0.text == "booked" }
        XCTAssertEqual(booked?.glossaryIndex, 0)
        XCTAssertEqual(booked?.wordId, "w-book", "lemat z mojego słownika")
        let window = first.first { $0.text == "window" }
        XCTAssertEqual(window?.glossaryIndex, 3)
        XCTAssertEqual(window?.wordId, "w-window")
        let booking = first.first { $0.text == "booking" }
        XCTAssertEqual(booking?.glossaryIndex, 1)
        XCTAssertNil(booking?.wordId, "„book” nie pasuje wewnątrz „booking”")

        let second = ReadingTokenizer.tokens(text: reading.paragraphs[1], words: words, glossary: glossary)
        XCTAssertEqual(second.map(\.text).joined(), reading.paragraphs[1])
        XCTAssertTrue(second.contains { $0.text == "took a photo" && $0.glossaryIndex == 2 })
        XCTAssertTrue(second.contains { $0.text == "river" && $0.wordId == "w-river" && $0.glossaryIndex == nil })

        let plain = ReadingTokenizer.tokens(text: "Nothing here.", words: [], glossary: [])
        XCTAssertEqual(plain, [ReadingToken(text: "Nothing here.")])
        XCTAssertFalse(plain[0].isHighlighted)
    }

    func testArchivedWordsAreNotHighlighted() {
        var word = TestData.freshWord("w-table", "table", "stolik")
        word.archived = true
        let tokens = ReadingTokenizer.tokens(text: "A table.", words: [word], glossary: [])
        XCTAssertEqual(tokens, [ReadingToken(text: "A table.")])
    }

    // MARK: Text helpers

    func testSentenceAroundOffset() {
        let paragraph = "Ruby booked a table. The waiter apologized! Was it ready? Yes"
        XCTAssertEqual(ReadingText.sentence(in: paragraph, at: 6), "Ruby booked a table.")
        XCTAssertEqual(ReadingText.sentence(in: paragraph, at: 25), "The waiter apologized!")
        XCTAssertEqual(ReadingText.sentence(in: paragraph, at: 50), "Was it ready?")
        XCTAssertEqual(ReadingText.sentence(in: paragraph, at: 999), "Yes")
        XCTAssertEqual(ReadingText.sentence(in: "", at: 3), "")
        let tokens = [ReadingToken(text: "Ruby "), ReadingToken(text: "booked", glossaryIndex: 0), ReadingToken(text: " a table.")]
        XCTAssertEqual(ReadingText.offset(ofToken: 1, in: tokens), 5)
        XCTAssertEqual(ReadingText.offset(ofToken: 0, in: tokens), 0)
    }

    func testEvidenceRanges() {
        let paragraph = "Ruby booked a table by the window. The waiter checked the booking and apologized."
        let ranges = ReadingText.evidenceRanges(in: paragraph, evidence: ["ruby booked a table.", "checked the booking … apologized", "xx", "not in text"])
        XCTAssertEqual(ranges.count, 3)
        XCTAssertEqual(ranges.first, 0..<19)
        let texts = ranges.map { range -> String in
            let chars = Array(paragraph)
            return String(chars[range])
        }
        XCTAssertEqual(texts, ["Ruby booked a table", "checked the booking", "apologized"])
        XCTAssertEqual(ReadingText.evidenceRanges(in: paragraph, evidence: ["booked a table", "Ruby booked"]), [0..<19], "zachodzące zakresy są scalane")
    }

    // MARK: Meaning choice

    func testMeaningChoiceUsesGlossaryReferenceOrTranslation() {
        var word = TestData.freshWord("w", "book", "książka")
        word.meanings.append(Meaning(id: "m-2", translation: "zarezerwować", examples: ["Can I book a table for two?"], contentRef: "restaurant/restaurant.book"))
        let byRef = ReadingMeaningMatcher.choose(word: word, sentence: "Ruby booked a table.", entry: ReadingGlossaryEntry(form: "booked", lemma: "book", translation: "rezerwować", ref: "restaurant/restaurant.book"))
        XCTAssertEqual(byRef, ReadingMeaningChoice(meaningId: "m-2", isConfident: true))
        let byTranslation = ReadingMeaningMatcher.choose(word: word, sentence: "", entry: ReadingGlossaryEntry(form: "booked", lemma: "book", translation: "zarezerwować, zamówić"))
        XCTAssertEqual(byTranslation.meaningId, "m-2")
        let unknown = ReadingMeaningMatcher.choose(word: word, sentence: "", entry: ReadingGlossaryEntry(form: "book", lemma: "book", translation: "księga"))
        XCTAssertEqual(unknown, ReadingMeaningChoice(meaningId: nil, isConfident: false))
    }

    func testMeaningChoiceFromExamplesWithoutGlossary() {
        var word = TestData.freshWord("w", "bank", "bank", example: "I need to go to the bank to pay money into my account.")
        word.meanings.append(Meaning(id: "m-river", translation: "brzeg", examples: ["We had a picnic on the river bank near the trees."]))
        let river = ReadingMeaningMatcher.choose(word: word, sentence: "They walked along the bank of the river under the trees.", entry: nil)
        XCTAssertEqual(river, ReadingMeaningChoice(meaningId: "m-river", isConfident: true))
        let weak = ReadingMeaningMatcher.choose(word: word, sentence: "She opened an account at the bank.", entry: nil)
        XCTAssertEqual(weak, ReadingMeaningChoice(meaningId: "m-w", isConfident: false), "jedno wspólne słowo → zgadywanie")
        let none = ReadingMeaningMatcher.choose(word: word, sentence: "The bank was quiet.", entry: nil)
        XCTAssertEqual(none, ReadingMeaningChoice(meaningId: nil, isConfident: false))
        let single = ReadingMeaningMatcher.choose(word: TestData.freshWord("s", "pen", "długopis"), sentence: "Nothing.", entry: nil)
        XCTAssertEqual(single, ReadingMeaningChoice(meaningId: "m-s", isConfident: true))
    }

    // MARK: Read-then-answer flow

    func testReadingSessionStages() throws {
        var session = ReadingSession(reading: sampleReading())
        XCTAssertEqual(session.stage, .reading)
        XCTAssertEqual(session.unansweredCount, 2)
        session.beginQuestions(at: 100)
        XCTAssertEqual(session.stage, .questions)
        session.beginQuestions(at: 200)
        XCTAssertEqual(session.questionsStartedAt, 100, "idempotentne")
        session.answer(question: 0, choice: 2)
        session.answer(question: 9, choice: 1)
        XCTAssertEqual(session.answers, [2, -1])
        XCTAssertEqual(session.unansweredCount, 1)

        let data = try JSONEncoder().encode(session)
        XCTAssertEqual(try JSONDecoder().decode(ReadingSession.self, from: data), session)

        var answeredOnly = ReadingSession(reading: sampleReading(), answers: [0, -1])
        XCTAssertEqual(answeredOnly.stage, .questions, "odpowiedź bez znacznika (stary zapis) → pytania")
        answeredOnly.submitted = true
        answeredOnly.answer(question: 1, choice: 1)
        XCTAssertEqual(answeredOnly.answers, [0, -1], "po sprawdzeniu bez zmian")
        XCTAssertEqual(answeredOnly.stage, .results)
        answeredOnly.beginQuestions(at: 5)
        XCTAssertNil(answeredOnly.questionsStartedAt)
    }

    func testCombinedReadingBlock() {
        let reading = sampleReading()
        let other = Reading(id: "r2", title: "Other", level: "A2", paragraphs: ["P"], questions: [ReadingQuestion(question: "Q", options: ["a", "b", "c", "d"], answer: 0)])
        func question(_ reading: Reading?, _ index: Int?) -> CombinedTask {
            .question(CombinedQuestionTask(mode: reading == nil ? .grammar : .reading, question: PracticeQuestion(category: .grammar, prompt: "Q", context: "", options: ["a", "b", "c", "d"], answer: 0), level: "A2", reading: reading, readingIndex: index))
        }
        let tasks = [question(nil, nil), question(reading, 0), question(reading, 1), question(other, 0), question(nil, nil)]
        let session = CombinedSession(id: "c", modes: [.grammar, .reading], random: true, minutes: 5, tasks: tasks, updatedAt: 1)
        XCTAssertNil(CombinedReadingBlock.block(in: session, at: 0))
        let first = CombinedReadingBlock.block(in: session, at: 1)
        XCTAssertEqual(first, CombinedReadingBlock(readingID: "r", taskIndices: [1, 2], position: 0))
        XCTAssertEqual(first?.opensBlock, true)
        XCTAssertEqual(first?.closesBlock, false)
        let last = CombinedReadingBlock.block(in: session, at: 2)
        XCTAssertEqual(last?.closesBlock, true)
        XCTAssertEqual(last?.opensBlock, false)
        let single = CombinedReadingBlock.block(in: session, at: 3)
        XCTAssertEqual(single?.taskIndices, [3])
        XCTAssertEqual(single?.opensBlock, true)
        XCTAssertEqual(single?.closesBlock, true)
        XCTAssertNil(CombinedReadingBlock.block(in: session, at: 99))
    }
}
