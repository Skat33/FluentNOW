import SwiftUI
import FluentKit

/// Pytanie sesji łączonej: kontekst, odsłuch, odpowiedzi ABCD lub wpisywanie, wynik.
struct CombinedQuestionView: View {
    @Bindable var model: CombinedQuestionModel

    @FocusState private var focused: Bool

    var body: some View {
        Group {
            // Czytanka (G1): najpierw sam tekst; pytania potem bez tekstu (wraca po ostatnim pytaniu bloku).
            if model.isReadingPassage, let reading = model.task.reading {
                ReadingFirstStage(reading: reading, questionCount: model.readingBlock?.taskIndices.count ?? 1) {
                    model.beginReadingQuestions()
                }
            } else {
                questionContent
            }
        }
        .task(id: model.key) {
            guard model.isInput, !model.isAnswered else { return }
            try? await Task.sleep(nanoseconds: 120_000_000)
            focused = true
        }
        .onChange(of: model.isAnswered) { _, answered in
            guard answered else { return }
            focused = false
            let correct = model.outcome?.correct ?? false
            AccessibilityNotification.Announcement(correct ? "Dobrze" : "Nie tym razem. Poprawnie: \(model.expected)").post()
        }
    }

    private var questionContent: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if model.task.reading != nil, model.readingBlock?.opensBlock == true, !model.isAnswered {
                ReadingMemoryNotice(title: model.task.reading?.title ?? "Tekst")
            }
            Card(spacing: Spacing.m) {
                StudyExerciseKindBanner(kind, detail: bannerDetail)
                HStack {
                    LevelBadge(level: model.task.level)
                    Spacer(minLength: Spacing.xs)
                    StudyElapsedClock(startedAt: model.startedAt, stoppedSeconds: model.stoppedSeconds)
                }
                Text(model.question.prompt)
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.question.context.isEmpty {
                    PracticeContextText(context: model.question.context)
                }
                StudySentenceAudioButton(text: model.audioText, solved: model.isAnswered)
                if model.isInput {
                    CombinedInputArea(model: model, focus: $focused)
                } else {
                    StudyChoiceList(
                        options: model.question.options,
                        selected: model.selected,
                        correct: model.question.answer,
                        isRevealed: model.isAnswered,
                        isEnabled: !model.isAnswered
                    ) { index in
                        model.choose(index)
                    }
                }
            }
            if model.isAnswered {
                CombinedQuestionFeedback(model: model)
                    .id(StudyScrollID.feedback)
                    .transition(.opacity)
            }
            if let reading = model.task.reading, let recap = model.readingRecap {
                ReadingRecapView(reading: reading, items: recap)
                    .transition(.opacity)
            }
        }
    }

    private var kind: StudyExerciseKindBanner.Kind {
        if model.task.reading != nil { return .reading }
        return model.question.category == .idiom ? .idioms : .grammar
    }

    /// Czytanka: „Pytanie 2 z 4 do tekstu” (pytania jednego tekstu idą po kolei).
    private var bannerDetail: String {
        if let reading = model.task.reading, let index = model.task.readingIndex {
            let total = min(reading.questions.count, CombinedSessionBuilder.maxReadingQuestions)
            return "Pytanie \(index + 1) z \(max(total, index + 1)) do tekstu"
        }
        return model.isInput ? "Wpisz odpowiedź" : "Wybierz odpowiedź"
    }
}

/// Wpisywanie odpowiedzi (miks językowy, produkcja w sesji łączonej).
private struct CombinedInputArea: View {
    @Bindable var model: CombinedQuestionModel
    let focus: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StudyAnswerField(
                text: $model.written,
                placeholder: model.task.production != nil ? "Wpisz formę czasownika…" : "Wpisz odpowiedź…",
                language: model.question.category == .idiom ? .polish : .english,
                isEnabled: !model.isAnswered,
                focus: focus,
                onSubmit: model.checkWritten
            )
            if model.hintShown && !model.isAnswered {
                StudyHintBox(lines: model.visibleHints)
            }
            if !model.isAnswered {
                HStack(spacing: Spacing.s) {
                    if model.canShowMoreHints {
                        StudyHintButton(title: model.hintShown ? "Więcej podpowiedzi" : "Podpowiedź") {
                            model.showHint()
                        }
                    }
                    Spacer(minLength: Spacing.xs)
                    PrimaryButton("Sprawdź", systemImage: "arrow.right", fillsWidth: false, action: model.checkWritten)
                        .disabled(!model.canCheck)
                }
            }
        }
    }
}

/// Wynik pytania: poprawna odpowiedź, diagnoza (produkcja), wyjaśnienie i tłumaczenie.
private struct CombinedQuestionFeedback: View {
    let model: CombinedQuestionModel

    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        let correct = model.outcome?.correct ?? false
        FeedbackPanel(
            kind: kindValue(correct: correct),
            title: title(correct: correct),
            message: "Poprawna odpowiedź: **\(VocabFeedbackSummary.escaped(model.expected))**",
            playsHaptic: preferences.hapticsEnabled
        ) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let item = model.task.production {
                    if let diagnosis = model.production?.diagnosis, !correct || diagnosis == .spelling {
                        TagChip(diagnosis.namePl, systemImage: "stethoscope", tone: correct ? .warning : .danger)
                    }
                    Text("Konstrukcja: **\(item.rule)**")
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.ink)
                }
                StudyExplanationDisclosure(correct: correct) {
                    if let explanation = model.outcome?.explanation, !explanation.isEmpty {
                        Text(explanation)
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !model.question.translation.isEmpty {
                        Text(model.question.translation)
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                StudyReportButton(draft: model.reportDraft)
            }
        }
    }

    private func kindValue(correct: Bool) -> FeedbackKind {
        guard correct else { return .incorrect }
        if let result = model.production, !result.spellingCorrect { return .almost }
        return model.outcome?.hinted == true ? .almost : .correct
    }

    private func title(correct: Bool) -> String {
        guard correct else { return "Nie tym razem" }
        if let result = model.production, !result.spellingCorrect { return "Zaliczone — popraw pisownię" }
        return model.outcome?.hinted == true ? "Udało się z podpowiedzią" : "Dobrze!"
    }
}
