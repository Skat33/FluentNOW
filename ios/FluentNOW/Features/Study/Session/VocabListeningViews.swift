import SwiftUI
import FluentKit

// „Zrozum ze słuchu” (FEEDBACK-4 I2): lektor czyta zdanie (tekst ukryty do odpowiedzi), najwyżej
// trzy odsłuchy (także wolniej), wybór polskiego tłumaczenia spośród czterech.

/// Odtwarzanie (normalnie / wolniej) z licznikiem odsłuchów; po odpowiedzi — zdanie i tłumaczenie.
struct VocabListeningPrompt: View {
    let model: VocabExerciseModel

    @Environment(SpeechService.self) private var speech
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StudyQuestionLabel(text: "Posłuchaj zdania i wybierz, co znaczy")
            HStack(spacing: Spacing.l) {
                SpeakButton(size: .large, isSpeaking: speech.isSpeaking, accessibilityLabel: "Odsłuchaj zdanie") {
                    play(slow: false)
                }
                SpeakButton(style: .slow, accessibilityLabel: "Odsłuchaj zdanie wolniej") {
                    play(slow: true)
                }
            }
            .disabled(!model.canPlay)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
            Text(playsLine)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if model.isFinished {
                StudyExampleSentence(text: model.content.example, focus: model.content.focus)
                StudyPairTranslation(pair: model.content.pair)
            }
        }
        .task(id: model.key) {
            // Pierwszy odsłuch sam (liczy się do limitu). Przy VoiceOver nie odtwarzamy sami —
            // mowa nałożyłaby się na czytnik ekranu.
            guard !voiceOverEnabled, model.plays == 0, !model.isFinished else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            play(slow: false)
        }
    }

    private var playsLine: String {
        if model.isFinished { return "Możesz odsłuchać zdanie dowolnie wiele razy." }
        let left = max(0, ListeningChoice.maxPlays - model.plays)
        switch left {
        case 0: return "Wykorzystano wszystkie odsłuchy — wybierz odpowiedź."
        case 1: return "Został 1 odsłuch."
        default: return "Pozostałe odsłuchy: \(left) z \(ListeningChoice.maxPlays)."
        }
    }

    private func play(slow: Bool) {
        guard model.registerPlay() else { return }
        speech.speak(model.content.example, slow: slow)
    }
}

/// Cztery tłumaczenia (klawisze 1–4). Pierwszy błąd: druga próba (błędna opcja zablokowana),
/// odpowiedź liczy się wtedy jako z pomocą. Po odpowiedzi lista zostaje z zaznaczeniem.
struct VocabListeningChoiceArea: View {
    let model: VocabExerciseModel

    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if model.phase == .retry {
                FeedbackPanel(
                    kind: .almost,
                    title: "Jeszcze nie",
                    message: "Posłuchaj jeszcze raz i wybierz inną odpowiedź.",
                    playsHaptic: preferences.hapticsEnabled
                )
            }
            VStack(spacing: Spacing.xs) {
                ForEach(Array(model.options.enumerated()), id: \.offset) { index, option in
                    StudyChoiceRow(
                        marker: "\(index + 1)",
                        text: option,
                        state: rowState(index),
                        isEnabled: isEnabled(index),
                        shortcut: shortcut(index)
                    ) {
                        model.chooseOption(at: index)
                    }
                }
            }
            if model.phase == .retry {
                Button("Pokaż odpowiedź", action: model.giveUp)
                    .font(FluentFont.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: HitTarget.minimum)
            }
        }
    }

    private var isAnswering: Bool {
        model.phase == .answering || model.phase == .retry
    }

    private func isEnabled(_ index: Int) -> Bool {
        isAnswering && !model.wrongOptions.contains(index)
    }

    private func shortcut(_ index: Int) -> KeyEquivalent? {
        guard isEnabled(index), index < 9 else { return nil }
        return KeyEquivalent(Character("\(index + 1)"))
    }

    private func rowState(_ index: Int) -> StudyChoiceRow.RowState {
        // Test (K4): tylko zaznaczenie wyboru, bez poprawnej/błędnej.
        if model.isAssessment {
            return index == model.chosenOption ? .chosen : .idle
        }
        if model.isFinished {
            if index == model.correctOption { return .correct }
            if index == model.chosenOption || model.wrongOptions.contains(index) { return .wrong }
            return .idle
        }
        return model.wrongOptions.contains(index) ? .wrong : .idle
    }
}
