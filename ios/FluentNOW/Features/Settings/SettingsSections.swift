import SwiftUI
import UIKit
import FluentKit

/// Cel dzienny i przypomnienia.
struct SettingsLearningSection: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(ReminderService.self) private var reminders
    @Environment(\.openURL) private var openURL

    @State private var showsDeniedAlert = false

    static let goals = [5, 10, 15, 20, 30, 50]

    private var goalOptions: [Int] {
        let current = store.settings.goal
        return SettingsLearningSection.goals.contains(current)
            ? SettingsLearningSection.goals
            : (SettingsLearningSection.goals + [current]).sorted()
    }

    private var goalBinding: Binding<Int> {
        Binding(
            get: { store.settings.goal },
            set: { value in
                let clamped = min(LearnerSettings.goalRange.upperBound, max(LearnerSettings.goalRange.lowerBound, value))
                store.update(.edit) { $0.settings.goal = clamped }
                refreshReminders()
            }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                let parts = store.settings.reminderComponents
                return Calendar.current.date(bySettingHour: parts.hour, minute: parts.minute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                let value = String(format: "%02d:%02d", parts.hour ?? 19, parts.minute ?? 0)
                guard LearnerSettings.isValidReminder(value) else { return }
                store.update(.edit) { $0.settings.reminder = value }
                refreshReminders()
            }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { preferences.remindersEnabled },
            set: { enabled in
                if enabled {
                    Task { await enableReminders() }
                } else {
                    preferences.remindersEnabled = false
                    refreshReminders()
                }
            }
        )
    }

    var body: some View {
        Section {
            Picker(selection: goalBinding) {
                ForEach(goalOptions, id: \.self) { goal in
                    Text(LibraryText.count(goal, one: "zadanie", few: "zadania", many: "zadań")).tag(goal)
                }
            } label: {
                Label("Cel dzienny", systemImage: "target")
            }
            Toggle(isOn: remindersBinding) {
                Label("Przypomnienie o nauce", systemImage: "bell")
            }
            if preferences.remindersEnabled {
                DatePicker(selection: reminderTime, displayedComponents: .hourAndMinute) {
                    Label("Pora", systemImage: "clock")
                }
            }
            SettingsWeeklyReportToggle()  // I3: cotygodniowe powiadomienie o raporcie (opt-in)
            SettingsRetentionPicker()  // I1: docelowa retencja FSRS (fsrs)
        } header: {
            Text("Twój rytm nauki")
        } footer: {
            Text(footer)
        }
        .alert("Powiadomienia są wyłączone", isPresented: $showsDeniedAlert) {
            Button("Otwórz Ustawienia systemu") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Nie teraz", role: .cancel) {}
        } message: {
            Text("Aby dostawać przypomnienia, zezwól FluentNOW na powiadomienia w Ustawieniach systemu.")
        }
    }

    private var footer: String {
        if reminders.authorization == .denied && preferences.remindersEnabled {
            return "Powiadomienia są zablokowane w ustawieniach systemu."
        }
        return "Cel to liczba krótkich ćwiczeń dziennie. Przypomnienie nie pojawi się, jeśli cel na dziś jest już osiągnięty."
    }

    private func enableReminders() async {
        let status = await reminders.requestAuthorization()
        if status == .authorized {
            preferences.remindersEnabled = true
            await env.refreshReminders()
        } else {
            preferences.remindersEnabled = false
            showsDeniedAlert = true
        }
    }

    private func refreshReminders() {
        Task { await env.refreshReminders() }
    }
}

/// Wymowa: głos, akcent, wolne tempo, próba.
struct SettingsVoiceSection: View {
    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech

    private var slowBinding: Binding<Bool> {
        Binding(
            get: { store.settings.slow },
            set: { value in store.update(.edit) { $0.settings.slow = value } }
        )
    }

    var body: some View {
        Section("Wymowa") {
            NavigationLink(value: SettingsRoute.voice) {
                LabeledContent {
                    Text(SettingsVoiceText.voiceName(store.settings, voices: speech.availableVoices()))
                } label: {
                    Label("Głos i akcent", systemImage: "person.wave.2")
                }
            }
            Toggle(isOn: slowBinding) {
                Label("Wolniejsze odtwarzanie", systemImage: "tortoise")
            }
            Button {
                speech.speak("A little practice every day goes a long way.")
            } label: {
                Label("Wypróbuj głos", systemImage: "speaker.wave.2")
            }
        }
    }
}

enum SettingsVoiceText {
    static func accentName(_ accent: String) -> String {
        accent == "en-GB" ? "brytyjski" : "amerykański"
    }

