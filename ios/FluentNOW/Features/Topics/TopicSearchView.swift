import SwiftUI
import FluentKit

/// „Szukaj tematu” (tryb arkusza „+”): opis sytuacji po polsku lub angielsku → wszystkie słowa
/// i zwroty tej sytuacji, od najistotniejszych. Najpierw wbudowana baza i pamięć tematów AI; bez
/// dobrego dopasowania — temat od AI (gdy włączone). Bez własnego `NavigationStack` (daje go arkusz).
struct TopicSearchView: View {
    let initialQuery: String?
    let initialTopicID: String?

    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(AssistantService.self) private var assistant

    @State private var model: TopicSearchModel?

    init(initialQuery: String? = nil, initialTopicID: String? = nil) {
        self.initialQuery = initialQuery
        self.initialTopicID = initialTopicID
    }

    var body: some View {
        Group {
            if let model {
                TopicSearchScreen(model: model)
            } else {
                LoadingStateView("Przygotowuję wyszukiwanie…")
            }
        }
        .navigationTitle("Szukaj tematu")
        .navigationBarTitleDisplayMode(.inline)
        .task { prepare() }
    }

    private func prepare() {
        guard model == nil else { return }
        let created = TopicSearchModel(content: env.content, store: store, assistant: assistant)
        if let initialQuery, !initialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            created.query = initialQuery
        }
        model = created
        if let initialTopicID, !initialTopicID.isEmpty {
            Task { await created.open(topicID: initialTopicID) }
        }
    }
}

/// Element podglądu wpisu (arkusz).
struct TopicPreviewItem: Identifiable {
    let entry: TopicEntry
    let reference: String
    var id: String { reference }
}

/// Ekran z modelem: pole, treść zależna od etapu, dolny pasek dodawania.
private struct TopicSearchScreen: View {
    @Bindable var model: TopicSearchModel

    @Environment(LearningStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var previewItem: TopicPreviewItem?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        list
            .safeAreaInset(edge: .bottom) { bottomBar }
            .toolbar { toolbarContent }
            .interactiveDismissDisabled(model.isBusy || model.selectedCount > 0)
            .task(id: model.query) { await model.search(debounced: true) }
            .task(id: store.revision) { await refreshAdded() }
            .sheet(item: $previewItem) { (item: TopicPreviewItem) in
                previewSheet(item)
            }
            .fluentSensoryFeedback(FluentHaptic.answerCorrect, trigger: model.addedTrigger)
            .onAppear { isFieldFocused = model.query.isEmpty }
    }

    private var list: some View {
        List {
            TopicSearchFieldSection(
                query: $model.query,
                isFocused: $isFieldFocused,
                isSearching: model.isSearching,
                onSubmit: { Task { await model.submit() } }
            )
            TopicSearchPhaseContent(model: model, onPreview: { (item: TopicPreviewItem) in previewItem = item })
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if model.phase == .results {
            TopicAddBar(
                selectedCount: model.selectedCount,
                isAdding: model.isAdding,
                progress: model.progress,
                progressLabel: model.progressLabel,
                outcome: model.outcome,
                onAdd: { model.addSelected() },
                onCancel: { model.cancelAdding() },
                onPractice: { practice() },
                onDismissOutcome: { model.dismissOutcome() }
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Zamknij") { close() }
        }
    }

    private func previewSheet(_ item: TopicPreviewItem) -> some View {
        TopicEntryPreviewSheet(
            entry: item.entry,
            isAdded: model.isAdded(item.reference),
            isSelected: model.selection.contains(item.reference),
            onToggle: { model.toggle(item.reference) },
            isDraft: model.isDraft(item.entry)
        )
    }

    private func refreshAdded() async {
        let references: Set<String> = await store.compute { (state: LearnerState) -> Set<String> in
            VocabularyMerger.addedContentReferences(state)
        }
        guard !Task.isCancelled else { return }
        model.added = references
    }

    private func practice() {
        let collection = model.outcome?.collection ?? ""
        router.startStudy(StudyLaunchRequest(modes: ["mixed"], collection: collection.isEmpty ? nil : collection))
    }

    private func close() {
        model.cancelGeneration()
        model.cancelAdding()
        dismiss()
    }
}

/// Pole wyszukiwania tematu.
private struct TopicSearchFieldSection: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding
    let isSearching: Bool
    let onSubmit: () -> Void

    var body: some View {
        Section {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityHidden(true)
                TextField("Opisz sytuację, np. zamawianie w restauracji", text: $query)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused(isFocused)
                    .onSubmit(onSubmit)
                if isSearching {
                    ProgressView()
                } else if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Palette.inkTertiary)
                            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Wyczyść pole"))
                }
            }
        } footer: {
            Text("Po polsku lub po angielsku. Pokażemy wszystkie słowa i zwroty tej sytuacji — najważniejsze na górze.")
        }
    }
}

/// Treść zależna od etapu (`switch` po enumie — krótkie wyrażenia dla kompilatora).
private struct TopicSearchPhaseContent: View {
    let model: TopicSearchModel
    let onPreview: (TopicPreviewItem) -> Void

    var body: some View {
        switch model.phase {
        case .idle:
            TopicExamplesSection(onSelect: { (text: String) in model.useExample(text) })
        case .searching:
            Section {
                ProgressView("Szukam w bazie tematów…")
                    .frame(maxWidth: .infinity)
            }
        case .results:
            TopicResultsContent(model: model, onPreview: onPreview)
        case .noMatch:
            TopicNoMatchContent(model: model)
        case .generating:
            TopicGeneratingSection(query: model.trimmedQuery, onCancel: { model.cancelGeneration() })
        case .failed(let message):
            TopicFailedContent(model: model, message: message)
        }
    }
}

#Preview("Szukaj tematu") {
    NavigationStack {
        TopicSearchView(initialQuery: "zamawianie w restauracji")
    }
    .fluentPreviewEnvironment()
}
