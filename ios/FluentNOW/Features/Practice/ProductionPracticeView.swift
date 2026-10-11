import SwiftUI
import FluentKit

/// Produkcja gramatyczna: luka + polski bezokolicznik → wpisz formę czasownika (`state.production`).
/// Ocena `ProductionGrader.grade` przez `PracticeFlow.answerProduction` (diagnoza: czas, aspekt, strona,
/// zgodność, słowo, pisownia). Reguła ujawniana dopiero po odpowiedzi.
struct ProductionPracticeView: View {
    let autoStart: Bool

    @Environment(LearningStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @State private var isStarting = false
    @State private var error: String?
    @State private var didAutoStart = false

    private var production: ProductionSession? { store.state.production }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    Color.clear.frame(height: 0).id(StudyScrollID.top)
                    if let error {
                        ErrorBanner(message: error, onRetry: { start() }, onDismiss: { self.error = nil })
                    }
                    content(proxy: proxy)
                }
                .frame(maxWidth: Spacing.readableWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task {
            guard autoStart, !didAutoStart else { return }
            didAutoStart = true
            if production == nil || production?.completedAt != nil {
                start()
            }
        }
    }

    @ViewBuilder
    private func content(proxy: ScrollViewProxy) -> some View {
        if let production, !production.set.items.isEmpty {
            if production.completedAt != nil {
                PracticeResultCard(
                    correct: production.results.filter { $0?.correct ?? false }.count,
                    total: production.set.items.count,
                    message: "Zestaw zapisany w historii. Literówki są zaliczone z zaznaczeniem pisowni.",
                    buttonTitle: "Następny zestaw",
                    isLoading: isStarting,
                    onNext: start
                )
            } else {
                StudySessionHeader(title: "Produkcja · " + production.set.level, index: production.index, total: production.set.items.count)
                ProductionItemView(production: production, proxy: proxy)
                    .id("\(production.id):\(production.index)")
            }
        } else {
            PracticeIntroCard(
                eyebrow: "Poziom \(LevelEstimator.estimatedLevel(store.state).targetLevel)",
                title: "Dobierz formę z kontekstu",
                message: "Wpisz angielską formę czasownika. Wskazówek szukaj w zdaniu — w nawiasie znajdziesz tylko polski bezokolicznik. Najpierw zadania, których jeszcze nie widziałeś.",
                buttonTitle: "Rozpocznij",
                isLoading: isStarting,
                onStart: start
            )
        }
        StudyHistoryList(title: "Ostatnie zestawy", lines: StudyHistoryLine.production(store.state.productionHistory))
    }

    private func start() {
        guard !isStarting else { return }
        isStarting = true
        error = nil
        Task { @MainActor in
            defer { isStarting = false }
            do {
                let loaded = try await PracticeContentLoader.load(store: store, library: env.content)
                let now = store.now()
                let started = store.update(.session) { (state: inout LearnerState) -> Bool in
                    let next = PracticeFlow.startProduction(state, level: loaded.level, content: loaded.content, now: now)
                    guard let set = next.production?.set, !set.items.isEmpty else { return false }
                    state = next
                    return true
                }
                if !started {
                    self.error = "Na poziomie \(loaded.level) nie ma jeszcze zadań produkcji."
                }
            } catch {
                self.error = PracticeContentLoader.errorMessage(error)
            }
        }
    }
}

/// Jedno zadanie produkcji.
private struct ProductionItemView: View {
    let production: ProductionSession
    let proxy: ScrollViewProxy

