import SwiftUI
import FluentKit

/// Karta zadania słownikowego — wspólna dla sesji słownictwa i sesji łączonej.
///
/// - `confidence`: wybór pewności (sesja słownictwa); `nil` w sesji łączonej (pewność 2 jak strona);
/// - `onFlashcardDecision`: wołane po „Pamiętam” / „Jeszcze nie pamiętam” — obie sesje od razu zapisują
///   odpowiedź i przechodzą do następnego zadania (bez panelu wyniku i przewijania).
struct VocabExerciseView: View {
    let model: VocabExerciseModel
    var confidence: Binding<ConfidenceLevel>?
    var onFlashcardDecision: (() -> Void)?

    @FocusState private var answerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Card(spacing: Spacing.m) {
                StudyExerciseKindBanner(
                    (model.type == .dictation || model.type == .listeningChoice) ? StudyExerciseKindBanner.Kind.listening : .vocabulary,
                    detail: model.content.mode == .pairs ? StudyMode.pairs.namePl : model.type.shortNamePl
                )
                VocabMetaRow(model: model)
                VocabPromptView(model: model)
                if showsSentenceAudio {
                    StudySentenceAudioButton(
                        text: model.content.sentenceAudio(solved: model.isFinished || model.revealed),
                        solved: model.isFinished || model.revealed
                    )
                }
                VocabExerciseInput(
                    model: model,
                    confidence: confidence,
                    onFlashcardDecision: onFlashcardDecision,
                    focus: $answerFocused
                )
            }
            .modifier(VocabFlashcardSwipe(model: model, onDecision: onFlashcardDecision))

            // Test (K4): bez panelu wyniku — ekran testu od razu przechodzi dalej.
            if model.isFinished && !model.isAssessment && !(model.type == .flashcard && onFlashcardDecision != nil) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    VocabFeedbackView(model: model)
                    if let confidence, model.type != .flashcard {
                        ConfidencePicker(selection: confidence)
                    }
                }
                .id(StudyScrollID.feedback)
                .transition(.opacity)
            }
        }
        .task(id: model.key) {
            guard model.inputStyle == .typing, !model.isFinished else { return }
            // Fokus po pojawieniu się zadania (klawiatura gotowa od razu).
            try? await Task.sleep(nanoseconds: 120_000_000)
            answerFocused = true
        }
        .onChange(of: model.inputStyle) { (_: VocabInputStyle, style: VocabInputStyle) in
            // „Pokaż warianty” chowa pole — klawiatura znika razem z nim.
            if style != .typing {
                answerFocused = false
            }
        }
        .onChange(of: model.phase) { _, phase in
            switch phase {
            case .retry:
                answerFocused = model.inputStyle == .typing
            case .finished:
                answerFocused = false
                announceResult()
            default:
                break
            }
        }
    }

    /// „Posłuchaj zadania” pod treścią: nie przy dyktandzie i słuchaniu (własne odtwarzanie), zdjęciach
    /// i parach (bez zdania); w rozsypance dopiero po odpowiedzi (nagranie zdradziłoby kolejność).
    private var showsSentenceAudio: Bool {
        switch model.type {
        case .dictation, .picture, .matchPairs, .listeningChoice: return false
        case .scramble: return model.isFinished
        case .flashcard, .recall, .cloze, .meaning: return true
        }
    }

    private func announceResult() {
        // Fiszka z obsługą decyzji przechodzi od razu dalej — bez komunikatu wyniku.
        if model.type == .flashcard && onFlashcardDecision != nil { return }
        // Test: bez informacji poprawne/błędne.
        if model.isAssessment { return }
        let summary = VocabFeedbackSummary(model: model)
        AccessibilityNotification.Announcement(summary.title).post()
    }
}

/// Część odpowiedzi zależna od typu: fiszka (odsłoń / pamiętam), zdjęcia (wybór w siatce —
/// nic więcej), pozostałe — pole odpowiedzi.
private struct VocabExerciseInput: View {
    let model: VocabExerciseModel
    let confidence: Binding<ConfidenceLevel>?
    let onFlashcardDecision: (() -> Void)?
    let focus: FocusState<Bool>.Binding

    var body: some View {
        // Zawsze jeden mechanizm odpowiedzi (H1): opcje znaczenia widoczne → tylko wybór.
        switch model.inputStyle {
        case .flashcard:
            VocabFlashcardActions(model: model, confidence: confidence, onDecision: onFlashcardDecision)
        case .picture:
            EmptyView()
        case .choice:
            VocabMeaningChoiceArea(model: model)
        case .typing:
            if !model.isFinished {
                VocabAnswerArea(model: model, focus: focus)
            }
        case .scramble:
            VocabScrambleArea(model: model)
        case .pairs:
            VocabPairsBoard(model: model)
        case .listening:
            VocabListeningChoiceArea(model: model)
        }
    }
}

/// Kolekcja · poziom · rejestr + licznik czasu.
private struct VocabMetaRow: View {
    let model: VocabExerciseModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(model.content.metaLine)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(2)
            Spacer(minLength: Spacing.xs)
            StudyElapsedClock(startedAt: model.startedAt, stoppedSeconds: model.stoppedSeconds)
        }
    }
}

/// Fiszka: „Odsłoń znaczenie” → pewność → „Jeszcze nie pamiętam” / „Pamiętam”.
private struct VocabFlashcardActions: View {
    let model: VocabExerciseModel
    let confidence: Binding<ConfidenceLevel>?
    let onDecision: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if model.isFinished {
            EmptyView()
        } else if !model.revealed {
            SecondaryButton("Odsłoń znaczenie", systemImage: "eye") {
                withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
                    model.reveal()
                }
            }
            .keyboardShortcut(.defaultAction)
        } else {
            VStack(alignment: .leading, spacing: Spacing.s) {
                if let confidence {
                    ConfidencePicker(selection: confidence)
                }
                StudyPronunciationButton(expected: model.content.word.en)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Spacing.s) { buttons }
                    VStack(spacing: Spacing.xs) { buttons }
                }
                Text("Możesz też przesunąć kartę: w prawo — pamiętam, w lewo — jeszcze nie.")
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        SecondaryButton("Jeszcze nie pamiętam") { decide(false) }
        PrimaryButton("Pamiętam", systemImage: "checkmark") { decide(true) }
            .keyboardShortcut(.defaultAction)
    }

    private func decide(_ remembered: Bool) {
        model.finishFlashcard(remembered: remembered)
        onDecision?()
    }
}

/// Gest przesunięcia odsłoniętej fiszki (w prawo = pamiętam, w lewo = jeszcze nie).
private struct VocabFlashcardSwipe: ViewModifier {
    let model: VocabExerciseModel
    let onDecision: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    private static let threshold: CGFloat = 110

    private var isActive: Bool {
        model.type == .flashcard && model.revealed && !model.isFinished
    }

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset / 40)))
            .opacity(1 - min(0.4, Double(abs(offset)) / 600))
            .simultaneousGesture(drag, including: isActive ? .all : .subviews)
        // Haptyka przejścia jest na ekranie sesji (karta znika od razu po decyzji).
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                // Tylko wyraźnie poziomy ruch — przewijanie w pionie zostaje dla ScrollView.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                offset = value.translation.width
            }
            .onEnded { value in
                let width = value.translation.width
                if abs(width) >= VocabFlashcardSwipe.threshold && abs(width) > abs(value.translation.height) {
                    model.finishFlashcard(remembered: width > 0)
                    offset = 0
                    onDecision?()
                } else {
                    withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
                        offset = 0
                    }
                }
            }
    }
}
