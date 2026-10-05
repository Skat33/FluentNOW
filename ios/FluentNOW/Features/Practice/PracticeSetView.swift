import SwiftUI
import FluentKit

/// Gramatyka / idiomy / miks językowy — zestaw pytań ABCD i z wpisywaniem (`state.practice`).
/// Przejścia stanu wyłącznie przez `PracticeFlow` (FluentKit).
struct PracticeSetView: View {
    let kind: PracticeKind
    let autoStart: Bool

    @Environment(LearningStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @State private var isStarting = false
    @State private var error: String?
    @State private var variants = AnswerVariants.builtIn
    @State private var didAutoStart = false

    private var practice: PracticeSession? {
        guard let practice = store.state.practice, practice.set.kind == kind else { return nil }
        return practice
    }

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
            variants = await env.content.answerVariants()
        }
        .task {
            guard autoStart, !didAutoStart else { return }
            didAutoStart = true
            if practice == nil || practice?.completedAt != nil {
                start()
            }
        }
    }

    @ViewBuilder
    private func content(proxy: ScrollViewProxy) -> some View {
        if let practice, !practice.set.items.isEmpty {
            if practice.completedAt != nil {
                PracticeResultCard(
                    correct: PracticeSetView.correctCount(practice),
                    total: practice.set.items.count,
                    message: "Zestaw zapisaliśmy w historii. Możesz od razu rozpocząć kolejny.",
                    buttonTitle: "Następny zestaw",
                    isLoading: isStarting,
                    onNext: start
                )
            } else {
                StudySessionHeader(title: kind.studyTitle + " · " + practice.set.level, index: practice.index, total: practice.set.items.count)
                PracticeItemView(practice: practice, variants: variants, proxy: proxy)
                    .id("\(practice.set.id):\(practice.index)")
            }
        } else {
            PracticeIntroCard(
                eyebrow: "Poziom \(LevelEstimator.estimatedLevel(store.state).targetLevel)",
                title: kind.studyTitle,
                message: PracticeSetView.introText(kind),
                buttonTitle: "Rozpocznij zestaw",
                isLoading: isStarting,
                onStart: start
            )
        }
        StudyHistoryList(title: "Ostatnie zestawy", lines: StudyHistoryLine.practice(store.state.practiceHistory, kind: kind))
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
                    let next = PracticeFlow.startPractice(state, kind: kind, level: loaded.level, content: loaded.content, now: now)
                    guard let set = next.practice?.set, !set.items.isEmpty else { return false }
                    state = next
                    return true
                }
                if !started {
                    self.error = "Na poziomie \(loaded.level) nie ma jeszcze zadań tego rodzaju."
                }
            } catch {
                self.error = PracticeContentLoader.errorMessage(error)
            }
        }
    }

    static func correctCount(_ practice: PracticeSession) -> Int {
        var count = 0
        for (index, item) in practice.set.items.enumerated() where practice.answers.studyItem(at: index) == item.answer {
            count += 1
        }
        return count
    }

    static func introText(_ kind: PracticeKind) -> String {
        switch kind {
        case .grammar:
            return "Ponad 300 zdań na Twoim poziomie, dostępnych od razu i bez internetu. Najpierw zobaczysz zadania, których jeszcze nie rozwiązywałeś."
        case .idioms:
            return "Znaczenie, kontekst i różnice, które pomagają używać idiomów naturalnie."
        case .mixed:
            return "Gramatyka i idiomy w różnych sytuacjach: pytania ABCD i luki do samodzielnego uzupełnienia."
        }
    }
}

/// Jedno pytanie zestawu.
private struct PracticeItemView: View {
    let practice: PracticeSession
    let variants: AnswerVariants
    let proxy: ScrollViewProxy

