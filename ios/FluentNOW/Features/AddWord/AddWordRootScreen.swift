import SwiftUI
import FluentKit

/// Co dodajemy w arkuszu „+”.
enum AddSheetMode: String, CaseIterable, Identifiable, Hashable {
    case word
    case topic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .word: return "Dodaj słowo"
        case .topic: return "Szukaj tematu"
        }
    }
}

/// Wspólny punkt wejścia „+” (prezentowany przez `RootView` dla `AppSheet.quickAdd` i
/// `AppSheet.topicSearch`): przełącznik „Dodaj słowo” / „Szukaj tematu” na górze treści arkusza.
/// Kontrakt powłoki: `init(prefill: String?)`; arkusz ma WŁASNY `NavigationStack`.
struct AddWordRootScreen: View {
    let prefill: String?
    let topicID: String?

    @State private var mode: AddSheetMode
    @State private var detent: PresentationDetent

    init(prefill: String? = nil, mode: AddSheetMode = .word, topicID: String? = nil) {
        self.prefill = prefill
        self.topicID = topicID
        _mode = State(initialValue: mode)
        _detent = State(initialValue: mode == .topic ? .large : .medium)
    }

    var body: some View {
        NavigationStack {
            // Przełącznik NIE w pasku nawigacji: na szerokości iPhone'a „Anuluj” + segmenty + „Dodaj”
            // nachodziły na siebie. Pasek: „Anuluj”/„Zamknij”, tytuł inline trybu, przycisk zatwierdzenia.
            AddSheetModeContent(mode: mode, prefill: prefill, topicID: topicID, detent: $detent)
                .safeAreaInset(edge: .top, spacing: 0) {
                    AddSheetModePicker(mode: $mode)
                }
        }
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .onChange(of: mode) { (_: AddSheetMode, newMode: AddSheetMode) in
            if newMode == .topic { detent = .large }
        }
    }
}

/// Przełącznik trybu arkusza — na górze treści, na pełną szerokość, pod paskiem nawigacji.
/// Segmenty ograniczone do xxxLarge (przy rozmiarach dostępności `UISegmentedControl` ucina
/// etykiety); reszta arkusza skaluje się dalej.
private struct AddSheetModePicker: View {
    @Binding var mode: AddSheetMode

    var body: some View {
        Picker("Co dodajesz", selection: $mode) {
            ForEach(AddSheetMode.allCases) { (item: AddSheetMode) in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(maxWidth: Spacing.readableWidth)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.xs)
        .background(Palette.background)
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: mode)
    }
}

/// Treść wybranego trybu (osobny widok — krótkie `body`).
private struct AddSheetModeContent: View {
    let mode: AddSheetMode
    let prefill: String?
    let topicID: String?
    @Binding var detent: PresentationDetent

    var body: some View {
        switch mode {
        case .word:
            AddWordQuickForm(prefill: prefill, detent: $detent)
        case .topic:
            TopicSearchView(initialQuery: prefill, initialTopicID: topicID)
        }
    }
}

/// Szybkie dodawanie pojedynczego słowa.
///
/// Przepływ: wpisz słowo (EN lub PL) → natychmiastowe propozycje z wbudowanego słownika (i tematów
/// wygenerowanych wcześniej przez AI) → wybierz jedno lub kilka znaczeń (nic nie jest zaznaczone
/// automatycznie) → „Dodaj”. Brak w bazie → asystent AI (jeśli skonfigurowany) albo formularz ręczny.
struct AddWordQuickForm: View {
    let prefill: String?
    @Binding var detent: PresentationDetent

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
    @State private var confirmDiscard = false
    @State private var addedTrigger = 0
    /// Arkusz wszystkich przykładów znaczenia (FEEDBACK-8 M4).
    @State private var examplesPreview: AddWordExamplesItem?
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
        form
            .navigationTitle("Dodaj słowo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .confirmationDialog("Porzucić wybrane znaczenia?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Porzuć", role: .destructive) { dismiss() }
                Button("Wróć", role: .cancel) {}
            }
            .interactiveDismissDisabled(hasUnsavedInput)
            .fluentSensoryFeedback(FluentHaptic.answerCorrect, trigger: addedTrigger)
            .sheet(item: $examplesPreview) { (item: AddWordExamplesItem) in
                AddWordExamplesSheet(item: item)
            }
            .task(id: query) { await search() }
            .onChange(of: query) { (_: String, _: String) in
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

    private var form: some View {
        Form {
            AddWordSearchField(query: $query, isFocused: $isFieldFocused, onSubmit: submitSearch)
            AddWordScanSection { (term: String) in query = term }  // I3: skanowanie tekstu
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
                },
                onShowExamples: { (item: AddWordExamplesItem) -> Void in examplesPreview = item }
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

    /// FEEDBACK-8 M3: jedno znaczenie na unikalne tłumaczenie — wpisy tego samego znaczenia
    /// z kilku tematów i core są zgrupowane (`SenseGrouping`); dodanie zgrupowanego znaczenia
    /// dołącza przykłady ze wszystkich wpisów (bez powtórzeń), a ich odwołania zapisuje w
    /// `mergedContentRefs`. Wybór zostaje tylko między różnymi znaczeniami.
    private func show(_ result: Lookup, source: AddWordLookupSource) {
        let grouped: Lookup = SenseGrouping.grouped(result).lookup
        lookup = grouped
        lookupSource = source
        selected = []
        known = AddWordLogic.knownSenseIndices(grouped, words: store.state.words)
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

#Preview("Szukaj tematu") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            AddWordRootScreen(prefill: "zamawianie w restauracji", mode: .topic)
        }
        .fluentPreviewEnvironment()
}
