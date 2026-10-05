import Foundation
import Observation
import FluentKit

/// Stan pytania w sesji łączonej (gramatyka, idiomy, miks, czytanie, produkcja).
/// Ocena: wybór ABCD = porównanie z kluczem; wpisywanie = `ProductionGrader.checkPracticeInput`;
/// produkcja = `ProductionGrader.grade` (z diagnozą).
@MainActor
@Observable
final class CombinedQuestionModel {
    let task: CombinedQuestionTask
    let key: String
    let startedAt: Date

    var written: String = ""
    private(set) var selected: Int?
    private(set) var hintShown = false
    private(set) var outcome: StudyAnswerOutcome?
    private(set) var production: ProductionResult?
    private(set) var stoppedSeconds: Double?

    private let variants: AnswerVariants

    init(task: CombinedQuestionTask, key: String, variants: AnswerVariants, saved: CombinedAnswer?) {
        self.task = task
        self.key = key
        self.variants = variants
        self.startedAt = Date()
        if let saved {
            written = saved.value
            selected = Int(saved.value)
            outcome = StudyAnswerOutcome(
                value: saved.value,
                correct: saved.correct,
                hinted: saved.hinted,
                spellingCorrect: saved.spellingCorrect,
                seconds: saved.seconds,
                explanation: saved.explanation
            )
            stoppedSeconds = saved.seconds
        }
    }

    var question: PracticeQuestion { task.question }
    var isInput: Bool { task.production != nil || question.isInput }
    var isAnswered: Bool { outcome != nil }
    var canCheck: Bool { !isAnswered && !written.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Wzorcowa odpowiedź pokazywana po sprawdzeniu.
    var expected: String {
        task.production?.answer ?? question.correctOption
    }

    var expectedAll: [String] {
        if let item = task.production {
            return [item.answer] + item.acceptedAnswers
        }
        return [question.correctOption] + (question.acceptedAnswers ?? [])
    }

    /// Podpowiedź do wpisywania (reguła lub wskazówka z banku).
    var hintText: String {
        let hint = question.inputHint ?? ""
        return hint.isEmpty ? "Dobierz formę do kontekstu zdania." : hint
    }

    func showHint() {
        guard !isAnswered else { return }
        hintShown = true
    }

    func choose(_ index: Int) {
        guard !isAnswered, index >= 0, index < question.options.count else { return }
        selected = index
        let seconds = elapsed()
        stoppedSeconds = seconds
        outcome = StudyAnswerOutcome(
            value: String(index),
            correct: index == question.answer,
            hinted: false,
            spellingCorrect: true,
            seconds: seconds,
            explanation: question.explanation
        )
    }

    func checkWritten() {
        guard canCheck else { return }
        let value = written.trimmingCharacters(in: .whitespacesAndNewlines)
        let seconds = elapsed()
        stoppedSeconds = seconds
        if let item = task.production {
            let result = ProductionGrader.grade(value, item: item)
            production = result
            outcome = StudyAnswerOutcome(
                value: value,
                correct: result.correct,
                hinted: hintShown,
                spellingCorrect: result.spellingCorrect,
                seconds: seconds,
                explanation: result.explanation
            )
        } else {
            let result = ProductionGrader.checkPracticeInput(question, value: value, variants: variants)
            outcome = StudyAnswerOutcome(
                value: value,
                correct: result.correct,
                hinted: hintShown,
                spellingCorrect: true,
                seconds: seconds,
                explanation: question.explanation
            )
        }
    }

    /// Tekst do odsłuchu (luka cicha przed sprawdzeniem).
    var audioText: String {
        guard task.reading == nil else { return "" }
        return ExerciseAudio.exerciseAudioText(context: question.context, solved: isAnswered, correctAnswer: expected)
    }

    var reportDraft: StudyReportDraft {
        let answerText: String
        if isInput {
            answerText = outcome?.value ?? written
        } else {
            answerText = selected.flatMap { question.options.studyItem(at: $0) } ?? ""
        }
        let questionText = question.context.isEmpty ? question.prompt : question.prompt + "\n" + question.context
        return StudyReportDraft(mode: task.mode.namePl, question: questionText, answer: answerText, expected: expectedAll)
    }

    private func elapsed() -> Double {
        max(0.1, Date().timeIntervalSince(startedAt))
    }
}
