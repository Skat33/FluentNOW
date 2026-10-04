import SwiftUI

@main
struct FluentNOWApp: App {
    @State private var router = AppRouter()

    // AppEnvironment wstrzykuje platform-services
    // (np. `@State private var environment = AppEnvironment.live()` i `.environment(environment.store)`
    //  oraz `.preferredColorScheme(store.settings.appearance.colorScheme)` — patrz docs/DESIGN.md).

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(router)
                .onOpenURL { url in
                    _ = router.handle(url: url)
                }
        }
    }
}
