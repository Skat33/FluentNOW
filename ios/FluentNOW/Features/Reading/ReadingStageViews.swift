import SwiftUI
import FluentKit

/// Etap 1 (G1): sam tekst, bez limitu czasu i bez pytań; na dole „Jestem gotowy na pytania”.
/// Wspólny dla samodzielnego czytania i bloku czytanki w sesji łączonej.
struct ReadingFirstStage: View {
    let reading: Reading
    let questionCount: Int
    let onReady: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ReadingStageNotice(
                systemImage: "book",
                title: "Najpierw przeczytaj tekst",
                message: "Czytaj w swoim tempie — nie ma limitu czasu. Potem tekst zniknie i odpowiesz na \(questionCount) \(StudyFormat.plural(questionCount, one: "pytanie", few: "pytania", many: "pytań")) z pamięci."
            )
            ReadingPassageCard(reading: reading)
            PrimaryButton("Jestem gotowy na pytania", systemImage: "checkmark", action: onReady)
            Text("Po odpowiedziach zobaczysz wynik i możesz wrócić do tekstu — z zaznaczonymi fragmentami, które potwierdzają odpowiedzi.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Etap 2: informacja, że tekst jest ukryty.
struct ReadingMemoryNotice: View {
    let title: String

    var body: some View {
        ReadingStageNotice(
            systemImage: "eye.slash",
            title: "Odpowiadaj z pamięci",
            message: "„\(title)” jest teraz ukryty. Po odpowiedziach możesz go przejrzeć z fragmentami-dowodami."
        )
    }
}

/// Krótka karta informacyjna etapu czytania.
struct ReadingStageNotice: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: systemImage)
                .font(FluentFont.title)
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                Text(message)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .fluentCardBackground(.tinted(.accent))
        .accessibilityElement(children: .combine)
    }
}

/// Etap 3: tekst znowu widoczny, z wyróżnionymi fragmentami-dowodami.
struct ReadingEvidenceSection: View {
    let reading: Reading
    let evidence: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Tekst z fragmentami-dowodami")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Zaznaczone fragmenty potwierdzają poprawne odpowiedzi.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
            ReadingPassageCard(reading: reading, evidence: evidence)
        }
    }
}

/// Odpowiedź na jedno pytanie czytanki (wynik i przegląd: blok w sesji łączonej i samodzielnie).
struct ReadingRecapItem: Hashable {
    /// Indeks pytania w `reading.questions`.
    let questionIndex: Int
    let chosen: Int?
    let correct: Bool

    /// Zapisane odpowiedzi wcześniejszych pytań bloku (przed bieżącym zadaniem).
    static func earlier(in session: CombinedSession, block: CombinedReadingBlock?) -> [ReadingRecapItem] {
        guard let block else { return [] }
        var items: [ReadingRecapItem] = []
        for taskIndex in block.taskIndices.prefix(block.position) {
            guard let task = session.tasks.studyItem(at: taskIndex)?.questionTask,
                  let questionIndex = task.readingIndex else { continue }
            let answer = session.answers.studyItem(at: taskIndex) ?? nil
            items.append(ReadingRecapItem(
                questionIndex: questionIndex,
                chosen: answer.flatMap { Int($0.value) },
                correct: answer?.correct ?? false
            ))
        }
        return items
    }
}
