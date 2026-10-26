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
/// wygląd (kolory, grubość, marker dowodu; bez linków), `links` — te same znaki i grubość z linkami słów.
struct ReadingPassageLayout {
    let tokens: ReadingPassageTokens
    let attributed: [AttributedString]
    let links: [AttributedString]
    /// Rodzaje wyróżnień obecne w tekście, w kolejności legendy.
    let kinds: [ReadingHighlightStyle.Kind]

    init(tokens: ReadingPassageTokens) {
        self.tokens = tokens
        var built: [AttributedString] = []
        var linked: [AttributedString] = []
        var present: Set<ReadingHighlightStyle.Kind> = []
        for (index, paragraph) in tokens.paragraphs.enumerated() {
            let ranges = tokens.evidence.studyItem(at: index) ?? []
            built.append(ReadingHighlightStyle.attributed(tokens: paragraph, paragraph: index, evidence: ranges, glossary: tokens.glossary))
            linked.append(ReadingHighlightStyle.attributed(tokens: paragraph, paragraph: index, evidence: [], layer: .links, glossary: tokens.glossary))
            for token in paragraph {
                if let kind = ReadingHighlightStyle.kind(of: token, glossary: tokens.glossary) {
                    present.insert(kind)
                }
            }
        }
        attributed = built
        links = linked
        kinds = ReadingHighlightStyle.Kind.allCases.filter { (kind: ReadingHighlightStyle.Kind) -> Bool in
            present.contains(kind)
        }
    }

    var hasHighlights: Bool { !kinds.isEmpty }

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

/// Kolory wyróżnień (FEEDBACK-8 M1, M7) — role z `Palette`; kolor tekstu, bez teł (polecane:
/// zieleń + ciągłe podkreślenie).
/// Kontrast ≥ 4,5:1 (WCAG AA) w obu motywach, także na markerze dowodu (`Palette.warningSoft`).
enum ReadingHighlightColors {
    static let glossaryInk = Palette.readingGlossaryInk
    static let recommendedInk = Palette.readingRecommendedInk
    static let ownInk = Palette.readingOwnInk

    static func ink(for kind: ReadingHighlightStyle.Kind) -> Color {
        switch kind {
        case .glossary: return glossaryInk
        case .recommended: return recommendedInk
        case .own: return ownInk
        }
    }
}

/// Wygląd wyróżnień w tekście (FEEDBACK-8 M1, M7). Bez teł i bez linii przerywanych/kropkowanych
/// (nie przypominają podkreślenia błędów pisowni). Rozróżnienie nie tylko kolorem:
/// - słowo ze słowniczka (dotknij → tłumaczenie): przyciemniony akcent, grubość średnia;
/// - słowo polecane do nauki (słowniczek z odwołaniem `ref` do wpisu bazy — „Dodaj do nauki”
///   jednym dotknięciem z przykładami): **pogrubione**, zielone, z **ciągłym** podkreśleniem;
/// - słowo z mojego słownika: półgrube, ciepły pomarańczowy brąz;
/// - dowód (etap wyników): tło markera; kolor i grubość słowa zostają.
/// Legenda z próbkami jest nad tekstem (`ReadingHighlightLegend`). Powód dwóch warstw:
/// `piece`, `ReadingHighlightedText`.
enum ReadingHighlightStyle {
    /// Kolejność przypadków = kolejność w legendzie.
    enum Kind: Hashable, CaseIterable {
        case glossary
        case recommended
        case own
    }

    /// Warstwa akapitu: wygląd (bez linków) albo linki (te same znaki i grubość, bez kolorów).
    enum Layer: Hashable {
        case display
        case links
    }

    /// Rozmiar tekstu, dla którego budujemy krój (akapit czytanki albo próbka w legendzie).
    enum TextSize: Hashable {
        case passage
        case legend
    }

    static func kind(of token: ReadingToken, glossary: [ReadingGlossaryEntry]) -> Kind? {
        if token.wordId != nil { return .own }
        guard let index = token.glossaryIndex else { return nil }
        if let ref = glossary.studyItem(at: index)?.ref, !ref.isEmpty {
            return .recommended
        }
        return .glossary
    }

    // Kroje jako stałe: te same wartości w obu warstwach (identyczne łamanie wierszy).
    private static let passageGlossaryFont = Font.system(.body, design: .serif, weight: .medium)
    private static let passageRecommendedFont = Font.system(.body, design: .serif, weight: .bold)
    private static let passageOwnFont = Font.system(.body, design: .serif, weight: .semibold)
    private static let legendGlossaryFont = Font.system(.footnote, design: .serif, weight: .medium)
    private static let legendRecommendedFont = Font.system(.footnote, design: .serif, weight: .bold)
    private static let legendOwnFont = Font.system(.footnote, design: .serif, weight: .semibold)