    @Environment(LearningStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var written = ""
    @State private var hintShown = false
    @State private var startedAt = Date()
    @State private var stoppedSeconds: Double?
    @State private var marked = false
    @FocusState private var focused: Bool

    private var item: PracticeQuestion? { practice.set.items.studyItem(at: practice.index) }
    private var chosen: Int { practice.answers.studyItem(at: practice.index) ?? -1 }
    private var answered: Bool { chosen >= 0 }

    var body: some View {
        if let item {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Card(spacing: Spacing.m) {
                    StudyExerciseKindBanner(item.category == .idiom ? .idioms : .grammar, detail: item.isInput ? "Wpisz odpowiedź" : "Wybierz odpowiedź")
                    HStack {
                        TagChip(practice.set.source == .ai ? "AI" : "Gotowy zestaw", tone: .neutral)
                        Spacer(minLength: Spacing.xs)
                        StudyElapsedClock(startedAt: startedAt, stoppedSeconds: stoppedSeconds)
                    }
                    Text(item.prompt)
                        .font(FluentFont.title)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    PracticeContextText(context: item.context)
                    StudySentenceAudioButton(
                        text: ExerciseAudio.exerciseAudioText(context: item.context, solved: answered, correctAnswer: item.correctOption),
                        solved: answered
                    )
                    if item.isInput {
                        inputArea(item)
                    } else {
                        StudyChoiceList(
                            options: item.options,
                            selected: answered ? chosen : nil,
                            correct: item.answer,
                            isRevealed: answered,
                            isEnabled: !answered
                        ) { index in
                            answer(choice: index)
                        }
                    }
                }
                if answered {
                    PracticeAnswerFeedback(item: item, practice: practice, chosen: chosen)
                        .id(StudyScrollID.feedback)
                    PrimaryButton(practice.index + 1 < practice.set.items.count ? "Następne pytanie" : "Zakończ zestaw", systemImage: "arrow.right") {
                        advance()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .task {
                markSeenIfNeeded(item)
                if item.isInput && !answered {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    focused = true
                }
            }
            .onChange(of: answered) { _, isAnswered in
                guard isAnswered else { return }
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

    @ViewBuilder
    private func inputArea(_ item: PracticeQuestion) -> some View {
        StudyAnswerField(
            text: answered ? Binding.constant(practice.writtenAnswers?.studyItem(at: practice.index) ?? written) : $written,
            placeholder: "Wpisz odpowiedź…",
            language: item.category == .idiom ? .polish : .english,
            isEnabled: !answered,
            focus: $focused,
            onSubmit: checkWritten
        )
        if hintShown && !answered {
            StudyHintBox(text: (item.inputHint ?? "").isEmpty ? "Dobierz formę do kontekstu zdania." : (item.inputHint ?? ""))
        }
        if !answered {
            HStack(spacing: Spacing.s) {
                if !hintShown {
                    StudyHintButton { hintShown = true }
                }
                Spacer(minLength: Spacing.xs)
                PrimaryButton("Sprawdź", systemImage: "arrow.right", fillsWidth: false, action: checkWritten)
                    .disabled(written.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func answer(choice: Int) {
        guard !answered else { return }
        stoppedSeconds = max(0.1, Date().timeIntervalSince(startedAt))
        store.update(.answer) { state in
            state = PracticeFlow.answerPractice(state, choice: choice)
        }
    }

    private func checkWritten() {
        let value = written.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answered, !value.isEmpty else { return }
        stoppedSeconds = max(0.1, Date().timeIntervalSince(startedAt))
        let currentVariants = variants
        store.update(.answer) { state in
            state = PracticeFlow.answerPracticeWritten(state, text: value, variants: currentVariants).state
        }
    }

    private func advance() {
        let now = store.now()
        withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            store.update(.answer) { state in
                state = PracticeFlow.advancePractice(state, now: now)
            }
        }
        proxy.scrollTo(StudyScrollID.top, anchor: .top)
    }

    /// Jak strona: zadanie gramatyczne z banku oznaczamy jako widziane przy wyświetleniu.
    private func markSeenIfNeeded(_ item: PracticeQuestion) {
        guard !marked, practice.completedAt == nil, item.category == .grammar,
              let bankId = item.bankId, !bankId.isEmpty else { return }
        marked = true
        let now = store.now()
        let context = item.context
        store.update(.edit) { state in
            state = GrammarSelector.markSeen(state, bankId: bankId, context: context, at: now)
        }
    }
}

/// Wynik pytania zestawu.
private struct PracticeAnswerFeedback: View {
    let item: PracticeQuestion
    let practice: PracticeSession
    let chosen: Int

    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        let correct = chosen == item.answer
        let expected = item.isInput ? item.correctOption : "\(StudyFormat.letter(item.answer)). \(item.correctOption)"
        FeedbackPanel(
            kind: correct ? .correct : .incorrect,
            title: correct ? "Dobrze!" : "Nie tym razem",
            message: correct ? nil : "Poprawna odpowiedź: **\(VocabFeedbackSummary.escaped(expected))**",
            playsHaptic: preferences.hapticsEnabled
        ) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                StudyExplanationDisclosure(correct: correct) {
                    if !item.explanation.isEmpty {
                        Text(item.explanation)
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
                    mode: practice.set.kind.studyTitle,
                    question: item.prompt + "\n" + item.context,
                    answer: item.isInput ? (practice.writtenAnswers?.studyItem(at: practice.index) ?? "") : (item.options.studyItem(at: chosen) ?? ""),
                    expected: [item.correctOption] + (item.acceptedAnswers ?? [])
                ))
            }
        }
        .onAppear {
            AccessibilityNotification.Announcement(correct ? "Dobrze" : "Nie tym razem. Poprawnie: \(expected)").post()
        }
    }
}

#Preview("Gramatyka") {
    NavigationStack {
        PracticeSetView(kind: .grammar, autoStart: false)
    }
    .fluentPreviewEnvironment()
}
