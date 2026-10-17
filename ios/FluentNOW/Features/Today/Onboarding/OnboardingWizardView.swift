import SwiftUI
import FluentKit

/// Pierwsze uruchomienie (G4): krótki wywiad w 8 krokach z postępem na górze, pomijalny.
/// Odpowiedzi trafiają do `LearnerSettings.profile` (iCloud) i realnie zmieniają działanie
/// aplikacji: cel dzienny, przypomnienie, akcent, poziom startowy, polecane słówka, zestaw
/// startowy i kolejność trybów nauki. Zastępuje dawne powitanie (`TodayOnboardingView`).
struct OnboardingWizardView: View {
    /// Trwa zapisywanie / dodawanie słów — ekran Dzisiaj trzyma kreator na wierzchu, choć słownik
    /// przestaje być pusty po pierwszej partii słów.
    @Binding var isActive: Bool

    @Environment(LearningStore.self) private var store
    @State private var model: OnboardingModel?

    var body: some View {
        Group {
            if let model {
                OnboardingWizardContent(model: model, isActive: $isActive)
            } else {
                LoadingStateView()
            }
        }
        .background(Palette.background)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if model == nil {
                model = OnboardingModel(reminder: store.settings.reminder, accent: store.settings.accent)
            }
        }
    }
}

private enum OnboardingScrollID {
    static let top = "onboarding.top"
}

private struct OnboardingWizardContent: View {
    @Bindable var model: OnboardingModel
    @Binding var isActive: Bool

    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { (proxy: ScrollViewProxy) in
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    OnboardingHeader(model: model, onSkip: skip)
                        .id(OnboardingScrollID.top)
                    stepContent
                        .id(model.step)
                        .transition(Motion.contentTransition(reduceMotion: reduceMotion))
                    OnboardingFooter(model: model, onNext: next, onBack: back)
                }
                .frame(maxWidth: Spacing.readableWidth)
                .padding(Spacing.screen)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: model.step) { (_: OnboardingStep, _: OnboardingStep) in
                proxy.scrollTo(OnboardingScrollID.top, anchor: .top)
            }
        }
        .task(id: model.step) { await prepareStep() }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.step {
        case .goals: OnboardingGoalsStep(model: model)
        case .level: OnboardingLevelStep(model: model)
        case .interests: OnboardingInterestsStep(model: model)
        case .styles: OnboardingStylesStep(model: model)
        case .time: OnboardingTimeStep(model: model)
        case .reminder: OnboardingReminderStep(model: model)
        case .accent: OnboardingAccentStep(model: model)
        case .summary: OnboardingSummaryStep(model: model)
        }
    }

    private func prepareStep() async {
        guard model.step == .summary else { return }
        await model.prepareSummary(content: env.content)
    }

    private func next() {
        if model.step == .summary {
            Task { await finish() }
            return
        }
        withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            model.goForward()
        }
    }

    private func back() {
        withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            model.goBack()
        }
    }

    /// „Pomiń”: zapisuje to, co już wybrano (jeśli cokolwiek), i kończy kreator.
    private func skip() {
        guard !model.isAdding else { return }
        if !model.goals.isEmpty || model.selfLevel != nil || !model.interests.isEmpty || !model.styles.isEmpty {
            let profile = model.makeProfile(now: store.now())
            store.update(.edit) { (state: inout LearnerState) in
                state.settings.profile = profile
            }
        }
        preferences.hasCompletedOnboarding = true
    }

    /// Zapis profilu i ustawień → zestaw startowy (w tle, z postępem) → pierwsza sesja.
    private func finish() async {
        guard !model.isAdding else { return }
        isActive = true
        model.isAdding = true
        model.errorMessage = nil
        model.progress = 0
        OnboardingFinisher.saveSettings(model: model, store: store)
        if model.reminderEnabled && preferences.remindersEnabled {
            await env.refreshReminders()
        }
        let result = await OnboardingFinisher.addStarterWords(model: model, store: store)
        model.isAdding = false
        isActive = false
        // Nic nie dodano, choć były tematy → kreator zostaje z komunikatem (można ponowić albo pominąć).
        if result.planned > 0 && result.added == 0 { return }
        preferences.hasCompletedOnboarding = true
        if result.added > 0 {
            router.startStudy(.daily)
        }
    }
}

