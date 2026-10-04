import SwiftUI

/// Korzeń karty „Ustawienia”. Kontrakt powłoki: inicjalizator bez argumentów, bez własnego `NavigationStack`.
/// Fala 2 (ui-library): zastąp `body` docelowym ekranem i usuń `SettingsRootPlaceholder`.
struct SettingsRootScreen: View {
    var body: some View {
        SettingsRootPlaceholder()
    }
}
