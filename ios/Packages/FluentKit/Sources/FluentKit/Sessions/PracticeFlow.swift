import Foundation

/// State transitions of the single-mode practice screens (grammar / idioms / mixed sets,
/// grammar production and readings), ported from the web UI handlers so every screen
/// writes identical history entries.
public enum PracticeFlow {
    // MARK: Grammar / idioms / mixed

    /// Starts a new offline practice set (variant = number of finished sets of this kind).
    public static func startPractice(_ state: LearnerState, kind: PracticeKind, level: String, content: PracticeContent, now: Timestamp) -> LearnerState {
        let variant = state.practiceHistory.filter { $0.kind == kind }.count
        let seen = GrammarSelector.selectionSeen(state, now: now)
        let set = PracticeBuilder.starterPractice(kind: kind, level: level, variant: variant, seen: seen, content: content)
        var next = state
        next.practice = PracticeSession(set: set)
        return next
    }

    /// Records a multiple-choice answer for the current item (ignored when already answered).
    public static func answerPractice(_ state: LearnerState, choice: Int) -> LearnerState {
        guard var practice = state.practice, practice.completedAt == nil else { return state }
        let index = practice.index
        guard index < practice.set.items.count else { return state }
        while practice.answers.count < practice.set.items.count { practice.answers.append(-1) }
        guard practice.answers[index] < 0 else { return state }
        practice.answers[index] = choice
        var next = state
        next.practice = practice
        return next
    }

    /// Checks and records a typed answer; returns the new state and whether it was correct.
    public static func answerPracticeWritten(_ state: LearnerState, text: String, variants: AnswerVariants = .builtIn) -> (state: LearnerState, correct: Bool) {
        guard var practice = state.practice, practice.completedAt == nil,
              let item = practice.set.items[safe: practice.index] else { return (state, false) }
        let result = ProductionGrader.checkPracticeInput(item, value: text, variants: variants)
        var written = practice.writtenAnswers ?? Array(repeating: "", count: practice.set.items.count)
        while written.count < practice.set.items.count { written.append("") }
        written[practice.index] = text
        practice.writtenAnswers = written
        var next = state
        next.practice = practice
        next = answerPractice(next, choice: result.choice)
        return (next, result.correct)
    }

    /// Moves to the next item; after the last one marks the set completed and appends history.
    /// Ignored while the current item has no answer (a double tap on „Dalej” must not skip a question).
    public static func advancePractice(_ state: LearnerState, now: Timestamp) -> LearnerState {
        guard var practice = state.practice, practice.completedAt == nil,
              (practice.answers[safe: practice.index] ?? -1) >= 0 else { return state }
        var next = state
        if practice.index + 1 < practice.set.items.count {
            practice.index += 1
            next.practice = practice
            return next
        }
        practice.completedAt = now
        next.practice = practice
        let correct = practice.set.items.enumerated().filter { practice.answers[safe: $0.offset] == $0.element.answer }.count
        next.practiceHistory.removeAll { $0.id == practice.set.id }
        next.practiceHistory.append(PracticeHistoryEntry(
            id: practice.set.id,
            at: now,
            kind: practice.set.kind,
            level: practice.set.level,
            correct: correct,
            total: max(1, practice.set.items.count),
            title: practice.set.title
        ))
        return next
    }

    // MARK: Production

    /// Starts a production set of 6 tasks.
    public static func startProduction(_ state: LearnerState, level: String, content: PracticeContent, now: Timestamp, id: String = UUID().uuidString.lowercased()) -> LearnerState {
        let seen = GrammarSelector.selectionSeen(state, now: now)
        let set = PracticeBuilder.starterProduction(level: level, variant: state.productionHistory.count, count: 6, seen: seen, content: content)
        var next = state
        next.production = ProductionSession(id: id, set: set, source: .starter)
        return next
    }

    /// Grades and stores the answer of the current production task (once).
    public static func answerProduction(_ state: LearnerState, text: String) -> LearnerState {
        guard var production = state.production, production.completedAt == nil,
              let item = production.set.items[safe: production.index] else { return state }
        while production.answers.count < production.set.items.count { production.answers.append("") }
        while production.results.count < production.set.items.count { production.results.append(nil) }
        guard production.results[production.index] == nil else { return state }
        production.answers[production.index] = text
        production.results[production.index] = ProductionGrader.grade(text, item: item)
        var next = state
        next.production = production
        return next
    }

    /// Next production task; after the last one completes the set and writes history.
    /// Ignored while the current task has no graded answer (double tap protection).
    public static func advanceProduction(_ state: LearnerState, now: Timestamp) -> LearnerState {
        guard var production = state.production, production.completedAt == nil,
              (production.results[safe: production.index] ?? nil) != nil else { return state }
        var next = state
        if production.index + 1 < production.set.items.count {
            production.index += 1
            next.production = production
            return next
        }
        production.completedAt = now
        next.production = production
        let correct = production.results.filter { $0?.correct ?? false }.count
        next.productionHistory.removeAll { $0.id == production.id }
        next.productionHistory.append(ProductionHistoryEntry(
            id: production.id,
            at: now,
            level: production.set.level,
            correct: correct,
            total: production.set.items.count,
            title: production.set.title
        ))
        return next
    }

    // MARK: Reading

    /// Starts the next bank reading at the learner's target level (optionally topical).
    public static func startReading(_ state: LearnerState, topic: String = "", bank: ReadingBank) -> LearnerState {
        let level = LevelEstimator.estimatedLevel(state).targetLevel
        guard let reading = ReadingSelector.selectBankReading(level: level, history: state.readingHistory, topic: topic, bank: bank) else {
            return state
        }
        var next = state
        next.reading = ReadingSession(reading: reading)
        return next
    }

    /// Submits the reading: word-in-context questions update recognition (weight 0.35) and a
    /// history entry is written. Ignored if already submitted.
    public static func submitReading(_ state: LearnerState, now: Timestamp, makeID: () -> String = { UUID().uuidString.lowercased() }) -> LearnerState {
        guard var reading = state.reading, !reading.submitted else { return state }
        reading.submitted = true
        reading.completedAt = now
        var next = Scheduler.applyReadingResults(state, reading: reading, now: now, makeID: makeID)
        next.reading = reading
        next.readingHistory.append(ReadingHistoryEntry(
            id: reading.reading.id,
            at: now,
            level: reading.reading.level,
            correct: reading.correctCount,
            total: reading.reading.questions.count,
            title: reading.reading.title
        ))
        return next
    }
}
