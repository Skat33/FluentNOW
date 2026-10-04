import Foundation

/// Combined multi-mode sessions (combined-session.ts, web v40).
public enum CombinedSessionBuilder {
    /// Number of tasks per 5 minutes.
    public static let tasksPerFiveMinutes = 8

    /// `orderCombinedTasks`: when `random`, interleaves modes so the same mode never follows itself
    /// while another is available; order inside a mode is kept. Otherwise returns tasks unchanged.
    public static func orderTasks<G: RandomNumberGenerator>(_ tasks: [CombinedTask], random: Bool, using rng: inout G) -> [CombinedTask] {
        guard random else { return tasks }
        var modes: [StudyMode] = []
        var buckets: [StudyMode: [CombinedTask]] = [:]
        for task in tasks {
            if buckets[task.mode] == nil { modes.append(task.mode) }
            buckets[task.mode, default: []].append(task)
        }
        var heads: [StudyMode: Int] = [:]
        var result: [CombinedTask] = []
        result.reserveCapacity(tasks.count)
        while !modes.isEmpty {
            let last = result.last?.mode
            let candidates = modes.filter { $0 != last }
            let choices = candidates.isEmpty ? modes : candidates
            let mode = choices[rng.nextIndex(below: choices.count)]
            let head = heads[mode] ?? 0
            if let bucket = buckets[mode], head < bucket.count {
                result.append(bucket[head])
                heads[mode] = head + 1
                if head + 1 >= bucket.count { modes.removeAll { $0 == mode } }
            } else {
                modes.removeAll { $0 == mode }
            }
        }
        return result
    }

    /// `makeCombinedSession`: `max(modes, round(minutes / 5) × 8)` tasks split evenly between the
    /// selected modes. Vocabulary modes use `makeSession`; the others use the offline banks at the
    /// learner's target level, without repeating grammar tasks already seen or reserved.
    public static func makeSession<G: RandomNumberGenerator>(
        state: LearnerState,
        modes: [StudyMode],
        minutes: Int,
        random: Bool,
        content: PracticeContent,
        now: Timestamp,
        id: String = UUID().uuidString.lowercased(),
        using rng: inout G
    ) -> CombinedSession {
        let selected = modes.uniqued()
        guard !selected.isEmpty else {
            return CombinedSession(id: id, modes: [], random: random, minutes: minutes, tasks: [], updatedAt: now)
        }
        let rounded = jsRoundInt(Double(minutes) / 5) * tasksPerFiveMinutes
        let total = max(selected.count, rounded)
        let level = LevelEstimator.estimatedLevel(state).targetLevel
        var tasks: [CombinedTask] = []
        var seen = GrammarSelector.selectionSeen(state, now: now)
        var readings = state.readingHistory
        for (modeIndex, mode) in selected.enumerated() {
            let count = total / selected.count + (modeIndex < total % selected.count ? 1 : 0)
            if mode.isVocabulary {
                let session = SessionBuilder.makeSession(state: state, minutes: minutes, mode: mode, using: &rng)
                for task in session.tasks.prefix(count) {
                    tasks.append(.vocabulary(mode: mode, task: task))
                }
                continue
            }
            var remaining = count
            var variant = state.practiceHistory.count + state.productionHistory.count
            while remaining > 0 {
                switch mode {
                case .reading:
                    guard let reading = ReadingSelector.selectBankReading(level: level, history: readings, bank: content.readings),
                          !reading.questions.isEmpty else {
                        remaining = 0
                        continue
                    }
                    readings.append(ReadingHistoryEntry(id: reading.id, at: now, level: level, correct: 0, total: reading.questions.count, title: reading.title))
                    for (index, question) in reading.questions.prefix(remaining).enumerated() {
                        let practice = PracticeQuestion(
                            category: .grammar,
                            prompt: question.question,
                            context: "",
                            options: question.options,
                            answer: question.answer,
                            explanation: question.explanation + " " + question.evidence,
                            translation: ""
                        )
                        tasks.append(.question(CombinedQuestionTask(mode: mode, question: practice, level: level, reading: reading, readingIndex: index)))
                    }
                    remaining -= min(remaining, reading.questions.count)
                case .production:
                    let set = PracticeBuilder.starterProduction(level: level, variant: variant, count: 6, seen: seen, content: content)
                    variant += 1
                    guard !set.items.isEmpty else {
                        remaining = 0
                        continue
                    }
                    for item in set.items.prefix(remaining) {
                        seen[GrammarSelector.taskID(item)] = now
                        let question = PracticeQuestion(
                            format: .input,
                            inputHint: item.rule,
                            acceptedAnswers: item.acceptedAnswers,
                            bankId: item.bankId,
                            scenarioId: item.scenarioId,
                            category: .grammar,
                            prompt: "Uzupełnij zdanie właściwą formą czasownika.",
                            context: item.context,
                            options: Array(([item.answer] + item.distractors.map { $0.form }).prefix(4)),
                            answer: 0,
                            explanation: item.explanation,
                            translation: item.translation
                        )
                        tasks.append(.question(CombinedQuestionTask(mode: mode, question: question, level: level, production: item)))
                    }
                    remaining -= min(remaining, set.items.count)
                default:
                    let kind: PracticeKind = mode == .languageMix ? .mixed : (mode == .idioms ? .idioms : .grammar)
                    let set = PracticeBuilder.starterPractice(kind: kind, level: level, variant: variant, seen: seen, content: content)
                    variant += 1
                    guard !set.items.isEmpty else {
                        remaining = 0
                        continue
                    }
                    for question in set.items.prefix(remaining) {
                        if let bankId = question.bankId, !bankId.isEmpty {
                            seen[GrammarSelector.taskID(question)] = now
                        }
                        tasks.append(.question(CombinedQuestionTask(mode: mode, question: question, level: level)))
                    }
                    remaining -= min(remaining, set.items.count)
                }
            }
        }
        let ordered = orderTasks(tasks, random: random, using: &rng)
        return CombinedSession(id: id, modes: selected, random: random, minutes: minutes, tasks: ordered, updatedAt: now)
    }

