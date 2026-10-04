import SwiftUI

/// Korzeń karty „Postępy”. Kontrakt powłoki: inicjalizator bez argumentów, bez własnego `NavigationStack`.
/// Fala 2 (ui-library): zastąp `body` docelowym ekranem i usuń `StatsRootPlaceholder`.
struct StatsRootScreen: View {
    var body: some View {
        StatsRootPlaceholder()
    }
}
