import SwiftUI

/// Korzeń karty „Nauka”. Kontrakt powłoki: inicjalizator bez argumentów, bez własnego
/// `NavigationStack`. Ekran konsumuje `router.consumeStudyLaunch()` (deep link / „Zaczynam naukę”).
/// Fala 2 (ui-learning): zastąp `body` docelowym ekranem i usuń `StudyRootPlaceholder`.
struct StudyRootScreen: View {
    var body: some View {
        StudyRootPlaceholder()
    }
}
