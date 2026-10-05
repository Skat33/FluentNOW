import SwiftUI
import FluentKit

/// Przeglądarka tematów — osadzana w karcie „Słownik” (segment „Tematy”), więc bez własnego
/// `NavigationStack` i bez `navigationTitle`. Trasy rejestruje `WordsRootScreen`.
struct TopicsRootScreen: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store

    @State private var index: TopicIndex?
    @State private var loadError: String?
    @State private var searchText = ""
    @State private var addedCounts: [String: Int] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if let loadError {
                    ErrorBanner(
                        message: "Nie udało się wczytać listy tematów. \(loadError)",
                        onRetry: { Task { await load() } }
                    )
                }
                if let index {
                    TopicsIndexContent(index: index, query: searchText, addedCounts: addedCounts)
                } else if loadError == nil {
                    TopicsLoadingGrid()
                }
            }
            .padding(Spacing.screen)
        }
        .background(Palette.background)
        .searchable(text: $searchText, prompt: Text("Szukaj tematu, np. lotnisko"))
        .task { await load() }
        .task(id: store.revision) {
            let counts = await store.compute { state in
                TopicProgress.addedCounts(state)
            }
            guard !Task.isCancelled else { return }
            addedCounts = counts
        }
    }

    private func load() async {
        guard index == nil else { return }
        do {
            let loaded = try await env.content.topicIndex()
            index = loaded
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// Liczba dodanych wpisów każdego tematu (z `Meaning.contentRef`).
enum TopicProgress {
    static func addedCounts(_ state: LearnerState) -> [String: Int] {
        var counts: [String: Int] = [:]
        for reference in VocabularyMerger.addedContentReferences(state) {
            guard let parsed = ContentReference(reference), !parsed.isStarter else { continue }
            counts[parsed.file, default: 0] += 1
        }
        return counts
    }
}

/// Grupy tematów albo wyniki wyszukiwania.
private struct TopicsIndexContent: View {
    let index: TopicIndex
    let query: String
    let addedCounts: [String: Int]

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        if trimmedQuery.isEmpty {
            ForEach(index.groups) { group in
                let topics = index.topics(inGroup: group.id)
                if !topics.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        Label(group.namePl, systemImage: group.symbol)
                            .font(FluentFont.title)
                            .foregroundStyle(Palette.ink)
                            .accessibilityAddTraits(.isHeader)
                        TopicGrid(topics: topics, addedCounts: addedCounts)
                    }
                }
            }
        } else {
            let results = index.topics.filter { $0.matches(trimmedQuery) }
            if results.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "Brak takiego tematu",
                    message: "Spróbuj innego słowa — po polsku lub po angielsku. Pojedyncze słowo dodasz przyciskiem +."
                )
            } else {
                TopicGrid(topics: results, addedCounts: addedCounts)
            }
        }
    }
}

struct TopicGrid: View {
    let topics: [TopicSummary]
    let addedCounts: [String: Int]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Spacing.s)], spacing: Spacing.s) {
            ForEach(topics) { topic in
                NavigationLink(value: TopicRoute.detail(id: topic.id)) {
                    TopicCard(topic: topic, added: addedCounts[topic.id] ?? 0)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TopicsLoadingGrid: View {
    var body: some View {
        TopicGrid(
            topics: (0..<4).map { TopicSummary(id: "placeholder-\($0)", namePl: "Temat słówek", summaryPl: "Opis tematu w jednym zdaniu", entryCount: 80) },
            addedCounts: [:]
        )
        .redacted(reason: .placeholder)
        .disabled(true)
        .accessibilityLabel(Text("Wczytywanie tematów"))
    }
}

#Preview("Tematy") {
    NavigationStack {
        TopicsRootScreen()
            .libraryNavigationDestinations()
    }
    .fluentPreviewEnvironment()
}
