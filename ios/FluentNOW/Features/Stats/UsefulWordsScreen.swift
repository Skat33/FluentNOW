import SwiftUI
import FluentKit

/// Ekran „Polecane słówka”: dłuższa lista przydatnych słów z bazy (często używane, do poziomu
/// docelowego, z tematów użytkownika i codziennych). Dodawanie jednym dotknięciem („+”) albo
/// zaznacz kilka → „Dodaj”. Osadzony w Słowniku jako segment „Polecane” (`embedded: true`);
/// skróty z Dzisiaj i z Postępów prowadzą do tego segmentu (`router.openLibrary(.recommended)`).
struct UsefulWordsScreen: View {
    static let limit = 30

    /// `true` — segment Słownika: bez własnego tytułu nawigacji (zostaje „Słownik”).
    var embedded: Bool = false

    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store

    @State private var result: UsefulWordsResult?
    @State private var selection: Set<String> = []
    @State private var addingIDs: Set<String> = []
    @State private var message: String?
    @State private var addTrigger = 0
    /// Dodane na tym ekranie — zostają na liście jako „Masz już” (G6).
    @State private var ownedIDs: Set<String> = []

    // Krótkie `body` (lekcja z pierwszej kompilacji): treść i haptyka w osobnych typach.
    var body: some View {
        ScrollView { screenContent }
            .background(Palette.background)
            .modifier(UsefulWordsNavigationTitle(embedded: embedded))
            .safeAreaInset(edge: .bottom) { bottomBar }
            .task(id: store.revision) { await refresh() }
            .modifier(UsefulWordsFeedback(addTrigger: addTrigger, selectionCount: selection.count))
    }

    private var screenContent: UsefulWordsScreenContent {
        UsefulWordsScreenContent(
            phase: phase,
            selection: selection,
            addingIDs: addingIDs,
            ownedIDs: ownedIDs,
            message: message,
            onToggle: { (id: String) -> Void in toggle(id) },
            onToggleAll: { () -> Void in toggleAll() },
            onAdd: { (item: UsefulWordSuggestion) -> Void in add([item]) }
        )
    }

    private var phase: UsefulWordsPhase {
        guard let result else { return .loading }
        if result.suggestions.isEmpty { return .empty }
        return .list(result)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if !selectedItems.isEmpty {
            PrimaryButton(
                "Dodaj do nauki: \(LibraryText.words(selectedItems.count))",
                systemImage: "plus",
                isLoading: !addingIDs.isEmpty
            ) {
                add(selectedItems)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: Spacing.readableWidth)
            .frame(maxWidth: .infinity)
            .background(Palette.background)
        }
    }

    private var selectedItems: [UsefulWordSuggestion] {
        guard let result else { return [] }
        return result.suggestions.filter { selection.contains($0.id) && !ownedIDs.contains($0.id) }
    }

    private func refresh() async {
        let loaded: UsefulWordsResult = await UsefulWordsLoader.load(store: store, content: env.content, limit: Self.limit)
        guard !Task.isCancelled else { return }
        let merged = UsefulWordsOwnership.merged(previous: result, fresh: loaded, kept: ownedIDs, limit: Self.limit)
        result = merged
        let visible = Set(merged.suggestions.map { $0.id }).subtracting(ownedIDs)
        selection = selection.intersection(visible)
    }

    private func toggle(_ id: String) {
        guard !ownedIDs.contains(id) else { return }
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    private func toggleAll() {
        guard let result else { return }
        let all = Set(result.suggestions.map { $0.id }).subtracting(ownedIDs)
        selection = selection.isSuperset(of: all) ? [] : all
    }

    private func add(_ items: [UsefulWordSuggestion]) {
        guard addingIDs.isEmpty, !items.isEmpty else { return }
        let ids = Set(items.map { $0.id })
        addingIDs = ids
        Task {
            let outcome: UsefulWordsAddOutcome = await UsefulWordsAdder.add(items.map { $0.candidate }, store: store, content: env.content)
            addingIDs = []
            selection.subtract(ids)
            message = UsefulWordsScreenText.summary(outcome, items: items)
            if outcome.addedMeanings > 0 {
                ownedIDs.formUnion(ids)
                addTrigger += 1
            }
        }
    }
}

/// Tytuł nawigacji tylko dla samodzielnego ekranu (osadzony segment zostawia tytuł „Słownik”).
private struct UsefulWordsNavigationTitle: ViewModifier {
    let embedded: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if embedded {
            content
        } else {
            content
                .navigationTitle("Polecane słówka")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Haptyka ekranu: dodanie i zmiana zaznaczenia.
private struct UsefulWordsFeedback: ViewModifier {
    let addTrigger: Int
    let selectionCount: Int

    func body(content: Content) -> some View {
        content
            .fluentSensoryFeedback(FluentHaptic.answerCorrect, trigger: addTrigger)
            .fluentSensoryFeedback(FluentHaptic.selection, trigger: selectionCount)
    }
}

/// Stan listy.
enum UsefulWordsPhase {
    case loading
    case empty
    case list(UsefulWordsResult)
}

/// Treść ekranu (osobny widok — krótkie `body`, `switch` zamiast łańcucha `if`).
private struct UsefulWordsScreenContent: View {
    let phase: UsefulWordsPhase
    let selection: Set<String>
    let addingIDs: Set<String>
    let ownedIDs: Set<String>
    let message: String?
    let onToggle: (String) -> Void
    let onToggleAll: () -> Void
    let onAdd: (UsefulWordSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.success)
            }
            phaseView
        }
        .frame(maxWidth: Spacing.readableWidth)
        .padding(Spacing.screen)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var phaseView: some View {
        switch phase {
        case .loading:
            LoadingStateView("Dobieram przydatne słówka…")
        case .empty:
            EmptyStateView(
                systemImage: "checkmark.seal",
                title: "Na razie nie mamy więcej propozycji",
                message: "Masz już najczęstsze słowa na swoim poziomie. Wróć po kolejnych sesjach — gdy poziom wzrośnie, pojawią się nowe."
            )
        case .list(let result):
            UsefulWordsIntro(level: result.level, targetLevel: result.targetLevel)
            UsefulWordsSelectableList(
                result: result,
                selection: selection,
                addingIDs: addingIDs,
                ownedIDs: ownedIDs,
                onToggle: onToggle,
                onToggleAll: onToggleAll,
                onAdd: onAdd
            )
        }
    }
}

/// Wyjaśnienie, skąd lista.
private struct UsefulWordsIntro: View {
    let level: String
    let targetLevel: String

