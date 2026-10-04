import Foundation

/// The spaced-repetition algorithm (learning.ts `schedule`, `recordAnswer`, `applyReadingResults`).
/// Pure functions: state in → new state out. Time and identifiers are injected.
public enum Scheduler {
    /// Weight of word-in-context answers from readings.
    public static let readingWeight = 0.35
    /// A failed task is re-queued only while the session has fewer tasks than this.
    public static let maxSessionTasks = 100

    /// `schedule`: next score of one skill after an answer.
    ///
    /// - independent correct answer: interval × factor (+ small bonus for real elapsed time), 1…90 days;
    /// - correct after a hint: 12 hours; wrong: 10 minutes;
    /// - `weight < 1` (readings) moves the interval only part of the way and never shortens it.
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
        let score = old ?? Score.empty
        let safeSeconds = finiteNonNegative(seconds)
        let slow = safeSeconds > type.slowSeconds
        let independent = correct && !hint
        let confidencePenalty: Double = confidence == 1 ? 0.65 : (confidence == 2 ? 0.25 : 0)
        let factor = max(
            1.15,
            2.5 - confidencePenalty - (slow ? 0.65 : 0) - min(0.45, Double(score.wrong) * 0.04)
        )
        var elapsed: Double = 0
        if score.last != 0, now.isFinite, score.last.isFinite {
            elapsed = max(0, (now - score.last) / TimeConstants.dayMs)
        }
        let previousInterval = finiteNonNegative(score.interval)
        var interval: Double
        if independent {
            let base = previousInterval == 0 ? 0.5 : previousInterval
            interval = min(90, max(1, base * factor + min(elapsed * 0.08, 2)))
        } else if correct {
            interval = 0.5
        } else {
            interval = 10.0 / 1440.0
        }
        let safeWeight = weight.isFinite ? min(1, max(0, weight)) : 1
        if safeWeight < 1 && correct {
            interval = max(previousInterval, previousInterval + (interval - previousInterval) * safeWeight)
        }
        let wrong = correct ? max(0, score.wrong - (independent ? 1 : 0)) : score.wrong + 1
        return Score(
            value: Mastery.fromInterval(interval),
            interval: interval,
            due: now + interval * TimeConstants.dayMs,
            correct: score.correct + (correct ? 1 : 0),
            wrong: wrong,
            hinted: score.hinted + (hint ? 1 : 0),
            last: now,
            slow: score.slow + (slow ? 1 : 0)
        )
    }

    /// Polish error category stored in the review.
    static func errorLabel(correct: Bool, spellingCorrect: Bool, hint: Bool, seconds: Double, type: ExerciseType) -> String {
        if correct && !spellingCorrect { return "Pisownia" }
        if !correct {
            switch type {
            case .dictation: return "Słuchanie i pisownia"
            case .meaning: return "Znaczenie w kontekście"
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
        else { return state }

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
        meaning.scores[skill] = schedule(
            meaning.scores[skill],
            correct: correct,
            seconds: safeSeconds,
            confidence: safeConfidence,
            hint: hint,
            now: now,
            type: task.type,
            weight: weight
        )
        if task.type.scoresSpelling {
            meaning.scores[.spelling] = schedule(
                meaning.scores[.spelling],
                correct: spelling,
                seconds: safeSeconds,
                confidence: safeConfidence,
                hint: hint,
                now: now,
                type: task.type,
                weight: weight
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
                let retryType: ExerciseType = session.mode == StudyMode.pairs.rawValue ? .cloze : task.type.retryType
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
