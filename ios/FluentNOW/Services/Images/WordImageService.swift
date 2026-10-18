import Foundation
import FluentKit

/// Photos for the „Słowo i zdjęcie” exercise (G2): internet only (Openverse), cached on disk,
/// one permanent photo per word meaning, downloaded in the background before sessions.
///
/// - assignments (meaning → chosen photo + remaining candidates + reported ones + verdicts):
///   `Application Support/WordImages/word-images.json` — survives cache purges, so the same photo
///   comes back at every review (re-downloaded from the same URL when the system cleared Caches);
/// - image files: `Caches/WordImages/<id>.jpg` (the system may purge them; nothing breaks);
/// - nothing here ever blocks the UI or a session: no network → no new photos, the exercise
///   simply is not drawn.
///
/// Verification (image-verify): a photo is shown only after it passed
/// 0. `WordImageEligibility` — the word can be photographed at all;
/// 1. `WordImageCandidateFilter` — title/tags name the word (sense-aware query, curated stock
///    sources first, drawings / brands / camera notes rejected);
/// 2. `WordImageVerifier` — Vision's on-device classifier sees the word or at least nothing that
///    contradicts it (an insect at „phone” is rejected).
/// Photos saved before this layer (or under older rules) are hidden until re-verified in the
/// background from the local file; the ones that fail are deleted.
///
/// Limits (FEEDBACK-3 H2): the anonymous Openverse API allows 20 searches per minute and 200 per
/// day, 1000 thumbnails per day. We keep below that: ≥ 3.5 s between searches (≤ 17/min),
/// ≤ `maxSearchesPerDay` searches and ≤ `maxDownloadsPerDay` downloads per local day (counters
/// stored with the assignments), and no searches until `Retry-After` after an HTTP 429.
/// Runs are started by `WordImagePrefetcher` (several short runs with pauses).
actor WordImageService {
    /// Minimum pause between two searches (anonymous Openverse limit is 20/min).
    static let defaultSearchInterval: TimeInterval = 3.5
    /// Searches per background run (one run ≈ 45 s).
    static let maxSearchesPerRun = 12
    /// Downloads per background run.
    static let maxDownloadsPerRun = 30
    /// Searches per day (anonymous limit is 200 — the rest is a safety margin).
    static let maxSearchesPerDay = 150
    /// Thumbnail downloads per day (anonymous limit is 1000).
    static let maxDownloadsPerDay = 600
    /// Photos checked (downloaded or local) for one meaning in one pass.
    static let maxChecksPerWord = 4
    /// Local files re-verified at the start of a run (no network, ~0.1 s each).
    static let maxLocalChecksPerRun = 40

    private let client: OpenverseClient?
    private let classifier: any WordImageClassifying
    private let storeURL: URL?
    private let cacheDirectory: URL?
    private let searchInterval: TimeInterval
    private var assignments: [String: WordImageAssignment] = [:]
    private var blockedUntil: Timestamp = 0
    private var counterDay = 0
    private var searchesToday = 0
    private var downloadsToday = 0
    private var lastRunAt: Timestamp = 0
    private var lastError: String?
    private var verificationRejections = 0
    private var loaded = false
    private var isPrefetching = false
    private var lastSearchAt: Date = .distantPast
    private var taxonomyCache: Set<String>?
    private var taxonomyLoaded = false

    /// - Parameters:
    ///   - networkEnabled: `false` in previews and tests (no requests at all).
    ///   - storeURL / cacheDirectory: `nil` → default locations; tests pass temporary folders.
    ///   - session: tests pass a session with a stub `URLProtocol`.
    ///   - searchInterval: pause between searches (tests use 0).
    ///   - classifier: `nil` → Vision; tests pass a stub.
    init(
        networkEnabled: Bool = true,
        storeURL: URL? = nil,
        cacheDirectory: URL? = nil,
        session: URLSession? = nil,
        searchInterval: TimeInterval = WordImageService.defaultSearchInterval,
        classifier: (any WordImageClassifying)? = nil
    ) {
        if networkEnabled {
            client = OpenverseClient(session: session ?? OpenverseClient.makeSession())
        } else {
            client = nil
        }
        self.classifier = classifier ?? VisionImageClassifier()
        self.storeURL = storeURL ?? WordImageService.defaultStoreURL()
        self.cacheDirectory = cacheDirectory ?? WordImageService.defaultCacheDirectory()
        self.searchInterval = max(0, searchInterval)
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

    /// `false` in previews and tests (no requests are ever made).
    var isNetworkEnabled: Bool { client != nil }

    /// Meanings whose chosen, verified photo is on disk right now (input of
    /// `PictureExercise.readyMeaningIDs`). Cheap: one file check per assignment.
    func cachedMeaningIDs() -> Set<String> {
        loadIfNeeded()
        var result = Set<String>()
        for (meaningID, assignment) in assignments where assignment.hasVerifiedChoice {
            guard let record = assignment.chosen, let url = fileURL(for: record) else { continue }
            if FileManager.default.fileExists(atPath: url.path) {
                result.insert(meaningID)
            }
        }
        return result
    }

    /// Meanings that need no background work now: verified photo on disk, or marked „bez
    /// zdjęcia”. Passed as `excluding:` to `PictureExercise.prefetchCandidates`.
    func settledMeaningIDs() -> Set<String> {
        var result = cachedMeaningIDs()
        for (meaningID, assignment) in assignments {
            if assignment.noPhotoReason != nil || (!needsNewSearch(assignment) && assignment.nextCandidate == nil) {
                result.insert(meaningID)
            }
        }
        return result
    }

    /// Meanings that never get a photo (excluded words, nothing verified after all attempts).
    func unavailableMeaningIDs() -> Set<String> {
        loadIfNeeded()
        var result = Set<String>()
        for (meaningID, assignment) in assignments where assignment.noPhotoReason != nil {
            result.insert(meaningID)
        }
        return result
    }

    /// The cached, verified photo of a meaning, or `nil` when it is not on disk.
    func image(for meaningID: String) -> WordImage? {
        loadIfNeeded()
        guard let assignment = assignments[meaningID], assignment.hasVerifiedChoice,
              let record = assignment.chosen, let url = fileURL(for: record),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return WordImage(meaningId: meaningID, record: record, fileURL: url, verification: assignment.verification(for: record.id))
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

    /// Numbers for „Ustawienia → Dane” (photos on disk, empty searches, verification, counters).
    func diagnostics() -> WordImageDiagnostics {
        let cached = cachedMeaningIDs()
        rollDailyCounters()
        var empty = 0
        var noPhoto = 0
        var awaiting = 0
        for (meaningID, assignment) in assignments where !cached.contains(meaningID) {
            if assignment.noPhotoReason != nil {
                noPhoto += 1
            } else if let record = assignment.chosen, !assignment.isVerified(record.id),
                      let url = fileURL(for: record), FileManager.default.fileExists(atPath: url.path) {
                awaiting += 1
            } else if assignment.nextCandidate == nil {
                empty += 1
            }
        }
        return WordImageDiagnostics(
            cachedCount: cached.count,
            emptyCount: empty,
            noPhotoCount: noPhoto,
            verificationRejections: verificationRejections,
            awaitingCheckCount: awaiting,
            searchesToday: searchesToday,
            downloadsToday: downloadsToday,
            lastRunAt: lastRunAt,
            lastError: lastError,
            blockedUntil: blockedUntil,
            networkEnabled: client != nil
        )
    }

    // MARK: Background download

    /// Downloads and verifies photos for the given candidates (in order) without ever blocking:
    /// sequential, throttled, stops at the first sign of being offline or rate-limited, and at
    /// the per-run and daily limits. Photos already on disk but not verified under the current
    /// rules are checked first (no network). A concurrent call returns `.busy` at once.
    /// Cancelling the calling task stops the run (the URL request is cancelled too).
    /// - Parameter contexts: topic and translation per meaning ID (sense of ambiguous words).
    @discardableResult
    func prefetch(_ candidates: [PictureCandidate], contexts: [String: WordImageContext] = [:]) async -> WordImagePrefetchReport {
        var report = WordImagePrefetchReport()
        guard let client else {
            report.stop = .disabled
            return report
        }
        guard !isPrefetching else {
            report.stop = .busy
            return report
        }
        loadIfNeeded()
        rollDailyCounters()
        isPrefetching = true
        defer { isPrefetching = false }
        var changed = false
        var searchLimitHit = false
        var problem: String?
        // Migration and rule changes: local files first, so wrong photos disappear even offline.
        let local = await verifyLocalPhotos(contexts: contexts, limit: Self.maxLocalChecksPerRun)
        report.checks += local.checks
        report.rejected += local.rejected
        if local.changed { changed = true }
        loop: for candidate in candidates {
            if Task.isCancelled {
                report.stop = .cancelled
                break loop
            }
            if report.downloads >= Self.maxDownloadsPerRun {
                report.stop = .runLimit
                break loop
            }
            if downloadsToday >= Self.maxDownloadsPerDay {
                report.stop = .dailyLimit
                break loop
            }
            let meaningID = candidate.meaningId
            let context = contexts[meaningID] ?? assignments[meaningID]?.context
            if markExcludedIfNeeded(candidate, context: context) {
                changed = true
                continue loop
            }
            if assignments[meaningID]?.noPhotoReason != nil { continue loop }
            let profile = WordImageTermProfile.make(term: candidate.term, context: context)
            do {
                if needsNewSearch(assignments[meaningID]) {
                    if FluentClock.now() < blockedUntil {
                        report.stop = .rateLimited
                        break loop
                    }
                    if searchesToday >= Self.maxSearchesPerDay {
                        report.stop = .dailyLimit
                        break loop
                    }
                    if report.searches >= Self.maxSearchesPerRun {
                        // Later candidates may only need a download (search made earlier).
                        searchLimitHit = true
                        continue loop
                    }
                    let attempt = assignments[meaningID]?.searchAttempts ?? 0
                    guard let plan = WordImageQueryPlanner.plan(attempt: attempt, profile: profile) else {
                        markNoPhoto(meaningID: meaningID, candidate: candidate, context: context, reason: Self.exhaustedReason(attempt))
                        changed = true
                        continue loop
                    }
                    await throttle()
                    if Task.isCancelled {
                        report.stop = .cancelled
                        break loop
                    }
                    report.searches += 1
                    searchesToday += 1
                    lastSearchAt = Date()
                    changed = true
                    let records = try await client.search(query: plan.query, sources: plan.sources)
                    let taxonomy = await loadTaxonomy()
                    let requireStrong = !WordImageVerifier.hasVisionEquivalent(profile, taxonomy: taxonomy)
                    let ranked = WordImageCandidateFilter.rank(records, profile: profile, requireStrong: requireStrong)
                    let previous = assignments[meaningID]
                    assignments[meaningID] = WordImageAssignment(
                        meaningId: meaningID,
                        wordId: candidate.wordId,
                        term: candidate.term,
                        query: plan.query,
                        candidates: ranked,
                        chosenID: nil,
                        rejectedIDs: previous?.rejectedIDs ?? [],
                        searchedAt: FluentClock.now(),
                        searchAttempts: attempt + 1,
                        verifications: previous?.verifications,
                        noPhotoReason: nil,
                        context: context
                    )
                } else if let context, var existing = assignments[meaningID], existing.context != context {
                    existing.context = context
                    assignments[meaningID] = existing
                    changed = true
                }
                let outcome = try await ensureVerifiedPhoto(meaningID: meaningID, profile: profile, client: client)
                report.downloads += outcome.downloads
                report.checks += outcome.checks
                report.rejected += outcome.rejected
                if outcome.changed { changed = true }
                if finalizeIfExhausted(meaningID: meaningID) { changed = true }
            } catch WordImageError.offline {
                report.stop = .offline
                problem = WordImageError.offline.errorDescription
                break loop
            } catch WordImageError.rateLimited(let retryAfter) {
                blockedUntil = FluentClock.now() + retryAfter * 1_000
                report.stop = .rateLimited
                problem = WordImageError.rateLimited(retryAfter: retryAfter).errorDescription
                changed = true
                break loop
            } catch is CancellationError {
                report.stop = .cancelled
                break loop
            } catch {
                // One bad result (broken file, HTTP error) — skip this word, keep going.
                problem = (error as? LocalizedError)?.errorDescription ?? "Nie udało się pobrać zdjęcia."
                continue loop
            }
        }
        if report.stop == .finished && searchLimitHit {
            report.stop = .runLimit
        }
        if report.stop == .dailyLimit && problem == nil {
            problem = "Dzienny limit pobierania zdjęć wykorzystany — dokończymy jutro."
        }
        if report.stop != .cancelled {
            lastRunAt = FluentClock.now()
            // A clean run clears the last problem; a run with progress but one broken word keeps it.
            if problem != nil || report.searches > 0 || report.downloads > 0 || report.stop == .finished {
                lastError = problem
            }
            changed = true
        }
        if changed { persist() }
        return report
    }

    // MARK: Reports

    /// „Zdjęcie nie pasuje”: the photo is never used again for this meaning; the next candidate
    /// (if any) is verified and downloaded in the background.
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
        let profile = WordImageTermProfile.make(term: assignment.term, context: assignment.context)
        if let outcome = try? await ensureVerifiedPhoto(meaningID: meaningID, profile: profile, client: client), outcome.changed {
            persist()
        }
    }

    /// Removes all photos and assignments („Usuń wszystkie dane”).
    func removeAll() {
        assignments = [:]
        blockedUntil = 0
        counterDay = 0
        searchesToday = 0
        downloadsToday = 0
        lastRunAt = 0
        lastError = nil
        verificationRejections = 0
        loaded = true
        if let cacheDirectory {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
        if let storeURL {
            try? FileManager.default.removeItem(at: storeURL)
        }
    }

    // MARK: Verification

    /// Result of checking the photos of one meaning.
    private struct PhotoOutcome {
        var downloads = 0
        var checks = 0
        var rejected = 0
        var changed = false
    }

    /// Makes sure the meaning has a verified photo on disk: verifies the chosen photo (local file
    /// or fresh download), moves on to the next candidate after a rejection (at most
    /// `maxChecksPerWord` photos per call). With `client == nil` only local files are checked.
    private func ensureVerifiedPhoto(meaningID: String, profile: WordImageTermProfile, client: OpenverseClient?) async throws -> PhotoOutcome {
        var outcome = PhotoOutcome()
        var attempts = 0
        while attempts < Self.maxChecksPerWord {
            attempts += 1
            guard var assignment = assignments[meaningID], assignment.noPhotoReason == nil else { return outcome }
            if assignment.chosen == nil || assignment.rejectedIDs.contains(assignment.chosenID ?? "") {
                let next = assignment.nextCandidate?.id
                if assignment.chosenID != next {
                    assignment.chosenID = next
                    assignments[meaningID] = assignment
                    outcome.changed = true
                }
            }
            guard let record = assignment.chosen, let url = fileURL(for: record) else { return outcome }
            let onDisk = FileManager.default.fileExists(atPath: url.path)
            if assignment.isVerified(record.id) {
                if onDisk { return outcome }
                // Verified earlier, file purged by the system: download again, no new check.
                guard let client, downloadsToday < Self.maxDownloadsPerDay else { return outcome }
                downloadsToday += 1
                outcome.downloads += 1
                outcome.changed = true
                do {
                    let data = try await client.downloadImage(from: record.thumbnailURL)
                    try writeImage(data, to: url)
                    return outcome
                } catch WordImageError.notAnImage {
                    markBroken(meaningID: meaningID, imageID: record.id)
                    continue
                } catch WordImageError.http(let code) where code == 404 || code == 410 || code == 424 {
                    markBroken(meaningID: meaningID, imageID: record.id)
                    continue
                }
            }
            let data: Data
            if onDisk {
                guard let local = try? Data(contentsOf: url) else {
                    try? FileManager.default.removeItem(at: url)
                    continue
                }
                data = local
            } else {
                guard let client, downloadsToday < Self.maxDownloadsPerDay else { return outcome }
                downloadsToday += 1
                outcome.downloads += 1
                outcome.changed = true
                do {
                    data = try await client.downloadImage(from: record.thumbnailURL)
                } catch WordImageError.notAnImage {
                    markBroken(meaningID: meaningID, imageID: record.id)
                    continue
                } catch WordImageError.http(let code) where code == 404 || code == 410 || code == 424 {
                    markBroken(meaningID: meaningID, imageID: record.id)
                    continue
                }
            }
            let verdict = await verify(data: data, record: record, profile: profile)
            outcome.checks += 1
            outcome.changed = true
            // Re-read after the suspension (a report may have changed the assignment meanwhile).
            guard var updated = assignments[meaningID] else { return outcome }
            updated.record(verdict)
            if verdict.accepted {
                assignments[meaningID] = updated
                if !onDisk {
                    try writeImage(data, to: url)
                }
                return outcome
            }
            if !updated.rejectedIDs.contains(record.id) {
                updated.rejectedIDs.append(record.id)
            }
            updated.chosenID = updated.nextCandidate?.id
            assignments[meaningID] = updated
            if onDisk {
                try? FileManager.default.removeItem(at: url)
            }
            verificationRejections += 1
            outcome.rejected += 1
        }
        return outcome
    }

    /// Layers 1 + 2 for one photo.
    private func verify(data: Data, record: WordImageRecord, profile: WordImageTermProfile) async -> WordImageVerification {
        let taxonomy = await loadTaxonomy()
        let labels = await classifier.labels(for: data)
        let metadata = WordImageMetadataMatcher.evaluate(record, profile: profile)
        let decision = WordImageVerifier.decide(profile: profile, metadata: metadata.match, labels: labels, taxonomy: taxonomy)
        return WordImageVerification(
            imageID: record.id,
            accepted: decision.accepted,
            code: decision.code,
            reason: decision.reason,
            labels: Array((labels ?? []).prefix(8)),
            metadataMatch: metadata.match.rawValue,
            usedVision: labels != nil,
            rulesVersion: WordImageVerifier.rulesVersion,
            checkedAt: FluentClock.now()
        )
    }

    /// Re-verifies photos already on disk whose verdict is missing or older than the current
    /// rules (photos saved before the verification layer). No network.
    private func verifyLocalPhotos(contexts: [String: WordImageContext], limit: Int) async -> PhotoOutcome {
        var total = PhotoOutcome()
        let pending = assignments.keys.sorted().filter { (meaningID: String) -> Bool in
            guard let assignment = assignments[meaningID], assignment.noPhotoReason == nil,
                  let record = assignment.chosen, !assignment.isVerified(record.id),
                  let url = fileURL(for: record) else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }
        for meaningID in pending where total.checks < limit {
            if Task.isCancelled { break }
            guard let assignment = assignments[meaningID] else { continue }
            let context = contexts[meaningID] ?? assignment.context
            let candidate = PictureCandidate(wordId: assignment.wordId, meaningId: meaningID, term: assignment.term, query: assignment.query)
            if markExcludedIfNeeded(candidate, context: context) {
                total.changed = true
                continue
            }
            let profile = WordImageTermProfile.make(term: assignment.term, context: context)
            if let outcome = try? await ensureVerifiedPhoto(meaningID: meaningID, profile: profile, client: nil) {
                total.checks += outcome.checks
                total.rejected += outcome.rejected
                if outcome.changed { total.changed = true }
            }
        }
        return total
    }

    /// Vision's identifiers, read once per launch.
    private func loadTaxonomy() async -> Set<String>? {
        if taxonomyLoaded { return taxonomyCache }
        let value = await classifier.taxonomy()
        taxonomyCache = value
        taxonomyLoaded = true
        return value
    }

    // MARK: Private

    /// Excluded word (`WordImageEligibility` or a sense that cannot be photographed) → „bez
    /// zdjęcia” for good, file removed. Returns `true` when the assignment changed.
    private func markExcludedIfNeeded(_ candidate: PictureCandidate, context: WordImageContext?) -> Bool {
        guard assignments[candidate.meaningId]?.noPhotoReason == nil else { return false }
        let profile = WordImageTermProfile.make(term: candidate.term, context: context)
        guard let reason = WordImageEligibility.exclusionReason(term: candidate.term) ?? profile.excludedReason else { return false }
        markNoPhoto(meaningID: candidate.meaningId, candidate: candidate, context: context, reason: reason)
        return true
    }

    private func markNoPhoto(meaningID: String, candidate: PictureCandidate, context: WordImageContext?, reason: String) {
        var assignment = assignments[meaningID] ?? WordImageAssignment(
            meaningId: meaningID,
            wordId: candidate.wordId,
            term: candidate.term,
            query: candidate.query,
            candidates: [],
            chosenID: nil,
            rejectedIDs: [],
            searchedAt: FluentClock.now()
        )
        if let record = assignment.chosen, let url = fileURL(for: record) {
            try? FileManager.default.removeItem(at: url)
        }
        assignment.chosenID = nil
        assignment.noPhotoReason = reason
        if let context { assignment.context = context }
        assignments[meaningID] = assignment
    }

    /// Every candidate rejected and every search attempt used → „bez zdjęcia” for good.
    private func finalizeIfExhausted(meaningID: String) -> Bool {
        guard let assignment = assignments[meaningID], assignment.noPhotoReason == nil,
              assignment.nextCandidate == nil else { return false }
        let attempts = assignment.searchAttempts ?? 0
        guard attempts >= WordImageQueryPlanner.maxAttempts || isLastPlannedAttempt(assignment) else { return false }
        var updated = assignment
        updated.noPhotoReason = Self.exhaustedReason(attempts)
        updated.chosenID = nil
        assignments[meaningID] = updated
        return true
    }

    /// `true` when no further query is planned for this assignment (e.g. no synonym for attempt 3).
    private func isLastPlannedAttempt(_ assignment: WordImageAssignment) -> Bool {
        let profile = WordImageTermProfile.make(term: assignment.term, context: assignment.context)
        return WordImageQueryPlanner.plan(attempt: assignment.searchAttempts ?? 0, profile: profile) == nil
    }

    static func exhaustedReason(_ attempts: Int) -> String {
        "Brak zweryfikowanego zdjęcia po \(attempts) wyszukiwaniach."
    }

    /// No usable candidate and another search attempt is still planned.
    private func needsNewSearch(_ assignment: WordImageAssignment?) -> Bool {
        guard let assignment else { return true }
        if assignment.noPhotoReason != nil { return false }
        if assignment.nextCandidate != nil { return false }
        return (assignment.searchAttempts ?? 0) < WordImageQueryPlanner.maxAttempts
    }

    /// New local day → counters start from zero.
    private func rollDailyCounters() {
        let today = Int((FluentClock.now() / TimeConstants.dayMs).rounded(.down))
        guard today != counterDay else { return }
        counterDay = today
        searchesToday = 0
        downloadsToday = 0
    }

    /// Waits so that searches keep the anonymous rate limit.
    private func throttle() async {
        let elapsed = Date().timeIntervalSince(lastSearchAt)
        guard elapsed < searchInterval else { return }
        let wait = searchInterval - elapsed
        try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
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
        counterDay = file.counterDay
        searchesToday = file.searchesToday
        downloadsToday = file.downloadsToday
        lastRunAt = file.lastRunAt
        lastError = file.lastError
        verificationRejections = file.verificationRejections
    }

    private func persist() {
        guard let storeURL else { return }
        let file = WordImageStoreFile(
            assignments: assignments.values.sorted { $0.meaningId < $1.meaningId },
            blockedUntil: blockedUntil,
            counterDay: counterDay,
            searchesToday: searchesToday,
            downloadsToday: downloadsToday,
            lastRunAt: lastRunAt,
            lastError: lastError,
            verificationRejections: verificationRejections
        )
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storeURL, options: [.atomic])
    }
}
