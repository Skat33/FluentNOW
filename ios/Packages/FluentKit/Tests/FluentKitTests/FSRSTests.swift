import XCTest
@testable import FluentKit

/// FSRS-6 scheduler (I1). Reference values come from the official ts-fsrs test suite
/// (`packages/fsrs/__tests__/FSRS-6.test.ts`) and from a Node port of the same formulas
/// (`ios/docs/reports/fsrs.md` §6), which reproduces the ts-fsrs values exactly.
final class FSRSTests: XCTestCase {
    // MARK: Model (official reference values)

    func testDefaultParametersAreFSRS6() {
        XCTAssertEqual(FSRS.defaultParameters.count, 21)
        XCTAssertEqual(FSRS.defaultParameters.first ?? 0, 0.212, accuracy: 1e-12)
        XCTAssertEqual(FSRS.defaultParameters.last ?? 0, 0.1542, accuracy: 1e-12)
        XCTAssertEqual(FSRS.retrievability(elapsedDays: 10, stability: 10), 0.9, accuracy: 1e-9, "R(S, S) = 90%")
    }

    func testFirstReviewMatchesTsFsrs() {
        let expectedStability = [0.212, 1.2931, 2.3065, 8.2956]
        let expectedDifficulty = [6.4133, 5.11217071, 2.11810397, 1]
        for (index, rating) in FSRS.Rating.allCases.enumerated() {
            let state = FSRS.nextState(nil, elapsedDays: 0, rating: rating)
            XCTAssertEqual(state.stability, expectedStability[index], accuracy: 1e-6, "\(rating)")
            XCTAssertEqual(state.difficulty, expectedDifficulty[index], accuracy: 1e-6, "\(rating)")
        }
    }

    func testMemoryStateSequenceMatchesTsFsrs() {
        // ts-fsrs „memory state[short-term]”: Again, Good ×5 with delta_t [0, 0, 1, 3, 8, 21].
        let ratings: [FSRS.Rating] = [.again, .good, .good, .good, .good, .good]
        let deltas: [Double] = [0, 0, 1, 3, 8, 21]
        var state: FSRS.MemoryState?
        for (rating, delta) in zip(ratings, deltas) {
            state = FSRS.nextState(state, elapsedDays: delta, rating: rating)
        }
        XCTAssertEqual(state?.stability ?? 0, 53.62691, accuracy: 1e-4)
        XCTAssertEqual(state?.difficulty ?? 0, 6.3574867, accuracy: 1e-5)
    }

    func testIntervalHistoryMatchesTsFsrs() {
        // ts-fsrs „ivl_history” (learning steps 1 m / 10 m, relearning 10 m, max 36 500 days):
        // G G G G G G A A G G G G G → [0, 2, 11, 46, 163, 498, 0, 0, 2, 4, 7, 12, 21].
        let ratings: [FSRS.Rating] = [.good, .good, .good, .good, .good, .good, .again, .again, .good, .good, .good, .good, .good]
        var state: FSRS.MemoryState?
        var elapsed: Double = 0
        var intervals: [Double] = []
        var inSteps = true
        for (index, rating) in ratings.enumerated() {
            state = FSRS.nextState(state, elapsedDays: elapsed, rating: rating)
            if rating == .again || (index == 0 && inSteps) {
                // learning / relearning step: back the same day
                inSteps = true
                intervals.append(0)
                elapsed = 0
                continue
            }
            inSteps = false
            let interval = FSRS.interval(stability: state?.stability ?? 0, retention: 0.9, maximum: 36_500)
            intervals.append(interval)
            elapsed = interval
        }
        XCTAssertEqual(intervals, [0, 2, 11, 46, 163, 498, 0, 0, 2, 4, 7, 12, 21])
    }

    func testRetrievabilityMatchesTsFsrs() {
        // ts-fsrs: Easy on a new card (S 8.2956) evaluated at its due date 8 days later.
        XCTAssertEqual(FSRS.retrievability(elapsedDays: 8, stability: 8.2956), 0.9024733, accuracy: 1e-6)
        XCTAssertEqual(FSRS.retrievability(elapsedDays: 3, stability: 0), 0)
    }

