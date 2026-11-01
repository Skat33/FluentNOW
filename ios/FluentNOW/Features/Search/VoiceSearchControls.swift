import SwiftUI
import UIKit

/// Pole wyszukiwania z mikrofonem (FEEDBACK-9 N3): domyślny język i klucz zapamiętanego wyboru.
enum VoiceSearchField: String {
    case addWord
    case dictionary
    case topic

    /// „Dodaj słowo” i Słownik — najpierw angielski; „Szukaj tematu” opisuje się po polsku.
    var defaultLanguage: VoiceSearchLanguage {
        switch self {
        case .addWord, .dictionary: return .english
        case .topic: return .polish
        }
    }

    var storageKey: String { "voiceSearch.language.\(rawValue)" }
}

/// Start / stop wyszukiwania głosowego wspólny dla pól i paska narzędzi.
@MainActor
enum VoiceSearchAction {
    /// Dotknięcie mikrofonu: zatrzymuje trwające nagranie albo zaczyna nowe. Zatrzymuje odsłuch
    /// wymowy (syntezator nie może nagrać się do wyszukiwania). Wynik częściowy od razu w polu;
    /// gdy nic nie rozpoznano, pole wraca do poprzedniego tekstu.
    static func toggle(
        _ voice: VoiceSearchController,
        text: Binding<String>,
        language: VoiceSearchLanguage,
        speech: SpeechService,
        onStart: @escaping () -> Void = {}
    ) {
        if voice.isActive {
            voice.stop()
            return
        }
        start(voice, text: text, language: language, speech: speech, onStart: onStart)
    }

    static func start(
        _ voice: VoiceSearchController,
        text: Binding<String>,
        language: VoiceSearchLanguage,
        speech: SpeechService,
        onStart: @escaping () -> Void = {}
    ) {
        speech.stop()
        onStart()
        let previous = text.wrappedValue
        Task {
            await voice.start(
                language: language,
                onPartial: { (value: String) -> Void in text.wrappedValue = value },
                onFinish: { (value: String) -> Void in text.wrappedValue = value.isEmpty ? previous : value }
            )
        }
    }
}

/// Przełącznik języka + mikrofon do wstawienia w wiersz pola wyszukiwania.
struct VoiceSearchControls: View {
    let voice: VoiceSearchController
    @Binding var text: String
    let field: VoiceSearchField
    let onStart: () -> Void

    @AppStorage private var languageRaw: String
    @Environment(SpeechService.self) private var speech

    init(voice: VoiceSearchController, text: Binding<String>, field: VoiceSearchField, onStart: @escaping () -> Void = {}) {
        self.voice = voice
        _text = text
        self.field = field
        self.onStart = onStart
        _languageRaw = AppStorage(wrappedValue: field.defaultLanguage.rawValue, field.storageKey)
    }

    private var language: VoiceSearchLanguage {
        VoiceSearchLanguage(rawValue: languageRaw) ?? field.defaultLanguage
    }

    var body: some View {
        HStack(spacing: 0) {
            VoiceLanguageToggle(language: language, isDisabled: voice.isActive) {
                languageRaw = language.toggled.rawValue
            }
            VoiceMicButton(state: voice.state, level: voice.level, language: language) {
                VoiceSearchAction.toggle(voice, text: $text, language: language, speech: speech, onStart: onStart)
            }
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: languageRaw)
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: voice.isListening)
    }
}

/// Mikrofon w pasku narzędzi (Słownik — pole `.searchable` należy do systemu). Język wybiera
/// się w pasku nagrywania (`VoiceSearchBanner`).
struct VoiceSearchToolbarButton: View {
    let voice: VoiceSearchController
    @Binding var text: String
    let field: VoiceSearchField

    @AppStorage private var languageRaw: String
    @Environment(SpeechService.self) private var speech

    init(voice: VoiceSearchController, text: Binding<String>, field: VoiceSearchField) {
        self.voice = voice
        _text = text
        self.field = field
        _languageRaw = AppStorage(wrappedValue: field.defaultLanguage.rawValue, field.storageKey)
    }

    private var language: VoiceSearchLanguage {
        VoiceSearchLanguage(rawValue: languageRaw) ?? field.defaultLanguage
    }

    var body: some View {
        VoiceMicButton(state: voice.state, level: voice.level, language: language) {
            VoiceSearchAction.toggle(voice, text: $text, language: language, speech: speech)
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: voice.isListening)
    }
}

/// Pasek nagrywania nad dolną krawędzią listy (Słownik): stan, zmiana języka (nagranie zaczyna
/// się od nowa w drugim języku), „Gotowe”. Jednolite tło — to kontrolka, nie treść.
struct VoiceSearchBanner: View {
    let voice: VoiceSearchController
    @Binding var text: String
    let field: VoiceSearchField

    @AppStorage private var languageRaw: String
    @Environment(SpeechService.self) private var speech
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(voice: VoiceSearchController, text: Binding<String>, field: VoiceSearchField) {
        self.voice = voice
        _text = text
        self.field = field
        _languageRaw = AppStorage(wrappedValue: field.defaultLanguage.rawValue, field.storageKey)
    }

    private var language: VoiceSearchLanguage {
        VoiceSearchLanguage(rawValue: languageRaw) ?? field.defaultLanguage
    }

