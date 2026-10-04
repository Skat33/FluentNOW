import SwiftUI

/// Karta treści: margines wewnętrzny + tło `fluentCardBackground`.
///
/// ```swift
/// Card {
///     SectionHeader("Twój tydzień")
///     WeekChart(...)
/// }
/// Card(style: .tinted(.accent)) { ... }
/// ```
struct Card<Content: View>: View {
    private let style: CardStyle
    private let padding: CGFloat
    private let spacing: CGFloat
    private let content: Content

    init(
        style: CardStyle = .solid,
        padding: CGFloat = Spacing.m,
        spacing: CGFloat = Spacing.s,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(padding)
        .fluentCardBackground(style)
    }
}

#Preview("Karta") {
    ScrollView {
        VStack(spacing: Spacing.m) {
            Card {
                Text("Lotnisko").font(FluentFont.title)
                Text("24 słowa · 8 opanowanych")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Card(style: .tinted(.accent)) {
                Text("Gotowość na krok dalej?").font(FluentFont.headline)
                Text("Opanowałeś „borrow”. Spróbuj „lend someone a hand”.")
                    .foregroundStyle(Palette.inkSecondary)
            }
            Card(style: .muted) {
                Text("Karta wyciszona")
            }
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
}
