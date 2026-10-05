import SwiftUI
import FluentKit

/// Wiersz słownika: hasło, tłumaczenia, poziom, status i opanowanie.
struct WordRowView: View {
    let row: WordListRow

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(row.en)
                        .font(FluentFont.bodyEmphasized)
                        .foregroundStyle(Palette.ink)
                    if row.isImportant {
                        Image(systemName: "star.fill")
                            .font(FluentFont.caption)
                            .foregroundStyle(Palette.warning)
                            .accessibilityHidden(true)
                    }
                }
                if !row.translations.isEmpty {
                    Text(row.translations)
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(2)
                }
                WordStatusLabel(status: row.status)
            }
            Spacer(minLength: Spacing.xs)
            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                LevelBadge(level: row.level)
                if row.status != .new {
                    Text("\(row.mastery)%")
                        .font(FluentFont.numberSmall)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
        .padding(.vertical, Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Pokazuje szczegóły słowa"))
    }
}

/// Status słowa jako mała etykieta (ikona + tekst — kolor nie jest jedynym nośnikiem).
struct WordStatusLabel: View {
    let status: WordStatus

    var body: some View {
        Label(status.namePl, systemImage: Self.systemImage(status))
            .font(FluentFont.caption)
            .foregroundStyle(Self.tone(status).foreground)
            .labelStyle(.titleAndIcon)
    }

    static func systemImage(_ status: WordStatus) -> String {
        switch status {
        case .new: return "sparkle"
        case .learning: return "arrow.triangle.2.circlepath"
        case .hard: return "flame"
        case .mastered: return "checkmark.seal"
        case .needsRefresh: return "clock.arrow.circlepath"
        case .archived: return "archivebox"
        }
    }

    static func tone(_ status: WordStatus) -> ToneColors {
        switch status {
        case .new: return .accent
        case .learning: return .info
        case .hard: return .warning
        case .mastered: return .success
        case .needsRefresh: return .warning
        case .archived: return .neutral
        }
    }
}

#Preview("Wiersz słowa") {
    List {
        WordRowView(row: WordListRow(
            id: "1", en: "boarding pass", translations: "karta pokładowa", level: "A2",
            status: .learning, mastery: 42, meaningCount: 1, collection: "Lotnisko",
            isHard: false, isImportant: true, isArchived: false
        ))
        WordRowView(row: WordListRow(
            id: "2", en: "borrow", translations: "pożyczyć (od kogoś)", level: "A2",
            status: .new, mastery: 0, meaningCount: 1, collection: "Codzienne rozmowy",
            isHard: false, isImportant: false, isArchived: false
        ))
    }
}
