import SwiftUI
import FluentKit

/// Ekran „Polecane słówka”: przydatne słowa z bazy (często używane, do poziomu docelowego,
/// z tematów użytkownika i codzienne). Osadzony w Słowniku jako segment „Polecane”
/// (`embedded: true`); skróty z Dzisiaj i z Postępów prowadzą do tego segmentu
/// (`router.openLibrary(.recommended)`).
///
/// FEEDBACK-5 J2: bez nieskończonego przewijania — zestaw `UsefulWordsPaging.setSize` słów
/// w stronach przewijanych poziomo (przesunięcie, strzałki, kropki; VoiceOver: akcja „dostosuj”).
/// „Odśwież propozycje” losuje nowy zestaw z tej samej puli rankingu, z pominięciem słów
/// pokazanych w tym tygodniu (pamiętane na urządzeniu).
///
/// FEEDBACK-6 K2: strona mieści się na ekranie **bez przewijania w pionie** — liczba słów na
/// stronie (3–6) dobrana do dostępnej wysokości (`UsefulWordsPageArea`, `GeometryReader`);
/// wiersze zwięzłe (hasło, poziom, tłumaczenie, uzasadnienie w 1 linii; przykład, wymowa i pełny
/// opis pod „i”); „Odśwież propozycje” w nagłówku na górze. Dolny pasek ma stałą wysokość
/// (przycisk dodawania / komunikat / wskazówka), żeby zaznaczanie nie zmieniało podziału stron.
/// Tylko przy bardzo dużej czcionce, gdy nie mieszczą się nawet 3 słowa, strona się przewija.
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
    /// Słów na stronie — z dostępnej wysokości (K2).
    @State private var pageSize = UsefulWordsPaging.pageSize
    /// Nie mieszczą się nawet 3 słowa — strona przewijana w pionie (bardzo duża czcionka).
    @State private var pageScrolls = false
    @State private var selection: Set<String> = []
    @State private var addingIDs: Set<String> = []
    @State private var message: String?
    @State private var note: String?
    @State private var addTrigger = 0
    /// Dodane na tym ekranie — zostają w zestawie jako „Masz już” (G6).
    @State private var ownedIDs: Set<String> = []

    // Krótkie `body` (lekcja z pierwszej kompilacji): treść i haptyka w osobnych typach.
    var body: some View {
        screenContent
            .background(Palette.background)
            .modifier(UsefulWordsNavigationTitle(embedded: embedded))
            .task(id: store.revision) { await refresh() }
            .modifier(UsefulWordsFeedback(addTrigger: addTrigger, selectionCount: selection.count, page: page))
    }

    private var screenContent: UsefulWordsScreenContent {
        UsefulWordsScreenContent(
            phase: phase,
            view: viewState,
            selectedCount: selectedItems.count,
            actions: actions
        )
    }

    private var viewState: UsefulWordsViewState {
        UsefulWordsViewState(
            page: page,
            forward: forward,
            setNumber: setNumber,
            pageSize: pageSize,
            pageScrolls: pageScrolls,
            selection: selection,
            addingIDs: addingIDs,
            ownedIDs: ownedIDs,
            message: message,
            note: note,
            canDrawNewSet: canDrawNewSet
        )
    }

    private var actions: UsefulWordsActions {
        UsefulWordsActions(
            onToggle: { (id: String) -> Void in toggle(id) },
            onTogglePage: { (pageItems: [UsefulWordSuggestion]) -> Void in togglePage(pageItems) },
            onAdd: { (item: UsefulWordSuggestion) -> Void in add([item]) },
            onAddSelected: { () -> Void in add(selectedItems) },
            onPage: { (target: Int) -> Void in goToPage(target) },
            onDrawNewSet: { () -> Void in drawNewSet() },
            onFit: { (size: Int?) -> Void in fit(size) }
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

    private var selectedItems: [UsefulWordSuggestion] {
        items.filter { selection.contains($0.id) && !ownedIDs.contains($0.id) }
    }

    private var pageCount: Int {
        UsefulWordsPaging.pages(items, size: pageSize).count
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
        let count = UsefulWordsPaging.pages(set, size: pageSize).count
        if page >= count {
            page = max(0, count - 1)
        }
        let visible = Set(set.map { $0.id }).subtracting(ownedIDs)
        selection = selection.intersection(visible)
    }

    private func goToPage(_ target: Int) {
        let count = pageCount
        guard count > 0 else { return }
        let clamped = min(max(0, target), count - 1)
        guard clamped != page else { return }
        forward = clamped > page
        withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            page = clamped
        }
    }

    /// Nowa wysokość obszaru listy → liczba słów na stronie (pierwsze widoczne słowo zostaje
    /// widoczne). `nil` — nie mieszczą się 3 słowa: strona po 3, przewijana.
    private func fit(_ size: Int?) {
        let scrolls = size == nil
        if pageScrolls != scrolls {
            pageScrolls = scrolls
        }
        let newSize = size ?? UsefulWordsPaging.minPageSize
        guard newSize != pageSize else { return }
        let firstVisible = page * pageSize
        pageSize = newSize
        let count = UsefulWordsPaging.pages(items, size: newSize).count
        page = min(UsefulWordsPaging.page(containing: firstVisible, size: newSize), max(0, count - 1))
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
            note = nil
            if outcome.addedMeanings > 0 {
                ownedIDs.formUnion(ids)
                addTrigger += 1
            }
        }
    }
}