    /// Krój wyróżnionego słowa (Dynamic Type — styl tekstowy, nie stały rozmiar).
    static func font(for kind: Kind, size: TextSize = .passage) -> Font {
        switch (kind, size) {
        case (.glossary, .passage): return passageGlossaryFont
        case (.recommended, .passage): return passageRecommendedFont
        case (.own, .passage): return passageOwnFont
        case (.glossary, .legend): return legendGlossaryFont
        case (.recommended, .legend): return legendRecommendedFont
        case (.own, .legend): return legendOwnFont
        }
    }

    static func attributed(
        tokens: [ReadingToken],
        paragraph: Int,
        evidence: [Range<Int>],
        layer: Layer = .display,
        glossary: [ReadingGlossaryEntry] = []
    ) -> AttributedString {
        var result = AttributedString()
        var offset = 0
        for (index, token) in tokens.enumerated() {
            let chars = Array(token.text)
            let start = offset
            let end = offset + chars.count
            offset = end
            let tokenKind: Kind? = ReadingHighlightStyle.kind(of: token, glossary: glossary)
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
    /// ignorowany, parametr zostaje dla zgodności), a kolory tekstu i marker rysują się zawsze.
    /// Linki są w osobnej, przezroczystej warstwie (`linkPiece`, `ReadingHighlightedText`).
    /// Bez tła słowa (FEEDBACK-8 M1); polecane — ciągłe podkreślenie w kolorze słowa (M7).
    /// Podkreślenie nie zmienia układu wierszy, więc warstwa linków go nie potrzebuje.
    static func piece(_ text: String, kind: Kind?, link: URL?, isEvidence: Bool, size: TextSize = .passage) -> AttributedString {
        var piece = AttributedString(text)
        if let kind {
            let ink: Color = ReadingHighlightColors.ink(for: kind)
            piece[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = font(for: kind, size: size)
            piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = ink
            if kind == .recommended {
                piece[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle(pattern: .solid, color: ink)
            }
        }
        if isEvidence {
            piece[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = Palette.warningSoft
        }
        return piece
    }

    /// Odcinek warstwy linków: te same znaki i ten sam krój co w warstwie wyglądu (identyczny
    /// układ wierszy), link słowa, bez kolorów.
    static func linkPiece(_ text: String, kind: Kind?, link: URL?) -> AttributedString {
        var piece = AttributedString(text)
        if let link {
            piece.link = link
        }
        if let kind {
            piece[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = font(for: kind)
        }
        return piece
    }

    /// Kolorowa próbka do legendy (krój legendy).
    static func sample(_ text: String, kind: Kind) -> AttributedString {
        piece(text, kind: kind, link: nil, isEvidence: false, size: .legend)
    }

    /// Słowo-próbka w legendzie.
    static func sampleWord(_ kind: Kind) -> String {
        switch kind {
        case .glossary: return "słowniczek"
        case .recommended: return "polecane"
        case .own: return "Twoje słowa"
        }
    }

    /// Opis rodzaju w legendzie (zgodny z `piece`).
    static func legendText(_ kind: Kind) -> String {
        switch kind {
        case .glossary:
            return "tłumaczenie w tym tekście"
        case .recommended:
            return "pogrubione, podkreślone — warte nauki"
        case .own:
            return "półgrube — z Twojego słownika"
        }
    }

    /// Opis próbki dla VoiceOver (kolor nie jest jedynym nośnikiem informacji).
    static func accessibilityText(_ kind: Kind) -> String {
        switch kind {
        case .glossary:
            return "Słowa ze słowniczka, fioletowe: tłumaczenie w tym tekście"
        case .recommended:
            return "Słowa polecane, pogrubione, zielone, podkreślone: warte nauki"
        case .own:
            return "Twoje słowa, półgrube, pomarańczowe: z Twojego słownika"
        }
    }
}

/// Akapit z podświetleniami w dwóch warstwach (FEEDBACK-6 K3):
/// - spód: `links` — te same znaki z linkami słów, przezroczyste (`tint` i tekst `.clear`);
///   obsługuje dotknięcia (`openURL` karty) i VoiceOver (rotor linków);
/// - wierzch: `display` — kolory, krój i marker dowodu bez linków (SwiftUI nie przemalowuje ich `tint`),
///   bez dotknięć i ukryty dla VoiceOver.
/// Obie warstwy mają tę samą czcionkę (z otoczenia i `ReadingHighlightStyle.font`), te same znaki, więc wiersze łamią
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
