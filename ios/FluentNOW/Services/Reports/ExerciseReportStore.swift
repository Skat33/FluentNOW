import Foundation
import Observation
import FluentKit

/// Zgłoszenie błędnego zadania („To zadanie jest błędne”) — zapisywane lokalnie,
/// użytkownik może je wyeksportować i wysłać autorom.
struct ExerciseReport: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var createdAt: Timestamp
    var mode: String
    var question: String
    var answer: String
    var expected: [String]
    var wordId: String?
    var meaningId: String?
    var comment: String

    init(
        id: String = UUID().uuidString.lowercased(),
        createdAt: Timestamp = FluentClock.now(),
        mode: String,
        question: String,
        answer: String,
        expected: [String],
        wordId: String? = nil,
        meaningId: String? = nil,
        comment: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mode = mode
        self.question = question
        self.answer = answer
        self.expected = expected
        self.wordId = wordId
        self.meaningId = meaningId
        self.comment = comment
    }
}

/// Lokalny magazyn zgłoszeń (plik JSON w Application Support, bez iCloud).
@MainActor
@Observable
final class ExerciseReportStore {
    private(set) var reports: [ExerciseReport]

    /// Maksymalna liczba przechowywanych zgłoszeń (najstarsze są usuwane).
    static let maxReports = 500

    @ObservationIgnored private let fileURL: URL?
    private static let writeQueue = DispatchQueue(label: "pl.fluentnow.reports", qos: .utility)

    /// - Parameter fileURL: `nil` = tylko w pamięci (podgląd, testy).
    init(fileURL: URL?, initial: [ExerciseReport] = []) {
        self.fileURL = fileURL
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([ExerciseReport].self, from: data) {
            reports = decoded
        } else {
            reports = initial
        }
    }

    /// Domyślne położenie pliku zgłoszeń.
    static func defaultFileURL() -> URL? {
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        return support.appendingPathComponent("exercise-reports.json")
    }

    func add(_ report: ExerciseReport) {
        reports.insert(report, at: 0)
        if reports.count > Self.maxReports {
            reports.removeLast(reports.count - Self.maxReports)
        }
        persist()
    }

    /// Plik JSON ze wszystkimi zgłoszeniami w katalogu tymczasowym (do `ShareLink`).
    func exportFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(reports)
        } catch {
            throw ExportFileError.encodingFailed
        }
        return try ExportFileWriter.write(data, baseName: "FluentNOW-zgloszenia", fileExtension: "json")
    }

    func removeAll() {
        reports = []
        persist()
    }

    private func persist() {
        guard let fileURL else { return }
        let snapshot = reports
        // Kolejka szeregowa: zapisy w kolejności zmian, poza głównym wątkiem.
        Self.writeQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
}
