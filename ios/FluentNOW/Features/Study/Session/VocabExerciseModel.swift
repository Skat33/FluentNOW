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

/// Sposób odpowiadania na zadanie — zawsze dokładnie jeden naraz (FEEDBACK-3 H1).
enum VocabInputStyle: Equatable {
    /// Fiszka: odsłoń → pamiętam / jeszcze nie.
    case flashcard
    /// „Słowo i zdjęcie”: dotknięcie zdjęcia.
    case picture
    /// „Wybierz znaczenie” z widocznymi opcjami: tylko dotknięcie opcji (klawisze 1–4), bez pola.
    case choice
    /// Pole tekstowe (tłumaczenie, luka, dyktando, znaczenie bez pokazanych wariantów).
    case typing
    /// „Ułóż zdanie”: kafelki słów (I2).
    case scramble
    /// „Dopasuj pary”: dwie kolumny do połączenia (I2).
    case pairs
    /// „Zrozum ze słuchu”: odsłuch + wybór tłumaczenia (I2).
    case listening
}

/// Błędna para na planszy „Dopasuj pary” (krótkie mignięcie).
struct VocabPairFlash: Equatable {
    let id: Int
    let englishID: String
    let polishID: String
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
    /// „Wybierz znaczenie” z opcjami: ostatnio wybrana opcja.
    private(set) var chosenOption: Int?
    /// Opcje wybrane błędnie (w drugiej próbie zablokowane i oznaczone).
    private(set) var wrongOptions: [Int] = []
    /// Była druga próba (typy bez podpowiedzi tekstowych liczą ją jako pomoc).
    private(set) var retried = false

    // „Ułóż zdanie”
    /// Identyfikatory kafelków ułożonych w zdaniu (po kolei).
    private(set) var placedTiles: [Int] = []
    /// Tłumaczenie zdania odsłonięte (podpowiedź).
    private(set) var scrambleHintShown = false

    // „Dopasuj pary”
    /// Zaznaczone słowo angielskie / tłumaczenie (identyfikator znaczenia).
    private(set) var selectedEnglish: String?
    private(set) var selectedPolish: String?
    /// Znaczenia już połączone w pary.
    private(set) var matchedPairs: [String] = []
    /// Liczba błędnych par, w których brało udział znaczenie.
    private(set) var pairMistakes: [String: Int] = [:]
    /// Ostatnia błędna para (mignięcie); `id` rośnie z każdym błędem.
    private(set) var pairFlash: VocabPairFlash?
    private(set) var pairMistakeCount = 0

    // „Zrozum ze słuchu”
    /// Liczba odsłuchów przed odpowiedzią.
    private(set) var plays = 0

    private let variants: AnswerVariants
    private let assistant: AssistantService?
    /// Opcje znaczeń pokazane od razu przy pierwszym kontakcie — nie liczą się jako pomoc.
    private let variantsAreFree: Bool
    @ObservationIgnored private var assistantTask: Task<Void, Never>?
    @ObservationIgnored private var pendingLocal: Grade?

