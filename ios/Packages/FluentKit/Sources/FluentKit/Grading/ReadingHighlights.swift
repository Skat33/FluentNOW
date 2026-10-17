import Foundation

/// What a highlighted span of a passage points to.
private struct ReadingHighlightTarget {
    var wordId: String?
    var glossaryIndex: Int?
}

extension ReadingTokenizer {
    /// Highlights saved words **and** the reading's glossary entries (FEEDBACK-2 G1).
    /// The longest match wins and a match never starts or ends inside a word. A glossary match
    /// whose lemma is a saved word (e.g. "booked" → "book") also carries that word's id.
    /// Archived words are ignored. Joined token texts equal `text`.
    public static func tokens(text: String, words: [Word], glossary: [ReadingGlossaryEntry]) -> [ReadingToken] {
        var targets: [String: ReadingHighlightTarget] = [:]
        var wordByTerm: [String: String] = [:]
        for word in words where !word.archived {
            let headword = TextScanning.trim(word.en).lowercased()
            if !headword.isEmpty && wordByTerm[headword] == nil {
                wordByTerm[headword] = word.id
            }
            var candidates = [word.en]
            for meaning in word.meanings {
                candidates.append(contentsOf: meaning.exampleFocusEn ?? [])
            }
            for term in candidates {
                let key = TextScanning.trim(term).lowercased()
                guard !key.isEmpty, key.count <= 120 else { continue }
                var target = targets[key] ?? ReadingHighlightTarget()
                if target.wordId == nil {
                    target.wordId = word.id
                }
                targets[key] = target
            }
        }
        for (index, entry) in glossary.enumerated() {
            let key = TextScanning.trim(entry.form).lowercased()
            guard !key.isEmpty, key.count <= 120 else { continue }
            var target = targets[key] ?? ReadingHighlightTarget()
            if target.glossaryIndex == nil {
                target.glossaryIndex = index
            }
            if target.wordId == nil {
                target.wordId = wordByTerm[TextScanning.trim(entry.lemma).lowercased()]
            }
            targets[key] = target
        }
        return scan(text, targets: targets)
    }

    private static func isTermCharacter(_ c: Character) -> Bool {
        c.isLetter || c.isNumber
    }

