import SwiftUI
import FluentKit

/// Ekran „Na co masz dziś ochotę?” — wybór trybów i czasu, wznowienie przerwanych sesji,
/// historia. Sesja otwiera się jako pełny ekran (`StudyFlowView`).
struct StudyHomeView: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @Environment(AppRouter.self) private var router

    @AppStorage("study.minutes") private var storedMinutes = 10
    @AppStorage("study.modes") private var storedModes = StudyMode.mixed.rawValue
    @AppStorage("study.random") private var random = false

    @State private var collection: String?
    @State private var isStarting = false
    @State private var notice: String?
    @State private var estimate = ""
    @State private var activeFlow: StudyFlow?
    @State private var combinedDraft: CombinedSession?
    @State private var flowAfterSheet: StudyFlow?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                StudyHomeHeader()
                if let loadError {
                    ErrorBanner(message: loadError)
                }
                if let notice {
                    StudyNoticeCard(message: notice) { self.notice = nil }
                }
                if store.loadPhase == .loading {
                    LoadingStateView("Wczytywanie Twoich słów…")
                } else {
                    loadedContent
                }
            }
            .frame(maxWidth: Spacing.readableWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.xl)
        }
        .background(Palette.background)
        .navigationTitle("Nauka")
        .navigationDestination(for: StudyRoute.self) { route in
            switch route {
            case .history:
                StudyHistoryScreen()
            }
        }
        .fullScreenCover(item: $activeFlow) { flow in
            StudyFlowView(flow: flow)
        }
        .sheet(item: $combinedDraft, onDismiss: presentFlowAfterSheet) { draft in
            StudyCombinedDraftSheet(draft: draft) {
                StudyStarter.commitCombined(draft, store: store)
                flowAfterSheet = .combined
                combinedDraft = nil
            }
        }
        .onChange(of: router.pendingStudyLaunch, initial: true) { _, request in
            guard request != nil else { return }
            consumeLaunchIfReady()
        }
        .onChange(of: store.loadPhase) { _, _ in
            consumeLaunchIfReady()
        }
        .task(id: estimateKey) {
            await updateEstimate()
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        let resumeItems = StudyResumeItem.items(in: store.state)
        ForEach(resumeItems) { item in
            StudyResumeCard(item: item) {
                activeFlow = item.flow
            }
        }
        if store.activeWords.isEmpty {
            StudyNoWordsCard(
                onBrowseTopics: { router.openLibrary(.topics) },
                onQuickAdd: { router.presentQuickAdd() }
            )
        }
        StudySetupCard(
            minutes: minutesBinding,
            selected: modesBinding,
            random: $random,
            hasWords: !store.activeWords.isEmpty,
            collection: collection,
            estimate: estimate,
            isStarting: isStarting,
            onClearCollection: { collection = nil },
            onStart: { start(modes: modesBinding.wrappedValue) }
        )
        StudyRecentHistoryCard(state: store.state)
    }

    private var loadError: String? {
        if case .failed(let message) = store.loadPhase { return message }
        return nil
    }

    // MARK: Wybór (pamiętany na urządzeniu)

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { StudyLaunchRequest.allowedMinutes.contains(storedMinutes) ? storedMinutes : 10 },
            set: { storedMinutes = $0 }
        )
    }

    private var modesBinding: Binding<[StudyMode]> {
        Binding(
            get: { StudyHomeView.decodeModes(storedModes) },
            set: { storedModes = $0.map(\.rawValue).joined(separator: ",") }
        )
    }

    static func decodeModes(_ raw: String) -> [StudyMode] {
        var result: [StudyMode] = []
        for part in raw.split(separator: ",") {
            if let mode = StudyMode(rawValue: String(part)), !result.contains(mode) {
                result.append(mode)
            }
        }
        return result
    }

    private var estimateKey: String {
        "\(storedModes)|\(minutesBinding.wrappedValue)|\(collection ?? "")|\(store.activeWords.count)"
    }

    // MARK: Start

    private func start(modes requested: [StudyMode]) {
        guard !isStarting else { return }
        let hasWords = !store.activeWords.isEmpty
        let modes = hasWords ? requested : requested.filter { !$0.isVocabulary }
        guard !modes.isEmpty else {
            notice = "Najpierw dodaj kilka słów lub cały temat — albo wybierz czytanie, gramatykę lub idiomy."
            return
        }
        isStarting = true
        notice = nil
        let minutes = minutesBinding.wrappedValue
        let shuffle = random
        let limitedTo = collection
        Task { @MainActor in
            let outcome = await StudyStarter.start(
                modes: modes,
                minutes: minutes,
                random: shuffle,
                collection: limitedTo,
                store: store,
                content: env.content
            )
            isStarting = false
            switch outcome {
            case .flow(let flow):
                activeFlow = flow
            case .combinedDraft(let draft):
                combinedDraft = draft
            case .message(let text):
                notice = text
            }
        }
    }

    private func presentFlowAfterSheet() {
        guard let flow = flowAfterSheet else { return }
        flowAfterSheet = nil
        activeFlow = flow
    }

    /// Prośba z routera (Dzisiaj, deep link, przypomnienie) — po wczytaniu danych.
    private func consumeLaunchIfReady() {
        guard router.pendingStudyLaunch != nil, store.loadPhase != .loading else { return }
        guard let request = router.consumeStudyLaunch() else { return }
        guard activeFlow == nil else { return }
        if request.resume {
            if let item = StudyResumeItem.items(in: store.state).first {
                activeFlow = item.flow
            } else {
                notice = "Nie ma przerwanej sesji — wybierz, co chcesz poćwiczyć."
            }
            return
        }
        var modes = request.modes.compactMap { StudyMode(rawValue: $0) }
        if modes.isEmpty { modes = [.mixed] }
        modesBinding.wrappedValue = modes
        if let minutes = request.minutes, StudyLaunchRequest.allowedMinutes.contains(minutes) {
            storedMinutes = minutes
        }
        collection = request.collection
        start(modes: modes)
    }

    private func updateEstimate() async {
        let modes = modesBinding.wrappedValue
        let minutes = minutesBinding.wrappedValue
        guard let first = modes.first else {
            estimate = "Wybierz rodzaj ćwiczeń"
            return
        }
        if modes.count > 1 {
            let count = max(modes.count, Int((Double(minutes) / 5).rounded()) * CombinedSessionBuilder.tasksPerFiveMinutes)
            estimate = "Około \(minutes) min · \(StudyFormat.tasks(count))"
            return
        }
        switch first {
        case .reading:
            estimate = "Około \(minutes) min · tekst i 3–6 pytań"
        case .grammar, .idioms, .languageMix, .production:
            estimate = "Około \(minutes) min · zestaw \(StudyFormat.tasks(6))"
        default:
            let limitedTo = collection
            let count = await store.compute { state in
                SessionBuilder.makeSession(state: state, minutes: minutes, mode: first, collection: limitedTo).tasks.count
            }
            estimate = "Około \(minutes) min · \(StudyFormat.exercises(count))"
        }
    }
}

