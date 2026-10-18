import Foundation
import Observation
import UIKit
import FluentKit

/// Keeps the photo cache of „Słowo i zdjęcie” filled in the background (FEEDBACK-3 H2).
///
/// - started after the first frame (`AppEnvironment.onAppear` → `prefetchWordImages()`, plus a
///   short delay), on the study screen, before every study session, and whenever words are added
///   (observes the number of words in `LearningStore.state`);
/// - several short runs of `WordImageService.prefetch` with pauses between them: a run makes at
///   most 12 searches ≥ 3.5 s apart (≤ 17/min), then waits 30 s — the anonymous Openverse limit
///   of 20 searches per minute is never reached; the daily limits live in the service;
/// - stops at once when the app goes to the background (the running request is cancelled) and
///   resumes when it comes back;
/// - never blocks the UI: candidates are computed with `store.compute` (off the main thread),
///   network and files are handled by the `WordImageService` actor.
@MainActor
@Observable
final class WordImagePrefetcher {
    enum Status: Equatable {
        /// Nothing to do (or not started yet).
        case idle
        /// Downloading (or pausing between two runs).
        case working
        /// No internet connection — retried at the next trigger.
        case offline
        /// Openverse asked to slow down or the daily limit is used up.
        case waiting
        /// No network service (previews, tests).
        case disabled
    }

    private(set) var status: Status = .idle
    /// Meanings whose photo is on disk (after the last run).
    private(set) var cachedCount = 0
    /// How the last run ended (diagnostics).
    private(set) var lastStop: WordImagePrefetchReport.Stop?

    /// Delay before the first run of a request (the first frame and the start-up work go first).
    static let startDelayNanoseconds: UInt64 = 2_000_000_000
    /// Pause between two runs of one request (keeps searches well below 20 per minute).
    static let pauseNanoseconds: UInt64 = 30_000_000_000
    /// Pause when another run of the service is still in progress.
    static let busyPauseNanoseconds: UInt64 = 10_000_000_000
    /// Candidates handed to one run (the service makes at most 12 searches per run).
    static let candidatesPerRun = 24
    /// Runs per request (≈ 100 searches) — the next trigger continues.
    static let maxRunsPerRequest = 8

    private let store: LearningStore
    private let images: WordImageService
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var rerunRequested = false
    @ObservationIgnored private var isInBackground = false
    @ObservationIgnored private var isObserving = false
    @ObservationIgnored private var lastWordCount = -1
    @ObservationIgnored private var notificationTokens: [NSObjectProtocol] = []

    /// One prefetcher per photo service (the app has one).
    private static var registry: [ObjectIdentifier: WordImagePrefetcher] = [:]

    static func shared(store: LearningStore, images: WordImageService) -> WordImagePrefetcher {
        let key = ObjectIdentifier(images)
        if let existing = registry[key] {
            return existing
        }
        let created = WordImagePrefetcher(store: store, images: images)
        registry[key] = created
        return created
    }

    private init(store: LearningStore, images: WordImageService) {
        self.store = store
        self.images = images
    }

    var isWorking: Bool { status == .working }

    /// Polish one-line status for the study screen and the settings diagnostics.
    var statusText: String {
        switch status {
        case .idle: return ""
        case .working: return "Pobieram zdjęcia w tle…"
        case .offline: return "Brak internetu — zdjęcia pobiorą się, gdy wrócisz online."
        case .waiting: return "Serwis zdjęć prosi o przerwę — dokończymy później."
        case .disabled: return "Pobieranie zdjęć jest wyłączone."
        }
    }

    // MARK: Triggers

    /// Starts (or continues) background downloading. Cheap and safe to call often: a request
    /// during a run only marks that another pass is needed.
    func request() {
        // „Słowo i zdjęcie” jest „W budowie” (FEEDBACK-4 I2): żadnych zapytań do Openverse.
        // Powrót: `PictureExercise.isEnabled = true` (FluentKit).
        guard PictureExercise.isEnabled else {
            status = .disabled
            return
        }
        startObservingIfNeeded()
        guard !isInBackground else { return }
        if task != nil {
            rerunRequested = true
            return
        }
        rerunRequested = false
        task = Task(priority: .utility) { [weak self] in
            await self?.runLoop()
        }
    }

    /// Stops the current run (app in the background). `request()` starts again.
    func stop() {
        task?.cancel()
    }

    /// Refreshes `cachedCount` without downloading anything.
    func refreshCount() async {
        cachedCount = await images.cachedMeaningIDs().count
    }

    // MARK: Loop

