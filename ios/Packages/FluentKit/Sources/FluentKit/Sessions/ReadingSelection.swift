import Foundation

/// A meaning suggested for a personalised reading (tutor-local.ts `selectReadingMeanings`).
public struct ReadingMeaningCandidate: Sendable, Hashable {
    public var en: String
    public var meaningId: String
    public var translation: String
    public var level: String
    public var topic: String?
    public var scene: String?

    public init(en: String, meaningId: String, translation: String, level: String, topic: String? = nil, scene: String? = nil) {
        self.en = en
        self.meaningId = meaningId
        self.translation = translation
        self.level = level
        self.topic = topic
        self.scene = scene
    }
}

/// Reading selection (reading-bank.ts `selectBankReading`, tutor-local.ts `selectReadingMeanings`).
public enum ReadingSelector {
    private static let topicStems = ["restauracj", "lotnisk", "podroz", "lekar", "prac"]

    static func topicKeywords(_ topic: String) -> [String] {
        let folded = TextScanning.foldPolish(topic)
        let words = folded.split(whereSeparator: { !($0.isASCII && $0.isLetter) }).map(String.init)
        return words.filter { $0.count > 3 }.map { word in
            topicStems.first { word.hasPrefix($0) } ?? word
        }
    }

    /// `selectBankReading`: an unread passage of the level (topic keywords preferred); after the
    /// level is exhausted, the least recently read one. Answer positions rotate by
    /// `history.count % 4`, so a revisited passage has different answer letters.
    /// Returns `nil` only when the bank is empty.
    public static func selectBankReading(level: String, history: [ReadingHistoryEntry] = [], topic: String = "", bank: ReadingBank) -> Reading? {
        var pool = bank.readings.filter { $0.level == level }
        if pool.isEmpty { pool = bank.readings.filter { $0.level == "A2" } }
        if pool.isEmpty { pool = bank.readings }
        guard !pool.isEmpty else { return nil }
        var used: [String: Double] = [:]
        for (index, entry) in history.enumerated() {
            used[entry.id] = entry.at != 0 ? entry.at : Double(index + 1)
        }
        let titlesUsed = Set(history.compactMap { $0.title }.filter { !$0.isEmpty })
        let keywords = topicKeywords(topic)
        func usage(_ reading: Reading) -> Double {
            if let value = used[reading.id], value != 0 { return value }
            return titlesUsed.contains(reading.title) ? 1 : 0
        }
        func topicScore(_ reading: Reading) -> Int {
            let text = TextScanning.foldPolish(reading.topic ?? "")
            return keywords.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
        }
        let ordered = pool.stableSorted { a, b in
            let ua = usage(a)
            let ub = usage(b)
            let usedA = ua != 0
            let usedB = ub != 0
            if usedA != usedB { return !usedA }
            if usedA && usedB { return ua < ub }
            return topicScore(a) > topicScore(b)
        }
        guard var selected = ordered.first else { return nil }
        let offset = history.count % 4
        selected.questions = selected.questions.map { (question: ReadingQuestion) -> ReadingQuestion in
            var copy = question
            let n = copy.options.count
            guard n > 0 else { return copy }
            let shift = offset % n
            copy.options = Array(copy.options[shift...]) + Array(copy.options[..<shift])
            copy.answer = PracticeBuilder.mod(copy.answer - shift, n)
            return copy
        }
        selected.topic = nil
        selected.source = .starter
        return selected
    }

    /// `selectReadingMeanings`: due and difficult meanings close to the target level first.
    public static func selectReadingMeanings(_ state: LearnerState, targetLevel: String, limit: Int = 20, now: Timestamp) -> [ReadingMeaningCandidate] {
        let target = max(0, CEFR.jsIndex(of: targetLevel))
        var scored: [(candidate: ReadingMeaningCandidate, priority: Int)] = []
        for word in state.words where !word.archived {
            for meaning in word.meanings where ExamplePool.availableCount(meaning) > 0 {
                let level = meaning.effectiveLevel(in: word)
                guard let levelIndex = CEFR.index(of: level) else { continue }
                var priority = 0
                if Mastery.due(meaning) <= now { priority -= 1000 }
                if word.hard { priority -= 500 }
                priority += Mastery.of(meaning) * 4
                priority += abs(levelIndex - target) * 60
                scored.append((ReadingMeaningCandidate(en: word.en, meaningId: meaning.id, translation: meaning.translation, level: level, topic: meaning.topic, scene: meaning.scene), priority))
            }
        }
        return scored.stableSorted { $0.priority < $1.priority }.prefix(max(0, limit)).map { $0.candidate }
    }
}

/// Estimated CEFR level of the learner.
public struct LevelEstimate: Sendable, Hashable {
    public var level: String
    /// One level above `level` (C2 max) — used for readings and practice.
    public var targetLevel: String
    /// Number of meanings in the sample.
    public var count: Int
    /// `.high` when based on meanings with mastery ≥ 40, otherwise `.low`.
    public var confidence: LevelConfidence