    func testDesiredRetentionChangesInterval() {
        XCTAssertEqual(FSRS.interval(stability: 10, retention: 0.85, maximum: 365), 19)
        XCTAssertEqual(FSRS.interval(stability: 10, retention: 0.9, maximum: 365), 10)
        XCTAssertEqual(FSRS.interval(stability: 10, retention: 0.95, maximum: 365), 4)
        XCTAssertEqual(FSRS.interval(stability: 0.001, retention: 0.9, maximum: 365), 1, "at least one day")
        XCTAssertEqual(FSRS.interval(stability: 30_000, retention: 0.9, maximum: 365), 365)
        XCTAssertEqual(FSRS.clampedRetention(.nan), 0.9)
        XCTAssertEqual(FSRS.clampedRetention(2), 0.97)
    }

    func testInvalidStatesAreRepairedOrTreatedAsNew() {
        XCTAssertNil(FSRS.validated(FSRS.MemoryState(stability: .nan, difficulty: 5)))
        XCTAssertNil(FSRS.validated(FSRS.MemoryState(stability: 0, difficulty: 5)))
        XCTAssertEqual(FSRS.validated(FSRS.MemoryState(stability: 5, difficulty: 42))?.difficulty, 10)
        let fresh = FSRS.nextState(FSRS.MemoryState(stability: -1, difficulty: 3), elapsedDays: 4, rating: .good)
        XCTAssertEqual(fresh.stability, 2.3065, accuracy: 1e-9, "an invalid state starts over")
        let weird = FSRS.nextState(FSRS.MemoryState(stability: 5, difficulty: 5), elapsedDays: .nan, rating: .good)
        XCTAssertTrue(weird.stability.isFinite)
    }

    // MARK: Rating of answers

    func testAnswerRating() {
        XCTAssertEqual(Scheduler.rating(correct: false, hint: false, seconds: 2, confidence: 3, type: .recall), .again)
        XCTAssertEqual(Scheduler.rating(correct: true, hint: true, seconds: 2, confidence: 3, type: .recall), .hard)
        XCTAssertEqual(Scheduler.rating(correct: true, hint: false, typo: true, seconds: 2, confidence: 3, type: .recall), .hard)
        XCTAssertEqual(Scheduler.rating(correct: true, hint: false, seconds: 16, confidence: 2, type: .recall), .hard, "slow")
        XCTAssertEqual(Scheduler.rating(correct: true, hint: false, seconds: 3, confidence: 1, type: .recall), .hard, "unsure")
        XCTAssertEqual(Scheduler.rating(correct: true, hint: false, seconds: 7.5, confidence: 3, type: .recall), .easy)
        XCTAssertEqual(Scheduler.rating(correct: true, hint: false, seconds: 8, confidence: 3, type: .recall), .good, "sure but not fast")
        XCTAssertEqual(Scheduler.rating(correct: true, hint: false, seconds: 2, confidence: 2, type: .recall), .good, "fast but default confidence")
        XCTAssertEqual(Scheduler.rating(correct: true, hint: false, seconds: .nan, confidence: 2, type: .cloze), .good)
    }

    // MARK: Scheduler (app-level reference values from the Node port)

    func testGoodAnswersFollowFSRSIntervals() {
        var score: Score?
        var now = testNow
        var intervals: [Double] = []
        for _ in 0..<5 {
            let next = Scheduler.schedule(score, correct: true, seconds: 5, confidence: 2, hint: false, now: now, type: .recall)
            intervals.append(next.interval)
            XCTAssertEqual(next.due, now + next.interval * day, accuracy: 1)
            XCTAssertEqual(next.value, Mastery.fromInterval(next.interval))
            now = next.due
            score = next
        }
        XCTAssertEqual(intervals, [2, 11, 46, 163, 365])
        XCTAssertEqual(score?.stability ?? 0, 497.447194, accuracy: 1e-3)
        XCTAssertEqual(score?.difficulty ?? 0, 2.090586, accuracy: 1e-5)
        XCTAssertEqual(score?.reps, 5)
        XCTAssertEqual(score?.lapses, 0)
        XCTAssertEqual(score?.correct, 5)
    }

    func testLapseReturnsInTenMinutesAndKeepsReducedStability() {
        var score: Score?
        var now = testNow
        for _ in 0..<7 {
            let next = Scheduler.schedule(score, correct: true, seconds: 5, confidence: 2, hint: false, now: now, type: .recall)
            now = next.due
            score = next
        }
        let lapse = Scheduler.schedule(score, correct: false, seconds: 5, confidence: 2, hint: false, now: now, type: .recall)
        XCTAssertEqual(lapse.interval, 10.0 / 1440.0, accuracy: 1e-12)
        XCTAssertEqual(lapse.due, now + 10 * 60_000, accuracy: 1)
        XCTAssertEqual(lapse.stability ?? 0, 9.239223, accuracy: 1e-4)
        XCTAssertEqual(lapse.difficulty ?? 0, 7.380949, accuracy: 1e-5)
        XCTAssertEqual(lapse.lapses, 1)
        XCTAssertEqual(lapse.wrong, 1)
        // The failed task comes back in the same session: a same-day Good keeps the stability.
        let retry = Scheduler.schedule(lapse, correct: true, seconds: 5, confidence: 2, hint: false, now: now + 10 * 60_000, type: .recall)
        XCTAssertEqual(retry.interval, 9)
        XCTAssertEqual(retry.stability ?? 0, 9.239223, accuracy: 1e-4)
        XCTAssertEqual(retry.wrong, 0)
    }

