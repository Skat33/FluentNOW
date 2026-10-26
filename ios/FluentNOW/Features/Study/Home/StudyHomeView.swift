import SwiftUI
import FluentKit

/// Ekran Nauka (FEEDBACK-6 K1, FEEDBACK-8 M2): od góry **Fiszki**, **Ćwiczenia** (jedna siatka:
/// każdy rodzaj zajęć to osobny kafelek — typy słownictwa, codzienna mieszanka, pomyłki, pary,
/// czytanie, gramatyka, idiomy, miks, produkcja; wybór pojedynczy), **Test** (`StudyTestCard`,
/// jedyne miejsce łączenia rodzajów zadań), niżej historia.
/// Bez sekcji „Ile masz czasu?” (łączenia trybów i losowania) i bez kart „Kontynuuj”: postęp
/// przerwanej sesji zapisuje się w tle, a dotknięcie kafelka z przerwaną sesją pokazuje wybór
/// „Kontynuuj, gdzie skończyłem” / „Zacznij od nowa”. Sesja otwiera się jako pełny ekran
/// (`StudyFlowView`).
struct StudyHomeView: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @Environment(AppRouter.self) private var router

    @State private var collection: String?
    @State private var notice: String?
    @State private var activeFlow: StudyFlow?
    @State private var deckCounts: FlashcardDeckCounts?
    @State private var pausedDeck: FlashcardPausedDeck?
    @State private var picturesSnapshot: StudyPicturesSnapshot?
    @State private var resumePrompt: StudyResumePrompt?
    /// Prośba z routera (codzienna mieszanka, pomyłki, pary…) w przygotowaniu.
    @State private var isStarting = false
    /// Zajęcie z czytania / gramatyki, którego nowy zestaw się przygotowuje („Zacznij od nowa”).
    @State private var startingActivity: StudyActivity?
    /// Tryb słownictwa (mieszanka, pomyłki, pary, zdjęcia), którego sesja się przygotowuje.
    @State private var startingMode: StudyMode?
    /// „Ćwiczenia” (J1): długość (5 / 10 min, pamiętana), uruchamiany typ, komunikat przy kafelkach.
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
        .navigationDestination(for: StudyRoute.self) { (route: StudyRoute) in
            switch route {
            case .history:
                StudyHistoryScreen()
            }
        }
        .fullScreenCover(item: $activeFlow, onDismiss: refreshPausedDeck) { (flow: StudyFlow) in
            StudyFlowView(flow: flow)
        }
        .modifier(StudyResumeDialog(
            prompt: $resumePrompt,
            onContinue: { (activity: StudyActivity) -> Void in resume(activity) },
            onRestart: { (activity: StudyActivity) -> Void in restart(activity) }
        ))
        .onChange(of: router.pendingStudyLaunch, initial: true) { (_: StudyLaunchRequest?, request: StudyLaunchRequest?) in
            guard request != nil else { return }
            consumeLaunchIfReady()
        }
        .onChange(of: store.loadPhase) { (_: StoreLoadPhase, _: StoreLoadPhase) in
            consumeLaunchIfReady()
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
        .onAppear(perform: refreshPausedDeck)
    }

    @ViewBuilder
    private var loadedContent: some View {
        let hasWords = !store.activeWords.isEmpty
        if !hasWords {
            StudyNoWordsCard(
                onBrowseTopics: { router.presentTopicSearch() },
                onQuickAdd: { router.presentQuickAdd() }
            )
        }
        if let collection {
            TagChip("Kolekcja: \(collection) ✕", systemImage: "folder", isSelected: true) {
                self.collection = nil
            }
            .accessibilityHint(Text("Usuwa ograniczenie do kolekcji"))
        }
        if hasWords {
            flashcardsCard
        }
        // M2: wszystkie ćwiczenia w jednej siatce (także bez słów — kafelki słownictwa wyjaśniają,
        // czego brakuje; czytanie i gramatyka działają od razu).
        exerciseTypesCard
        // K4 (agent test-mode): karta testu — widok `StudyTestCard` z `Features/Study/Test/`.
        StudyTestCard()
        if hasWords && PictureExercise.isEnabled {
            picturesCard
        }
        StudyRecentHistoryCard(state: store.state)
    }

    // MARK: Karty

    private var flashcardsCard: some View {
        StudyFlashcardsCard(counts: deckCounts, pausedText: pausedDeck?.positionText) {
            open(.flashcards)
        }
    }

    /// „Ćwiczenia” (FEEDBACK-8 M2): jedna siatka, dotknięcie kafelka = start jednego ćwiczenia.
    private var exerciseTypesCard: some View {
        StudyExerciseTypesCard(
            minutes: singleTypeMinutesBinding,
            collection: collection,
            starting: startingTile,
            isBusy: isBusy,
            notice: typeNotice,
            paused: pausedActivities,
            onOpen: { (activity: StudyActivity) -> Void in open(activity) },
            onPictures: { () -> Void in openPicturesFromTypes() },
            onDismissNotice: { () -> Void in typeNotice = nil }
        )
    }

    /// Zajęcie, którego sesja się przygotowuje (wskaźnik na kafelku).
    private var startingTile: StudyActivity? {
        if let startingType { return .singleType(startingType) }
        if let startingActivity { return startingActivity }
        if let startingMode, StudyExerciseAvailability.reviewModes.contains(startingMode) {
            return .vocabulary(startingMode)
        }
        return nil
    }

    /// Coś się uruchamia — kolejne dotknięcia czekają.
    private var isBusy: Bool {
        isStarting || startingType != nil || startingActivity != nil
    }

    private var prefetcher: WordImagePrefetcher {
        WordImagePrefetcher.shared(store: store, images: env.images)
    }

    /// „Słowa i obrazki” — tylko po odblokowaniu trybu (I2); „W budowie” pokazuje kafelek w „Ćwiczeniach”.
    private var picturesCard: some View {
        StudyPicturesCard(
            snapshot: picturesSnapshot,
            status: prefetcher.status,
            statusText: prefetcher.statusText,
            isStarting: isStarting,
            onStart: { startMode(.pictures) }
        )
    }

    private var singleTypeMinutesBinding: Binding<Int> {
        Binding(
            get: { SingleTypeSession.durations.contains(singleTypeMinutes) ? singleTypeMinutes : 5 },
            set: { (value: Int) -> Void in singleTypeMinutes = value }
        )
    }

    // MARK: Przerwane sesje

    /// Zajęcia z kafelków „Ćwiczeń” z przerwaną sesją (znacznik „Przerwane”).
    private var pausedActivities: Set<StudyActivity> {
        var result: Set<StudyActivity> = []
        let state = store.state
        for activity in StudyExerciseGroup.allActivities where StudyResumePrompt.make(for: activity, state: state, pausedDeck: nil) != nil {
            result.insert(activity)
        }
        return result
    }

    private func refreshPausedDeck() {
        pausedDeck = FlashcardPauseStore.load()
    }

    /// Dotknięcie kafelka: przerwana sesja → okno wyboru; inaczej od razu nowa sesja.
    private func open(_ activity: StudyActivity) {
        guard !isBusy else { return }
        let paused = FlashcardPauseStore.load()
        pausedDeck = paused
        if let prompt = StudyResumePrompt.make(for: activity, state: store.state, pausedDeck: paused) {
            resumePrompt = prompt
            return
        }
        startNew(activity)
    }

    /// „Kontynuuj, gdzie skończyłem”.
    private func resume(_ activity: StudyActivity) {
        switch activity {
        case .singleType, .vocabulary:
            activeFlow = .vocabulary
        case .flashcards:
            if let paused = FlashcardPauseStore.load() {
                activeFlow = .resumedFlashcards(paused)
            } else {
                activeFlow = .flashcards(collection: collection)
            }
        case .reading:
            activeFlow = .reading(autoStart: false)
        case .practice(let kind):
            activeFlow = .practice(kind, autoStart: false)
        case .production:
            activeFlow = .production(autoStart: false)
        }
    }

    /// „Zacznij od nowa”: nowa sesja z innymi zdaniami / zadaniami; przerwana zostaje porzucona
    /// (udzielone odpowiedzi są już zapisane).
    private func restart(_ activity: StudyActivity) {
        switch activity {
        case .singleType(let type):
            startSingleType(type, noticeInline: true, fresh: true)
        case .vocabulary(let mode):
            startMode(mode, minutes: singleTypeMinutesBinding.wrappedValue, noticeInline: true, fresh: true)
        case .flashcards:
            FlashcardPauseStore.abandon()
            refreshPausedDeck()
            activeFlow = .flashcards(collection: collection)
        case .reading, .practice, .production:
            restartBank(activity)
        }
    }

    /// Nowa sesja zajęcia bez przerwanej.
    private func startNew(_ activity: StudyActivity) {
        switch activity {
        case .singleType(let type):
            startSingleType(type, noticeInline: true, fresh: false)
        case .vocabulary(let mode):
            startMode(mode, minutes: singleTypeMinutesBinding.wrappedValue, noticeInline: true)
        case .flashcards:
            activeFlow = .flashcards(collection: collection)
        case .reading:
            activeFlow = .reading(autoStart: true)
        case .practice(let kind):
            activeFlow = .practice(kind, autoStart: true)
        case .production:
            activeFlow = .production(autoStart: true)
        }
    }

    private func restartBank(_ activity: StudyActivity) {
        startingActivity = activity
        notice = nil
        Task { @MainActor in
            let outcome = await StudyStarter.restartBank(activity, store: store, content: env.content)
            startingActivity = nil
            show(outcome, noticeInline: false)
        }
    }

    // MARK: Start

    /// Kafelek „Słowo i zdjęcie”: w budowie — informacja przy kafelkach; po odblokowaniu tryb zdjęć.
    private func openPicturesFromTypes() {
        guard PictureExercise.isEnabled else {
            typeNotice = StudyPicturesLockedCard.message
            return
        }
        startMode(.pictures)
    }

    /// Sesja jednego typu. `noticeInline` — komunikat przy kafelkach (dotknięcie kafelka);
    /// prośba z routera (deep link) pokazuje go na górze ekranu.
    private func startSingleType(_ type: ExerciseType, noticeInline: Bool, fresh: Bool) {
        guard !isBusy else { return }
        startingType = type
        typeNotice = nil
        notice = nil
        let minutes = singleTypeMinutesBinding.wrappedValue
        let limitedTo = collection
        Task { @MainActor in
            let outcome = await StudyStarter.startSingleType(type, minutes: minutes, collection: limitedTo, store: store, fresh: fresh)
            startingType = nil
            show(outcome, noticeInline: noticeInline)
        }
    }

    /// Jeden tryb: z kafelka (codzienna mieszanka, pomyłki, pary — `noticeInline`, komunikat przy
    /// siatce) albo z prośby routera (Dzisiaj, deep link — komunikat na górze ekranu).
    /// `fresh` — „Zacznij od nowa”: inne zdania niż w przerwanej sesji.
    private func startMode(_ mode: StudyMode, minutes requested: Int? = nil, noticeInline: Bool = false, fresh: Bool = false) {
        guard !isBusy else { return }
        let hasWords = !store.activeWords.isEmpty
        if mode.isVocabulary && !hasWords {
            let message = "„\(mode.namePl)” ćwiczy słowa z Twojego słownika — najpierw dodaj kilka słów lub cały temat. Czytanie, gramatyka i idiomy działają od razu."
            if noticeInline {
                typeNotice = message
            } else {
                notice = message
            }
            return
        }
        isStarting = true
        startingMode = mode
        notice = nil
        typeNotice = nil
        let minutes = sessionMinutes(requested)
        let limitedTo = collection
        Task { @MainActor in
            let outcome: StudyStarter.Outcome
            if fresh && mode.isVocabulary {
                outcome = await StudyStarter.startVocabulary(mode: mode, minutes: minutes, collection: limitedTo, store: store, images: env.images, fresh: true)
            } else {
                outcome = await StudyStarter.startMode(mode, minutes: minutes, collection: limitedTo, store: store, images: env.images)
            }
            isStarting = false
            startingMode = nil
            show(outcome, noticeInline: noticeInline)
        }
    }

    private func show(_ outcome: StudyStarter.Outcome, noticeInline: Bool) {
        switch outcome {
        case .flow(let flow):
            activeFlow = flow
        case .message(let text):
            if noticeInline {
                typeNotice = text
            } else {
                notice = text
            }
        }
    }

    /// Długość codziennej sesji: z prośby, potem z profilu nauki (G4), domyślnie 10 minut.
    private func sessionMinutes(_ requested: Int?) -> Int {
        if let requested, StudyLaunchRequest.allowedMinutes.contains(requested) {
            return requested
        }
        if let minutes = store.settings.profile?.sessionMinutes, StudyLaunchRequest.allowedMinutes.contains(minutes) {
            return minutes
        }
        return 10
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
        collection = request.collection
        // „Ćwiczenia” (J1): `exercise-<typ>` (np. `fluentnow://study/start?mode=exercise-scramble`).
        if let type = request.modes.compactMap({ (raw: String) -> ExerciseType? in SingleTypeSession.type(ofMode: raw) }).first {
            if let minutes = request.minutes, SingleTypeSession.durations.contains(minutes) {
                singleTypeMinutes = minutes
            }
            startSingleType(type, noticeInline: false, fresh: false)
            return
        }
        // Bez sesji łączonej (K1): z kilku trybów prośby uruchamiamy pierwszy znany —
        // codzienna mieszanka, gdy prośba jej nie określa.
        let mode = StudyHomeView.decodeModes(request.modes.joined(separator: ",")).first ?? .mixed
        if mode == .pictures && !PictureExercise.isEnabled {
            notice = StudyPicturesLockedCard.message
            return
        }
        // Zajęcia z kafelków — przez to samo okno wyboru, gdy czeka przerwana sesja. Sesja
        // słownictwa bez przerwanej startuje od razu z długością z prośby.
        if let activity = StudyHomeView.activity(for: mode) {
            if case .vocabulary = activity, StudyResumePrompt.make(for: activity, state: store.state, pausedDeck: nil) == nil {
                startMode(mode, minutes: request.minutes)
                return
            }
            open(activity)
            return
        }
        startMode(mode, minutes: request.minutes)
    }

    /// Kafelek odpowiadający trybowi z prośby (fiszki, codzienna mieszanka, pomyłki, pary,
    /// czytanie, gramatyka…); `nil` dla zdjęć (kafelek „W budowie”).
    static func activity(for mode: StudyMode) -> StudyActivity? {
        switch mode {
        case .flashcards: return .flashcards
        case .mixed, .mistakes, .pairs: return .vocabulary(mode)
        case .reading: return .reading
        case .production: return .production
        case .grammar: return .practice(.grammar)
        case .idioms: return .practice(.idioms)
        case .languageMix: return .practice(.mixed)
        case .pictures: return nil
        }
    }

    /// Tryby z zapisu „mixed,reading” (bez nieznanych i powtórzeń).
    static func decodeModes(_ raw: String) -> [StudyMode] {
        var result: [StudyMode] = []
        for part in raw.split(separator: ",") {
            if let mode = StudyMode(rawValue: String(part)), !result.contains(mode) {
                result.append(mode)
            }
        }
        return result
    }

    // MARK: Liczniki

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
}

