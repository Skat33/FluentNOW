import SwiftUI
import FluentKit

/// Ekran sesji słownictwa (pełny ekran). Zamknięcie zostawia sesję w stanie — można ją wznowić.
struct VocabSessionView: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @Environment(AssistantService.self) private var assistant

    @State private var model: VocabSessionModel?

    var body: some View {
        Group {
            if let model {
                VocabSessionContent(model: model)
            } else {
                LoadingStateView("Przygotowuję sesję…")
            }
        }
        .onDisappear {
            model?.suspend()
        }
        .task {
            if model == nil {
                let created = VocabSessionModel(store: store, content: env.content, assistant: assistant)
                model = created
                await created.prepare()
            }
        }
    }
}

private struct VocabSessionContent: View {
    @Bindable var model: VocabSessionModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExtending = false
    @State private var notice: String?
    /// Licznik decyzji na fiszkach — krótka haptyka przy przejściu dalej.
    @State private var flashcardCommits = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Color.clear.frame(height: 0).id(StudyScrollID.top)
                    content
                }
                .frame(maxWidth: Spacing.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.exercise?.phase) { _, phase in
                // Fiszka przechodzi dalej od razu — bez przewijania do wyniku.
                guard phase == .finished, model.exercise?.type != ExerciseType.flashcard else { return }
                scroll(proxy, to: StudyScrollID.feedback, anchor: .top)
            }
            .onChange(of: model.exercise?.key) { _, _ in
                proxy.scrollTo(StudyScrollID.top, anchor: .top)
            }
        }
        .onChange(of: model.store.revision) { _, _ in
            model.sync()
        }
        .fluentSensoryFeedback(FluentHaptic.swipeCommit, trigger: flashcardCommits)
    }

    @ViewBuilder
    private var content: some View {
        if let session = model.session {
            if session.isFinished {
                StudySummaryView(
                    data: model.summary(),
                    onExtend: extend,
                    isExtending: isExtending,
                    onFinish: finish
                )
                if let notice {
                    Text(notice)
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                StudySessionHeader(title: "Twój mały krok", index: session.index, total: session.tasks.count)
                if let exercise = model.exercise {
                    VocabExerciseView(
                        model: exercise,
                        confidence: $model.confidence,
                        onFlashcardDecision: { flashcardDecided() }
                    )
                    .id(exercise.key)
                    .transition(Motion.contentTransition(reduceMotion: reduceMotion))
                    if exercise.isFinished && exercise.type != .flashcard {
                        PrimaryButton("Dalej", systemImage: "arrow.right") { advance() }
                            .keyboardShortcut(.defaultAction)
                    }
                } else if model.missingTask {
                    StudyMissingWordCard(onSkip: { model.skipMissing() })
                }
                Text("Postęp zapisujemy na urządzeniu po każdym zadaniu.")
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
        } else {
            EmptyStateView(
                systemImage: "checkmark.circle",
                title: "Brak aktywnej sesji",
                message: "Wybierz rodzaj ćwiczeń na ekranie Nauka.",
                actionTitle: "Wróć"
            ) {
                dismiss()
            }
        }
    }

    private func advance() {
        withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            model.commit()
        }
    }

    /// „Pamiętam” / „Jeszcze nie” — zapis (`Scheduler.recordAnswer`) i od razu następne zadanie.
    private func flashcardDecided() {
        flashcardCommits += 1
        advance()
    }

    private func extend() {
        guard !isExtending else { return }
        isExtending = true
        notice = nil
        Task { @MainActor in
            let message = await model.extend()
            notice = message
            isExtending = false
        }
    }

    private func finish() {
        model.finish()
        dismiss()
    }

    private func scroll(_ proxy: ScrollViewProxy, to id: String, anchor: UnitPoint) {
        Task { @MainActor in
            // Chwila na schowanie klawiatury, potem przewinięcie do wyniku (jak use-answer-scroll).
            try? await Task.sleep(nanoseconds: 180_000_000)
            withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion)) {
                proxy.scrollTo(id, anchor: anchor)
            }
        }
    }
}

/// Zadanie wskazuje słowo, którego już nie ma.
struct StudyMissingWordCard: View {
    let onSkip: () -> Void

    var body: some View {
        Card(style: .tinted(.info)) {
            Text("To słowo nie jest już dostępne")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
            Text("Mogło zostać usunięte lub zarchiwizowane. Pomiń zadanie, a sesja potoczy się dalej.")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryButton("Pomiń zadanie", systemImage: "forward", action: onSkip)
        }
    }
}

#Preview("Sesja słownictwa") {
    NavigationStack {
        VocabSessionView()
    }
    .fluentPreviewEnvironment()
}
