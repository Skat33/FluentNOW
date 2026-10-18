import SwiftUI
import FluentKit

/// Etap 2 samodzielnej czytanki: pytania bez tekstu, „Zobacz wynik” po odpowiedzi na wszystkie.
struct ReadingQuestionsStage: View {
    let session: ReadingSession
    let onSelect: (Int, Int) -> Void
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            ReadingMemoryNotice(title: session.reading.title)
            ForEach(Array(session.reading.questions.enumerated()), id: \.offset) { index, question in
                ReadingQuestionCard(
                    number: index + 1,
                    question: question,
                    chosen: session.answers.studyItem(at: index) ?? -1,
                    submitted: false
                ) { (choice: Int) in
                    onSelect(index, choice)
                }
            }
            ReadingSubmitBar(unanswered: session.unansweredCount, onSubmit: onSubmit)
        }
    }
}

private struct ReadingSubmitBar: View {
    let unanswered: Int
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            PrimaryButton("Zobacz wynik", systemImage: "arrow.right", action: onSubmit)
                .disabled(unanswered > 0)
            if unanswered > 0 {
                Text("Odpowiedz na wszystkie pytania (zostało: \(unanswered)).")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

/// Etap wyników samodzielnej czytanki (zapis już się odbył w `submitReading`):
/// krótki wynik → „Sprawdź odpowiedzi” (przegląd z tekstem i dowodami, na końcu „Dalej”)
/// albo „Przejdź dalej” → podsumowanie z „Następny tekst”.
enum ReadingResultsPhase: Hashable {
    case outcome
    case review
    case done
}

struct ReadingResultsStage: View {
    let session: ReadingSession
    let isStarting: Bool
    let onNext: () -> Void
    /// Zmiana etapu wyników — rodzic przewija do początku wyników (`StudyScrollID.feedback`).
    let onPhaseChange: () -> Void

    @State private var phase: ReadingResultsPhase = .outcome

    var body: some View {
        phaseContent
            .id(StudyScrollID.feedback)
            .onChange(of: phase) { (_: ReadingResultsPhase, _: ReadingResultsPhase) in
                onPhaseChange()
            }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .outcome:
            ReadingOutcomeCard(
                correct: session.correctCount,
                total: total,
                continueTitle: "Przejdź dalej",
                onReview: { phase = .review },
                onContinue: { phase = .done }
            )
        case .review:
            ReadingReviewView(
                reading: session.reading,
                items: ReadingRecapItem.items(from: session),
                doneTitle: "Dalej",
                onDone: { phase = .done }
            )
        case .done:
            ReadingDoneView(
                correct: session.correctCount,
                total: total,
                isStarting: isStarting,
                onNext: onNext,
                onReview: { phase = .review }
            )
        }
    }

    private var total: Int {
        session.reading.questions.count
    }
}
