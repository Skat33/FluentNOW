import SwiftUI

/// Zdanie z pogrubionym wyrażeniem, którego się uczysz (`focusEn` / `focusPl`).
/// Dopasowanie bez rozróżniania wielkości liter i znaków diakrytycznych; pierwsze wystąpienie.
/// Brak dopasowania lub pusty `focus` → zwykły tekst (nigdy crash).
///
/// ```swift
/// HighlightedText(example.en, focus: example.focusEn)
///     .font(FluentFont.sentence)
/// HighlightedText(example.pl, focus: example.focusPl, highlight: Palette.accent)
/// ```
/// Czcionkę ustawiaj modyfikatorem `.font` — wyróżnienie dziedziczy rozmiar (Dynamic Type).
struct HighlightedText: View {
    private let text: String
    private let focus: String?
    private let highlight: Color?

    /// - Parameters:
    ///   - highlight: kolor wyróżnienia; `nil` = tylko pogrubienie w kolorze tekstu.
    init(_ text: String, focus: String?, highlight: Color? = Palette.accent) {
        self.text = text
        self.focus = focus
        self.highlight = highlight
    }

    var body: some View {
        Text(HighlightedText.attributed(text, focus: focus, highlight: highlight))
    }

    /// Podział zdania na część przed, wyróżnioną i po. `nil`, gdy nie ma czego wyróżnić.
    static func split(_ text: String, focus: String?) -> (before: String, match: String, after: String)? {
        guard let focus else { return nil }
        let needle = focus.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty, !text.isEmpty else { return nil }
        guard let range = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }
        return (
            before: String(text[text.startIndex..<range.lowerBound]),
            match: String(text[range]),
            after: String(text[range.upperBound..<text.endIndex])
        )
    }

    /// Tekst z atrybutami: wyróżnienie jako `stronglyEmphasized` (+ opcjonalny kolor).
    static func attributed(_ text: String, focus: String?, highlight: Color?) -> AttributedString {
        guard let parts = split(text, focus: focus) else {
            return AttributedString(text)
        }
        var result = AttributedString(parts.before)
        var emphasized = AttributedString(parts.match)
        emphasized.inlinePresentationIntent = .stronglyEmphasized
        if let highlight {
            // Jawny klucz atrybutu SwiftUI — bez niejednoznaczności z UIKit (`UIColor`).
            emphasized[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = highlight
        }
        result.append(emphasized)
        result.append(AttributedString(parts.after))
        return result
    }
}

#Preview("Wyróżnione wyrażenie") {
    VStack(alignment: .leading, spacing: Spacing.m) {
        HighlightedText("Could you lend me your pen for a minute?", focus: "lend me")
            .font(FluentFont.sentence)
        HighlightedText("Czy możesz pożyczyć mi długopis na chwilę?", focus: "pożyczyć mi")
            .font(FluentFont.body)
        HighlightedText("Brak dopasowania — zwykły tekst.", focus: "xyz")
        HighlightedText("Wielkość liter: Boarding Pass jest gotowy.", focus: "boarding pass", highlight: nil)
    }
    .padding(Spacing.screen)
    .background(Palette.background)
}
