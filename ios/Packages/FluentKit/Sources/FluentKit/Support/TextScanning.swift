import Foundation

/// Small, allocation-light string helpers that replace the web app's regular expressions.
/// Everything here works on `Character` arrays so it is Unicode-safe ("\r\n" is one Character).
enum TextScanning {
    /// JS `\w` (ASCII letters, digits, underscore).
    @inline(__always)
    static func isWordChar(_ c: Character) -> Bool {
        guard c.isASCII else { return false }
        return c.isLetter || c.isNumber || c == "_"
    }

    /// JS `[A-Za-z]`.
    @inline(__always)
    static func isASCIILetter(_ c: Character) -> Bool {
        c.isASCII && c.isLetter
    }

    /// JS `\b` at position `index` of `chars`.
    static func isWordBoundary(_ chars: [Character], at index: Int) -> Bool {
        let before = index > 0 && index - 1 < chars.count ? isWordChar(chars[index - 1]) : false
        let after = index >= 0 && index < chars.count ? isWordChar(chars[index]) : false
        return before != after
    }

    /// `true` when `token` occurs in `chars` at `index` (exact, case-sensitive).
    static func matches(_ chars: [Character], at index: Int, _ token: [Character]) -> Bool {
        guard index >= 0, index + token.count <= chars.count else { return false }
        var offset = 0
        while offset < token.count {
            if chars[index + offset] != token[offset] { return false }
            offset += 1
        }
        return true
    }

    /// Port of `text.replace(/\btoken\b/g, replacement)` (or without the leading `\b`).
    /// The trailing `\b` is always required.
    static func replaceToken(_ text: String, _ token: String, with replacement: String, leftBoundary: Bool) -> String {
        let chars = Array(text)
        let tokenChars = Array(token)
        guard !tokenChars.isEmpty, chars.count >= tokenChars.count else { return text }
        let replacementChars = Array(replacement)
        var out: [Character] = []
        out.reserveCapacity(chars.count + 8)
        var index = 0
        var changed = false
        while index < chars.count {
            if matches(chars, at: index, tokenChars),
               (!leftBoundary || isWordBoundary(chars, at: index)),
               isWordBoundary(chars, at: index + tokenChars.count) {
                out.append(contentsOf: replacementChars)
                index += tokenChars.count
                changed = true
            } else {
                out.append(chars[index])
                index += 1
            }
        }
        return changed ? String(out) : text
    }

    /// Port of `.replace(/\s+/g, " ")` — collapses every whitespace run to one space (no trimming).
    static func collapseWhitespace(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.utf8.count)
        var inWhitespace = false
        for c in text {
            if c.isWhitespace {
                if !inWhitespace { out.append(" ") }
                inWhitespace = true
            } else {
                out.append(c)
                inWhitespace = false
            }
        }
        return out
    }

    /// Trims whitespace and newlines on both ends (JS `trim()`).
    static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Removes every character contained in `set`.
    static func removing(_ set: Set<Character>, from text: String) -> String {
        String(text.filter { !set.contains($0) })
    }

    /// Removes a trailing run of characters contained in `set`.
    static func removingTrailing(_ set: Set<Character>, from text: String) -> String {
        var chars = Array(text)
        while let last = chars.last, set.contains(last) {
            chars.removeLast()
        }
        return String(chars)
    }

    /// Lowercases, decomposes and removes combining marks U+0300–U+036F, maps `ł` → `l`.
    /// Port of `.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'').replace(/ł/g,'l')`.
    static func foldPolish(_ text: String) -> String {
        let decomposed = text.lowercased().decomposedStringWithCanonicalMapping
        var scalars = String.UnicodeScalarView()
        for scalar in decomposed.unicodeScalars {
            if scalar.value >= 0x300 && scalar.value <= 0x36F { continue }
            if scalar == "ł" {
                scalars.append("l")
            } else {
                scalars.append(scalar)
            }
        }
        return String(scalars)
    }

    /// Replaces typographic apostrophes `’` and `‘` with `'`.
    static func straightenApostrophes(_ text: String) -> String {
        guard text.contains("\u{2019}") || text.contains("\u{2018}") else { return text }
        var out = ""
        out.reserveCapacity(text.utf8.count)
        for c in text {
            if c == "\u{2019}" || c == "\u{2018}" {
                out.append("'")
            } else {
                out.append(c)
            }
        }
        return out
    }
}
