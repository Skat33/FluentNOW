import SwiftUI
import UniformTypeIdentifiers
import FluentKit

/// Rodzaj wczytanych danych do importu.
private enum SettingsImportPayload: Equatable {
    case json(Data)
    case delimited(String)

    var isJSON: Bool {
        if case .json = self { return true }
        return false
    }
}

/// Import: kopia JSON (strona Fluent / ta aplikacja) albo CSV/TSV/lista słów — zawsze z podglądem.
struct SettingsImportScreen: View {
    @Environment(LearningStore.self) private var store

    @State private var pastedText = ""
    @State private var payload: SettingsImportPayload?
    @State private var sourceName = ""
    @State private var preview: ImportSummary?
    @State private var mode: ImportMode = .merge
    @State private var errorMessage: String?
    @State private var result: ImportSummary?
    @State private var showsImporter = false
    @State private var confirmReplace = false
    @State private var importedTrigger = 0

    static let maxFileBytes = 8 * 1024 * 1024

    var body: some View {
        Form {
            Section {
                Button {
                    showsImporter = true
                } label: {
                    Label("Wybierz plik (JSON, CSV, TSV)", systemImage: "doc.badge.plus")
                }
            } footer: {
                Text("Kopia JSON przenosi słowa, postęp i historię. CSV/TSV: kolumny słowo, tłumaczenie (opcjonalnie: przykład, kolekcja). Lista: „word - tłumaczenie” w każdej linii.")
            }
            Section("Albo wklej tekst") {
                TextEditor(text: $pastedText)
                    .frame(minHeight: 120)
                    .font(FluentFont.callout)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Sprawdź wklejony tekst") {
                    load(text: pastedText, name: "Wklejony tekst")
                }
                .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Palette.danger)
                }
            }
            if let preview, let payload {
                SettingsImportPreviewSection(
                    summary: preview,
                    sourceName: sourceName,
                    isJSON: payload.isJSON,
                    mode: $mode,
                    onImport: {
                        if payload.isJSON && mode == .replace { confirmReplace = true } else { apply() }
                    }
                )
            }
            if let result {
                Section("Gotowe") {
                    Label(SettingsImportText.describe(result, done: true), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.success)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Import")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.json, .commaSeparatedText, .tabSeparatedText, .plainText, .text]
        ) { outcome in
            switch outcome {
            case .success(let url):
                Task { await load(url: url) }
            case .failure(let error):
                errorMessage = "Nie udało się otworzyć pliku: \(error.localizedDescription)"
            }
        }
        .confirmationDialog("Zastąpić wszystkie dane?", isPresented: $confirmReplace, titleVisibility: .visible) {
            Button("Zastąp dane", role: .destructive) { apply() }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Obecne słowa i postęp zostaną zastąpione zawartością pliku (także w iCloud). Bezpieczniej jest scalić.")
        }
        .sensoryFeedback(FluentHaptic.answerCorrect, trigger: importedTrigger)
    }

    // MARK: Wczytanie i podgląd

    private func load(url: URL) async {
        let data = await Task.detached(priority: .userInitiated) { () -> Data? in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            return try? Data(contentsOf: url, options: .mappedIfSafe)
        }.value
        guard let data else {
            errorMessage = "Nie udało się odczytać pliku. Sprawdź, czy jest dostępny na urządzeniu."
            return
        }
        guard data.count <= SettingsImportScreen.maxFileBytes else {
            errorMessage = "Plik jest za duży (maks. 8 MB)."
            return
        }
        if SettingsImportText.looksLikeJSON(data) {
            preparePreview(.json(data), name: url.lastPathComponent)
        } else if let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1250) {
            preparePreview(.delimited(text), name: url.lastPathComponent)
        } else {
            errorMessage = "Plik nie jest tekstem UTF-8 ani kopią JSON."
        }
    }

    private func load(text: String, name: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8) {
            preparePreview(.json(data), name: name)
        } else {
            preparePreview(.delimited(trimmed), name: name)
        }
    }

    private func preparePreview(_ newPayload: SettingsImportPayload, name: String) {
        errorMessage = nil
        result = nil
        preview = nil
        payload = nil
        do {
            switch newPayload {
            case .json(let data):
                preview = try store.previewImportJSON(data)
            case .delimited(let text):
                preview = try store.previewImportDelimited(text)
            }
            payload = newPayload
            sourceName = name
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply() {
        guard let payload else { return }
        do {
            switch payload {
            case .json(let data):
                result = try store.importJSON(data, mode: mode)
            case .delimited(let text):
                result = try store.importDelimited(text)
            }
            self.payload = nil
            preview = nil
            pastedText = ""
            importedTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SettingsImportPreviewSection: View {
    let summary: ImportSummary
    let sourceName: String
    let isJSON: Bool
    @Binding var mode: ImportMode
    let onImport: () -> Void

    var body: some View {
        Section {
            Text(SettingsImportText.describe(summary, done: false))
            ForEach(Array(summary.messages.prefix(8).enumerated()), id: \.offset) { _, message in
                Text(message)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if isJSON {
                Picker("Sposób importu", selection: $mode) {
                    Text("Scal z moimi danymi").tag(ImportMode.merge)
                    Text("Zastąp moje dane").tag(ImportMode.replace)
                }
                .pickerStyle(.inline)
            }
            Button(action: onImport) {
                Label("Importuj", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Podgląd: \(sourceName)")
        } footer: {
            Text(isJSON
                 ? "Scalanie zachowuje postęp z obu stron (wygrywa nowsza edycja). Słów, które już masz, nie dublujemy."
                 : "Wiersze, które już masz (to samo słowo i tłumaczenie), zostaną pominięte.")
        }
    }
}

enum SettingsImportText {
    static func looksLikeJSON(_ data: Data) -> Bool {
        for byte in data.prefix(64) {
            switch byte {
            case 0x20, 0x09, 0x0A, 0x0D, 0xEF, 0xBB, 0xBF: continue
            case 0x7B: return true
            default: return false
            }
        }
        return false
    }

    static func describe(_ summary: ImportSummary, done: Bool) -> String {
        let new = LibraryText.words(summary.newWords)
        var parts = [done ? "Dodano \(new)" : "Nowe: \(new)"]
        if summary.mergedWords > 0 { parts.append("scalone: \(summary.mergedWords)") }
        if summary.skipped > 0 { parts.append("pominięte: \(summary.skipped)") }
        return parts.joined(separator: " · ")
    }
}

#Preview("Import") {
    NavigationStack {
        SettingsImportScreen()
    }
    .fluentPreviewEnvironment()
}
