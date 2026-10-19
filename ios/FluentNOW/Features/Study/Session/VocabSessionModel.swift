import Foundation
import Observation
import FluentKit

/// Model sesji słownictwa: prowadzi `state.session` przez `LearningStore`.
/// Każda odpowiedź = `Scheduler.recordAnswer` w `store.update(.answer)` (zapis natychmiastowy),
/// więc przerwana sesja wznawia się sama po ponownym otwarciu aplikacji.
@MainActor
@Observable
final class VocabSessionModel {
    let store: LearningStore
    private(set) var exercise: VocabExerciseModel?
    /// Zadanie wskazuje słowo, którego już nie ma (usunięte na innym urządzeniu).
    private(set) var missingTask = false
    var confidence: ConfidenceLevel = .fair
    /// Identyfikatory recenzji zapisanych w tym uruchomieniu (podsumowanie).
    private(set) var runReviewIDs: [String] = []
    private(set) var runSeconds: Double = 0

    private let content: ContentLibrary
    private let assistant: AssistantService
    private let images: WordImageService?
    @ObservationIgnored private var resources = StudyResources.fallback
    @ObservationIgnored private var resourcesLoaded = false
    @ObservationIgnored private var optionCache: [String: [String]] = [:]

    init(store: LearningStore, content: ContentLibrary, assistant: AssistantService, images: WordImageService? = nil) {
        self.store = store
        self.content = content
        self.assistant = assistant
        self.images = images
    }

    var session: VocabSession? { store.state.session }
    var isFinished: Bool { session?.isFinished ?? false }
    var mode: StudyMode { session?.studyMode ?? .mixed }
    /// Typ sesji „Ćwicz wybrany typ” (J1); `nil` dla zwykłych sesji.
    var singleType: ExerciseType? { session.flatMap { SingleTypeSession.type(ofMode: $0.mode) } }
    /// Tytuł nagłówka sesji.
    var headerTitle: String { singleType?.practiceTitle ?? "Twój mały krok" }

    /// Wczytuje zasoby oceniania i ustawia bieżące zadanie.
    func prepare() async {
        sync()
        guard !resourcesLoaded else { return }
        resources = await StudyResources.load(from: content)
        resourcesLoaded = true
        optionCache.removeAll()
        if let exercise, exercise.type == .meaning {
            exercise.replaceOptions(options(for: exercise.content))
        }
    }

    /// Dopasowuje model zadania do `session.index` (po zapisie lub zmianie z innego urządzenia).
    func sync() {
        guard let session, let task = session.currentTask else {
            exercise?.cancelPendingWork()
            exercise = nil
            missingTask = false
            return
        }
        let key = VocabExerciseContent.key(index: session.index, task: task)
        // Słowo/znaczenie usunięte w trakcie zadania (Słownik, inne urządzenie) — zamiast odpowiadać
        // na nieistniejące zadanie pokaż kartę „Pomiń zadanie”.
        if store.state.word(id: task.wordId)?.meaning(id: task.meaningId) == nil {
            exercise?.cancelPendingWork()
            exercise = nil
            missingTask = true
            return
        }
        if exercise?.key == key { return }
        exercise?.cancelPendingWork()
        guard let base = VocabExerciseContent(task: task, mode: session.studyMode, state: store.state, variants: resources.variants) else {
            exercise = nil
            missingTask = true
            return
        }
        // Rozsypanka / pary / słuchanie, których nie da się pokazać → zadanie zastępcze (I2).
        let content = base.displayFallback(state: store.state, variants: resources.variants) ?? base
        missingTask = false
        confidence = .fair
        let created = VocabExerciseModel(
            content: content,
            key: key,
            options: content.type == .meaning ? options(for: content) : [],
            variants: resources.variants,
            assistant: assistant
        )
        exercise = created
        if content.type == .picture {
            loadPictures(for: created)
        }
        preloadNext(after: session)
    }

    /// „Słowo i zdjęcie”: zdjęcia z dysku (bez sieci). Gdy ich nie ma (wyczyszczony cache) albo
    /// działa VoiceOver — to samo zadanie jako „Wybierz znaczenie” (ta sama umiejętność).
    private func loadPictures(for created: VocabExerciseModel) {
        let state = store.state
        let images = images
        Task { @MainActor [weak self] in
            var loaded: [StudyPictureOption]?
            // „W budowie” (I2): stare przerwane zadania zdjęciowe idą jako „Wybierz znaczenie”.
            if let images, PictureExercise.isEnabled, !StudyPictureAccessibility.prefersTextExercise {
                loaded = await StudyPictureLoader.options(for: created.content, key: created.key, state: state, images: images)
            }
            guard let self, self.exercise === created else { return }
            if let loaded {
                created.setPictures(loaded)
            } else {
                self.replaceWithMeaning(created)
            }
        }
    }

    private func replaceWithMeaning(_ current: VocabExerciseModel) {
        guard let fallback = current.content.asMeaningTask(state: store.state, variants: resources.variants) else { return }
        exercise = VocabExerciseModel(
            content: fallback,
            key: current.key,
            options: options(for: fallback),
            variants: resources.variants,
            assistant: assistant
        )
    }

