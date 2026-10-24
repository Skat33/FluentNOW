import SwiftUI
import FluentKit

/// Postęp testu: „Pytanie 5 z 30 · Uzupełnij zdanie”, pasek i orientacyjny zegar (bez limitu).
struct TestProgressHeader: View {
    let session: AssessmentSession
    let shownAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(blockName)
                    .fluentEyebrow()
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                Spacer(minLength: Spacing.xs)
                Text("\(position) / \(total)")
                    .font(FluentFont.numberSmall)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
            }
            LinearProgressBar(progress: ProgressMath.fraction(session.index, of: total))
            TestClockLine(activeSeconds: session.activeSeconds, shownAt: shownAt, plannedMinutes: plannedMinutes)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Test, \(blockName)"))
        .accessibilityValue(Text("Pytanie \(position) z \(total)"))
    }

    private var total: Int { max(session.total, 1) }
    private var position: Int { min(session.index + 1, total) }
    private var plannedMinutes: Int { max(1, Int((Double(session.plannedSeconds) / 60).rounded())) }
    private var blockName: String { session.currentQuestion?.block.namePl ?? "Test" }
}

/// „Czas: 6 min · zaplanowano ok. 19 min” — odświeżane co kilkanaście sekund.
private struct TestClockLine: View {
    let activeSeconds: Double
    let shownAt: Date
    let plannedMinutes: Int

    var body: some View {
        TimelineView(.periodic(from: shownAt, by: 15)) { context in
            Label(text(at: context.date), systemImage: "clock")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private func text(at date: Date) -> String {
        let seconds = max(0, activeSeconds) + max(0, date.timeIntervalSince(shownAt))
        let minutes = seconds.isFinite ? Int(seconds / 60) : 0
        return "Czas: \(minutes) min · zaplanowano ok. \(plannedMinutes) min (bez limitu)"
    }
}

/// Czytanka: najpierw sam tekst (bez limitu czasu i bez tłumaczeń słów), potem pytania z pamięci.
struct TestReadingPassage: View {
    let reading: Reading
    let onReady: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ReadingStageNotice(
                systemImage: "book",
                title: "Najpierw przeczytaj tekst",
                message: "Czytaj w swoim tempie. Potem tekst zniknie i odpowiesz na \(questionCount) \(StudyFormat.plural(questionCount, one: "pytanie", few: "pytania", many: "pytań")) z pamięci."
            )
            Card(spacing: Spacing.s) {
                HStack(alignment: .firstTextBaseline) {
                    Text(reading.title)
                        .font(FluentFont.title)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: Spacing.xs)
                    LevelBadge(level: reading.level)
                }
                ForEach(Array(reading.paragraphs.enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .font(FluentFont.body)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            PrimaryButton("Jestem gotowy na pytania", systemImage: "checkmark", action: onReady)
        }
    }

    private var questionCount: Int { max(1, reading.questions.count) }
}

/// Pytanie z gramatyki albo do czytanki: wybór ABCD zaznaczany, zatwierdzany przez „Dalej”.
struct TestTextQuestionView: View {
    let model: TestQuestionModel
    let readingTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if isReading, model.task.readingIndex == 0 {
                ReadingMemoryNotice(title: readingTitle ?? "Tekst")
            }
            Card(spacing: Spacing.m) {
                StudyExerciseKindBanner(isReading ? .reading : .grammar, detail: detail)
                Text(model.question.prompt)
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !model.question.context.isEmpty {
                    PracticeContextText(context: model.question.context)
                }
                StudyChoiceList(
                    options: model.question.options,
                    selected: model.selected,
                    correct: nil,
                    isRevealed: false,
                    isEnabled: !model.isAnswered
                ) { (index: Int) in
                    model.choose(index)
                }
            }
        }
    }

    private var isReading: Bool { model.task.block == .reading }

    private var detail: String {
        if isReading, let index = model.task.readingIndex {
            return "Pytanie \(index + 1) do tekstu"
        }
        return "Wybierz odpowiedź"
    }
}