    init(content: VocabExerciseContent, key: String, options: [String], variants: AnswerVariants, assistant: AssistantService?) {
        self.content = content
        self.key = key
        self.options = content.type == .listeningChoice ? content.listeningOptions : options
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
    var usedHelp: Bool {
        hintShown || (variantsShown && !variantsAreFree) || scrambleHintShown || (retried && !type.hasTextHints)
    }
    /// Zdjęcie poprawnej odpowiedzi (po wczytaniu).
    var correctPicture: StudyPictureOption? {
        pictures.first { (option: StudyPictureOption) -> Bool in option.isCorrect }
    }
    var canCheck: Bool {
        (phase == .answering || phase == .retry) && !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Jeden mechanizm odpowiedzi naraz (H1): gdy opcje znaczenia są widoczne — tylko wybór.
    var inputStyle: VocabInputStyle {
        switch type {
        case .flashcard: return .flashcard
        case .picture: return .picture
        case .meaning: return (variantsShown && options.count >= 2) ? .choice : .typing
        case .recall, .cloze, .dictation: return .typing
        case .scramble: return .scramble
        case .matchPairs: return .pairs
        case .listeningChoice: return .listening
        }
    }

    /// Indeks poprawnej opcji (tłumaczenie znaczenia, a w słuchaniu — tłumaczenie zdania) albo
    /// `nil`, gdy go wśród opcji nie ma.
    var correctOption: Int? {
        if type == .listeningChoice {
            return ListeningChoice.correctIndex(options: options, meaning: content.meaning, exampleIndex: content.exampleIndex)
        }
        let key = TextNormalizer.normalize(content.meaning.translation)
        return options.firstIndex { (option: String) -> Bool in TextNormalizer.normalize(option) == key }
    }

    /// Kafelki ułożone w zdaniu (w kolejności).
    var placedScrambleTiles: [ScrambleTile] {
        guard let board = content.scramble else { return [] }
        return placedTiles.compactMap { (id: Int) -> ScrambleTile? in
            board.tiles.first { (tile: ScrambleTile) -> Bool in tile.id == id }
        }
    }

    /// Kafelki jeszcze do wyboru (w kolejności planszy).
    var availableScrambleTiles: [ScrambleTile] {
        guard let board = content.scramble else { return [] }
        return board.tiles.filter { (tile: ScrambleTile) -> Bool in !placedTiles.contains(tile.id) }
    }

    /// „Sprawdź” w rozsypance: ułożono tyle słów, ile ma zdanie.
    var canCheckScramble: Bool {
        guard let board = content.scramble else { return false }
        return (phase == .answering || phase == .retry) && placedTiles.count == board.answer.count
    }

    /// Wynik „Dopasuj pary” per znaczenie (kolejność lewej kolumny).
    var pairResults: [MatchPairResult] {
        content.pairItems.map { (item: MatchPairItem) -> MatchPairResult in
            MatchPairResult(wordId: item.wordId, meaningId: item.meaningId, mistakes: pairMistakes[item.meaningId] ?? 0)
        }
    }

    /// Odsłuch w „Zrozum ze słuchu” jest jeszcze możliwy (po odpowiedzi — bez limitu).
    var canPlay: Bool {
        isFinished || plays < ListeningChoice.maxPlays
    }

    // MARK: Akcje

    /// Odsłania kolejny poziom podpowiedzi (pierwsza prośba — znaczenie, kolejna — pierwsze litery).
    func showHint() {
        guard canShowMoreHints else { return }
        hintLevel += 1
    }

    /// „Pokaż warianty”: od teraz odpowiedź tylko wyborem opcji (wpisany tekst znika — H1).
    func showVariants() {
        guard phase == .answering || phase == .retry else { return }
        variantsShown = true
        if inputStyle == .choice {
            answer = ""
        }
    }

    /// Dotknięcie opcji (lub klawisz 1–4) = odpowiedź. Ocena po tożsamości opcji, nie po tekście —
    /// dystraktor nigdy nie zostanie uznany za „literówkę” poprawnej odpowiedzi. Pierwszy błąd daje
    /// drugą próbę z podpowiedzią (błędna opcja zostaje oznaczona i zablokowana), jak przy wpisywaniu.
    func chooseOption(at index: Int) {
        guard inputStyle == .choice || inputStyle == .listening, phase == .answering || phase == .retry,
              let option = options.studyItem(at: index), !wrongOptions.contains(index) else { return }
        answer = option
        chosenOption = index
        stoppedSeconds = elapsed()
        let correct: Bool
        if let expected = correctOption {
            correct = index == expected
        } else if type == .listeningChoice {
            correct = false
        } else {
            correct = VocabularyGrader.localGrade(
                answer: option,
                word: content.gradingWord,
                meaning: content.meaning,
                type: type,
                variants: variants
            ).isCorrect
        }
        if correct {
            finish(with: Grade(verdict: .correct, explanation: "", spellingCorrect: true))
            return
        }
        wrongOptions.append(index)
        failed(Grade(verdict: .incorrect, explanation: "Wybrano „\(option)”.", spellingCorrect: false))
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

    // MARK: „Ułóż zdanie”

    /// Dotknięcie kafelka z puli — trafia na koniec zdania.
    func placeTile(_ id: Int) {
        guard type == .scramble, phase == .answering || phase == .retry, !placedTiles.contains(id),
              content.scramble?.tiles.contains(where: { (tile: ScrambleTile) -> Bool in tile.id == id }) == true else { return }
        placedTiles.append(id)
    }

    /// Dotknięcie kafelka w zdaniu — wraca do puli.
    func removeTile(_ id: Int) {
        guard type == .scramble, phase == .answering || phase == .retry else { return }
        placedTiles.removeAll { (placed: Int) -> Bool in placed == id }
    }

    /// „Wyczyść” — wszystkie kafelki wracają do puli.
    func clearTiles() {
        guard type == .scramble, phase == .answering || phase == .retry else { return }
        placedTiles = []
    }

    /// Podpowiedź rozsypanki: polskie tłumaczenie zdania (odpowiedź z pomocą).
    func showScrambleHint() {
        guard type == .scramble, phase == .answering || phase == .retry else { return }
        scrambleHintShown = true
    }

    /// Sprawdza ułożone zdanie (wielkość liter i interpunkcja bez znaczenia). Pierwszy błąd:
    /// druga próba — poprawny początek zostaje, reszta wraca do puli, tłumaczenie się odsłania.
    func checkScramble() {
        guard canCheckScramble, let board = content.scramble else { return }
        let texts = placedScrambleTiles.map { (tile: ScrambleTile) -> String in tile.text }
        answer = texts.joined(separator: " ")
        stoppedSeconds = elapsed()
        if SentenceScramble.isCorrect(texts, board: board) {
            finish(with: Grade(verdict: .correct, explanation: "", spellingCorrect: true))
            return
        }
        if phase == .answering {
            let kept = SentenceScramble.correctPrefixCount(texts, board: board)
            placedTiles = Array(placedTiles.prefix(kept))
            retried = true
            scrambleHintShown = scrambleHintShown || !board.translation.isEmpty
            phase = .retry
            return
        }
        finish(with: Grade(verdict: .incorrect, explanation: "Ułożono: „\(answer)”.", spellingCorrect: false))
    }

    // MARK: „Dopasuj pary”

    /// Dotknięcie słowa angielskiego (ponowne — odznacza).
    func tapEnglish(_ meaningID: String) {
        guard type == .matchPairs, phase == .answering, !matchedPairs.contains(meaningID) else { return }
        selectedEnglish = selectedEnglish == meaningID ? nil : meaningID
        resolvePair()
    }

    /// Dotknięcie tłumaczenia (ponowne — odznacza).
    func tapPolish(_ meaningID: String) {
        guard type == .matchPairs, phase == .answering, !matchedPairs.contains(meaningID) else { return }
        selectedPolish = selectedPolish == meaningID ? nil : meaningID
        resolvePair()
    }

    /// Koniec mignięcia błędnej pary (wołane przez widok po chwili).
    func clearPairFlash(_ id: Int) {
        guard pairFlash?.id == id else { return }
        pairFlash = nil
    }

    private func resolvePair() {
        guard let english = selectedEnglish, let polish = selectedPolish else { return }
        selectedEnglish = nil
        selectedPolish = nil
        if english == polish {
            matchedPairs.append(english)
            if matchedPairs.count >= content.pairItems.count {
                finishPairs()
            }
            return
        }
        // Błędna para liczy pomyłkę dla obu znaczeń.
        pairMistakes[english, default: 0] += 1
        pairMistakes[polish, default: 0] += 1
        pairMistakeCount += 1
        pairFlash = VocabPairFlash(id: pairMistakeCount, englishID: english, polishID: polish)
    }

    private func finishPairs() {
        let seconds = elapsed()
        stoppedSeconds = seconds
        let total = content.pairItems.count
        let missed = pairResults.filter { (result: MatchPairResult) -> Bool in !result.correct }.count
        answer = "\(total - missed)/\(total)"
        let correct = missed == 0
        grade = Grade(verdict: correct ? .correct : .incorrect, explanation: "", spellingCorrect: correct)
        outcome = StudyAnswerOutcome(
            value: answer,
            correct: correct,
            hinted: false,
            spellingCorrect: correct,
            seconds: seconds,
            explanation: correct ? "" : "Pomyłki w parach: \(pairMistakeCount)."
        )
        phase = .finished
    }

    // MARK: „Zrozum ze słuchu”

    /// Rejestruje odsłuch; `false`, gdy limit przed odpowiedzią jest wyczerpany.
    func registerPlay() -> Bool {
        guard type == .listeningChoice else { return false }
        if isFinished { return true }
        guard plays < ListeningChoice.maxPlays else { return false }
        plays += 1
        return true
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
        guard inputStyle == .typing, canCheck else { return }
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
            retried = true
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
