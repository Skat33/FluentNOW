import Foundation
import Observation
import CoreData
import CloudKit

/// Stan synchronizacji iCloud pokazywany w Ustawieniach.
enum SyncStatus: Equatable {
    /// Zsynchronizowano (data ostatniej udanej wymiany, jeśli znana).
    case synced(Date?)
    /// Trwa wymiana danych z iCloud.
    case syncing
    /// Dane tylko na tym urządzeniu (powód po polsku).
    case localOnly(String)
    /// Błąd synchronizacji (komunikat po polsku). Dane lokalne są bezpieczne.
    case error(String)
}

extension SyncStatus {
    /// Krótki opis po polsku do wiersza w Ustawieniach.
    var titlePl: String {
        switch self {
        case .synced: return "Zsynchronizowano z iCloud"
        case .syncing: return "Synchronizacja…"
        case .localOnly: return "Tylko na tym urządzeniu"
        case .error: return "Błąd synchronizacji"
        }
    }

    /// Szczegóły (powód, komunikat, data) — może być pusty.
    var detailPl: String {
        switch self {
        case .synced(let date):
            guard let date else { return "Dane są zapisane w iCloud." }
            return "Ostatnio: " + date.formatted(date: .abbreviated, time: .shortened)
        case .syncing:
            return "Wymiana danych z iCloud trwa w tle."
        case .localOnly(let reason):
            return reason
        case .error(let message):
            return message
        }
    }

    var systemImage: String {
        switch self {
        case .synced: return "checkmark.icloud"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .localOnly: return "icloud.slash"
        case .error: return "exclamationmark.icloud"
        }
    }
}

/// Konfiguracja monitora ustalana przy tworzeniu kontenera danych.
enum SyncMode: Equatable {
    /// Magazyn z CloudKit (identyfikator kontenera iCloud).
    case cloudKit(containerIdentifier: String)
    /// Magazyn lokalny (powód po polsku).
    case localOnly(String)
    /// Podgląd / testy — stały stan, bez systemowych usług.
    case fixed(SyncStatus)
}

/// Obserwuje stan konta iCloud i zdarzenia `NSPersistentCloudKitContainer` (SwiftData z CloudKit
/// korzysta z niego pod spodem) i wystawia czytelny `SyncStatus`.
@MainActor
@Observable
final class SyncMonitor {
    private(set) var status: SyncStatus

    /// Wołane po udanym imporcie zmian z iCloud (AppEnvironment → `store.reloadRemoteChanges()`).
    @ObservationIgnored var onRemoteImport: (@MainActor () -> Void)?

    @ObservationIgnored private let mode: SyncMode
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var lastSuccess: Date?
    @ObservationIgnored private var accountAvailable = true
    @ObservationIgnored private var activeEvents = 0

    init(mode: SyncMode) {
        self.mode = mode
        switch mode {
        case .cloudKit:
            status = .syncing
        case .localOnly(let reason):
            status = .localOnly(reason)
        case .fixed(let fixed):
            status = fixed
        }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Czy dane są synchronizowane przez CloudKit (a nie tylko lokalnie).
    var usesCloudKit: Bool {
        if case .cloudKit = mode { return true }
        return false
    }

    /// Rozpoczyna obserwację zdarzeń (wołane raz po utworzeniu kontenera).
    func start() {
        guard case .cloudKit = mode, observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event else { return }
            let finished = event.endDate != nil
            let succeeded = event.succeeded
            let message = event.error.map { SyncMonitor.describe($0) }
            let endDate = event.endDate
            let isImport = event.type == .import
            Task { @MainActor in
                self?.handleEvent(finished: finished, succeeded: succeeded, errorMessage: message, endDate: endDate, isImport: isImport)
            }
        })
        observers.append(center.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        })
    }

    /// Sprawdza ponownie stan konta iCloud.
    func refresh() async {
        switch mode {
        case .fixed, .localOnly:
            return
        case .cloudKit(let identifier):
            let accountStatus: CKAccountStatus
            do {
                accountStatus = try await CKContainer(identifier: identifier).accountStatus()
            } catch {
                accountAvailable = false
                status = .error("Nie udało się sprawdzić konta iCloud: \(error.localizedDescription)")
                return
            }
            switch accountStatus {
            case .available:
                accountAvailable = true
                if case .localOnly = status { status = .synced(lastSuccess) }
                if case .syncing = status, activeEvents == 0 { status = .synced(lastSuccess) }
                if case .error = status { status = .synced(lastSuccess) }
            case .noAccount:
                accountAvailable = false
                status = .localOnly("Zaloguj się do iCloud w Ustawieniach systemu, aby synchronizować postępy między urządzeniami.")
            case .restricted:
                accountAvailable = false
                status = .localOnly("Dostęp do iCloud jest ograniczony na tym urządzeniu (np. przez Czas przed ekranem lub profil firmowy).")
            case .temporarilyUnavailable:
                accountAvailable = false
                status = .localOnly("iCloud jest chwilowo niedostępny. Dane zapisują się lokalnie i zsynchronizują później.")
            case .couldNotDetermine:
                accountAvailable = false
                status = .localOnly("Nie można ustalić stanu konta iCloud. Dane zapisują się lokalnie.")
            @unknown default:
                accountAvailable = false
                status = .localOnly("Stan iCloud jest nieznany. Dane zapisują się lokalnie.")
            }
        }
    }

    /// Zgłoszenie z warstwy trwałości (np. nieudany zapis lokalny nie zmienia statusu iCloud,
    /// ale błąd odczytu zdalnych zmian — tak).
    func reportError(_ message: String) {
        guard case .cloudKit = mode else { return }
        status = .error(message)
    }

    private func handleEvent(finished: Bool, succeeded: Bool, errorMessage: String?, endDate: Date?, isImport: Bool) {
        if finished, succeeded, isImport {
            onRemoteImport?()
        }
        guard accountAvailable else { return }
        if !finished {
            activeEvents += 1
            status = .syncing
            return
        }
        activeEvents = max(0, activeEvents - 1)
        if succeeded {
            lastSuccess = endDate ?? Date()
            if activeEvents == 0 { status = .synced(lastSuccess) }
        } else if let errorMessage {
            status = .error(errorMessage)
        } else if activeEvents == 0 {
            status = .synced(lastSuccess)
        }
    }

    nonisolated private static func describe(_ error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                return "Brak połączenia z internetem. Zmiany wyślą się automatycznie później."
            case .quotaExceeded:
                return "Brak miejsca w iCloud. Zwolnij miejsce, aby synchronizacja wróciła."
            case .notAuthenticated:
                return "Nie zalogowano do iCloud."
            case .requestRateLimited, .serviceUnavailable, .zoneBusy:
                return "iCloud jest chwilowo przeciążony. Ponowimy automatycznie."
            default:
                return "iCloud zgłosił błąd (\(ckError.code.rawValue)). Dane lokalne są bezpieczne."
            }
        }
        return "Synchronizacja nie powiodła się: \(error.localizedDescription). Dane lokalne są bezpieczne."
    }
}
