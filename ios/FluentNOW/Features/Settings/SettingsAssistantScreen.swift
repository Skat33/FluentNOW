import SwiftUI
import FluentKit

/// Wybór asystenta AI: offline / Apple na urządzeniu (gdy dostępny) / Gemini z kluczem w Keychain.
struct SettingsAssistantScreen: View {
    @Environment(AssistantService.self) private var assistant
    @Environment(AppPreferences.self) private var preferences

    @State private var apiKey = ""
    @State private var isConnecting = false
    @State private var connectError: String?

    var body: some View {
        Form {
            Section {
                ForEach(AssistantProvider.allCases) { provider in
                    SettingsProviderRow(
                        provider: provider,
                        isSelected: preferences.assistantProvider == provider,
                        isActive: assistant.activeProvider == provider,
                        isAvailable: provider != .appleOnDevice || assistant.isAppleOnDeviceAvailable
                    ) {
                        preferences.assistantProvider = provider
                    }
                }
            } header: {
                Text("Dostawca")
            } footer: {
                Text("Aplikacja działa w pełni bez AI. Asystent pomaga tylko przy słowach spoza wbudowanej bazy i przy niejednoznacznych odpowiedziach — jego propozycje zawsze są oznaczone.")
            }
            if preferences.assistantProvider == .appleOnDevice && !assistant.isAppleOnDeviceAvailable {
                Section {
                    Label(assistant.appleOnDeviceUnavailableReason, systemImage: "exclamationmark.triangle")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.warning)
                }
            }
            if preferences.assistantProvider == .gemini {
                SettingsGeminiSection(
                    apiKey: $apiKey,
                    isConnecting: isConnecting,
                    connectError: connectError,
                    onConnect: { Task { await connect() } }
                )
            }
            Section("Prywatność") {
                Text("Przy Gemini do Google trafia tylko treść bieżącego zapytania: wpisane słowo albo zadanie z Twoją odpowiedzią. Nie wysyłamy słownika, historii ani nagrań. Klucz API jest zapisany wyłącznie w pęku kluczy tego urządzenia.")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Asystent AI")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { assistant.refreshAvailability() }
    }

    private func connect() async {
        guard !isConnecting else { return }
        isConnecting = true
        connectError = nil
        do {
            try await assistant.connectGemini(apiKey: apiKey)
            apiKey = ""
        } catch {
            connectError = error.localizedDescription
        }
        isConnecting = false
    }
}

private struct SettingsProviderRow: View {
    let provider: AssistantProvider
    let isSelected: Bool
    let isActive: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Spacing.s) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Palette.accent : Palette.inkSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.namePl)
                        .foregroundStyle(isAvailable ? Palette.ink : Palette.inkSecondary)
                    Text(isAvailable ? provider.detailPl : "Niedostępne na tym urządzeniu.")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isSelected && !isActive && provider != .offline {
                        Text("Nieaktywne — do czasu połączenia działa tryb bez AI.")
                            .font(FluentFont.footnote)
                            .foregroundStyle(Palette.warning)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SettingsGeminiSection: View {
    @Binding var apiKey: String
    let isConnecting: Bool
    let connectError: String?
    let onConnect: () -> Void

    @Environment(AssistantService.self) private var assistant

    var body: some View {
        Section {
            switch assistant.geminiStatus {
            case .connected(let model):
                Label("Połączono · \(model)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Palette.success)
                Button("Odłącz i usuń klucz", role: .destructive) {
                    assistant.disconnectGemini()
                }
            case .notConfigured, .error:
                SecureField("Klucz API Gemini", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.password)
                Button {
                    onConnect()
                } label: {
                    HStack {
                        Text("Połącz")
                        if isConnecting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
                if let message = connectError ?? SettingsGeminiSection.statusError(assistant.geminiStatus) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.danger)
                }
            }
        } header: {
            Text("Google Gemini")
        } footer: {
            Text("Klucz utworzysz bezpłatnie w Google AI Studio. „Połącz” sprawdza go od razu i pokazuje czytelny błąd, jeśli coś jest nie tak.")
        }
    }

    static func statusError(_ status: GeminiConnectionStatus) -> String? {
        if case .error(let message) = status { return message }
        return nil
    }
}

#Preview("Asystent AI") {
    NavigationStack {
        SettingsAssistantScreen()
    }
    .fluentPreviewEnvironment()
}
