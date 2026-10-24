import Foundation
import Observation
import os
import FluentKit

/// Jedyne źródło prawdy dla UI: stan ucznia w pamięci + zapis przyrostowy w tle.
///
/// Każda zmiana to `update(_:_:)` z czystą funkcją FluentKit w środku. Zapis:
/// `.answer`/`.session` — natychmiast, `.edit` — z opóźnieniem 250 ms (łączenie edycji),
/// `.bulk` — natychmiast w tle (repozytorium zapisuje partiami). Zapisy są szeregowane,
/// więc kolejność zmian na dysku zawsze odpowiada kolejności w aplikacji.
@MainActor
@Observable
final class LearningStore {
    /// Migawka stanu (zawsze po `StateMigration.migrate`).
    private(set) var state: LearnerState
    private(set) var loadPhase: StoreLoadPhase
    /// Ostatni błąd zapisu — UI pokazuje `ErrorBanner` z „Spróbuj ponownie” i „Eksportuj kopię”.
    private(set) var lastSaveError: String?
    /// Rośnie przy każdej zmianie stanu (klucz cache dla UI).
    private(set) var revision: Int = 0
    /// Komunikat o rekordach pominiętych przy wczytaniu (uszkodzone dane) — do Ustawień.
    private(set) var loadNotice: String?
    /// Katalog z kopią uszkodzonej bazy (do udostępnienia w Ustawieniach), jeśli powstała.
    private(set) var corruptedStoreBackupURL: URL?

    let syncMonitor: SyncMonitor

    /// Wołane po `deleteAllData()` (AppEnvironment czyści zgłoszenia, klucz AI, przypomnienia).
    @ObservationIgnored var onDeleteAll: (@MainActor () async -> Void)?

    @ObservationIgnored private let persistence: any LearningPersistence
    @ObservationIgnored private let fixedNow: Timestamp?
    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var saveChain: Task<Void, Never>?
    @ObservationIgnored private var hasPendingChanges = false
    @ObservationIgnored private var mutatedDuringLoad = false
    @ObservationIgnored private var isReloading = false
    @ObservationIgnored private var reloadRequested = false
    /// Ustawienia z ostatniego wczytania / scalenia z iCloud (wykrywanie lokalnej zmiany ustawień).
    @ObservationIgnored private var lastSyncedSettings: LearnerSettings?

    @ObservationIgnored private var activeWordsCache: (revision: Int, words: [Word]) = (-1, [])
    @ObservationIgnored private var wordIndexCache: (revision: Int, index: [String: Int]) = (-1, [:])

    /// Opóźnienie zapisu edycji (≤ 300 ms wg kontraktu).
    static let editDebounceNanoseconds: UInt64 = 250_000_000

    private static let log = Logger(subsystem: "pl.fluentnow.app", category: "LearningStore")

    /// - Parameters:
    ///   - initialState: stan gotowy od razu (podgląd/testy) — `loadPhase = .ready` bez wczytywania.
    ///   - fixedNow: stały zegar (podgląd, testy deterministyczne).
    init(
        persistence: any LearningPersistence,
        syncMonitor: SyncMonitor,
        initialState: LearnerState? = nil,
        fixedNow: Timestamp? = nil
    ) {
        self.persistence = persistence
        self.syncMonitor = syncMonitor
        self.fixedNow = fixedNow
        if let initialState {
            state = StateMigration.migrate(initialState)
            loadPhase = .ready
        } else {
            state = .empty
            loadPhase = .loading
        }
    }

    // MARK: - Odczyty pomocnicze

    var settings: LearnerSettings { state.settings }

    /// Słowa bez archiwum, najnowsze najpierw (kolejność stanu). Cache per `revision`.
    var activeWords: [Word] {
        let current = revision
        if activeWordsCache.revision != current {
            activeWordsCache = (current, state.words.filter { !$0.archived })
        }
        return activeWordsCache.words
    }

    func word(id: String) -> Word? {
        let current = revision
        if wordIndexCache.revision != current {
            var index: [String: Int] = [:]
            index.reserveCapacity(state.words.count)
            for (position, word) in state.words.enumerated() where index[word.id] == nil {
                index[word.id] = position
            }
            wordIndexCache = (current, index)
        }
        guard let position = wordIndexCache.index[id], state.words.indices.contains(position) else { return nil }
        return state.words[position]
    }

    /// `FluentClock.now()`; w podglądzie i testach stały zegar.
    func now() -> Timestamp {
        fixedNow ?? FluentClock.now()
    }

