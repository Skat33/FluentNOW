import SwiftUI
import FluentKit

// Wspólne widoki „Polecanych słówek” (Słownik → Polecane, linki z Dzisiaj i Postępów).
// FEEDBACK-5 J2: przeniesione z `Features/Today/TodayRecommendedWordsSection.swift`, gdy sekcja
// polecanych zniknęła z ekranu Dzisiaj.

/// Wiersz „zobacz więcej” z chevronem.
struct UsefulWordsMoreLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(FluentFont.bodyEmphasized)
                .foregroundStyle(Palette.accent)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: HitTarget.minimum)
        .contentShape(Rectangle())
    }
}

/// Przycisk „+” (dodanie jednym dotknięciem).
struct UsefulWordAddButton: View {
    let term: String
    let isAdding: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isAdding {
                    ProgressView()
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(.title2, design: .default, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
            }
            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAdding)
        .accessibilityLabel(Text("Dodaj „\(term)” do nauki"))
    }
}

/// Uzasadnienie polecenia; słowo, z którego rodziny pochodzi propozycja (H4), kursywą:
/// „Z rodziny słowa *decide*, które znasz · często używane”.
enum UsefulWordSummaryText {
    static func attributed(_ suggestion: UsefulWordSuggestion) -> AttributedString {
        let summary = suggestion.summaryPl
        var text = AttributedString(summary)
        guard let source = suggestion.familySource, !source.isEmpty else { return text }
        let marker = UsefulWordReason.wordFamilyPrefixPl + source
        guard let found = text.range(of: marker, options: [.caseInsensitive]) else { return text }
        let start = text.characters.index(found.upperBound, offsetBy: -source.count)
        text[start..<found.upperBound].inlinePresentationIntent = .emphasized
        return text
    }
}

/// Tekst wiersza: hasło + poziom, tłumaczenie, uzasadnienie (i opcjonalnie przykład).
struct UsefulWordText: View {
    let suggestion: UsefulWordSuggestion
    let detail: UsefulWordDetail?
    let showsExample: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(suggestion.candidate.term)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                LevelBadge(level: suggestion.candidate.level)
            }
            Text(suggestion.candidate.translation)
                .font(FluentFont.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !suggestion.summaryPl.isEmpty {
                Text(UsefulWordSummaryText.attributed(suggestion))
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.accentSoftInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsExample, let example = detail?.example {
                HighlightedText(example.en, focus: example.focusEn)
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
