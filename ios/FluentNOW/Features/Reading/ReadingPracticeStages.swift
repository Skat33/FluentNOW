import SwiftUI
import FluentKit

/// Etap 2 samodzielnej czytanki: pytania bez tekstu, „Sprawdź odpowiedzi” po odpowiedzi na wszystkie.
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
            PrimaryButton("Sprawdź odpowiedzi", systemImage: "arrow.right", action: onSubmit)
                .disabled(unanswered > 0)
            if unanswered > 0 {
                Text("Odpowiedz na wszystkie pytania (zostało: \(unanswered)).")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

/// Etap 3: wynik, pytania z wyjaśnieniem i dowodem, tekst z wyróżnionymi fragmentami-dowodami.
struct ReadingResultsStage: View {
    let session: ReadingSession
    let isStarting: Bool
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            PracticeResultCard(
                correct: session.correctCount,
                total: session.reading.questions.count,
                message: "Pytania o słowo w kontekście delikatnie aktualizują jego rozpoznawanie.",
                buttonTitle: "Następny tekst",
                isLoading: isStarting,
                onNext: onNext
            )
            .id(StudyScrollID.feedback)
            ForEach(Array(session.reading.questions.enumerated()), id: \.offset) { index, question in
                ReadingQuestionCard(
                    number: index + 1,
                    question: question,
                    chosen: session.answers.studyItem(at: index) ?? -1,
                    submitted: true
                ) { (_: Int) in }
            }
            ReadingEvidenceSection(reading: session.reading, evidence: evidence)
        }
    }

    private var evidence: [String] {
        session.reading.questions.map { $0.evidence }.filter { !$0.isEmpty }
    }
}
