import SwiftUI
import FluentKit

/// „Gotowość na krok dalej?” — trudniejsze pokrewne słowa po opanowaniu łatwiejszych.
struct TodayRecommendationsSection: View {
    let recommendations: [Recommendation]

    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech
    @State private var addedTerms: Set<String> = []
    @State private var addTrigger = 0

    var body: some View {
        if !recommendations.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Gotowość na krok dalej?", subtitle: "Znasz już łatwiejsze słowo — spróbuj bardziej precyzyjnego.")
                ForEach(recommendations, id: \.term) { item in
                    Card(style: .tinted(.accent)) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.term)
                                .font(FluentFont.headline)
                                .foregroundStyle(Palette.ink)
                            LevelBadge(level: item.level)
                            Spacer(minLength: 0)
                            SpeakButton(size: .small) { speech.speak(item.term) }
                        }
                        Text("Zamiast „\(item.known)”: \(item.translation)")
                            .font(FluentFont.subheadline)
                            .foregroundStyle(Palette.inkSecondary)
                        if !item.difference.isEmpty {
                            Text(item.difference)
                                .font(FluentFont.footnote)
                                .foregroundStyle(Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HighlightedText(item.example, focus: item.term)
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if addedTerms.contains(item.term) {
                            Label("Dodano do kolekcji „Krok dalej”", systemImage: "checkmark.circle.fill")
                                .font(FluentFont.footnote)
                                .foregroundStyle(Palette.success)
                        } else {
                            SecondaryButton("Dodaj do nauki", systemImage: "plus", fillsWidth: false) { add(item) }
                        }
                    }
                }
            }
            .sensoryFeedback(FluentHaptic.answerCorrect, trigger: addTrigger)
        }
    }

    private func add(_ item: Recommendation) {
        let lookup = LevelEstimator.lookup(for: item)
        let now = store.now()
        store.update(.edit) { (state: inout LearnerState) in
            let result = VocabularyMerger.mergeSuggestions(state, lookup: lookup, indices: [0], now: now)
            state = result.state
        }
        addedTerms.insert(item.term)
        addTrigger += 1
    }
}

/// Kolekcje w toku (maks. 3) + „Wszystkie”.
struct TodayCollectionsSection: View {
    let collections: [CollectionSummary]

    @Environment(AppRouter.self) private var router

    var body: some View {
        if !collections.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Twoje kolekcje", actionTitle: "Wszystkie") {
                    router.openLibrary(.collections)
                }
                CollectionGrid(collections: collections)
            }
        }
    }
}

/// Ostatnio dodane słowa (4) + „Cały słownik”.
struct TodayRecentSection: View {
    let rows: [WordListRow]

    @Environment(AppRouter.self) private var router

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.s) {
                SectionHeader("Ostatnio dodane", actionTitle: "Cały słownik") {
                    router.openLibrary(.words)
                }
                Card(spacing: 0) {
                    ForEach(rows) { row in
                        NavigationLink(value: WordRoute.detail(id: row.id)) {
                            HStack {
                                WordRowView(row: row)
                                Image(systemName: "chevron.right")
                                    .font(FluentFont.footnote.weight(.semibold))
                                    .foregroundStyle(Palette.inkTertiary)
                                    .accessibilityHidden(true)
                            }
                            .padding(.vertical, Spacing.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if row.id != rows.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}
