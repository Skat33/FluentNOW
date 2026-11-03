import Foundation

/// One word of the sentence after a pronunciation attempt.
public struct PronunciationWord: Sendable, Hashable, Identifiable {
    /// Position in the sentence.
    public var id: Int
    /// The word as written in the sentence (edge punctuation removed).
    public var text: String
    /// The speech recogniser heard this word in place.
    public var heard: Bool

    public init(id: Int, text: String, heard: Bool) {
        self.id = id
        self.text = text
        self.heard = heard
    }
}

/// Word-by-word result of „Powiedz to zdanie na głos” (FEEDBACK-10 P2). Orientation only — it
/// never changes mastery.
public struct PronunciationScore: Sendable, Hashable {
    public var words: [PronunciationWord]
    public var heardCount: Int
    public var transcript: String

    public init(words: [PronunciationWord], heardCount: Int, transcript: String) {
        self.words = words
        self.heardCount = heardCount
        self.transcript = transcript
    }

    public var total: Int { words.count }

    /// 0…1 — share of the sentence's words heard in order.
    public var fraction: Double {
        total > 0 ? Double(heardCount) / Double(total) : 0
    }

    /// Words that were not recognised (to say again).
    public var missedWords: [String] {
        words.filter { (word: PronunciationWord) -> Bool in !word.heard }.map { (word: PronunciationWord) -> String in word.text }
    }

    /// A calm Polish verdict (the recogniser is not an examiner).
    public var verdictPl: String {
        if TextScanning.trim(transcript).isEmpty {
            return "Nic nie usłyszałem. Mów wyraźnie, bliżej mikrofonu, i spróbuj jeszcze raz."
        }
        if fraction >= 0.9 {
            return "Świetnie — urządzenie rozpoznało całe zdanie."
        }
        if fraction >= 0.6 {
            return "Dobrze. Powtórz słowa zaznaczone na pomarańczowo."
        }
        return "Część słów nie została rozpoznana. Posłuchaj zdania i spróbuj jeszcze raz."
    }
}

/// Compares a sentence with a speech transcript word by word (longest common subsequence of
/// comparison keys — a skipped or misheard word does not shift the rest). Keys ignore case and
/// punctuation, expand unambiguous contractions („I'm” = „I am”), split hyphenated words
/// („check-in” = „check in”) and read numbers 0–20 as words („7” = „seven”).
public enum PronunciationScoring {
    public static func score(expected: String, heard: String) -> PronunciationScore {
        let tokens = SentenceScramble.tokens(expected)
        var flat: [(key: String, owner: Int)] = []
        for (owner, token) in tokens.enumerated() {
            for key in keys(token) {
                flat.append((key: key, owner: owner))
            }
        }
        let heardKeys = keys(heard)
        let matched = matchedPositions(flat.map { (item: (key: String, owner: Int)) -> String in item.key }, heardKeys)
        var missedOwners = Set<Int>()
        for (position, item) in flat.enumerated() where !matched.contains(position) {
            missedOwners.insert(item.owner)
        }
        let words = tokens.enumerated().map { (entry: (offset: Int, element: String)) -> PronunciationWord in
            PronunciationWord(id: entry.offset, text: entry.element, heard: !missedOwners.contains(entry.offset))
        }
        let heardCount = words.filter { (word: PronunciationWord) -> Bool in word.heard }.count
        return PronunciationScore(words: words, heardCount: heardCount, transcript: heard)
    }

    /// Comparison keys of free text (see the type description).
    public static func keys(_ text: String) -> [String] {
        let expanded = TextNormalizer.englishAnswerKey(text.replacingOccurrences(of: "-", with: " "))
        var result: [String] = []
        for token in SentenceScramble.tokens(expanded) {
            let key = SentenceScramble.key(token)
            guard !key.isEmpty else { continue }
            result.append(numberWords[key] ?? spellingVariants[key] ?? key)
        }
        return result
    }

    /// Positions of `expected` that are part of a longest common subsequence with `heard`.
    static func matchedPositions(_ expected: [String], _ heard: [String]) -> Set<Int> {
        let n = expected.count
        let m = heard.count
        guard n > 0, m > 0 else { return [] }
        var table = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if expected[i] == heard[j] {
                    table[i][j] = table[i + 1][j + 1] + 1
                } else {
                    table[i][j] = max(table[i + 1][j], table[i][j + 1])
                }
            }
        }
        var result = Set<Int>()
        var i = 0
        var j = 0
        while i < n && j < m {
            if expected[i] == heard[j] {
                result.insert(i)
                i += 1
                j += 1
            } else if table[i + 1][j] >= table[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return result
    }

    private static let numberWords: [String: String] = [
        "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "6": "six",
        "7": "seven", "8": "eight", "9": "nine", "10": "ten", "11": "eleven", "12": "twelve",
        "13": "thirteen", "14": "fourteen", "15": "fifteen", "16": "sixteen", "17": "seventeen",
        "18": "eighteen", "19": "nineteen", "20": "twenty"
    ]

    /// Spellings the recogniser writes differently from the content.
    private static let spellingVariants: [String: String] = [
        "okay": "ok", "o.k": "ok", "mr": "mister", "mrs": "missus", "ms": "miz"
    ]
}
