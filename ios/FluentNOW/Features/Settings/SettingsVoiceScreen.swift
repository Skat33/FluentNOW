import SwiftUI
import FluentKit

/// Wybór akcentu i głosu lektora (z odsłuchem).
struct SettingsVoiceScreen: View {
    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech

    @State private var voices: [VoiceOption] = []

    private var accentBinding: Binding<String> {
        Binding(
            get: { store.settings.accent },
            set: { value in
                guard LearnerSettings.supportedAccents.contains(value) else { return }
                store.update(.edit) { $0.settings.accent = value }
            }
        )
    }

    private var selectedVoice: String? {
        guard let id = store.settings.voice, !id.isEmpty else { return nil }
        return id
    }

    var body: some View {
        List {
            Section {
                Picker("Akcent", selection: accentBinding) {
                    ForEach(LearnerSettings.supportedAccents, id: \.self) { accent in
                        Text(SettingsVoiceText.accentName(accent).capitalized).tag(accent)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Domyślnie wymowa amerykańska — tak samo jak zapis IPA w aplikacji.")
            }
            Section {
                SettingsVoiceRow(title: "Automatycznie", subtitle: "Najlepszy dostępny głos dla akcentu",
                                 isSelected: selectedVoice == nil) {
                    select(nil)
                }
                ForEach(voices) { voice in
                    SettingsVoiceRow(title: voice.name, subtitle: "\(voice.language) · \(voice.qualityLabel)",
                                     isSelected: selectedVoice == voice.id) {
                        select(voice)
                    }
                }
            } header: {
                Text("Głos")
            } footer: {
                Text("Dotknij głosu, aby go odsłuchać i wybrać. Więcej naturalnych głosów (wersje rozszerzone i premium) pobierzesz w Ustawieniach systemu: Dostępność → Treść mówiona → Głosy.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Głos i akcent")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { voices = speech.availableVoices() }
    }

    private func select(_ voice: VoiceOption?) {
        let id = voice?.id
        store.update(.edit) { $0.settings.voice = id }
        if let voice {
            speech.preview(voice: voice)
        } else {
            speech.speak("A little practice every day goes a long way.")
        }
    }
}

private struct SettingsVoiceRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(Text("Odtwarza próbkę i wybiera głos"))
    }
}

#Preview("Głos") {
    NavigationStack {
        SettingsVoiceScreen()
    }
    .fluentPreviewEnvironment()
}
