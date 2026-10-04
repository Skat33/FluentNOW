import SwiftUI

/// Korzeń karty „Słownik” (segmenty Słowa / Kolekcje / Tematy — `AppRouter.librarySection`).
/// Kontrakt powłoki: inicjalizator bez argumentów, bez własnego `NavigationStack`.
/// Fala 2 (ui-library): zastąp `body` docelowym ekranem i usuń `WordsRootPlaceholder`.
struct WordsRootScreen: View {
    var body: some View {
        WordsRootPlaceholder()
    }
}
