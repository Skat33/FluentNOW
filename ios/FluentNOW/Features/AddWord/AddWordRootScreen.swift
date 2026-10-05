import SwiftUI
import FluentKit

/// Arkusz szybkiego dodawania (prezentowany przez `RootView` dla `AppSheet.quickAdd`).
/// Kontrakt powłoki: `init(prefill: String?)`; arkusz ma WŁASNY `NavigationStack`.
///
/// Przepływ: wpisz słowo (EN lub PL) → natychmiastowe propozycje z wbudowanego słownika →
/// wybierz jedno lub kilka znaczeń (nic nie jest zaznaczone automatycznie) → „Dodaj”.
/// Brak w bazie → asystent AI (jeśli skonfigurowany, oznaczony jako propozycja) albo formularz ręczny.
struct AddWordRootScreen: View {
    let prefill: String?

    init(prefill: String? = nil) {
        self.prefill = prefill
    }

    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(AssistantService.self) private var assistant
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var candidates: [AddWordCandidate] = []
    @State private var searchedQuery = ""
    @State private var lookup: Lookup?
    @State private var lookupSource: AddWordLookupSource = .builtIn
    @State private var selected: Set<Int> = []
    @State private var known: Set<Int> = []
    @State private var isLoadingLookup = false
    @State private var manual: AddWordManualDraft?
    @State private var collectionOverride: String?
    @State private var outcome: AddWordOutcome?
    @State private var assistantError: String?
    @State private var isAskingAssistant = false
    @State private var detent: PresentationDetent = .medium
    @State private var confirmDiscard = false
    @State private var addedTrigger = 0
    @FocusState private var isFieldFocused: Bool

    private var hasUnsavedInput: Bool {
        if !selected.isEmpty { return true }
        guard let manual else { return false }
        return !manual.translation.isEmpty || !manual.exampleEn.isEmpty || !manual.definition.isEmpty
    }

    private var canAdd: Bool {
        if let manual { return manual.issues.isEmpty }
        return lookup != nil && !selected.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                AddWordSearchField(query: $query, isFocused: $isFieldFocused, onSubmit: submitSearch)
                if let outcome {
                    Section {
                        Label(outcome.message, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(outcome.added > 0 ? Palette.success : Palette.inkSecondary)
                    }
                }
                content
                if lookup != nil || manual != nil {
                    AddWordCollectionSection(
                        selection: $collectionOverride,
                        collections: WordListBuilder.allCollections(store.state)
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Dodaj słowo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .confirmationDialog("Porzucić wybrane znaczenia?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Porzuć", role: .destructive) { dismiss() }
                Button("Wróć", role: .cancel) {}
            }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(hasUnsavedInput)
        .sensoryFeedback(FluentHaptic.answerCorrect, trigger: addedTrigger)
        .task(id: query) { await search() }
        .onChange(of: query) { _, _ in
            lookup = nil
            manual = nil
            selected = []
            assistantError = nil
        }
        .onAppear {
            if let prefill, query.isEmpty { query = prefill }
            isFieldFocused = true
        }
    }

    @ViewBuilder
    private var content: some View {
        if let manual {
            AddWordManualSection(draft: Binding(
                get: { self.manual ?? manual },
                set: { self.manual = $0 }
            ))
        } else if let lookup {
            AddWordSenseSection(
                lookup: lookup,
                source: lookupSource,
                selected: $selected,
                known: known,
                onEdit: { sense in
                    self.manual = AddWordManualDraft(term: lookup.term, sense: sense)
                }
            )
        } else if isLoadingLookup {
            Section { ProgressView("Wczytywanie znaczeń…") }
        } else {
            AddWordResultsSection(
                query: query,
                searchedQuery: searchedQuery,
                candidates: candidates,
                assistantAvailable: assistant.activeProvider != .offline,
                isAskingAssistant: isAskingAssistant,
                assistantError: assistantError,
                onSelect: { candidate in Task { await select(candidate) } },
                onAskAssistant: { Task { await askAssistant() } },
                onManual: { manual = AddWordManualDraft(term: query.trimmingCharacters(in: .whitespacesAndNewlines), sense: nil) }
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(outcome == nil ? "Anuluj" : "Gotowe") {
                if hasUnsavedInput { confirmDiscard = true } else { dismiss() }
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Dodaj") { add() }
                .disabled(!canAdd)
        }
    }

    // MARK: Wyszukiwanie

    private func submitSearch() {
        if let first = candidates.first, lookup == nil, manual == nil {
            Task { await select(first) }
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            candidates = []
            searchedQuery = ""
            return
        }
        try? await Task.sleep(for: .milliseconds(120))
        guard !Task.isCancelled else { return }
        var hits = await env.content.search(text, limit: 30)
        if hits.isEmpty {
            // Indeks mógł się jeszcze budować przy pierwszym wyszukiwaniu — jedna ponowna próba.
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            hits = await env.content.search(text, limit: 30)
        }
        guard !Task.isCancelled else { return }
        candidates = AddWordCandidate.group(hits)
        searchedQuery = text
        if !candidates.isEmpty { detent = .large }
    }

    private func select(_ candidate: AddWordCandidate) async {
        isLoadingLookup = true
        let result = await env.content.lookup(term: candidate.term)
        isLoadingLookup = false
        guard let result, !result.meanings.isEmpty else {
            manual = AddWordManualDraft(term: candidate.term, sense: nil)
            return
        }
        show(result, source: .builtIn)
    }

    private func askAssistant() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty, !isAskingAssistant else { return }
        isAskingAssistant = true
        assistantError = nil
        defer { isAskingAssistant = false }
        do {
            let raw = try await assistant.lookup(term: term)
            let checked = AddWordLogic.sanitizedAssistantLookup(raw)
            if checked.meanings.isEmpty {
                assistantError = "Asystent nie zaproponował poprawnych znaczeń. Dodaj słowo ręcznie."
            } else {
                show(checked, source: .assistant)
            }
        } catch {
            assistantError = error.localizedDescription
        }
    }

    private func show(_ result: Lookup, source: AddWordLookupSource) {
        lookup = result
        lookupSource = source
        selected = []
        known = AddWordLogic.knownSenseIndices(result, words: store.state.words)
        detent = .large
    }

    // MARK: Zapis

    private func add() {
        guard canAdd else { return }
        let now = store.now()
        let override = collectionOverride
        let result: AddWordOutcome
        if let manual {
            let lookup = manual.lookup(collection: override ?? VocabularyMerger.defaultCollection)
            result = store.update(.bulk) { (state: inout LearnerState) -> AddWordOutcome in
                AddWordLogic.merge(&state, lookup: lookup, indices: [0], collectionOverride: override,
                                   markManual: true, now: now)
            }
        } else if let lookup {
            let indices = selected.sorted()
            result = store.update(.bulk) { (state: inout LearnerState) -> AddWordOutcome in
                AddWordLogic.merge(&state, lookup: lookup, indices: indices, collectionOverride: override,
                                   markManual: false, now: now)
            }
        } else {
            return
        }
        outcome = result
        addedTrigger += 1
        query = ""
        lookup = nil
        manual = nil
        selected = []
        candidates = []
        isFieldFocused = true
    }
}

#Preview("Dodawanie słowa") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddWordRootScreen(prefill: "borrow")
        }
        .fluentPreviewEnvironment()
}
