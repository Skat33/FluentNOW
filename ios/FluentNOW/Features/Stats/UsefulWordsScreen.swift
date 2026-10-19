import SwiftUI
import FluentKit

/// Ekran „Polecane słówka”: przydatne słowa z bazy (często używane, do poziomu docelowego,
/// z tematów użytkownika i codzienne). Osadzony w Słowniku jako segment „Polecane”
/// (`embedded: true`); skróty z Dzisiaj i z Postępów prowadzą do tego segmentu
/// (`router.openLibrary(.recommended)`).
///
/// FEEDBACK-5 J2: bez nieskończonego przewijania — zestaw najwyżej 3 stron po 6 słów
/// (`UsefulWordsPaging`), przewijanych poziomo (przesunięcie, strzałki, kropki; VoiceOver: akcja
/// „dostosuj”). „Odśwież propozycje” losuje nowy zestaw z tej samej puli rankingu, z pominięciem
/// słów pokazanych w tym tygodniu (pamiętane na urządzeniu). Zaznaczanie i dodawanie bez zmian:
/// dotknięcie zaznacza, „+” dodaje od razu, dolny przycisk dodaje zaznaczone ze wszystkich stron.
struct UsefulWordsScreen: View {
    /// `true` — segment Słownika: bez własnego tytułu nawigacji (zostaje „Słownik”).
    var embedded: Bool = false

    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Tydzień, którego dotyczą zapamiętane zestawy (nowy tydzień = nowy ranking, od nowa).
    @AppStorage("usefulWords.week") private var storedWeek = -1
    /// Słowa pokazane w tym tygodniu w poprzednich zestawach.
    @AppStorage("usefulWords.shown") private var shownRaw = ""
    /// Bieżący zestaw (ten sam po powrocie na ekran).
    @AppStorage("usefulWords.current") private var currentRaw = ""

    @State private var pool: UsefulWordsResult?
    @State private var items: [UsefulWordSuggestion] = []
    @State private var details: [String: UsefulWordDetail] = [:]
    @State private var page = 0
    @State private var forward = true
    /// Numer wylosowanego zestawu (nowy zestaw = nowa karta strony, także na stronie 1).
    @State private var setNumber = 0
    @State private var selection: Set<String> = []
    @State private var addingIDs: Set<String> = []
    @State private var message: String?
    @State private var note: String?
    @State private var addTrigger = 0
    /// Dodane na tym ekranie — zostają w zestawie jako „Masz już” (G6).
    @State private var ownedIDs: Set<String> = []

    // Krótkie `body` (lekcja z pierwszej kompilacji): treść i haptyka w osobnych typach.
    var body: some View {
        ScrollView { screenContent }
            .background(Palette.background)
            .modifier(UsefulWordsNavigationTitle(embedded: embedded))
            .safeAreaInset(edge: .bottom) { bottomBar }
            .task(id: store.revision) { await refresh() }
            .modifier(UsefulWordsFeedback(addTrigger: addTrigger, selectionCount: selection.count, page: page))
    }

    private var screenContent: UsefulWordsScreenContent {
        UsefulWordsScreenContent(
            phase: phase,
            page: page,
            forward: forward,
            setNumber: setNumber,
            selection: selection,
            addingIDs: addingIDs,
            ownedIDs: ownedIDs,
            message: message,
            note: note,
            canDrawNewSet: canDrawNewSet,
            onToggle: { (id: String) -> Void in toggle(id) },
            onTogglePage: { (pageItems: [UsefulWordSuggestion]) -> Void in togglePage(pageItems) },
            onAdd: { (item: UsefulWordSuggestion) -> Void in add([item]) },
            onPage: { (target: Int) -> Void in goToPage(target) },
            onDrawNewSet: { () -> Void in drawNewSet() }
        )
    }

    private var phase: UsefulWordsPhase {
        guard let pool else { return .loading }
        if items.isEmpty { return .empty }
        return .list(UsefulWordsResult(suggestions: items, details: details, level: pool.level, targetLevel: pool.targetLevel))
    }

    /// W puli są słowa spoza bieżącego zestawu.
    private var canDrawNewSet: Bool {
        (pool?.suggestions.count ?? 0) > items.count
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
        items.filter { selection.contains($0.id) && !ownedIDs.contains($0.id) }
    }

    // MARK: Zestaw

    private func refresh() async {
        let loaded: UsefulWordsResult = await UsefulWordsLoader.load(store: store, content: env.content, limit: UsefulWordsPaging.poolLimit)
        guard !Task.isCancelled else { return }
        let week = UsefulWordsPaging.week(now: store.now())
        if storedWeek != week {
            storedWeek = week
            shownRaw = ""
            currentRaw = ""
        }
        var set = UsefulWordsPaging.refreshed(
            current: items,
            storedIDs: UsefulWordsPaging.ids(currentRaw),
            pool: loaded.suggestions,
            owned: ownedIDs,
            shown: Set(UsefulWordsPaging.ids(shownRaw))
        )
        if set.isEmpty && !loaded.suggestions.isEmpty {
            // Wszystko z puli było już pokazane — tydzień zaczyna się od nowa.
            shownRaw = ""
            set = UsefulWordsPaging.refreshed(current: [], storedIDs: [], pool: loaded.suggestions, owned: ownedIDs, shown: [])
        }
        details.merge(loaded.details) { (_: UsefulWordDetail, new: UsefulWordDetail) -> UsefulWordDetail in new }
        pool = loaded
        show(set)
    }

