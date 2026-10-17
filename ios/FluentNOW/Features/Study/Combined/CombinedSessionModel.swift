import Foundation
import Observation
import FluentKit

/// Model sesji łączonej (`state.combined`). Odpowiedź zapisujemy przy przejściu dalej:
/// `CombinedSessionBuilder.saveAnswer` + `advance` w jednym `store.update(.answer)` — dzięki temu
/// „Uznaj moją odpowiedź” (literówka) trafia do zapisu.
@MainActor
@Observable
final class CombinedSessionModel {
    let store: LearningStore
    private(set) var vocabulary: VocabExerciseModel?
    private(set) var question: CombinedQuestionModel?
    private(set) var missingTask = false
    private(set) var runReviewIDs: [String] = []

    private let content: ContentLibrary
    private let assistant: AssistantService
    /// Zdjęcia do zadań „Słowo i zdjęcie” (G2, practice-modes).
    private let images: WordImageService?
    @ObservationIgnored private var resources = StudyResources.fallback
    @ObservationIgnored private var resourcesLoaded = false
    @ObservationIgnored private var currentKey: String?
    @ObservationIgnored private var markedKeys: Set<String> = []

    init(store: LearningStore, content: ContentLibrary, assistant: AssistantService, images: WordImageService? = nil) {
        self.store = store
        self.content = content
        self.assistant = assistant
        self.images = images
    }

    var session: CombinedSession? { store.state.combined }
    var isCompleted: Bool { session?.completedAt != nil }

    /// Bieżące zadanie ma gotowy wynik (można przejść dalej).
    var canAdvance: Bool {
        if session?.currentAnswer != nil { return true }
        if let vocabulary { return vocabulary.outcome != nil }
        if let question { return question.isAnswered }
        return missingTask
    }

    func prepare() async {
        sync()
        guard !resourcesLoaded else { return }
        resources = await StudyResources.load(from: content)
        resourcesLoaded = true
        if let vocabulary, vocabulary.type == .meaning {
            vocabulary.replaceOptions(options(for: vocabulary.content))
        }
    }

    func sync() {
        guard let session, session.completedAt == nil, let task = session.currentTask else {
            clear()
            currentKey = nil
            return
        }
        let key = "\(session.id):\(session.index)"
        if key == currentKey { return }
        clear()
        currentKey = key
        let saved = session.currentAnswer
        switch task {
        case .vocabulary(let mode, let vocabTask):
            guard let content = VocabExerciseContent(task: vocabTask, mode: mode, state: store.state, variants: resources.variants) else {
                missingTask = true
                return
            }
            let created = VocabExerciseModel(
                content: content,
                key: key,
                options: vocabTask.type == .meaning ? options(for: content) : [],
                variants: resources.variants,
                assistant: assistant
            )
            vocabulary = created
            if vocabTask.type == .picture {
                loadPictures(for: created)
            }
        case .question(let questionTask):
            // Czytanka (G1): blok pytań jednego tekstu — tekst przed pierwszym, wyniki po ostatnim.
            let readingBlock = questionTask.reading == nil ? nil : CombinedReadingBlock.block(in: session, at: session.index)
            question = CombinedQuestionModel(
                task: questionTask,
                key: key,
                variants: resources.variants,
                saved: saved,
                readingBlock: readingBlock,
                readingEarlier: ReadingRecapItem.earlier(in: session, block: readingBlock)
            )
            markSeen(questionTask, key: key)
        }
    }

    /// Zapisuje odpowiedź (jeśli jeszcze nie zapisana) i przechodzi do następnego zadania.
    func advance() {
        guard let session, session.completedAt == nil else { return }
        let now = store.now()
        let answer = pendingAnswer()
        let reviewID = UUID().uuidString.lowercased()
        let isVocabulary = session.currentTask?.vocabularyTask != nil
        store.update(.answer) { (state: inout LearnerState) -> Void in
            if let answer, state.combined?.currentAnswer == nil {
                state = CombinedSessionBuilder.saveAnswer(state, answer: answer, now: now, reviewID: reviewID)
            }
            state = CombinedSessionBuilder.advance(state, now: now)
        }
        if answer != nil && isVocabulary {
            runReviewIDs.append(reviewID)
        }
        sync()
    }