    func testFirstAnswerPerRating() {
        let again = Scheduler.schedule(nil, correct: false, seconds: 5, confidence: 2, hint: false, now: testNow, type: .recall)
        let hard = Scheduler.schedule(nil, correct: true, seconds: 5, confidence: 2, hint: true, now: testNow, type: .recall)
        let good = Scheduler.schedule(nil, correct: true, seconds: 5, confidence: 2, hint: false, now: testNow, type: .recall)
        let easy = Scheduler.schedule(nil, correct: true, seconds: 2, confidence: 3, hint: false, now: testNow, type: .recall)
        XCTAssertEqual(again.interval, 10.0 / 1440.0, accuracy: 1e-12)
        XCTAssertEqual([hard.interval, good.interval, easy.interval], [1, 2, 8])
        XCTAssertEqual(again.stability ?? 0, 0.212, accuracy: 1e-9)
        XCTAssertEqual(easy.difficulty ?? 0, 1, accuracy: 1e-9)
        XCTAssertEqual(again.lapses, 0, "a new card cannot lapse")
    }

    func testReadingWeightMovesStatePartWay() {
        let base = Score(value: 50, interval: 20, due: testNow, correct: 3, wrong: 0, hinted: 0, last: testNow - day, slow: 0)
        let weighted = Scheduler.schedule(base, correct: true, seconds: 15, confidence: 2, hint: false, now: testNow, type: .meaning, weight: 0.35)
        let full = Scheduler.schedule(base, correct: true, seconds: 15, confidence: 2, hint: false, now: testNow, type: .meaning, weight: 1)
        XCTAssertEqual(weighted.interval, 21)
        XCTAssertEqual(full.interval, 22)
        XCTAssertEqual(weighted.stability ?? 0, 20.866335, accuracy: 1e-4)
        // Even when FSRS would not grow the interval (same day), a reading never shortens it.
        let sameDay = Scheduler.schedule(full, correct: true, seconds: 15, confidence: 2, hint: false, now: testNow + 60_000, type: .meaning, weight: 0.35)
        XCTAssertGreaterThanOrEqual(sameDay.interval, full.interval)
        XCTAssertGreaterThanOrEqual(sameDay.stability ?? 0, full.stability ?? 0)
    }

    func testReadingAnswersAreGoodNotHard() {
        var state = TestData.emptyState()
        state.words = [TestData.freshWord("gate", "gate", "bramka")]
        var score = Scheduler.schedule(nil, correct: true, seconds: 5, confidence: 2, hint: false, now: testNow - 3 * day, type: .meaning)
        state.words[0].meanings[0].scores[.recognition] = score
        let task = VocabTask(wordId: "gate", meaningId: "m-gate", type: .meaning, example: 0)
        let next = Scheduler.recordAnswer(state, task: task, correct: true, seconds: 15, confidence: 2, hint: false, weight: Scheduler.readingWeight, source: .reading, now: testNow, reviewID: "r")
        score = next.words[0].meanings[0].scores[.recognition] ?? Score()
        // Good lowers difficulty slightly; Hard (15 s > 12 s) would have raised it by about 3 × 0.35.
        XCTAssertLessThanOrEqual(score.difficulty ?? 10, 2.118104 + 1e-6)
    }

    // MARK: Migration of legacy (web / pre-FSRS) scores

