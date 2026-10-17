import Foundation
import Observation
import FluentKit

/// Etap zadania słownikowego.
enum VocabExercisePhase: Equatable {
    /// Pierwsza próba (fiszka: przed i po odsłonięciu).
    case answering
    /// Pierwsza odpowiedź była błędna — podpowiedź odsłonięta, druga próba.
    case retry
    /// Odpowiedź niejednoznaczna — sprawdza asystent AI (można pominąć).
    case checking
    /// Wynik gotowy.
    case finished
}

/// Stan jednego zadania słownikowego (fiszka, tłumaczenie, luka, znaczenie, dyktando).
/// Ocena wyłącznie przez FluentKit (`VocabularyGrader.localGrade`) i opcjonalnie `AssistantService`.
@MainActor
@Observable
final class VocabExerciseModel {
    let content: VocabExerciseContent
    let key: String
    let startedAt: Date

    var answer: String = ""
    private(set) var phase: VocabExercisePhase = .answering
    /// Ile poziomów podpowiedzi jest odsłoniętych (0 — żaden; 1 — znaczenie; 2 — pierwsze litery).
    private(set) var hintLevel = 0
    private(set) var variantsShown = false
    private(set) var revealed = false
    private(set) var grade: Grade?
    private(set) var retryGrade: Grade?
    private(set) var acceptedTypo = false
    private(set) var outcome: StudyAnswerOutcome?
    private(set) var options: [String]
    private(set) var stoppedSeconds: Double?
    /// „Słowo i zdjęcie”: cztery zdjęcia w kolejności wyświetlania (puste, dopóki się wczytują).
    private(set) var pictures: [StudyPictureOption] = []
    /// Indeks wybranego zdjęcia (po odpowiedzi).
    private(set) var selectedPicture: Int?

    private let variants: AnswerVariants
    private let assistant: AssistantService?
    /// Opcje znaczeń pokazane od razu przy pierwszym kontakcie — nie liczą się jako pomoc.
    private let variantsAreFree: Bool
    @ObservationIgnored private var assistantTask: Task<Void, Never>?
    @ObservationIgnored private var pendingLocal: Grade?

    init(content: VocabExerciseContent, key: String, options: [String], variants: AnswerVariants, assistant: AssistantService?) {
        self.content = content
        self.key = key
        self.options = options
        self.variants = variants
        self.assistant = assistant
        self.startedAt = Date()
        self.variantsAreFree = content.showsMeaningOptionsAtOnce
        self.variantsShown = content.showsMeaningOptionsAtOnce
    }

