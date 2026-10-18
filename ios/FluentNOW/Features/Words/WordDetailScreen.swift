import SwiftUI
import FluentKit

/// Szczegóły słowa: znaczenia z wynikami umiejętności, przykłady, formy, następna powtórka,
/// historia odpowiedzi; edycja, archiwizacja, oznaczenia, usuwanie z potwierdzeniem.
struct WordDetailScreen: View {
    let wordID: String

    @Environment(LearningStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var confirmDelete = false
    @State private var deleteTrigger = 0

    var body: some View {
        Group {
            if let word = store.word(id: wordID) {
                WordDetailContent(word: word, now: store.now())
                    .toolbar {
                        // Gwiazdka widoczna od razu (priorytet w sesjach i fiszkach), obok menu akcji.
                        ToolbarItem(placement: .primaryAction) {
                            WordStarButton(isStarred: word.important, term: word.en) {
                                setImportant(!word.important)
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            WordDetailMenu(
                                word: word,
                                onEdit: { isEditing = true },
                                onToggleHard: { setHard(!word.hard) },
                                onToggleImportant: { setImportant(!word.important) },
                                onToggleArchived: { setArchived(!word.archived) },
                                onDelete: { confirmDelete = true }
                            )
                        }
                    }
                    .sheet(isPresented: $isEditing) {
                        WordEditorSheet(word: word)
                    }
            } else {
                ScrollView {
                    EmptyStateView(
                        systemImage: "questionmark.folder",
                        title: "Nie ma tego słowa",
                        message: "Mogło zostać usunięte, także na innym urządzeniu."
                    )
                }
            }
        }
        .background(Palette.background)
        .navigationTitle(store.word(id: wordID)?.en ?? "Słowo")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Usunąć to słowo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Usuń słowo", role: .destructive) { deleteWord() }
            Button("Archiwizuj zamiast tego") { setArchived(true) }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Słowo i postęp jego znaczeń znikną ze wszystkich urządzeń. Historia odpowiedzi w statystykach zostanie. Archiwizacja ukrywa słowo, ale pozwala je przywrócić.")
        }
        .fluentSensoryFeedback(FluentHaptic.destructive, trigger: deleteTrigger)
    }

    // MARK: Akcje

    private func setHard(_ value: Bool) {
        let now = store.now()
        store.update(.edit) { WordMutations.setHard(&$0, id: wordID, hard: value, now: now) }
    }

    private func setImportant(_ value: Bool) {
        let now = store.now()
        store.update(.edit) { WordMutations.setImportant(&$0, id: wordID, important: value, now: now) }
    }

    private func setArchived(_ value: Bool) {
        let now = store.now()
        store.update(.edit) { WordMutations.setArchived(&$0, id: wordID, archived: value, now: now) }
    }

    private func deleteWord() {
        let id = wordID
        store.update(.edit) { WordMutations.delete(&$0, id: id) }
        deleteTrigger += 1
        dismiss()
    }
}

/// Menu akcji słowa w pasku narzędzi.
private struct WordDetailMenu: View {
    let word: Word
    let onEdit: () -> Void
    let onToggleHard: () -> Void
    let onToggleImportant: () -> Void
    let onToggleArchived: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button(action: onEdit) {
                Label("Edytuj", systemImage: "pencil")
            }
            Button(action: onToggleImportant) {
                Label(word.important ? "Usuń gwiazdkę" : "Dodaj gwiazdkę", systemImage: word.important ? "star.slash" : "star")
            }
            Button(action: onToggleHard) {
                Label(word.hard ? "Usuń oznaczenie „trudne”" : "Oznacz jako trudne", systemImage: "flame")
            }
            Button(action: onToggleArchived) {
                Label(word.archived ? "Przywróć z archiwum" : "Archiwizuj",
                      systemImage: word.archived ? "arrow.uturn.backward" : "archivebox")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Usuń słowo", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel(Text("Akcje słowa"))
    }
}

/// Treść szczegółów (przewijana kolumna kart).
private struct WordDetailContent: View {
    let word: Word
    let now: Timestamp

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                WordDetailHeader(word: word, now: now)
                ForEach(Array(word.meanings.enumerated()), id: \.element.id) { offset, meaning in
                    WordMeaningCard(word: word, meaning: meaning, number: offset + 1, total: word.meanings.count)
                }
                WordExtrasCard(word: word)
                WordScheduleCard(word: word, now: now)
                WordHistoryCard(wordID: word.id)
            }
            .frame(maxWidth: Spacing.readableWidth, alignment: .leading)
            .padding(Spacing.screen)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Podgląd na pierwszym słowie z danych przykładowych.
private struct WordDetailPreviewHost: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        WordDetailScreen(wordID: store.activeWords.first?.id ?? "")
    }
}

#Preview("Szczegóły słowa") {
    NavigationStack {
        WordDetailPreviewHost()
    }
    .fluentPreviewEnvironment()
}