    /// „Odśwież propozycje”: nowy zestaw z tej samej puli, bez słów pokazanych w tym tygodniu.
    private func drawNewSet() {
        guard let pool else { return }
        var generator = SystemRandomNumberGenerator()
        let draw = UsefulWordsPaging.nextSet(
            pool: pool.suggestions,
            current: items,
            shown: Set(UsefulWordsPaging.ids(shownRaw)),
            using: &generator
        )
        shownRaw = UsefulWordsPaging.raw(draw.shown.sorted())
        ownedIDs = []
        selection = []
        message = nil
        note = draw.startedOver ? "Pokazaliśmy już wszystkie propozycje na ten tydzień — losujemy od nowa." : nil
        forward = true
        withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            setNumber += 1
            page = 0
            show(draw.items)
        }
    }

    private func show(_ set: [UsefulWordSuggestion]) {
        items = set
        currentRaw = UsefulWordsPaging.raw(set.map { $0.id })
        let pageCount = UsefulWordsPaging.pages(set).count
        if page >= pageCount {
            page = max(0, pageCount - 1)
        }
        let visible = Set(set.map { $0.id }).subtracting(ownedIDs)
        selection = selection.intersection(visible)
    }

    private func goToPage(_ target: Int) {
        let count = UsefulWordsPaging.pages(items).count
        guard count > 0 else { return }
        let clamped = min(max(0, target), count - 1)
        guard clamped != page else { return }
        forward = clamped > page
        withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            page = clamped
        }
    }

    // MARK: Zaznaczanie i dodawanie (bez zmian)

    private func toggle(_ id: String) {
        guard !ownedIDs.contains(id) else { return }
        if selection.contains(id) {
            selection.remove(id)
        } else {
            selection.insert(id)
        }
    }

    /// „Zaznacz stronę” / „Odznacz” — słowa widocznej strony.
    private func togglePage(_ pageItems: [UsefulWordSuggestion]) {
        let open = Set(pageItems.map { $0.id }).subtracting(ownedIDs)
        if selection.isSuperset(of: open) {
            selection.subtract(open)
        } else {
            selection.formUnion(open)
        }
    }

    private func add(_ toAdd: [UsefulWordSuggestion]) {
        guard addingIDs.isEmpty, !toAdd.isEmpty else { return }
        let ids = Set(toAdd.map { $0.id })
        addingIDs = ids
        Task {
            let outcome: UsefulWordsAddOutcome = await UsefulWordsAdder.add(toAdd.map { $0.candidate }, store: store, content: env.content)
            addingIDs = []
            selection.subtract(ids)
            message = UsefulWordsScreenText.summary(outcome, items: toAdd)
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

/// Haptyka ekranu: dodanie, zmiana zaznaczenia i strony.
private struct UsefulWordsFeedback: ViewModifier {
    let addTrigger: Int
    let selectionCount: Int
    let page: Int

    func body(content: Content) -> some View {
        content
            .fluentSensoryFeedback(FluentHaptic.answerCorrect, trigger: addTrigger)
            .fluentSensoryFeedback(FluentHaptic.selection, trigger: selectionCount)
            .fluentSensoryFeedback(FluentHaptic.selection, trigger: page)
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
    let page: Int
    let forward: Bool
    let setNumber: Int
    let selection: Set<String>
    let addingIDs: Set<String>
    let ownedIDs: Set<String>
    let message: String?
    let note: String?
    let canDrawNewSet: Bool
    let onToggle: (String) -> Void
    let onTogglePage: ([UsefulWordSuggestion]) -> Void
    let onAdd: (UsefulWordSuggestion) -> Void
    let onPage: (Int) -> Void
    let onDrawNewSet: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            if let message {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.success)
            }
            if let note {
                Label(note, systemImage: "info.circle")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            UsefulWordsPager(
                result: result,
                page: page,
                forward: forward,
                setNumber: setNumber,
                selection: selection,
                addingIDs: addingIDs,
                ownedIDs: ownedIDs,
                canDrawNewSet: canDrawNewSet,
                onToggle: onToggle,
                onTogglePage: onTogglePage,
                onAdd: onAdd,
                onPage: onPage,
                onDrawNewSet: onDrawNewSet
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

/// Zestaw w stronach: nagłówek z „Zaznacz stronę”, karta bieżącej strony (przesunięcie w bok
/// zmienia stronę), wskaźnik stron i „Odśwież propozycje”.
private struct UsefulWordsPager: View {
    let result: UsefulWordsResult
    let page: Int
    let forward: Bool
    let setNumber: Int
    let selection: Set<String>
    let addingIDs: Set<String>
    let ownedIDs: Set<String>
    let canDrawNewSet: Bool
    let onToggle: (String) -> Void
    let onTogglePage: ([UsefulWordSuggestion]) -> Void
    let onAdd: (UsefulWordSuggestion) -> Void
    let onPage: (Int) -> Void
    let onDrawNewSet: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pages: [[UsefulWordSuggestion]] { UsefulWordsPaging.pages(result.suggestions) }

    private var current: Int { min(max(0, page), max(0, pages.count - 1)) }

    private var pageItems: [UsefulWordSuggestion] {
        pages.indices.contains(current) ? pages[current] : []
    }

    private var pageSelected: Bool {
        let open = pageItems.filter { !ownedIDs.contains($0.id) }
        return !open.isEmpty && open.allSatisfy { selection.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader(
                "Propozycje",
                subtitle: "Dotknij, aby zaznaczyć, albo dodaj od razu przyciskiem +. Przesuń w bok, aby zobaczyć kolejną stronę.",
                actionTitle: pageSelected ? "Odznacz" : "Zaznacz stronę",
                action: { onTogglePage(pageItems) }
            )
            ZStack(alignment: .top) {
                UsefulWordsPageCard(
                    items: pageItems,
                    details: result.details,
                    selection: selection,
                    addingIDs: addingIDs,
                    ownedIDs: ownedIDs,
                    onToggle: onToggle,
                    onAdd: onAdd
                )
                .id("\(setNumber)-\(current)")
                .transition(pageTransition)
            }
            .simultaneousGesture(swipe)
            if pages.count > 1 {
                UsefulWordsPageControl(page: current, count: pages.count, onPage: onPage)
            }
            SecondaryButton("Odśwież propozycje", systemImage: "arrow.clockwise", action: onDrawNewSet)
                .disabled(!canDrawNewSet)
                .accessibilityHint(Text("Losuje nowy zestaw słów, których w tym tygodniu jeszcze nie było"))
        }
    }

    /// Przesunięcie w lewo — następna strona, w prawo — poprzednia (tylko wyraźnie poziome, żeby
    /// nie przeszkadzać w przewijaniu ekranu).
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { (value: DragGesture.Value) -> Void in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                onPage(dx < 0 ? current + 1 : current - 1)
            }
    }

    private var pageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}

/// Karta jednej strony (wiersze z polem wyboru).
private struct UsefulWordsPageCard: View {
    let items: [UsefulWordSuggestion]
    let details: [String: UsefulWordDetail]
    let selection: Set<String>
    let addingIDs: Set<String>
    let ownedIDs: Set<String>
    let onToggle: (String) -> Void
    let onAdd: (UsefulWordSuggestion) -> Void

    var body: some View {
        Card(spacing: 0) {
            ForEach(items) { (item: UsefulWordSuggestion) in
                UsefulWordSelectableRow(
                    suggestion: item,
                    detail: details[item.id],
                    isSelected: selection.contains(item.id),
                    isAdding: addingIDs.contains(item.id),
                    isOwned: ownedIDs.contains(item.id),
                    onToggle: { onToggle(item.id) },
                    onAdd: { onAdd(item) }
                )
                if item.id != items.last?.id {
                    Divider()
                }
            }
        }
    }
}

/// „‹ • • • ›” + „Strona 2 z 3”. VoiceOver: jeden element z akcją „dostosuj” (w górę / w dół).
private struct UsefulWordsPageControl: View {
    let page: Int
    let count: Int
    let onPage: (Int) -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            UsefulWordsPageArrow(systemImage: "chevron.left", isEnabled: page > 0) { onPage(page - 1) }
            Spacer(minLength: 0)
            UsefulWordsPageDots(page: page, count: count)
            Text("Strona \(page + 1) z \(count)")
                .font(FluentFont.footnote.monospacedDigit())
                .foregroundStyle(Palette.inkSecondary)
            Spacer(minLength: 0)
            UsefulWordsPageArrow(systemImage: "chevron.right", isEnabled: page < count - 1) { onPage(page + 1) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Strona \(page + 1) z \(count)"))
        .accessibilityHint(Text("Przesuń w górę lub w dół jednym palcem, aby zmienić stronę"))
        .accessibilityAdjustableAction { (direction: AccessibilityAdjustmentDirection) -> Void in
            switch direction {
            case .increment:
                onPage(page + 1)
            case .decrement:
                onPage(page - 1)
            @unknown default:
                break
            }
        }
    }
}

/// Strzałka poprzednia / następna strona (44 × 44).
private struct UsefulWordsPageArrow: View {
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(FluentFont.headline)
                .foregroundStyle(isEnabled ? Palette.accent : Palette.inkTertiary)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

/// Kropki stron.
private struct UsefulWordsPageDots: View {
    let page: Int
    let count: Int

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(0..<max(0, count), id: \.self) { (index: Int) in
                Circle()
                    .fill(index == page ? Palette.accent : Palette.separator)
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
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
