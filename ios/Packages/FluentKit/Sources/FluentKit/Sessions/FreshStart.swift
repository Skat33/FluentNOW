import Foundation

/// „Zacznij od nowa” (FEEDBACK-6 K1): a new session in place of a paused one, with other
/// sentences / items than the paused one had. The paused session is simply replaced — answers
/// already given were saved when they were given (`Scheduler.recordAnswer`, history, grammar
/// exposure), so nothing is lost. Pure functions; the app writes the result in one update.
public enum FreshStart {
    // MARK: Sentences to avoid

    /// Example indexes per meaning used by the tasks of a vocabulary session (all of them —
    /// answered ones are also in `usedExamples`, pending ones would otherwise come back first).
    /// „Dopasuj pary” boards show no sentence and are skipped.
    public static func examples(in session: VocabSession?) -> [String: Set<Int>] {
        guard let session else { return [:] }
        var result: [String: Set<Int>] = [:]
        for task in session.tasks where !task.type.coversSeveralMeanings && task.example >= 0 {
            result[task.meaningId, default: []].insert(task.example)
        }
        return result
    }

    /// Example indexes per meaning shown on the cards of a flashcard deck.
    public static func examples(in cards: [FlashcardCard]) -> [String: Set<Int>] {
        var result: [String: Set<Int>] = [:]
        for card in cards where card.example >= 0 {
            result[card.meaningId, default: []].insert(card.example)
        }
        return result
    }

    /// The example a new task should use: the first published example that is neither used
    /// (`usedExamples`) nor in `avoid`; then the first one not in `avoid`, starting at `fallback`;
    /// when every example is avoided — the usual `ExamplePool.nextUnusedExample`. With an empty
    /// `avoid` exactly `ExamplePool.nextUnusedExample(meaning, fallback:)`.
    public static func preferredExample(_ meaning: Meaning, fallback: Int, avoiding avoid: Set<Int>) -> Int {
        let count = ExamplePool.availableCount(meaning)
        guard !avoid.isEmpty, count > 0 else {
            return ExamplePool.nextUnusedExample(meaning, fallback: fallback)
        }
        let used = Set(meaning.usedExamples ?? [])
        for index in 0..<count where !used.contains(index) && !avoid.contains(index) {
            return index
        }
        let start = ((fallback % count) + count) % count
        for step in 0..<count {
            let index = (start + step) % count
            if !avoid.contains(index) {
                return index
            }
        }
        return ExamplePool.nextUnusedExample(meaning, fallback: fallback)
    }

    // MARK: Vocabulary

    /// A new one-type session („Ćwicz wybrany typ”) avoiding the sentences of the paused
    /// `state.session`. Empty when no meaning can carry the type (as `SingleTypeSession`).
    public static func singleTypeSession(
        state: LearnerState,
        type: ExerciseType,
        minutes: Int,
        collection: String? = nil,
        now: Timestamp
    ) -> VocabSession {
        SingleTypeSession.makeSession(
            state: state,
            type: type,
            minutes: minutes,
            collection: collection,
            now: now,
            avoidingExamples: examples(in: state.session)
        )
    }

    // MARK: Grammar, idioms, production, reading

    /// A new grammar / idioms / mixed set instead of the paused one: every bank task of the
    /// paused set counts as just seen (unseen tasks first), the idiom rotation moves one step
    /// further, and the set gets its own id (history entries are keyed by set id). Returns the
    /// state unchanged when the bank has no tasks of this kind on `level`.
    public static func restartPractice(
        _ state: LearnerState,
        kind: PracticeKind,
        level: String,
        content: PracticeContent,
        now: Timestamp,
        id: String = UUID().uuidString.lowercased()
    ) -> LearnerState {
        var seen = GrammarSelector.selectionSeen(state, now: now)
        if let paused = state.practice {
            for item in paused.set.items where item.category == .grammar {
                let key = GrammarSelector.taskID(item)
                seen[key] = max(seen[key] ?? 0, now)
            }
        }
        let finished = state.practiceHistory.filter { (entry: PracticeHistoryEntry) -> Bool in entry.kind == kind }.count
        var set = PracticeBuilder.starterPractice(kind: kind, level: level, variant: finished + 1, seen: seen, content: content)
        guard !set.items.isEmpty else { return state }
        set.id = "\(set.id)-\(id)"
        var next = state
        next.practice = PracticeSession(set: set)
        return next
    }

    /// A new production set instead of the paused one (its tasks count as just seen).
    /// Returns the state unchanged when the bank has no production tasks on `level`.
    public static func restartProduction(
        _ state: LearnerState,
        level: String,
        content: PracticeContent,
        now: Timestamp,
        id: String = UUID().uuidString.lowercased()
    ) -> LearnerState {
        var seen = GrammarSelector.selectionSeen(state, now: now)
        if let paused = state.production {
            for item in paused.set.items {
                let key = GrammarSelector.taskID(item)
                seen[key] = max(seen[key] ?? 0, now)
            }
        }
        let set = PracticeBuilder.starterProduction(level: level, variant: state.productionHistory.count + 1, count: 6, seen: seen, content: content)
        guard !set.items.isEmpty else { return state }
        var next = state
        next.production = ProductionSession(id: id, set: set, source: .starter)
        return next
    }

    /// The next bank reading instead of the paused one: the paused text counts as the most
    /// recently read, so another passage of the level is chosen whenever one exists. The paused
    /// text is not written to the history (it was not finished). Returns the state unchanged when
    /// the bank is empty.
    public static func restartReading(_ state: LearnerState, bank: ReadingBank, now: Timestamp) -> LearnerState {
        let level = LevelEstimator.estimatedLevel(state).targetLevel
        var history = state.readingHistory
        if let paused = state.reading, !paused.submitted {
            history.append(ReadingHistoryEntry(
                id: paused.reading.id,
                at: max(now, (history.map { (entry: ReadingHistoryEntry) -> Timestamp in entry.at }.max() ?? 0) + 1),
                level: paused.reading.level,
                correct: 0,
                total: 0,
                title: paused.reading.title
            ))
        }
        guard let reading = ReadingSelector.selectBankReading(level: level, history: history, bank: bank) else {
            return state
        }
        var next = state
        next.reading = ReadingSession(reading: reading)
        return next
    }
}
