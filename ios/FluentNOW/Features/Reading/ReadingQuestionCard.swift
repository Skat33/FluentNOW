import SwiftUI
import FluentKit

/// Pytanie do czytanki: odpowiedzi ABCD, po sprawdzeniu wynik, wyjaśnienie i fragment-dowód z tekstu.
struct ReadingQuestionCard: View {
    let number: Int
    let question: ReadingQuestion
    let chosen: Int
    let submitted: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        Card(spacing: Spacing.m) {
            StudyExerciseKindBanner(.reading, detail: "Rozumienie tekstu")
            Text("\(number). \(question.question)")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            StudyChoiceList(
                options: question.options,
                selected: chosen >= 0 ? chosen : nil,
                correct: question.answer,
                isRevealed: submitted,
                isEnabled: !submitted,
                usesKeyboardShortcuts: false,
                onSelect: onSelect
            )
            if submitted {
                ReadingQuestionResult(question: question, chosen: chosen)
            }
        }
        .sensoryFeedback(FluentHaptic.selection, trigger: chosen)
    }
}

private struct ReadingQuestionResult: View {
    let question: ReadingQuestion
    let chosen: Int

    var body: some View {
        let correct = chosen == question.answer
        FeedbackPanel(
            kind: correct ? .correct : .incorrect,
            title: correct ? "Dobrze!" : "Nie tym razem",
            message: correct ? nil : "Poprawna odpowiedź: **\(StudyFormat.letter(question.answer)). \(VocabFeedbackSummary.escaped(question.correctOption))**",
            playsHaptic: false
        ) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                StudyExplanationDisclosure(correct: correct) {
                    if !question.explanation.isEmpty {
                        Text(question.explanation)
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !question.evidence.isEmpty {
                        Text("“\(question.evidence)”")
                            .font(FluentFont.reading.italic())
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, Spacing.s)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(Palette.accent)
                                    .frame(width: 3)
                            }
                            .accessibilityLabel(Text("Fragment tekstu: \(question.evidence)"))
                    }
                }
                StudyReportButton(draft: StudyReportDraft(
                    mode: "Czytanie",
                    question: question.question,
                    answer: question.options.studyItem(at: chosen) ?? "",
                    expected: [question.correctOption]
                ))
            }
        }
    }
}

#Preview("Pytanie do czytanki") {
    ScrollView {
        VStack(spacing: Spacing.m) {
            ReadingQuestionCard(
                number: 1,
                question: ReadingQuestion(question: "Why did Anna arrive early?", options: ["She was nervous.", "Her flight changed.", "She wanted coffee.", "She lost her bag."], answer: 0, explanation: "Tekst mówi, że się denerwowała.", evidence: "She was nervous about the flight."),
                chosen: 2,
                submitted: true
            ) { _ in }
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
