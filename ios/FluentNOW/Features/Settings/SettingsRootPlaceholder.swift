import SwiftUI

/// ZAŚLEPKA (design-shell) — fala 2 zastąpi ją Ustawieniami.
/// Zawiera wejście do galerii design systemu (przydatne przy przeglądzie wizualnym na urządzeniu).
struct SettingsRootPlaceholder: View {
    var body: some View {
        List {
            Section {
                NavigationLink {
                    DesignSystemGallery()
                } label: {
                    Label("Galeria komponentów", systemImage: "paintpalette")
                }
            } footer: {
                Text("Ustawienia (cel, przypomnienia, głos, motyw, iCloud, AI, import i eksport) pojawią się tutaj.")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Ustawienia")
    }
}

#Preview("Ustawienia — zaślepka") {
    NavigationStack {
        SettingsRootPlaceholder()
    }
}
