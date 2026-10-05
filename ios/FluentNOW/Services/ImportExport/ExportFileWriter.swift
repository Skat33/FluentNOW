import Foundation

/// Błędy tworzenia plików eksportu.
enum ExportFileError: Error, LocalizedError, Equatable {
    case encodingFailed
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Nie udało się przygotować danych do eksportu."
        case .writeFailed(let detail):
            return "Nie udało się zapisać pliku eksportu: \(detail)"
        }
    }
}

/// Zapis plików eksportu do katalogu tymczasowego (gotowe do `ShareLink` / `fileExporter`).
enum ExportFileWriter {
    /// Podkatalog w `tmp/`, czyszczony przy każdym nowym eksporcie danego typu.
    static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
    }

    /// Zapisuje dane do `tmp/Export/<baseName>-<data>.<ext>` i zwraca URL pliku.
    static func write(_ data: Data, baseName: String, fileExtension: String, date: Date = Date()) throws -> URL {
        let fileManager = FileManager.default
        let folder = directory
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            // Usuń poprzednie eksporty tego samego typu (nie zostawiamy kopii danych w tmp).
            if let existing = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                for url in existing where url.lastPathComponent.hasPrefix(baseName + "-") {
                    try? fileManager.removeItem(at: url)
                }
            }
            let url = folder.appendingPathComponent("\(baseName)-\(stamp(date)).\(fileExtension)")
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            throw ExportFileError.writeFailed(error.localizedDescription)
        }
    }

    /// Usuwa wszystkie pliki eksportu (np. przy „Usuń wszystkie dane”).
    static func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }
}
