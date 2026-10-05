import SwiftUI

/// Korzeń karty „Nauka”. Kontrakt powłoki: inicjalizator bez argumentów, bez własnego
/// `NavigationStack`. Ekran konsumuje `router.consumeStudyLaunch()` (deep link / „Zaczynam naukę”)
/// w `StudyHomeView`.
struct StudyRootScreen: View {
    var body: some View {
        StudyHomeView()
    }
}

#Preview("Nauka") {
    NavigationStack {
        StudyRootScreen()
    }
    .fluentPreviewEnvironment()
}
