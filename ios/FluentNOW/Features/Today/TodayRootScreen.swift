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

    private var showsOnboarding: Bool {
        store.loadPhase == .ready && store.state.words.isEmpty && !preferences.hasCompletedOnboarding
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                TodayStatusBanners()
                if case .failed(let message) = store.loadPhase {
                    ErrorBanner(
                        title: "Nie udało się wczytać danych",
                        message: "\(message) Twoje dane nie zostały nadpisane."
                    )
                } else if store.loadPhase == .loading {
                    TodaySkeleton()
                } else if showsOnboarding {
                    TodayOnboardingView()
                } else if let snapshot {
                    TodayContent(snapshot: snapshot, isEmpty: store.state.words.isEmpty)
                } else {
                    TodaySkeleton()
                }
            }
            .frame(maxWidth: Spacing.readableWidth)
            .padding(Spacing.screen)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle("Dzisiaj")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { QuickAddButton() }
        }
        .libraryNavigationDestinations()
        .task {
            let loaded = await env.content.recommendations()
            candidates = loaded
        }
        .task(id: TodayRefreshKey(revision: store.revision, candidateCount: candidates.count)) {
            let now = store.now()
            let pool = candidates
            let computed = await store.compute { state in
                TodaySnapshot.make(state: state, candidates: pool, now: now)
            }
            guard !Task.isCancelled else { return }
            snapshot = computed
        }
        .sensoryFeedback(FluentHaptic.goalReached, trigger: snapshot?.goal.isReached ?? false) { old, new in
            !old && new
        }
    }
}

private struct TodayRefreshKey: Hashable {
    let revision: Int
    let candidateCount: Int
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
                message: "Dodaj cały temat w kilka sekund albo pojedyncze słowo przyciskiem +.",
                actionTitle: "Przeglądaj tematy"
            ) {
                router.openLibrary(.topics)
            }
        } else {
            TodayStatsGrid(overview: snapshot.overview)
            TodayWeekCard(week: snapshot.week, goal: snapshot.goal.goal)
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
