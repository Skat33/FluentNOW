import SwiftUI

/// Korzeń karty „Dzisiaj”. Kontrakt powłoki: inicjalizator bez argumentów, bez własnego
/// `NavigationStack` (dostarcza go `RootView`), trasy przez `.navigationDestination(for:)`.
/// Fala 2 (ui-library): zastąp `body` docelowym ekranem i usuń `TodayRootPlaceholder`.
struct TodayRootScreen: View {
    var body: some View {
        TodayRootPlaceholder()
    }
}
