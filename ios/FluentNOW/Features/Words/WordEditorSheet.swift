import SwiftUI
import FluentKit

/// Edycja słowa w arkuszu: wiele znaczeń, przykłady, rejestr, tagi, kolekcja — z walidacją na bieżąco.
/// Przy niezapisanych zmianach arkusza nie da się zamknąć gestem; „Anuluj” pyta o porzucenie zmian.
struct WordEditorSheet: View {
    let word: Word

    @Environment(LearningStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var draft: WordDraft
    @State private var original: WordDraft
    @State private var confirmDiscard = false
    @State private var savedTrigger = 0

    init(word: Word) {
        self.word = word
        let initial = WordDraft(word: word)
        _draft = State(initialValue: initial)
        _original = State(initialValue: initial)
    }

    private var hasChanges: Bool { draft != original }
    private var issues: [String] { draft.issues }

    var body: some View {
        NavigationStack {
            Form {
                WordEditorTermSection(draft: $draft, collections: WordListBuilder.allCollections(store.state))
                ForEach(Array(draft.meanings.indices), id: \.self) { index in
                    if draft.meanings.indices.contains(index) {
                        WordEditorMeaningSection(
                            meaning: meaningBinding(index),
                            number: index + 1,
                            canRemove: draft.meanings.count > 1,
                            onRemove: { removeMeaning(at: index) }
                        )
                    }
                }
                Section {
                    Button {
                        draft.meanings.append(WordDraft.newMeaning())
                    } label: {
                        Label("Dodaj znaczenie", systemImage: "plus.circle")
                    }
                } footer: {
                    Text("Każde znaczenie ma własny postęp i własne powtórki.")
                }
                WordEditorExtrasSection(draft: $draft)
                if !issues.isEmpty {
                    Section("Do poprawienia") {
                        ForEach(issues, id: \.self) { issue in
                            Label(issue, systemImage: "exclamationmark.circle")
                                .font(FluentFont.footnote)
                                .foregroundStyle(Palette.danger)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Edytuj słowo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") {
                        if hasChanges { confirmDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") { save() }
                        .disabled(!issues.isEmpty || !hasChanges)
                }
            }
            .confirmationDialog("Porzucić zmiany?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Porzuć zmiany", role: .destructive) { dismiss() }
                Button("Wróć do edycji", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(hasChanges)
        .sensoryFeedback(FluentHaptic.answerCorrect, trigger: savedTrigger)
    }

    /// Bezpieczne powiązanie z elementem tablicy (po usunięciu elementu SwiftUI może jeszcze raz odczytać stary indeks).
    private func meaningBinding(_ index: Int) -> Binding<WordDraft.MeaningDraft> {
        Binding(
            get: { draft.meanings.indices.contains(index) ? draft.meanings[index] : WordDraft.placeholderMeaning },
            set: { newValue in
                if draft.meanings.indices.contains(index) { draft.meanings[index] = newValue }
            }
        )
    }

    private func removeMeaning(at index: Int) {
        guard draft.meanings.indices.contains(index), draft.meanings.count > 1 else { return }
        draft.meanings.remove(at: index)
    }

    private func save() {
        guard issues.isEmpty else { return }
        let now = store.now()
        let id = word.id
        let currentDraft = draft
        store.update(.edit) { state in
            guard let current = state.word(id: id) else { return }
            WordMutations.replace(&state, with: currentDraft.applied(to: current, now: now))
        }
        savedTrigger += 1
        dismiss()
    }
}

/// Hasło, wymowa, część mowy, poziom, kolekcja.
private struct WordEditorTermSection: View {
    @Binding var draft: WordDraft
    let collections: [String]

    var body: some View {
        Section("Hasło") {
            TextField("Słowo lub zwrot po angielsku", text: $draft.en)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Wymowa (IPA), np. /ˈbɔːrdɪŋ ˌpæs/", text: $draft.ipa)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            WordEditorPosPicker(title: "Część mowy", selection: $draft.pos)
            WordEditorLevelPicker(selection: $draft.level)
            HStack {
                TextField("Kolekcja", text: $draft.collection)
                if !collections.isEmpty {
                    Menu {
                        ForEach(collections, id: \.self) { name in
                            Button(name) { draft.collection = name }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    }
                    .accessibilityLabel(Text("Wybierz istniejącą kolekcję"))
                }
            }
        }
    }
}

/// Jedno znaczenie z przykładami.
private struct WordEditorMeaningSection: View {
    @Binding var meaning: WordDraft.MeaningDraft
    let number: Int
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        Section {
            TextField("Tłumaczenie (wymagane)", text: $meaning.translation)
            TextField("Wyjaśnienie po angielsku", text: $meaning.definition, axis: .vertical)
            WordEditorPosPicker(title: "Część mowy znaczenia", selection: $meaning.pos)
            WordEditorLevelPicker(selection: $meaning.level)
            Picker("Rejestr", selection: $meaning.register) {
                ForEach(WordDraft.registers, id: \.self) { register in
                    Text(register).tag(register)
                }
            }
            TextField("Kiedy się używa (po polsku)", text: $meaning.context, axis: .vertical)
            ForEach(Array(meaning.examples.indices), id: \.self) { index in
                if meaning.examples.indices.contains(index) {
                    WordEditorExampleFields(
                        example: exampleBinding(index),
                        number: index + 1,
                        canRemove: meaning.examples.count > 1,
                        onRemove: { removeExample(at: index) }
                    )
                }
            }
            Button {
                meaning.examples.append(WordDraft.ExampleDraft())
            } label: {
                Label("Dodaj przykład", systemImage: "text.badge.plus")
            }
            if canRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Usuń to znaczenie", systemImage: "trash")
                }
            }
        } header: {
            Text("Znaczenie \(number)")
        } footer: {
            if meaning.isNew {
                Text("Nowe znaczenie — pojawi się w najbliższej sesji.")
            }
        }
    }

    private func exampleBinding(_ index: Int) -> Binding<WordDraft.ExampleDraft> {
        Binding(
            get: { meaning.examples.indices.contains(index) ? meaning.examples[index] : WordDraft.ExampleDraft() },
            set: { newValue in
                if meaning.examples.indices.contains(index) { meaning.examples[index] = newValue }
            }
        )
    }

    private func removeExample(at index: Int) {
        guard meaning.examples.indices.contains(index), meaning.examples.count > 1 else { return }
        meaning.examples.remove(at: index)
    }
}

private struct WordEditorExampleFields: View {
    @Binding var example: WordDraft.ExampleDraft
    let number: Int
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text("Przykład \(number)")
                    .fluentEyebrow()
                    .foregroundStyle(Palette.inkSecondary)
                Spacer()
                if canRemove {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "minus.circle")
                            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Usuń przykład \(number)"))
                }
            }
            TextField("Zdanie po angielsku", text: $example.en, axis: .vertical)
                .textInputAutocapitalization(.sentences)
            TextField("Tłumaczenie zdania", text: $example.pl, axis: .vertical)
            TextField("Wyróżniony fragment EN (np. boarding pass)", text: $example.focusEn)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Wyróżniony fragment PL", text: $example.focusPl)
            if let issue = WordDraft.focusIssue(example) {
                Text(String(issue.prefix(1)).uppercased() + String(issue.dropFirst()))
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.danger)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
}

/// Formy, kolokacje, synonimy, antonimy, notatka, tagi.
private struct WordEditorExtrasSection: View {
    @Binding var draft: WordDraft

    var body: some View {
        Section("Więcej") {
            TextField("Formy (np. go – went – gone)", text: $draft.forms)
            TextField("Kolokacje", text: $draft.collocations, axis: .vertical)
            TextField("Synonimy", text: $draft.synonyms)
            TextField("Antonimy", text: $draft.antonyms)
            TextField("Notatka", text: $draft.note, axis: .vertical)
            TextField("Tagi oddzielone przecinkami", text: $draft.tags)
                .textInputAutocapitalization(.never)
        }
    }
}

struct WordEditorPosPicker: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            Text("Nie podano").tag("")
            ForEach(WordDraft.partsOfSpeech, id: \.self) { pos in
                Text(pos).tag(pos)
            }
            if !selection.isEmpty && !WordDraft.partsOfSpeech.contains(selection) {
                Text(selection).tag(selection)
            }
        }
    }
}

struct WordEditorLevelPicker: View {
    @Binding var selection: String

    var body: some View {
        Picker("Poziom CEFR", selection: $selection) {
            Text("Nie podano").tag("")
            ForEach(CEFR.levels, id: \.self) { level in
                Text(level).tag(level)
            }
            if !selection.isEmpty && !CEFR.levels.contains(selection) {
                Text(selection).tag(selection)
            }
        }
    }
}

private struct WordEditorPreviewHost: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        if let word = store.activeWords.first {
            WordEditorSheet(word: word)
        } else {
            Text("Brak słów w danych podglądu")
        }
    }
}

#Preview("Edycja słowa") {
    WordEditorPreviewHost()
        .fluentPreviewEnvironment()
}
