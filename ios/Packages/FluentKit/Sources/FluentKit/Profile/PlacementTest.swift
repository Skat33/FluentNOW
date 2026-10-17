import Foundation

/// One question of the quick placement test.
public struct PlacementQuestion: Sendable, Hashable, Identifiable {
    public enum Kind: String, Sendable, Hashable {
        /// „Co znaczy …?” — recognise an English word (Polish options).
        case vocabulary
        /// Choose the correct form for the gap (grammar bank).
        case grammar
    }

    public var id: String
    public var kind: Kind
    /// CEFR level of the item.
    public var level: String
    /// English word (vocabulary) or the sentence with a gap (grammar).
    public var prompt: String
    /// Polish hint under the prompt (grammar: the verb / translation), may be empty.
    public var hint: String
    public var options: [String]
    /// Index of the correct option.
    public var answer: Int

    public init(id: String, kind: Kind, level: String, prompt: String, hint: String = "", options: [String], answer: Int) {
        self.id = id
        self.kind = kind
        self.level = level
        self.prompt = prompt
        self.hint = hint
        self.options = options
        self.answer = answer
    }
}

/// Result of the placement test.
public struct PlacementResult: Sendable, Hashable {
    public var level: String
    public var correct: Int
    public var total: Int
    /// Level → (correct, asked).
    public var byLevel: [String: PlacementLevelScore]

    public init(level: String, correct: Int, total: Int, byLevel: [String: PlacementLevelScore]) {
        self.level = level
        self.correct = correct
        self.total = total
        self.byLevel = byLevel
    }

    /// „Wynik: 8 z 12 — proponujemy poziom B1.”
    public var summaryPl: String {
        "Wynik: \(correct) z \(total) — proponujemy poziom \(level)."
    }
}

public struct PlacementLevelScore: Sendable, Hashable {
    public var correct: Int
    public var asked: Int

    public init(correct: Int, asked: Int) {
        self.correct = correct
        self.asked = asked
    }
}

/// Quick placement test from built-in content (G4): recognition of words of different levels
/// from `dictionary-index.json` plus a few gap sentences from `grammar/<level>.json`. Every
/// question has the option „Nie wiem” (last), so guessing is not encouraged.
public enum PlacementTest {
    /// Levels of the vocabulary questions (9 questions, more weight in the middle).
    public static let vocabularyLevels = ["A1", "A2", "A2", "B1", "B1", "B2", "B2", "C1", "C2"]
    /// Levels of the grammar questions.
    public static let grammarLevels = ["A2", "B1", "B2"]
    public static let dontKnow = "Nie wiem"

    /// Builds 9 vocabulary + up to 3 grammar questions, deterministic for a seed.
    /// - Parameters:
    ///   - dictionary: entries of `dictionary-index.json`.
    ///   - grammar: level → items of `grammar/<level>.json` (missing levels are skipped).
    public static func makeQuestions(dictionary: [DictionaryIndex.Entry], grammar: [String: [ProductionItem]], seed: UInt64) -> [PlacementQuestion] {
        var rng = SeededGenerator(seed: seed)
        var questions: [PlacementQuestion] = []
        var usedKeys = Set<String>()
        var pools: [String: [DictionaryIndex.Entry]] = [:]
        for level in Set(vocabularyLevels) {
            pools[level] = vocabularyPool(dictionary, level: level)
        }
        for (index, level) in vocabularyLevels.enumerated() {
            guard let pool = pools[level], !pool.isEmpty else { continue }
            if let question = vocabularyQuestion(pool: pool, level: level, number: index, used: &usedKeys, using: &rng) {
                questions.append(question)
            }
        }
        var grammarQuestions: [PlacementQuestion] = []
        for (index, level) in grammarLevels.enumerated() {
            let items = (grammar[level] ?? []).filter { (item: ProductionItem) -> Bool in isUsableGrammarItem(item) }
            guard !items.isEmpty else { continue }
            let item = items[Int(rng.next() % UInt64(items.count))]
            grammarQuestions.append(grammarQuestion(item, level: level, number: index, using: &rng))
        }
        // Grammar questions are spread through the test (after questions 3, 6 and 9).
        var result: [PlacementQuestion] = []
        for (index, question) in questions.enumerated() {
            result.append(question)
            let slot = (index + 1) / 3 - 1
            if (index + 1) % 3 == 0, slot >= 0, slot < grammarQuestions.count {
                result.append(grammarQuestions[slot])
            }
        }
        let placed = result.filter { $0.kind == .grammar }.count
        if placed < grammarQuestions.count {
            result.append(contentsOf: grammarQuestions.suffix(grammarQuestions.count - placed))
        }
        return result
    }

    /// Frequent, single-word entries of a level with a short translation (fall back to any frequency).
    static func vocabularyPool(_ entries: [DictionaryIndex.Entry], level: String) -> [DictionaryIndex.Entry] {
        let usable = entries.filter { (entry: DictionaryIndex.Entry) -> Bool in
            entry.level == level
                && !entry.term.contains(" ")
                && entry.term.count >= 3
                && entry.term.allSatisfy { $0.isLetter || $0 == "-" }
                && !TextScanning.trim(entry.translation).isEmpty
                && entry.translation.count <= 32
                && !entry.translation.contains("(")
        }
        let frequent = usable.filter { (entry: DictionaryIndex.Entry) -> Bool in
            guard let frequency = entry.spokenFrequency else { return false }
            return frequency == .veryCommon || frequency == .common
        }
        let pool = frequent.count >= 8 ? frequent : usable
        // Stable order independent of the file order (sorting by reference).
        return pool.sorted { (lhs: DictionaryIndex.Entry, rhs: DictionaryIndex.Entry) -> Bool in
            lhs.reference < rhs.reference
        }
    }

