import Foundation
import SwiftData
import os

/// Wynik przygotowania magazynu przy starcie aplikacji.
struct LiveStoreSetup {
    let persistence: any LearningPersistence
    let syncMode: SyncMode
    /// Komunikat dla użytkownika (np. przeniesienie uszkodzonej bazy do kopii zapasowej).
    let notice: String?
    /// Katalog z kopią uszkodzonej bazy (jeśli powstała).
    let backupURL: URL?
}

/// Tworzy `ModelContainer` raz przy starcie: CloudKit, gdy aplikacja ma uprawnienie,
/// inaczej (lub przy błędzie) magazyn lokalny; uszkodzony magazyn trafia do kopii zapasowej
/// i powstaje nowy; w ostateczności magazyn w pamięci. Nigdy nie kończy się crashem.
enum PersistenceController {
    static let schema = Schema([
        WordRecord.self,
        ReviewRecord.self,
        SettingsRecord.self,
        SessionRecord.self,
        HistoryRecord.self
    ])

    private static let log = Logger(subsystem: "pl.fluentnow.app", category: "Persistence")
    private static let storeName = "FluentNOW"

    static func makeLive() -> LiveStoreSetup {
        let url = storeURL()
        let wantsCloud = CloudKitAvailability.hasCloudKitEntitlement

        if wantsCloud, let container = try? makeContainer(url: url, cloudKit: true) {
            return LiveStoreSetup(
                persistence: SwiftDataPersistence(container: container),
                syncMode: .cloudKit(containerIdentifier: CloudKitAvailability.containerIdentifier),
                notice: nil,
                backupURL: nil
            )
        }

        let localReason = wantsCloud
            ? "Nie udało się włączyć synchronizacji iCloud. Dane zapisują się na tym urządzeniu."
            : "Ta wersja aplikacji nie ma włączonej usługi iCloud — dane zapisują się tylko na tym urządzeniu."

        do {
            let container = try makeContainer(url: url, cloudKit: false)
            return LiveStoreSetup(
                persistence: SwiftDataPersistence(container: container),
                syncMode: .localOnly(localReason),
                notice: nil,
                backupURL: nil
            )
        } catch {
            log.error("Store open failed: \(error.localizedDescription, privacy: .public)")
        }

        // Magazyn nie otwiera się nawet lokalnie — przenosimy go do kopii i zaczynamy od nowa.
        let backup = moveStoreToBackup(url: url)
        let backupNotice = "Baza danych na tym urządzeniu była uszkodzona. Zachowaliśmy jej kopię (możesz ją udostępnić w Ustawieniach) i utworzyliśmy nową."
            + (wantsCloud ? " Jeśli korzystasz z iCloud, dane wrócą z chmury." : " Jeśli masz eksport JSON, możesz go zaimportować w Ustawieniach.")
        if wantsCloud, let container = try? makeContainer(url: url, cloudKit: true) {
            return LiveStoreSetup(
                persistence: SwiftDataPersistence(container: container),
                syncMode: .cloudKit(containerIdentifier: CloudKitAvailability.containerIdentifier),
                notice: backupNotice,
                backupURL: backup
            )
        }
        if let container = try? makeContainer(url: url, cloudKit: false) {
            return LiveStoreSetup(
                persistence: SwiftDataPersistence(container: container),
                syncMode: .localOnly(localReason),
                notice: backupNotice,
                backupURL: backup
            )
        }

        // Ostateczność: magazyn w pamięci — aplikacja działa, ale zmiany nie przetrwają zamknięcia.
        let memoryNotice = "Nie udało się otworzyć bazy danych. Zmiany z tej sesji nie zostaną zapisane — wyeksportuj kopię przed zamknięciem aplikacji."
        if let container = try? ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]) {
            return LiveStoreSetup(
                persistence: SwiftDataPersistence(container: container),
                syncMode: .localOnly(memoryNotice),
                notice: memoryNotice,
                backupURL: backup
            )
        }
        return LiveStoreSetup(
            persistence: InMemoryPersistence(),
            syncMode: .localOnly(memoryNotice),
            notice: memoryNotice,
            backupURL: backup
        )
    }

    /// Kontener w pamięci (testy).
    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeContainer(url: URL, cloudKit: Bool) throws -> ModelContainer {
        let database: ModelConfiguration.CloudKitDatabase = cloudKit
            ? .private(CloudKitAvailability.containerIdentifier)
            : .none
        let configuration = ModelConfiguration(storeName, schema: schema, url: url, cloudKitDatabase: database)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// `Application Support/FluentNOW/FluentNOW.store`.
    static func storeURL() -> URL {
        let fileManager = FileManager.default
        let support = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
        let folder = support.appendingPathComponent("FluentNOW", isDirectory: true)
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("FluentNOW.store")
    }

    /// Przenosi pliki magazynu (`.store`, `-shm`, `-wal`) do `Documents/Kopie/<data>/`.
    @discardableResult
    static func moveStoreToBackup(url: URL) -> URL? {
        let fileManager = FileManager.default
        guard let documents = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let folder = documents
            .appendingPathComponent("Kopie", isDirectory: true)
            .appendingPathComponent(formatter.string(from: Date()), isDirectory: true)
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        var movedAny = false
        for suffix in ["", "-shm", "-wal"] {
            let source = URL(fileURLWithPath: url.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = folder.appendingPathComponent(source.lastPathComponent)
            do {
                try fileManager.moveItem(at: source, to: target)
                movedAny = true
            } catch {
                try? fileManager.removeItem(at: source)
            }
        }
        return movedAny ? folder : nil
    }
}
