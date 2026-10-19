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
                // Logowanie (J3) → wywiad (G4, ekran Dzisiaj przy pustym słowniku) → aplikacja.
                AuthGate {
                    RootView()
                }
            }
            .environment(router)
            .fluentEnvironment(environment)
            .onOpenURL { url in
                _ = router.handle(url: url)
            }
            .task {
                // Sesja z pęku kluczy (ułamek sekundy) — przed wczytaniem danych nauki.
                await environment.auth.bootstrap(hasExistingInstall: environment.preferences.hasCompletedOnboarding)
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
