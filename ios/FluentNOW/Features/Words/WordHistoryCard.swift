import SwiftUI
import FluentKit

/// Jedna odpowiedź w historii słowa (lekki model liczony poza głównym wątkiem).
struct WordHistoryItem: Identifiable, Hashable, Sendable {
    let id: String
    let at: Timestamp
    let skillName: String
    let correct: Bool
    let hinted: Bool
    let meaning: String
    let fromReading: Bool
}

enum WordHistoryBuilder {
    static let limit = 20

    static func items(state: LearnerState, wordID: String) -> [WordHistoryItem] {
        let word = state.word(id: wordID)
        let reviews = state.reviews
            .filter { $0.wordId == wordID && !$0.demo }
            .sorted { $0.at > $1.at }
            .prefix(limit)
        return reviews.map { review in
            WordHistoryItem(
                id: review.id,
                at: review.at,
                skillName: review.skill.namePl,
                correct: review.correct,
                hinted: review.hint,
                meaning: word?.meaning(id: review.meaningId)?.translation ?? "",
                fromReading: review.source == .reading
            )
        }
    }
}

/// Historia odpowiedzi słowa (ostatnie 20).
struct WordHistoryCard: View {
    let wordID: String

    @Environment(LearningStore.self) private var store
    @State private var items: [WordHistoryItem]?

    var body: some View {
        Card {
            SectionHeader("Historia odpowiedzi")
            if let items {
                if items.isEmpty {
                    Text("Brak odpowiedzi — historia pojawi się po pierwszej sesji.")
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.inkSecondary)
                } else {
                    ForEach(items) { item in
                        WordHistoryRow(item: item)
                    }
                }
            } else {
                Text("Wczytywanie historii…")
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .redacted(reason: .placeholder)
            }
        }
        .task(id: store.revision) {
            let id = wordID
            let computed = await store.compute { state in
                WordHistoryBuilder.items(state: state, wordID: id)
            }
            guard !Task.isCancelled else { return }
            items = computed
        }
    }
}

private struct WordHistoryRow: View {
    let item: WordHistoryItem

    private var resultText: String {
        if !item.correct { return "Nie tym razem" }
        return item.hinted ? "Dobrze, z podpowiedzią" : "Dobrze"
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: item.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(item.correct ? Palette.success : Palette.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("\(resultText) · \(item.skillName)\(item.fromReading ? " · czytanie" : "")")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                if !item.meaning.isEmpty {
                    Text(item.meaning)
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer(minLength: Spacing.xs)
            Text(Date(timestamp: item.at).formatted(date: .abbreviated, time: .shortened))
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
