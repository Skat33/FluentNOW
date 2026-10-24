import Foundation
import Observation
import FluentKit

/// Etap ekranu testu.
enum TestScreenPhase: Equatable {
    /// Budowanie nowego testu (treść z pakietu, FluentKit poza głównym wątkiem).
    case preparing
    /// Pytania.
    case running
    /// Wynik ukończonego testu.
    case result
    /// Nie da się zbudować testu (komunikat).
    case unavailable(String)
}

/// Model ekranu testu (`state.assessment`). Każda odpowiedź od razu trafia do stanu przez
/// `AssessmentEngine.answer` w `store.update(.answer)` — przerwany test wznawia się od bieżącego
/// pytania (bez cofania), także na innym urządzeniu.
@MainActor
@Observable
final class TestSessionModel {
    let store: LearningStore
    private(set) var phase: TestScreenPhase = .preparing
    private(set) var vocabulary: VocabExerciseModel?
    private(set) var question: TestQuestionModel?
    /// Słowo bieżącego pytania usunięto w międzyczasie (pytanie zostanie pominięte).
    private(set) var missingQuestion = false
    /// Czytanka: najpierw sam tekst (przed pierwszym pytaniem do niego).
    private(set) var showsReadingPassage = false
    /// Chwila pokazania bieżącego pytania (zegar testu i czas na ekranie).
    private(set) var shownAt = Date()
    /// Wynik akcji po teście („Dodano 3 słowa…”).
    private(set) var actionNotice: String?
    private(set) var isAddingWords = false
    private(set) var markedWrongWords = false
    private(set) var addedNewWords = false

    private let content: ContentLibrary
    @ObservationIgnored private var resources = StudyResources.fallback
    @ObservationIgnored private var resourcesLoaded = false
    @ObservationIgnored private var currentKey: String?
    @ObservationIgnored private var cachedResult: (id: String, result: AssessmentResult)?

    init(store: LearningStore, content: ContentLibrary) {
        self.store = store
        self.content = content
    }

    var session: AssessmentSession? { store.state.assessment }

    // MARK: Start

    /// Wczytuje zasoby oceniania; bez zapisanego testu buduje nowy.
    func prepare() async {
        if store.state.assessment == nil {
            phase = .preparing
            let built = await TestLoader.makeSession(store: store, content: content)
            switch built {
            case .success(let created):
                store.update(.session) { (state: inout LearnerState) -> Void in
                    if state.assessment == nil {
                        state.assessment = created
                    }
                }
            case .failure:
                phase = .unavailable("Brakuje treści, żeby ułożyć test na Twoim poziomie. Dodaj kilka słów albo temat i spróbuj ponownie.")
                return
            }
        }
        sync()
        guard !resourcesLoaded else { return }
        resources = await StudyResources.load(from: content)
        resourcesLoaded = true
        if let vocabulary, vocabulary.type == .meaning {
            vocabulary.replaceOptions(options(for: vocabulary.content))
        }
    }

    /// Dopasowuje ekran do `state.assessment` (po zapisie albo zmianie z innego urządzenia).
    func sync() {
        guard let session = store.state.assessment else {
            clear()
            currentKey = nil
            // Test porzucony lub zamknięty (np. na innym urządzeniu) w trakcie pokazywania.
            if phase == .running || phase == .result {
                phase = .unavailable("Test został zakończony lub porzucony.")
            }
            return
        }
        if session.completedAt != nil {
            clear()
            currentKey = nil
            phase = .result
            return
        }
        phase = .running
        guard let current = session.currentQuestion else {
            clear()
            currentKey = nil
            return
        }
        let key = "\(session.id):\(session.index)"
        if key == currentKey { return }
        clear()
        currentKey = key
        shownAt = Date()
        switch current {
        case .vocabulary(let item):
            makeVocabulary(item, key: key, session: session)
        case .text(let item):
            question = TestQuestionModel(task: item, key: key)
            showsReadingPassage = session.opensReading
        }
    }

    private func makeVocabulary(_ item: AssessmentVocabQuestion, key: String, session: AssessmentSession) {
        let working = AssessmentEngine.workingState(store.state, session: session)
        guard let base = VocabExerciseContent(task: item.task, mode: .mixed, state: working, variants: resources.variants) else {
            missingQuestion = true
            return
        }
        // Plansza / rozsypanka / słuchanie, których nie da się pokazać → zadanie zastępcze.
        let shown = base.displayFallback(state: working, variants: resources.variants) ?? base
        vocabulary = VocabExerciseModel(
            content: shown,
            key: key,
            options: shown.type == .meaning ? options(for: shown) : [],
            variants: resources.variants,
            assistant: nil,
            assessment: true
        )
    }

    // MARK: Odpowiedzi

    /// „Dalej” jest aktywne.
    var canAdvance: Bool {
        if missingQuestion { return true }
        if let vocabulary { return vocabulary.assessmentReady || vocabulary.isFinished }
        if let question { return question.isReady }
        return false
    }

    /// „Dalej”: ocena (jedna próba, bez wyniku na ekranie) i od razu następne pytanie.
    func advance() {
        if let vocabulary, !vocabulary.isFinished {
            vocabulary.submitAssessment()
        }
        if let question, !question.isAnswered {
            question.submit()
        }
        commit()
    }

    /// „Nie wiem”: odpowiedź błędna i następne pytanie.
    func giveUp() {
        vocabulary?.giveUpAssessment()
        question?.giveUp()
        commit()
    }

    /// Zadanie skończyło się samo (Enter w polu, ostatnia para na planszy) — zapis i dalej.
    func commitIfFinished() {
        guard let vocabulary, vocabulary.isFinished, vocabulary.key == currentKey else { return }
        commit()
    }

