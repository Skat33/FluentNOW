import SwiftUI

/// Korzeń karty „Słownik” (segmenty Słowa / Kolekcje / Polecane — `AppRouter.librarySection`).
/// Tematy nie są publicznym katalogiem (F1): szuka się ich w arkuszu „+” → „Szukaj tematu”.
/// Kontrakt powłoki: inicjalizator bez argumentów, bez własnego `NavigationStack`.
/// Rejestruje trasy Słownika dla całej karty i konsumuje cele z deep linków.
struct WordsRootScreen: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            Picker("Widok słownika", selection: $router.librarySection) {
                ForEach(LibrarySection.browsable) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.xs)

            WordsSectionContent(section: router.librarySection)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(Palette.background)
        .navigationTitle("Słownik")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { QuickAddButton() }
            ToolbarItem(placement: .topBarTrailing) { ScanToolbarButton() }  // I3: skanowanie tekstu
        }
        .libraryNavigationDestinations()
        .onChange(of: router.pendingLibraryDestination, initial: true) { _, newValue in
            guard newValue != nil, let destination = router.consumeLibraryDestination() else { return }
            open(destination)
        }
    }

    private func open(_ destination: LibraryDestination) {
        switch destination {
        case .word(let id):
            router.push(WordRoute.detail(id: id), on: .words)
        case .collection(let name):
            router.push(CollectionRoute.detail(name: name), on: .words)
        case .topic(let id):
            router.presentTopicSearch(topicID: id)
        }
    }
}

/// Treść wybranego segmentu (osobny widok — mniejsze `body`).
private struct WordsSectionContent: View {
    let section: LibrarySection

    var body: some View {
        switch section {
        case .words, .topics:
            WordListView()
        case .collections:
            CollectionsRootScreen()
        case .recommended:
            // Ten sam ekran co „Polecane słówka” (zaznaczanie, dodawanie, uzasadnienia, „Masz już”),
            // bez własnego tytułu nawigacji — tytuł „Słownik” zostaje.
            UsefulWordsScreen(embedded: true)
        }
    }
}

#Preview("Słownik") {
    NavigationStack {
        WordsRootScreen()
    }
    .fluentPreviewEnvironment()
}
