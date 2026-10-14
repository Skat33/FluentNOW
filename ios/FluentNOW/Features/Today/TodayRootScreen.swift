import SwiftUI
import FluentKit

/// Korzeń karty „Dzisiaj”. Kontrakt powłoki: inicjalizator bez argumentów, bez własnego
/// `NavigationStack` (dostarcza go `RootView`), trasy przez `.navigationDestination(for:)`.
struct TodayRootScreen: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(AppRouter.self) private var router

    @State private var snapshot: TodaySnapshot?
    @State private var candidates: [Recommendation] = []
    @State private var onboardingInProgress = false

    private var showsOnboarding: Bool {
        guard store.loadPhase == .ready, !preferences.hasCompletedOnboarding else { return false }
        return store.state.words.isEmpty || onboardingInProgress
    }

    // `body` jest celowo krótki: łańcuch warunków i modyfikatory z domknięciami w jednym wyrażeniu
    // przekraczały limit czasu sprawdzania typów kompilatora („unable to type-check … in reasonable time”).
    var body: some View {
        ScrollView {
            scrollContent
        }
        .background(Palette.background)
        .navigationTitle("Dzisiaj")
        .toolbar { toolbarContent }
        .libraryNavigationDestinations()
        .task { await loadCandidates() }
        .task(id: refreshKey) { await refreshSnapshot() }
        .modifier(TodayGoalHaptic(isReached: snapshot?.goal.isReached, enabled: preferences.hapticsEnabled))
    }

    private var scrollContent: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            TodayStatusBanners()
            mainSection
        }
        .frame(maxWidth: Spacing.readableWidth)
        .padding(Spacing.screen)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var mainSection: some View {
        switch displayState {
        case .failed(let message):
            ErrorBanner(
                title: "Nie udało się wczytać danych",
                message: message + " Twoje dane nie zostały nadpisane."
            )
        case .loading:
            TodaySkeleton()
        case .onboarding:
            TodayOnboardingView(isAdding: $onboardingInProgress)
        case .content(let current):
            TodayContent(snapshot: current, isEmpty: store.state.words.isEmpty)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) { QuickAddButton() }
    }

    private var displayState: TodayDisplayState {
        if case .failed(let message) = store.loadPhase { return .failed(message) }
        if store.loadPhase == .loading { return .loading }
        if showsOnboarding { return .onboarding }
        if let snapshot { return .content(snapshot) }
        return .loading
    }

    private var refreshKey: TodayRefreshKey {
        TodayRefreshKey(revision: store.revision, candidateCount: candidates.count)
    }

    private func loadCandidates() async {
        let loaded: [Recommendation] = await env.content.recommendations()
        candidates = loaded
    }

    private func refreshSnapshot() async {
        let now: Timestamp = store.now()
        let pool: [Recommendation] = candidates
        let computed: TodaySnapshot = await store.compute { (state: LearnerState) -> TodaySnapshot in
            TodaySnapshot.make(state: state, candidates: pool, now: now)
        }
        guard !Task.isCancelled else { return }
        snapshot = computed
    }
}

private enum TodayDisplayState {
    case failed(String)
    case loading
    case onboarding
    case content(TodaySnapshot)
}

private struct TodayRefreshKey: Hashable {
    let revision: Int
    let candidateCount: Int
}

/// Haptyka „cel osiągnięty” — tylko przejście „nieosiągnięty → osiągnięty” w trakcie działania ekranu
/// (nie przy pierwszym wczytaniu migawki, gdy cel był osiągnięty już wcześniej: wtedy `old == nil`).
private struct TodayGoalHaptic: ViewModifier {
    let isReached: Bool?
    let enabled: Bool

    func body(content: Content) -> some View {
        content.sensoryFeedback(FluentHaptic.goalReached, trigger: isReached) { (old: Bool?, new: Bool?) -> Bool in
            enabled && old == false && new == true
        }
    }
}

/// Komunikaty o zapisie i trybie lokalnym (dane są bezpieczne — nie blokują ekranu).
private struct TodayStatusBanners: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        if let error = store.lastSaveError {
            ErrorBanner(
                title: "Nie udało się zapisać zmian",
                message: "\(error) Zmiany są w pamięci aplikacji. Możesz też wyeksportować kopię w Ustawieniach.",
                onRetry: { Task { await store.retryFailedSave() } }
            )
        }
    }
}

/// Właściwa treść ekranu (po wczytaniu).
private struct TodayContent: View {
    let snapshot: TodaySnapshot
    let isEmpty: Bool

    @Environment(AppRouter.self) private var router

    var body: some View {
        TodayHeroCard(goal: snapshot.goal, dueCount: snapshot.overview.dueMeanings,
                      newCount: snapshot.overview.newMeanings, resume: snapshot.resume)
        if isEmpty {
            EmptyStateView(
                systemImage: "text.book.closed",
                title: "Pierwsze słowo zaczyna historię",
                message: "Opisz sytuację, np. „w restauracji”, i dodaj jej słowa w kilka sekund — albo pojedyncze słowo przyciskiem +.",
                actionTitle: "Szukaj tematu"
            ) {
                router.presentTopicSearch()
            }
        } else {
            TodayStatsGrid(overview: snapshot.overview)
            TodayWeekCard(week: snapshot.week, goal: snapshot.goal.goal)
            TodayAnalysisCard(analysis: snapshot.analysis)
            TodayRecommendedWordsSection()
            TodayRecommendationsSection(recommendations: snapshot.recommendations)
            TodayCollectionsSection(collections: snapshot.collections)
            TodayRecentSection(rows: snapshot.recent)
        }
    }
}

/// Szkielet ładowania (bez blokującego spinnera).
private struct TodaySkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            RoundedRectangle(cornerRadius: Radius.hero, style: .continuous)
                .fill(Palette.surfaceMuted)
                .frame(height: 200)
            HStack(spacing: Spacing.s) {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.surfaceMuted).frame(height: 96)
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.surfaceMuted).frame(height: 96)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Wczytywanie"))
    }
}

#Preview("Dzisiaj") {
    NavigationStack {
        TodayRootScreen()
    }
    .fluentPreviewEnvironment()
}

#Preview("Dzisiaj — pierwsze uruchomienie") {
    NavigationStack {
        TodayRootScreen()
    }
    .fluentPreviewEnvironment(.previewEmpty)
}
