import Foundation

/// Combined multi-mode sessions (combined-session.ts, web v40).
public enum CombinedSessionBuilder {
    /// Number of tasks per 5 minutes.
    public static let tasksPerFiveMinutes = 8
    /// A reading in a session always brings at least this many questions (all of them when the
    /// passage has fewer) …
    public static let minReadingQuestions = 3
    /// … and at most this many.
    public static let maxReadingQuestions = 6

    /// `orderCombinedTasks`: when `random`, interleaves modes so the same mode never follows itself
    /// while another is available; order inside a mode is kept. Otherwise returns tasks unchanged.
    /// The questions of one reading are a block: they always stay together, in order
    /// (deviation from the web, which could split a passage between other tasks).
    public static func orderTasks<G: RandomNumberGenerator>(_ tasks: [CombinedTask], random: Bool, using rng: inout G) -> [CombinedTask] {
        guard random else { return tasks }
        var modes: [StudyMode] = []
        var buckets: [StudyMode: [[CombinedTask]]] = [:]
        for block in taskBlocks(tasks) {
            guard let mode = block.first?.mode else { continue }
            if buckets[mode] == nil { modes.append(mode) }
            buckets[mode, default: []].append(block)
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
                result.append(contentsOf: bucket[head])
                heads[mode] = head + 1
                if head + 1 >= bucket.count { modes.removeAll { $0 == mode } }
            } else {
                modes.removeAll { $0 == mode }
            }
        }
        return result
    }

    /// Splits tasks into blocks: consecutive questions of the same reading form one block,
    /// every other task is a block of its own.
    static func taskBlocks(_ tasks: [CombinedTask]) -> [[CombinedTask]] {
        var blocks: [[CombinedTask]] = []
        for task in tasks {
            if let id = readingID(task), let lastBlock = blocks.last, let lastTask = lastBlock.last,
               readingID(lastTask) == id {
                blocks[blocks.count - 1].append(task)
            } else {
                blocks.append([task])
            }
        }
        return blocks
    }

    static func readingID(_ task: CombinedTask) -> String? {
        task.questionTask?.reading?.id
    }

    /// Reading blocks for a budget of `budget` tasks: the first passage always comes whole
    /// (3–6 questions, never cut to the budget); another passage is added only while at least
    /// `minReadingQuestions` tasks of the budget are left. The same passage is never used twice.
    static func readingTasks(budget: Int, level: String, history: [ReadingHistoryEntry], bank: ReadingBank, now: Timestamp) -> [CombinedTask] {
        guard budget > 0 else { return [] }
        var tasks: [CombinedTask] = []
        var readHistory = history
        var used = Set<String>()
        var remaining = budget
        while remaining > 0 {
            if !tasks.isEmpty && remaining < minReadingQuestions { break }
            guard let reading = ReadingSelector.selectBankReading(level: level, history: readHistory, bank: bank),
                  !reading.questions.isEmpty, !used.contains(reading.id) else { break }
            used.insert(reading.id)
            readHistory.append(ReadingHistoryEntry(id: reading.id, at: now, level: level, correct: 0, total: reading.questions.count, title: reading.title))
            let questions = Array(reading.questions.prefix(maxReadingQuestions))
            for (index, question) in questions.enumerated() {
                let practice = PracticeQuestion(
                    category: .grammar,
                    prompt: question.question,
                    context: "",
                    options: question.options,
                    answer: question.answer,
                    explanation: question.explanation + " " + question.evidence,
                    translation: ""
                )
                tasks.append(.question(CombinedQuestionTask(mode: .reading, question: practice, level: level, reading: reading, readingIndex: index)))
            }
            remaining -= questions.count
        }
        return tasks
    }

    /// Moves `delta` tasks of budget from (delta > 0) or to (delta < 0) the modes other than
    /// `fixed`: taking from the largest budget first (never below 1), giving round-robin.
    static func rebalance(_ counts: inout [Int], fixed: Int, delta: Int) {
        let others = counts.indices.filter { $0 != fixed }
        guard !others.isEmpty, delta != 0 else { return }
        if delta > 0 {
            var left = delta
            while left > 0 {
                var best: Int?
                for index in others where counts[index] > 1 {
                    if let current = best, counts[current] >= counts[index] { continue }
                    best = index
                }
                guard let chosen = best else { break }
                counts[chosen] -= 1
                left -= 1
            }
        } else {
            for step in 0..<(-delta) {
                counts[others[step % others.count]] += 1
            }
        }
    }

    /// `makeCombinedSession`: `max(modes, round(minutes / 5) × 8)` tasks split evenly between the
    /// selected modes. Vocabulary modes use `makeSession`; the others use the offline banks at the
    /// learner's target level, without repeating grammar tasks already seen or reserved.
    /// Readings come as whole blocks (see `readingTasks`); the difference between the reading
    /// block and its share of the budget is taken from / given to the other modes, so the session
    /// keeps its length.
    public static func makeSession<G: RandomNumberGenerator>(
        state: LearnerState,
        modes: [StudyMode],
        minutes: Int,
        random: Bool,
        content: PracticeContent,
        now: Timestamp,
        id: String = UUID().uuidString.lowercased(),
        pictureMeaningIDs: Set<String> = [],
        using rng: inout G
    ) -> CombinedSession {
        // The flashcard deck has its own screen and never joins a combined session (G3).
        let selected = modes.uniqued().filter { (mode: StudyMode) -> Bool in mode.isCombinable }
        guard !selected.isEmpty else {
            return CombinedSession(id: id, modes: [], random: random, minutes: minutes, tasks: [], updatedAt: now)
        }
        let rounded = jsRoundInt(Double(minutes) / 5) * tasksPerFiveMinutes
        let total = max(selected.count, rounded)
        let level = LevelEstimator.estimatedLevel(state).targetLevel
        var tasks: [CombinedTask] = []
        var seen = GrammarSelector.selectionSeen(state, now: now)
        var counts = selected.indices.map { (modeIndex: Int) -> Int in
            total / selected.count + (modeIndex < total % selected.count ? 1 : 0)
        }
        var readingBlock: [CombinedTask] = []
        if let readingIndex = selected.firstIndex(of: .reading) {
            readingBlock = readingTasks(budget: counts[readingIndex], level: level, history: state.readingHistory, bank: content.readings, now: now)
            // Bez czytanki (pusty bank) budżet trybu przepada jak w pozostałych trybach.
            if !readingBlock.isEmpty {
                rebalance(&counts, fixed: readingIndex, delta: readingBlock.count - counts[readingIndex])
                counts[readingIndex] = readingBlock.count
            }
        }
        for (modeIndex, mode) in selected.enumerated() {
            let count = counts[modeIndex]
            if mode == .reading {
                tasks.append(contentsOf: readingBlock)
                continue
            }
            if mode.isVocabulary {
                let session = SessionBuilder.makeSession(state: state, minutes: minutes, mode: mode, pictureMeaningIDs: pictureMeaningIDs, using: &rng)
                for task in session.tasks.prefix(count) {
                    tasks.append(.vocabulary(mode: mode, task: task))
                }
                continue
            }
            var remaining = count
            var variant = state.practiceHistory.count + state.productionHistory.count
            while remaining > 0 {
                switch mode {
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
    /// vocabulary session is not touched. A „Dopasuj pary” board passes `matchResults` — every
    /// meaning of the board is then scored (`MatchPairsExercise.record`, review IDs `reviewID`,
    /// `reviewID-2`…); `answer.correct` is the whole board.
    public static func saveAnswer(
        _ state: LearnerState,
        answer: CombinedAnswer,
        now: Timestamp,
        reviewID: String = UUID().uuidString.lowercased(),
        matchResults: [MatchPairResult] = []
    ) -> LearnerState {
        guard var session = state.combined, session.completedAt == nil,
              session.index < session.tasks.count, session.index < session.answers.count,
              session.answers[session.index] == nil else { return state }
        var next = state
        if let task = session.tasks[session.index].vocabularyTask, task.type == .matchPairs, !matchResults.isEmpty {
            next = MatchPairsExercise.record(
                state,
                task: task,
                results: matchResults,
                seconds: answer.seconds,
                confidence: 2,
                now: now,
                reviewID: reviewID,
                advancesSession: false
            )
        } else if let task = session.tasks[session.index].vocabularyTask,
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
