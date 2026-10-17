import Foundation

/// Why a card is in the deck (deck order: due → new → hard).
public enum FlashcardGroup: String, Codable, CaseIterable, Sendable, Hashable {
    case due
    case new
    case hard

    /// Polish label shown on the card and in the deck counter.
    public var namePl: String {
        switch self {
        case .due: return "Do powtórki"
        case .new: return "Nowe"
        case .hard: return "Trudne"
        }
    }
}

/// One flashcard of the separate „Fiszki” mode (G3).
public struct FlashcardCard: Codable, Sendable, Hashable, Identifiable {
    public var wordId: String
    public var meaningId: String
    /// Example sentence shown on the card (index into `meaning.examples`, may be out of range
    /// when the meaning has no examples — the screen then shows the word only).
    public var example: Int
    public var group: FlashcardGroup
    /// 0 for the first showing, 1 when a forgotten card returns at the end of the deck.
    public var attempt: Int

    public init(wordId: String, meaningId: String, example: Int, group: FlashcardGroup, attempt: Int = 0) {
        self.wordId = wordId
        self.meaningId = meaningId
        self.example = example
        self.group = group
        self.attempt = attempt
    }

    /// Unique within a run (a returning card is a new position in the deck).
    public var id: String { "\(meaningId)#\(attempt)" }

    /// The vocabulary task recorded for this card (flashcard → recognition).
    public var task: VocabTask {
        VocabTask(wordId: wordId, meaningId: meaningId, type: .flashcard, example: example)
    }
}

/// Number of cards available in each group (deck setup screen).
public struct FlashcardDeckCounts: Sendable, Hashable {
    public var due: Int
    public var new: Int
    public var hard: Int

    public init(due: Int = 0, new: Int = 0, hard: Int = 0) {
        self.due = due
        self.new = new
        self.hard = hard
    }

    public var total: Int { due + new + hard }
}

/// A running deck: position, answers and returning cards. Pure value — the screen keeps it in
/// memory; every answer is saved immediately with `FlashcardDeckBuilder.record`.
public struct FlashcardRun: Sendable, Hashable {
    public var cards: [FlashcardCard]
    public var index: Int
    public var remembered: Int
    public var forgotten: Int
    /// Meanings answered „Pamiętam” at least once / „Nie pamiętam” at least once in this run.
    public var rememberedMeaningIDs: [String]
    public var forgottenMeaningIDs: [String]

    public init(cards: [FlashcardCard]) {
        self.cards = cards
        self.index = 0
        self.remembered = 0
        self.forgotten = 0
        self.rememberedMeaningIDs = []
        self.forgottenMeaningIDs = []
    }

    public var currentCard: FlashcardCard? {
        cards[safe: index]
    }

    public var isFinished: Bool {
        index >= cards.count
    }

    /// Cards left including the current one.
    public var remaining: Int {
        max(0, cards.count - index)
    }

    /// Records the decision for the current card and moves on. A forgotten card returns once at
    /// the end of the deck (classic flashcard practice). Does nothing when the deck is finished.
    public mutating func answer(remembered isRemembered: Bool) {
        guard let card = currentCard else { return }
        if isRemembered {
            remembered += 1
            if !rememberedMeaningIDs.contains(card.meaningId) { rememberedMeaningIDs.append(card.meaningId) }
        } else {
            forgotten += 1
            if !forgottenMeaningIDs.contains(card.meaningId) { forgottenMeaningIDs.append(card.meaningId) }
            if card.attempt == 0 {
                var again = card
                again.attempt = 1
                cards.append(again)
            }
        }
        index += 1
    }

    /// Removes cards whose word / meaning no longer exists (deleted on another device).
    public mutating func dropMissing(in state: LearnerState) {
        guard index < cards.count else { return }
        let head = Array(cards[..<index])
        let tail = cards[index...].filter { card in state.word(id: card.wordId)?.meaning(id: card.meaningId) != nil }
        cards = head + tail
    }
}