/// Stan widoku przekazywany do treści (jedna wartość zamiast wielu parametrów).
struct UsefulWordsViewState {
    var page: Int
    var forward: Bool
    var setNumber: Int
    var pageSize: Int
    var pageScrolls: Bool
    var selection: Set<String>
    var addingIDs: Set<String>
    var ownedIDs: Set<String>
    var message: String?
    var note: String?
    var canDrawNewSet: Bool
}

/// Akcje ekranu.
struct UsefulWordsActions {
    let onToggle: (String) -> Void
    let onTogglePage: ([UsefulWordSuggestion]) -> Void
    let onAdd: (UsefulWordSuggestion) -> Void
    let onAddSelected: () -> Void
    let onPage: (Int) -> Void
    let onDrawNewSet: () -> Void
    /// Liczba słów mieszczących się na stronie (`nil` — mniej niż 3).
    let onFit: (Int?) -> Void
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

/// Treść ekranu: nagłówek z „Odśwież propozycje”, obszar strony (elastyczny), dolny pasek
/// o stałej wysokości. Całość mieści się w wysokości ekranu — bez przewijania w pionie.
private struct UsefulWordsScreenContent: View {
    let phase: UsefulWordsPhase
    let view: UsefulWordsViewState
    let selectedCount: Int
    let actions: UsefulWordsActions

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            UsefulWordsTopBar(
                level: level,
                canDrawNewSet: view.canDrawNewSet,
                onDrawNewSet: actions.onDrawNewSet
            )
            phaseView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            UsefulWordsBottomBar(
                selectedCount: selectedCount,
                isAdding: !view.addingIDs.isEmpty,
                message: view.message,
                note: view.note,
                hasList: hasList,
                onAddSelected: actions.onAddSelected
            )
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.s)
        .frame(maxWidth: Spacing.readableWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var level: (level: String, target: String)? {
        if case .list(let result) = phase {
            return (result.level, result.targetLevel)
        }
        return nil
    }

    private var hasList: Bool {
        if case .list = phase { return true }
        return false
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
            UsefulWordsPager(result: result, view: view, actions: actions)
        }
    }
}

