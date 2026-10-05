import SwiftUI
import FluentKit

/// Treść zadania zależna od typu (bez pola odpowiedzi).
struct VocabPromptView: View {
    let model: VocabExerciseModel

    var body: some View {
        switch model.type {
        case .flashcard:
            VocabFlashcardPrompt(content: model.content, revealed: model.revealed || model.isFinished)
        case .recall:
            VocabRecallPrompt(content: model.content)
        case .cloze:
            VocabClozePrompt(content: model.content)
        case .meaning:
            VocabMeaningPrompt(content: model.content)
        case .dictation:
            VocabDictationPrompt(content: model.content)
        }
    }
}

/// Polskie tłumaczenie zdania z wyróżnionym odpowiednikiem.
struct StudyPairTranslation: View {
    let pair: ExamplePair?

    var body: some View {
        if let pair, !pair.pl.isEmpty {
            HighlightedText(pair.pl, focus: pair.focusPl, highlight: Palette.accentSoftInk)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Etykieta pytania nad treścią zadania.
struct StudyQuestionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(FluentFont.subheadline.weight(.semibold))
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Zdanie angielskie w cudzysłowie z wyróżnionym wyrażeniem.
struct StudyExampleSentence: View {
    let text: String
    let focus: String

    var body: some View {
        if !text.isEmpty {
            HighlightedText("“\(text)”", focus: focus)
                .font(FluentFont.sentence)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Typy zadań

private struct VocabFlashcardPrompt: View {
    let content: VocabExerciseContent
    let revealed: Bool

    @Environment(SpeechService.self) private var speech

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .center, spacing: Spacing.s) {
                Text(content.word.en)
                    .font(FluentFont.flashcardTerm)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.xs)
                SpeakButton(isSpeaking: speech.isSpeaking) { speech.speak(content.word.en) }
            }
            if !content.word.ipa.isEmpty {
                Text(content.word.ipa)
                    .font(FluentFont.ipa)
                    .foregroundStyle(Palette.inkSecondary)
            }
            StudyExampleSentence(text: content.example, focus: content.focus)
            if revealed {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    StudyPairTranslation(pair: content.pair)
                    Text("**\(content.word.en)** — \(content.meaning.translation)")
                        .font(FluentFont.body)
                        .foregroundStyle(Palette.ink)
                    if !content.meaning.definition.isEmpty {
                        Text(content.meaning.definition)
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fluentCardBackground(.muted, cornerRadius: Radius.medium)
                .transition(.opacity)
            }
        }
    }
}

private struct VocabRecallPrompt: View {
    let content: VocabExerciseContent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StudyQuestionLabel(text: "Jak powiesz to po angielsku?")
            Text(content.meaning.translation)
                .font(FluentFont.flashcardTerm)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            StudyPairTranslation(pair: content.pair)
            Text("Podaj słowo lub pasujący zwrot. Kontekst: \(content.meaning.context.isEmpty ? content.word.collection : content.meaning.context)")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct VocabClozePrompt: View {
    let content: VocabExerciseContent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StudyQuestionLabel(text: "Uzupełnij zdanie słowem ze swojego słownika")
            Text(content.clozeSentence)
                .font(FluentFont.sentence)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text(content.clozeSentence.replacingOccurrences(of: Cloze.gap, with: "luka")))
            if content.mode != .pairs {
                StudyPairTranslation(pair: content.pair)
            }
            Text(content.mode == .pairs
                 ? "Wpisz słowo pasujące do polskiej podpowiedzi w nawiasie. Dobierz formę do zdania."
                 : "Uzupełnij angielskie zdanie tak, aby zachować powyższy sens.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct VocabMeaningPrompt: View {
    let content: VocabExerciseContent

    @Environment(SpeechService.self) private var speech

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StudyQuestionLabel(text: "Co oznacza wyróżnione słowo w tym kontekście?")
            HStack(alignment: .center, spacing: Spacing.s) {
                Text(content.word.en)
                    .font(FluentFont.flashcardTerm)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.xs)
                SpeakButton(isSpeaking: speech.isSpeaking) { speech.speak(content.word.en) }
            }
            StudyExampleSentence(text: content.example, focus: content.focus)
        }
    }
}

private struct VocabDictationPrompt: View {
    let content: VocabExerciseContent

    @Environment(SpeechService.self) private var speech
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StudyQuestionLabel(text: "Posłuchaj i zapisz po angielsku")
            HStack(spacing: Spacing.l) {
                SpeakButton(size: .large, isSpeaking: speech.isSpeaking, accessibilityLabel: "Odsłuchaj słowo do dyktanda") {
                    speech.speak(content.word.en)
                }
                SpeakButton(style: .slow, accessibilityLabel: "Odtwórz wolniej") {
                    speech.speak(content.word.en, slow: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.s)
        }
        .task(id: content.word.id) {
            // Krótka chwila na pojawienie się ekranu, potem automatyczny odsłuch.
            // Przy VoiceOver nie odtwarzamy sami — mowa nałożyłaby się na czytnik ekranu.
            guard !voiceOverEnabled else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            speech.speak(content.word.en)
        }
    }
}