    /// `saveCombinedAnswer`: stores the answer of the current task once (a second call is ignored).
    /// Vocabulary answers are also scored with `recordAnswer` (confidence 2); the paused
    /// vocabulary session is not touched.
    public static func saveAnswer(_ state: LearnerState, answer: CombinedAnswer, now: Timestamp, reviewID: String = UUID().uuidString.lowercased()) -> LearnerState {
        guard var session = state.combined, session.completedAt == nil,
              session.index < session.tasks.count, session.index < session.answers.count,
              session.answers[session.index] == nil else { return state }
        var next = state
        if let task = session.tasks[session.index].vocabularyTask,
           state.word(id: task.wordId)?.meaning(id: task.meaningId) != nil {
            var scratch = state
            scratch.session = nil
            next = Scheduler.recordAnswer(
                scratch,
                task: task,
                correct: answer.correct,
                seconds: answer.seconds,
                confidence: 2,
                hint: answer.hinted,
                spellingCorrect: answer.spellingCorrect,
                now: now,
                reviewID: reviewID
            )
            next.session = state.session
        }
        session.answers[session.index] = answer
        session.updatedAt = now
        next.combined = session
        return next
    }

    /// `advanceCombined`: moves to the next task after the current one was answered. Finishing
    /// the session writes reading and practice history entries (one per reading / per mode).
    public static func advance(_ state: LearnerState, now: Timestamp) -> LearnerState {
        guard var session = state.combined, session.completedAt == nil,
              session.index < session.answers.count, session.answers[session.index] != nil else { return state }
        var next = state
        let index = session.index + 1
        session.index = index
        session.updatedAt = now
        if index < session.tasks.count {
            next.combined = session
            return next
        }
        session.completedAt = now
        next.combined = session
        for mode in session.modes {
            var items: [(task: CombinedQuestionTask, answer: CombinedAnswer?)] = []
            for (taskIndex, task) in session.tasks.enumerated() {
                if let question = task.questionTask, question.mode == mode {
                    items.append((question, session.answers[safe: taskIndex] ?? nil))
                }
            }
            guard let first = items.first else { continue }
            if mode == .reading {
                var readingIDs: [String] = []
                for item in items {
                    if let id = item.task.reading?.id, !readingIDs.contains(id) { readingIDs.append(id) }
                }
                for id in readingIDs {
                    let subset = items.filter { $0.task.reading?.id == id }
                    guard let reading = subset.first?.task.reading, let level = subset.first?.task.level else { continue }
                    next.readingHistory.append(ReadingHistoryEntry(
                        id: reading.id,
                        at: now,
                        level: level,
                        correct: subset.filter { $0.answer?.correct ?? false }.count,
                        total: subset.count,
                        title: reading.title
                    ))
                }
            } else {
                let kind: PracticeKind = mode == .idioms ? .idioms : (mode == .languageMix ? .mixed : .grammar)
                next.practiceHistory.append(PracticeHistoryEntry(
                    id: "\(session.id):\(mode.rawValue)",
                    at: now,
                    kind: kind,
                    level: first.task.level,
                    correct: items.filter { $0.answer?.correct ?? false }.count,
                    total: items.count,
                    title: "Sesja łączona · \(mode.namePl)"
                ))
            }
        }
        return next
    }
}
