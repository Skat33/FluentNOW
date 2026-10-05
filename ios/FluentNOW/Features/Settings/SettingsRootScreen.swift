import SwiftUI
import FluentKit

/// Podstrony Ustawień.
enum SettingsRoute: Hashable {
    case voice
    case assistant
    case importData
    case exportData
    case about
}

/// Korzeń karty „Ustawienia”. Kontrakt powłoki: inicjalizator bez argumentów, bez własnego `NavigationStack`.
struct SettingsRootScreen: View {
    @Environment(AssistantService.self) private var assistant

    var body: some View {
        Form {
            SettingsLearningSection()
            SettingsVoiceSection()
            SettingsAppearanceSection()
            SettingsSyncSection()
            Section("Asystent AI") {
                NavigationLink(value: SettingsRoute.assistant) {
                    LabeledContent {
                        Text(assistant.activeProvider.namePl)
                    } label: {
                        Label("Dostawca", systemImage: "sparkles")
                    }
                }
            }
            SettingsDataSection()
            Section {
                NavigationLink(value: SettingsRoute.about) {
                    Label("O aplikacji i prywatność", systemImage: "info.circle")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Ustawienia")
        .navigationDestination(for: SettingsRoute.self) { route in
            SettingsDestination(route: route)
        }
    }
}

private struct SettingsDestination: View {
    let route: SettingsRoute

    var body: some View {
        switch route {
        case .voice: SettingsVoiceScreen()
        case .assistant: SettingsAssistantScreen()
        case .importData: SettingsImportScreen()
        case .exportData: SettingsExportScreen()
        case .about: SettingsAboutScreen()
        }
    }
}

#Preview("Ustawienia") {
    NavigationStack {
        SettingsRootScreen()
    }
    .fluentPreviewEnvironment()
}
