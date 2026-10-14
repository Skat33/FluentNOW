import SwiftUI
import FluentKit

/// Ekran sesji łączonej (pełny ekran). Kolejność zadań jest zapisana — wznowienie działa zawsze.
struct CombinedSessionView: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @Environment(AssistantService.self) private var assistant

    @State private var model: CombinedSessionModel?

    var body: some View {
        Group {
            if let model {
                CombinedSessionContent(model: model)
            } else {
                LoadingStateView("Przygotowuję sesję…")
            }
        }
        .onDisappear {
            model?.suspend()
        }
        .task {
            if model == nil {
                let created = CombinedSessionModel(store: store, content: env.content, assistant: assistant)
                model = created
                await created.prepare()
            }
        }
    }
}

private struct CombinedSessionContent: View {
    let model: CombinedSessionModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .onChange(of: model.canAdvance) { _, ready in
                // Fiszka przechodzi dalej sama — nie przewijamy do (nieistniejącego) wyniku.
                guard ready, model.vocabulary?.type != ExerciseType.flashcard else { return }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion)) {
                        proxy.scrollTo(StudyScrollID.feedback, anchor: .top)
                    }
                }
            }
            .onChange(of: model.session?.index) { _, _ in
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
            if session.completedAt != nil {
                StudySummaryView(data: model.summary(), onFinish: finish)
            } else {
                StudySessionHeader(
                    title: session.currentTask?.mode.namePl ?? "Sesja łączona",
                    index: session.index,
                    total: session.tasks.count
                )
                currentTaskView(for: session)
                if model.canAdvance {
                    PrimaryButton(
                        session.index + 1 < session.tasks.count ? "Następne zadanie" : "Zakończ sesję",
                        systemImage: "arrow.right"
                    ) {
                        advance()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                Text(session.random ? "Kolejność losowa · zapisana na wypadek przerwy." : "Według rodzaju · kolejność zapisana na wypadek przerwy.")
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
        } else {
            EmptyStateView(
                systemImage: "checkmark.circle",
                title: "Brak aktywnej sesji",
                message: "Wybierz rodzaje ćwiczeń na ekranie Nauka.",
                actionTitle: "Wróć"
            ) {
                dismiss()
            }
        }
    }

    @ViewBuilder
    private func currentTaskView(for session: CombinedSession) -> some View {
        if let vocabulary = model.vocabulary {
            // Fiszka: „Pamiętam” / „Jeszcze nie” zapisuje i od razu przechodzi dalej (bez panelu wyniku).
            VocabExerciseView(model: vocabulary, onFlashcardDecision: { flashcardDecided() })
                .id(vocabulary.key)
                .transition(Motion.contentTransition(reduceMotion: reduceMotion))
        } else if let question = model.question {
            CombinedQuestionView(model: question)
                .id(question.key)
                .transition(Motion.contentTransition(reduceMotion: reduceMotion))
        } else if model.missingTask {
            StudyMissingWordCard {
                advance()
            }
        }
    }

    private func advance() {
        withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            model.advance()
        }
    }

    private func flashcardDecided() {
        flashcardCommits += 1
        advance()
    }

    private func finish() {
        model.finish()
        dismiss()
    }
}

#Preview("Sesja łączona") {
    NavigationStack {
        CombinedSessionView()
    }
    .fluentPreviewEnvironment()
}
