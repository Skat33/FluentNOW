import Foundation
import FluentKit

/// Photos for the „Słowo i zdjęcie” exercise (G2): internet only (Openverse), cached on disk,
/// one permanent photo per word meaning, downloaded in the background before sessions.
///
/// - assignments (meaning → chosen photo + remaining candidates + reported ones):
///   `Application Support/WordImages/word-images.json` — survives cache purges, so the same photo
///   comes back at every review (re-downloaded from the same URL when the system cleared Caches);
/// - image files: `Caches/WordImages/<id>.jpg` (the system may purge them; nothing breaks);
/// - nothing here ever blocks the UI or a session: no network → no new photos, the exercise
///   simply is not drawn.
actor WordImageService {
    /// Minimum pause between two searches (anonymous Openverse limit is 20/min).
    static let searchInterval: TimeInterval = 3.5
    /// Searches per background run (daily anonymous limit is 200).
    static let maxSearchesPerRun = 12
    /// Downloads per background run.
    static let maxDownloadsPerRun = 30
    /// A search without a usable result is retried after this many days.
    static let emptyRetryDays: Double = 14

    private let client: OpenverseClient?
    private let storeURL: URL?
    private let cacheDirectory: URL?
    private var assignments: [String: WordImageAssignment] = [:]
    private var blockedUntil: Timestamp = 0
    private var loaded = false
    private var isPrefetching = false
    private var lastSearchAt: Date = .distantPast

    /// - Parameters:
    ///   - networkEnabled: `false` in previews and tests (no requests at all).
    ///   - storeURL / cacheDirectory: `nil` → default locations; tests pass temporary folders.
    init(networkEnabled: Bool = true, storeURL: URL? = nil, cacheDirectory: URL? = nil, session: URLSession? = nil) {
        if networkEnabled {
            client = OpenverseClient(session: session ?? OpenverseClient.makeSession())
        } else {
            client = nil
        }
        self.storeURL = storeURL ?? WordImageService.defaultStoreURL()
        self.cacheDirectory = cacheDirectory ?? WordImageService.defaultCacheDirectory()
    }

    /// Preview instance: no network (reads photos cached earlier, if any).
    static func offline() -> WordImageService {
        WordImageService(networkEnabled: false)
    }

    static func defaultStoreURL() -> URL? {
        guard let support = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        return support
            .appendingPathComponent("WordImages", isDirectory: true)
            .appendingPathComponent("word-images.json")
    }

    static func defaultCacheDirectory() -> URL? {
        guard let caches = try? FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return nil
        }
        return caches.appendingPathComponent("WordImages", isDirectory: true)
    }

    // MARK: Reading

    /// Meanings whose chosen photo is on disk right now (input of
    /// `PictureExercise.readyMeaningIDs`). Cheap: one directory check per assignment.
    func cachedMeaningIDs() -> Set<String> {
        loadIfNeeded()
        var result = Set<String>()
        for (meaningID, assignment) in assignments {
            guard let record = assignment.chosen, let url = fileURL(for: record) else { continue }
            if FileManager.default.fileExists(atPath: url.path) {
                result.insert(meaningID)
            }
        }
        return result
    }

    /// Meanings that need no background work now: photo on disk, or searched recently without a
    /// usable result. Passed as `excluding:` to `PictureExercise.prefetchCandidates`.
    func settledMeaningIDs() -> Set<String> {
        var result = cachedMeaningIDs()
        for (meaningID, assignment) in assignments where !needsNewSearch(assignment) && assignment.nextCandidate == nil {
            result.insert(meaningID)
        }
        return result
    }

    /// The cached photo of a meaning, or `nil` when it is not on disk.
    func image(for meaningID: String) -> WordImage? {
        loadIfNeeded()
        guard let record = assignments[meaningID]?.chosen, let url = fileURL(for: record),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return WordImage(meaningId: meaningID, record: record, fileURL: url)
    }

    /// Photos of several meanings; `nil` when any of them is missing (the exercise then falls
    /// back to „Wybierz znaczenie”).
    func images(for meaningIDs: [String]) -> [WordImage]? {
        var result: [WordImage] = []
        for meaningID in meaningIDs {
            guard let found = image(for: meaningID) else { return nil }
            result.append(found)
        }
        return result
    }

    // MARK: Background download

    /// Downloads photos for the given candidates (in order) without ever blocking: sequential,
    /// throttled, stops at the first sign of being offline or rate-limited. Concurrent calls are
    /// ignored while a run is in progress.
    func prefetch(_ candidates: [PictureCandidate]) async {
        guard let client, !candidates.isEmpty, !isPrefetching else { return }
        loadIfNeeded()
        isPrefetching = true
        defer { isPrefetching = false }
        var searches = 0
        var downloads = 0
        var changed = false
        for candidate in candidates {
            if Task.isCancelled { break }
            if downloads >= Self.maxDownloadsPerRun { break }
            do {
                var assignment = assignments[candidate.meaningId]
                if assignment == nil || needsNewSearch(assignment) {
                    guard searches < Self.maxSearchesPerRun, FluentClock.now() >= blockedUntil else { continue }
                    await throttle()
                    searches += 1
                    lastSearchAt = Date()
                    let records = try await client.search(query: candidate.query)
                    let previous = assignment
                    assignment = WordImageAssignment(
                        meaningId: candidate.meaningId,
                        wordId: candidate.wordId,
                        term: candidate.term,
                        query: candidate.query,
                        candidates: records,
                        chosenID: nil,
                        rejectedIDs: previous?.rejectedIDs ?? [],
                        searchedAt: FluentClock.now()
                    )
                    changed = true
                }
                guard var current = assignment else { continue }
                if current.chosen == nil || current.rejectedIDs.contains(current.chosenID ?? "") {
                    current.chosenID = current.nextCandidate?.id
                    changed = true
                }
                assignments[candidate.meaningId] = current
                if try await ensureDownloaded(meaningID: candidate.meaningId, client: client) {
                    downloads += 1
                    changed = true
                }
            } catch WordImageError.offline {
                break
            } catch WordImageError.rateLimited(let retryAfter) {
                blockedUntil = FluentClock.now() + retryAfter * 1_000
                changed = true
                break
            } catch is CancellationError {
                break
            } catch {
                // One bad result (broken file, HTTP error) — skip this word, keep going.
                continue
            }
        }
        if changed { persist() }
    }

    // MARK: Reports

    /// „Zdjęcie nie pasuje”: the photo is never used again for this meaning; the next candidate
    /// (if any) becomes the chosen one and is downloaded in the background.
    func reject(meaningID: String, imageID: String) async {
        loadIfNeeded()
        guard var assignment = assignments[meaningID] else { return }
        if !assignment.rejectedIDs.contains(imageID) {
            assignment.rejectedIDs.append(imageID)
        }
        if let old = assignment.candidates.first(where: { $0.id == imageID }), let url = fileURL(for: old) {
            try? FileManager.default.removeItem(at: url)
        }
        assignment.chosenID = assignment.nextCandidate?.id
        assignments[meaningID] = assignment
        persist()
        guard let client, !isPrefetching else { return }
        _ = try? await ensureDownloaded(meaningID: meaningID, client: client)
    }

    /// Removes all photos and assignments („Usuń wszystkie dane”).
    func removeAll() {
        assignments = [:]
        blockedUntil = 0
        loaded = true
        if let cacheDirectory {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
        if let storeURL {
            try? FileManager.default.removeItem(at: storeURL)
        }
    }

    // MARK: Private

    private func needsNewSearch(_ assignment: WordImageAssignment?) -> Bool {
        guard let assignment else { return true }
        if assignment.nextCandidate != nil { return false }
        let age = FluentClock.now() - assignment.searchedAt
        return age > Self.emptyRetryDays * TimeConstants.dayMs
    }

    /// Waits so that searches keep the anonymous rate limit.
    private func throttle() async {
        let elapsed = Date().timeIntervalSince(lastSearchAt)
        guard elapsed < Self.searchInterval else { return }
        let wait = Self.searchInterval - elapsed
        try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
    }

    /// Downloads the chosen photo when it is not on disk. Returns `true` after a download.
    /// A broken photo is rejected and the next candidate is tried (at most 3 per call).
    private func ensureDownloaded(meaningID: String, client: OpenverseClient) async throws -> Bool {
        var attempts = 0
        while attempts < 3 {
            attempts += 1
            guard let assignment = assignments[meaningID], let record = assignment.chosen,
                  let url = fileURL(for: record) else { return false }
            if FileManager.default.fileExists(atPath: url.path) { return false }
            do {
                let data = try await client.downloadImage(from: record.thumbnailURL)
                try writeImage(data, to: url)
                return true
            } catch WordImageError.notAnImage {
                markBroken(meaningID: meaningID, imageID: record.id)
            } catch WordImageError.http(let code) where code == 404 || code == 410 || code == 424 {
                markBroken(meaningID: meaningID, imageID: record.id)
            }
        }
        return false
    }

    private func markBroken(meaningID: String, imageID: String) {
        guard var assignment = assignments[meaningID] else { return }
        if !assignment.rejectedIDs.contains(imageID) {
            assignment.rejectedIDs.append(imageID)
        }
        assignment.chosenID = assignment.nextCandidate?.id
        assignments[meaningID] = assignment
    }

    private func writeImage(_ data: Data, to url: URL) throws {
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic])
    }

    private func fileURL(for record: WordImageRecord) -> URL? {
        cacheDirectory?.appendingPathComponent(record.fileName)
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let storeURL, let data = try? Data(contentsOf: storeURL),
              let file = try? JSONDecoder().decode(WordImageStoreFile.self, from: data) else { return }
        var map: [String: WordImageAssignment] = [:]
        for assignment in file.assignments {
            map[assignment.meaningId] = assignment
        }
        assignments = map
        blockedUntil = file.blockedUntil
    }

    private func persist() {
        guard let storeURL else { return }
        let file = WordImageStoreFile(
            assignments: assignments.values.sorted { $0.meaningId < $1.meaningId },
            blockedUntil: blockedUntil
        )
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storeURL, options: [.atomic])
    }
}
