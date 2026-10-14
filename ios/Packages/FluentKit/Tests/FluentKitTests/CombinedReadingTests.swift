import Foundation
import XCTest
@testable import FluentKit

/// Readings in combined sessions (FEEDBACK-1 F4): every passage brings at least 3 questions,
/// the questions of one passage stay together (also in random order) and the passage counts
/// against the time budget as one block.
final class CombinedReadingTests: XCTestCase {

    /// Synthetic banks where every passage (all levels) has `questions` questions.
    private func content(questionsPerReading questions: Int, readingsPerLevel: Int = 3) -> PracticeContent {
        var content = TestData.syntheticContent()
        let readings = CEFR.levels.flatMap { (level: String) -> [Reading] in
            (0..<readingsPerLevel).map { (index: Int) -> Reading in
                Reading(
                    id: "r-\(level)-\(index)",
                    title: "Text \(level) \(index)",
                    level: level,
                    paragraphs: ["One.", "Two."],
                    questions: (0..<questions).map { (number: Int) -> ReadingQuestion in
                        ReadingQuestion(question: "Q\(number)?", options: ["a", "b", "c", "d"], answer: number % 4)
                    }
                )
            }
        }
        content.readings = ReadingBank(readings: readings)
        return content
    }

    /// Reading questions per passage id, checking that each passage is one contiguous block
    /// with question indices 0, 1, 2, …
    private func readingBlocks(_ tasks: [CombinedTask], file: StaticString = #filePath, line: UInt = #line) -> [String: Int] {
        var counts: [String: Int] = [:]
        var previous: String?
        var expectedIndex = 0
        for task in tasks {
            let id = task.questionTask?.reading?.id
            if let id {
                if id != previous {
                    XCTAssertNil(counts[id], "czytanka \(id) rozdzielona innymi zadaniami", file: file, line: line)
                    expectedIndex = 0
                }
                XCTAssertEqual(task.questionTask?.readingIndex, expectedIndex, "kolejność pytań \(id)", file: file, line: line)
                expectedIndex += 1
                counts[id, default: 0] += 1
            }
            previous = id
        }
        return counts
    }

    private func session(modes: [StudyMode], minutes: Int, random: Bool, content: PracticeContent, seed: UInt64) -> CombinedSession {
        var generator = SeededGenerator(seed: seed)
        return CombinedSessionBuilder.makeSession(
            state: TestData.seed(),
            modes: modes,
            minutes: minutes,
            random: random,
            content: content,
            now: testNow,
            id: "s-\(seed)",
            using: &generator
        )
    }

    func testReadingBudgetOfOneStillBringsTheWholePassage() {
        let banks = content(questionsPerReading: 4)
        // 8 modes in 5 minutes = 1 task of budget per mode (the case from the feedback).
        let modes: [StudyMode] = [.grammar, .idioms, .production, .languageMix, .reading, .mixed, .pairs, .mistakes]
        for random in [false, true] {
            let result = session(modes: modes, minutes: 5, random: random, content: banks, seed: 7)
            let blocks = readingBlocks(result.tasks)
            XCTAssertEqual(blocks.count, 1)
            XCTAssertEqual(blocks.values.first, 4, "all questions of the passage, not prefix(1)")
        }
    }

    func testEveryPassageHasAtLeastThreeQuestionsAndStaysTogether() {
        for questions in 3...6 {
            let banks = content(questionsPerReading: questions)
            for seed in UInt64(1)...UInt64(25) {
                let result = session(modes: [.grammar, .reading, .idioms], minutes: 15, random: true, content: banks, seed: seed)
                let blocks = readingBlocks(result.tasks)
                XCTAssertFalse(blocks.isEmpty)
                for (id, count) in blocks {
                    XCTAssertEqual(count, questions, "\(id): \(count) pytań")
                    XCTAssertGreaterThanOrEqual(count, CombinedSessionBuilder.minReadingQuestions)
                }
                // Random order still alternates modes between blocks.
                let modes = CombinedSessionBuilder.taskBlocks(result.tasks).compactMap { $0.first?.mode }
                for index in modes.indices.dropFirst() where modes[index] == modes[index - 1] {
                    // Allowed only when no other mode was left.
                    let rest = modes[index...]
                    XCTAssertTrue(rest.allSatisfy { $0 == modes[index] }, "seed \(seed): \(modes)")
                }
            }
        }
    }

