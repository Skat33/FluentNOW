import Foundation

/// Location of the focus word inside an example sentence.
public struct ClozeSpan: Sendable, Hashable {
    /// Range of the matched text in the original sentence.
    public var range: Range<String.Index>
    /// The matched text as written in the sentence (may be inflected: "borrowed").
    public var match: String
    /// Offset of the match in Characters.
    public var characterOffset: Int
}

/// Cloze helpers (learning.ts `clozeSpan`, `clozeText`).
public enum Cloze {
    /// Gap marker used in cloze sentences (8 underscores).
    public static let gap = "________"

    private static let inflections = ["s", "es", "ed", "ing", "d"]

    /// Finds `focus` as a whole word (case-insensitive, ASCII-letter boundaries).
    /// Single words may also match with `-s/-es/-ed/-ing/-d`. Never matches inside another word.
    public static func span(in text: String, focus: String) -> ClozeSpan? {
        let trimmedFocus = TextScanning.trim(focus)
        guard !trimmedFocus.isEmpty else { return nil }
        let chars = Array(text)
        let lowerChars = chars.map(lowercasedCharacter)
        let focusChars = Array(trimmedFocus).map(lowercasedCharacter)
        if let offset = findWord(lowerChars, focusChars, suffixes: [""]) {
            return makeSpan(text: text, chars: chars, offset: offset.start, length: offset.length)
        }
        if !trimmedFocus.contains(" ") {
            if let offset = findWord(lowerChars, focusChars, suffixes: inflections) {
                return makeSpan(text: text, chars: chars, offset: offset.start, length: offset.length)
            }
        }
        return nil
    }

    /// Lowercases one Character, keeping it unchanged if lowercasing would change its length.
    static func lowercasedCharacter(_ character: Character) -> Character {
        let lowered = character.lowercased()
        guard lowered.count == 1, let first = lowered.first else { return character }
        return first
    }

    /// The sentence with the focus replaced by `________`, or `nil` when the focus is not found.
    public static func text(_ text: String, focus: String) -> String? {
        guard let span = span(in: text, focus: focus) else { return nil }
        var result = text
        result.replaceSubrange(span.range, with: gap)
        return result
    }

    /// Leftmost position where `focus + suffix` is a whole word; suffixes tried in order at each position.
    private static func findWord(_ chars: [Character], _ focus: [Character], suffixes: [String]) -> (start: Int, length: Int)? {
        guard !focus.isEmpty, chars.count >= focus.count else { return nil }
        let suffixChars = suffixes.map { Array($0) }
        var start = 0
        while start + focus.count <= chars.count {
            let leftOK = start == 0 || !TextScanning.isASCIILetter(chars[start - 1])
            if leftOK && TextScanning.matches(chars, at: start, focus) {
                for suffix in suffixChars {
                    let end = start + focus.count
                    if !suffix.isEmpty && !TextScanning.matches(chars, at: end, suffix) { continue }
                    let finish = end + suffix.count
                    let rightOK = finish == chars.count || (finish < chars.count && !TextScanning.isASCIILetter(chars[finish]))
                    if rightOK { return (start, finish - start) }
                }
            }
            start += 1
        }
        return nil
    }

    private static func makeSpan(text: String, chars: [Character], offset: Int, length: Int) -> ClozeSpan? {
        guard offset >= 0, length > 0, offset + length <= chars.count else { return nil }
        guard let lower = text.index(text.startIndex, offsetBy: offset, limitedBy: text.endIndex),
              let upper = text.index(lower, offsetBy: length, limitedBy: text.endIndex) else { return nil }
        return ClozeSpan(range: lower..<upper, match: String(text[lower..<upper]), characterOffset: offset)
    }
}
