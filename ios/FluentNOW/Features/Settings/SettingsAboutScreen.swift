import SwiftUI
import FluentKit

/// „O aplikacji”: wersja, treści, prywatność.
struct SettingsAboutScreen: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Wersja", value: version)
                LabeledContent("Silnik nauki", value: FluentKitInfo.version)
            }
            Section("Treści") {
                Text("Tematy słówek, przykłady, ćwiczenia gramatyczne, idiomy i czytanki są wbudowane w aplikację i działają bez internetu. Angielski w wersji amerykańskiej, wymowa w zapisie IPA (General American). Treści przygotowano dla FluentNOW; nie pochodzą z zewnętrznych słowników objętych licencją.")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Section("Prywatność") {
                SettingsPrivacyRow(systemImage: "iphone", text: "Słowa, postęp i historia są na tym urządzeniu i w Twoim prywatnym iCloud. Nie mamy serwera ani kont.")
                SettingsPrivacyRow(systemImage: "mic.slash", text: "Rozpoznawanie wymowy działa na urządzeniu; nagrania nie są zapisywane ani wysyłane.")
                SettingsPrivacyRow(systemImage: "sparkles", text: "Gemini (tylko jeśli go włączysz): do Google trafia wpisane słowo albo bieżące zadanie z Twoją odpowiedzią — nic więcej. Apple Intelligence działa na urządzeniu.")
                SettingsPrivacyRow(systemImage: "bell", text: "Przypomnienia są lokalne — planuje je system, bez serwera powiadomień.")
            }
            #if DEBUG
            Section("Dla twórców") {
                NavigationLink {
                    DesignSystemGallery()
                } label: {
                    Label("Galeria komponentów", systemImage: "paintpalette")
                }
            }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("O aplikacji")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SettingsPrivacyRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.accent)
        }
    }
}

#Preview("O aplikacji") {
    NavigationStack {
        SettingsAboutScreen()
    }
}
