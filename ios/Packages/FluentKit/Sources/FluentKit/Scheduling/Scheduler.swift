import Foundation

/// The spaced-repetition scheduler (learning.ts `schedule`, `recordAnswer`, `applyReadingResults`).
/// Since round 4 (I1) the interval comes from the FSRS-6 memory model (`FSRS`) instead of the
/// web heuristic. Pure functions: state in → new state out. Time and identifiers are injected.
public enum Scheduler {
    /// Weight of word-in-context answers from readings.
    public static let readingWeight = 0.35
    /// A failed task is re-queued only while the session has fewer tasks than this.
    public static let maxSessionTasks = 100
    /// Longest interval in days (the web heuristic stopped at 90).
    public static let maximumInterval: Double = 365
    /// A wrong answer comes back after 10 minutes (relearning step, as before).
    public static let relearningInterval: Double = 10.0 / 1440.0
    /// A correct answer is „fast” (may be rated Easy) up to this share of `slowSeconds`.
    public static let easySpeedShare = 0.5

    /// FSRS rating of an answer:
    /// - wrong → Again;
    /// - correct after a hint, with an accepted typo, slow (`> type.slowSeconds`) or marked
    ///   „Niepewnie” (confidence 1) → Hard;
    /// - correct, fast (`≤ easySpeedShare × slowSeconds`) and „Bardzo pewnie” (confidence 3) → Easy;
    /// - other correct answers → Good.
    public static func rating(
        correct: Bool,
        hint: Bool,
        typo: Bool = false,
        seconds: Double,
        confidence: Int,
        type: ExerciseType
    ) -> FSRS.Rating {
        guard correct else { return .again }
        let safeSeconds = finiteNonNegative(seconds)
        if hint || typo || confidence <= 1 || safeSeconds > type.slowSeconds { return .hard }
        if confidence >= 3 && safeSeconds <= type.slowSeconds * easySpeedShare { return .easy }
        return .good
    }

    /// `schedule`: next score of one skill after an answer (FSRS-6, default retention 0.90).
    ///
    /// - the answer is rated with `rating(correct:hint:seconds:confidence:type:)`;
    /// - Hard / Good / Easy: the interval is the FSRS interval of the new stability, 1…365 days;
    /// - wrong: 10 minutes (the new, lower stability is kept for the next answer);
    /// - `weight < 1` (readings) moves the memory state only part of the way and never shortens
    ///   the interval.
    public static func schedule(
        _ old: Score?,
        correct: Bool,
        seconds: Double,
        confidence: Int,
        hint: Bool,
        now: Timestamp,
        type: ExerciseType = .recall,
        weight: Double = 1
    ) -> Score {
        let safeSeconds = finiteNonNegative(seconds)
        return review(
            old,
            rating: rating(correct: correct, hint: hint, seconds: safeSeconds, confidence: confidence, type: type),
            hint: hint,
            slow: safeSeconds > type.slowSeconds,
            now: now,
            weight: weight
        )
    }

    /// FSRS step for an already rated answer. `hint` and `slow` only update the counters
    /// (`hinted`, `slow`, `wrong`) that the rest of the app reads.
    public static func review(
        _ old: Score?,
        rating: FSRS.Rating,
        hint: Bool,
        slow: Bool,
        now: Timestamp,
        weight: Double = 1,
        retention: Double = FSRS.defaultRetention
    ) -> Score {
        let score = old ?? Score.empty
        let correct = rating != .again
        let independent = correct && !hint
        var elapsedDays: Double = 0
        if score.last != 0, now.isFinite, score.last.isFinite {
            elapsedDays = max(0, ((now - score.last) / TimeConstants.dayMs).rounded(.down))
        }
        let previous = memory(of: score)
        let full = FSRS.nextState(previous, elapsedDays: elapsedDays, rating: rating)
        var state = full
        var interval = correct
            ? FSRS.interval(stability: full.stability, retention: retention, maximum: maximumInterval)
            : relearningInterval

        let safeWeight = weight.isFinite ? min(1, max(0, weight)) : 1
        if safeWeight < 1 && correct {
            // Readings: part of the way, never backwards.
            let baseStability = previous?.stability ?? 0
            let baseDifficulty = previous?.difficulty ?? full.difficulty
            let stability = max(baseStability, baseStability + (full.stability - baseStability) * safeWeight)
            let difficulty = baseDifficulty + (full.difficulty - baseDifficulty) * safeWeight
            state = FSRS.validated(FSRS.MemoryState(stability: stability, difficulty: difficulty)) ?? full
            let previousInterval = min(maximumInterval, finiteNonNegative(score.interval))
            interval = max(
                previousInterval,
                FSRS.interval(stability: state.stability, retention: retention, maximum: maximumInterval)
            )
        }

        let wrong = correct ? max(0, score.wrong - (independent ? 1 : 0)) : score.wrong + 1
        let wasLearned = previous != nil && score.correct > 0
        return Score(
            value: Mastery.fromInterval(interval),
            interval: interval,
            due: now + interval * TimeConstants.dayMs,
            correct: score.correct + (correct ? 1 : 0),
            wrong: wrong,
            hinted: score.hinted + (hint ? 1 : 0),
            last: now,
            slow: score.slow + (slow ? 1 : 0),
            stability: state.stability,
            difficulty: state.difficulty,
            reps: (score.reps ?? legacyReps(score)) + 1,
            lapses: (score.lapses ?? legacyLapses(score)) + (!correct && wasLearned ? 1 : 0)
        )
    }