/// Nagłówek ekranu.
private struct StudyHomeHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Kilka minut dla siebie")
                .fluentEyebrow()
                .foregroundStyle(Palette.accent)
            Text("Na co masz dziś ochotę?")
                .font(FluentFont.display)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Wybierz swój rytm. Możesz zrobić przerwę w dowolnej chwili — postęp zostaje zapisany.")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Spacing.xs)
    }
}

/// Spokojny komunikat (np. brak zadań w trybie pomyłek).
private struct StudyNoticeCard: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Palette.info)
                .accessibilityHidden(true)
            Text(message)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(FluentFont.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Zamknij komunikat"))
        }
        .padding(Spacing.m)
        .fluentCardBackground(.tinted(.info), cornerRadius: Radius.medium)
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

/// Stan pusty: brak słów — nauka słownictwa wymaga słów, reszta trybów działa.
private struct StudyNoWordsCard: View {
    let onBrowseTopics: () -> Void
    let onQuickAdd: () -> Void

    var body: some View {
        Card(style: .tinted(.accent), spacing: Spacing.m) {
            Label("Zacznij od kilku słów", systemImage: "text.book.closed")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
            Text("Dodaj pojedyncze słowa albo cały temat — wtedy przygotujemy sesje słownictwa. Czytanie, gramatyka i idiomy działają od razu.")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) { buttons }
                VStack(spacing: Spacing.xs) { buttons }
            }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        SecondaryButton("Przeglądaj tematy", systemImage: "square.grid.2x2", action: onBrowseTopics)
        SecondaryButton("Dodaj słowo", systemImage: "plus", action: onQuickAdd)
    }
}

#Preview("Nauka") {
    NavigationStack {
        StudyHomeView()
    }
    .fluentPreviewEnvironment()
}

#Preview("Nauka — bez słów") {
    NavigationStack {
        StudyHomeView()
    }
    .fluentPreviewEnvironment(.previewEmpty)
}
