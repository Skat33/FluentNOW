import Foundation
import os
import FluentKit

/// Błędy lokalnej pamięci tematów.
enum LocalTopicStoreError: Error, LocalizedError, Equatable {
    case unavailable
    case invalidTopicID(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Pamięć tematów jest niedostępna na tym urządzeniu."
        case .invalidTopicID(let id):
            return "Niepoprawny identyfikator tematu „\(id)”."
        case .writeFailed(let detail):
            return "Nie udało się zapisać tematu na urządzeniu (\(detail)). Wygenerowane słowa są nadal widoczne — spróbuj ponownie."
        }
    }
}

/// Lokalna pamięć tematów wygenerowanych przez AI i zapamiętanych zapytań (Application Support,
/// `FluentNOW/GeneratedTopics/`):
/// - `topics/<id>.json` — `GeneratedTopicRecord` (temat w formacie `TopicFile`),
/// - `aliases.json` — `TopicAliasBook` (zapytanie → temat/kategoria).
///
/// Zapis atomowy (`.atomic`: plik tymczasowy + podmiana), więc przerwany zapis nie psuje danych.
/// Uszkodzony plik jest odkładany jako `*.corrupt` (do diagnozy) i pomijany — reszta działa.
/// Typ bez stanu (`Sendable`); używany wyłącznie z aktora `ContentLibrary`, który szereguje dostęp.
struct LocalTopicStore: Sendable {
    let directory: URL

    private static let log = Logger(subsystem: "pl.fluentnow.app", category: "LocalTopicStore")

    init(directory: URL) {
        self.directory = directory
    }

    /// `Application Support/FluentNOW/GeneratedTopics` (lokalnie, z kopią zapasową iCloud urządzenia).
    static func defaultDirectory() -> URL? {
        guard let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        return base
            .appendingPathComponent("FluentNOW", isDirectory: true)
            .appendingPathComponent("GeneratedTopics", isDirectory: true)
    }

    private var topicsDirectory: URL { directory.appendingPathComponent("topics", isDirectory: true) }
    private var aliasesURL: URL { directory.appendingPathComponent("aliases.json") }

    // MARK: Tematy

    /// Wszystkie zapisane tematy (uszkodzone pliki pominięte i odłożone jako `*.corrupt`).
    func loadRecords() -> [GeneratedTopicRecord] {
        let manager = FileManager.default
        guard let names = try? manager.contentsOfDirectory(atPath: topicsDirectory.path) else { return [] }
        var records: [GeneratedTopicRecord] = []
        let decoder = JSONDecoder()
        for name in names.sorted() where name.hasSuffix(".json") {
            let url = topicsDirectory.appendingPathComponent(name)
            do {
                let data = try Data(contentsOf: url)
                let record = try decoder.decode(GeneratedTopicRecord.self, from: data)
                guard ContentLibrary.isSafeFileName(record.topic.id), name == "\(record.topic.id).json" else {
                    Self.log.error("Pominięto temat o niezgodnej nazwie pliku: \(name, privacy: .public)")
                    continue
                }
                records.append(record)
            } catch {
                Self.log.error("Uszkodzony temat \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                quarantine(url)
            }
        }
        return records
    }

    func save(_ record: GeneratedTopicRecord) throws {
        let id = record.topic.id
        guard ContentLibrary.isSafeFileName(id) else { throw LocalTopicStoreError.invalidTopicID(id) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(record)
            try ensureDirectory(topicsDirectory)
            try data.write(to: topicsDirectory.appendingPathComponent("\(id).json"), options: [.atomic])
        } catch let error as LocalTopicStoreError {
            throw error
        } catch {
            throw LocalTopicStoreError.writeFailed(error.localizedDescription)
        }
    }

    func delete(topicID: String) {
        guard ContentLibrary.isSafeFileName(topicID) else { return }
        try? FileManager.default.removeItem(at: topicsDirectory.appendingPathComponent("\(topicID).json"))
    }

    // MARK: Zapytania

    func loadAliases() -> TopicAliasBook {
        guard let data = try? Data(contentsOf: aliasesURL) else { return TopicAliasBook() }
        do {
            return try JSONDecoder().decode(TopicAliasBook.self, from: data)
        } catch {
            Self.log.error("Uszkodzony plik aliasów: \(error.localizedDescription, privacy: .public)")
            quarantine(aliasesURL)
            return TopicAliasBook()
        }
    }

    func saveAliases(_ book: TopicAliasBook) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(book)
            try ensureDirectory(directory)
            try data.write(to: aliasesURL, options: [.atomic])
        } catch {
            throw LocalTopicStoreError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: Całość

    /// Usuwa całą pamięć tematów („Usuń wszystkie dane”).
    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Pomocnicze

    private func ensureDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func quarantine(_ url: URL) {
        let manager = FileManager.default
        let target = url.appendingPathExtension("corrupt")
        try? manager.removeItem(at: target)
        do {
            try manager.moveItem(at: url, to: target)
        } catch {
            Self.log.error("Nie udało się odłożyć uszkodzonego pliku: \(error.localizedDescription, privacy: .public)")
        }
    }
}
