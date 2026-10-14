import Foundation

/// Graded hints of one typed exercise (index 0 = level 1). No level ever contains the answer,
/// one of its accepted variants or (as far as the content tells) one of its forms.
public struct HintSet: Sendable, Hashable {
    public var levels: [String]

    public init(levels: [String]) {
        self.levels = levels.filter { !TextScanning.trim($0).isEmpty }
    }

    public static let empty = HintSet(levels: [])

    /// Number of available levels.
    public var count: Int { levels.count }

    /// Texts visible at `level` (1 = first hint, 2 = first and second hint, …).
    public func visible(upTo level: Int) -> [String] {
        Array(levels.prefix(max(0, level)))
    }
}

/// Builds hints that point the learner in the right direction without giving the answer away.
///
/// - Level 1: meaning — part of speech, number of words, the English definition / Polish context
///   with the answer and all its forms masked (`___`).
/// - Level 2: the first letter of each word plus a length mask (`b _ _ _ _ _`,
///   `g _ _   t _ _   h _ _ _   o _`), never more than about a third of the letters.
///
/// Masking compares folded tokens (lowercase, no Polish diacritics, straight apostrophes;
/// hyphens split tokens) and also hides inflected forms that share a long prefix with the answer
/// (`borrow` → `borrowed`, `odprawa` → `odprawy`) and the forms listed in the content.
/// As a last safety net every line that still contains an accepted answer is dropped.
/// Notes (`Word.note`) are never used — they often quote the term.
public enum HintBuilder {
    /// Replacement for a masked fragment.
    public static let maskToken = "___"

    /// Words of multi-word answers that are not masked on their own (too common).
    /// Keys are folded (`TextScanning.foldPolish`).
    static let stopWords: Set<String> = [
        "about", "after", "again", "also", "been", "before", "being", "does", "doing", "down", "each",
        "from", "have", "having", "here", "into", "just", "like", "more", "most", "much", "only", "onto",
        "other", "over", "some", "such", "than", "that", "their", "them", "then", "there", "these", "they",
        "this", "those", "through", "under", "upon", "very", "what", "when", "where", "which", "while",
        "with", "your", "yours", "will", "would", "could", "should", "someone", "something", "somebody",
        "somewhere", "one's", "oneself", "yourself", "itself",
        "jest", "sie", "jako", "albo", "przez", "przed", "oraz", "cos", "kogos", "czegos", "komus",
        "czyms", "kims", "jakis", "ktory", "ktora", "ktore", "bardzo", "tylko"
    ]

    // MARK: Vocabulary

    /// Hints for a vocabulary exercise (recall, cloze, meaning, dictation). Flashcards have none.
    /// `exampleIndex` is the index of the example shown (the cloze answer is the form used there).
    public static func vocabularyHints(word: Word, meaning: Meaning, type: ExerciseType, exampleIndex: Int, variants: AnswerVariants = .builtIn) -> HintSet {
        guard type != .flashcard else { return .empty }
        let answers = vocabularyMaskTerms(word: word, meaning: meaning, type: type, exampleIndex: exampleIndex, variants: variants)
        let primary = primaryVocabularyAnswer(word: word, meaning: meaning, type: type, exampleIndex: exampleIndex)
        var lines: [String] = []
        let pos = TextScanning.trim(meaning.effectivePos(in: word))
        if !pos.isEmpty {
            lines.append("Część mowy: \(sentence(pos))")
        }
        lines.append("Liczba słów: \(wordCount(primary)).")
        if let definition = informativeMask(meaning.definition, answers: answers) {
            lines.append("Angielska definicja: \(definition)")
        }
        if type == .dictation, let translation = informativeMask(meaning.translation, answers: answers, minimumTokens: 1) {
            lines.append("Znaczenie: \(translation)")
        }
        let scene = TextScanning.trim(meaning.scene ?? "")
        let context = TextScanning.trim(meaning.context)
        // W tłumaczeniu (PL→EN) kontekst jest już widoczny w treści zadania.
        let situation = scene.isEmpty ? (type == .recall ? "" : context) : scene
        if let masked = informativeMask(situation, answers: answers, minimumTokens: 1) {
            lines.append("Sytuacja: \(masked)")
        }
        return build(levelOne: lines, primary: primary, answers: answers, fallback: "Pomyśl, jakiego słowa użyłbyś w tej sytuacji.")
    }