/// Okno „Kontynuuj, gdzie skończyłem” / „Zacznij od nowa” (FEEDBACK-6 K1) — systemowy arkusz
/// akcji (bez własnego szkła).
private struct StudyResumeDialog: ViewModifier {
    @Binding var prompt: StudyResumePrompt?
    let onContinue: (StudyActivity) -> Void
    let onRestart: (StudyActivity) -> Void

    private var isPresented: Binding<Bool> {
        Binding(
            get: { prompt != nil },
            set: { (shown: Bool) -> Void in
                if !shown { prompt = nil }
            }
        )
    }

    func body(content: Content) -> some View {
        content.confirmationDialog(
            Text(prompt?.title ?? "Przerwana sesja"),
            isPresented: isPresented,
            titleVisibility: .visible,
            presenting: prompt
        ) { (shown: StudyResumePrompt) in
            Button("Kontynuuj, gdzie skończyłem") {
                onContinue(shown.activity)
            }
            Button("Zacznij od nowa") {
                onRestart(shown.activity)
            }
            Button("Anuluj", role: .cancel) {}
        } message: { (shown: StudyResumePrompt) in
            Text(shown.detail + "\n" + StudyResumePrompt.restartNote)
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
            Text("Fiszki, jedno wybrane ćwiczenie albo test, który łączy wszystkie rodzaje zadań. Możesz zrobić przerwę w dowolnej chwili — postęp zostaje zapisany.")
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

/// Stan pusty: brak słów — fiszki i ćwiczenia wymagają słów, czytanie, gramatyka i test działają.
private struct StudyNoWordsCard: View {
    let onBrowseTopics: () -> Void
    let onQuickAdd: () -> Void

    var body: some View {
        Card(style: .tinted(.accent), spacing: Spacing.m) {
            Label("Zacznij od kilku słów", systemImage: "text.book.closed")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
            Text("Dodaj pojedyncze słowa albo cały temat — wtedy przygotujemy fiszki i ćwiczenia. Czytanie, gramatyka i idiomy działają od razu.")
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