    /// Czytanka: koniec etapu tekstu.
    func beginReadingQuestions() {
        guard showsReadingPassage else { return }
        showsReadingPassage = false
        question?.restartClock()
    }

    private func commit() {
        guard let session = store.state.assessment, session.completedAt == nil else { return }
        let expectedIndex = session.index
        let now: Timestamp = store.now()
        let elapsed = max(0, Date().timeIntervalSince(shownAt))
        if missingQuestion {
            store.update(.answer) { (state: inout LearnerState) -> Void in
                guard state.assessment?.index == expectedIndex else { return }
                state = AssessmentEngine.skipCurrent(state, now: now)
            }
            sync()
            return
        }
        guard let response = pendingResponse(session: session, elapsed: elapsed) else { return }
        let reviewID = UUID().uuidString.lowercased()
        store.update(.answer) { (state: inout LearnerState) -> Void in
            // Podwójne dotknięcie nie zapisze odpowiedzi do następnego pytania.
            guard state.assessment?.index == expectedIndex else { return }
            state = AssessmentEngine.answer(state, response: response, now: now, reviewID: reviewID)
        }
        sync()
    }

    private func pendingResponse(session: AssessmentSession, elapsed: Double) -> AssessmentResponse? {
        if let vocabulary, let outcome = vocabulary.outcome {
            let planned = session.currentQuestion?.vocabulary?.task.type
            let shownType = vocabulary.content.task.type
            return AssessmentResponse(
                value: outcome.value,
                correct: outcome.correct,
                spellingCorrect: outcome.spellingCorrect,
                seconds: outcome.seconds,
                elapsedSeconds: elapsed,
                shownType: shownType == planned ? nil : shownType,
                pairResults: shownType == .matchPairs ? vocabulary.pairResults : []
            )
        }
        if let question, let outcome = question.outcome {
            return AssessmentResponse(
                value: outcome.value,
                correct: outcome.correct,
                spellingCorrect: true,
                seconds: outcome.seconds,
                elapsedSeconds: elapsed
            )
        }
        return nil
    }

    // MARK: Wyjście i wynik

    /// „Porzuć test” (odpowiedzi już udzielone zostają w historii powtórek).
    func abandon() {
        clear()
        store.update(.session) { (state: inout LearnerState) -> Void in
            state = AssessmentEngine.abandon(state)
        }
    }

    /// Zamknięcie wyniku (wpis w historii testów zostaje).
    func dismissResult() {
        store.update(.session) { (state: inout LearnerState) -> Void in
            state = AssessmentEngine.dismissResult(state)
        }
    }

    /// Ekran znika — nic do przerwania (ocena lokalna, bez asystenta AI).
    func suspend() {
        vocabulary?.cancelPendingWork()
    }

    /// Wynik ukończonego testu (liczony raz).
    var result: AssessmentResult? {
        guard let session, session.completedAt != nil else { return nil }
        if let cachedResult, cachedResult.id == session.id { return cachedResult.result }
        let computed = AssessmentScoring.result(session)
        cachedResult = (session.id, computed)
        return computed
    }

    /// Słowa z bazy z błędną odpowiedzią, których jeszcze nie ma w słowniku.
    var newWordReferences: [String] {
        guard let session else { return [] }
        let owned = OwnedVocabulary(store.state)
        return AssessmentScoring.wrongBankReferences(session).filter { (reference: String) -> Bool in
            !owned.references.contains(reference)
        }
    }

    /// Własne słowa z błędną odpowiedzią.
    var wrongOwnedCount: Int {
        guard let session else { return 0 }
        return AssessmentScoring.wrongOwnedWordIDs(session).filter { (id: String) -> Bool in store.state.word(id: id) != nil }.count
    }

    /// „Dodaj błędne słowa do powtórek”.
    func markWrongWords() {
        let now: Timestamp = store.now()
        let changed: Int = store.update(.edit) { (state: inout LearnerState) -> Int in
            let marked = AssessmentEngine.markWrongWordsHard(state, now: now)
            state = marked.state
            return marked.count
        }
        markedWrongWords = true
        actionNotice = changed > 0
            ? "Oznaczono jako trudne: \(changed) \(StudyFormat.plural(changed, one: "słowo", few: "słowa", many: "słów")). Pojawią się w trybie pomyłek i w fiszkach."
            : "Te słowa są już oznaczone jako trudne — pojawią się w trybie pomyłek."
    }

    /// „Dodaj nowe słowa do nauki” (słowa z bazy z błędną odpowiedzią).
    func addNewWords() async {
        guard !isAddingWords else { return }
        let references = newWordReferences
        guard !references.isEmpty else { return }
        isAddingWords = true
        let added = await TestLoader.addBankWords(references: references, store: store, content: content)
        isAddingWords = false
        addedNewWords = true
        actionNotice = added > 0
            ? "Dodano do nauki: \(added) \(StudyFormat.plural(added, one: "słowo", few: "słowa", many: "słów"))."
            : "Nie udało się dodać słów — sprawdź je w wyszukiwarce tematów."
    }

    // MARK: Prywatne

    private func clear() {
        vocabulary?.cancelPendingWork()
        vocabulary = nil
        question = nil
        missingQuestion = false
        showsReadingPassage = false
    }

    private func options(for shown: VocabExerciseContent) -> [String] {
        guard let session = store.state.assessment else { return [] }
        let working = AssessmentEngine.workingState(store.state, session: session)
        return MeaningOptions.options(
            state: working,
            word: shown.word,
            meaning: shown.meaning,
            task: shown.task,
            starterWords: resources.starterWords,
            answerIndex: resources.answerIndex
        )
    }
}