    private static func vocabularyQuestion<G: RandomNumberGenerator>(pool: [DictionaryIndex.Entry], level: String, number: Int, used: inout Set<String>, using rng: inout G) -> PlacementQuestion? {
        for _ in 0..<20 {
            let entry = pool[Int(rng.next() % UInt64(pool.count))]
            let key = entry.key.isEmpty ? TextNormalizer.searchKey(entry.term) : entry.key
            guard !used.contains(key) else { continue }
            let distractors = pickDistractors(for: entry, pool: pool, count: 3, using: &rng)
            guard distractors.count == 3 else { continue }
            used.insert(key)
            var options = distractors + [entry.translation]
            shuffle(&options, using: &rng)
            let answer = options.firstIndex(of: entry.translation) ?? 0
            return PlacementQuestion(
                id: "vocabulary-\(number)",
                kind: .vocabulary,
                level: level,
                prompt: entry.term,
                options: options + [dontKnow],
                answer: answer
            )
        }
        return nil
    }

    /// Translations of other entries of the level that differ clearly from the correct one.
    static func pickDistractors<G: RandomNumberGenerator>(for entry: DictionaryIndex.Entry, pool: [DictionaryIndex.Entry], count: Int, using rng: inout G) -> [String] {
        let correctKey = TextNormalizer.searchKey(entry.translation)
        let correctFirst = correctKey.split(separator: " ").first.map(String.init) ?? correctKey
        var keys: Set<String> = [correctKey]
        var result: [String] = []
        var attempts = 0
        while result.count < count && attempts < 60 {
            attempts += 1
            let candidate = pool[Int(rng.next() % UInt64(pool.count))]
            let key = TextNormalizer.searchKey(candidate.translation)
            let first = key.split(separator: " ").first.map(String.init) ?? key
            guard !key.isEmpty, !keys.contains(key), first != correctFirst,
                  candidate.term.lowercased() != entry.term.lowercased() else { continue }
            keys.insert(key)
            result.append(candidate.translation)
        }
        return result
    }

    static func isUsableGrammarItem(_ item: ProductionItem) -> Bool {
        item.context.contains("___") && !item.answer.isEmpty && item.distractors.count >= 2
    }

    private static func grammarQuestion<G: RandomNumberGenerator>(_ item: ProductionItem, level: String, number: Int, using rng: inout G) -> PlacementQuestion {
        var forms: [String] = [item.answer]
        for distractor in item.distractors where !forms.contains(distractor.form) && forms.count < 4 {
            forms.append(distractor.form)
        }
        shuffle(&forms, using: &rng)
        let answer = forms.firstIndex(of: item.answer) ?? 0
        return PlacementQuestion(
            id: "grammar-\(number)",
            kind: .grammar,
            level: level,
            prompt: item.context,
            hint: item.translation,
            options: forms + [dontKnow],
            answer: answer
        )
    }

    private static func shuffle<T, G: RandomNumberGenerator>(_ values: inout [T], using rng: inout G) {
        guard values.count > 1 else { return }
        for index in stride(from: values.count - 1, to: 0, by: -1) {
            let other = Int(rng.next() % UInt64(index + 1))
            values.swapAt(index, other)
        }
    }

    // MARK: Scoring

    /// Start level: going up from A1, each level is reached when at least half of its questions
    /// and at least 60% of all questions up to it are correct; the first failed level (other than
    /// A1 — one slip on the easiest word does not cap the result) stops the climb, so a lucky guess
    /// at C2 does not count. Unanswered or „Nie wiem” = wrong. Nothing reached → A1.
    public static func result(questions: [PlacementQuestion], answers: [Int?]) -> PlacementResult {
        var byLevel: [String: PlacementLevelScore] = [:]
        var correct = 0
        for (index, question) in questions.enumerated() {
            let chosen = answers[safe: index] ?? nil
            let isCorrect = chosen == question.answer
            var score = byLevel[question.level] ?? PlacementLevelScore(correct: 0, asked: 0)
            score.asked += 1
            if isCorrect {
                score.correct += 1
                correct += 1
            }
            byLevel[question.level] = score
        }
        var level = "A1"
        var cumulativeCorrect = 0
        var cumulativeAsked = 0
        for candidate in CEFR.levels {
            guard let score = byLevel[candidate], score.asked > 0 else { continue }
            cumulativeCorrect += score.correct
            cumulativeAsked += score.asked
            let levelShare = Double(score.correct) / Double(score.asked)
            let cumulativeShare = Double(cumulativeCorrect) / Double(cumulativeAsked)
            if levelShare >= 0.5 && cumulativeShare >= 0.6 {
                level = candidate
            } else if candidate != "A1" {
                break
            }
        }
        return PlacementResult(level: level, correct: correct, total: questions.count, byLevel: byLevel)
    }
}
