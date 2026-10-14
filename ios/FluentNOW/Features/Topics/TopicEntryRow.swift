import SwiftUI
import FluentKit

/// Wiersz wpisu tematu: pole wyboru + hasło, tłumaczenie, poziom; przycisk podglądu.
/// Szkic AI (bez szczegółów) ma dopisek — szczegóły powstaną przy dodawaniu.
struct TopicEntryRow: View {
    let entry: TopicEntry
    let isSelected: Bool
    let isAdded: Bool
    let isDraft: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    private var detail: String {
        if isAdded { return "\(entry.translation) · już w słowniku" }
        if isDraft { return "\(entry.translation) · propozycja AI" }
        return entry.translation
    }

    var body: some View {
        HStack(spacing: Spacing.s) {
            Button(action: onToggle) {
                HStack(spacing: Spacing.s) {
                    TopicCheckmark(isSelected: isSelected, isAdded: isAdded)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.term)
                            .font(FluentFont.bodyEmphasized)
                            .foregroundStyle(Palette.ink)
                        Text(detail)
                            .font(FluentFont.subheadline)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    Spacer(minLength: Spacing.xs)
                    LevelBadge(level: entry.level)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(isAdded)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityHint(Text(isAdded ? "Już dodane do nauki" : "Zaznacz do dodania"))
            Button(action: onPreview) {
                Image(systemName: "info.circle")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.accent)
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Podgląd: \(entry.term)"))
        }
    }
}

private struct TopicCheckmark: View {
    let isSelected: Bool
    let isAdded: Bool

    private var symbol: String {
        if isAdded { return "checkmark.circle.fill" }
        return isSelected ? "checkmark.square.fill" : "square"
    }

    private var tint: Color {
        if isAdded { return Palette.success }
        return isSelected ? Palette.accent : Palette.inkSecondary
    }

    var body: some View {
        Image(systemName: symbol)
            .font(FluentFont.headline)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }
}
