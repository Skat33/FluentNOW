import SwiftUI
import FluentKit

/// Pole odpowiedzi + warianty + podpowiedź + druga próba + przyciski (zadania 1–4).
struct VocabAnswerArea: View {
    @Bindable var model: VocabExerciseModel
    let focus: FocusState<Bool>.Binding

    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if model.phase == .retry {
                FeedbackPanel(
                    kind: .almost,
                    title: "Jeszcze nie",
                    message: "Spróbuj jeszcze raz — podpowiedź masz poniżej.",
                    playsHaptic: preferences.hapticsEnabled
                )
            }
            StudyAnswerField(
                text: $model.answer,
                placeholder: model.type == .meaning ? "Wpisz polskie znaczenie…" : "Wpisz swoją odpowiedź…",
                language: model.type == .meaning ? .polish : .english,
                isEnabled: model.phase == .answering || model.phase == .retry,
                focus: focus,
                onSubmit: model.check
            )
            if model.type == .meaning {
                VocabMeaningVariants(model: model)
            }
            if model.hintShown && model.phase != .checking {
                StudyHintBox(text: model.content.hintText)
            }
            if model.phase == .checking {
                VocabAssistantChecking(onSkip: model.skipAssistant)
            } else {
                VocabAnswerActions(model: model)
            }
        }
    }
}

/// „Pokaż warianty” w zadaniu „Wybierz znaczenie” — cztery opcje (`MeaningOptions`).
private struct VocabMeaningVariants: View {
    let model: VocabExerciseModel

    var body: some View {
        if model.variantsShown {
            StudyChoiceList(
                options: model.options,
                selected: model.options.firstIndex(of: model.answer),
                correct: nil,
                isRevealed: false,
                isEnabled: model.phase == .answering || model.phase == .retry,
                marker: .numbers,
                usesKeyboardShortcuts: false
            ) { index in
                if let option = model.options.studyItem(at: index) {
                    model.choose(option)
                }
            }
        } else if !model.options.isEmpty {
            Button(action: model.showVariants) {
                Label("Pokaż warianty", systemImage: "list.bullet")
                    .font(FluentFont.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Pokazuje cztery możliwe znaczenia. Odpowiedź zostanie zapisana jako udzielona z pomocą."))
        }
    }
}

/// Wiersz akcji przed sprawdzeniem.
private struct VocabAnswerActions: View {
    let model: VocabExerciseModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.s) {
                leading
                Spacer(minLength: Spacing.xs)
                checkButton(fillsWidth: false)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                checkButton(fillsWidth: true)
                leading
            }
        }
    }

    @ViewBuilder
    private var leading: some View {
        if model.phase == .retry {
            Button("Pokaż odpowiedź", action: model.giveUp)
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: HitTarget.minimum)
        } else if !model.hintShown {
            StudyHintButton(action: model.showHint)
        }
    }

    private func checkButton(fillsWidth: Bool) -> some View {
        PrimaryButton("Sprawdź", systemImage: "arrow.right", fillsWidth: fillsWidth, action: model.check)
            .disabled(!model.canCheck)
    }
}

/// Oczekiwanie na ocenę asystenta — nigdy nie blokuje: można pominąć.
private struct VocabAssistantChecking: View {
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            ProgressView()
                .tint(Palette.accent)
                .accessibilityHidden(true)
            Text("Asystent sprawdza, czy to też poprawna odpowiedź…")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)
            Button("Pomiń", action: onSkip)
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: HitTarget.minimum)
        }
        .padding(Spacing.s)
        .fluentCardBackground(.muted, cornerRadius: Radius.medium)
        .accessibilityElement(children: .contain)
    }
}