    private static func scan(_ text: String, targets: [String: ReadingHighlightTarget]) -> [ReadingToken] {
        guard !targets.isEmpty else { return [ReadingToken(text: text)] }
        let chars = Array(text)
        let lower = chars.map(Cloze.lowercasedCharacter)
        var byFirst: [Character: [(chars: [Character], target: ReadingHighlightTarget)]] = [:]
        for (term, target) in targets {
            let termChars = Array(term).map(Cloze.lowercasedCharacter)
            guard let first = termChars.first else { continue }
            byFirst[first, default: []].append((chars: termChars, target: target))
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
            let leftOK = index == 0 || !isTermCharacter(chars[index - 1])
            if leftOK, let candidates = byFirst[lower[index]] {
                var matched: (length: Int, target: ReadingHighlightTarget)?
                for candidate in candidates where TextScanning.matches(lower, at: index, candidate.chars) {
                    let end = index + candidate.chars.count
                    if end == chars.count || !isTermCharacter(chars[end]) {
                        matched = (length: candidate.chars.count, target: candidate.target)
                        break
                    }
                }
                if let matched {
                    if plainStart < index {
                        result.append(ReadingToken(text: String(chars[plainStart..<index])))
                    }
                    let end = index + matched.length
                    result.append(ReadingToken(
                        text: String(chars[index..<end]),
                        wordId: matched.target.wordId,
                        glossaryIndex: matched.target.glossaryIndex
                    ))
                    index = end
                    plainStart = end
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

/// Text helpers for the reading screens: the sentence around a tapped word and the evidence
/// fragments to highlight after the questions.
public enum ReadingText {
    private static let terminators: Set<Character> = [".", "!", "?", "…"]

    /// Character offset where token `tokenIndex` starts (sum of the previous token lengths).
    public static func offset(ofToken tokenIndex: Int, in tokens: [ReadingToken]) -> Int {
        guard tokenIndex > 0 else { return 0 }
        return tokens.prefix(tokenIndex).reduce(0) { total, token in total + token.text.count }
    }

    /// The sentence of `paragraph` containing the character at `offset` (clamped to the text).
    /// A sentence ends with `. ! ? …` followed by whitespace or the end of the paragraph.
    public static func sentence(in paragraph: String, at offset: Int) -> String {
        let chars = Array(paragraph)
        guard !chars.isEmpty else { return "" }
        let position = min(max(0, offset), chars.count - 1)
        var start = position
        while start > 0 {
            if chars[start - 1].isWhitespace, start >= 2, terminators.contains(chars[start - 2]) {
                break
            }
            start -= 1
        }
        var end = position
        while end < chars.count {
            let isLast = end + 1 == chars.count
            if terminators.contains(chars[end]), isLast || chars[end + 1].isWhitespace {
                end += 1
                break
            }
            end += 1
        }
        return TextScanning.trim(String(chars[start..<end]))
    }

    /// Character ranges of the evidence fragments in `paragraph`, merged and sorted. A fragment
    /// may be split by "…" or "..."; it is found exactly first, then ignoring case. Parts shorter
    /// than 3 characters are ignored.
    public static func evidenceRanges(in paragraph: String, evidence: [String]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        for item in evidence {
            for part in fragments(of: item) {
                guard let found = paragraph.range(of: part) ?? paragraph.range(of: part, options: [.caseInsensitive, .diacriticInsensitive]) else {
                    continue
                }
                let lower = paragraph.distance(from: paragraph.startIndex, to: found.lowerBound)
                let upper = paragraph.distance(from: paragraph.startIndex, to: found.upperBound)
                if lower < upper {
                    ranges.append(lower..<upper)
                }
            }
        }
        return merged(ranges)
    }

    static func fragments(of evidence: String) -> [String] {
        let unified = evidence.replacingOccurrences(of: "...", with: "…")
        let edge: Set<Character> = [".", ",", ";", ":", "!", "?", "\"", "“", "”", "„", "'", "‘", "’", " "]
        return unified.split(separator: "…").compactMap { piece -> String? in
            var chars = Array(TextScanning.trim(String(piece)))
            while let last = chars.last, edge.contains(last) { chars.removeLast() }
            while let first = chars.first, edge.contains(first) { chars.removeFirst() }
            return chars.count >= 3 ? String(chars) : nil
        }
    }

    static func merged(_ ranges: [Range<Int>]) -> [Range<Int>] {
        let sorted = ranges.sorted { $0.lowerBound < $1.lowerBound }
        var result: [Range<Int>] = []
        for range in sorted {
            if let last = result.last, range.lowerBound <= last.upperBound {
                result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                result.append(range)
            }
        }
        return result
    }
}

/// Which of my meanings fits a word met in a passage.
public struct ReadingMeaningChoice: Sendable, Hashable {
    /// Best meaning, or `nil` when it cannot be told (show all meanings).
    public var meaningId: String?
    /// `false` = a guess; the UI says it is uncertain and shows the other meanings too.
    public var isConfident: Bool

    public init(meaningId: String?, isConfident: Bool) {
        self.meaningId = meaningId
        self.isConfident = isConfident
    }
}

/// Picks the meaning of a saved word that fits the passage (FEEDBACK-2 G1).
/// With a glossary entry: the meaning with the same content reference or the same translation.
/// Without one: the meaning whose example sentences share the most content words with the
/// sentence of the passage; ties or no overlap → no choice (all meanings shown as uncertain).
public enum ReadingMeaningMatcher {
    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "was", "were", "are", "have", "has", "had", "you", "your",
        "his", "her", "hers", "their", "they", "she", "him", "them", "our", "its", "not", "but", "from", "into",
        "about", "then", "than", "there", "here", "what", "when", "which", "who", "whom", "will", "would", "can",
        "could", "should", "been", "being", "did", "does", "just", "very", "also", "some", "any", "all", "one",
        "two", "more", "most", "other", "out", "off", "over", "after", "before", "because", "while", "where",
        "how", "why", "too", "only", "each", "every", "much", "many", "such", "own", "same", "may", "might",
        "must", "shall", "these", "those", "yet", "still", "even", "now",
    ]

    public static func choose(word: Word, sentence: String, entry: ReadingGlossaryEntry?) -> ReadingMeaningChoice {
        let meanings = word.meanings
        guard let first = meanings.first else {
            return ReadingMeaningChoice(meaningId: nil, isConfident: false)
        }
        if let entry {
            if let ref = entry.ref, let match = meanings.first(where: { $0.contentRef == ref }) {
                return ReadingMeaningChoice(meaningId: match.id, isConfident: true)
            }
            let glossKeys = translationKeys(entry.translation)
            if let match = meanings.first(where: { !translationKeys($0.translation).isDisjoint(with: glossKeys) }) {
                return ReadingMeaningChoice(meaningId: match.id, isConfident: true)
            }
            return ReadingMeaningChoice(meaningId: nil, isConfident: false)
        }
        if meanings.count == 1 {
            return ReadingMeaningChoice(meaningId: first.id, isConfident: true)
        }
        let own = contentWords(word.en, excluding: [])
        let sentenceWords = contentWords(sentence, excluding: own)
        var scored: [(id: String, score: Int)] = []
        for meaning in meanings {
            var bag = Set<String>()
            for example in meaning.examples {
                bag.formUnion(contentWords(example, excluding: own))
            }
            scored.append((id: meaning.id, score: bag.intersection(sentenceWords).count))
        }
        let ranked = scored.stableSorted { $0.score > $1.score }
        guard let best = ranked.first, best.score > 0 else {
            return ReadingMeaningChoice(meaningId: nil, isConfident: false)
        }
        let second = ranked.count > 1 ? ranked[1].score : 0
        guard best.score > second else {
            return ReadingMeaningChoice(meaningId: nil, isConfident: false)
        }
        return ReadingMeaningChoice(meaningId: best.id, isConfident: best.score >= 2)
    }

    /// Normalized parts of a Polish translation split at `, ; / ( )`.
    static func translationKeys(_ translation: String) -> Set<String> {
        let separators: Set<Character> = [",", ";", "/", "(", ")"]
        var keys = Set<String>()
        for part in translation.split(whereSeparator: { separators.contains($0) }) {
            let key = TextNormalizer.normalize(String(part))
            if !key.isEmpty { keys.insert(key) }
        }
        return keys
    }

    /// Lowercased English content words (≥ 3 letters, no stop words, plural `-s` dropped).
    static func contentWords(_ text: String, excluding: Set<String>) -> Set<String> {
        var result = Set<String>()
        for raw in text.lowercased().split(whereSeparator: { !($0.isLetter || $0 == "'") }) {
            var token = String(raw).trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            if token.hasSuffix("'s") { token = String(token.dropLast(2)) }
            if token.count > 4 && token.hasSuffix("s") && !token.hasSuffix("ss") { token = String(token.dropLast()) }
            guard token.count >= 3, !stopWords.contains(token), !excluding.contains(token) else { continue }
            result.insert(token)
        }
        return result
    }
}
