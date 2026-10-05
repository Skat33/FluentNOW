import SwiftUI
import FluentKit

/// Ekran tematu: kategorie, wpisy z tłumaczeniem i poziomem, zaznaczanie (wszystko / kategoria /
/// filtr poziomów), podgląd wpisu, „Dodaj N słów do nauki” w tle z postępem; oznaczenie dodanych.
struct TopicDetailScreen: View {
    let topicID: String

    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var topic: TopicFile?
    @State private var loadError: String?
    @State private var selection: Set<String> = []
    @State private var levels: Set<String> = Set(CEFR.levels)
    @State private var added: Set<String> = []
    @State private var previewEntry: TopicEntry?
    @State private var isAdding = false
    @State private var progress: Double = 0
    @State private var outcome: TopicAddOutcome?
    @State private var addedTrigger = 0

    var body: some View {
        Group {
            if let topic {
                TopicEntriesList(
                    topic: topic,
                    levels: $levels,
                    selection: $selection,
                    added: added,
                    onPreview: { previewEntry = $0 }
                )
                .safeAreaInset(edge: .bottom) {
                    TopicAddBar(
                        selectedCount: selection.subtracting(addedIDs(topic)).count,
                        isAdding: isAdding,
                        progress: progress,
                        outcome: outcome,
                        onAdd: { Task { await addSelected(topic) } },
                        onPractice: { router.startStudy(StudyLaunchRequest(modes: ["mixed"], collection: topic.namePl)) },
                        onDismissOutcome: { outcome = nil }
                    )
                }
            } else if let loadError {
                ScrollView {
                    VStack(spacing: Spacing.l) {
                        ErrorBanner(message: "Nie udało się wczytać tematu. \(loadError)", onRetry: { Task { await load() } })
                    }
                    .padding(Spacing.screen)
                }
            } else {
                LoadingStateView("Wczytywanie tematu…")
            }
        }
        .background(Palette.background)
        .navigationTitle(topic?.namePl ?? "Temat")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task(id: store.revision) {
            let refs = await store.compute { state in
                VocabularyMerger.addedContentReferences(state)
            }
            guard !Task.isCancelled else { return }
            added = refs
        }
        .sheet(item: $previewEntry) { entry in
            TopicEntryPreviewSheet(
                entry: entry,
                isAdded: added.contains(ContentReference(file: topicID, entryID: entry.id).rawValue),
                isSelected: selection.contains(entry.id),
                onToggle: { toggle(entry.id) }
            )
        }
        .sensoryFeedback(FluentHaptic.answerCorrect, trigger: addedTrigger)
    }

    // MARK: Logika

    private func addedIDs(_ topic: TopicFile) -> Set<String> {
        Set(topic.allEntries.map { $0.id }.filter {
            added.contains(ContentReference(file: topic.id, entryID: $0).rawValue)
        })
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }

    private func load() async {
        guard topic == nil else { return }
        do {
            topic = try await env.content.topic(id: topicID)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func addSelected(_ topic: TopicFile) async {
        guard !isAdding else { return }
        let ids = Array(selection.subtracting(addedIDs(topic)))
        guard !ids.isEmpty else { return }
        isAdding = true
        outcome = nil
        progress = 0
        let result = await TopicAdder.add(topic: topic, entryIDs: ids, store: store) { value in
            progress = value
        }
        isAdding = false
        selection.removeAll()
        outcome = result
        addedTrigger += 1
    }
}

private struct TopicDetailPreviewHost: View {
    var body: some View {
        TopicDetailScreen(topicID: "airport")
    }
}

#Preview("Temat") {
    NavigationStack {
        TopicDetailPreviewHost()
            .libraryNavigationDestinations()
    }
    .fluentPreviewEnvironment()
}