    /// FSRS state of a score: the stored one, or one derived from a legacy (web / pre-FSRS)
    /// score, or `nil` for a skill that was never answered.
    public static func memory(of score: Score) -> FSRS.MemoryState? {
        score.memoryState ?? legacyMemory(score)
    }

    /// Migration of a pre-FSRS score at its first FSRS answer:
    /// - stability = the old interval (the old scheduler aimed at reviewing just before forgetting,
    ///   which is what FSRS stability means at 90%), at least S0(Again), at most 90 days;
    /// - difficulty = D0(Good) + 1.2 per current error (max 6) + 0.4 per hinted/slow answer (max 5),
    ///   clamped to 1…10 — words with ≥ 3 errors („Trudne”) start around 5.7 or more.
    /// A score with no answer at all returns `nil` (treated as new).
    public static func legacyMemory(_ score: Score) -> FSRS.MemoryState? {
        guard score.last != 0 || score.correct > 0 || score.wrong > 0 || score.interval > 0 else { return nil }
        let interval = min(90, finiteNonNegative(score.interval))
        let stability = max(FSRS.initialStability(.again), interval)
        let errors = Double(min(6, max(0, score.wrong)))
        let assisted = Double(min(5, max(0, score.hinted) + max(0, score.slow)))
        let difficulty = FSRS.initialDifficulty(.good) + 1.2 * errors + 0.4 * assisted
        return FSRS.validated(FSRS.MemoryState(stability: stability, difficulty: difficulty))
    }

    static func legacyReps(_ score: Score) -> Int {
        max(0, score.correct) + max(0, score.wrong)
    }

    static func legacyLapses(_ score: Score) -> Int {
        max(0, score.wrong)
    }

    /// Polish error category stored in the review.
    static func errorLabel(correct: Bool, spellingCorrect: Bool, hint: Bool, seconds: Double, type: ExerciseType) -> String {
        if correct && !spellingCorrect { return "Pisownia" }
        if !correct {
            switch type {
            case .dictation: return "Słuchanie i pisownia"
            case .meaning: return "Znaczenie w kontekście"
            case .picture: return "Rozpoznawanie ze zdjęcia"
            case .scramble: return "Szyk zdania"
            case .matchPairs: return "Dopasowanie znaczenia"
            case .listeningChoice: return "Rozumienie ze słuchu"
            default: return "Przypominanie lub pisownia"
            }
        }
        if hint { return "Odpowiedź po podpowiedzi" }
        if seconds > type.slowSeconds { return "Wolne przypominanie" }
        return ""
    }

