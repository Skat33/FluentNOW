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
    /// „Pokaż wszystkie przykłady” (FEEDBACK-8 M4) — arkusz prezentuje formularz (`AddWordQuickForm`),
    /// nie sekcja listy (modyfikatory na `Section` trafiają do każdego wiersza).
    let onShowExamples: (AddWordExamplesItem) -> Void

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
                    onEdit: { onEdit(sense) },
                    onShowExamples: { onShowExamples(AddWordExamplesItem(id: index, term: lookup.term, sense: sense)) }
                )
            }
        } header: {
            AddWordSenseHeader(term: lookup.term, ipa: lookup.ipa, isSpeaking: speech.isSpeaking) {
                speech.speak(lookup.term)
            }
        } footer: {
            if source == .assistant {
                Label("Propozycja AI — sprawdź znaczenia przed dodaniem. Możesz je poprawić.", systemImage: "sparkles")
            } else {
                Text("Zaznacz znaczenia, których chcesz się uczyć. Każde ma osobny postęp. To samo znaczenie z kilku tematów jest pokazane raz — dostaje przykłady ze wszystkich.")
            }
        }
    }

    private func toggle(_ index: Int) {
        guard !known.contains(index) else { return }
        if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
    }
}

/// Hasło, wymowa i odsłuch w nagłówku sekcji znaczeń.
private struct AddWordSenseHeader: View {
    let term: String
    let ipa: String
    let isSpeaking: Bool
    let onSpeak: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(term)
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.ink)
                    .textCase(nil)
                if !ipa.isEmpty {
                    Text(ipa)
                        .font(FluentFont.ipa)
                        .foregroundStyle(Palette.inkSecondary)
                        .textCase(nil)
                }
            }
            Spacer()
            SpeakButton(size: .small, isSpeaking: isSpeaking, action: onSpeak)
        }
    }
}

/// Wiersz znaczenia: zaznaczenie (całe pole tekstu), opcjonalna edycja propozycji AI i — gdy
/// przykładów jest więcej niż widać w wierszu — „Pokaż wszystkie przykłady (N)” (M4).
/// Przycisk podglądu jest poza przyciskiem zaznaczenia (bez zagnieżdżonych przycisków).
private struct AddWordSenseRow: View {
    let sense: SenseSuggestion
    let isSelected: Bool
    let isKnown: Bool
    let showsEdit: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onShowExamples: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top, spacing: Spacing.s) {
                toggleButton
                if showsEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Popraw przed dodaniem"))
                }
            }
            if sense.examples.count > AddWordSenseText.previewCount {
                Button(action: onShowExamples) {
                    Label("Pokaż wszystkie przykłady (\(sense.examples.count))", systemImage: "text.quote")
                        .font(FluentFont.footnote.weight(.semibold))
                        .frame(minHeight: HitTarget.minimum, alignment: .leading)
                }
                .buttonStyle(.borderless)
                .padding(.leading, AddWordSenseRow.textInset)
                .accessibilityHint(Text("Otwiera listę zdań z tłumaczeniem i odsłuchem"))
            }
        }
    }

    /// Wcięcie pod pola zaznaczenia (ikona + odstęp), by przycisk zaczynał się pod tekstem.
    static let textInset: CGFloat = 28

    private var toggleButton: some View {
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
    }
}

private struct AddWordSenseText: View {
    let sense: SenseSuggestion
    let isKnown: Bool

    /// Ile zdań widać w wierszu (FEEDBACK-8 M4: zwięzły podgląd, reszta w arkuszu).
    static let previewCount = 2

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
            ForEach(Array(sense.examples.prefix(AddWordSenseText.previewCount).enumerated()), id: \.offset) { (item: (offset: Int, element: ExamplePair)) in
                AddWordExamplePreviewLine(example: item.element)
            }
        }
        .multilineTextAlignment(.leading)
    }

    /// Część mowy · kategoria · liczba przykładów („4 przykłady”).
    private var meta: String {
        var parts: [String] = [sense.pos, sense.topic ?? ""].filter { (part: String) -> Bool in !part.isEmpty }
        if !sense.examples.isEmpty {
            parts.append(AddWordSenseText.examplesText(sense.examples.count))
        }
        return parts.joined(separator: " · ")
    }

    /// „1 przykład”, „4 przykłady”, „5 przykładów” — wszystkie zdania, które dostanie znaczenie
    /// (ze wszystkich zgrupowanych wpisów, FEEDBACK-8 M3).
    static func examplesText(_ count: Int) -> String {
        LibraryText.count(count, one: "przykład", few: "przykłady", many: "przykładów")
    }
}

/// Jedno zdanie w podglądzie wiersza: cytat z wyróżnionym słowem, z delikatną linią po lewej.
private struct AddWordExamplePreviewLine: View {
    let example: ExamplePair

    var body: some View {
        HighlightedText(example.en, focus: example.focusEn)
            .font(FluentFont.subheadline)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, Spacing.xs)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Palette.separator)
                    .frame(width: 2)
                    .accessibilityHidden(true)
            }
    }
}

/// Znaczenie, którego przykłady pokazuje arkusz.
struct AddWordExamplesItem: Identifiable {
    let id: Int
    let term: String
    let sense: SenseSuggestion
}

/// Wszystkie przykłady znaczenia (FEEDBACK-8 M4): arkusz `.medium` → `.large`, zdanie EN
/// z wyróżnieniem, tłumaczenie PL, odsłuch. Zwykła lista (bez szkła).
struct AddWordExamplesSheet: View {
    let item: AddWordExamplesItem

    @Environment(SpeechService.self) private var speech
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(item.sense.examples.enumerated()), id: \.offset) { (entry: (offset: Int, element: ExamplePair)) in
                        AddWordExampleRow(example: entry.element) {
                            speech.speak(entry.element.en)
                        }
                    }
                } header: {
                    Text("\(item.term) — \(item.sense.translation)")
                        .textCase(nil)
                } footer: {
                    Text("Wszystkie zdania trafią do słowa po dodaniu znaczenia.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .navigationTitle("Przykłady (\(item.sense.examples.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Wiersz arkusza przykładów: EN (wyróżnione słowo), PL, odsłuch.
private struct AddWordExampleRow: View {
    let example: ExamplePair
    let onSpeak: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HighlightedText(example.en, focus: example.focusEn)
                    .font(FluentFont.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !example.pl.isEmpty {
                    Text(example.pl)
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Spacing.xs)
            SpeakButton(size: .small, accessibilityLabel: "Odtwórz przykład", action: onSpeak)
        }
        .padding(.vertical, Spacing.xxs)
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
