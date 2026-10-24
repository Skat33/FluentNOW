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
                StudyHintBox(lines: model.visibleHints)
            }
            if model.phase == .checking {
                VocabAssistantChecking(onSkip: model.skipAssistant)
            } else if !model.isAssessment {
                // Test (K4): zamiast „Sprawdź” jest „Dalej” ekranu testu.
                VocabAnswerActions(model: model)
            }
        }
    }
}

/// „Pokaż warianty” w zadaniu „Wybierz znaczenie” wpisywanym z pamięci. Po dotknięciu pole
/// tekstowe znika i zostaje sam wybór opcji (`VocabMeaningChoiceArea`, H1).
private struct VocabMeaningVariants: View {
    let model: VocabExerciseModel

    var body: some View {
        if !model.variantsShown && model.options.count >= 2 {
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

    private var leading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.m) { helpButtons }
            VStack(alignment: .leading, spacing: 0) { helpButtons }
        }
    }

    /// „Podpowiedź” → „Więcej podpowiedzi” (kolejny poziom) i w drugiej próbie „Pokaż odpowiedź”.
    @ViewBuilder
    private var helpButtons: some View {
        if model.canShowMoreHints {
            StudyHintButton(title: model.hintShown ? "Więcej podpowiedzi" : "Podpowiedź") {
                model.showHint()
            }
        }
        if model.phase == .retry {
            Button("Pokaż odpowiedź", action: model.giveUp)
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: HitTarget.minimum)
        }
    }

    private func checkButton(fillsWidth: Bool) -> some View {
        PrimaryButton("Sprawdź", systemImage: "arrow.right", fillsWidth: fillsWidth, action: model.check)
            .disabled(!model.canCheck)
    }
}

/// „Wybierz znaczenie” z widocznymi opcjami (H1): tylko wybór dotknięciem albo klawiszem 1–4 —
/// bez pola tekstowego. Po pierwszym błędzie: druga próba z podpowiedzią, błędna opcja zablokowana.
/// Po odpowiedzi lista zostaje z zaznaczeniem poprawnej i błędnej opcji.
struct VocabMeaningChoiceArea: View {
    let model: VocabExerciseModel

    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if model.phase == .retry {
                FeedbackPanel(
                    kind: .almost,
                    title: "Jeszcze nie",
                    message: "Wybierz inną odpowiedź — podpowiedź masz poniżej.",
                    playsHaptic: preferences.hapticsEnabled
                )
            }
            VocabMeaningChoiceList(model: model)
            if model.hintShown && !model.isFinished {
                StudyHintBox(lines: model.visibleHints)
            }
            if !model.isFinished {
                VocabChoiceHelpButtons(model: model)
            }
        }
    }
}

/// Opcje znaczenia (1–4).
private struct VocabMeaningChoiceList: View {
    let model: VocabExerciseModel

    var body: some View {
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

/// Podpowiedź (kolejne poziomy) i — w drugiej próbie — „Pokaż odpowiedź”. Bez „Sprawdź”:
/// dotknięcie opcji jest odpowiedzią.
private struct VocabChoiceHelpButtons: View {
    let model: VocabExerciseModel

    var body: some View {
        if model.canShowMoreHints || model.phase == .retry {
            HStack(spacing: Spacing.m) {
                if model.canShowMoreHints {
                    StudyHintButton(title: model.hintShown ? "Więcej podpowiedzi" : "Podpowiedź") {
                        model.showHint()
                    }
                }
                if model.phase == .retry {
                    Button("Pokaż odpowiedź", action: model.giveUp)
                        .font(FluentFont.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: HitTarget.minimum)
                }
                Spacer(minLength: 0)
            }
        }
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
