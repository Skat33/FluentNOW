import SwiftUI
import FluentKit

/// Eksport: pełna kopia JSON (zgodna ze stroną), CSV dla Anki, zgłoszone błędy ćwiczeń — przez `ShareLink`.
struct SettingsExportScreen: View {
    @Environment(LearningStore.self) private var store
    @Environment(ExerciseReportStore.self) private var reports

    @State private var jsonFile: URL?
    @State private var csvFile: URL?
    @State private var reportsFile: URL?
    @State private var errors: [String] = []
    @State private var isPreparing = true
    @State private var confirmClearReports = false

    var body: some View {
        Form {
            Section {
                SettingsExportRow(title: "Pełna kopia JSON", subtitle: "Słowa, postęp, historia, ustawienia",
                                  systemImage: "doc.text", file: jsonFile, isPreparing: isPreparing)
                SettingsExportRow(title: "Słowa CSV / Anki", subtitle: "Jedno znaczenie w wierszu: English → przód, Polish → tył",
                                  systemImage: "tablecells", file: csvFile, isPreparing: isPreparing)
            } header: {
                Text("Twoje dane")
            } footer: {
                Text("Kopię JSON zaimportujesz w tej aplikacji na innym urządzeniu albo na stronie Fluent.")
            }
            Section {
                if reports.reports.isEmpty {
                    Text("Brak zgłoszonych błędów ćwiczeń.")
                        .foregroundStyle(Palette.inkSecondary)
                } else {
                    SettingsExportRow(title: "Zgłoszone błędy (\(reports.reports.count))", subtitle: "Plik JSON do przesłania autorom treści",
                                      systemImage: "exclamationmark.bubble", file: reportsFile, isPreparing: isPreparing)
                    Button("Usuń zgłoszenia", role: .destructive) { confirmClearReports = true }
                }
            } header: {
                Text("Zgłoszenia")
            }
            if !errors.isEmpty {
                Section {
                    ForEach(errors, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Palette.danger)
                    }
                    Button("Spróbuj ponownie") { prepare() }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Eksport")
        .navigationBarTitleDisplayMode(.inline)
        .task { prepare() }
        .confirmationDialog("Usunąć zgłoszenia?", isPresented: $confirmClearReports, titleVisibility: .visible) {
            Button("Usuń", role: .destructive) {
                reports.removeAll()
                reportsFile = nil
            }
            Button("Anuluj", role: .cancel) {}
        }
    }

    private func prepare() {
        isPreparing = true
        errors = []
        do { jsonFile = try store.exportJSONFile() } catch { errors.append("Kopia JSON: \(error.localizedDescription)") }
        do { csvFile = try store.exportAnkiCSVFile() } catch { errors.append("CSV: \(error.localizedDescription)") }
        if !reports.reports.isEmpty {
            do { reportsFile = try reports.exportFile() } catch { errors.append("Zgłoszenia: \(error.localizedDescription)") }
        }
        isPreparing = false
    }
}

private struct SettingsExportRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let file: URL?
    let isPreparing: Bool

    var body: some View {
        if let file {
            ShareLink(item: file) {
                SettingsExportLabel(title: title, subtitle: subtitle, systemImage: systemImage, trailing: "square.and.arrow.up")
            }
        } else {
            HStack {
                SettingsExportLabel(title: title, subtitle: subtitle, systemImage: systemImage, trailing: nil)
                if isPreparing { ProgressView() }
            }
            .foregroundStyle(Palette.inkSecondary)
        }
    }
}

private struct SettingsExportLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let trailing: String?

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }
            Spacer(minLength: 0)
            if let trailing {
                Image(systemName: trailing)
                    .accessibilityHidden(true)
            }
        }
    }
}

#Preview("Eksport") {
    NavigationStack {
        SettingsExportScreen()
    }
    .fluentPreviewEnvironment()
}
