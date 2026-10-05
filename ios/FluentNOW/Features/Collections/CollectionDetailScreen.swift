import SwiftUI
import FluentKit

/// Kolekcja: postęp, słowa, „Ćwicz tę kolekcję”, zmiana nazwy, usuwanie (słowa zostają).
struct CollectionDetailScreen: View {
    let name: String

    @Environment(LearningStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var summary: CollectionSummary?
    @State private var rows: [WordListRow]?
    @State private var isRenaming = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                CollectionDetailHeader(summary: summary) {
                    router.startStudy(StudyLaunchRequest(modes: ["mixed"], collection: name))
                }
                .listRowInsets(EdgeInsets(top: Spacing.s, leading: 0, bottom: Spacing.s, trailing: 0))
                .listRowBackground(Color.clear)
            }
            Section {
                if let rows {
                    if rows.isEmpty {
                        Text("W tej kolekcji nie ma jeszcze słów. Dodaj słowo i wybierz tę kolekcję.")
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.inkSecondary)
                    } else {
                        ForEach(rows) { row in
                            NavigationLink(value: WordRoute.detail(id: row.id)) {
                                WordRowView(row: row)
                            }
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text("Wczytywanie słów kolekcji"))
                }
            } header: {
                Text("Słowa")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isRenaming = true
                    } label: {
                        Label("Zmień nazwę", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Usuń kolekcję", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Text("Akcje kolekcji"))
            }
        }
        .task(id: store.revision) { await reload() }
        .collectionNameAlert(
            isPresented: $isRenaming,
            title: "Zmień nazwę kolekcji",
            initialName: name,
            existing: WordListBuilder.allCollections(store.state),
            current: name,
            confirmTitle: "Zapisz"
        ) { newName in
            rename(to: newName)
        }
        .confirmationDialog("Usunąć kolekcję „\(name)”?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Usuń kolekcję", role: .destructive) { deleteCollection() }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Słowa zostaną w słowniku razem z postępem — trafią do kolekcji „\(CollectionMutations.fallbackName(forDeleting: name))”.")
        }
    }

    private func reload() async {
        let collection = name
        let now = store.now()
        let result = await store.compute { state in
            CollectionDetailData(
                summary: CollectionBuilder.summary(state: state, name: collection, now: now),
                rows: CollectionBuilder.rows(state: state, name: collection, now: now)
            )
        }
        guard !Task.isCancelled else { return }
        summary = result.summary
        rows = result.rows
    }

    private func rename(to newName: String) {
        let old = name
        let now = store.now()
        store.update(.edit) { CollectionMutations.rename(&$0, from: old, to: newName, now: now) }
        // Ekran jest przypięty do nazwy — po zmianie wracamy i otwieramy kolekcję pod nową nazwą.
        router.pop(on: router.selectedTab)
        router.push(CollectionRoute.detail(name: newName), on: router.selectedTab)
    }

    private func deleteCollection() {
        let old = name
        let now = store.now()
        store.update(.edit) { CollectionMutations.delete(&$0, name: old, now: now) }
        dismiss()
    }
}

private struct CollectionDetailData: Sendable {
    let summary: CollectionSummary
    let rows: [WordListRow]
}

/// Nagłówek kolekcji: postęp i główna akcja.
private struct CollectionDetailHeader: View {
    let summary: CollectionSummary?
    let onPractice: () -> Void

    var body: some View {
        Card(spacing: Spacing.m) {
            if let summary {
                HStack(spacing: Spacing.m) {
                    ProgressRing(progress: Double(summary.averageMastery) / 100, lineWidth: 8,
                                 accessibilityLabel: "Opanowanie kolekcji") {
                        Text("\(summary.averageMastery)%")
                            .font(FluentFont.numberSmall)
                            .foregroundStyle(Palette.ink)
                    }
                    .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(LibraryText.words(summary.wordCount))
                            .font(FluentFont.headline)
                            .foregroundStyle(Palette.ink)
                        Text("\(LibraryText.meanings(summary.meaningCount)) · \(summary.masteredMeanings) opanowanych")
                            .font(FluentFont.subheadline)
                            .foregroundStyle(Palette.inkSecondary)
                        if summary.dueMeanings > 0 {
                            Text("\(summary.dueMeanings) czeka na powtórkę")
                                .font(FluentFont.subheadline)
                                .foregroundStyle(Palette.warning)
                        }
                    }
                }
                PrimaryButton("Ćwicz tę kolekcję", systemImage: "play.fill", action: onPractice)
                    .disabled(summary.meaningCount == 0)
            } else {
                Text("Wczytywanie…")
                    .font(FluentFont.callout)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(.horizontal, Spacing.screen)
    }
}

private struct CollectionDetailPreviewHost: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        CollectionDetailScreen(name: store.activeWords.first?.collection ?? "Codzienne rozmowy")
    }
}

#Preview("Kolekcja") {
    NavigationStack {
        CollectionDetailPreviewHost()
            .libraryNavigationDestinations()
    }
    .fluentPreviewEnvironment()
}
