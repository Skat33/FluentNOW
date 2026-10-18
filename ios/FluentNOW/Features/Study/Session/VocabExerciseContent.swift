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
    /// Stopniowane podpowiedzi (FluentKit `HintBuilder`): 1 — znaczenie, 2 — pierwsze litery.
    let hints: HintSet
    /// Wszystko, czego tekst pomocniczy przed odpowiedzią nie może pokazać (hasło, formy, warianty).
    let maskTerms: [String]
    /// Pierwsze spotkanie ze znaczeniem (G3: zamiast fiszki „Wybierz znaczenie” z od razu
    /// widocznymi opcjami, bez liczenia ich jako podpowiedzi).
    let isFirstContact: Bool
    /// „Ułóż zdanie”: kafelki (stałe dla zadania); `nil`, gdy zdania nie da się ułożyć.
    let scramble: ScrambleBoard?
    /// „Dopasuj pary”: plansza z kolumnami w stałej kolejności; `nil`, gdy zostało mniej niż 3 par.
    let pairs: MatchPairBoard?
    /// „Zrozum ze słuchu”: cztery tłumaczenia zdania w stałej kolejności (mniej niż 2 — zadanie
    /// zastępuje dyktando).
    let listeningOptions: [String]

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
        self.hints = HintBuilder.vocabularyHints(word: word, meaning: meaning, type: task.type, exampleIndex: index, variants: variants)
        self.maskTerms = HintBuilder.vocabularyMaskTerms(word: word, meaning: meaning, type: task.type, exampleIndex: index, variants: variants)
        self.isFirstContact = SessionBuilder.isFirstContact(meaning)
        // Ziarno bez indeksu w sesji — wznowione zadanie pokazuje te same kafelki i opcje.
        let seed = "\(task.wordId):\(task.meaningId):\(index)"
        switch task.type {
        case .scramble:
            self.scramble = SentenceScramble.board(word: word, meaning: meaning, exampleIndex: index, seed: seed)
            self.pairs = nil
            self.listeningOptions = []
        case .matchPairs:
            let items = MatchPairsExercise.items(for: task, state: state)
            self.scramble = nil
            self.pairs = items.count >= MatchPairsExercise.minimumPairs ? MatchPairsExercise.board(items, seed: seed) : nil
            self.listeningOptions = []
        case .listeningChoice:
            self.scramble = nil
            self.pairs = nil
            self.listeningOptions = ListeningChoice.options(state: state, meaning: meaning, exampleIndex: index, seed: seed)
        case .flashcard, .recall, .cloze, .meaning, .dictation, .picture:
            self.scramble = nil
            self.pairs = nil
            self.listeningOptions = []
        }
    }

    var type: ExerciseType { task.type }

    /// Zastępstwo, gdy nowego typu nie da się pokazać (I2): rozsypanka bez zdania → luka albo
    /// tłumaczenie, za mało par → „Wybierz znaczenie”, za mało tłumaczeń → dyktando. Ta sama
    /// umiejętność (poza rozsypanką bez luki). `nil` — zadanie można pokazać bez zmian.
    func displayFallback(state: LearnerState, variants: AnswerVariants) -> VocabExerciseContent? {
        let replacement: ExerciseType
        switch type {
        case .scramble:
            guard scramble == nil else { return nil }
            replacement = SessionBuilder.canCloze(word: word, meaning: meaning, exampleIndex: exampleIndex) ? .cloze : .recall
        case .matchPairs:
            guard pairs == nil else { return nil }
            replacement = .meaning
        case .listeningChoice:
            guard listeningOptions.count < 2 else { return nil }
            replacement = .dictation
        case .flashcard, .recall, .cloze, .meaning, .dictation, .picture:
            return nil
        }
        let fallback = VocabTask(wordId: task.wordId, meaningId: task.meaningId, type: replacement, example: task.example)
        return VocabExerciseContent(task: fallback, mode: mode, state: state, variants: variants)
    }

    /// „Dopasuj pary”: kolejność par do zapisu (lewa kolumna).
    var pairItems: [MatchPairItem] { pairs?.english ?? [] }

    /// Opcje „Wybierz znaczenie” widoczne od razu (pierwszy kontakt ze słowem).
    var showsMeaningOptionsAtOnce: Bool { type == .meaning && isFirstContact }

    /// To samo zadanie jako „Wybierz znaczenie” — gdy zdjęć nie da się pokazać (brak w cache).
    func asMeaningTask(state: LearnerState, variants: AnswerVariants) -> VocabExerciseContent? {
        let fallback = VocabTask(wordId: task.wordId, meaningId: task.meaningId, type: .meaning, example: task.example)
        return VocabExerciseContent(task: fallback, mode: mode, state: state, variants: variants)
    }

    /// Klucz zadania (zmiana = nowe zadanie na ekranie).
    static func key(index: Int, task: VocabTask) -> String {
        "\(index):\(task.wordId):\(task.meaningId):\(task.type.rawValue):\(task.example)"
    }

    /// Zdanie z luką; w trybie par z polską podpowiedzią w nawiasie (jak strona).
    /// Tłumaczenie bywa takie samo jak hasło (np. „pizza”) — wtedy jest zamaskowane albo pominięte.
    var clozeSentence: String {
        let translation = HintBuilder.mask(meaning.translation, answers: maskTerms)
        let hasTranslation = translation.contains(where: { (character: Character) -> Bool in character.isLetter })
        let suffix = hasTranslation ? " (\(translation))" : ""
        guard let gapped = Cloze.text(example, focus: focus) else {
            return Cloze.gap + suffix
        }
        guard mode == .pairs else { return gapped }
        return gapped.replacingOccurrences(of: Cloze.gap, with: Cloze.gap + suffix)
    }

    /// Kontekst pod pytaniem „Jak powiesz to po angielsku?” — bez hasła i jego form.
    var promptContext: String {
        let context = meaning.context.isEmpty ? word.collection : meaning.context
        return HintBuilder.mask(context, answers: maskTerms)
    }

    /// Odpowiedź wzorcowa pokazywana po sprawdzeniu.
    var expectedAnswer: String {
        switch type {
        case .meaning: return meaning.translation
        case .cloze: return gradingWord.en
        case .scramble: return example
        case .listeningChoice: return ListeningChoice.translation(meaning: meaning, exampleIndex: exampleIndex) ?? meaning.translation
        default: return word.en
        }
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