    /// Everything that must not appear in a hint of this vocabulary exercise: for the meaning
    /// exercise the accepted Polish answers; otherwise the term, the form in the shown sentence,
    /// accepted English answers and aliases, the forms from `Word.forms` and the inflected forms
    /// used in all examples.
    public static func vocabularyMaskTerms(word: Word, meaning: Meaning, type: ExerciseType, exampleIndex: Int, variants: AnswerVariants = .builtIn) -> [String] {
        var terms: [String]
        if type == .meaning {
            terms = VocabularyGrader.polishAnswers(term: word.en, translation: meaning.translation, saved: meaning.acceptedTranslations ?? [], variants: variants)
            terms.append(meaning.translation)
            terms.append(contentsOf: meaning.acceptedTranslations ?? [])
        } else {
            let grading = gradingWord(word: word, meaning: meaning, type: type, exampleIndex: exampleIndex)
            terms = [word.en, grading.en]
            terms.append(contentsOf: meaning.acceptedAnswers ?? [])
            terms.append(contentsOf: VocabularyGrader.vocabularyAnswers(word: word, meaning: meaning, type: .recall, variants: variants))
            terms.append(contentsOf: formVariants(word.forms))
            terms.append(contentsOf: meaning.exampleFocusEn ?? [])
        }
        return terms
            .map { TextScanning.trim(TextNormalizer.withoutDialectLabel($0)) }
            .filter { !$0.isEmpty }
            .uniqued()
    }

