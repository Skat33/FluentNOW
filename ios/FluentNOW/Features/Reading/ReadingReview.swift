import SwiftUI
import FluentKit

/// Po ostatnim pytaniu czytanki (samodzielnie i w sesji łączonej): krótki wynik z wyborem
/// „Sprawdź odpowiedzi” (przegląd) albo „Przejdź dalej”. Zapis wyników się nie zmienia —
/// te widoki tylko pokazują to, co już zapisano.
struct ReadingOutcomeCard: View {
    let correct: Int
    let total: Int
    let continueTitle: String
    let onReview: () -> Void
    let onContinue: () -> Void

    var body: some View {
        Card(padding: Spacing.l, spacing: Spacing.m) {
            Text("Czytanka ukończona")
                .fluentEyebrow()
                .foregroundStyle(Palette.accent)
            ReadingOutcomeScore(correct: correct, total: total)
            PrimaryButton("Sprawdź odpowiedzi", systemImage: "text.magnifyingglass", action: onReview)
                .accessibilityHint(Text("Tekst z fragmentami-dowodami i Twoje odpowiedzi z wyjaśnieniem"))
            SecondaryButton(continueTitle, systemImage: "arrow.right", action: onContinue)
                .keyboardShortcut(.defaultAction)
        }
    }
}

/// Pierścień i „3/4 poprawnie” z krótkim komentarzem.
private struct ReadingOutcomeScore: View {
    let correct: Int
    let total: Int

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            ProgressRing(
                progress: ProgressMath.fraction(correct, of: total),
                lineWidth: 8,
                tint: Palette.success,
                accessibilityLabel: "Wynik czytanki"
            )
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(correct)/\(total) poprawnie")
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(ReadingReviewText.comment(correct: correct, total: total))
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Przegląd odpowiedzi: tekst z wyróżnionymi fragmentami-dowodami (i podświetleniami słów),
/// potem każde pytanie z zaznaczoną odpowiedzią użytkownika, poprawną odpowiedzią i wyjaśnieniem;
/// na końcu „Dalej”.
struct ReadingReviewView: View {
    let reading: Reading
    let items: [ReadingRecapItem]
    let doneTitle: String
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            ReadingStageNotice(
                systemImage: "text.magnifyingglass",
                title: "Przegląd odpowiedzi: \(correctCount)/\(items.count) poprawnie",
                message: "Najpierw tekst z zaznaczonymi fragmentami, które potwierdzają odpowiedzi. Niżej każde pytanie z Twoją odpowiedzią i wyjaśnieniem."
            )
            ReadingEvidenceSection(reading: reading, evidence: evidence)
            Text("Twoje odpowiedzi")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(rows) { (row: ReadingReviewRow) in
                ReadingReviewQuestionCard(row: row)
            }
            PrimaryButton(doneTitle, systemImage: "arrow.right", action: onDone)
                .keyboardShortcut(.defaultAction)
        }
    }

    private var correctCount: Int {
        items.filter { $0.correct }.count
    }

    private var rows: [ReadingReviewRow] {
        ReadingReviewRow.rows(reading: reading, items: items)
    }

    private var evidence: [String] {
        rows.map { $0.question.evidence }.filter { !$0.isEmpty }
    }
}

/// Jedno pytanie przeglądu (pytanie z banku + odpowiedź użytkownika).
struct ReadingReviewRow: Identifiable, Hashable {
    let id: Int
    let number: Int
    let question: ReadingQuestion
    let chosen: Int?
    let correct: Bool

    /// Pomija pozycje bez pytania w tekście (bezpieczne indeksowanie).
    static func rows(reading: Reading, items: [ReadingRecapItem]) -> [ReadingReviewRow] {
        var result: [ReadingReviewRow] = []
        for item in items {
            guard let question = reading.questions.studyItem(at: item.questionIndex) else { continue }
            let chosen: Int? = item.chosen.flatMap { (value: Int) -> Int? in
                (value >= 0 && value < question.options.count) ? value : nil
            }
            result.append(ReadingReviewRow(
                id: item.questionIndex,
                number: result.count + 1,
                question: question,
                chosen: chosen,
                correct: item.correct
            ))
        }
        return result
    }
}

/// Karta pytania w przeglądzie: odpowiedzi ABCD z zaznaczeniem, „Twoja odpowiedź”, wyjaśnienie, dowód.
private struct ReadingReviewQuestionCard: View {
    let row: ReadingReviewRow

    var body: some View {
        Card(spacing: Spacing.s) {
            ReadingReviewQuestionTitle(number: row.number, text: row.question.question, correct: row.correct)
            StudyChoiceList(
                options: row.question.options,
                selected: row.chosen,
                correct: row.question.answer,
                isRevealed: true,
                isEnabled: false,
                usesKeyboardShortcuts: false
            ) { (_: Int) -> Void in }
            ReadingReviewAnswerLines(row: row)
            if !row.question.explanation.isEmpty {
                Text(row.question.explanation)
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !row.question.evidence.isEmpty {
                ReadingEvidenceQuote(text: row.question.evidence)
            }
        }
    }
}

private struct ReadingReviewQuestionTitle: View {
    let number: Int
    let text: String
    let correct: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? Palette.success : Palette.danger)
                .accessibilityHidden(true)
            Text("\(number). \(text)")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Pytanie \(number), \(correct ? "dobrze" : "źle"): \(text)"))
        .accessibilityAddTraits(.isHeader)
    }
}

