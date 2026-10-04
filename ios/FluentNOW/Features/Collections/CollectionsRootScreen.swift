import SwiftUI

/// Lista kolekcji — osadzana w karcie „Słownik” (segment „Kolekcje”), więc bez własnego
/// `NavigationStack` i bez `navigationTitle`.
/// Fala 2 (ui-library): zastąp `body` docelowym widokiem i usuń `CollectionsRootPlaceholder`.
struct CollectionsRootScreen: View {
    var body: some View {
        CollectionsRootPlaceholder()
    }
}