    /// The answer the letter mask is built from.
    static func primaryVocabularyAnswer(word: Word, meaning: Meaning, type: ExerciseType, exampleIndex: Int) -> String {
        switch type {
        case .meaning:
            let translation = withoutParentheses(TextNormalizer.withoutDialectLabel(meaning.translation))
            let parts = translation.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "/" })
            let first = parts.first.map { TextScanning.trim(String($0)) } ?? ""
            return first.isEmpty ? translation : first
        case .cloze:
            return withoutParentheses(gradingWord(word: word, meaning: meaning, type: type, exampleIndex: exampleIndex).en)
        case .flashcard, .recall, .dictation:
            return withoutParentheses(TextNormalizer.withoutDialectLabel(word.en))
        }
    }

    static func gradingWord(word: Word, meaning: Meaning, type: ExerciseType, exampleIndex: Int) -> Word {
        let task = VocabTask(wordId: word.id, meaningId: meaning.id, type: type, example: exampleIndex)
        return VocabularyGrader.gradingWord(word: word, meaning: meaning, task: task)
    }

    /// Forms listed in content (`checks in – checked in – checked in`, `drew; drawn; drawing`,
    /// `burned/burnt`); parenthesised labels are dropped.
    public static func formVariants(_ forms: String) -> [String] {
        let cleaned = withoutParentheses(forms)
        var parts: [String] = []
        var current = ""
        for character in cleaned {
            if character == "," || character == ";" || character == "/" || character == "–" || character == "—" {
                parts.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        parts.append(current)
        var result: [String] = []
        for part in parts {
            for piece in part.components(separatedBy: " - ") {
                let trimmed = TextScanning.trim(piece)
                // „A/B tests” nie daje formy „A” (jedna litera to nie forma słowa).
                if trimmed.filter({ $0.isLetter || $0.isNumber }).count >= 2 {
                    result.append(trimmed)
                }
            }
        }
        return result
    }

    // MARK: Practice (grammar, idioms, production)

    /// Hints for a typed practice question (mixed set, combined session, production item).
    public static func practiceHints(question: PracticeQuestion, production: ProductionItem? = nil) -> HintSet {
        let answers = practiceMaskTerms(question: question, production: production)
        let primary = withoutParentheses(production?.answer ?? question.correctOption)
        var lines: [String] = []
        if let production {
            if let rule = informativeMask(production.rule, answers: answers, minimumTokens: 1) {
                lines.append("Konstrukcja: \(sentence(rule))")
            }
            let verb = TextScanning.trim(production.hintPl)
            if !verb.isEmpty, !production.context.contains("(\(verb))"),
               let masked = informativeMask(verb, answers: answers, minimumTokens: 1) {
                lines.append("Czasownik: \(sentence(masked))")
            }
        } else if let hint = question.inputHint, let masked = informativeMask(hint, answers: answers, minimumTokens: 1) {
            lines.append("Wskazówka: \(sentence(masked))")
        }
        // Wyjaśnienia gramatyki często wymieniają poprawną formę obok błędnych — tylko idiomy.
        if question.category == .idiom, let explanation = informativeMask(question.explanation, answers: answers) {
            lines.append("Wyjaśnienie: \(explanation)")
        }
        let translation = production?.translation ?? question.translation
        if let masked = informativeMask(translation, answers: answers) {
            lines.append("Polskie zdanie: \(masked)")
        }
        lines.append("Liczba słów: \(wordCount(primary)).")
        return build(levelOne: lines, primary: primary, answers: answers, fallback: "Dobierz formę do kontekstu zdania.")
    }

    /// The key and all accepted answers of a practice question / production item.
    public static func practiceMaskTerms(question: PracticeQuestion, production: ProductionItem? = nil) -> [String] {
        var terms = [question.correctOption] + (question.acceptedAnswers ?? [])
        if let production {
            terms.append(production.answer)
            terms.append(contentsOf: production.acceptedAnswers)
        }
        return terms
            .map { TextScanning.trim($0) }
            .filter { !$0.isEmpty }
            .uniqued()
    }

    // MARK: Masks

    /// First letter of each word + one `_` per remaining letter; words separated by three spaces.
    /// At most `letters / 3` letters are shown (one letter for 3–5 letters, none for 1–2);
    /// one-letter words are never shown. Punctuation inside the answer (`-`, `'`) stays visible.
    /// `revealing: 0` gives a pure length mask (`_ _ _   _ _ _ _`).
    public static func letterMask(_ answer: String, revealing limit: Int? = nil) -> String {
        let words = answer.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        let letters = answer.filter { $0.isLetter || $0.isNumber }.count
        var budget = letters >= 3 ? max(1, letters / 3) : 0
        if let limit {
            budget = min(budget, max(0, limit))
        }
        var parts: [String] = []
        for word in words {
            let wordLetters = word.filter { $0.isLetter || $0.isNumber }.count
            var symbols: [String] = []
            var firstLetterSeen = false
            for character in word {
                if character.isLetter || character.isNumber {
                    if !firstLetterSeen && budget > 0 && wordLetters >= 2 {
                        symbols.append(String(character))
                        budget -= 1
                    } else {
                        symbols.append("_")
                    }
                    firstLetterSeen = true
                } else {
                    symbols.append(String(character))
                }
            }
            if !symbols.isEmpty {
                parts.append(symbols.joined(separator: " "))
            }
        }
        return parts.joined(separator: "   ")
    }

    /// `text` with every occurrence of the answers (and their forms) replaced by `___`.
    public static func mask(_ text: String, answers: [String]) -> String {
        mask(text, sequences: maskSequences(answers))
    }

    /// `true` when `text` contains one of `answers` as whole words (after folding: case,
    /// Polish diacritics, apostrophes; hyphens and punctuation separate words).
    public static func reveals(_ text: String, answers: [String]) -> Bool {
        reveals(keys: tokenKeys(text), sequences: revealSequences(answers))
    }

    // MARK: Internals

    static func build(levelOne lines: [String], primary: String, answers: [String], fallback: String) -> HintSet {
        let sequences = revealSequences(answers)
        var safe = lines.filter { (line: String) -> Bool in
            !reveals(keys: tokenKeys(line), sequences: sequences)
        }
        if safe.isEmpty && !reveals(keys: tokenKeys(fallback), sequences: sequences) {
            safe = [fallback]
        }
        let first = safe.joined(separator: "\n")
        let letters = letterMask(primary)
        var second = ""
        if !letters.isEmpty {
            let labelled = "Pierwsze litery: \(letters)"
            if !reveals(keys: tokenKeys(labelled), sequences: sequences) {
                second = labelled
            } else {
                // Odsłonięte litery składają się w wariant odpowiedzi (np. „A/C” dla „air conditioning”):
                // zostaje sama długość.
                let lengthOnly = letterMask(primary, revealing: 0)
                let labelledLength = "Długość: \(lengthOnly)"
                second = reveals(keys: tokenKeys(labelledLength), sequences: sequences) ? lengthOnly : labelledLength
            }
        }
        return HintSet(levels: [first, second])
    }

    /// Masked `text`, or `nil` when it is empty or fewer than `minimumTokens` words survive.
    static func informativeMask(_ text: String, answers: [String], minimumTokens: Int = 2) -> String? {
        let trimmed = TextScanning.trim(text)
        guard !trimmed.isEmpty else { return nil }
        let masked = TextScanning.trim(mask(trimmed, answers: answers))
        return tokenize(masked).count >= minimumTokens ? masked : nil
    }

    static func sentence(_ text: String) -> String {
        guard let last = text.last else { return text }
        return ".!?…".contains(last) ? text : text + "."
    }

    static func wordCount(_ text: String) -> Int {
        max(1, text.split(whereSeparator: { $0.isWhitespace }).count)
    }

    static func withoutParentheses(_ text: String) -> String {
        var depth = 0
        var out = ""
        for character in text {
            if character == "(" {
                depth += 1
            } else if character == ")" {
                if depth > 0 { depth -= 1 }
            } else if depth == 0 {
                out.append(character)
            }
        }
        return TextScanning.trim(TextScanning.collapseWhitespace(out))
    }

    struct Token {
        var range: Range<String.Index>
        var key: String
    }

    static func isApostrophe(_ character: Character) -> Bool {
        character == "'" || character == "\u{2019}" || character == "\u{2018}"
    }

    static func isTokenCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || isApostrophe(character)
    }

    static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var start: String.Index?
        var index = text.startIndex
        while index < text.endIndex {
            if isTokenCharacter(text[index]) {
                if start == nil { start = index }
            } else if let begin = start {
                appendToken(text, begin..<index, to: &tokens)
                start = nil
            }
            index = text.index(after: index)
        }
        if let begin = start {
            appendToken(text, begin..<text.endIndex, to: &tokens)
        }
        return tokens
    }

    static func appendToken(_ text: String, _ range: Range<String.Index>, to tokens: inout [Token]) {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper, isApostrophe(text[lower]) {
            lower = text.index(after: lower)
        }
        while upper > lower, isApostrophe(text[text.index(before: upper)]) {
            upper = text.index(before: upper)
        }
        guard lower < upper else { return }
        let key = TextScanning.foldPolish(TextScanning.straightenApostrophes(String(text[lower..<upper])))
        tokens.append(Token(range: lower..<upper, key: key))
    }

    static func tokenKeys(_ text: String) -> [String] {
        tokenize(text).map { (token: Token) -> String in token.key }
    }

    /// Whole answers as token sequences (used by `reveals`).
    static func revealSequences(_ answers: [String]) -> [[String]] {
        answers
            .map { (answer: String) -> [String] in tokenKeys(answer) }
            .filter { !$0.isEmpty }
            .uniqued()
    }

    /// Whole answers plus the content words of multi-word answers (used for masking).
    static func maskSequences(_ answers: [String]) -> [[String]] {
        var result: [[String]] = []
        for answer in answers {
            let keys = tokenKeys(answer)
            guard !keys.isEmpty else { continue }
            result.append(keys)
            if keys.count > 1 {
                for key in keys where key.count >= 4 && !stopWords.contains(key) {
                    result.append([key])
                }
            }
        }
        return result.uniqued()
    }

    static func reveals(keys: [String], sequences: [[String]]) -> Bool {
        for sequence in sequences where !sequence.isEmpty && sequence.count <= keys.count {
            for start in 0...(keys.count - sequence.count) where Array(keys[start..<(start + sequence.count)]) == sequence {
                return true
            }
        }
        return false
    }

    /// A text word matches an answer word when equal, or when it is an inflected form:
    /// 3-letter answers — the word starts with the answer and is at most 2 letters longer;
    /// 4+ letters — common prefix ≥ max(4, length − 2) and at most 5 letters longer;
    /// 5+ letters — also any word that contains the answer (`toothbrush`, `zresetować`).
    static func tokenMatches(_ text: String, _ answer: String) -> Bool {
        if text == answer { return true }
        let answerLength = answer.count
        let textLength = text.count
        if answerLength >= 5 && textLength > answerLength && text.contains(answer) {
            return true
        }
        if answerLength == 3 {
            return textLength <= answerLength + 2 && text.hasPrefix(answer)
        }
        guard answerLength >= 4, textLength <= answerLength + 5 else { return false }
        return commonPrefixLength(text, answer) >= max(4, answerLength - 2)
    }

    static func commonPrefixLength(_ left: String, _ right: String) -> Int {
        var count = 0
        var leftIterator = left.makeIterator()
        var rightIterator = right.makeIterator()
        while let a = leftIterator.next(), let b = rightIterator.next(), a == b {
            count += 1
        }
        return count
    }

    static func isJoinable(_ gap: Substring) -> Bool {
        gap.allSatisfy { (character: Character) -> Bool in
            character.isWhitespace || character == "-" || character == "/" || isApostrophe(character)
        }
    }

    static func mask(_ text: String, sequences: [[String]]) -> String {
        let tokens = tokenize(text)
        guard !tokens.isEmpty, !sequences.isEmpty else { return text }
        var masked = [Bool](repeating: false, count: tokens.count)
        for sequence in sequences where !sequence.isEmpty && sequence.count <= tokens.count {
            for start in 0...(tokens.count - sequence.count) {
                var matched = true
                for offset in 0..<sequence.count where !tokenMatches(tokens[start + offset].key, sequence[offset]) {
                    matched = false
                    break
                }
                if matched {
                    for offset in 0..<sequence.count {
                        masked[start + offset] = true
                    }
                }
            }
        }
        guard masked.contains(true) else { return text }
        var result = ""
        var cursor = text.startIndex
        var index = 0
        while index < tokens.count {
            guard masked[index] else {
                index += 1
                continue
            }
            var end = index
            while end + 1 < tokens.count, masked[end + 1],
                  isJoinable(text[tokens[end].range.upperBound..<tokens[end + 1].range.lowerBound]) {
                end += 1
            }
            result.append(contentsOf: text[cursor..<tokens[index].range.lowerBound])
            result.append(maskToken)
            cursor = tokens[end].range.upperBound
            index = end + 1
        }
        result.append(contentsOf: text[cursor...])
        return result
    }
}