/// Nagłówek: tytuł z poziomem, „i” (skąd lista) i „Odśwież propozycje” (K2: na górze).
private struct UsefulWordsTopBar: View {
    let level: (level: String, target: String)?
    let canDrawNewSet: Bool
    let onDrawNewSet: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Przydatne słowa")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Spacing.xxs)
            UsefulWordsAboutButton(level: level)
            UsefulWordsRefreshButton(isEnabled: canDrawNewSet, action: onDrawNewSet)
        }
    }

    private var subtitle: String {
        guard let level else { return "Często używane, na Twoim poziomie" }
        return "Do poziomu \(level.target) · Twój poziom: \(level.level)"
    }
}

/// „Odśwież propozycje” — pełny napis, gdy się mieści, inaczej „Odśwież”.
private struct UsefulWordsRefreshButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                label("Odśwież propozycje")
                label("Odśwież")
            }
            .font(FluentFont.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? Palette.accentSoftInk : Palette.inkTertiary)
            .padding(.horizontal, Spacing.s)
            .frame(minHeight: HitTarget.minimum)
            .background(isEnabled ? Palette.accentSoft : Palette.surfaceMuted, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Odśwież propozycje"))
        .accessibilityHint(Text("Losuje nowy zestaw słów, których w tym tygodniu jeszcze nie było"))
    }

    private func label(_ title: String) -> some View {
        Label(title, systemImage: "arrow.clockwise")
            .lineLimit(1)
            .fixedSize()
    }
}

/// „i” w nagłówku: skąd te propozycje (dawny opis nad listą — teraz na życzenie).
private struct UsefulWordsAboutButton: View {
    let level: (level: String, target: String)?

    @State private var isShown = false