    /// Zapisuje wynik bieżącego zadania i przechodzi dalej.
    func commit() {
        guard let exercise, let outcome = exercise.outcome else { return }
        let reviewID = UUID().uuidString.lowercased()
        let now = store.now()
        let task = exercise.content.task
        let confidenceValue = confidence.rawValue
        let expectedIndex = session?.index
        // „Dopasuj pary” (I2): każde znaczenie planszy dostaje własną recenzję.
        let pairResults = task.type == .matchPairs ? exercise.pairResults : []
        store.update(.answer) { (state: inout LearnerState) -> Void in
            let tasksBefore = state.session?.tasks.count ?? 0
            if !pairResults.isEmpty {
                state = MatchPairsExercise.record(
                    state,
                    task: task,
                    results: pairResults,
                    seconds: outcome.seconds,
                    confidence: confidenceValue,
                    now: now,
                    reviewID: reviewID
                )
            } else {
                state = Scheduler.recordAnswer(
                    state,
                    task: task,
                    correct: outcome.correct,
                    seconds: outcome.seconds,
                    confidence: confidenceValue,
                    hint: outcome.hinted,
                    spellingCorrect: outcome.spellingCorrect,
                    now: now,
                    reviewID: reviewID
                )
            }
            // „Ćwicz wybrany typ” (J1): powtórka błędnego zadania zostaje w wybranym typie.
            state = SingleTypeSession.alignRetries(state, from: tasksBefore)
            // `recordAnswer` nie zmienia stanu, gdy słowa/znaczenia już nie ma (usunięte w międzyczasie) —
            // wtedy sesja nie przesunęłaby się dalej i ekran by utknął. Przesuwamy indeks sami.
            if let expectedIndex, var current = state.session, current.index == expectedIndex,
               current.index < current.tasks.count {
                current.index += 1
                state.session = current
            }
        }
        if pairResults.isEmpty {
            runReviewIDs.append(reviewID)
        } else {
            runReviewIDs.append(contentsOf: MatchPairsExercise.reviewIDs(base: reviewID, count: pairResults.count))
        }
        runSeconds += outcome.seconds
        sync()
    }

    /// Pomija zadanie ze słowem, którego już nie ma.
    func skipMissing() {
        store.update(.session) { (state: inout LearnerState) -> Void in
            // Pomijamy tylko zadanie, którego słowa naprawdę nie ma (podwójne dotknięcie nie pominie
            // kolejnego, poprawnego zadania).
            guard var session = state.session, let task = session.currentTask,
                  state.word(id: task.wordId)?.meaning(id: task.meaningId) == nil else { return }
            session.index += 1
            state.session = session
        }
        sync()
    }

    /// „Jeszcze 5 minut” — nowa krótka sesja w tym samym trybie. Zwraca komunikat, gdy nie ma zadań.
    func extend() async -> String? {
        let currentMode = mode
        let outcome: StudyStarter.Outcome
        if let type = singleType {
            // „Ćwicz wybrany typ” (J1): kolejne 5 minut tym samym typem.
            outcome = await StudyStarter.startSingleType(type, minutes: 5, collection: nil, store: store)
        } else {
            outcome = await StudyStarter.startVocabulary(mode: currentMode, minutes: 5, collection: nil, store: store, images: images)
        }
        switch outcome {
        case .message(let text):
            return text
        default:
            runReviewIDs = []
            runSeconds = 0
            sync()
            return nil
        }
    }

    /// Ekran sesji znika (przerwa) — przerywa oczekiwanie na asystenta AI; stan sesji zostaje.
    func suspend() {
        exercise?.cancelPendingWork()
    }

    /// Kończy sesję (czyści `state.session`).
    func finish() {
        exercise?.cancelPendingWork()
        store.update(.session) { state in
            state.session = nil
        }
    }

    /// Dane podsumowania (liczone z recenzji zapisanych w tym uruchomieniu).
    func summary() -> StudySummaryData {
        let total = session?.tasks.count ?? 0
        let correct = session?.correct ?? 0
        return StudySummaryData.make(
            state: store.state,
            total: total,
            correct: correct,
            seconds: runSeconds,
            reviewIDs: runReviewIDs,
            modeLines: []
        )
    }

    // MARK: Prywatne

    private func options(for content: VocabExerciseContent) -> [String] {
        let cacheKey = "\(content.meaning.id):\(content.task.example)"
        if let cached = optionCache[cacheKey] { return cached }
        let computed = MeaningOptions.options(
            state: store.state,
            word: content.word,
            meaning: content.meaning,
            task: content.task,
            starterWords: resources.starterWords,
            answerIndex: resources.answerIndex
        )
        optionCache[cacheKey] = computed
        return computed
    }

    /// Następne zadanie „znaczenia” liczy dystraktory zawczasu (bez opóźnienia przy przejściu).
    private func preloadNext(after session: VocabSession) {
        guard let next = session.tasks.studyItem(at: session.index + 1), next.type == .meaning else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, let content = VocabExerciseContent(task: next, mode: session.studyMode, state: self.store.state, variants: self.resources.variants) else { return }
            _ = self.options(for: content)
        }
    }
}