    /// `recordAnswer`: scores the answer, appends a review and advances the running vocabulary
    /// session (a failed task returns at the end in another format).
    ///
    /// Returns the state unchanged when the task's word or meaning no longer exists
    /// (the web app crashed in that case).
    public static func recordAnswer(
        _ state: LearnerState,
        task: VocabTask,
        correct: Bool,
        seconds: Double,
        confidence: Int,
        hint: Bool,
        spellingCorrect: Bool? = nil,
        weight: Double = 1,
        source: ReviewSource = .exercise,
        now: Timestamp,
        reviewID: String = UUID().uuidString.lowercased()
    ) -> LearnerState {
        guard let wordIndex = state.words.firstIndex(where: { $0.id == task.wordId }),
              let meaningIndex = state.words[wordIndex].meanings.firstIndex(where: { $0.id == task.meaningId })
        else {
            // The word was deleted while the session was paused: nothing to score, but the running
            // session must still move on (otherwise the screen is stuck on this task). No retry is
            // queued for a word that no longer exists.
            guard var session = state.session, let current = session.currentTask,
                  current.wordId == task.wordId, current.meaningId == task.meaningId else { return state }
            var next = state
            session.index += 1
            next.session = session
            return next
        }

        var next = state
        var word = next.words[wordIndex]
        var meaning = word.meanings[meaningIndex]
        let spelling = spellingCorrect ?? correct
        let safeSeconds = finiteNonNegative(seconds)
        let safeConfidence = min(3, max(1, confidence))

        if source == .exercise && task.example >= 0 && task.example < ExamplePool.availableCount(meaning) {
            meaning.usedExamples = ((meaning.usedExamples ?? []) + [task.example]).uniqued()
        }
        word.updatedAt = now
        let skill = task.type.skill
        let before = Mastery.of(meaning)
        let retention = state.settings.effectiveRetention
        let slow = safeSeconds > task.type.slowSeconds
        // An accepted typo („Uznaj moją odpowiedź”) is Hard for the tested skill; the spelling
        // skill itself fails, as before. Reading questions carry no real answer time or
        // confidence (fixed 15 s / 2), so a correct one is Good, never Hard — otherwise every
        // reading would raise the word's FSRS difficulty.
        let primaryRating: FSRS.Rating = source == .reading
            ? (correct ? (hint ? .hard : .good) : .again)
            : rating(
                correct: correct,
                hint: hint,
                typo: correct && !spelling,
                seconds: safeSeconds,
                confidence: safeConfidence,
                type: task.type
            )
        meaning.scores[skill] = review(
            meaning.scores[skill],
            rating: primaryRating,
            hint: hint,
            slow: slow,
            now: now,
            weight: weight,
            retention: retention
        )
        if task.type.scoresSpelling {
            meaning.scores[.spelling] = review(
                meaning.scores[.spelling],
                rating: rating(
                    correct: spelling,
                    hint: hint,
                    seconds: safeSeconds,
                    confidence: safeConfidence,
                    type: task.type
                ),
                hint: hint,
                slow: slow,
                now: now,
                weight: weight,
                retention: retention
            )
        }
        let after = Mastery.of(meaning)
        word.meanings[meaningIndex] = meaning
        next.words[wordIndex] = word

        next.reviews.append(Review(
            id: reviewID,
            wordId: word.id,
            meaningId: meaning.id,
            skill: skill,
            correct: correct,
            at: now,
            seconds: safeSeconds,
            confidence: safeConfidence,
            hint: hint,
            error: errorLabel(correct: correct, spellingCorrect: spelling, hint: hint, seconds: safeSeconds, type: task.type),
            before: before,
            after: after,
            masteryVersion: 2,
            weight: weight.isFinite ? min(1, max(0, weight)) : 1,
            source: source
        ))

        if var session = next.session {
            session.index += 1
            session.correct += (correct && !hint) ? 1 : 0
            if !correct && session.tasks.count < maxSessionTasks {
                let retryType: ExerciseType = session.mode == StudyMode.pairs.rawValue
                    ? .cloze
                    : SessionBuilder.retryType(after: task.type, meaning: meaning)
                session.tasks.append(VocabTask(
                    wordId: task.wordId,
                    meaningId: task.meaningId,
                    type: retryType,
                    example: ExamplePool.nextUnusedExample(meaning, fallback: task.example + 1)
                ))
            }
            next.session = session
        }
        return next
    }

    /// `applyReadingResults`: word-in-context reading questions update recognition with weight 0.35.
    /// The paused vocabulary session is left untouched.
    public static func applyReadingResults(
        _ state: LearnerState,
        reading: ReadingSession,
        now: Timestamp,
        makeID: () -> String = { UUID().uuidString.lowercased() }
    ) -> LearnerState {
        var next = state
        let activeSession = next.session
        next.session = nil
        for (index, question) in reading.reading.questions.enumerated() {
            guard let meaningID = question.meaningId,
                  let found = next.wordAndMeaning(meaningID: meaningID) else { continue }
            let isCorrect = reading.answers[safe: index] == question.answer
            next = recordAnswer(
                next,
                task: VocabTask(wordId: found.word.id, meaningId: found.meaning.id, type: .meaning, example: 0),
                correct: isCorrect,
                seconds: 15,
                confidence: 2,
                hint: false,
                spellingCorrect: isCorrect,
                weight: readingWeight,
                source: .reading,
                now: now,
                reviewID: makeID()
            )
        }
        next.session = activeSession
        return next
    }
}