    @Environment(LearningStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var answer = ""
    @State private var startedAt = Date()
    @State private var stoppedSeconds: Double?
    @State private var marked = false
    @FocusState private var focused: Bool

    private var item: ProductionItem? { production.set.items.studyItem(at: production.index) }
    private var result: ProductionResult? { production.results.studyItem(at: production.index) ?? nil }

    var body: some View {
        if let item {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Card(spacing: Spacing.m) {
                    StudyExerciseKindBanner(.grammar, detail: "Wpisywanie formy czasownika")
                    HStack {
                        TagChip(production.source == .ai ? "AI" : "Bank gramatyki", tone: .neutral)
                        Spacer(minLength: Spacing.xs)
                        StudyElapsedClock(startedAt: startedAt, stoppedSeconds: stoppedSeconds)
                    }
                    StudyQuestionLabel(text: "Uzupełnij zdanie właściwą formą czasownika")
                    PracticeContextText(context: item.context)
                    if !item.hintPl.isEmpty && !item.context.contains("(\(item.hintPl))") {
                        Text("Czasownik: \(item.hintPl)")
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    StudySentenceAudioButton(
                        text: ExerciseAudio.exerciseAudioText(context: item.context, solved: result != nil, correctAnswer: item.answer),
                        solved: result != nil
                    )
                    StudyAnswerField(
                        text: result != nil ? Binding.constant(production.answers.studyItem(at: production.index) ?? answer) : $answer,
                        placeholder: "Wpisz formę czasownika…",
                        language: .english,
                        isEnabled: result == nil,
                        focus: $focused,
                        onSubmit: check
                    )
                    if result == nil {
                        PrimaryButton("Sprawdź", systemImage: "arrow.right", action: check)
                            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                if let result {
                    ProductionFeedback(item: item, result: result, answer: production.answers.studyItem(at: production.index) ?? "")
                        .id(StudyScrollID.feedback)
                    PrimaryButton(production.index + 1 < production.set.items.count ? "Następne zadanie" : "Zakończ zestaw", systemImage: "arrow.right") {
                        advance()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .task {
                markSeenIfNeeded(item)
                guard result == nil else { return }
                try? await Task.sleep(nanoseconds: 120_000_000)
                focused = true
            }
            .onChange(of: result != nil) { _, answered in
                guard answered else { return }
                focused = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion)) {
                        proxy.scrollTo(StudyScrollID.feedback, anchor: .top)
                    }
                }
            }
        }
    }

    private func check() {
        let value = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard result == nil, !value.isEmpty else { return }
        stoppedSeconds = max(0.1, Date().timeIntervalSince(startedAt))
        store.update(.answer) { state in
            state = PracticeFlow.answerProduction(state, text: value)
        }
    }

    private func advance() {
        let now = store.now()
        let expectedIndex = production.index
        let sessionID = production.id
        withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            store.update(.answer) { (state: inout LearnerState) -> Void in
                // Podwójne dotknięcie nie może przeskoczyć zadania bez odpowiedzi
                // (`advanceProduction` nie sprawdza wyniku bieżącego zadania).
                guard let current = state.production, current.id == sessionID, current.index == expectedIndex,
                      (current.results.studyItem(at: expectedIndex) ?? nil) != nil else { return }
                state = PracticeFlow.advanceProduction(state, now: now)
            }
        }
        proxy.scrollTo(StudyScrollID.top, anchor: .top)
    }

    private func markSeenIfNeeded(_ item: ProductionItem) {
        guard !marked, production.completedAt == nil, let bankId = item.bankId, !bankId.isEmpty else { return }
        marked = true
        let now = store.now()
        let context = item.context
        store.update(.edit) { state in
            state = GrammarSelector.markSeen(state, bankId: bankId, context: context, at: now)
        }
    }
}

/// Wynik produkcji: diagnoza błędu, poprawna forma, reguła, wyjaśnienie, tłumaczenie.
private struct ProductionFeedback: View {
    let item: ProductionItem
    let result: ProductionResult
    let answer: String

    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        FeedbackPanel(
            kind: result.correct ? (result.spellingCorrect ? .correct : .almost) : .incorrect,
            title: result.correct ? (result.spellingCorrect ? "Poprawnie" : "Zaliczone — popraw pisownię") : "Nie tym razem",
            message: "Poprawna forma: **\(VocabFeedbackSummary.escaped(item.answer))**",
            playsHaptic: preferences.hapticsEnabled
        ) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if let diagnosis = result.diagnosis, !result.correct || diagnosis == .spelling {
                    TagChip(diagnosis.namePl, systemImage: "stethoscope", tone: result.correct ? .warning : .danger)
                        .accessibilityLabel(Text("Diagnoza: \(diagnosis.namePl)"))
                }
                Text("Konstrukcja: **\(item.rule)**")
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.ink)
                StudyExplanationDisclosure(correct: result.correct) {
                    if !result.explanation.isEmpty {
                        Text(result.explanation)
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !item.translation.isEmpty {
                        Text(item.translation)
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                StudyReportButton(draft: StudyReportDraft(
                    mode: "Produkcja gramatyczna",
                    question: item.context,
                    answer: answer,
                    expected: [item.answer] + item.acceptedAnswers
                ))
            }
        }
        .onAppear {
            AccessibilityNotification.Announcement(result.correct ? "Poprawnie" : "Nie tym razem. Poprawna forma: \(item.answer)").post()
        }
    }
}

#Preview("Produkcja gramatyczna") {
    NavigationStack {
        ProductionPracticeView(autoStart: false)
    }
    .fluentPreviewEnvironment()
}
