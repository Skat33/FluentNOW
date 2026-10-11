import SwiftUI

@main
struct FluentNOWApp: App {
    @State private var router = AppRouter()
    /// Wszystkie serwisy (platform-services): SwiftData + CloudKit z fallbackiem, mowa, przypomnienia, AI.
    @State private var environment = AppEnvironment.live()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppearanceRoot {
                RootView()
            }
            .environment(router)
            .fluentEnvironment(environment)
            .onOpenURL { url in
                _ = router.handle(url: url)
            }
            .task {
                // Dotknięcie przypomnienia → sesja nauki (także przy zimnym starcie — link czeka w serwisie).
                let router = router
                environment.reminders.onOpenURL = { url in
                    _ = router.handle(url: url)
                }
                await environment.onAppear()
            }
            .onChange(of: scenePhase) { _, phase in
                environment.onScenePhase(phase)
            }
        }
    }
}

/// Motyw z preferencji (`AppAppearance`: system/jasny/ciemny) nałożony na korzeń interfejsu.
/// Osobny widok, żeby zmiana motywu odświeżała tylko ten poziom (obserwacja `AppPreferences`).
private struct AppearanceRoot<Content: View>: View {
    @Environment(AppPreferences.self) private var preferences
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .preferredColorScheme(preferences.appearance.colorScheme)
            .environment(\.fluentHapticsEnabled, preferences.hapticsEnabled)
    }
}