/// Builds the flashcard deck (G3): cards due for review first (earliest due), then new meanings
/// (at most `newLimit`), then hard ones (most errors first); optionally one collection.
public enum FlashcardDeckBuilder {
    /// Default deck size.
    public static let defaultLimit = 30
    /// New cards per deck (more would not be remembered).
    public static let defaultNewLimit = 10
    /// Deck sizes offered on the setup card.
    public static let sizes = [10, 20, 30]

    /// Number of available cards per group (without limits).
    public static func counts(state: LearnerState, collection: String? = nil, now: Timestamp) -> FlashcardDeckCounts {
        let groups = grouped(state: state, collection: collection, now: now)
        return FlashcardDeckCounts(due: groups.due.count, new: groups.new.count, hard: groups.hard.count)
    }

    /// The deck: due → new → hard, at most `limit` cards (`newLimit` new ones).
    public static func makeDeck(
        state: LearnerState,
        collection: String? = nil,
        limit: Int = defaultLimit,
        newLimit: Int = defaultNewLimit,
        now: Timestamp
    ) -> [FlashcardCard] {
        let safeLimit = max(0, limit)
        guard safeLimit > 0 else { return [] }
        let groups = grouped(state: state, collection: collection, now: now)
        var seenCounts: [String: Int] = [:]
        for review in state.reviews {
            seenCounts[review.meaningId, default: 0] += 1
        }
        var cards: [FlashcardCard] = []
        func add(_ items: [WordMeaning], group: FlashcardGroup, max count: Int) {
            var added = 0
            for item in items where cards.count < safeLimit && added < count {
                let seen = seenCounts[item.meaning.id] ?? 0
                let example = ExamplePool.availableCount(item.meaning) > 0
                    ? ExamplePool.nextUnusedExample(item.meaning, fallback: seen)
                    : 0
                cards.append(FlashcardCard(wordId: item.word.id, meaningId: item.meaning.id, example: example, group: group))
                added += 1
            }
        }
        add(groups.due, group: .due, max: safeLimit)
        add(groups.new, group: .new, max: max(0, newLimit))
        add(groups.hard, group: .hard, max: safeLimit)
        return cards
    }

    /// Saves one flashcard answer (`Scheduler.recordAnswer`, skill recognition, confidence 2,
    /// as in combined sessions). A paused vocabulary session is left untouched.
    public static func record(
        _ state: LearnerState,
        card: FlashcardCard,
        remembered: Bool,
        seconds: Double,
        now: Timestamp,
        reviewID: String = UUID().uuidString.lowercased()
    ) -> LearnerState {
        guard state.word(id: card.wordId)?.meaning(id: card.meaningId) != nil else { return state }
        var scratch = state
        scratch.session = nil
        var next = Scheduler.recordAnswer(
            scratch,
            task: card.task,
            correct: remembered,
            seconds: seconds,
            confidence: 2,
            hint: false,
            spellingCorrect: remembered,
            now: now,
            reviewID: reviewID
        )
        next.session = state.session
        return next
    }

    // MARK: Internal

    static func grouped(state: LearnerState, collection: String?, now: Timestamp) -> (due: [WordMeaning], new: [WordMeaning], hard: [WordMeaning]) {
        var due: [(item: WordMeaning, due: Timestamp)] = []
        var fresh: [WordMeaning] = []
        var hard: [(item: WordMeaning, errors: Int)] = []
        for word in state.words where !word.archived && (collection == nil || word.collection == collection) {
            for meaning in word.meanings {
                let item = WordMeaning(word: word, meaning: meaning)
                if Mastery.isNew(meaning) {
                    fresh.append(item)
                    continue
                }
                let dueAt = Mastery.due(meaning)
                if dueAt <= now {
                    due.append((item: item, due: dueAt))
                    continue
                }
                let errors = meaning.scores.values.reduce(0) { $0 + $1.wrong + $1.slow }
                if word.hard || errors > 0 {
                    hard.append((item: item, errors: errors))
                }
            }
        }
        let dueSorted = due.stableSorted { $0.due < $1.due }.map { $0.item }
        let hardSorted = hard.stableSorted { $0.errors > $1.errors }.map { $0.item }
        return (due: dueSorted, new: fresh, hard: hardSorted)
    }
}