    var body: some View {
        if voice.isActive {
            HStack(spacing: Spacing.s) {
                Image(systemName: "waveform")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.accent)
                    .symbolEffect(.variableColor.iterative, isActive: voice.isListening && !reduceMotion)
                    .accessibilityHidden(true)
                Text(VoiceSearchStatus.text(for: voice) ?? "")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button(language.toggled.shortLabel) { switchLanguage() }
                    .font(FluentFont.button)
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    .accessibilityLabel(Text("Mów \(language.toggled.adverbPl)"))
                Button("Gotowe") { voice.stop() }
                    .font(FluentFont.button)
                    .frame(minHeight: HitTarget.minimum)
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.xxs)
            .background(Palette.surfaceElevated, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .stroke(Palette.separator)
            }
            .fluentShadow(.raised)
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xs)
            .transition(.opacity)
        }
    }

    /// Nagranie od nowa w drugim języku (to, co już powiedziano, było w złym języku).
    private func switchLanguage() {
        let next = language.toggled
        languageRaw = next.rawValue
        voice.cancel()
        VoiceSearchAction.start(voice, text: $text, language: next, speech: speech)
    }
}

/// Tekst stanu pod polem / w pasku nagrywania.
enum VoiceSearchStatus {
    @MainActor
    static func text(for voice: VoiceSearchController) -> String? {
        switch voice.state {
        case .idle:
            return voice.notice
        case .starting:
            return "Włączam mikrofon…"
        case .listening:
            return "Słucham \(voice.language.adverbPl)… Skończę po chwili ciszy."
        case .finishing:
            return "Rozpoznaję…"
        }
    }
}

/// Stopka sekcji pola: stan nagrywania albo zwykła podpowiedź.
struct VoiceSearchFooter: View {
    let voice: VoiceSearchController
    let hint: String

    var body: some View {
        if let status = VoiceSearchStatus.text(for: voice) {
            Label(status, systemImage: voice.isActive ? "mic.fill" : "info.circle")
                .foregroundStyle(voice.isActive ? Palette.accent : Palette.inkSecondary)
        } else {
            Text(hint)
        }
    }
}

/// Mikrofon: idle — ikona; nagrywanie — wypełnione kółko pulsujące z poziomem dźwięku.
private struct VoiceMicButton: View {
    let state: VoiceSearchState
    let level: Double
    let language: VoiceSearchLanguage
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isListening: Bool { state == .listening }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isListening ? Palette.accentFill : Color.clear)
                    .frame(width: 34, height: 34)
                    .scaleEffect(isListening && !reduceMotion ? 1 + level * 0.3 : 1)
                    .animation(reduceMotion ? nil : Animation.easeOut(duration: 0.12), value: level)
                icon
            }
            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityHint(Text(isListening ? "Kończy nagrywanie i szuka" : "Mów słowo \(language.adverbPl)"))
    }

    @ViewBuilder
    private var icon: some View {
        switch state {
        case .idle:
            Image(systemName: "mic")
                .font(FluentFont.body.weight(.semibold))
                .foregroundStyle(Palette.accent)
        case .starting, .finishing:
            ProgressView()
                .controlSize(.small)
        case .listening:
            Image(systemName: "waveform")
                .font(FluentFont.body.weight(.semibold))
                .foregroundStyle(Palette.onAccent)
                .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
        }
    }

    private var accessibilityText: String {
        switch state {
        case .idle: return "Szukaj głosem"
        case .starting: return "Włączanie mikrofonu"
        case .listening: return "Zatrzymaj nagrywanie"
        case .finishing: return "Rozpoznawanie mowy"
        }
    }
}

/// Mały przełącznik „EN” / „PL” — język rozpoznawania mowy.
private struct VoiceLanguageToggle: View {
    let language: VoiceSearchLanguage
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(language.shortLabel)
                .font(FluentFont.caption.weight(.semibold))
                .foregroundStyle(Palette.accentSoftInk)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xxs)
                .background(Capsule().fill(Palette.accentSoft))
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(isDisabled)
        .accessibilityLabel(Text("Język dyktowania: \(language.namePl)"))
        .accessibilityHint(Text("Zmienia na \(language.toggled.namePl)"))
    }
}

/// Alert problemu z mikrofonem (z „Otwórz Ustawienia” przy braku zgody). Dołączać do ekranu
/// (formularza / listy), nie do sekcji — modyfikator sekcji trafia do każdego wiersza.
private struct VoiceSearchIssueAlert: ViewModifier {
    let voice: VoiceSearchController

    @Environment(\.openURL) private var openURL

    private var isPresented: Binding<Bool> {
        Binding(
            get: { voice.issue != nil },
            set: { (shown: Bool) -> Void in if !shown { voice.issue = nil } }
        )
    }

    func body(content: Content) -> some View {
        content.alert(voice.issue?.title ?? "", isPresented: isPresented, presenting: voice.issue) { (issue: VoiceSearchIssue) in
            if issue.offersSettings {
                Button("Otwórz Ustawienia") { openSettings() }
                Button("Anuluj", role: .cancel) {}
            } else {
                Button("OK", role: .cancel) {}
            }
        } message: { (issue: VoiceSearchIssue) in
            Text(issue.message)
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

extension View {
    /// Alert problemu z wyszukiwaniem głosowym + zatrzymanie mikrofonu, gdy ekran znika.
    func voiceSearchLifecycle(_ voice: VoiceSearchController) -> some View {
        modifier(VoiceSearchIssueAlert(voice: voice))
            .onDisappear { voice.cancel() }
    }
}