    func testReadingBlockCountsAgainstTheBudgetOfOtherModes() {
        // 5 minutes, two modes: 4 + 4 tasks of budget.
        let long = session(modes: [.grammar, .reading], minutes: 5, random: false, content: content(questionsPerReading: 6), seed: 3)
        XCTAssertEqual(long.tasks.filter { $0.mode == .reading }.count, 6)
        XCTAssertEqual(long.tasks.filter { $0.mode == .grammar }.count, 2, "the passage takes 2 tasks from grammar")
        XCTAssertEqual(long.tasks.count, 8)

        let short = session(modes: [.grammar, .reading], minutes: 5, random: false, content: content(questionsPerReading: 3), seed: 3)
        XCTAssertEqual(short.tasks.filter { $0.mode == .reading }.count, 3, "a second passage would not fit (1 task left)")
        XCTAssertEqual(short.tasks.filter { $0.mode == .grammar }.count, 5, "the unused task goes to grammar")
        XCTAssertEqual(short.tasks.count, 8)

        // 15 minutes, two modes: 12 tasks for reading = three passages of 4 questions.
        let three = session(modes: [.grammar, .reading], minutes: 15, random: true, content: content(questionsPerReading: 4), seed: 5)
        XCTAssertEqual(readingBlocks(three.tasks).count, 3)
        XCTAssertEqual(three.tasks.count, 24)
    }

    func testSamePassageIsNeverRepeatedInOneSession() {
        // Only one passage per level: the second reading block would repeat it.
        let banks = content(questionsPerReading: 3, readingsPerLevel: 1)
        let result = session(modes: [.grammar, .reading], minutes: 15, random: false, content: banks, seed: 1)
        let blocks = readingBlocks(result.tasks)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.values.first, 3)
    }

    func testOrderTasksKeepsReadingBlocksIntact() {
        let banks = content(questionsPerReading: 5)
        let ordered = session(modes: [.grammar, .reading, .idioms], minutes: 10, random: false, content: banks, seed: 2)
        for seed in UInt64(1)...UInt64(30) {
            var generator = SeededGenerator(seed: seed)
            let shuffled = CombinedSessionBuilder.orderTasks(ordered.tasks, random: true, using: &generator)
            XCTAssertEqual(shuffled.count, ordered.tasks.count)
            XCTAssertEqual(Set(shuffled.map { $0 }), Set(ordered.tasks.map { $0 }))
            _ = readingBlocks(shuffled)
        }
    }

    func testFinishedSessionWritesOneHistoryEntryPerPassage() {
        var state = TestData.seed()
        var generator = SeededGenerator(seed: 4)
        state.combined = CombinedSessionBuilder.makeSession(state: state, modes: [.grammar, .reading], minutes: 10, random: true, content: content(questionsPerReading: 4), now: testNow, id: "c", using: &generator)
        let readingCount = state.combined?.tasks.filter { $0.mode == .reading }.count ?? 0
        var guardCounter = 0
        while state.combined?.completedAt == nil && guardCounter < 100 {
            let answer = CombinedAnswer(value: "0", correct: true, seconds: 2)
            state = CombinedSessionBuilder.advance(CombinedSessionBuilder.saveAnswer(state, answer: answer, now: testNow, reviewID: "r-\(guardCounter)"), now: testNow)
            guardCounter += 1
        }
        let entries = state.readingHistory.suffix(readingCount / 4)
        XCTAssertEqual(readingCount, 8)
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.allSatisfy { $0.total == 4 && $0.correct == 4 })
    }

    /// The real bank: every passage has 3–6 questions, and a session at every level brings
    /// whole passages.
    func testBuiltInReadingsAlwaysBringAtLeastThreeQuestions() throws {
        let banks = try TestData.practiceContent()
        XCTAssertTrue(banks.readings.readings.allSatisfy { (3...6).contains($0.questions.count) })
        let tasks = CombinedSessionBuilder.readingTasks(budget: 1, level: "B2", history: [], bank: banks.readings, now: testNow)
        XCTAssertGreaterThanOrEqual(tasks.count, CombinedSessionBuilder.minReadingQuestions)
        for level in CEFR.levels {
            let block = CombinedSessionBuilder.readingTasks(budget: 1, level: level, history: [], bank: banks.readings, now: testNow)
            let passage: Reading? = block.first?.questionTask?.reading
            let expected = passage.map { (reading: Reading) -> Int in
                min(reading.questions.count, CombinedSessionBuilder.maxReadingQuestions)
            } ?? -1
            XCTAssertEqual(block.count, expected, level)
        }
    }
}
