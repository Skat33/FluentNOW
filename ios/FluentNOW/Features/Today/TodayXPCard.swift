import SwiftUI
import FluentKit

/// Pasek doświadczenia na Dzisiaj (G5): poziom, ranga, XP dziś i postęp do następnego poziomu.
/// Dotknięcie → szczegóły w Postępach.
struct TodayXPCard: View {
    let progression: ProgressionSummary

    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.select(.progress)
        } label: {
            Card {
                TodayXPHeadline(progression: progression)
                LinearProgressBar(progress: progression.level.fraction, height: 10)
                Text(XPText.nextLevel(progression.level))
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(XPText.accessibility(progression)))
        .accessibilityHint(Text("Otwiera szczegóły w Postępach"))
    }
}

private struct TodayXPHeadline: View {
    let progression: ProgressionSummary

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            XPLevelBadge(level: progression.level.level, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Poziom \(progression.level.level)")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                Text(progression.level.rank.namePl)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: Spacing.xs)
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(progression.todayXP) XP")
                    .font(FluentFont.numberSmall)
                    .foregroundStyle(progression.todayXP > 0 ? Palette.success : Palette.inkSecondary)
                    .contentTransition(.numericText())
                Text("dziś")
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

/// Okrągła odznaka z numerem poziomu (też w podsumowaniu sesji i w Postępach).
struct XPLevelBadge: View {
    let level: Int
    var size: CGFloat = 44

    var body: some View {
        Text("\(level)")
            .font(FluentFont.numberSmall)
            .foregroundStyle(Palette.onAccent)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(width: size, height: size)
            .background(Palette.accentFill, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Teksty XP (polska odmiana).
enum XPText {
    static func nextLevel(_ level: XPLevel) -> String {
        if level.isMaxLevel { return "Najwyższy poziom — gratulacje." }
        return "\(level.xpIntoLevel) / \(level.xpForLevel) XP · jeszcze \(level.xpToNextLevel) XP do poziomu \(level.level + 1)"
    }

    static func accessibility(_ progression: ProgressionSummary) -> String {
        "Poziom \(progression.level.level), \(progression.level.rank.namePl). Dziś \(progression.todayXP) XP. \(nextLevel(progression.level))"
    }

    static func gain(_ xp: Int) -> String {
        "+\(xp) XP"
    }
}
