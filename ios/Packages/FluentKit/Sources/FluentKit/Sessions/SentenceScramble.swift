import Foundation

/// One tile of „Ułóż zdanie”.
public struct ScrambleTile: Sendable, Hashable, Identifiable {
    /// Position on the shuffled board (stable for one task).
    public var id: Int
    /// Text shown on the tile (no punctuation at the edges).
    public var text: String
    /// `true` for a decoy word that does not belong to the sentence.
    public var isDecoy: Bool

    public init(id: Int, text: String, isDecoy: Bool) {
        self.id = id
        self.text = text
        self.isDecoy = isDecoy
    }
}

/// The board of one „Ułóż zdanie” task.
public struct ScrambleBoard: Sendable, Hashable {
    /// The example sentence as stored (shown after answering).
    public var sentence: String
    /// Polish translation of the sentence (the hint; may be empty).
    public var translation: String
    /// The words of the sentence in the right order (tile texts).
    public var answer: [String]
    /// All tiles in their shuffled order (sentence words + decoys).
    public var tiles: [ScrambleTile]

    public init(sentence: String, translation: String, answer: [String], tiles: [ScrambleTile]) {
        self.sentence = sentence
        self.translation = translation
        self.answer = answer
        self.tiles = tiles
    }

    public var decoyCount: Int {
        tiles.filter { (tile: ScrambleTile) -> Bool in tile.isDecoy }.count
    }
}

/// „Ułóż zdanie” (rozsypanka, FEEDBACK-4 I2): the words of an example sentence with the learned
/// word as tiles in random order, plus 1–3 decoys (FEEDBACK-9 N1, `ScrambleDecoys`). The Polish
/// translation is always shown above the tiles. Punctuation and letter case never matter when
/// checking; the sentence is right only with exactly its own words in order (decoys stay unused).
public enum SentenceScramble {
    /// Sentences shorter or longer than this are not scrambled (≈ 96 % of the built-in examples
    /// have 6–14 words).
    public static let minWords = 4
    public static let maxWords = 14
    /// Most decoys on one board.
    public static let maxDecoys = 3

    /// Characters kept at the edge of a tile besides letters and digits.
    private static let keptEdgeCharacters: Set<Character> = ["$", "€", "£", "%", "&", "+", "#"]

    /// Sentence starters shown in lower case on the tile (any other first word keeps its case —
    /// it may be a name). Never used as content-word decoys: a pronoun or article taken from
    /// another sentence could build another correct sentence (prepositions and „a/an” come only
    /// from the safe rules in `ScrambleDecoys`).
    static let functionWords: Set<String> = [
        "a", "an", "the", "this", "that", "these", "those", "my", "your", "his", "her", "its", "our",
        "their", "we", "you", "they", "he", "she", "it", "there", "here", "what", "where", "when",
        "why", "how", "who", "which", "can", "could", "do", "does", "did", "is", "are", "was", "were",
        "will", "would", "should", "shall", "may", "might", "must", "have", "has", "had", "please",
        "let's", "if", "after", "before", "some", "many", "most", "every", "each", "all", "at", "in",
        "on", "for", "to", "with", "from", "of", "by", "and", "or", "but", "so", "not", "no", "yes",
        "don't", "doesn't", "didn't", "can't", "won't", "isn't", "aren't", "wasn't", "it's",
        "there's", "that's", "she's", "he's", "we're", "they're", "you're", "we'll", "you'll",
        "i", "i'm", "i'll", "i've", "i'd", "me", "him", "them", "us", "one", "be", "been", "being",
        "as", "than", "then", "too", "very", "just", "about", "into", "over", "under", "up", "down",
        "out", "off", "again", "also", "only", "any", "much", "more"
    ]

    // MARK: Tokens

