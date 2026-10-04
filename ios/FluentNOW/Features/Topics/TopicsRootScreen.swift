import SwiftUI

/// Przeglądarka tematów — osadzana w karcie „Słownik” (segment „Tematy”), więc bez własnego
/// `NavigationStack` i bez `navigationTitle`.
/// Fala 2 (ui-library): zastąp `body` docelowym widokiem i usuń `TopicsRootPlaceholder`.
struct TopicsRootScreen: View {
    var body: some View {
        TopicsRootPlaceholder()
    }
}
