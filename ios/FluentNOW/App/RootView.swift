import SwiftUI

/// Korzeń interfejsu: `TabView` z pięcioma kartami, każda z własnym `NavigationStack`
/// powiązanym ze ścieżką w `AppRouter`, oraz globalny arkusz (szybkie dodawanie).
///
/// - iOS 18+: nowe API `Tab(value:)` i styl `.sidebarAdaptable` (pasek boczny na iPadzie).
/// - iOS 26+: pasek kart chowa się przy przewijaniu w dół (`tabBarMinimizeBehavior(.onScrollDown)`).
/// - iOS 17: klasyczne `.tabItem` + `.tag`.
struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        Group {
            if #available(iOS 18.0, *) {
                ModernTabView(router: router)
            } else {
                LegacyTabView(router: router)
            }
        }
        .tint(Palette.accent)
        .sheet(item: $router.activeSheet) { sheet in
            AppSheetContent(sheet: sheet)
        }
    }
}

// MARK: - Karty (iOS 18+)

@available(iOS 18.0, *)
private struct ModernTabView: View {
    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab(value: AppTab.today) {
                TabNavigationStack(path: $router.todayPath) { TodayRootScreen() }
            } label: {
                TabLabel(tab: .today)
            }
            Tab(value: AppTab.words) {
                TabNavigationStack(path: $router.wordsPath) { WordsRootScreen() }
            } label: {
                TabLabel(tab: .words)
            }
            Tab(value: AppTab.study) {
                TabNavigationStack(path: $router.studyPath) { StudyRootScreen() }
            } label: {
                TabLabel(tab: .study)
            }
            Tab(value: AppTab.progress) {
                TabNavigationStack(path: $router.progressPath) { StatsRootScreen() }
            } label: {
                TabLabel(tab: .progress)
            }
            Tab(value: AppTab.settings) {
                TabNavigationStack(path: $router.settingsPath) { SettingsRootScreen() }
            } label: {
                TabLabel(tab: .settings)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // Modyfikator bezpośrednio na TabView (iOS 26 — chowanie paska przy przewijaniu).
        .modifier(TabBarMinimizeOnScroll())
    }
}

// MARK: - Karty (iOS 17)

private struct LegacyTabView: View {
    @Bindable var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            TabNavigationStack(path: $router.todayPath) { TodayRootScreen() }
                .tabItem { TabLabel(tab: .today) }
                .tag(AppTab.today)
            TabNavigationStack(path: $router.wordsPath) { WordsRootScreen() }
                .tabItem { TabLabel(tab: .words) }
                .tag(AppTab.words)
            TabNavigationStack(path: $router.studyPath) { StudyRootScreen() }
                .tabItem { TabLabel(tab: .study) }
                .tag(AppTab.study)
            TabNavigationStack(path: $router.progressPath) { StatsRootScreen() }
                .tabItem { TabLabel(tab: .progress) }
                .tag(AppTab.progress)
            TabNavigationStack(path: $router.settingsPath) { SettingsRootScreen() }
                .tabItem { TabLabel(tab: .settings) }
                .tag(AppTab.settings)
        }
    }
}

// MARK: - Elementy wspólne

private struct TabLabel: View {
    let tab: AppTab

    var body: some View {
        Label(tab.title, systemImage: tab.systemImage)
    }
}

/// `NavigationStack` karty powiązany ze ścieżką routera; tło ekranu z palety.
private struct TabNavigationStack<Root: View>: View {
    @Binding var path: NavigationPath
    private let root: Root

    init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) {
        self._path = path
        self.root = root()
    }

    var body: some View {
        NavigationStack(path: $path) {
            root
                .background(Palette.background.ignoresSafeArea())
        }
    }
}

/// iOS 26: pasek kart minimalizuje się przy przewijaniu w dół (więcej miejsca na treść).
private struct TabBarMinimizeOnScroll: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
    }
}

/// Treść arkuszy globalnych.
private struct AppSheetContent: View {
    let sheet: AppSheet

    var body: some View {
        switch sheet {
        case .quickAdd(let prefill):
            AddWordRootScreen(prefill: prefill)
        case .topicSearch(let query, let topicID):
            AddWordRootScreen(prefill: query, mode: .topic, topicID: topicID)
        case .profile:
            ProfileScreen()
        }
    }
}

#Preview("Aplikacja") {
    RootView()
        .fluentPreviewEnvironment(.preview, router: AppRouter())
}

#Preview("Aplikacja — ciemny") {
    RootView()
        .fluentPreviewEnvironment(.preview, router: AppRouter(selectedTab: .words))
        .preferredColorScheme(.dark)
}
