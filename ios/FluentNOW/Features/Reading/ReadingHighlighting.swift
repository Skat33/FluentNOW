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
/// Każdy akapit w dwóch warstwach (FEEDBACK-6 K3, `ReadingHighlightedText`): `attributed` —
/// wygląd (kolory, tła, linie; bez linków), `links` — te same znaki i grubość z linkami słów.
struct ReadingPassageLayout {
    let tokens: ReadingPassageTokens
    let attributed: [AttributedString]
    let links: [AttributedString]
    let hasOwnWords: Bool
    let hasUsefulWords: Bool

    init(tokens: ReadingPassageTokens) {
        self.tokens = tokens
        var built: [AttributedString] = []
        var linked: [AttributedString] = []
        var own = false
        var useful = false
        for (index, paragraph) in tokens.paragraphs.enumerated() {
            let ranges = tokens.evidence.studyItem(at: index) ?? []
            built.append(ReadingHighlightStyle.attributed(tokens: paragraph, paragraph: index, evidence: ranges))
            linked.append(ReadingHighlightStyle.attributed(tokens: paragraph, paragraph: index, evidence: [], layer: .links))
            for token in paragraph {
                if token.wordId != nil { own = true } else if token.glossaryIndex != nil { useful = true }
            }
        }
        attributed = built
        links = linked
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

/// Kolory podświetleń (FEEDBACK-6 K3). Pary tekst/tło ≥ 4,5:1 (WCAG AA) w obu motywach, także
/// na tle markera dowodu (`Palette.warningSoft`): słowo z mojego słownika 5,8 / 6,4 na swoim tle
/// (6,3 / 5,7 na markerze), słowo przydatne (teal) 5,6 / 7,3 (5,9 / 6,9 na markerze).
enum ReadingHighlightColors {
    /// Słowo z mojego słownika: fiolet na delikatnym fioletowym tle.
    static let ownInk = Palette.accentSoftInk
    static let ownFill = Palette.accentSoft
    /// Słowo przydatne (słowniczek): pogrubiony teal na delikatnym morskim tle.
    static let usefulInk = Palette.dynamic(light: 0x0B6870, dark: 0x7DD8D3)
    static let usefulFill = Palette.dynamic(light: 0xDDF2F1, dark: 0x173B3E)
}

/// Wygląd podświetleń w tekście (FEEDBACK-6 K3). Rozróżnienie nie tylko kolorem:
/// - słowo z mojego słownika: fioletowy tekst na fioletowym tle, zwykła grubość, ciągłe podkreślenie;
/// - słowo przydatne: **pogrubiony** teal na jasnym morskim tle, bez podkreślenia;
/// - dowód: tło markera zastępuje tło słowa; kolor, grubość i linia zostają.
/// Szczegóły i powód dwóch warstw: `piece`, `ReadingHighlightedText`.
enum ReadingHighlightStyle {
    enum Kind: Hashable {
        case own
        case useful
    }

    /// Warstwa akapitu: wygląd (bez linków) albo linki (te same znaki i grubość, bez kolorów).
    enum Layer: Hashable {
        case display
        case links
    }

    static func kind(of token: ReadingToken) -> Kind? {
        if token.wordId != nil { return .own }
        if token.glossaryIndex != nil { return .useful }
        return nil
    }

    static func attributed(tokens: [ReadingToken], paragraph: Int, evidence: [Range<Int>], layer: Layer = .display) -> AttributedString {
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
                switch layer {
                case .display:
                    result.append(piece(text, kind: tokenKind, link: nil, isEvidence: segment.isEvidence))
                case .links:
                    result.append(linkPiece(text, kind: tokenKind, link: link))
                }
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

    /// Odcinek warstwy wyglądu. SwiftUI `Text` rysuje odcinki-linki kolorem `tint` i pomija ich
    /// `ForegroundColorAttribute` (ui-tweaks) — dlatego ta warstwa **nie ma linków** (`link` jest
    /// ignorowany, parametr zostaje dla zgodności), a kolory tekstu, tła i linie rysują się zawsze.
    /// Linki są w osobnej, przezroczystej warstwie (`linkPiece`, `ReadingHighlightedText`).
    /// - mój słownik: `ReadingHighlightColors.ownInk` na `ownFill`, zwykła grubość, ciągłe podkreślenie;
    /// - przydatne: **pogrubiony** `usefulInk` (teal) na `usefulFill`, bez podkreślenia;
    /// - dowód: tło markera (`warningSoft`) zastępuje tło słowa; kolor, grubość i linia zostają.
    static func piece(_ text: String, kind: Kind?, link: URL?, isEvidence: Bool) -> AttributedString {
        var piece = AttributedString(text)
        switch kind {
        case nil:
            break
        case .own:
            piece[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle(pattern: .solid, color: ReadingHighlightColors.ownInk)
            piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = ReadingHighlightColors.ownInk
            piece[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = ReadingHighlightColors.ownFill
        case .useful:
            piece.inlinePresentationIntent = .stronglyEmphasized
            piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = ReadingHighlightColors.usefulInk
            piece[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = ReadingHighlightColors.usefulFill
        }
        if isEvidence {
            piece[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = Palette.warningSoft
        }
        return piece
    }

    /// Odcinek warstwy linków: te same znaki i ta sama grubość co w warstwie wyglądu (identyczny
    /// układ wierszy), link słowa, bez kolorów i teł.
    static func linkPiece(_ text: String, kind: Kind?, link: URL?) -> AttributedString {
        var piece = AttributedString(text)
        if let link {
            piece.link = link
        }
        if kind == .useful {
            piece.inlinePresentationIntent = .stronglyEmphasized
        }
        return piece
    }

    /// Próbka do legendy.
    static func sample(_ text: String, kind: Kind) -> AttributedString {
        piece(text, kind: kind, link: nil, isEvidence: false)
    }

    /// Opis rodzaju w legendzie (zgodny z `piece`).
    static func legendText(_ kind: Kind) -> String {
        switch kind {
        case .own:
            return "fioletowe na fioletowym tle, podkreślone — z Twojego słownika"
        case .useful:
            return "pogrubione, morskie na jasnym tle — warte nauki"
        }
    }
}

/// Akapit z podświetleniami w dwóch warstwach (FEEDBACK-6 K3):
/// - spód: `links` — te same znaki z linkami słów, przezroczyste (`tint` i tekst `.clear`);
///   obsługuje dotknięcia (`openURL` karty) i VoiceOver (rotor linków);
/// - wierzch: `display` — kolory, tła i linie bez linków (SwiftUI nie przemalowuje ich `tint`),
///   bez dotknięć i ukryty dla VoiceOver.
/// Obie warstwy mają tę samą czcionkę (z otoczenia), te same znaki i grubość, więc wiersze łamią
/// się identycznie.
struct ReadingHighlightedText: View {
    let display: AttributedString
    let links: AttributedString

    var body: some View {
        Text(links)
            .foregroundStyle(Color.clear)
            .tint(Color.clear)
            .contentShape(Rectangle())
            .overlay(alignment: .topLeading) {
                Text(display)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}
