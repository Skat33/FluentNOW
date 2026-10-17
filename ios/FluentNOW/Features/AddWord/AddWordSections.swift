import SwiftUI
import FluentKit

/// Pole wyszukiwania (EN lub PL).
struct AddWordSearchField: View {
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    var body: some View {
        Section {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityHidden(true)
                TextField("Wpisz słowo po angielsku lub po polsku", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused(isFocused)
                    .onSubmit(onSubmit)
                if !query.isEmpty {
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
            Text("Propozycje znaczeń pojawiają się od razu, także bez internetu.")
        }
    }
}

/// Propozycje z wbudowanego słownika albo opcje, gdy hasła nie ma w bazie.
struct AddWordResultsSection: View {
    let query: String
    let searchedQuery: String
    let candidates: [AddWordCandidate]
    let assistantAvailable: Bool
    let isAskingAssistant: Bool
    let assistantError: String?
    let onSelect: (AddWordCandidate) -> Void
    let onAskAssistant: () -> Void
    let onManual: () -> Void

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        if !candidates.isEmpty {
            Section("Propozycje") {
                ForEach(candidates) { candidate in
                    Button {
                        onSelect(candidate)
                    } label: {
                        AddWordCandidateRow(candidate: candidate)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        if !trimmed.isEmpty && searchedQuery == trimmed {
            Section {
                if candidates.isEmpty {
                    Text("Nie ma „\(trimmed)” we wbudowanym słowniku.")
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.inkSecondary)
                }
                if assistantAvailable {
                    Button(action: onAskAssistant) {
                        HStack {
                            Label("Zapytaj asystenta AI", systemImage: "sparkles")
                            if isAskingAssistant {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isAskingAssistant)
                }
                if let assistantError {
                    Label(assistantError, systemImage: "exclamationmark.triangle")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.danger)
                }
                Button(action: onManual) {
                    Label("Dodaj ręcznie", systemImage: "square.and.pencil")
                }
            } header: {
                Text(candidates.isEmpty ? "Brak w bazie" : "Nie ma tu tego znaczenia?")
            } footer: {
                if !assistantAvailable {
                    Text("Asystenta AI możesz włączyć w Ustawieniach. Bez niego dodasz słowo ręcznie.")
                }
            }
        }
    }
}

private struct AddWordCandidateRow: View {
    let candidate: AddWordCandidate

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.term)
                    .font(FluentFont.bodyEmphasized)
                    .foregroundStyle(Palette.ink)
                Text(candidate.translations.joined(separator: " · "))
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: Spacing.xs)
            LevelBadge(level: candidate.level)
            Image(systemName: "chevron.right")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkTertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .frame(minHeight: HitTarget.minimum)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Pokazuje znaczenia do wyboru"))
    }
}

/// Wybór znaczeń hasła (żadne nie jest zaznaczone automatycznie).
struct AddWordSenseSection: View {
    let lookup: Lookup
    let source: AddWordLookupSource
    @Binding var selected: Set<Int>
    let known: Set<Int>
    let onEdit: (SenseSuggestion) -> Void

    @Environment(SpeechService.self) private var speech

    var body: some View {
        Section {
            ForEach(Array(lookup.meanings.enumerated()), id: \.offset) { index, sense in
                AddWordSenseRow(
                    sense: sense,
                    isSelected: selected.contains(index),
                    isKnown: known.contains(index),
                    showsEdit: source == .assistant,
                    onToggle: { toggle(index) },
                    onEdit: { onEdit(sense) }
                )
            }
        } header: {
            HStack(spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lookup.term)
                        .font(FluentFont.title)
                        .foregroundStyle(Palette.ink)
                        .textCase(nil)
                    if !lookup.ipa.isEmpty {
                        Text(lookup.ipa)
                            .font(FluentFont.ipa)
                            .foregroundStyle(Palette.inkSecondary)
                            .textCase(nil)
                    }
                }
                Spacer()
                SpeakButton(size: .small, isSpeaking: speech.isSpeaking) { speech.speak(lookup.term) }
            }
        } footer: {
            if source == .assistant {
                Label("Propozycja AI — sprawdź znaczenia przed dodaniem. Możesz je poprawić.", systemImage: "sparkles")
            } else {
                Text("Zaznacz znaczenia, których chcesz się uczyć. Każde ma osobny postęp.")
            }
        }
    }

    private func toggle(_ index: Int) {
        guard !known.contains(index) else { return }
        if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
    }
}

private struct AddWordSenseRow: View {
    let sense: SenseSuggestion
    let isSelected: Bool
    let isKnown: Bool
    let showsEdit: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: Spacing.s) {
                    Image(systemName: isKnown ? "checkmark.circle.fill" : (isSelected ? "checkmark.square.fill" : "square"))
                        .font(FluentFont.headline)
                        .foregroundStyle(isKnown ? Palette.success : (isSelected ? Palette.accent : Palette.inkSecondary))
                        .accessibilityHidden(true)
                    AddWordSenseText(sense: sense, isKnown: isKnown)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(isKnown)
            .accessibilityAddTraits(isSelected || isKnown ? .isSelected : [])
            if showsEdit {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Popraw przed dodaniem"))
            }
        }
    }
}

private struct AddWordSenseText: View {
    let sense: SenseSuggestion
    let isKnown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Text(sense.translation)
                    .font(FluentFont.bodyEmphasized)
                    .foregroundStyle(isKnown ? Palette.inkSecondary : Palette.ink)
                LevelBadge(level: sense.level)
                if isKnown {
                    OwnedVocabularyBadge()
                }
            }
            let meta = [sense.pos, sense.topic ?? ""]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !meta.isEmpty {
                Text(meta)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if !sense.definition.isEmpty {
                Text(sense.definition)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let example = sense.examples.first {
                HighlightedText(example.en, focus: example.focusEn)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.leading)
    }
}

/// Formularz ręcznego dodania.
struct AddWordManualSection: View {
    @Binding var draft: AddWordManualDraft

    var body: some View {
        Section {
            TextField("Słowo lub zwrot po angielsku", text: $draft.term)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Tłumaczenie", text: $draft.translation)
            WordEditorPosPicker(title: "Część mowy", selection: $draft.pos)
            WordEditorLevelPicker(selection: $draft.level)
            TextField("Wyjaśnienie po angielsku (opcjonalnie)", text: $draft.definition, axis: .vertical)
            TextField("Przykładowe zdanie po angielsku", text: $draft.exampleEn, axis: .vertical)
            TextField("Tłumaczenie zdania (opcjonalnie)", text: $draft.examplePl, axis: .vertical)
        } header: {
            Text("Dodaj ręcznie")
        } footer: {
            let issues = draft.issues
            if !issues.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    ForEach(issues, id: \.self) { issue in
                        Text(issue)
                    }
                }
            }
        }
    }
}

/// Wybór kolekcji (domyślnie automatycznie: kolekcja tematu albo pasująca istniejąca).
struct AddWordCollectionSection: View {
    @Binding var selection: String?
    let collections: [String]

    var body: some View {
        Section {
            Picker("Kolekcja", selection: $selection) {
                Text("Automatycznie").tag(String?.none)
                ForEach(collections, id: \.self) { name in
                    Text(name).tag(String?.some(name))
                }
            }
        } footer: {
            Text("Automatycznie: słowo trafi do kolekcji swojego tematu albo do podobnej, którą już masz.")
        }
    }
}