    func testLegacyScoreIsMigratedAtFirstAnswer() {
        let legacy = Score(value: 31, interval: 3, due: testNow, correct: 2, wrong: 1, hinted: 1, last: testNow - 3 * day, slow: 0)
        XCTAssertNil(legacy.memoryState)
        let memory = Scheduler.legacyMemory(legacy)
        XCTAssertEqual(memory?.stability ?? 0, 3, accuracy: 1e-9)
        XCTAssertEqual(memory?.difficulty ?? 0, 2.118104 + 1.2 + 0.4, accuracy: 1e-5)
        let good = Scheduler.schedule(legacy, correct: true, seconds: 5, confidence: 2, hint: false, now: testNow, type: .recall)
        XCTAssertEqual(good.interval, 13)
        XCTAssertEqual(good.stability ?? 0, 12.801129, accuracy: 1e-4)
        XCTAssertEqual(good.difficulty ?? 0, 3.709614, accuracy: 1e-5)
        XCTAssertEqual(good.reps, 4, "legacy reps = correct + wrong, plus this answer")
        XCTAssertEqual(good.correct, 3)
        let again = Scheduler.schedule(legacy, correct: false, seconds: 5, confidence: 2, hint: false, now: testNow, type: .recall)
        XCTAssertEqual(again.stability ?? 0, 0.709647, accuracy: 1e-4)
        XCTAssertEqual(again.lapses, 2)
        // A „Trudne” legacy score (3 errors) starts with a high difficulty.
        let hard = Score(value: 0, interval: 0.1, due: 0, correct: 0, wrong: 3, hinted: 0, last: 1, slow: 0)
        XCTAssertGreaterThan(Scheduler.legacyMemory(hard)?.difficulty ?? 0, 5.7)
        XCTAssertNil(Scheduler.legacyMemory(Score()), "never answered = new")
    }

    func testLegacyJSONDecodesWithoutFSRSAndEncodesWithoutNewKeys() throws {
        let json = #"{"value":31,"interval":3,"due":5,"correct":1,"wrong":0,"hinted":0,"last":5,"slow":0}"#
        let decoded = try JSONDecoder().decode(Score.self, from: Data(json.utf8))
        XCTAssertNil(decoded.stability)
        XCTAssertNil(decoded.difficulty)
        XCTAssertNil(decoded.reps)
        XCTAssertNil(decoded.lapses)
        let encoded = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        XCTAssertFalse(encoded.contains("stability"), "web-compatible export: no FSRS keys for legacy scores")
        XCTAssertFalse(encoded.contains("reps"))

        let fsrs = Scheduler.schedule(decoded, correct: true, seconds: 5, confidence: 2, hint: false, now: 5 + 3 * day, type: .recall)
        let roundTrip = try JSONDecoder().decode(Score.self, from: try JSONEncoder().encode(fsrs))
        XCTAssertEqual(roundTrip, fsrs)
        XCTAssertNotNil(roundTrip.memoryState)

        let half = #"{"value":31,"interval":3,"due":5,"correct":1,"last":5,"stability":4}"#
        XCTAssertNil(try JSONDecoder().decode(Score.self, from: Data(half.utf8)).stability, "half a state is legacy")
        let broken = #"{"interval":3,"last":5,"stability":-2,"difficulty":4,"reps":-3}"#
        let repaired = try JSONDecoder().decode(Score.self, from: Data(broken.utf8))
        XCTAssertNil(repaired.stability)
        XCTAssertEqual(repaired.reps, 0)
    }

    func testMigrationKeepsLongIntervalsAndDropsInvalidFSRSState() {
        var state = TestData.emptyState()
        var word = TestData.freshWord("w", "word", "słowo")
        word.meanings[0].scores[.recall] = Score(value: 100, interval: 200, due: testNow, correct: 6, last: testNow - day, stability: 210, difficulty: 3, reps: 6, lapses: 0)
        word.meanings[0].scores[.listening] = Score(interval: 3, correct: 1, last: 1, stability: .nan, difficulty: 5)
        word.meanings[0].scores[.usage] = Score(interval: 3, correct: 1, last: 1, stability: 4, difficulty: nil, reps: -1)
        word.meanings[0].scores[.spelling] = Score(interval: 900, correct: 1, last: 1)
        state.words = [word]
        let migrated = StateMigration.migrate(state)
        let scores = migrated.words[0].meanings[0].scores
        XCTAssertEqual(scores[.recall]?.interval, 200, "FSRS intervals above 90 days survive every load")
        XCTAssertEqual(scores[.recall]?.stability, 210)
        XCTAssertNil(scores[.listening]?.stability)
        XCTAssertNil(scores[.listening]?.difficulty)
        XCTAssertNil(scores[.usage]?.stability)
        XCTAssertEqual(scores[.usage]?.reps, 0)
        XCTAssertEqual(scores[.spelling]?.interval, 365)
        XCTAssertEqual(StateMigration.migrate(migrated), migrated, "idempotent")
    }

    // MARK: Settings

