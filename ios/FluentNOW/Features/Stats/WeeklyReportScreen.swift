import SwiftUI
import FluentKit

/// Trasy karty „Postępy” (I3). Rejestrowane w `StatsRootScreen` (`.statsNavigationDestinations()`).
/// Z innych kart: `router.popToRoot(.progress); router.push(StatsRoute.weeklyReport(weekOffset: 1), on: .progress)`.
enum StatsRoute: Hashable {
    /// 0 = bieżący tydzień, 1 = poprzedni, …
    case weeklyReport(weekOffset: Int)
}

extension View {
    /// Rejestruje cele nawigacji Postępów (raport tygodniowy) w bieżącym `NavigationStack`.
    func statsNavigationDestinations() -> some View {
        navigationDestination(for: StatsRoute.self) { (route: StatsRoute) in
            switch route {
            case .weeklyReport(let weekOffset):
                WeeklyReportScreen(initialOffset: weekOffset)
            }
        }
    }
}

/// Raport + zakres wyboru tygodnia — wynik `store.compute` (poza głównym wątkiem).
struct WeeklyReportPage: Hashable, Sendable {
    let report: WeeklyReport
    let availableWeeks: Int
}

private struct WeeklyReportKey: Hashable {
    let revision: Int
    let offset: Int
}

/// „Raport tygodniowy” (I3): tydzień poniedziałek–niedziela w strefie czasowej użytkownika,
/// porównanie z poprzednim tygodniem, wybór tygodnia wstecz (do 12).
struct WeeklyReportScreen: View {
    @Environment(LearningStore.self) private var store

    @State private var offset: Int
    @State private var page: WeeklyReportPage?

    init(initialOffset: Int = 0) {
        _offset = State(initialValue: max(0, initialOffset))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                WeeklyReportBody(page: page, offset: $offset, goal: store.settings.goal)
            }
            .frame(maxWidth: Spacing.readableWidth)
            .padding(Spacing.screen)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle("Raport tygodniowy")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: WeeklyReportKey(revision: store.revision, offset: offset)) { await refresh() }
    }

    private func refresh() async {
        let now: Timestamp = store.now()
        let calendar = Calendar.current
        let requested = offset
        let computed: WeeklyReportPage = await store.compute { (state: LearnerState) -> WeeklyReportPage in
            let weeks = WeeklyReportBuilder.availableWeeks(state, now: now, calendar: calendar)
            let report = WeeklyReportBuilder.report(state, weekOffset: requested, now: now, calendar: calendar)
            return WeeklyReportPage(report: report, availableWeeks: max(weeks, requested + 1))
        }
        guard !Task.isCancelled else { return }
        page = computed
    }
}

/// Stan ekranu: ładowanie albo treść (osobny widok — krótkie `body`).
private struct WeeklyReportBody: View {
    let page: WeeklyReportPage?
    @Binding var offset: Int
    let goal: Int

    var body: some View {
        if let page {
            WeeklyReportHeaderCard(report: page.report, offset: $offset, availableWeeks: page.availableWeeks)
            WeeklyReportContent(report: page.report, goal: goal)
        } else {
            LoadingStateView("Liczę raport…")
        }
    }
}

/// Treść raportu po wczytaniu.
private struct WeeklyReportContent: View {
    let report: WeeklyReport
    let goal: Int

    @Environment(AppRouter.self) private var router

    var body: some View {
        WeeklyReportNumbersGrid(report: report)
        TodayWeekCard(week: report.days, goal: goal)
        WeeklyReportSkillsCard(skills: report.skills)
        WeeklyReportHardWordsCard(words: report.hardestWords) {
            router.startStudy(.mistakes)
        }
        WeeklyReportFootnote()
    }
}

#Preview("Raport tygodniowy") {
    NavigationStack {
        WeeklyReportScreen()
    }
    .fluentPreviewEnvironment()
}