    /// Words of a sentence: split at whitespace, punctuation removed from the edges of each word
    /// (inner apostrophes and hyphens stay: „don't”, „check-in”); pieces without a letter or
    /// digit (dashes) are dropped.
    public static func tokens(_ sentence: String) -> [String] {
        var result: [String] = []
        for chunk in sentence.split(whereSeparator: { (character: Character) -> Bool in character.isWhitespace }) {
            var characters = Array(chunk)
            while let first = characters.first, !isKept(first) {
                characters.removeFirst()
            }
            while let last = characters.last, !isKept(last) {
                characters.removeLast()
            }
            let word = String(characters)
            if word.contains(where: { (character: Character) -> Bool in character.isLetter || character.isNumber }) {
                result.append(word)
            }
        }
        return result
    }

    /// Comparison key of a tile: lower case, typographic apostrophes folded, edge punctuation
    /// removed — „Don’t,” and „don't” are the same tile.
    public static func key(_ token: String) -> String {
        let folded = token.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
        return tokens(folded).joined(separator: " ")
    }

    private static func isKept(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || keptEdgeCharacters.contains(character)
    }

    // MARK: Eligibility

    /// The example used by a task (`index` wraps like the screen: `index % count`).
    static func example(meaning: Meaning, exampleIndex: Int) -> (sentence: String, index: Int)? {
        let count = meaning.examples.count
        guard count > 0 else { return nil }
        let index = ((exampleIndex % count) + count) % count
        guard let sentence = meaning.examples[safe: index] else { return nil }
        return (sentence, index)
    }

    /// `true` when the example has 4–14 words (a board can be built).
    public static func canBuild(meaning: Meaning, exampleIndex: Int) -> Bool {
        guard let example = example(meaning: meaning, exampleIndex: exampleIndex) else { return false }
        let count = tokens(example.sentence).count
        return count >= minWords && count <= maxWords
    }

    /// Number of decoys (FEEDBACK-9 N1): 1–3 by the CEFR level of the meaning (A → 1, B → 2,
    /// C → 3), one more once usage was answered correctly three times, never more than the
    /// sentence length allows (≤ 6 words → 1, 7–9 → 2, longer → 3).
    public static func decoyCount(word: Word, meaning: Meaning, wordCount: Int) -> Int {
        let level = meaning.effectiveLevel(in: word).uppercased()
        var count = 1
        if level.hasPrefix("B") { count = 2 }
        if level.hasPrefix("C") { count = 3 }
        if let usage = meaning.scores[.usage], usage.correct >= 3 { count += 1 }
        let lengthCap: Int
        if wordCount <= 6 {
            lengthCap = 1
        } else if wordCount <= 9 {
            lengthCap = 2
        } else {
            lengthCap = 3
        }
        return max(1, min(maxDecoys, min(count, lengthCap)))
    }

    /// Seed of a vocabulary session for its boards: stable while the session lasts (its first task
    /// never changes), so a resumed task shows the same tiles; another session shuffles anew.
    public static func sessionSeed(tasks: [VocabTask], mode: String) -> String {
        guard let first = tasks.first else { return mode }
        return "\(mode):\(first.wordId):\(first.meaningId):\(first.type.rawValue):\(first.example)"
    }

    /// A few example sentences of other words (deterministic for `seed`) — the last-resort source
    /// of decoys when the sentence and the entry give none.
    public static func poolSentences(state: LearnerState, excludingWordID: String, seed: String, limit: Int = 6) -> [String] {
        let words = state.words
        guard words.count > 1, limit > 0 else { return [] }
        var generator = SeededGenerator(seed: "scramble-pool:" + seed)
        var result: [String] = []
        var attempts = 0
        while result.count < limit && attempts < limit * 4 {
            attempts += 1
            guard let candidate = words[safe: generator.nextIndex(below: words.count)], candidate.id != excludingWordID else { continue }
            let sentences: [String] = candidate.meanings.flatMap { (other: Meaning) -> [String] in other.examples }
            guard let sentence = sentences[safe: generator.nextIndex(below: sentences.count)],
                  !result.contains(sentence) else { continue }
            result.append(sentence)
        }
        return result
    }

    // MARK: Board