    public init(level: String, targetLevel: String, count: Int, confidence: LevelConfidence) {
        self.level = level
        self.targetLevel = targetLevel
        self.count = count
        self.confidence = confidence
    }
}

/// Level estimation and recommendations (tutor-local.ts `estimatedLevel`, `recommendations`).
public enum LevelEstimator {
    /// `estimatedLevel`: mastery-weighted average CEFR of practiced meanings (≥ 40%), or of all
    /// declared meanings (low confidence). Meanings without a valid level are ignored.
    public static func estimatedLevel(_ state: LearnerState) -> LevelEstimate {
        var available: [(level: Int, score: Int)] = []
        for word in state.words where !word.archived {
            for meaning in word.meanings {
                if let index = CEFR.index(of: meaning.effectiveLevel(in: word)) {
                    available.append((index, Mastery.of(meaning)))
                }
            }
        }
        let practiced = available.filter { $0.score >= 40 }
        var sample: [(level: Int, score: Int)] = practiced
        if practiced.isEmpty {
            sample = available.map { item -> (level: Int, score: Int) in (level: item.level, score: max(10, item.score)) }
        }
        guard !sample.isEmpty else {
            return LevelEstimate(level: "A1", targetLevel: "A2", count: 0, confidence: .low)
        }
        let weighted = sample.reduce(0.0) { $0 + Double($1.level * $1.score) }
        let total = sample.reduce(0.0) { $0 + Double($1.score) }
        let average = total > 0 ? weighted / total : 0
        let index = min(CEFR.levels.count - 1, max(0, jsRoundInt(average)))
        return LevelEstimate(
            level: CEFR.levels[index],
            targetLevel: CEFR.levels[min(CEFR.levels.count - 1, index + 1)],
            count: sample.count,
            confidence: practiced.isEmpty ? .low : .high
        )
    }

    /// `recommendations`: up to 3 harder related words for mastered words the learner knows,
    /// skipping terms already in the vocabulary.
    public static func recommendations(_ state: LearnerState, candidates: [Recommendation]) -> [Recommendation] {
        let known = state.words.filter { word in
            !word.archived && word.meanings.contains { Mastery.of($0) >= Mastery.masteredThreshold }
        }
        let existing = Set(state.words.filter { !$0.archived }.map { TextNormalizer.normalize($0.en) })
        let result = candidates.filter { recommendation in
            known.contains { word in
                word.en == recommendation.known && CEFR.jsIndex(of: word.level) < CEFR.jsIndex(of: recommendation.level)
            } && !existing.contains(TextNormalizer.normalize(recommendation.term))
        }
        return Array(result.prefix(3))
    }

    /// `recommendationLookup`: a recommendation as a one-sense lookup ready for `mergeSuggestions`.
    public static func lookup(for recommendation: Recommendation) -> Lookup {
        let focusPl = recommendation.focusPl ?? polishFocus(translation: recommendation.translation, sentence: recommendation.examplePl)
        let neutral = ["create", "carry out"].contains(recommendation.term)
        let sense = SenseSuggestion(
            translation: recommendation.translation,
            definition: recommendation.difference,
            pos: "czasownik",
            level: recommendation.level,
            context: "Rozwijanie słownictwa",
            register: neutral ? "neutralny" : "formalny",
            natural: recommendation.known,
            collection: "Krok dalej",
            examples: [ExamplePair(en: recommendation.example, pl: recommendation.examplePl, focusEn: recommendation.term, focusPl: focusPl)],
            acceptedAnswers: []
        )
        return Lookup(
            exists: true,
            term: recommendation.term,
            ipa: recommendation.ipa ?? "",
            synonyms: recommendation.known,
            note: recommendation.difference,
            meanings: [sense],
            source: .starter
        )
    }

    /// A fragment of `sentence` corresponding to the translation (exact part, or a word with the
    /// same 4-letter beginning), "" when nothing fits — never a non-substring.
    static func polishFocus(translation: String, sentence: String) -> String {
        let parts = translation.split(separator: ",").map { TextScanning.trim(String($0)) }.filter { !$0.isEmpty }
        let lowerSentence = sentence.lowercased()
        for part in parts {
            if let range = lowerSentence.range(of: part.lowercased()) {
                let start = lowerSentence.distance(from: lowerSentence.startIndex, to: range.lowerBound)
                let length = part.count
                let chars = Array(sentence)
                if start + length <= chars.count {
                    return String(chars[start..<(start + length)])
                }
            }
        }
        let words = sentence.split(whereSeparator: { !$0.isLetter }).map(String.init)
        for part in parts {
            let stem = String(TextScanning.foldPolish(part).prefix(4))
            guard stem.count == 4 else { continue }
            if let word = words.first(where: { TextScanning.foldPolish($0).hasPrefix(stem) }) {
                return word
            }
        }
        return ""
    }
}