    private func runLoop() async {
        try? await Task.sleep(nanoseconds: Self.startDelayNanoseconds)
        var runs = 0
        while !Task.isCancelled && runs < Self.maxRunsPerRequest {
            rerunRequested = false
            guard store.loadPhase == .ready else { break }
            let settled = await images.settledMeaningIDs()
            let limit = Self.candidatesPerRun
            let batch = await store.compute { (state: LearnerState) -> WordImagePrefetchBatch in
                WordImagePrefetchBatch.make(state: state, excluding: settled, limit: limit)
            }
            let candidates = batch.candidates
            guard !candidates.isEmpty, !Task.isCancelled else {
                status = .idle
                break
            }
            status = .working
            let report = await images.prefetch(candidates, contexts: batch.contexts)
            runs += 1
            lastStop = report.stop
            await refreshCount()
            status = Self.statusAfter(report.stop)
            guard let pause = Self.pause(after: report, candidateCount: candidates.count, limit: limit, rerun: rerunRequested) else {
                break
            }
            status = .working
            try? await Task.sleep(nanoseconds: pause)
        }
        if status == .working {
            status = .idle
        }
        task = nil
        // A request that arrived after the last check (e.g. words added just now) gets its run.
        if rerunRequested && !isInBackground {
            request()
        }
    }

    /// Status shown after a run.
    static func statusAfter(_ stop: WordImagePrefetchReport.Stop) -> Status {
        switch stop {
        case .finished, .runLimit, .busy, .cancelled: return .working
        case .offline: return .offline
        case .rateLimited, .dailyLimit: return .waiting
        case .disabled: return .disabled
        }
    }

    /// Pause before the next run, or `nil` to stop: continue only while there is progress and
    /// more work (the per-run limit was hit, the list was cut at `limit`, or words were added).
    static func pause(after report: WordImagePrefetchReport, candidateCount: Int, limit: Int, rerun: Bool) -> UInt64? {
        switch report.stop {
        case .busy:
            return busyPauseNanoseconds
        case .offline, .rateLimited, .dailyLimit, .cancelled, .disabled:
            return nil
        case .finished, .runLimit:
            // No search, no download and no verification — nothing more can be done now (broken
            // results wait for the next trigger instead of looping).
            guard report.searches > 0 || report.downloads > 0 || report.checks > 0 else { return nil }
            if report.stop == .runLimit || candidateCount >= limit || rerun {
                return pauseNanoseconds
            }
            return nil
        }
    }

    // MARK: Observation

    private func startObservingIfNeeded() {
        guard !isObserving else { return }
        isObserving = true
        lastWordCount = store.state.words.count
        observeWords()
        let center = NotificationCenter.default
        let background = center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] (_: Notification) in
            Task { @MainActor [weak self] in
                self?.enteredBackground()
            }
        }
        let foreground = center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] (_: Notification) in
            Task { @MainActor [weak self] in
                self?.enteredForeground()
            }
        }
        notificationTokens = [background, foreground]
    }

    private func enteredBackground() {
        isInBackground = true
        stop()
    }

    private func enteredForeground() {
        isInBackground = false
        request()
    }

    /// Re-registers after every change of the state (Observation fires once per registration).
    private func observeWords() {
        withObservationTracking {
            _ = store.state.words.count
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.wordsMayHaveChanged()
            }
        }
    }

    private func wordsMayHaveChanged() {
        observeWords()
        let count = store.state.words.count
        guard count != lastWordCount else { return }
        let added = count > lastWordCount
        lastWordCount = count
        if added {
            request()
        }
    }
}

/// Candidates of one background run plus the context (topic, translation) of each meaning —
/// computed together on a state snapshot off the main thread (`LearningStore.compute`).
struct WordImagePrefetchBatch: Sendable {
    var candidates: [PictureCandidate]
    var contexts: [String: WordImageContext]

    static func make(state: LearnerState, excluding: Set<String>, limit: Int) -> WordImagePrefetchBatch {
        let candidates = PictureExercise.prefetchCandidates(state: state, excluding: excluding, limit: limit)
        let wanted = Set(candidates.map { (candidate: PictureCandidate) -> String in candidate.meaningId })
        var contexts: [String: WordImageContext] = [:]
        if !wanted.isEmpty {
            for word in state.words {
                for meaning in word.meanings where wanted.contains(meaning.id) {
                    contexts[meaning.id] = WordImageContext(meaning: meaning)
                }
            }
        }
        return WordImagePrefetchBatch(candidates: candidates, contexts: contexts)
    }
}
