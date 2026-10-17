import SwiftUI
import FluentKit

/// Tokeny akapitów czytanki i zakresy dowodów — liczone poza głównym wątkiem (wynik `Sendable`).
struct ReadingPassageTokens: Sendable, Hashable {
    let paragraphs: [[ReadingToken]]
    /// Zakresy znaków fragmentów-dowodów w każdym akapicie.
    let evidence: [[Range<Int>]]
    let glossary: [ReadingGlossaryEntry]

    static func make(paragraphs: [String], words: [Word], glossary: [ReadingGlossaryEntry], evidence: [String]) -> ReadingPassageTokens {
        let tokens = paragraphs.map { (paragraph: String) -> [ReadingToken] in
            ReadingTokenizer.tokens(text: paragraph, words: words, glossary: glossary)
        }
        let ranges = paragraphs.map { (paragraph: String) -> [Range<Int>] in
            evidence.isEmpty ? [] : ReadingText.evidenceRanges(in: paragraph, evidence: evidence)
        }
        return ReadingPassageTokens(paragraphs: tokens, evidence: ranges, glossary: glossary)
    }
}

/// Gotowy do wyświetlenia tekst czytanki (budowany na głównym wątku z `ReadingPassageTokens`).
struct ReadingPassageLayout {
    let tokens: ReadingPassageTokens
    let attributed: [AttributedString]
    let hasOwnWords: Bool
    let hasUsefulWords: Bool

    init(tokens: ReadingPassageTokens) {
        self.tokens = tokens
        var built: [AttributedString] = []
        var own = false
        var useful = false
        for (index, paragraph) in tokens.paragraphs.enumerated() {
            let ranges = tokens.evidence.studyItem(at: index) ?? []
            built.append(ReadingHighlightStyle.attributed(tokens: paragraph, paragraph: index, evidence: ranges))
            for token in paragraph {
                if token.wordId != nil { own = true } else if token.glossaryIndex != nil { useful = true }
            }
        }
        attributed = built
        hasOwnWords = own
        hasUsefulWords = useful
    }

    var hasHighlights: Bool { hasOwnWords || hasUsefulWords }

    /// Dotknięte słowo: forma z tekstu, zdanie, pozycja słowniczka, id słowa z mojego słownika.
    func selection(paragraph: Int, token index: Int, paragraphs: [String]) -> ReadingTermSelection? {
        guard let tokens = self.tokens.paragraphs.studyItem(at: paragraph),
              let token = tokens.studyItem(at: index), token.isHighlighted,
              let text = paragraphs.studyItem(at: paragraph) else { return nil }
        let offset = ReadingText.offset(ofToken: index, in: tokens)
        let entry: ReadingGlossaryEntry?
        if let glossaryIndex = token.glossaryIndex {
            entry = self.tokens.glossary.studyItem(at: glossaryIndex)
        } else {
            entry = nil
        }
        return ReadingTermSelection(
            id: "\(paragraph):\(index)",
            surface: token.text,
            sentence: ReadingText.sentence(in: text, at: offset),
            entry: entry,
            wordID: token.wordId
        )
    }
}

/// Słowo wybrane w tekście (arkusz `ReadingWordSheet`).
struct ReadingTermSelection: Identifiable, Hashable {
    let id: String
    /// Forma dokładnie jak w tekście.
    let surface: String
    /// Zdanie z tekstu, w którym wystąpiło słowo.
    let sentence: String
    /// Pozycja słowniczka kontekstowego (tłumaczenie w tym tekście).
    let entry: ReadingGlossaryEntry?
    /// Słowo z mojego słownika, jeśli je mam.
    let wordID: String?
}

/// Link podświetlonego słowa: `fluentnow-reading://term/<akapit>/<token>` (obsługa lokalna `openURL`).
struct ReadingTermLink: Hashable {
    static let scheme = "fluentnow-reading"
    private static let prefix = "fluentnow-reading://term/"

    let paragraph: Int
    let token: Int

    init(paragraph: Int, token: Int) {
        self.paragraph = paragraph
        self.token = token
    }

    init?(url: URL) {
        let raw = url.absoluteString
        guard raw.hasPrefix(Self.prefix) else { return nil }
        let parts = raw.dropFirst(Self.prefix.count).split(separator: "/")
        guard parts.count == 2, let paragraph = Int(parts[0]), let token = Int(parts[1]),
              paragraph >= 0, token >= 0 else { return nil }
        self.paragraph = paragraph
        self.token = token
    }

    var url: URL? {
        URL(string: "\(Self.prefix)\(paragraph)/\(token)")
    }
}

/// Wygląd podświetleń w tekście. Rozróżnienie nie tylko kolorem: słowa z mojego słownika mają tło
/// i ciągłe podkreślenie, słowa przydatne — podkreślenie kropkowane; dowody — tło markera.
enum ReadingHighlightStyle {
    enum Kind: Hashable {
        case own
        case useful
    }

    static func kind(of token: ReadingToken) -> Kind? {
        if token.wordId != nil { return .own }
        if token.glossaryIndex != nil { return .useful }
        return nil
    }

    static func attributed(tokens: [ReadingToken], paragraph: Int, evidence: [Range<Int>]) -> AttributedString {
        var result = AttributedString()
        var offset = 0
        for (index, token) in tokens.enumerated() {
            let chars = Array(token.text)
            let start = offset
            let end = offset + chars.count
            offset = end
            let tokenKind: Kind? = ReadingHighlightStyle.kind(of: token)
            let link: URL? = tokenKind == nil ? nil : ReadingTermLink(paragraph: paragraph, token: index).url
            for segment in segments(start: start, end: end, evidence: evidence) {
                let text = String(chars[(segment.range.lowerBound - start)..<(segment.range.upperBound - start)])
                result.append(piece(text, kind: tokenKind, link: link, isEvidence: segment.isEvidence))
            }
        }
        return result
    }

    /// Podział zakresu tokenu na odcinki w dowodzie i poza nim.
    static func segments(start: Int, end: Int, evidence: [Range<Int>]) -> [(range: Range<Int>, isEvidence: Bool)] {
        guard start < end else { return [] }
        var cuts: Set<Int> = [start, end]
        for range in evidence where range.lowerBound < end && range.upperBound > start {
            cuts.insert(max(start, range.lowerBound))
            cuts.insert(min(end, range.upperBound))
        }
        let points = cuts.sorted()
        var result: [(range: Range<Int>, isEvidence: Bool)] = []
        for position in 0..<(points.count - 1) {
            let lower = points[position]
            let upper = points[position + 1]
            guard lower < upper else { continue }
            let inside = evidence.contains { (range: Range<Int>) -> Bool in
                range.lowerBound <= lower && upper <= range.upperBound
            }
            result.append((range: lower..<upper, isEvidence: inside))
        }
        return result
    }

    static func piece(_ text: String, kind: Kind?, link: URL?, isEvidence: Bool) -> AttributedString {
        var piece = AttributedString(text)
        if let link {
            piece.link = link
        }
        switch kind {
        case nil:
            break
        case .own:
            piece[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle.single
            piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Palette.accent
            if !isEvidence {
                piece[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = Palette.accentSoft
            }
        case .useful:
            piece[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle(pattern: .dot, color: Palette.accent)
            piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Palette.accentSoftInk
        }
        if isEvidence {
            piece[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = Palette.warningSoft
        }
        return piece
    }

    /// Próbka do legendy.
    static func sample(_ text: String, kind: Kind) -> AttributedString {
        piece(text, kind: kind, link: nil, isEvidence: false)
    }
}
