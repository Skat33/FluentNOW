import Foundation

/// „Zrozum ze słuchu” (FEEDBACK-4 I2): the example sentence is read aloud (text hidden until the
/// answer, at most `maxPlays` plays, a slower option), the learner picks its Polish translation
/// out of four. Distractors are translations of other example sentences of similar length.
public enum ListeningChoice {
    /// Options shown (the right translation + 3 distractors).
    public static let optionCount = 4
    /// Plays before answering (normal or slow, together).
    public static let maxPlays = 3
    /// Sentences with fewer / more words are not used.
    public static let minWords = 3
    public static let maxWords = 25
    /// Words scanned for distractors (bounded — a 5 000-word dictionary stays fast).
    static let scanLimit = 800
    /// Distractors are drawn from this many candidates closest in length.
    static let closestPool = 10

    /// Polish translation of the example at `exampleIndex` (wrapped like the screen), or `nil`.
    public static func translation(meaning: Meaning, exampleIndex: Int) -> String? {
        let count = meaning.examples.count
        guard count > 0 else { return nil }
        let index = ((exampleIndex % count) + count) % count
        let text = TextScanning.trim(meaning.exampleTranslations?[safe: index] ?? "")
        return text.isEmpty ? nil : text
    }

    /// `true` when the example has a Polish translation and 3–25 words.
    public static func canBuild(meaning: Meaning, exampleIndex: Int) -> Bool {
        guard translation(meaning: meaning, exampleIndex: exampleIndex) != nil,
              let sentence = SentenceScramble.example(meaning: meaning, exampleIndex: exampleIndex)?.sentence else { return false }
        let words = SentenceScramble.tokens(sentence).count
        return words >= minWords && words <= maxWords
    }

    /// `true` when the dictionary has at least `optionCount` different example translations (three
    /// distractors can be found for any sentence). Checked once per session build.
    public static func hasDistractorPool(_ state: LearnerState) -> Bool {
        var keys = Set<String>()
        for word in state.words where !word.archived {
            for meaning in word.meanings {
                for text in meaning.exampleTranslations ?? [] {
                    let key = TextNormalizer.normalize(text)
                    guard !key.isEmpty else { continue }
                    keys.insert(key)
                    if keys.count >= optionCount { return true }
                }
            }
        }
        return false
    }

    /// The options of one task in a stable order (`seed` = task key): the right translation plus
    /// up to three distractors — translations of other examples (also other sentences of the same
    /// word) closest in length. `extra` adds a fallback pool (e.g. starter words). Fewer than two
    /// options means the task cannot be shown (the screen falls back to dictation).
    public static func options(state: LearnerState, meaning: Meaning, exampleIndex: Int, seed: String, extra: [String] = []) -> [String] {
        guard let target = translation(meaning: meaning, exampleIndex: exampleIndex) else { return [] }
        let targetKey = TextNormalizer.normalize(target)
        let targetLength = target.count
        var generator = SeededGenerator(seed: "listening:" + seed)
        var seen: Set<String> = [targetKey]
        var candidates: [(text: String, distance: Int, tie: Double)] = []
        func consider(_ raw: String) {
            let text = TextScanning.trim(raw)
            let key = TextNormalizer.normalize(text)
            guard !key.isEmpty, seen.insert(key).inserted else { return }
            candidates.append((text: text, distance: abs(text.count - targetLength), tie: generator.nextUnit()))
        }
        let words = state.words.filter { (word: Word) -> Bool in !word.archived }
        if !words.isEmpty {
            let start = generator.nextIndex(below: words.count)
            let scanned = min(words.count, scanLimit)
            for step in 0..<scanned {
                let word = words[(start + step) % words.count]
                for other in word.meanings {
                    for text in other.exampleTranslations ?? [] {
                        consider(text)
                    }
                }
            }
        }
        if candidates.count < optionCount - 1 {
            for text in extra {
                consider(text)
            }
        }
        let closest = candidates.sorted { (a: (text: String, distance: Int, tie: Double), b: (text: String, distance: Int, tie: Double)) -> Bool in
            if a.distance != b.distance { return a.distance < b.distance }
            return a.tie < b.tie
        }.prefix(closestPool)
        var pool = Array(closest.map { $0.text })
        var chosen: [String] = []
        while chosen.count < optionCount - 1 && !pool.isEmpty {
            chosen.append(pool.remove(at: generator.nextIndex(below: pool.count)))
        }
        let all = [target] + chosen
        let keyed = all.map { (text: String) -> (text: String, key: Double) in (text: text, key: generator.nextUnit()) }
        return keyed.sorted { $0.key < $1.key }.map { $0.text }
    }

    /// Index of the right option (`nil` when it is missing).
    public static func correctIndex(options: [String], meaning: Meaning, exampleIndex: Int) -> Int? {
        guard let target = translation(meaning: meaning, exampleIndex: exampleIndex) else { return nil }
        let key = TextNormalizer.normalize(target)
        return options.firstIndex { (option: String) -> Bool in TextNormalizer.normalize(option) == key }
    }
}
