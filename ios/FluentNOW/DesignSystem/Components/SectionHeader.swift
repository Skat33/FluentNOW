import SwiftUI

/// Nagłówek sekcji ekranu z opcjonalnym podtytułem i akcją („Zobacz wszystkie”).
///
/// ```swift
/// SectionHeader("Twoje kolekcje", subtitle: "3 w toku", actionTitle: "Wszystkie") { router.openLibrary(.collections) }
/// ```
struct SectionHeader: View {
    private let title: String
    private let subtitle: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    init(_ title: String, subtitle: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer(minLength: Spacing.xs)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(FluentFont.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: HitTarget.minimum)
            }
        }
    }
}

#Preview("Nagłówek sekcji") {
    VStack(spacing: Spacing.l) {
        SectionHeader("Twój tydzień")
        SectionHeader("Twoje kolekcje", subtitle: "3 w toku", actionTitle: "Wszystkie") {}
    }
    .padding(Spacing.screen)
    .background(Palette.background)
}
