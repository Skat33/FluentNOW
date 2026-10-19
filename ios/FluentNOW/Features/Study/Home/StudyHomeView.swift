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
    /// `updatedAt` profilu nauki (G4), którego domyślne tryby i czas już zastosowano — po edycji
    /// profilu domyślne wartości wracają, a między edycjami zostaje wybór użytkownika.
    @AppStorage("study.profileApplied") private var profileApplied: Double = 0

    @State private var collection: String?
    @State private var isStarting = false
    @State private var notice: String?
    @State private var estimate = ""
    @State private var activeFlow: StudyFlow?
    @State private var combinedDraft: CombinedSession?
    @State private var flowAfterSheet: StudyFlow?
    @State private var deckCounts: FlashcardDeckCounts?
    @State private var picturesSnapshot: StudyPicturesSnapshot?
    /// „Ćwicz wybrany typ” (J1): długość (5 / 10 min, pamiętana), uruchamiany typ, komunikat przy kafelkach.
    @AppStorage("study.singleTypeMinutes") private var singleTypeMinutes = 5
    @State private var startingType: ExerciseType?
    @State private var typeNotice: String?

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
        .task(id: deckKey) {
            await updateDeckCounts()
        }
        .task(id: store.loadPhase) {
            // Zdjęcia do „Słowo i zdjęcie” pobierają się w tle przed sesją (G2, H2).
            env.prefetchWordImages()
        }
        .task(id: picturesKey) {
            await updatePicturesSnapshot()
        }
        .onChange(of: store.settings.profile?.updatedAt, initial: true) { (_: Double?, _: Double?) in
            applyProfileDefaults()
        }
    }

    /// Domyślne tryby i czas z profilu nauki (G4, `LearnerProfile.dailyMixModes` / `sessionMinutes`).
    private func applyProfileDefaults() {
        guard let profile = store.settings.profile, profile.updatedAt > profileApplied else { return }
        profileApplied = profile.updatedAt
        let minutes = profile.sessionMinutes
        if StudyLaunchRequest.allowedMinutes.contains(minutes) {
            storedMinutes = minutes
        }
        let modes = profile.dailyMixModes(limit: 3)
        if !modes.isEmpty {
            storedModes = modes.map(\.rawValue).joined(separator: ",")
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
                onBrowseTopics: { router.presentTopicSearch() },
                onQuickAdd: { router.presentQuickAdd() }
            )
        }
        if prefersFlashcards && !store.activeWords.isEmpty {
            flashcardsCard
        }
        if prefersPictures && !store.activeWords.isEmpty {
            picturesCard
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
        if !store.activeWords.isEmpty {
            exerciseTypesCard
        }
        if !prefersFlashcards && !store.activeWords.isEmpty {
            flashcardsCard
        }
        if !prefersPictures && !store.activeWords.isEmpty {
            picturesCard
        }
        StudyRecentHistoryCard(state: store.state)
    }

    /// Profil nauki (G4): „Fiszki” wśród ulubionych → karta talii nad wyborem trybów.
    private var prefersFlashcards: Bool {
        store.settings.profile?.styles.contains(.flashcards) ?? false
    }

    /// Profil nauki (G4): „Obrazki” wśród ulubionych → karta „Słowa i obrazki” nad wyborem trybów.
    /// Gdy tryb jest „W budowie” (I2), preferencja niczego nie zmienia — karta zostaje na dole.
    private var prefersPictures: Bool {
        PictureExercise.isEnabled && (store.settings.profile?.styles.contains(.pictures) ?? false)
    }

    /// „Ćwicz wybrany typ” (FEEDBACK-5 J1).
    private var exerciseTypesCard: some View {
        StudyExerciseTypesCard(
            minutes: singleTypeMinutesBinding,
            collection: collection,
            startingType: startingType,
            notice: typeNotice,
            onStart: { (type: ExerciseType) -> Void in startSingleType(type, noticeInline: true) },
            onPictures: { () -> Void in openPicturesFromTypes() },
            onDismissNotice: { () -> Void in typeNotice = nil }
        )
    }

    private var singleTypeMinutesBinding: Binding<Int> {
        Binding(
            get: { SingleTypeSession.durations.contains(singleTypeMinutes) ? singleTypeMinutes : 5 },
            set: { singleTypeMinutes = $0 }
        )
    }

    /// Kafelek „Słowo i zdjęcie”: w budowie — informacja przy kafelkach; po odblokowaniu tryb zdjęć.
    private func openPicturesFromTypes() {
        guard PictureExercise.isEnabled else {
            typeNotice = StudyPicturesLockedCard.message
            return
        }
        start(modes: [.pictures])
    }

    /// Sesja jednego typu. `noticeInline` — komunikat przy kafelkach (dotknięcie kafelka);
    /// prośba z routera (deep link) pokazuje go na górze ekranu.
    private func startSingleType(_ type: ExerciseType, noticeInline: Bool) {
        // Osobny stan od `isStarting` — przycisk „Rozpocznij sesję” nie pokazuje wtedy ładowania.
        guard !isStarting, startingType == nil else { return }
        startingType = type
        typeNotice = nil
        notice = nil
        let minutes = singleTypeMinutesBinding.wrappedValue
        let limitedTo = collection
        Task { @MainActor in
            let outcome = await StudyStarter.startSingleType(type, minutes: minutes, collection: limitedTo, store: store)
            startingType = nil
            switch outcome {
            case .flow(let flow):
                activeFlow = flow
            case .combinedDraft(let draft):
                combinedDraft = draft
            case .message(let text):
                if noticeInline {
                    typeNotice = text
                } else {
                    notice = text
                }
            }
        }
    }

    private var flashcardsCard: some View {
        StudyFlashcardsCard(counts: deckCounts) {
            activeFlow = .flashcards(collection: collection)
        }
    }

    private var prefetcher: WordImagePrefetcher {
        WordImagePrefetcher.shared(store: store, images: env.images)
    }

    @ViewBuilder
    private var picturesCard: some View {
        if PictureExercise.isEnabled {
            StudyPicturesCard(
                snapshot: picturesSnapshot,
                status: prefetcher.status,
                statusText: prefetcher.statusText,
                isStarting: isStarting,
                onStart: { start(modes: [.pictures]) }
            )
        } else {
            // „W budowie” (I2): karta wyszarzona, dotknięcie — krótka informacja.
            StudyPicturesLockedCard {
                notice = StudyPicturesLockedCard.message
            }
        }
    }

    /// Klucz odświeżenia karty zdjęć: zmiana słów/wyników albo nowe zdjęcia na dysku.
    private var picturesKey: String {
        "\(store.revision)|\(prefetcher.cachedCount)|\(store.loadPhase == .ready)"
    }

    private func updatePicturesSnapshot() async {
        guard PictureExercise.isEnabled, store.loadPhase == .ready else { return }
        picturesSnapshot = await StudyPicturesSnapshot.make(store: store, images: env.images)
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
            get: { StudyHomeView.decodeModes(storedModes).filter { (mode: StudyMode) -> Bool in mode.isCombinable } },
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

    private var deckKey: String {
        "\(store.revision)|\(collection ?? "")"
    }

    /// Liczniki talii fiszek (do powtórki / nowe / trudne) — liczone poza głównym wątkiem.
    private func updateDeckCounts() async {
        guard store.loadPhase == .ready else { return }
        let limitedTo = collection
        let now = store.now()
        deckCounts = await store.compute { (state: LearnerState) -> FlashcardDeckCounts in
            FlashcardDeckBuilder.counts(state: state, collection: limitedTo, now: now)
        }
    }

    // MARK: Start

    private func start(modes requested: [StudyMode]) {
        guard !isStarting, startingType == nil else { return }
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
                content: env.content,
                images: env.images
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
        // „Ćwicz wybrany typ” (J1): `exercise-<typ>` (np. `fluentnow://study/start?mode=exercise-scramble`).
        if let type = request.modes.compactMap({ (raw: String) -> ExerciseType? in SingleTypeSession.type(ofMode: raw) }).first {
            collection = request.collection
            if let minutes = request.minutes, SingleTypeSession.durations.contains(minutes) {
                singleTypeMinutes = minutes
            }
            startSingleType(type, noticeInline: false)
            return
        }
        var modes = request.modes.compactMap { StudyMode(rawValue: $0) }
        // Fiszki to osobny ekran (G3) — bez zmiany zapamiętanego wyboru trybów.
        if modes.contains(.flashcards) {
            collection = request.collection
            activeFlow = .flashcards(collection: request.collection)
            return
        }
        // „Słowa i obrazki” (H2) — osobny tryb, bez zmiany zapamiętanego wyboru trybów.
        if modes.contains(.pictures) {
            guard PictureExercise.isEnabled else {
                notice = StudyPicturesLockedCard.message
                return
            }
            collection = request.collection
            start(modes: [.pictures])
            return
        }
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
        case .flashcards:
            estimate = "Talia fiszek — we własnym tempie"
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
        SecondaryButton("Szukaj tematu", systemImage: "magnifyingglass", action: onBrowseTopics)
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
