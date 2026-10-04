import Foundation

/// Text normalisation used for comparing answers, translations and search keys.
/// Ports of `normalize` (learning.ts), `answerKey`, `englishAnswerKey`, `withoutDialectLabel`
/// (answer-variants.ts) and `levenshtein` (tutor-local.ts).
public enum TextNormalizer {
    private static let normalizePunctuation: Set<Character> = [".", ",", "!", "?", ";", ":"]
    private static let trailingPunctuation: Set<Character> = [".", "!", "?", ",", ";", ":"]

    /// `normalize` from learning.ts: lowercase, trim, drop `. , ! ? ; :`, collapse whitespace.
    /// Keeps Polish diacritics (used for identity of words and translations).
    public static func normalize(_ value: String) -> String {
        let trimmed = TextScanning.trim(value.lowercased())
        let withoutPunctuation = TextScanning.removing(normalizePunctuation, from: trimmed)
        return TextScanning.collapseWhitespace(withoutPunctuation)
    }

    /// Removes `(AmE)` / `(BrE)` labels (case-insensitive) together with the whitespace before them.
    public static func withoutDialectLabel(_ text: String) -> String {
        let chars = Array(text)
        var out: [Character] = []
        out.reserveCapacity(chars.count)
        var index = 0
        while index < chars.count {
            if chars[index] == "(", index + 4 < chars.count, chars[index + 4] == ")" {
                let inner = String(chars[(index + 1)...(index + 3)]).lowercased()
                if inner == "ame" || inner == "bre" {
                    while let last = out.last, last.isWhitespace {
                        out.removeLast()
                    }
                    index += 5
                    continue
                }
            }
            out.append(chars[index])
            index += 1
        }
        return TextScanning.trim(String(out))
    }

    /// `answerKey`: dialect label removed, lowercase, no diacritics (`ł`→`l`), straight apostrophes,
    /// trimmed, trailing `.!?,;:` removed, single spaces.
    public static func answerKey(_ text: String) -> String {
        var value = TextScanning.foldPolish(withoutDialectLabel(text))
        value = TextScanning.straightenApostrophes(value)
        value = TextScanning.trim(value)
        value = TextScanning.removingTrailing(trailingPunctuation, from: value)
        value = TextScanning.collapseWhitespace(value)
        // Deviation: the web leaves a trailing space for inputs like "word ." — trimmed here.
        return TextScanning.trim(value)
    }

    /// `englishAnswerKey`: `answerKey` plus expansion of unambiguous contractions
    /// (won't, can't, shan't, n't, 're, 've, 'll, 'm). Ambiguous 's / 'd stay untouched.
    public static func englishAnswerKey(_ value: String) -> String {
        var text = answerKey(value)
        text = expandUnambiguousContractions(text)
        return TextScanning.trim(TextScanning.collapseWhitespace(text))
    }

    /// Shared by `englishAnswerKey` and `normalizeProduction`.
    static func expandUnambiguousContractions(_ input: String) -> String {
        var text = input
        text = TextScanning.replaceToken(text, "won't", with: "will not", leftBoundary: true)
        text = TextScanning.replaceToken(text, "can't", with: "cannot", leftBoundary: true)
        text = TextScanning.replaceToken(text, "can not", with: "cannot", leftBoundary: true)
        text = TextScanning.replaceToken(text, "shan't", with: "shall not", leftBoundary: true)
        text = TextScanning.replaceToken(text, "n't", with: " not", leftBoundary: false)
        text = TextScanning.replaceToken(text, "'re", with: " are", leftBoundary: false)
        text = TextScanning.replaceToken(text, "'ve", with: " have", leftBoundary: false)
        text = TextScanning.replaceToken(text, "'ll", with: " will", leftBoundary: false)
        text = TextScanning.replaceToken(text, "'m", with: " am", leftBoundary: false)
        return text
    }

    /// Key used by the dictionary search index (`k` in `dictionary-index.json`):
    /// lowercase, no diacritics, `’`→`'`, single spaces, trimmed.
    public static func searchKey(_ text: String) -> String {
        var value = TextScanning.foldPolish(text)
        value = TextScanning.straightenApostrophes(value)
        value = TextScanning.collapseWhitespace(value)
        return TextScanning.trim(value)
    }

    /// Edit distance (insert / delete / substitute) over Unicode scalars.
    public static func levenshtein(_ left: String, _ right: String) -> Int {
        let a = Array(left.unicodeScalars)
        let b = Array(right.unicodeScalars)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        for row in 1...a.count {
            var diagonal = previous[0]
            previous[0] = row
            for column in 1...b.count {
                let above = previous[column]
                let cost = a[row - 1] == b[column - 1] ? 0 : 1
                previous[column] = Swift.min(previous[column] + 1, previous[column - 1] + 1, diagonal + cost)
                diagonal = above
            }
        }
        return previous[b.count]
    }

    /// Levenshtein distance with an upper bound over byte arrays; returns `nil` when the
    /// distance exceeds `limit`. Used by the dictionary fuzzy search.
    static func boundedLevenshtein(_ a: [UInt8], _ b: [UInt8], limit: Int) -> Int? {
        if abs(a.count - b.count) > limit { return nil }
        if a.isEmpty { return b.count <= limit ? b.count : nil }
        if b.isEmpty { return a.count <= limit ? a.count : nil }
        let large = limit + 1
        var previous = [Int](repeating: large, count: b.count + 1)
        var current = [Int](repeating: large, count: b.count + 1)
        for column in 0...b.count {
            previous[column] = column <= limit ? column : large
        }
        for row in 1...a.count {
            let low = Swift.max(1, row - limit)
            let high = Swift.min(b.count, row + limit)
            for column in 0...b.count {
                current[column] = large
            }
            current[0] = row <= limit ? row : large
            var rowMinimum = current[0]
            if low <= high {
                for column in low...high {
                    let cost = a[row - 1] == b[column - 1] ? 0 : 1
                    let value = Swift.min(previous[column] + 1, current[column - 1] + 1, previous[column - 1] + cost)
                    current[column] = Swift.min(value, large)
                    if current[column] < rowMinimum { rowMinimum = current[column] }
                }
            }
            if rowMinimum > limit { return nil }
            swap(&previous, &current)
        }
        let result = previous[b.count]
        return result <= limit ? result : nil
    }
}