    var type: ExerciseType { content.type }
    var isFinished: Bool { phase == .finished }
    var hintShown: Bool { hintLevel > 0 }
    /// Teksty odsłoniętych poziomów podpowiedzi (nigdy nie zawierają odpowiedzi — FluentKit `HintBuilder`).
    var visibleHints: [String] { content.hints.visible(upTo: hintLevel) }
    /// Jest jeszcze kolejny poziom podpowiedzi do odsłonięcia.
    var canShowMoreHints: Bool {
        (phase == .answering || phase == .retry) && hintLevel < content.hints.count
    }
    /// Podpowiedź lub warianty = odpowiedź z pomocą (strona: `hint`). Opcje pokazane od razu
    /// przy pierwszym kontakcie ze słowem nie są pomocą.
    var usedHelp: Bool { hintShown || (variantsShown && !variantsAreFree) }
    /// Zdjęcie poprawnej odpowiedzi (po wczytaniu).
    var correctPicture: StudyPictureOption? {
        pictures.first { (option: StudyPictureOption) -> Bool in option.isCorrect }
    }
    var canCheck: Bool {
        (phase == .answering || phase == .retry) && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Akcje

    /// Odsłania kolejny poziom podpowiedzi (pierwsza prośba — znaczenie, kolejna — pierwsze litery).
    func showHint() {
        guard canShowMoreHints else { return }
        hintLevel += 1
    }

    func showVariants() {
        guard phase != .finished else { return }
        variantsShown = true
    }

    func choose(_ option: String) {
        guard phase == .answering || phase == .retry else { return }
        answer = option
    }

    /// Wymienia dystraktory, gdy zasoby treści dotarły później (przed pokazaniem wariantów albo —
    /// przy opcjach widocznych od razu — zanim użytkownik coś wybrał).
    func replaceOptions(_ newOptions: [String]) {
        guard !newOptions.isEmpty else { return }
        guard !variantsShown || (variantsAreFree && answer.isEmpty && phase == .answering) else { return }
        options = newOptions
    }

    /// „Słowo i zdjęcie”: zdjęcia gotowe do pokazania.
    func setPictures(_ newPictures: [StudyPictureOption]) {
        guard type == .picture, phase == .answering, selectedPicture == nil else { return }
        pictures = newPictures
    }

    /// „Słowo i zdjęcie”: dotknięcie zdjęcia = odpowiedź (jedna próba, bez podpowiedzi).
    func choosePicture(at index: Int) {
        guard type == .picture, phase == .answering, let option = pictures.studyItem(at: index) else { return }
        selectedPicture = index
        let seconds = elapsed()
        stoppedSeconds = seconds
        answer = option.term
        let correct = option.isCorrect
        let explanation = correct ? "" : "Wybrane zdjęcie to „\(option.term)” — \(option.translation)."
        grade = Grade(verdict: correct ? .correct : .incorrect, explanation: explanation, spellingCorrect: correct)
        outcome = StudyAnswerOutcome(
            value: option.term,
            correct: correct,
            hinted: false,
            spellingCorrect: correct,
            seconds: seconds,
            explanation: ""
        )
        phase = .finished
    }

    /// Fiszka: odsłonięcie znaczenia zatrzymuje licznik.
    func reveal() {
        guard type == .flashcard, !revealed else { return }
        revealed = true
        stoppedSeconds = elapsed()
    }

    /// Fiszka: „Pamiętam” / „Jeszcze nie pamiętam”.
    func finishFlashcard(remembered: Bool) {
        guard type == .flashcard, phase != .finished else { return }
        if !revealed { reveal() }
        let seconds = stoppedSeconds ?? elapsed()
        outcome = StudyAnswerOutcome(
            value: remembered ? "Pamiętam" : "Jeszcze nie pamiętam",
            correct: remembered,
            hinted: false,
            spellingCorrect: remembered,
            seconds: seconds,
            explanation: ""
        )
        phase = .finished
    }

    /// Sprawdza wpisaną odpowiedź (Enter / „Sprawdź”).
    func check() {
        guard type != .flashcard, type != .picture, canCheck else { return }
        let value = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        stoppedSeconds = elapsed()
        let local = VocabularyGrader.localGrade(
            answer: value,
            word: content.gradingWord,
            meaning: content.meaning,
            type: type,
            variants: variants
        )
        if local.isCorrect || local.closestAnswer != nil {
            finish(with: local)
            return
        }
        if let assistant, shouldAskAssistant(assistant) {
            askAssistant(assistant, answer: value, local: local)
            return
        }
        failed(local)
    }

    /// Pomija sprawdzanie przez asystenta — zostaje ocena lokalna.
    func skipAssistant() {
        guard phase == .checking else { return }
        assistantTask?.cancel()
        assistantTask = nil
        failed(pendingLocal ?? Grade(verdict: .incorrect, explanation: "", spellingCorrect: false))
    }

    /// Druga próba: rezygnacja — pokaż poprawną odpowiedź.
    func giveUp() {
        guard phase == .retry else { return }
        stoppedSeconds = elapsed()
        finish(with: retryGrade ?? Grade(verdict: .incorrect, explanation: "", spellingCorrect: false))
    }

    /// „Uznaj moją odpowiedź” przy literówce: zaliczone, ale z błędem pisowni.
    func acceptTypo() {
        guard phase == .finished, !acceptedTypo, var current = outcome, !current.correct, grade?.closestAnswer != nil else { return }
        acceptedTypo = true
        current.correct = true
        current.spellingCorrect = false
        outcome = current
    }

    func cancelPendingWork() {
        assistantTask?.cancel()
        assistantTask = nil
    }

    // MARK: Prywatne

    private func elapsed() -> Double {
        max(0.1, Date().timeIntervalSince(startedAt))
    }

    private func shouldAskAssistant(_ assistant: AssistantService) -> Bool {
        assistant.activeProvider != .offline && (type == .recall || type == .meaning)
    }

    private func askAssistant(_ assistant: AssistantService, answer value: String, local: Grade) {
        phase = .checking
        pendingLocal = local
        let word = content.word
        let meaning = content.meaning
        let exerciseType = type
        let context = content.example
        assistantTask = Task { [weak self] in
            let remote = await assistant.grade(answer: value, word: word, meaning: meaning, exerciseType: exerciseType, context: context)
            guard !Task.isCancelled else { return }
            self?.assistantReturned(remote, local: local)
        }
    }

    private func assistantReturned(_ remote: Grade?, local: Grade) {
        guard phase == .checking else { return }
        assistantTask = nil
        if let remote, !remote.isFailure {
            finish(with: remote)
        } else {
            failed(remote ?? local)
        }
    }

    /// Błędna odpowiedź: pierwsza — druga próba z kolejnym poziomem podpowiedzi; kolejna — wynik.
    private func failed(_ grade: Grade) {
        if phase == .answering || (phase == .checking && retryGrade == nil) {
            retryGrade = grade
            hintLevel = min(content.hints.count, hintLevel + 1)
            phase = .retry
            return
        }
        finish(with: grade)
    }

    private func finish(with grade: Grade) {
        self.grade = grade
        let correct = !grade.isFailure
        outcome = StudyAnswerOutcome(
            value: answer.trimmingCharacters(in: .whitespacesAndNewlines),
            correct: correct,
            hinted: usedHelp,
            spellingCorrect: correct && grade.spellingCorrect,
            seconds: stoppedSeconds ?? elapsed(),
            explanation: grade.explanation
        )
        phase = .finished
    }
}