    var body: some View {
        Button {
            isShown = true
        } label: {
            Image(systemName: "info.circle")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.accent)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Skąd te propozycje"))
        .popover(isPresented: $isShown) {
            UsefulWordsAboutText(level: level)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct UsefulWordsAboutText: View {
    let level: (level: String, target: String)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Słowa, które naprawdę przydają się w życiu")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
            Text(text)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
            Text("Dotknij słowa, aby je zaznaczyć, albo dodaj od razu przyciskiem +. Przesuń w bok, aby zobaczyć kolejną stronę.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.m)
        .frame(idealWidth: 320, maxWidth: 360)
    }

    private var text: String {
        let range = level.map { (value: (level: String, target: String)) -> String in
            "do poziomu \(value.target) (Twój szacowany poziom: \(value.level))"
        } ?? "na Twoim poziomie"
        return "Tylko często używane w codziennym angielskim, \(range). Najpierw tematy, których się uczysz, i sytuacje z codzienności. Do tego słowa z rodzin wyrazów, które znasz (np. decide → decision) — te mogą być rzadsze i o poziom trudniejsze. Bez słów, które już masz."
    }
}

/// Zestaw w stronach: wiersz z „Zaznacz stronę”, obszar strony (przesunięcie w bok zmienia
/// stronę), wskaźnik stron.
private struct UsefulWordsPager: View {
    let result: UsefulWordsResult
    let view: UsefulWordsViewState
    let actions: UsefulWordsActions

    private var pages: [[UsefulWordSuggestion]] {
        UsefulWordsPaging.pages(result.suggestions, size: view.pageSize)
    }

    private var current: Int { min(max(0, view.page), max(0, pages.count - 1)) }

    private var pageItems: [UsefulWordSuggestion] {
        pages.indices.contains(current) ? pages[current] : []
    }

    private var pageSelected: Bool {
        let open = pageItems.filter { !view.ownedIDs.contains($0.id) }
        return !open.isEmpty && open.allSatisfy { view.selection.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text("Przesuń w bok — kolejna strona")
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: Spacing.xs)
                Button {
                    actions.onTogglePage(pageItems)
                } label: {
                    Text(pageSelected ? "Odznacz" : "Zaznacz stronę")
                        .font(FluentFont.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .lineLimit(1)
                        .frame(minHeight: HitTarget.minimum)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            UsefulWordsPageArea(
                items: pageItems,
                details: result.details,
                pageKey: "\(view.setNumber)-\(current)-\(view.pageSize)",
                view: view,
                current: current,
                actions: actions
            )
            if pages.count > 1 {
                UsefulWordsPageControl(page: current, count: pages.count, onPage: actions.onPage)
            }
        }
    }
}

/// Obszar bieżącej strony: zajmuje całą wolną wysokość, mierzy ją (`GeometryReader`) i zgłasza,
/// ile wierszy się mieści (`actions.onFit`). Strona nie przewija się w pionie — chyba że nie
/// mieszczą się nawet 3 wiersze (bardzo duża czcionka).
private struct UsefulWordsPageArea: View {
    let items: [UsefulWordSuggestion]
    let details: [String: UsefulWordDetail]
    let pageKey: String
    let view: UsefulWordsViewState
    let current: Int
    let actions: UsefulWordsActions

    /// Wysokość zwięzłego wiersza z podziałem (3 linie tekstu + odstępy), skalowana z czcionką.
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 78
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { (proxy: GeometryProxy) in
            pageContent
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .onAppear { report(proxy.size.height) }
                .onChange(of: proxy.size.height) { (_: CGFloat, height: CGFloat) in report(height) }
                .onChange(of: rowHeight) { (_: CGFloat, _: CGFloat) in report(proxy.size.height) }
        }
        .clipped()
    }

    @ViewBuilder
    private var pageContent: some View {
        if view.pageScrolls {
            ScrollView {
                card
            }
            .simultaneousGesture(swipe)
        } else {
            ZStack(alignment: .top) {
                card
                    .id(pageKey)
                    .transition(pageTransition)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
            .simultaneousGesture(swipe)
        }
    }

    private var card: some View {
        UsefulWordsPageCard(
            items: items,
            details: details,
            selection: view.selection,
            addingIDs: view.addingIDs,
            ownedIDs: view.ownedIDs,
            onToggle: actions.onToggle,
            onAdd: actions.onAdd
        )
    }

    /// Wysokość na wiersze = obszar minus wewnętrzny margines karty.
    private func report(_ height: CGFloat) {
        let available = Double(height - 2 * Spacing.xs)
        actions.onFit(UsefulWordsPaging.pageSize(forHeight: available, rowHeight: Double(rowHeight)))
    }

    /// Przesunięcie w lewo — następna strona, w prawo — poprzednia (tylko wyraźnie poziome).
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { (value: DragGesture.Value) -> Void in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
                actions.onPage(dx < 0 ? current + 1 : current - 1)
            }
    }

    private var pageTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: view.forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: view.forward ? .leading : .trailing).combined(with: .opacity)
        )
    }
}

/// Karta jednej strony (zwięzłe wiersze z polem wyboru).
private struct UsefulWordsPageCard: View {
    let items: [UsefulWordSuggestion]
    let details: [String: UsefulWordDetail]
    let selection: Set<String>
    let addingIDs: Set<String>
    let ownedIDs: Set<String>
    let onToggle: (String) -> Void
    let onAdd: (UsefulWordSuggestion) -> Void

