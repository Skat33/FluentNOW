import SwiftUI
import FluentKit

/// Czytanie ze zrozumieniem (`state.reading`): tekst z banku na poziomie docelowym. Etapy (G1):
/// sam tekst → pytania ABCD z pamięci (tekst ukryty, `ReadingSession.questionsStartedAt`) →
/// wynik i tekst z fragmentami-dowodami. Zapis przez `PracticeFlow.submitReading` (pytania o słowo w kontekście
/// delikatnie aktualizują rozpoznawanie — waga czytania, nie podnosi automatycznie wyniku słów).
struct ReadingPracticeView: View {
    let autoStart: Bool

    @Environment(LearningStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @Environment(SpeechService.self) private var speech
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isStarting = false
    @State private var error: String?
    @State private var didAutoStart = false
    /// Szacowany poziom liczony poza `body` (przegląd całego słownika) — odświeżany przy zmianie stanu.
    @State private var estimate: LevelEstimate?

    private var current: ReadingSession? { store.state.reading }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Color.clear.frame(height: 0).id(StudyScrollID.top)
                    if let error {
                        ErrorBanner(message: error, onRetry: { start(proxy: proxy) }, onDismiss: { self.error = nil })
                    }
                    if let estimate {
                        ReadingLevelCard(estimate: estimate)
                    }
                    content(proxy: proxy)
                    StudyHistoryList(title: "Ostatnie czytanki", lines: StudyHistoryLine.reading(store.state.readingHistory))
                }
                .frame(maxWidth: Spacing.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
            }
            .task(id: store.revision) {
                let computed = await store.compute { state in LevelEstimator.estimatedLevel(state) }
                guard !Task.isCancelled else { return }
                estimate = computed
            }
            .task {
                guard autoStart, !didAutoStart else { return }
                didAutoStart = true
                if current == nil || current?.submitted == true {
                    start(proxy: proxy)
                }
            }
        }
    }

    /// G1: najpierw sam tekst → pytania z pamięci (tekst ukryty) → wyniki i tekst z dowodami.
    @ViewBuilder
    private func content(proxy: ScrollViewProxy) -> some View {
        if let current {
            switch current.stage {
            case .reading:
                ReadingFirstStage(reading: current.reading, questionCount: current.reading.questions.count) {
                    beginQuestions(proxy: proxy)
                }
            case .questions:
                ReadingQuestionsStage(session: current, onSelect: { (index: Int, choice: Int) in
                    select(question: index, choice: choice)
                }, onSubmit: {
                    submit(proxy: proxy)
                })
            case .results:
                ReadingResultsStage(session: current, isStarting: isStarting) {
                    start(proxy: proxy)
                }
            }
        } else {
            PracticeIntroCard(
                eyebrow: "Czytanie ze zrozumieniem",
                title: "Mała historia. Więcej zrozumienia.",
                message: "Bank tekstów A1–C2 działa od razu i bez internetu. Im wyższy poziom, tym dłuższy tekst i więcej pytań o intencje, wnioski oraz pozornie podobne informacje.",
                buttonTitle: "Przygotuj czytankę",
                isLoading: isStarting
            ) {
                start(proxy: proxy)
            }
        }
    }

    private func beginQuestions(proxy: ScrollViewProxy) {
        let now = store.now()
        store.update(.answer) { (state: inout LearnerState) -> Void in
            guard var reading = state.reading else { return }
            reading.beginQuestions(at: now)
            state.reading = reading
        }
        speech.stop()
        AccessibilityNotification.Announcement("Tekst ukryty. Odpowiadaj z pamięci.").post()
        proxy.scrollTo(StudyScrollID.top, anchor: .top)
    }

    private func select(question index: Int, choice: Int) {
        store.update(.answer) { (state: inout LearnerState) -> Void in
            guard var reading = state.reading else { return }
            reading.answer(question: index, choice: choice)
            state.reading = reading
        }
    }

    private func submit(proxy: ScrollViewProxy) {
        let now = store.now()
        store.update(.answer) { state in
            state = PracticeFlow.submitReading(state, now: now)
        }
        let correct = store.state.reading?.correctCount ?? 0
        let total = store.state.reading?.reading.questions.count ?? 0
        AccessibilityNotification.Announcement("\(correct) z \(total) poprawnych odpowiedzi").post()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion)) {
                proxy.scrollTo(StudyScrollID.feedback, anchor: .top)
            }
        }
    }

    private func start(proxy: ScrollViewProxy) {
        guard !isStarting else { return }
        isStarting = true
        error = nil
        Task { @MainActor in
            defer { isStarting = false }
            do {
                let loaded = try await PracticeContentLoader.load(store: store, library: env.content)
                let started = store.update(.session) { (state: inout LearnerState) -> Bool in
                    let next = PracticeFlow.startReading(state, bank: loaded.content.readings)
                    // `startReading` zwraca stan bez zmian, gdy w banku nie ma tekstu na tym poziomie.
                    guard let reading = next.reading, !reading.submitted else {
                        return false
                    }
                    state = next
                    return true
                }
                if started {
                    proxy.scrollTo(StudyScrollID.top, anchor: .top)
                } else {
                    self.error = "Nie mamy teraz nowej czytanki na Twoim poziomie. Spróbuj później lub wybierz inny rodzaj ćwiczeń."
                }
            } catch {
                self.error = PracticeContentLoader.errorMessage(error)
            }
        }
    }
}

/// „Twój poziom: B1 · tekst: B2” z uczciwym opisem pewności.
private struct ReadingLevelCard: View {
    let estimate: LevelEstimate

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "book")
                .font(FluentFont.title)
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Twój poziom: \(estimate.level) · tekst: \(estimate.targetLevel)")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .fluentCardBackground(.tinted(.accent))
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        guard estimate.count > 0 else {
            return "Wstępnie A1; tekst jest o jeden krok wyżej. Poziom dopasuje się do wyników nauki."
        }
        let confidence = estimate.confidence == .high ? "wyższa" : "wstępna"
        return "Na podstawie \(estimate.count) znaczeń · pewność \(confidence). To wskazówka, nie certyfikowana ocena."
    }
}

#Preview("Czytanie") {
    NavigationStack {
        ReadingPracticeView(autoStart: false)
    }
    .fluentPreviewEnvironment()
}
