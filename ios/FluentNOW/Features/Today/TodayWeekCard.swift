import SwiftUI
import Charts
import FluentKit

/// „Twój tydzień” — mini-histogram odpowiedzi z linią dziennego celu.
struct TodayWeekCard: View {
    let week: [DayActivity]
    let goal: Int

    private var total: Int { week.reduce(0) { $0 + $1.count } }
    private var activeDays: Int { week.filter { $0.count > 0 }.count }

    var body: some View {
        Card {
            SectionHeader("Twój tydzień", subtitle: "\(total) odpowiedzi · aktywne dni: \(activeDays) z \(week.count)")
            Chart {
                ForEach(week) { day in
                    BarMark(
                        x: .value("Dzień", day.date, unit: .day),
                        y: .value("Odpowiedzi", day.count)
                    )
                    .foregroundStyle(day.count >= goal ? Palette.success : Palette.accent)
                    .cornerRadius(4)
                    .accessibilityLabel(Text(day.date.formatted(.dateTime.weekday(.wide))))
                    .accessibilityValue(Text("\(day.count) odpowiedzi"))
                }
                if goal > 0 {
                    RuleMark(y: .value("Cel", goal))
                        .foregroundStyle(Palette.inkTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .accessibilityHidden(true)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 140)
        }
    }
}
