import SwiftUI
import Charts
import FluentKit

/// Doświadczenie w Postępach (G5): poziom i ranga z opisem, postęp do następnego poziomu,
/// XP z 14 dni, skąd pochodzą punkty i jak je zdobywać.
struct StatsProgressionSection: View {
    let progression: ProgressionSummary

    var body: some View {
        StatsLevelCard(progression: progression)
        StatsXPChart(days: progression.recentDays, weekXP: progression.weekXP)
        StatsXPSourcesCard(sources: progression.sources, total: progression.level.totalXP)
    }
}

private struct StatsLevelCard: View {
    let progression: ProgressionSummary

    private var level: XPLevel { progression.level }

    var body: some View {
        Card {
            SectionHeader("Doświadczenie", subtitle: "Liczone z historii odpowiedzi — nic się nie zgubi przy synchronizacji.")
            HStack(alignment: .center, spacing: Spacing.m) {
                XPLevelBadge(level: level.level, size: 64)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Label(level.rank.namePl, systemImage: level.rank.systemImage)
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.ink)
                    Text("Poziom \(level.level) · \(level.totalXP) XP")
                        .font(FluentFont.numberSmall)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            LinearProgressBar(progress: level.fraction, height: 10)
            Text(XPText.nextLevel(level))
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(level.rank.descriptionPl) \(progression.meaningPl)")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let next = level.rank.next {
                Text("Następna ranga: „\(next.namePl)” od poziomu \(next.firstLevel).")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

/// XP z ostatnich 14 dni.
private struct StatsXPChart: View {
    let days: [XPDay]
    let weekXP: Int

    var body: some View {
        Card {
            SectionHeader("XP z ostatnich dni", subtitle: "Ostatnie 7 dni: \(weekXP) XP")
            Chart(days) { (item: XPDay) in
                BarMark(
                    x: .value("Dzień", item.date, unit: .day),
                    y: .value("XP", item.total)
                )
                .foregroundStyle(Palette.accent)
                .cornerRadius(4)
                .accessibilityLabel(Text(item.date.formatted(.dateTime.weekday(.wide).day().month())))
                .accessibilityValue(Text("\(item.total) XP"))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 140)
        }
    }
}

/// Skąd pochodzą punkty + krótkie zasady.
private struct StatsXPSourcesCard: View {
    let sources: [XPSourceTotal]
    let total: Int

    var body: some View {
        Card {
            SectionHeader("Skąd punkty")
            ForEach(sources) { (item: XPSourceTotal) in
                HStack(spacing: Spacing.s) {
                    Label(item.source.namePl, systemImage: item.source.systemImage)
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: Spacing.xs)
                    Text("\(item.xp) XP")
                        .font(FluentFont.numberSmall)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .accessibilityElement(children: .combine)
            }
            Text(StatsXPText.rules)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

enum StatsXPText {
    static let rules = "Za poprawną odpowiedź: 4 XP za rozpoznanie, 7–8 XP za wpisanie słowa, dyktando lub lukę; połowa z podpowiedzią, 0 za błąd. Kolejne powtórki tego samego słowa w ciągu dnia dają coraz mniej. Premie: dzienny cel +20 XP, seria do +15 XP dziennie, ukończona czytanka i zestaw gramatyki."
}