    var body: some View {
        Card(style: .tinted(.accent)) {
            Text("Słowa, które naprawdę przydają się w życiu")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
            Text("Tylko często używane w codziennym angielskim, do poziomu \(targetLevel) (Twój szacowany poziom: \(level)). Najpierw tematy, których się uczysz, i sytuacje z codzienności. Do tego słowa z rodzin wyrazów, które znasz (np. decide → decision) — te mogą być rzadsze i o poziom trudniejsze. Bez słów, które już masz.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Lista z polami wyboru.
private struct UsefulWordsSelectableList: View {
    let result: UsefulWordsResult
    let selection: Set<String>
    let addingIDs: Set<String>
    let ownedIDs: Set<String>
    let onToggle: (String) -> Void
    let onToggleAll: () -> Void
    let onAdd: (UsefulWordSuggestion) -> Void

    private var allSelected: Bool {
        let open = result.suggestions.filter { !ownedIDs.contains($0.id) }
        return !open.isEmpty && open.allSatisfy { selection.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader(
                "Propozycje",
                subtitle: "Dotknij, aby zaznaczyć, albo dodaj od razu przyciskiem +.",
                actionTitle: allSelected ? "Odznacz" : "Zaznacz wszystkie",
                action: onToggleAll
            )
            Card(spacing: 0) {
                ForEach(result.suggestions) { (item: UsefulWordSuggestion) in
                    UsefulWordSelectableRow(
                        suggestion: item,
                        detail: result.details[item.id],
                        isSelected: selection.contains(item.id),
                        isAdding: addingIDs.contains(item.id),
                        isOwned: ownedIDs.contains(item.id),
                        onToggle: { onToggle(item.id) },
                        onAdd: { onAdd(item) }
                    )
                    if item.id != result.suggestions.last?.id {
                        Divider()
                    }
                }
            }
        }
    }
}

/// Wiersz z polem wyboru, przykładem, wymową i „+”.
private struct UsefulWordSelectableRow: View {
    let suggestion: UsefulWordSuggestion
    let detail: UsefulWordDetail?
    let isSelected: Bool
    let isAdding: Bool
    let isOwned: Bool
    let onToggle: () -> Void
    let onAdd: () -> Void

    @Environment(SpeechService.self) private var speech

    private var indicator: String {
        if isOwned { return "checkmark.circle.fill" }
        return isSelected ? "checkmark.circle.fill" : "circle"
    }

    private var indicatorColor: Color {
        if isOwned { return Palette.success }
        return isSelected ? Palette.accent : Palette.inkTertiary
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: Spacing.s) {
                    Image(systemName: indicator)
                        .font(.system(.title3, design: .default, weight: .regular))
                        .foregroundStyle(indicatorColor)
                        .accessibilityHidden(true)
                    UsefulWordText(suggestion: suggestion, detail: detail, showsExample: true)
                        .ownedVocabularyDimmed(isOwned)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isOwned)
            .accessibilityAddTraits(isSelected || isOwned ? [.isSelected] : [])
            .accessibilityHint(Text(isSelected ? "Dotknij, aby odznaczyć" : "Dotknij, aby zaznaczyć"))
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

enum UsefulWordsScreenText {
    /// „Dodano do nauki: 3 słowa.” (+ informacja o pominiętych).
    static func summary(_ outcome: UsefulWordsAddOutcome, items: [UsefulWordSuggestion]) -> String {
        if outcome.addedMeanings == 0 && outcome.failed >= items.count {
            return "Nie udało się wczytać tych słów z bazy. Spróbuj ponownie."
        }
        var text: String
        if outcome.addedMeanings == 0 {
            text = "Te słowa są już w Twoim słowniku."
        } else if items.count == 1, let item = items.first {
            text = "Dodano „\(item.candidate.term)” do nauki."
        } else {
            text = "Dodano do nauki: \(LibraryText.words(items.count - outcome.failed))."
        }
        if outcome.failed > 0 {
            text += " Nie udało się wczytać: \(LibraryText.words(outcome.failed))."
        }
        return text
    }
}

#Preview("Polecane słówka") {
    NavigationStack {
        UsefulWordsScreen()
    }
    .fluentPreviewEnvironment()
}

#Preview("Słownik → Polecane") {
    NavigationStack {
        UsefulWordsScreen(embedded: true)
            .navigationTitle("Słownik")
    }
    .fluentPreviewEnvironment()
}
