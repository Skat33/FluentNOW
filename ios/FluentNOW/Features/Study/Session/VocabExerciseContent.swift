import Foundation
import FluentKit

/// Dane jednego zadania słownikowego wyliczone raz z migawki stanu (czyste wartości).
struct VocabExerciseContent {
    /// Zadanie z sesji (bez zmian — tak trafia do `Scheduler.recordAnswer`).
    let task: VocabTask
    let mode: StudyMode
    let word: Word
    let meaning: Meaning
    /// Indeks przykładu po normalizacji (`task.example % liczba przykładów`, jak strona).
    let exampleIndex: Int
    let example: String
    let pair: ExamplePair?
    /// Wyrażenie w zdaniu w formie z tekstu (np. „borrowed”).
    let focus: String
    /// Słowo do oceny (dla luki `en` = forma ze zdania — `VocabularyGrader.gradingWord`).
    let gradingWord: Word
    /// Akceptowane odpowiedzi (do „Pokaż warianty” po sprawdzeniu).
    let accepted: [String]

    init?(task: VocabTask, mode: StudyMode, state: LearnerState, variants: AnswerVariants) {
        guard let word = state.word(id: task.wordId), let meaning = word.meaning(id: task.meaningId) else {
            return nil
        }
        let count = meaning.examples.count
        let index = count > 0 ? ((task.example % count) + count) % count : 0
        let normalized = VocabTask(wordId: task.wordId, meaningId: task.meaningId, type: task.type, example: index)
        let example = meaning.examples.studyItem(at: index) ?? ""
        let savedFocus = meaning.exampleFocusEn?.studyItem(at: index) ?? ""
        let baseFocus = savedFocus.isEmpty ? word.en : savedFocus
        let gradingWord = VocabularyGrader.gradingWord(word: word, meaning: meaning, task: normalized)

        self.task = task
        self.mode = mode
        self.word = word
        self.meaning = meaning
        self.exampleIndex = index
        self.example = example
        self.pair = VocabularyGrader.examplePair(word: word, meaning: meaning, index: index)
        self.focus = Cloze.span(in: example, focus: baseFocus)?.match ?? baseFocus
        self.gradingWord = gradingWord
        self.accepted = VocabularyGrader.vocabularyAnswers(word: gradingWord, meaning: meaning, type: task.type, variants: variants)
    }

    var type: ExerciseType { task.type }

    /// Klucz zadania (zmiana = nowe zadanie na ekranie).
    static func key(index: Int, task: VocabTask) -> String {
        "\(index):\(task.wordId):\(task.meaningId):\(task.type.rawValue):\(task.example)"
    }

    /// Zdanie z luką; w trybie par z polską podpowiedzią w nawiasie (jak strona).
    var clozeSentence: String {
        guard let gapped = Cloze.text(example, focus: focus) else {
            return Cloze.gap + " (\(meaning.translation))"
        }
        guard mode == .pairs else { return gapped }
        return gapped.replacingOccurrences(of: Cloze.gap, with: Cloze.gap + " (\(meaning.translation))")
    }

    /// Odpowiedź wzorcowa pokazywana po sprawdzeniu.
    var expectedAnswer: String {
        switch type {
        case .meaning: return meaning.translation
        case .cloze: return gradingWord.en
        default: return word.en
        }
    }

    /// Tekst podpowiedzi (strona: definicja dla znaczenia, początek słowa dla pozostałych).
    var hintText: String {
        if type == .meaning {
            if !meaning.definition.isEmpty { return meaning.definition }
            return meaning.context.isEmpty ? "Pomyśl o kontekście zdania." : "Kontekst: \(meaning.context)"
        }
        let target = type == .cloze ? gradingWord.en : word.en
        let start = String(target.prefix(2))
        var text = "Zaczyna się od „\(start)…” i ma \(StudyFormat.characters(target.count))."
        if !word.note.isEmpty {
            text += " \(word.note)"
        }
        return text
    }

    /// Tekst do odsłuchu zdania: przed sprawdzeniem luka tam, gdzie zdanie zdradza odpowiedź.
    func sentenceAudio(solved: Bool) -> String {
        let hidden = (type == .recall || type == .cloze) && !solved
        return ExerciseAudio.vocabularyAudioText(example: example, focus: focus, hidden: hidden)
    }

    /// Metadane nad zadaniem: kolekcja · poziom · rejestr.
    var metaLine: String {
        let level = meaning.effectiveLevel(in: word)
        return [word.collection, level, meaning.register]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Zgłoszenie błędu w tym zadaniu.
    func reportDraft(answer: String) -> StudyReportDraft {
        StudyReportDraft(
            mode: mode == .pairs ? StudyMode.pairs.namePl : type.namePl,
            question: example.isEmpty ? word.en : example,
            answer: answer,
            expected: accepted,
            wordId: word.id,
            meaningId: meaning.id
        )
    }
}