    func testDesiredRetentionSettingIsOptionalAndUsedByRecordAnswer() throws {
        let legacy = try JSONDecoder().decode(LearnerSettings.self, from: Data(#"{"goal":20}"#.utf8))
        XCTAssertNil(legacy.desiredRetention)
        XCTAssertEqual(legacy.effectiveRetention, 0.9)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(legacy), as: UTF8.self).contains("desiredRetention"))
        let chosen = try JSONDecoder().decode(LearnerSettings.self, from: Data(#"{"desiredRetention":0.95}"#.utf8))
        XCTAssertEqual(chosen.effectiveRetention, 0.95, accuracy: 1e-12)
        let wild = try JSONDecoder().decode(LearnerSettings.self, from: Data(#"{"desiredRetention":7}"#.utf8))
        XCTAssertEqual(wild.effectiveRetention, 0.97, accuracy: 1e-12)

        func secondInterval(retention: Double?) -> Double? {
            var state = TestData.emptyState()
            state.settings.desiredRetention = retention
            state.words = [TestData.freshWord("gate", "gate", "bramka")]
            let task = VocabTask(wordId: "gate", meaningId: "m-gate", type: .recall, example: 0)
            state = Scheduler.recordAnswer(state, task: task, correct: true, seconds: 5, confidence: 2, hint: false, now: testNow, reviewID: "a")
            state = Scheduler.recordAnswer(state, task: task, correct: true, seconds: 5, confidence: 2, hint: false, now: testNow + 2 * day, reviewID: "b")
            return state.words[0].meanings[0].scores[.recall]?.interval
        }
        XCTAssertEqual(secondInterval(retention: nil), 11)
        XCTAssertEqual(secondInterval(retention: 0.85), 21)
        XCTAssertEqual(secondInterval(retention: 0.95), 4)
    }

    func testAcceptedTypoIsHardForTheSkill() {
        let state = TestData.seed()
        let next = Scheduler.recordAnswer(state, task: VocabTask(wordId: "w6", meaningId: "m6", type: .recall, example: 0), correct: true, seconds: 4, confidence: 3, hint: false, spellingCorrect: false, now: testNow, reviewID: "r")
        let recall = next.word(en: "bank")?.meanings[0].scores[.recall]
        XCTAssertEqual(recall?.interval, 10)
        XCTAssertEqual(recall?.stability ?? 0, 10.189534, accuracy: 1e-4)
        XCTAssertEqual(next.word(en: "bank")?.meanings[0].scores[.spelling]?.interval ?? 1, 10.0 / 1440.0, accuracy: 1e-12)
    }

    // MARK: iCloud merge

    func testMergeTakesWholeFSRSStatePerSkillByLastAnswer() {
        var local = TestData.freshWord("w", "word", "słowo")
        var remote = local
        local.updatedAt = testNow
        remote.updatedAt = testNow - day
        let localRecall = Score(interval: 10, due: testNow + 10 * day, correct: 3, last: testNow, stability: 10, difficulty: 4, reps: 3, lapses: 0)
        let remoteRecall = Score(interval: 50, due: testNow + 40 * day, correct: 4, last: testNow - 10 * day, stability: 50, difficulty: 2, reps: 4, lapses: 0)
        let localListening = Score(interval: 3, due: testNow, correct: 1, last: testNow - 5 * day, stability: 3, difficulty: 6, reps: 1, lapses: 0)
        let remoteListening = Score(interval: 0.01, due: testNow, correct: 1, wrong: 1, last: testNow - day, stability: 1.2, difficulty: 7.5, reps: 2, lapses: 1)
        let legacyUsage = Score(interval: 3, due: testNow, correct: 1, last: testNow - 2 * day)
        let fsrsUsage = Score(interval: 3, due: testNow, correct: 1, last: testNow - 2 * day, stability: 3, difficulty: 5, reps: 1, lapses: 0)
        local.meanings[0].scores = SkillScores([.recall: localRecall, .listening: localListening, .usage: legacyUsage])
        remote.meanings[0].scores = SkillScores([.recall: remoteRecall, .listening: remoteListening, .usage: fsrsUsage])
        for merged in [StateSync.mergeWord(local, remote), StateSync.mergeWord(remote, local)] {
            let scores = merged.meanings[0].scores
            XCTAssertEqual(scores[.recall], localRecall, "later answer wins with its own S/D")
            XCTAssertEqual(scores[.listening], remoteListening, "the lapse on the other device is kept")
            XCTAssertEqual(scores[.usage], fsrsUsage, "same answer: the copy with an FSRS state wins")
        }
    }
}
