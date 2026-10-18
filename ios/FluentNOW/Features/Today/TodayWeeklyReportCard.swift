import SwiftUI
import FluentKit

/// Karta „Raport tygodniowy” na Dzisiaj (I3): w niedzielę — bieżący tydzień, w poniedziałek —
/// zakończony tydzień; w inne dni nic nie rysuje (sprawdzenie dnia jest tanie i synchroniczne).
/// Samodzielna: raport liczony poza głównym wątkiem (`store.compute`) przy każdej zmianie stanu,
/// więc `TodaySnapshot` się nie zmienia.
struct TodayWeeklyReportCard: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        if let offset = WeeklyReportBuilder.todayCardWeekOffset(now: store.now(), calendar: Calendar.current) {
            TodayWeeklyReportLoader(offset: offset)
        }
    }
}

/// Zawsze rysuje kartę (szkielet do czasu wyliczenia), żeby `.task` na pewno wystartował.
private struct TodayWeeklyReportLoader: View {
    let offset: Int

    @Environment(LearningStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var report: WeeklyReport?

    var body: some View {
        content
            .task(id: TodayWeeklyReportKey(revision: store.revision, offset: offset)) { await refresh() }
    }

    @ViewBuilder
    private var content: some View {
        if let report {
            TodayWeeklyReportCardContent(report: report) {
                router.popToRoot(.progress)
                router.push(StatsRoute.weeklyReport(weekOffset: report.weekOffset), on: .progress)
            }
        } else {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Palette.surfaceMuted)
                .frame(height: 150)
                .accessibilityHidden(true)
        }
    }

    private func refresh() async {
        let now: Timestamp = store.now()
        let calendar = Calendar.current
        let requested = offset
        let computed: WeeklyReport = await store.compute { (state: LearnerState) -> WeeklyReport in
            WeeklyReportBuilder.report(state, weekOffset: requested, now: now, calendar: calendar)
        }
        guard !Task.isCancelled else { return }
        report = computed
    }
}

private struct TodayWeeklyReportKey: Hashable {
    let revision: Int
    let offset: Int
}

private struct TodayWeeklyReportCardContent: View {
    let report: WeeklyReport
    let onOpen: () -> Void

    var body: some View {
        Card(style: .tinted(.accent)) {
            SectionHeader(report.isCurrentWeek ? "Twój tydzień w skrócie" : "Raport z minionego tygodnia",
                          subtitle: WeeklyReportFormat.range(report))
            if report.current.hasActivity {
                TodayWeeklyReportNumbers(report: report)
            }
            Text(report.summaryPl)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton("Zobacz raport", systemImage: "chart.bar.doc.horizontal", action: onOpen)
        }
    }
}

private struct TodayWeeklyReportNumbers: View {
    let report: WeeklyReport

    var body: some View {
        HStack(spacing: Spacing.m) {
            TodayWeeklyReportNumber(value: "\(report.current.answers)", label: "odpowiedzi")
            TodayWeeklyReportNumber(value: WeeklyReportFormat.percent(report.current.accuracy), label: "poprawnych")
            TodayWeeklyReportNumber(value: "\(report.current.activeDays)/\(report.elapsedDays)", label: "dni nauki")
            TodayWeeklyReportNumber(value: "+\(report.current.xp)", label: "XP")
        }
    }
}

private struct TodayWeeklyReportNumber: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(FluentFont.numberSmall)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
