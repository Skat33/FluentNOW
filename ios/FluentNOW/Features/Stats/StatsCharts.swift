import SwiftUI
import Charts
import FluentKit

/// Kalendarz aktywności (12 tygodni) — heatmapa kolumn tygodni × dni.
struct StatsActivityCalendar: View {
    let days: [DayActivity]

    private var maxCount: Int { max(1, days.map { $0.count }.max() ?? 1) }
    private var activeDays: Int { days.filter { $0.count > 0 }.count }

    /// Dni pogrupowane po 7 (najstarsze najpierw).
    private var weeks: [[DayActivity]] {
        stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }
    }

    var body: some View {
        Card {
            SectionHeader("Kalendarz aktywności", subtitle: "Ostatnie 12 tygodni · aktywne dni: \(activeDays)")
            HStack(alignment: .top, spacing: 3) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 3) {
                        ForEach(week) { day in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(color(for: day.count))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            HStack(spacing: Spacing.xs) {
                Text("Mniej")
                ForEach(0..<4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color(level: level))
                        .frame(width: 12, height: 12)
                }
                Text("Więcej")
            }
            .font(FluentFont.caption)
            .foregroundStyle(Palette.inkSecondary)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Kalendarz aktywności: \(activeDays) aktywnych dni w ostatnich 12 tygodniach, najwięcej \(maxCount) odpowiedzi jednego dnia."))
    }

    private func color(for count: Int) -> Color {
        guard count > 0 else { return color(level: 0) }
        let ratio = Double(count) / Double(maxCount)
        if ratio > 0.66 { return color(level: 3) }
        if ratio > 0.33 { return color(level: 2) }
        return color(level: 1)
    }

    private func color(level: Int) -> Color {
        switch level {
        case 0: return Palette.surfaceMuted
        case 1: return Palette.accent.opacity(0.35)
        case 2: return Palette.accent.opacity(0.65)
        default: return Palette.accent
        }
    }
}

/// Tygodniowy przyrost opanowanych znaczeń (8 tygodni).
struct StatsGainsChart: View {
    let gains: [WeeklyGain]

    private var total: Int { gains.reduce(0) { $0 + $1.count } }

    var body: some View {
        Card {
            SectionHeader("Nowe opanowane znaczenia", subtitle: "Tygodniowo · razem \(total) w ciągu 8 tygodni")
            Chart(gains) { gain in
                BarMark(
                    x: .value("Tydzień", gain.start, unit: .weekOfYear),
                    y: .value("Opanowane", gain.count)
                )
                .foregroundStyle(Palette.success)
                .cornerRadius(4)
                .accessibilityLabel(Text("Tydzień od \(gain.start.formatted(date: .abbreviated, time: .omitted))"))
                .accessibilityValue(Text("\(gain.count) opanowanych"))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 140)
        }
    }
}

/// Prognoza powtórek na 7 dni (dzień 0 zawiera zaległe).
struct StatsForecastChart: View {
    let forecast: [ForecastDay]

    private var total: Int { forecast.reduce(0) { $0 + $1.count } }

    var body: some View {
        Card {
            SectionHeader("Prognoza powtórek", subtitle: "Najbliższe 7 dni · razem \(total)")
            Chart(forecast) { day in
                BarMark(
                    x: .value("Dzień", day.date, unit: .day),
                    y: .value("Powtórki", day.count)
                )
                .foregroundStyle(Palette.info)
                .cornerRadius(4)
                .accessibilityLabel(Text(day.date.formatted(.dateTime.weekday(.wide).day().month())))
                .accessibilityValue(Text("\(day.count) powtórek"))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 140)
        }
    }
}
