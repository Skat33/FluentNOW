import SwiftUI
import UIKit

/// Przełącznik cotygodniowego powiadomienia o raporcie (I3, opt-in). Preferencja urządzenia
/// w UserDefaults pod kluczem z prefiksem `fluent.` — „Usuń wszystkie dane” ją czyści
/// (`AppPreferences.resettableKeyPrefixes`), a `ReminderService.cancelAll()` usuwa powiadomienie.
struct SettingsWeeklyReportToggle: View {
    static let storageKey = "fluent.weeklyReportEnabled"

    @Environment(ReminderService.self) private var reminders
    @Environment(\.openURL) private var openURL
    @AppStorage(SettingsWeeklyReportToggle.storageKey) private var isEnabled = false
    @State private var showsDeniedAlert = false

    private var binding: Binding<Bool> {
        Binding(
            get: { isEnabled },
            set: { (value: Bool) in
                if value {
                    Task { await enable() }
                } else {
                    isEnabled = false
                    Task { await reminders.scheduleWeeklyReport(enabled: false) }
                }
            }
        )
    }

    var body: some View {
        Toggle(isOn: binding) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Raport tygodniowy")
                    Text("Powiadomienie w niedzielę o 20:00")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
            } icon: {
                Image(systemName: "calendar.badge.clock")
            }
        }
        .alert("Powiadomienia są wyłączone", isPresented: $showsDeniedAlert) {
            Button("Otwórz Ustawienia systemu") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            Button("Nie teraz", role: .cancel) {}
        } message: {
            Text("Aby dostawać raport tygodniowy, zezwól FluentNOW na powiadomienia w Ustawieniach systemu.")
        }
    }

    private func enable() async {
        let status = await reminders.requestAuthorization()
        if status == .authorized {
            isEnabled = true
            await reminders.scheduleWeeklyReport(enabled: true)
        } else {
            isEnabled = false
            showsDeniedAlert = true
        }
    }
}
