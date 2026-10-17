import SwiftUI
import FluentKit

/// 1. Po co się uczysz? (wielokrotny wybór)
struct OnboardingGoalsStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(LearningGoal.allCases) { (goal: LearningGoal) in
                OnboardingOptionRow(
                    title: goal.namePl,
                    detail: nil,
                    systemImage: goal.systemImage,
                    isSelected: model.goals.contains(goal),
                    isMultiple: true
                ) {
                    model.toggle(goal)
                }
            }
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.goals.count)
    }
}

/// 2. Twój poziom: samoocena opisowa albo szybki test.
struct OnboardingLevelStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        if model.showsPlacement {
            OnboardingPlacementView(model: model)
        } else {
            OnboardingLevelChoices(model: model)
        }
    }
}

private struct OnboardingLevelChoices: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(OnboardingLevelOption.all) { (option: OnboardingLevelOption) in
                OnboardingOptionRow(
                    title: "\(option.level) · \(option.title)",
                    detail: option.detail,
                    systemImage: nil,
                    isSelected: model.selfLevel == option.level,
                    isMultiple: false
                ) {
                    model.chooseLevel(option.level)
                }
            }
            if model.levelSource == .placementTest, let level = model.selfLevel {
                Label("Poziom \(level) ustalony na podstawie testu", systemImage: "checkmark.seal")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.success)
            }
            Card(style: .tinted(.accent)) {
                Text("Nie wiesz, który wybrać?")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                Text("Szybki test: 12 pytań, około 2 minut — znaczenia słów z różnych poziomów i kilka zdań z gramatyki.")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton("Zrób szybki test", systemImage: "checklist") {
                    Task { await model.startPlacement() }
                }
            }
            .padding(.top, Spacing.xs)
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.selfLevel)
    }
}

/// 3. Zainteresowania (siatka kafelków).
struct OnboardingInterestsStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: Spacing.xs)], spacing: Spacing.xs) {
            ForEach(LearningInterest.allCases) { (interest: LearningInterest) in
                OnboardingTile(
                    title: interest.namePl,
                    systemImage: interest.systemImage,
                    isSelected: model.interests.contains(interest)
                ) {
                    model.toggle(interest)
                }
            }
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.interests.count)
    }
}

/// 4. Jak lubisz się uczyć? (wielokrotny wybór)
struct OnboardingStylesStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(LearningStyle.allCases) { (style: LearningStyle) in
                OnboardingOptionRow(
                    title: style.namePl,
                    detail: style.detailPl,
                    systemImage: style.systemImage,
                    isSelected: model.styles.contains(style),
                    isMultiple: true
                ) {
                    model.toggle(style)
                }
            }
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.styles.count)
    }
}

/// 5. Ile czasu dziennie?
struct OnboardingTimeStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ForEach(LearnerProfile.minuteOptions, id: \.self) { (minutes: Int) in
                OnboardingOptionRow(
                    title: "\(minutes) minut dziennie",
                    detail: OnboardingText.timeDetail(minutes),
                    systemImage: "clock",
                    isSelected: model.minutes == minutes,
                    isMultiple: false
                ) {
                    model.minutes = minutes
                }
            }
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.minutes)
    }
}

/// 6. Przypomnienie — prośba o zgodę dopiero po włączeniu przełącznika.
struct OnboardingReminderStep: View {
    @Bindable var model: OnboardingModel

    @Environment(ReminderService.self) private var reminders
    @Environment(AppPreferences.self) private var preferences
    @State private var isDenied = false

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { model.reminderEnabled },
            set: { (enabled: Bool) in
                if enabled {
                    Task { await enable() }
                } else {
                    model.reminderEnabled = false
                }
            }
        )
    }

    var body: some View {
        Card {
            Toggle(isOn: toggleBinding) {
                Label("Przypominaj mi o nauce", systemImage: "bell")
                    .font(FluentFont.body)
                    .foregroundStyle(Palette.ink)
            }
            .tint(Palette.accent)
            if model.reminderEnabled {
                DatePicker(selection: $model.reminderTime, displayedComponents: .hourAndMinute) {
                    Label("Pora", systemImage: "clock")
                        .font(FluentFont.body)
                        .foregroundStyle(Palette.ink)
                }
            }
            Text(footer)
                .font(FluentFont.footnote)
                .foregroundStyle(isDenied ? Palette.warning : Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: String {
        if isDenied {
            return "Powiadomienia są wyłączone w ustawieniach systemu. Możesz je włączyć później — aplikacja działa i bez nich."
        }
        return "Nie wyślemy przypomnienia, jeśli dzienny cel będzie już osiągnięty."
    }

    private func enable() async {
        let status = await reminders.requestAuthorization()
        if status == .authorized {
            model.reminderEnabled = true
            preferences.remindersEnabled = true
            isDenied = false
        } else {
            model.reminderEnabled = false
            isDenied = true
        }
    }
}

/// 7. Akcent i odsłuch próbki.
struct OnboardingAccentStep: View {
    @Bindable var model: OnboardingModel

    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech

    static let sample = "Nice to meet you. Let's learn some English together."

    var body: some View {
        VStack(spacing: Spacing.xs) {
            OnboardingOptionRow(
                title: "Amerykański",
                detail: "Domyślny — pisownia i wymowa jak w USA.",
                systemImage: "speaker.wave.2",
                isSelected: model.accent == "en-US",
                isMultiple: false
            ) {
                choose("en-US")
            }
            OnboardingOptionRow(
                title: "Brytyjski",
                detail: "Wymowa z Wielkiej Brytanii (słówka zostają w pisowni amerykańskiej).",
                systemImage: "speaker.wave.2",
                isSelected: model.accent == "en-GB",
                isMultiple: false
            ) {
                choose("en-GB")
            }
            SecondaryButton("Posłuchaj próbki", systemImage: "play.circle") {
                speech.speak(OnboardingAccentStep.sample)
            }
            .padding(.top, Spacing.xs)
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.accent)
    }

    /// Akcent zapisany od razu (próbka czyta już wybranym głosem); głos „automatycznie” dla akcentu.
    private func choose(_ accent: String) {
        model.accent = accent
        store.update(.edit) { (state: inout LearnerState) in
            if state.settings.accent != accent {
                state.settings.accent = accent
                state.settings.voice = nil
            }
        }
        speech.speak(OnboardingAccentStep.sample)
    }
}

enum OnboardingText {
    static func timeDetail(_ minutes: Int) -> String {
        let goal = LearnerProfile.dailyGoal(minutes: minutes)
        let words = OnboardingPlan.starterWordCount(minutes: minutes)
        switch minutes {
        case ..<8:
            return "Na rozgrzewkę · cel \(goal) zadań, na start \(words) słów"
        case 8..<13:
            return "Najpopularniejszy wybór · cel \(goal) zadań, na start \(words) słowa"
        case 13..<18:
            return "Solidna dawka · cel \(goal) zadań, na start \(words) słów"
        default:
            return "Intensywnie · cel \(goal) zadań, na start \(words) słów"
        }
    }
}