    /// The board of a task. Deterministic for `seed` (session seed + task) — a resumed task shows
    /// the same tiles and decoys. `pool` — sentences of other words (`poolSentences`), used only
    /// when the sentence and the entry give too few decoys. `nil` when the sentence cannot be
    /// scrambled.
    public static func board(word: Word, meaning: Meaning, exampleIndex: Int, seed: String, pool: [String] = []) -> ScrambleBoard? {
        guard canBuild(meaning: meaning, exampleIndex: exampleIndex),
              let example = example(meaning: meaning, exampleIndex: exampleIndex) else { return nil }
        var answer = tokens(example.sentence)
        guard let first = answer.first else { return nil }
        if functionWords.contains(key(first)) && first != "I" && !first.hasPrefix("I'") && !first.hasPrefix("I\u{2019}") {
            answer[0] = first.lowercased()
        }
        var generator = SeededGenerator(seed: "scramble:" + seed)
        let decoys = self.decoys(
            word: word,
            meaning: meaning,
            exampleIndex: example.index,
            answer: answer,
            pool: pool,
            using: &generator
        )
        var texts: [(text: String, isDecoy: Bool)] = answer.map { (text: String) -> (text: String, isDecoy: Bool) in (text: text, isDecoy: false) }
        texts.append(contentsOf: decoys.map { (decoy: ScrambleDecoy) -> (text: String, isDecoy: Bool) in (text: decoy.text, isDecoy: true) })
        var order = Array(texts.indices)
        var position = order.count - 1
        while position > 0 {
            let other = generator.nextIndex(below: position + 1)
            order.swapAt(position, other)
            position -= 1
        }
        // Never show the sentence already in order.
        let sentenceOrder = order.filter { (index: Int) -> Bool in index < answer.count }
        if sentenceOrder == Array(0..<answer.count),
           let firstSlot = order.firstIndex(of: 0), let secondSlot = order.firstIndex(of: 1) {
            order.swapAt(firstSlot, secondSlot)
        }
        let tiles = order.enumerated().map { (entry: (offset: Int, element: Int)) -> ScrambleTile in
            ScrambleTile(id: entry.offset, text: texts[entry.element].text, isDecoy: texts[entry.element].isDecoy)
        }
        let translation = TextScanning.trim(meaning.exampleTranslations?[safe: example.index] ?? "")
        return ScrambleBoard(sentence: example.sentence, translation: translation, answer: answer, tiles: tiles)
    }

    /// Decoys of a board (`ScrambleDecoys.choose`): 1–3 words that are never words of the sentence
    /// and never build another correct sentence — wrong verb forms and prepositions first (the
    /// focus expression before other words), then words from the entry's other examples, then
    /// words from `pool`.
    static func decoys<G: RandomNumberGenerator>(word: Word, meaning: Meaning, exampleIndex: Int, answer: [String], pool: [String], using rng: inout G) -> [ScrambleDecoy] {
        let entrySentences: [String] = word.meanings.flatMap { (other: Meaning) -> [String] in
            other.examples.enumerated().compactMap { (entry: (offset: Int, element: String)) -> String? in
                other.id == meaning.id && entry.offset == exampleIndex ? nil : entry.element
            }
        }
        let savedFocus = meaning.exampleFocusEn?[safe: exampleIndex] ?? ""
        let focusText = savedFocus.isEmpty ? word.en : savedFocus
        let focusKeys = Set(tokens(focusText).map { (token: String) -> String in key(token) })
        return ScrambleDecoys.choose(
            answer: answer,
            focusKeys: focusKeys,
            entrySentences: entrySentences,
            pool: pool,
            count: decoyCount(word: word, meaning: meaning, wordCount: answer.count),
            using: &rng
        )
    }

    // MARK: Checking

    /// `true` when the placed tiles spell the sentence (case and punctuation ignored, no decoy).
    public static func isCorrect(_ placed: [String], board: ScrambleBoard) -> Bool {
        placed.map { (text: String) -> String in key(text) } == board.answer.map { (text: String) -> String in key(text) }
    }

    /// Number of leading tiles already in the right place (shown after a wrong attempt).
    public static func correctPrefixCount(_ placed: [String], board: ScrambleBoard) -> Int {
        var count = 0
        for (index, text) in placed.enumerated() {
            guard let expected = board.answer[safe: index], key(expected) == key(text) else { break }
            count += 1
        }
        return count
    }
}
