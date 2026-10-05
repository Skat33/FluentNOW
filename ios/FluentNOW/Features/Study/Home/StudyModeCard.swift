import SwiftUI
import FluentKit

/// Kafelek rodzaju ćwiczeń (wielokrotny wybór).
struct StudyModeCard: View {
    let mode: StudyMode
    let isSelected: Bool
    /// Powód niedostępności (np. brak słów) — kafelek wyłączony.
    let disabledReason: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .top) {
                    Image(systemName: mode.studySystemImage)
                        .font(FluentFont.title)
                        .foregroundStyle(disabledReason == nil ? Palette.accent : Palette.inkSecondary)
                        .accessibilityHidden(true)
                    Spacer(minLength: Spacing.xs)
                    StudySelectionIndicator(isSelected: isSelected)
                }
                Text(mode.namePl)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(disabledReason ?? mode.studyDescription)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.leading)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(Spacing.m)
            .background(isSelected ? Palette.accentSoft : Palette.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(isSelected ? Palette.accent : Palette.separator, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .opacity(disabledReason == nil ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(disabledReason != nil)
        .sensoryFeedback(FluentHaptic.selection, trigger: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(mode.namePl))
        .accessibilityValue(Text(isSelected ? "Zaznaczono" : ""))
        .accessibilityHint(Text(disabledReason ?? mode.studyDescription))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Okrągły wskaźnik zaznaczenia.
private struct StudySelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? Palette.accent : Palette.separator, lineWidth: 1.5)
                .background(Circle().fill(isSelected ? Palette.accentFill : Color.clear))
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.onAccent)
            }
        }
        .frame(width: 22, height: 22)
        .accessibilityHidden(true)
    }
}

#Preview("Kafelki trybów") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
        StudyModeCard(mode: .mixed, isSelected: true, disabledReason: nil) {}
        StudyModeCard(mode: .pairs, isSelected: false, disabledReason: "Najpierw dodaj kilka słów.") {}
        StudyModeCard(mode: .reading, isSelected: false, disabledReason: nil) {}
    }
    .padding(Spacing.screen)
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
