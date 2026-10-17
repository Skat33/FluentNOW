import SwiftUI
import FluentKit

/// „Polecane słówka” na ekranie Dzisiaj: kilka często używanych słów dopasowanych do poziomu
/// i tematów użytkownika, dodawanych jednym dotknięciem; „Zobacz więcej” → pełna lista z zaznaczaniem.
/// Lista liczona poza głównym wątkiem i odświeżana po zmianie stanu (`revision`).
struct TodayRecommendedWordsSection: View {
    static let limit = 5

    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store

    @State private var result: UsefulWordsResult?
    @State private var addingID: String?
    @State private var lastAdded: String?
    @State private var addTrigger = 0
    /// Dodane z tej listy — zostają widoczne jako „Masz już” do opuszczenia ekranu (G6).
    @State private var ownedIDs: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if let result, !result.suggestions.isEmpty {
                TodayRecommendedWordsList(
                    result: result,
                    addingID: addingID,
                    lastAdded: lastAdded,
                    ownedIDs: ownedIDs,
                    onAdd: { (item: UsefulWordSuggestion) in add(item) }
                )
            }
        }
        .task(id: store.revision) { await refresh() }
        .onDisappear { ownedIDs = [] }
        .fluentSensoryFeedback(FluentHaptic.answerCorrect, trigger: addTrigger)
    }

    private func refresh() async {
        if result != nil {
            // Seria szybkich zmian (np. kilka dodanych słów) liczy się raz.
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
        }
        let loaded: UsefulWordsResult = await UsefulWordsLoader.load(store: store, content: env.content, limit: Self.limit)
        guard !Task.isCancelled else { return }
        result = UsefulWordsOwnership.merged(previous: result, fresh: loaded, kept: ownedIDs, limit: Self.limit)
    }

    private func add(_ item: UsefulWordSuggestion) {
        guard addingID == nil else { return }
        addingID = item.id
        Task {
            let outcome: UsefulWordsAddOutcome = await UsefulWordsAdder.add([item.candidate], store: store, content: env.content)
            addingID = nil
            if outcome.addedMeanings > 0 {
                lastAdded = item.candidate.term
                ownedIDs.insert(item.id)
                addTrigger += 1
            }
        }
    }
}

/// Treść sekcji (osobny widok — krótkie `body`).
private struct TodayRecommendedWordsList: View {
    let result: UsefulWordsResult
    let addingID: String?
    let lastAdded: String?
    let ownedIDs: Set<String>
    let onAdd: (UsefulWordSuggestion) -> Void

    var body: some View {
        SectionHeader("Polecane słówka", subtitle: "Często używane na co dzień, dobrane do Twojego poziomu \(result.level).")
        Card(spacing: 0) {
            ForEach(result.suggestions) { (item: UsefulWordSuggestion) in
                UsefulWordRow(
                    suggestion: item,
                    detail: result.details[item.id],
                    isAdding: addingID == item.id,
                    isOwned: ownedIDs.contains(item.id),
                    onAdd: { onAdd(item) }
                )
                if item.id != result.suggestions.last?.id {
                    Divider()
                }
            }
        }
        if let lastAdded {
            Label("Dodano „\(lastAdded)” do nauki", systemImage: "checkmark.circle.fill")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.success)
        }
        NavigationLink(destination: UsefulWordsScreen()) {
            UsefulWordsMoreLabel(title: "Zobacz więcej polecanych słówek")
        }
        .buttonStyle(.plain)
    }
}

/// Wiersz „zobacz więcej” z chevronem.
struct UsefulWordsMoreLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "sparkles")
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            Text(title)
                .font(FluentFont.bodyEmphasized)
                .foregroundStyle(Palette.accent)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: HitTarget.minimum)
        .contentShape(Rectangle())
    }
}

/// Jeden polecany wyraz: hasło, poziom, tłumaczenie, uzasadnienie, wymowa i „dodaj”.
struct UsefulWordRow: View {
    let suggestion: UsefulWordSuggestion
    let detail: UsefulWordDetail?
    let isAdding: Bool
    var isOwned: Bool = false
    let onAdd: () -> Void

    @Environment(SpeechService.self) private var speech

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            UsefulWordText(suggestion: suggestion, detail: detail, showsExample: false)
                .ownedVocabularyDimmed(isOwned)
            Spacer(minLength: 0)
            SpeakButton(size: .small, accessibilityLabel: "Odtwórz wymowę „\(suggestion.candidate.term)”") {
                speech.speak(suggestion.candidate.term)
            }
            if isOwned {
                OwnedVocabularyBadge()
            } else {
                UsefulWordAddButton(term: suggestion.candidate.term, isAdding: isAdding, action: onAdd)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

/// Przycisk „+” (dodanie jednym dotknięciem).
struct UsefulWordAddButton: View {
    let term: String
    let isAdding: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isAdding {
                    ProgressView()
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(.title2, design: .default, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
            }
            .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAdding)
        .accessibilityLabel(Text("Dodaj „\(term)” do nauki"))
    }
}

/// Tekst wiersza: hasło + poziom, tłumaczenie, uzasadnienie (i opcjonalnie przykład).
struct UsefulWordText: View {
    let suggestion: UsefulWordSuggestion
    let detail: UsefulWordDetail?
    let showsExample: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(suggestion.candidate.term)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                LevelBadge(level: suggestion.candidate.level)
            }
            Text(suggestion.candidate.translation)
                .font(FluentFont.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !suggestion.summaryPl.isEmpty {
                Text(suggestion.summaryPl)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.accentSoftInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if showsExample, let example = detail?.example {
                HighlightedText(example.en, focus: example.focusEn)
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
