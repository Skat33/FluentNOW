import SwiftUI
import FluentKit

/// Segment „Słowa” karty Słownik: wyszukiwanie (PL i EN), filtry, sortowanie, akcje przesunięcia.
/// Lista liczona poza głównym wątkiem (`store.compute`) z debounce.
struct WordListView: View {
    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech
    @Environment(AppRouter.self) private var router

    @State private var searchText = ""
    @State private var filter = WordListFilter()
    @State private var result: WordListResult?

    private var query: WordListQuery {
        WordListQuery(revision: store.revision, text: searchText, filter: filter)
    }

    var body: some View {
        content
            .searchable(text: $searchText, prompt: Text("Szukaj po angielsku lub po polsku"))
            .task(id: query) { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        if let result {
            if store.state.words.isEmpty {
                ScrollView {
                    EmptyStateView(
                        systemImage: "text.book.closed",
                        title: "Twój słownik jest pusty",
                        message: "Dodaj pierwsze słowo albo znajdź temat, np. „w restauracji” — nauka zacznie się od razu.",
                        actionTitle: "Szukaj tematu"
                    ) {
                        router.presentTopicSearch()
                    }
                }
            } else {
                list(result)
            }
        } else {
            WordListSkeleton()
        }
    }

    private func list(_ result: WordListResult) -> some View {
        List {
            Section {
                WordFilterBar(filter: $filter, collections: result.collections)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
            }
            ForEach(result.sections) { section in
                Section {
                    ForEach(section.rows) { row in
                        NavigationLink(value: WordRoute.detail(id: row.id)) {
                            WordRowView(row: row, onToggleStar: { toggleStar(row) })
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                speech.speak(row.en)
                            } label: {
                                Label("Wymowa", systemImage: "speaker.wave.2.fill")
                            }
                            .tint(Palette.accentFill)
                            Button {
                                toggleHard(row)
                            } label: {
                                Label(row.isHard ? "Nie trudne" : "Trudne", systemImage: "flame")
                            }
                            .tint(Palette.warning)
                            Button {
                                toggleStar(row)
                            } label: {
                                Label(row.isImportant ? "Bez gwiazdki" : "Gwiazdka", systemImage: row.isImportant ? "star.slash" : "star.fill")
                            }
                            .tint(Palette.accentFill)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                toggleArchived(row)
                            } label: {
                                Label(row.isArchived ? "Przywróć" : "Archiwizuj",
                                      systemImage: row.isArchived ? "arrow.uturn.backward" : "archivebox")
                            }
                            .tint(Palette.info)
                        }
                        .contextMenu {
                            Button {
                                speech.speak(row.en)
                            } label: {
                                Label("Odtwórz wymowę", systemImage: "speaker.wave.2")
                            }
                            Button {
                                toggleStar(row)
                            } label: {
                                Label(row.isImportant ? "Usuń gwiazdkę" : "Dodaj gwiazdkę", systemImage: row.isImportant ? "star.slash" : "star")
                            }
                            Button {
                                toggleHard(row)
                            } label: {
                                Label(row.isHard ? "Usuń oznaczenie „trudne”" : "Oznacz jako trudne", systemImage: "flame")
                            }
                            Button {
                                toggleArchived(row)
                            } label: {
                                Label(row.isArchived ? "Przywróć z archiwum" : "Archiwizuj",
                                      systemImage: "archivebox")
                            }
                        }
                    }
                } header: {
                    if let title = section.title {
                        Text(title)
                    }
                }
            }
            if result.matchCount == 0 {
                Section {
                    WordListNoResults {
                        searchText = ""
                        filter = WordListFilter()
                    }
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    EmptyView()
                } footer: {
                    WordListFooter(count: result.matchCount, collection: filter.collection) { name in
                        router.startStudy(StudyLaunchRequest(modes: ["mixed"], collection: name))
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: Akcje

    private func toggleHard(_ row: WordListRow) {
        let now = store.now()
        store.update(.edit) { state in
            WordMutations.setHard(&state, id: row.id, hard: !row.isHard, now: now)
        }
    }

    /// Gwiazdka (`Word.important`): słowa z gwiazdką mają pierwszeństwo w sesjach i fiszkach.
    private func toggleStar(_ row: WordListRow) {
        let now = store.now()
        store.update(.edit) { state in
            WordMutations.setImportant(&state, id: row.id, important: !row.isImportant, now: now)
        }
    }

    private func toggleArchived(_ row: WordListRow) {
        let now = store.now()
        store.update(.edit) { state in
            WordMutations.setArchived(&state, id: row.id, archived: !row.isArchived, now: now)
        }
    }

    private func reload() async {
        let current = query
        if result != nil {
            // Debounce wpisywania i serii szybkich zmian.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
        }
        let now = store.now()
        let computed = await store.compute { state in
            WordListBuilder.build(state: state, query: current.text, filter: current.filter, now: now)
        }
        guard !Task.isCancelled else { return }
        result = computed
    }
}

/// Stopka listy: liczba wpisów i „Ćwicz kolekcję” przy filtrze kolekcji.
private struct WordListFooter: View {
    let count: Int
    let collection: String?
    let onPractice: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("\(LibraryText.count(count, one: "wpis", few: "wpisy", many: "wpisów")) · każde znaczenie ma własny postęp")
            if let collection {
                Button {
                    onPractice(collection)
                } label: {
                    Label("Ćwicz kolekcję „\(collection)”", systemImage: "play.fill")
                        .font(FluentFont.button)
                }
                .frame(minHeight: HitTarget.minimum)
            }
        }
    }

}

private struct WordListNoResults: View {
    let onClear: () -> Void

    var body: some View {
        EmptyStateView(
            systemImage: "magnifyingglass",
            title: "Nic tu nie pasuje",
            message: "Zmień wyszukiwanie albo wyczyść filtry.",
            actionTitle: "Wyczyść filtry",
            action: onClear
        )
    }
}

/// Szkielet ładowania listy (`redacted`).
private struct WordListSkeleton: View {
    var body: some View {
        List {
            ForEach(0..<8, id: \.self) { index in
                WordRowView(row: WordListRow(
                    id: "placeholder-\(index)", en: "placeholder", translations: "tłumaczenie słowa",
                    level: "A1", status: .new, mastery: 0, meaningCount: 1, collection: "",
                    isHard: false, isImportant: false, isArchived: false
                ))
            }
        }
        .redacted(reason: .placeholder)
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .accessibilityLabel(Text("Wczytywanie słownika"))
    }
}

#Preview("Słowa") {
    NavigationStack {
        WordListView()
            .libraryNavigationDestinations()
            .navigationTitle("Słownik")
    }
    .fluentPreviewEnvironment()
}