    var body: some View {
        Card(padding: Spacing.xs, spacing: 0) {
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

/// Dolny pasek o stałej wysokości: przycisk dodawania zaznaczonych, komunikat po dodaniu albo
/// wskazówka. Stała wysokość = zaznaczanie nie zmienia liczby słów na stronie.
private struct UsefulWordsBottomBar: View {
    let selectedCount: Int
    let isAdding: Bool
    let message: String?
    let note: String?
    let hasList: Bool
    let onAddSelected: () -> Void

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 52

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .center)
    }

    @ViewBuilder
    private var content: some View {
        if selectedCount > 0 {
            PrimaryButton(
                "Dodaj do nauki: \(LibraryText.words(selectedCount))",
                systemImage: "plus",
                isLoading: isAdding,
                action: onAddSelected
            )
        } else if let message {
            UsefulWordsStatusLabel(text: message, systemImage: "checkmark.circle.fill", color: Palette.success)
        } else if let note {
            UsefulWordsStatusLabel(text: note, systemImage: "info.circle", color: Palette.inkSecondary)
        } else if hasList {
            UsefulWordsStatusLabel(
                text: "Dotknij słowa, aby je zaznaczyć, albo dodaj od razu przyciskiem +.",
                systemImage: "hand.tap",
                color: Palette.inkSecondary
            )
        } else {
            Color.clear
        }
    }
}

private struct UsefulWordsStatusLabel: View {
    let text: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(FluentFont.footnote)
            .foregroundStyle(color)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
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
                .lineLimit(1)
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

/// Zwięzły wiersz: pole wyboru, hasło z poziomem, tłumaczenie, uzasadnienie (1 linia),
/// „i” (przykład, wymowa, pełny opis) i „+”.
private struct UsefulWordSelectableRow: View {
    let suggestion: UsefulWordSuggestion
    let detail: UsefulWordDetail?
    let isSelected: Bool
    let isAdding: Bool
    let isOwned: Bool
    let onToggle: () -> Void
    let onAdd: () -> Void

    private var indicator: String {
        if isOwned { return "checkmark.circle.fill" }
        return isSelected ? "checkmark.circle.fill" : "circle"
    }

    private var indicatorColor: Color {
        if isOwned { return Palette.success }
        return isSelected ? Palette.accent : Palette.inkTertiary
    }

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xxs) {
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: Spacing.xs) {
                    Image(systemName: indicator)
                        .font(.system(.title3, design: .default, weight: .regular))
                        .foregroundStyle(indicatorColor)
                        .accessibilityHidden(true)
                    UsefulWordCompactText(suggestion: suggestion)
                        .ownedVocabularyDimmed(isOwned)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isOwned)
            .accessibilityAddTraits(isSelected || isOwned ? [.isSelected] : [])
            .accessibilityHint(Text(isSelected ? "Dotknij, aby odznaczyć" : "Dotknij, aby zaznaczyć"))
            UsefulWordInfoButton(suggestion: suggestion, detail: detail)
            if isOwned {
                OwnedVocabularyBadge()
            } else {
                UsefulWordAddButton(term: suggestion.candidate.term, isAdding: isAdding, action: onAdd)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }
}

/// „i” przy słowie: pełny opis, wymowa i przykład (K2: przykład tylko na życzenie).
private struct UsefulWordInfoButton: View {
    let suggestion: UsefulWordSuggestion
    let detail: UsefulWordDetail?

    @State private var isShown = false

    var body: some View {
        Button {
            isShown = true
        } label: {
            Image(systemName: "info.circle")
                .font(FluentFont.body)
                .foregroundStyle(Palette.accent)
                .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Więcej o „\(suggestion.candidate.term)”"))
        .accessibilityHint(Text("Przykład, wymowa i pełny opis"))
        .popover(isPresented: $isShown) {
            UsefulWordDetailPopover(suggestion: suggestion, detail: detail)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct UsefulWordDetailPopover: View {
    let suggestion: UsefulWordSuggestion
    let detail: UsefulWordDetail?

    @Environment(SpeechService.self) private var speech

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .center, spacing: Spacing.xs) {
                UsefulWordText(suggestion: suggestion, detail: detail, showsExample: false)
                Spacer(minLength: Spacing.xs)
                SpeakButton(size: .small, accessibilityLabel: "Odtwórz wymowę „\(suggestion.candidate.term)”") {
                    speech.speak(suggestion.candidate.term)
                }
            }
            if let ipa = detail?.ipa, !ipa.isEmpty {
                Text(ipa)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if let example = detail?.example {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HighlightedText(example.en, focus: example.focusEn)
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.ink)
                    if !example.pl.isEmpty {
                        Text(example.pl)
                            .font(FluentFont.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.m)
        .frame(idealWidth: 320, maxWidth: 360)
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