/// „Twoja odpowiedź: B. …” oraz (przy błędzie) „Poprawna odpowiedź: A. …” — tekstem, nie tylko kolorem.
private struct ReadingReviewAnswerLines: View {
    let row: ReadingReviewRow

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label {
                Text(ReadingReviewText.yourAnswer(question: row.question, chosen: row.chosen))
                    .foregroundStyle(Palette.ink)
            } icon: {
                Image(systemName: row.correct ? "checkmark" : "xmark")
                    .foregroundStyle(row.correct ? Palette.success : Palette.danger)
            }
            if !row.correct {
                Label {
                    Text(ReadingReviewText.correctAnswer(question: row.question))
                        .foregroundStyle(Palette.ink)
                } icon: {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(Palette.success)
                }
            }
        }
        .font(FluentFont.subheadline)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Cytat z tekstu (fragment-dowód) z pionową kreską akcentu.
struct ReadingEvidenceQuote: View {
    let text: String

    var body: some View {
        Text("“\(text)”")
            .font(FluentFont.reading.italic())
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, Spacing.s)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Palette.accent)
                    .frame(width: 3)
            }
            .accessibilityLabel(Text("Fragment tekstu: \(text)"))
    }
}

/// Podsumowanie samodzielnej czytanki po „Przejdź dalej” / „Dalej”: wynik, następny tekst,
/// i nadal możliwość przejrzenia odpowiedzi.
struct ReadingDoneView: View {
    let correct: Int
    let total: Int
    let isStarting: Bool
    let onNext: () -> Void
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            PracticeResultCard(
                correct: correct,
                total: total,
                message: "Czytanka zapisana w historii. Pytania o słowo w kontekście delikatnie aktualizują jego rozpoznawanie.",
                buttonTitle: "Następny tekst",
                isLoading: isStarting,
                onNext: onNext
            )
            SecondaryButton("Sprawdź odpowiedzi", systemImage: "text.magnifyingglass", action: onReview)
        }
    }
}

enum ReadingReviewText {
    /// Krótki komentarz do wyniku (spokojny ton, bez wykrzykników).
    static func comment(correct: Int, total: Int) -> String {
        guard total > 0 else { return "Brak pytań do tego tekstu." }
        if correct >= total {
            return "Wszystkie odpowiedzi poprawne. Możesz zobaczyć, które fragmenty tekstu je potwierdzają."
        }
        if correct == 0 {
            return "Tym razem się nie udało. Sprawdź odpowiedzi — fragmenty tekstu pokażą, gdzie była wskazówka."
        }
        return "Sprawdź odpowiedzi, żeby zobaczyć, które fragmenty tekstu je potwierdzają."
    }

    /// „Twoja odpowiedź: B. She was nervous.” / „Bez odpowiedzi”.
    static func yourAnswer(question: ReadingQuestion, chosen: Int?) -> String {
        guard let chosen, let option = question.options.studyItem(at: chosen) else {
            return "Bez odpowiedzi"
        }
        return "Twoja odpowiedź: \(StudyFormat.letter(chosen)). \(option)"
    }

    /// „Poprawna odpowiedź: A. …”.
    static func correctAnswer(question: ReadingQuestion) -> String {
        "Poprawna odpowiedź: \(StudyFormat.letter(question.answer)). \(question.correctOption)"
    }
}

extension ReadingRecapItem {
    /// Odpowiedzi samodzielnej czytanki (`ReadingSession.answers`, −1 = brak odpowiedzi).
    static func items(from session: ReadingSession) -> [ReadingRecapItem] {
        var result: [ReadingRecapItem] = []
        for (index, question) in session.reading.questions.enumerated() {
            let value = session.answers.studyItem(at: index) ?? -1
            result.append(ReadingRecapItem(
                questionIndex: index,
                chosen: value >= 0 ? value : nil,
                correct: value >= 0 && value == question.answer
            ))
        }
        return result
    }
}

private enum ReadingReviewPreviewData {
    static let reading = Reading(
        id: "preview",
        title: "A Day at the Airport",
        level: "A2",
        paragraphs: ["Anna arrived at the airport two hours early because she was nervous about the flight."],
        questions: [
            ReadingQuestion(question: "Why did Anna arrive early?", options: ["She was nervous.", "Her flight changed.", "She wanted coffee.", "She lost her bag."], answer: 0, explanation: "Tekst mówi, że się denerwowała.", evidence: "she was nervous about the flight")
        ]
    )
}

#Preview("Wynik i przegląd czytanki") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.l) {
            ReadingOutcomeCard(correct: 0, total: 1, continueTitle: "Przejdź dalej", onReview: {}, onContinue: {})
            ReadingReviewView(
                reading: ReadingReviewPreviewData.reading,
                items: [ReadingRecapItem(questionIndex: 0, chosen: 2, correct: false)],
                doneTitle: "Dalej",
                onDone: {}
            )
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
