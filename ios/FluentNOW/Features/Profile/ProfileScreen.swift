import SwiftUI
import FluentKit

/// Trasy wewnątrz panelu użytkownika.
enum ProfileRoute: Hashable {
    case avatar
    case learningProfile
}

/// Dane panelu liczone poza głównym wątkiem (`store.compute`).
struct ProfileSnapshot: Sendable, Equatable {
    var level: XPLevel
    var todayXP: Int
    var weekXP: Int
    var masteredMeanings: Int
    var studyDays: Int
    var wordCount: Int
    var streak: Int
    var achievements: [ProfileAchievement]

    static func make(state: LearnerState, now: Timestamp) -> ProfileSnapshot {
        let summary = Progression.summary(state, now: now)
        let overview = ProgressStatistics.overview(state, now: now)
        var input = ProfileAchievements.input(from: state)
        input.level = summary.level.level
        return ProfileSnapshot(
            level: summary.level,
            todayXP: summary.todayXP,
            weekXP: summary.weekXP,
            masteredMeanings: summary.masteredMeanings,
            studyDays: summary.studyDays,
            wordCount: overview.wordCount,
            streak: overview.streak,
            achievements: ProfileAchievements.evaluate(input)
        )
    }
}

/// Panel użytkownika (FEEDBACK-5 J3) — arkusz otwierany awatarem w nagłówku Dzisiaj:
/// awatar i nazwa, konto, poziom i ranga, statystyki skrótowe, odznaki, profil nauki,
/// Ustawienia, Wyloguj, Usuń konto. Własny `NavigationStack` (arkusz).
struct ProfileScreen: View {
    @Environment(LearningStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var path = NavigationPath()
    @State private var snapshot: ProfileSnapshot?

    var body: some View {
        NavigationStack(path: $path) {
            ProfileContent(snapshot: snapshot)
                .background(Palette.background.ignoresSafeArea())
                .navigationTitle("Profil")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Gotowe") { dismiss() }
                    }
                }
                .navigationDestination(for: ProfileRoute.self) { (route: ProfileRoute) in
                    ProfileDestination(route: route, level: snapshot?.level.level ?? 1)
                }
        }
        .task(id: store.revision) { await refresh() }
    }

    private func refresh() async {
        let now: Timestamp = store.now()
        let computed: ProfileSnapshot = await store.compute { (state: LearnerState) -> ProfileSnapshot in
            ProfileSnapshot.make(state: state, now: now)
        }
        guard !Task.isCancelled else { return }
        snapshot = computed
    }
}

private struct ProfileDestination: View {
    let route: ProfileRoute
    let level: Int

    var body: some View {
        switch route {
        case .avatar:
            AvatarPickerScreen(level: level)
        case .learningProfile:
            SettingsProfileScreen()
        }
    }
}

/// Treść panelu (przewijana kolumna kart).
private struct ProfileContent: View {
    let snapshot: ProfileSnapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                ProfileHeaderCard(level: snapshot?.level.level ?? 1)
                if let snapshot {
                    ProfileLevelCard(level: snapshot.level, todayXP: snapshot.todayXP)
                    ProfileStatsGrid(snapshot: snapshot)
                    ProfileBadgesSection(achievements: snapshot.achievements)
                } else {
                    LoadingStateView()
                        .frame(maxWidth: .infinity, minHeight: 160)
                }
                ProfileLinksSection()
                ProfileAccountSection()
            }
            .frame(maxWidth: Spacing.readableWidth)
            .padding(Spacing.screen)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview("Profil — gość") {
    ProfileScreen()
        .fluentPreviewEnvironment()
}

#Preview("Profil — zalogowany") {
    ProfileScreen()
        .environment(AuthController.inMemory(status: .signedIn(AuthSession(userID: "email:demo", provider: .email, email: "ania@example.com", displayName: "Ania"))))
        .fluentPreviewEnvironment()
}