    /// Ekran sesji znika (przerwa) — przerywa oczekiwanie na asystenta AI; stan sesji zostaje.
    func suspend() {
        vocabulary?.cancelPendingWork()
    }

    /// Kończy sesję po podsumowaniu (historia jest już zapisana przez `advance`).
    func finish() {
        clear()
        store.update(.session) { (state: inout LearnerState) -> Void in
            if state.combined?.completedAt != nil {
                state.combined = nil
            }
        }
    }

    func summary() -> StudySummaryData {
        guard let session else {
            return StudySummaryData(total: 0, correct: 0, seconds: 0, skills: [], grown: [], toReview: [], modeLines: [])
        }
        var seconds: Double = 0
        for answer in session.answers {
            if let answer, answer.seconds.isFinite {
                seconds += max(0, answer.seconds)
            }
        }
        let lines = session.modes.compactMap { mode -> StudySummaryData.ModeLine? in
            var total = 0
            var correct = 0
            for (index, task) in session.tasks.enumerated() where task.mode == mode {
                total += 1
                if let answer = session.answers.studyItem(at: index) ?? nil, answer.correct {
                    correct += 1
                }
            }
            return total > 0 ? StudySummaryData.ModeLine(mode: mode, correct: correct, total: total) : nil
        }
        return StudySummaryData.make(
            state: store.state,
            total: session.tasks.count,
            correct: session.correctCount,
            seconds: seconds,
            reviewIDs: runReviewIDs,
            modeLines: lines
        )
    }

    // MARK: Prywatne

    private func clear() {
        vocabulary?.cancelPendingWork()
        vocabulary = nil
        question = nil
        missingTask = false
    }

    private func pendingAnswer() -> CombinedAnswer? {
        let outcome: StudyAnswerOutcome?
        if let vocabulary {
            outcome = vocabulary.outcome
        } else if let question {
            outcome = question.outcome
        } else if missingTask {
            outcome = StudyAnswerOutcome(value: "", correct: false, hinted: false, spellingCorrect: false, seconds: 0.1, explanation: "Słowo nie jest już dostępne.")
        } else {
            outcome = nil
        }
        guard let outcome else { return nil }
        return CombinedAnswer(
            value: outcome.value,
            correct: outcome.correct,
            seconds: outcome.seconds,
            hinted: outcome.hinted,
            spellingCorrect: outcome.spellingCorrect,
            explanation: outcome.explanation
        )
    }

    /// Jak strona: zadanie z banku oznaczamy jako widziane przy wyświetleniu (raz).
    private func markSeen(_ task: CombinedQuestionTask, key: String) {
        guard let bankId = task.question.bankId, !bankId.isEmpty, !markedKeys.contains(key) else { return }
        markedKeys.insert(key)
        let now = store.now()
        let context = task.production?.context ?? task.question.context
        store.update(.edit) { state in
            state = GrammarSelector.markSeen(state, bankId: bankId, context: context, at: now)
        }
    }

    private func options(for content: VocabExerciseContent) -> [String] {
        MeaningOptions.options(
            state: store.state,
            word: content.word,
            meaning: content.meaning,
            task: content.task,
            starterWords: resources.starterWords,
            answerIndex: resources.answerIndex
        )
    }

    /// „Słowo i zdjęcie”: zdjęcia z dysku; bez nich (lub z VoiceOver) — „Wybierz znaczenie”.
    /// Zapis idzie przez zadanie z sesji (`saveAnswer`), więc umiejętność się nie zmienia.
    private func loadPictures(for created: VocabExerciseModel) {
        let state = store.state
        let images = images
        Task { @MainActor [weak self] in
            var loaded: [StudyPictureOption]?
            if let images, !StudyPictureAccessibility.prefersTextExercise {
                loaded = await StudyPictureLoader.options(for: created.content, key: created.key, state: state, images: images)
            }
            guard let self, self.vocabulary === created else { return }
            if let loaded {
                created.setPictures(loaded)
            } else if let fallback = created.content.asMeaningTask(state: self.store.state, variants: self.resources.variants) {
                self.vocabulary = VocabExerciseModel(
                    content: fallback,
                    key: created.key,
                    options: self.options(for: fallback),
                    variants: self.resources.variants,
                    assistant: self.assistant
                )
            }
        }
    }
}