    /// Komunikat z uruchomienia magazynu (np. przeniesienie uszkodzonej bazy do kopii zapasowej).
    func setStartupNotice(_ notice: String, backupURL: URL? = nil) {
        loadNotice = notice
        corruptedStoreBackupURL = backupURL
    }

    /// Czy są zmiany jeszcze niezapisane (np. przed zamknięciem aplikacji).
    var hasUnsavedChanges: Bool { hasPendingChanges }

    // MARK: - Mutacje

    /// Jedyny sposób mutacji: transformacja stanu funkcjami FluentKit.
    @discardableResult
    func update<R>(_ kind: ChangeKind = .edit, _ body: (inout LearnerState) -> R) -> R {
        var next = state
        let result = body(&next)
        apply(next, kind: kind)
        return result
    }

    /// Ciężkie obliczenia na migawce stanu poza głównym wątkiem.
    func compute<T: Sendable>(_ work: @escaping @Sendable (LearnerState) -> T) async -> T {
        let snapshot = state
        return await Task.detached(priority: .userInitiated) {
            work(snapshot)
        }.value
    }

    private func apply(_ next: LearnerState, kind: ChangeKind) {
        state = next
        revision &+= 1
        if loadPhase == .loading {
            // Zmiana przed wczytaniem (rzadkie) — scalimy ją z wczytanym stanem, zamiast zapisywać
            // niepełny stan i nadpisać dane z dysku.
            mutatedDuringLoad = true
            return
        }
        hasPendingChanges = true
        switch kind {
        case .answer, .session, .bulk:
            flushNow()
        case .edit:
            scheduleDebouncedSave()
        }
    }

    // MARK: - Wczytanie

    /// Pierwsze wczytanie stanu z magazynu (w tle). Wołane raz z `AppEnvironment.onAppear()`.
    func load() async {
        guard loadPhase != .ready || mutatedDuringLoad else { return }
        loadPhase = .loading
        do {
            let result = try await persistence.load(now: now())
            var loaded = result.state
            if mutatedDuringLoad {
                loaded = Self.mergePreloadChanges(preload: state, loaded: loaded)
                mutatedDuringLoad = false
            }
            lastSyncedSettings = loaded.settings
            state = loaded
            revision &+= 1
            loadPhase = .ready
            if let notice = Self.notice(for: result) {
                loadNotice = [loadNotice, notice].compactMap { $0 }.joined(separator: " ")
            }
            // Zapis po migracji / scaleniu duplikatów / kompaktowaniu (repozytorium zapisze tylko różnice).
            hasPendingChanges = true
            flushNow()
        } catch {
            Self.log.error("Load failed: \(error.localizedDescription, privacy: .public)")
            loadPhase = .failed(Self.message(for: error))
        }
    }

    /// Ponowne wczytanie po zmianach z iCloud i scalenie z bieżącym stanem
    /// (`StateSync.mergeStates`) — trwająca sesja nie ginie.
    func reloadRemoteChanges() async {
        guard loadPhase == .ready else { return }
        if isReloading {
            reloadRequested = true
            return
        }
        isReloading = true
        defer { isReloading = false }
        repeat {
            reloadRequested = false
            await flush()
            do {
                // Ustawienia niezmienione lokalnie od ostatniej synchronizacji bierzemy z dysku
                // (zmiana z innego urządzenia) — inaczej `mergeStates` (ustawienia z `local`)
                // nadpisałby je przy najbliższym zapisie.
                let result = try await persistence.reloadAfterRemoteChange(now: now())
                // Liczone po `await` — zmiana ustawień w trakcie wczytywania też jest lokalna.
                let settingsChangedLocally = lastSyncedSettings.map { $0 != state.settings } ?? true
                var merged = StateSync.mergeStates(local: state, remote: result.state)
                if !settingsChangedLocally {
                    merged.settings = result.state.settings
                }
                if !result.removedWordIDs.isEmpty {
                    merged.words.removeAll { result.removedWordIDs.contains($0.id) }
                }
                merged = StateMigration.migrate(merged)
                lastSyncedSettings = merged.settings
                if merged != state {
                    state = merged
                    revision &+= 1
                }
                hasPendingChanges = true
                flushNow()
            } catch {
                Self.log.error("Remote reload failed: \(error.localizedDescription, privacy: .public)")
                syncMonitor.reportError("Nie udało się wczytać zmian z iCloud. Spróbujemy ponownie.")
            }
        } while reloadRequested
    }

    // MARK: - Zapis

