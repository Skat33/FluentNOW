import Foundation
import Observation
import FluentKit

/// Pytanie testu z gramatyki albo do czytanki (wybór ABCD). Wybór można zmieniać aż do „Dalej”;
/// wynik nie jest pokazywany (FEEDBACK-6 K4).
@MainActor
@Observable
final class TestQuestionModel {
    let task: AssessmentTextQuestion
    let key: String
    private(set) var startedAt = Date()
    private(set) var selected: Int?
    private(set) var outcome: StudyAnswerOutcome?

    init(task: AssessmentTextQuestion, key: String) {
        self.task = task
        self.key = key
    }

    var question: PracticeQuestion { task.question }
    var isAnswered: Bool { outcome != nil }
    /// „Dalej” aktywne.
    var isReady: Bool { selected != nil && outcome == nil }

    func choose(_ index: Int) {
        guard outcome == nil, index >= 0, index < question.options.count else { return }
        selected = index
    }

    /// „Dalej”: ocena wyboru (bez pokazywania wyniku).
    func submit() {
        guard outcome == nil, let index = selected, let option = question.options.studyItem(at: index) else { return }
        outcome = StudyAnswerOutcome(
            value: option,
            correct: index == question.answer,
            hinted: false,
            spellingCorrect: true,
            seconds: elapsed(),
            explanation: ""
        )
    }

    /// „Nie wiem”: odpowiedź błędna.
    func giveUp() {
        guard outcome == nil else { return }
        outcome = StudyAnswerOutcome(value: "", correct: false, hinted: false, spellingCorrect: false, seconds: elapsed(), explanation: "")
    }

    /// Czytanka: odliczanie od „Jestem gotowy na pytania”, nie od tekstu.
    func restartClock() {
        guard outcome == nil else { return }
        startedAt = Date()
    }

    private func elapsed() -> Double {
        max(0.1, Date().timeIntervalSince(startedAt))
    }
}
