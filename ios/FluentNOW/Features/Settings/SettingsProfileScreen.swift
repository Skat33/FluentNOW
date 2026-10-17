import SwiftUI
import FluentKit

/// Wiersz w Ustawieniach → „Twój profil nauki”.
struct SettingsProfileLinkSection: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        Section {
            NavigationLink(value: SettingsRoute.learningProfile) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Twój profil nauki", systemImage: "person.text.rectangle")
                    Text(SettingsProfileText.summary(store.settings.profile))
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// „Twój profil nauki” (G4): edycja odpowiedzi z wywiadu. Każda zmiana od razu w stanie
/// (`LearnerSettings.profile`, iCloud) i wpływa na polecane słówka, poziom startowy i tryby nauki.
struct SettingsProfileScreen: View {
    @Environment(LearningStore.self) private var store

    private var profile: LearnerProfile {
        store.settings.profile ?? LearnerProfile()
    }

    var body: some View {
        Form {
            SettingsProfileGoalsSection(profile: profile, edit: update)
            SettingsProfileLevelSection(profile: profile, edit: update)
            SettingsProfileInterestsSection(profile: profile, edit: update)
            SettingsProfileStylesSection(profile: profile, edit: update)
            SettingsProfileTimeSection(profile: profile, select: updateMinutes)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Twój profil nauki")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func update(_ change: (inout LearnerProfile) -> Void) {
        SettingsProfileEditor.update(store: store, change)
    }

    /// Czas dziennie zmienia też cel dzienny (jak w wywiadzie).
    private func updateMinutes(_ minutes: Int) {
        SettingsProfileEditor.update(store: store) { (profile: inout LearnerProfile) in
            profile.dailyMinutes = minutes
        }
        let goal = LearnerProfile.dailyGoal(minutes: minutes)
        store.update(.edit) { (state: inout LearnerState) in
            state.settings.goal = goal
        }
    }
}

@MainActor
enum SettingsProfileEditor {
    static func update(store: LearningStore, _ change: (inout LearnerProfile) -> Void) {
        let now: Timestamp = store.now()
        var profile = store.settings.profile ?? LearnerProfile(createdAt: now, updatedAt: now)
        change(&profile)
        profile.updatedAt = now
        let updated = profile.normalized()
        store.update(.edit) { (state: inout LearnerState) in
            state.settings.profile = updated
        }
    }
}

/// Wiersz wielokrotnego wyboru w `Form`.
private struct SettingsProfileToggleRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Spacing.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Palette.accent : Palette.inkTertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct SettingsProfileGoalsSection: View {
    let profile: LearnerProfile
    let edit: ((inout LearnerProfile) -> Void) -> Void

    var body: some View {
        Section {
            ForEach(LearningGoal.allCases) { (goal: LearningGoal) in
                SettingsProfileToggleRow(title: goal.namePl, systemImage: goal.systemImage, isSelected: profile.goals.contains(goal)) {
                    edit { (value: inout LearnerProfile) in
                        if let index = value.goals.firstIndex(of: goal) { value.goals.remove(at: index) } else { value.goals.append(goal) }
                    }
                }
            }
        } header: {
            Text("Po co się uczysz?")
        } footer: {
            Text("Tematy z Twoich celów pojawiają się wyżej w polecanych słówkach.")
        }
    }
}

private struct SettingsProfileLevelSection: View {
    let profile: LearnerProfile
    let edit: ((inout LearnerProfile) -> Void) -> Void

    private var binding: Binding<String> {
        Binding(
            get: { profile.startLevel ?? "" },
            set: { (value: String) in
                edit { (edited: inout LearnerProfile) in
                    edited.startLevel = value.isEmpty ? nil : value
                    edited.levelSource = value.isEmpty ? nil : .selfAssessment
                    edited.placementCorrect = nil
                    edited.placementTotal = nil
                }
            }
        )
    }

    var body: some View {
        Section {
            Picker(selection: binding) {
                Text("Nie ustalono").tag("")
                ForEach(OnboardingLevelOption.all) { (option: OnboardingLevelOption) in
                    Text("\(option.level) · \(option.title)").tag(option.level)
                }
            } label: {
                Label("Poziom startowy", systemImage: "chart.bar")
            }
        } header: {
            Text("Poziom")
        } footer: {
            Text(SettingsProfileText.levelFooter(profile))
        }
    }
}

private struct SettingsProfileInterestsSection: View {
    let profile: LearnerProfile
    let edit: ((inout LearnerProfile) -> Void) -> Void

    var body: some View {
        Section("Zainteresowania") {
            ForEach(LearningInterest.allCases) { (interest: LearningInterest) in
                SettingsProfileToggleRow(title: interest.namePl, systemImage: interest.systemImage, isSelected: profile.interests.contains(interest)) {
                    edit { (value: inout LearnerProfile) in
                        if let index = value.interests.firstIndex(of: interest) { value.interests.remove(at: index) } else { value.interests.append(interest) }
                    }
                }
            }
        }
    }
}

private struct SettingsProfileStylesSection: View {
    let profile: LearnerProfile
    let edit: ((inout LearnerProfile) -> Void) -> Void

    var body: some View {
        Section {
            ForEach(LearningStyle.allCases) { (style: LearningStyle) in
                SettingsProfileToggleRow(title: style.namePl, systemImage: style.systemImage, isSelected: profile.styles.contains(style)) {
                    edit { (value: inout LearnerProfile) in
                        if let index = value.styles.firstIndex(of: style) { value.styles.remove(at: index) } else { value.styles.append(style) }
                    }
                }
            }
        } header: {
            Text("Jak lubisz się uczyć?")
        } footer: {
            Text("Ulubione tryby pokazujemy najpierw na ekranie Nauka.")
        }
    }
}

private struct SettingsProfileTimeSection: View {
    let profile: LearnerProfile
    let select: (Int) -> Void

    private var binding: Binding<Int> {
        Binding(
            get: { profile.dailyMinutes ?? 10 },
            set: { (value: Int) in select(value) }
        )
    }

    var body: some View {
        Section {
            Picker(selection: binding) {
                ForEach(LearnerProfile.minuteOptions, id: \.self) { (minutes: Int) in
                    Text("\(minutes) min").tag(minutes)
                }
            } label: {
                Label("Czas dziennie", systemImage: "clock")
            }
        } footer: {
            Text("Zmiana ustawia też dzienny cel (ok. 2 zadania na minutę). Cel zmienisz osobno w sekcji „Twój rytm nauki”.")
        }
    }
}

enum SettingsProfileText {
    static func summary(_ profile: LearnerProfile?) -> String {
        guard let profile, !profile.isEmpty else {
            return "Uzupełnij cele i zainteresowania — lepiej dobierzemy słowa."
        }
        var parts: [String] = []
        if !profile.goals.isEmpty { parts.append(profile.goals.map { $0.namePl }.joined(separator: ", ")) }
        if let level = profile.startLevel { parts.append("poziom \(level)") }
        if let minutes = profile.dailyMinutes { parts.append("\(minutes) min dziennie") }
        return parts.isEmpty ? "Zainteresowania i sposób nauki" : parts.joined(separator: " · ")
    }

    static func levelFooter(_ profile: LearnerProfile) -> String {
        var text = "Używany, dopóki nie masz historii odpowiedzi — potem poziom liczymy z Twoich wyników."
        if profile.levelSource == .placementTest, let correct = profile.placementCorrect, let total = profile.placementTotal {
            text += " Szybki test: \(correct) z \(total)."
        }
        return text
    }
}
