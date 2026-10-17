import Foundation
import Observation
import FluentKit

/// Reports „Zdjęcie nie pasuje” (G2) — a separate local file `image-reports.json` in
/// Application Support (not synced). Exported from Settings next to exercise reports.
@MainActor
@Observable
final class ImageReportStore {
    private(set) var reports: [ImageReport]

    /// Maximum number of stored reports (the oldest are removed).
    static let maxReports = 500

    @ObservationIgnored private let fileURL: URL?
    private static let writeQueue = DispatchQueue(label: "pl.fluentnow.image-reports", qos: .utility)

    /// - Parameter fileURL: `nil` = memory only (previews, tests).
    init(fileURL: URL?, initial: [ImageReport] = []) {
        self.fileURL = fileURL
        if let fileURL, let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([ImageReport].self, from: data) {
            reports = decoded
        } else {
            reports = initial
        }
    }

    /// Default location of the report file.
    static func defaultFileURL() -> URL? {
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        return support.appendingPathComponent("image-reports.json")
    }

    func add(_ report: ImageReport) {
        reports.insert(report, at: 0)
        if reports.count > Self.maxReports {
            reports.removeLast(reports.count - Self.maxReports)
        }
        persist()
    }

    /// JSON file with all image reports in the temporary folder (for `ShareLink`).
    func exportFile() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(reports)
        } catch {
            throw ExportFileError.encodingFailed
        }
        return try ExportFileWriter.write(data, baseName: "FluentNOW-zdjecia-zgloszenia", fileExtension: "json")
    }

    func removeAll() {
        reports = []
        persist()
    }

    private func persist() {
        guard let fileURL else { return }
        let snapshot = reports
        // Serial queue: writes in order of changes, off the main thread.
        Self.writeQueue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
}