/// Postęp, tytuł kroku i „Pomiń”.
private struct OnboardingHeader: View {
    let model: OnboardingModel
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("Krok \(model.stepNumber) z \(model.stepCount)")
                    .fluentEyebrow()
                    .foregroundStyle(Palette.accent)
                Spacer(minLength: 0)
                Button("Pomiń", action: onSkip)
                    .font(FluentFont.button)
                    .frame(minHeight: HitTarget.minimum)
                    .disabled(model.isAdding)
                    .accessibilityHint(Text("Kończy wywiad. Odpowiedzi zmienisz w Ustawieniach."))
            }
            LinearProgressBar(progress: model.fraction)
            if model.step == .goals {
                Text("Witaj w FluentNOW")
                    .font(FluentFont.display)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(model.step.title)
                .font(model.step == .goals ? FluentFont.title : FluentFont.heroTitle)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(model.step.subtitle)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
    }
}

/// „Dalej” (jedyna główna akcja) i „Wstecz”.
private struct OnboardingFooter: View {
    let model: OnboardingModel
    let onNext: () -> Void
    let onBack: () -> Void

    private var nextTitle: String {
        guard model.step == .summary else { return "Dalej" }
        if model.selectedStarterTopics.isEmpty { return "Zaczynam" }
        return "Dodaj \(LibraryText.words(model.starterWordCount)) i zacznij"
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            if !(model.step == .level && model.showsPlacement) {
                PrimaryButton(nextTitle, systemImage: model.step == .summary ? "sparkles" : "arrow.right", isLoading: model.isAdding, action: onNext)
            }
            if model.step != .goals {
                Button("Wstecz", action: onBack)
                    .font(FluentFont.button)
                    .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
                    .disabled(model.isAdding)
            }
        }
    }
}

/// Efekty końca kreatora (zapis przez `store.update`, dodanie słów przez `TopicAdder`).
@MainActor
enum OnboardingFinisher {
    static func saveSettings(model: OnboardingModel, store: LearningStore) {
        let profile = model.makeProfile(now: store.now())
        let goal = LearnerProfile.dailyGoal(minutes: model.minutes)
        let reminder = model.reminderString
        let accent = model.accent
        let setsReminder = model.reminderEnabled
        store.update(.edit) { (state: inout LearnerState) in
            state.settings.profile = profile
            state.settings.goal = goal
            if setsReminder { state.settings.reminder = reminder }
            if state.settings.accent != accent {
                state.settings.accent = accent
                state.settings.voice = nil
            }
        }
    }

    /// Zwraca liczbę zaplanowanych wpisów i znaczeń gotowych do nauki (dodanych lub już posiadanych).
    static func addStarterWords(model: OnboardingModel, store: LearningStore) async -> (planned: Int, added: Int) {
        let plan = model.starterEntryIDs().filter { !$0.entryIDs.isEmpty }
        let planned = plan.reduce(0) { $0 + $1.entryIDs.count }
        guard !plan.isEmpty else { return (planned: 0, added: 0) }
        var added = 0
        let count = Double(plan.count)
        for (offset, item) in plan.enumerated() {
            let outcome = await TopicAdder.add(topic: item.topic, entryIDs: item.entryIDs, store: store) { (value: Double) in
                model.progress = (Double(offset) + value) / count
            }
            // Już posiadane (np. ponowna próba po przerwaniu) też liczą się jako gotowe.
            added += outcome.addedMeanings + outcome.skippedExisting
        }
        if added == 0 {
            model.errorMessage = "Nie udało się dodać słów. Spróbuj ponownie albo pomiń — słowa znajdziesz później przyciskiem + → „Szukaj tematu”."
        }
        return (planned: planned, added: added)
    }
}
