import Foundation

/// Text to read aloud for exercises (exercise-audio.ts). Gaps become `ExerciseAudio.speechGap`
/// before checking (the speech layer renders it as a short pause) and the answer key after.
public enum ExerciseAudio {
    /// Marker for a silent gap.
    public static let speechGap = "[[gap]]"

    /// `exerciseAudioText`: `________ (hint)` → gap; after checking, the gap is filled with the
    /// key — never with the learner's answer.
    public static func exerciseAudioText(context: String, solved: Bool, correctAnswer: String) -> String {
        let chars = Array(context)
        let gapChars = Array(speechGap)
        let filler = solved ? correctAnswer : speechGap
        var out = ""
        var index = 0
        while index < chars.count {
            if chars[index] == "_", index + 1 < chars.count, chars[index + 1] == "_" {
                var end = index
                while end < chars.count && chars[end] == "_" { end += 1 }
                // Optional "  (hint)" directly after the gap is dropped.
                var look = end
                while look < chars.count && chars[look].isWhitespace { look += 1 }
                if look < chars.count && chars[look] == "(" {
                    var close = look + 1
                    while close < chars.count && chars[close] != ")" { close += 1 }
                    if close < chars.count { end = close + 1 }
                }
                out += filler
                index = end
                continue
            }
            if TextScanning.matches(chars, at: index, gapChars) {
                out += filler
                index += gapChars.count
                continue
            }
            out.append(chars[index])
            index += 1
        }
        return TextScanning.trim(TextScanning.collapseWhitespace(out))
    }

    /// `vocabularyAudioText`: the example sentence; when `hidden`, every whole-word occurrence of the
    /// focus becomes a gap. If the focus cannot be found the result is `""` (stay silent rather
    /// than reveal the answer).
    public static func vocabularyAudioText(example: String, focus: String, hidden: Bool) -> String {
        guard hidden else { return example }
        let trimmed = TextScanning.trim(focus)
        guard !trimmed.isEmpty else { return "" }
        let chars = Array(example)
        let lower = chars.map(Cloze.lowercasedCharacter)
        let target = Array(trimmed).map(Cloze.lowercasedCharacter)
        var out = ""
        var index = 0
        var found = false
        while index < chars.count {
            let leftOK = index == 0 || !TextScanning.isASCIILetter(chars[index - 1])
            if leftOK && TextScanning.matches(lower, at: index, target) {
                let end = index + target.count
                if end == chars.count || !TextScanning.isASCIILetter(chars[end]) {
                    out += speechGap
                    index = end
                    found = true
                    continue
                }
            }
            out.append(chars[index])
            index += 1
        }
        return found ? out : ""
    }
}

/// A piece of a reading passage; `wordId` is set for saved vocabulary.
public struct ReadingToken: Sendable, Hashable {
    public var text: String
    public var wordId: String?

    public init(text: String, wordId: String? = nil) {
        self.text = text
        self.wordId = wordId
    }
}

/// Highlighting saved words in readings (reading-vocabulary.ts `readingTokens`).
public enum ReadingTokenizer {
    private static func isLetterOrNumber(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
    }

    /// Splits `text` into tokens; the longest saved phrase wins and a word never matches inside
    /// another word. Archived words are ignored. Joined token texts equal `text`.
    public static func tokens(text: String, words: [Word]) -> [ReadingToken] {
        var terms: [String: String] = [:]
        for word in words where !word.archived {
            var candidates = [word.en]
            for meaning in word.meanings {
                candidates.append(contentsOf: meaning.exampleFocusEn ?? [])
            }
            for term in candidates {
                let normalized = TextScanning.trim(term).lowercased()
                if !normalized.isEmpty && normalized.count <= 120 && terms[normalized] == nil {
                    terms[normalized] = word.id
                }
            }
        }
        guard !terms.isEmpty else { return [ReadingToken(text: text)] }
        let chars = Array(text)
        let lower = chars.map(Cloze.lowercasedCharacter)
        // Terms grouped by first character, longest first.
        var byFirst: [Character: [(chars: [Character], wordId: String)]] = [:]
        for (term, wordId) in terms {
            let termChars = Array(term).map(Cloze.lowercasedCharacter)
            guard let first = termChars.first else { continue }
            byFirst[first, default: []].append((chars: termChars, wordId: wordId))
        }
        for key in Array(byFirst.keys) {
            byFirst[key]?.sort { a, b in
                a.chars.count != b.chars.count ? a.chars.count > b.chars.count : String(a.chars) < String(b.chars)
            }
        }
        var result: [ReadingToken] = []
        var plainStart = 0
        var index = 0
        while index < chars.count {
            let leftOK = index == 0 || !isLetterOrNumber(chars[index - 1])
            if leftOK, let candidates = byFirst[lower[index]] {
                var matched: (length: Int, wordId: String)?
                for candidate in candidates where TextScanning.matches(lower, at: index, candidate.chars) {
                    let end = index + candidate.chars.count
                    if end == chars.count || !isLetterOrNumber(chars[end]) {
                        matched = (length: candidate.chars.count, wordId: candidate.wordId)
                        break
                    }
                }
                if let matched {
                    if plainStart < index {
                        result.append(ReadingToken(text: String(chars[plainStart..<index])))
                    }
                    result.append(ReadingToken(text: String(chars[index..<(index + matched.length)]), wordId: matched.wordId))
                    index += matched.length
                    plainStart = index
                    continue
                }
            }
            index += 1
        }
        if plainStart < chars.count {
            result.append(ReadingToken(text: String(chars[plainStart..<chars.count])))
        }
        return result
    }
}