    static func voiceName(_ settings: LearnerSettings, voices: [VoiceOption]) -> String {
        if let id = settings.voice, !id.isEmpty, let voice = voices.first(where: { $0.id == id }) {
            return voice.name
        }
        return "Automatycznie · \(accentName(settings.accent))"
    }
}

/// Motyw i haptyka (per urządzenie).
struct SettingsAppearanceSection: View {
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Section("Wygląd") {
            Picker(selection: $preferences.appearance) {
                ForEach(AppAppearance.allCases) { appearance in
                    Label(appearance.title, systemImage: appearance.systemImage).tag(appearance)
                }
            } label: {
                Label("Motyw", systemImage: "circle.lefthalf.filled")
            }
            Toggle(isOn: $preferences.hapticsEnabled) {
                Label("Wibracje", systemImage: "iphone.radiowaves.left.and.right")
            }
        }
    }
}

/// Status synchronizacji iCloud.
struct SettingsSyncSection: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        let status = store.syncMonitor.status
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(status.titlePl)
                        .foregroundStyle(Palette.ink)
                    Text(status.detailPl)
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
            } icon: {
                Image(systemName: status.systemImage)
                    .foregroundStyle(SettingsSyncSection.tint(status))
            }
            .accessibilityElement(children: .combine)
            Button {
                Task { await store.syncMonitor.refresh() }
            } label: {
                Label("Sprawdź ponownie", systemImage: "arrow.clockwise")
            }
            .disabled(status == .syncing)
        } header: {
            Text("iCloud")
        } footer: {
            Text("Słowa i postęp synchronizują się między Twoimi urządzeniami przez iCloud, bez zakładania konta. Bez iCloud wszystko działa lokalnie.")
        }
    }

    static func tint(_ status: SyncStatus) -> Color {
        switch status {
        case .synced: return Palette.success
        case .syncing: return Palette.info
        case .localOnly: return Palette.warning
        case .error: return Palette.danger
        }
    }
}

/// Import, eksport, raporty, usuwanie danych.
struct SettingsDataSection: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(AppRouter.self) private var router

    @State private var confirmStep1 = false
    @State private var confirmStep2 = false
    @State private var confirmationText = ""
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var deletedTrigger = 0

    static let confirmationWord = "USUŃ"

    var body: some View {
        Section {
            NavigationLink(value: SettingsRoute.importData) {
                Label("Importuj dane", systemImage: "square.and.arrow.down")
            }
            NavigationLink(value: SettingsRoute.exportData) {
                Label("Eksportuj dane", systemImage: "square.and.arrow.up")
            }
            StudyImageDiagnosticsRow()  // H2: zdjęcia do ćwiczeń — liczby, kolejka, ostatni błąd (study-polish)
            Button(role: .destructive) {
                confirmStep1 = true
            } label: {
                HStack {
                    Label("Usuń wszystkie dane", systemImage: "trash")
                    if isDeleting {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isDeleting)
            if let deleteError {
                Text(deleteError)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.danger)
            }
        } header: {
            Text("Twoje dane należą do Ciebie")
        } footer: {
            Text("Kopia JSON zachowuje pełną historię i działa też na stronie Fluent. CSV otworzysz w Anki lub arkuszu.")
        }
        .confirmationDialog("Usunąć wszystkie dane?", isPresented: $confirmStep1, titleVisibility: .visible) {
            Button("Dalej", role: .destructive) {
                confirmationText = ""
                confirmStep2 = true
            }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Znikną wszystkie słowa, postęp i historia — na tym urządzeniu i w iCloud. Tej operacji nie można cofnąć. Najpierw możesz wyeksportować kopię.")
        }
        .alert("Na pewno?", isPresented: $confirmStep2) {
            TextField("Wpisz \(SettingsDataSection.confirmationWord)", text: $confirmationText)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Usuń wszystko", role: .destructive) {
                Task { await deleteAll() }
            }
            .disabled(!isConfirmed)
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Wpisz „\(SettingsDataSection.confirmationWord)”, aby potwierdzić usunięcie wszystkich danych.")
        }
        .fluentSensoryFeedback(FluentHaptic.destructive, trigger: deletedTrigger)
    }

    private var isConfirmed: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == SettingsDataSection.confirmationWord
    }

    private func deleteAll() async {
        guard isConfirmed, !isDeleting else { return }
        isDeleting = true
        deleteError = nil
        do {
            try await store.deleteAllData()
            preferences.hasCompletedOnboarding = false
            deletedTrigger += 1
            router.select(.today)
        } catch {
            deleteError = "Nie udało się usunąć danych: \(error.localizedDescription)"
        }
        isDeleting = false
    }
}