    private func scheduleDebouncedSave() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: LearningStore.editDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            self?.flushNow()
        }
    }

    /// Natychmiastowy zapis bieżącej migawki (w kolejce za poprzednimi zapisami).
    private func flushNow() {
        debounceTask?.cancel()
        debounceTask = nil
        guard hasPendingChanges, loadPhase == .ready else { return }
        hasPendingChanges = false
        let snapshot = state
        let previous = saveChain
        let persistence = persistence
        saveChain = Task { [weak self] in
            await previous?.value
            do {
                try await persistence.save(snapshot)
                self?.saveSucceeded()
            } catch {
                self?.saveFailed(error)
            }
        }
    }

    /// Czeka na zapis wszystkich zmian (np. przy przejściu aplikacji w tło).
    func flush() async {
        if debounceTask != nil || hasPendingChanges {
            flushNow()
        }
        await saveChain?.value
    }

    private func saveSucceeded() {
        if lastSaveError != nil {
            lastSaveError = nil
        }
    }

    private func saveFailed(_ error: Error) {
        Self.log.error("Save failed: \(error.localizedDescription, privacy: .public)")
        hasPendingChanges = true
        lastSaveError = Self.message(for: error)
    }

    /// Ponawia zapis po błędzie (przycisk „Spróbuj ponownie” w `ErrorBanner`).
    func retryFailedSave() async {
        hasPendingChanges = true
        flushNow()
        await saveChain?.value
    }

    // MARK: - Import / eksport

    /// Import kopii JSON (strona lub aplikacja). `.merge` — `StateSync.mergeStates`, `.replace` — zastąpienie.
    func importJSON(_ data: Data, mode: ImportMode) throws -> ImportSummary {
        let imported = try StateImporter.importJSON(data)
        let summary = Self.summary(local: state, imported: imported, mode: mode)
        let next: LearnerState
        switch mode {
        case .merge:
            next = StateMigration.migrate(StateSync.mergeStates(local: state, remote: imported))
        case .replace:
            next = imported
        }
        apply(next, kind: .bulk)
        return summary
    }

    /// Jak `importJSON`, ale dekodowanie i walidacja pliku (do 50 MB) poza głównym wątkiem.
    func importJSONInBackground(_ data: Data, mode: ImportMode) async throws -> ImportSummary {
        let imported = try await Self.decodeImportInBackground(data)
        let summary = Self.summary(local: state, imported: imported, mode: mode)
        let next: LearnerState
        switch mode {
        case .merge:
            next = StateMigration.migrate(StateSync.mergeStates(local: state, remote: imported))
        case .replace:
            next = imported
        }
        apply(next, kind: .bulk)
        return summary
    }

    /// Jak `previewImportJSON`, ale dekodowanie poza głównym wątkiem.
    func previewImportJSONInBackground(_ data: Data) async throws -> ImportSummary {
        let imported = try await Self.decodeImportInBackground(data)
        return Self.summary(local: state, imported: imported, mode: .merge)
    }

    nonisolated private static func decodeImportInBackground(_ data: Data) async throws -> LearnerState {
        try await Task.detached(priority: .userInitiated) {
            try StateImporter.importJSON(data)
        }.value
    }

    /// Import CSV/TSV/listy słów (`DelimitedImport`).
    func importDelimited(_ text: String) throws -> ImportSummary {
        let result = try DelimitedImport.importRows(text, into: state, now: now())
        apply(result.state, kind: .bulk)
        return Self.summary(delimited: result)
    }

    /// Podgląd importu JSON bez zapisu.
    func previewImportJSON(_ data: Data) throws -> ImportSummary {
        let imported = try StateImporter.importJSON(data)
        return Self.summary(local: state, imported: imported, mode: .merge)
    }

    /// Podgląd importu CSV/TSV bez zapisu.
    func previewImportDelimited(_ text: String) throws -> ImportSummary {
        let result = try DelimitedImport.importRows(text, into: state, now: now())
        return Self.summary(delimited: result)
    }

    /// Pełna kopia JSON (zgodna ze stroną) w pliku tymczasowym — do `ShareLink`.
    func exportJSONFile() throws -> URL {
        let data = try StateExporter.exportJSON(state)
        return try ExportFileWriter.write(data, baseName: "FluentNOW-kopia", fileExtension: "json")
    }

    /// CSV dla Anki w pliku tymczasowym.
    func exportAnkiCSVFile() throws -> URL {
        let csv = StateExporter.ankiCSV(state)
        return try ExportFileWriter.write(Data(csv.utf8), baseName: "FluentNOW-anki", fileExtension: "csv")
    }

    /// Jak `exportJSONFile()`, ale kodowanie i zapis pliku poza głównym wątkiem (duże kopie).
    func exportJSONFileInBackground() async throws -> URL {
        let snapshot = state
        return try await Task.detached(priority: .userInitiated) {
            let data = try StateExporter.exportJSON(snapshot)
            return try ExportFileWriter.write(data, baseName: "FluentNOW-kopia", fileExtension: "json")
        }.value
    }

    /// Jak `exportAnkiCSVFile()`, ale poza głównym wątkiem.
    func exportAnkiCSVFileInBackground() async throws -> URL {
        let snapshot = state
        return try await Task.detached(priority: .userInitiated) {
            let csv = StateExporter.ankiCSV(snapshot)
            return try ExportFileWriter.write(Data(csv.utf8), baseName: "FluentNOW-anki", fileExtension: "csv")
        }.value
    }

    /// Usuwa wszystkie dane: lokalnie, w iCloud (usunięcie rekordów synchronizuje się),
    /// zgłoszenia, klucz AI i pliki eksportu (przez `onDeleteAll`).
    func deleteAllData() async throws {
        debounceTask?.cancel()
        debounceTask = nil
        hasPendingChanges = false
        await saveChain?.value
        do {
            try await persistence.deleteAll()
        } catch {
            throw PersistenceError.deleteFailed(error.localizedDescription)
        }
        state = .empty
        lastSyncedSettings = LearnerState.empty.settings
        revision &+= 1
        lastSaveError = nil
        loadNotice = nil
        ExportFileWriter.removeAll()
        if let onDeleteAll {
            await onDeleteAll()
        }
    }

    // MARK: - Pomocnicze

    /// Scala zmiany zrobione przed zakończeniem wczytywania (stan startowy `.empty` + zmiany)
    /// z wczytanym stanem. `mergeStates` bierze ustawienia i sesje z `local` — tutaj `local` to
    /// pusty stan startowy, więc wartości domyślne nie mogą nadpisać zapisanych ustawień ani
    /// przerwanych sesji.
    static func mergePreloadChanges(preload: LearnerState, loaded: LearnerState) -> LearnerState {
        var merged = StateSync.mergeStates(local: preload, remote: loaded)
        if preload.settings == LearnerState.empty.settings {
            merged.settings = loaded.settings
        }
        merged.session = preload.session ?? loaded.session
        merged.reading = preload.reading ?? loaded.reading
        merged.practice = preload.practice ?? loaded.practice
        merged.production = preload.production ?? loaded.production
        merged.combined = preload.combined ?? loaded.combined
        // Test poziomu (K4); historia testów jest już scalona przez `mergeStates`.
        merged.assessment = preload.assessment ?? loaded.assessment
        merged.demo = preload.demo || loaded.demo
        return StateMigration.migrate(merged)
    }

    static func summary(local: LearnerState, imported: LearnerState, mode: ImportMode) -> ImportSummary {
        let localIDs = Set(local.words.map(\.id))
        let total = imported.words.count
        var messages: [String] = []
        switch mode {
        case .merge:
            let newWords = imported.words.filter { !localIDs.contains($0.id) }.count
            let merged = total - newWords
            if merged > 0 {
                messages.append("Słowa obecne w obu miejscach zostaną scalone — postęp z obu kopii jest zachowany.")
            }
            if !imported.reviews.isEmpty {
                messages.append("Historia odpowiedzi: \(imported.reviews.count) wpisów.")
            }
            return ImportSummary(newWords: newWords, mergedWords: merged, skipped: 0, messages: messages)
        case .replace:
            if !local.words.isEmpty {
                messages.append("Obecne dane (\(local.words.count) słów) zostaną zastąpione zawartością pliku.")
            }
            return ImportSummary(newWords: total, mergedWords: 0, skipped: 0, messages: messages)
        }
    }

    static func summary(delimited result: DelimitedImportResult) -> ImportSummary {
        let mergedWords = max(0, result.addedMeanings - result.addedWords)
        var messages: [String] = []
        if result.addedMeanings > 0 {
            messages.append("Nowe znaczenia: \(result.addedMeanings).")
        }
        if result.skippedExisting > 0 {
            messages.append("Pominięto \(result.skippedExisting) — te słowa z tym tłumaczeniem już masz.")
        }
        return ImportSummary(newWords: result.addedWords, mergedWords: mergedWords, skipped: result.skippedExisting, messages: messages)
    }

    private static func notice(for result: PersistenceLoadResult) -> String? {
        guard result.skippedRecords > 0 else { return nil }
        return "Pominięto \(result.skippedRecords) uszkodzonych rekordów. Pozostałe dane wczytano poprawnie."
    }

    static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
