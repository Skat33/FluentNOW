import SwiftUI
import FluentKit

/// Pełny ekran testu (FEEDBACK-6 K4). Zamknięcie w trakcie = przerwa: test jest zapisany i można
/// go dokończyć („Kontynuuj test”) albo porzucić z karty na ekranie Nauka.
struct StudyTestScreen: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @Environment(SpeechService.self) private var speech
    @Environment(\.dismiss) private var dismiss

    @State private var model: TestSessionModel?
    @State private var confirmsExit = false

    var body: some View {
        NavigationStack {
            Group {
                if let model {
                    TestScreenContent(model: model, onClose: close)
                } else {
                    LoadingStateView("Przygotowuję test…")
                }
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        exitTapped()
                    } label: {
                        Label("Zamknij test", systemImage: "xmark")
                    }
                    .accessibilityHint(Text("Test jest zapisany — możesz go dokończyć później."))
                }
            }
            .confirmationDialog("Przerwać test?", isPresented: $confirmsExit, titleVisibility: .visible) {
                Button("Wyjdź — dokończę później") { close() }
                Button("Porzuć test", role: .destructive) {
                    model?.abandon()
                    close()
                }
                Button("Wróć do testu", role: .cancel) {}
            } message: {
                Text("Odpowiedzi są zapisane. Po powrocie zaczniesz od bieżącego pytania.")
            }
        }
        .onDisappear {
            speech.stop()
            model?.suspend()
        }
        .task {
            guard model == nil else { return }
            let created = TestSessionModel(store: store, content: env.content)
            model = created
            await created.prepare()
        }
    }

    private func exitTapped() {
        if model?.phase == .running {
            confirmsExit = true
        } else {
            close()
        }
    }

    private func close() {
        speech.stop()
        dismiss()
    }
}

/// Treść zależna od etapu: przygotowanie, pytania, wynik, brak testu.
private struct TestScreenContent: View {
    let model: TestSessionModel
    let onClose: () -> Void

    var body: some View {
        switch model.phase {
        case .preparing:
            LoadingStateView("Układam test na Twoim poziomie…")
        case .running:
            TestRunView(model: model)
        case .result:
            TestResultView(model: model, onClose: onClose)
        case .unavailable(let message):
            EmptyStateView(
                systemImage: "checklist",
                title: "Test niedostępny",
                message: message,
                actionTitle: "Wróć",
                action: onClose
            )
        }
    }
}

/// Przebieg testu: postęp i zegar, pytanie, „Dalej” / „Nie wiem”. Bez cofania.
private struct TestRunView: View {
    let model: TestSessionModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Color.clear.frame(height: 0).id(StudyScrollID.top)
                    if let session = model.session {
                        TestProgressHeader(session: session, shownAt: model.shownAt)
                    }
                    TestQuestionArea(model: model)
                    TestRunFooter(model: model)
                }
                .frame(maxWidth: Spacing.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: model.session?.index) { (_: Int?, _: Int?) in
                proxy.scrollTo(StudyScrollID.top, anchor: .top)
            }
        }
        .onChange(of: model.store.revision) { (_: Int, _: Int) in
            model.sync()
        }
        .onChange(of: model.vocabulary?.isFinished) { (_: Bool?, finished: Bool?) in
            // Enter w polu tekstowym albo ostatnia para planszy kończą zadanie — od razu dalej.
            guard finished == true else { return }
            withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
                model.commitIfFinished()
            }
        }
    }
}

/// Bieżące pytanie (zadanie słownikowe, gramatyka albo czytanka).
private struct TestQuestionArea: View {
    let model: TestSessionModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let vocabulary = model.vocabulary {
            VocabExerciseView(model: vocabulary, confidence: nil, onFlashcardDecision: nil)
                .id(vocabulary.key)
                .transition(Motion.contentTransition(reduceMotion: reduceMotion))
        } else if let question = model.question {
            if model.showsReadingPassage, let reading = model.session?.reading {
                TestReadingPassage(reading: reading) {
                    model.beginReadingQuestions()
                }
            } else {
                TestTextQuestionView(model: question, readingTitle: model.session?.reading?.title)
                    .id(question.key)
                    .transition(Motion.contentTransition(reduceMotion: reduceMotion))
            }
        } else if model.missingQuestion {
            TestMissingQuestionCard()
        } else {
            LoadingStateView("Przygotowuję pytanie…")
        }
    }
}

/// „Dalej” i „Nie wiem” (bez sprawdzania i bez cofania) + zasady testu.
private struct TestRunFooter: View {
    let model: TestSessionModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if !model.showsReadingPassage {
                PrimaryButton("Dalej", systemImage: "arrow.right") {
                    withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
                        model.advance()
                    }
                }
                .disabled(!model.canAdvance)
                .keyboardShortcut(.defaultAction)
                if !model.missingQuestion {
                    SecondaryButton("Nie wiem", systemImage: "questionmark") {
                        withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
                            model.giveUp()
                        }
                    }
                    .accessibilityHint(Text("Pytanie zostanie policzone jako błędne i test przejdzie dalej."))
                }
            }
            Text(hint)
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var hint: String {
        if model.vocabulary?.type == .matchPairs {
            return "Połącz wszystkie pary — po ostatniej test przejdzie dalej. Bez podpowiedzi i bez cofania."
        }
        return "Bez podpowiedzi i bez cofania. Poprawne odpowiedzi zobaczysz w wyniku na końcu."
    }
}

/// Słowo z pytania usunięto w trakcie (np. na innym urządzeniu).
private struct TestMissingQuestionCard: View {
    var body: some View {
        Card(style: .tinted(.info)) {
            Text("To pytanie nie jest już dostępne")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
            Text("Słowo zostało usunięte ze słownika. Dotknij „Dalej” — pytanie zostanie pominięte.")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview("Test") {
    StudyTestScreen()
        .fluentPreviewEnvironment()
}
