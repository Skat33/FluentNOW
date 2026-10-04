import Foundation

/// Result of checking a typed practice answer.
public struct PracticeInputResult: Sendable, Hashable {
    public var correct: Bool
    /// Option index to record: the key when correct, otherwise a different index.
    public var choice: Int

    public init(correct: Bool, choice: Int) {
        self.correct = correct
        self.choice = choice
    }
}

/// Grading of grammar production and typed practice answers
/// (production.ts `normalizeProduction`, `gradeProduction`; practice-input.ts `checkPracticeInput`).
public enum ProductionGrader {
    private static let subjects: Set<String> = ["i", "you", "he", "she", "it", "we", "they"]
    private static let auxiliaries: Set<String> = [
        "am", "is", "are", "was", "were", "be", "been", "being", "has", "have", "had", "do", "does", "did",
        "will", "would", "can", "could", "may", "might", "must", "shall", "should"
    ]
    private static let trailingPunctuation: Set<Character> = [".", "!", "?", ",", ";", ":"]

    /// Words of a text split on non-word characters (JS `\b` semantics).
    static func containsWord(_ text: String, _ word: String) -> Bool {
        text.split(whereSeparator: { !TextScanning.isWordChar($0) }).contains { $0 == word }
    }

    /// The pronoun directly before the gap (`they ________` → `they`), if any.
    static func subjectBeforeGap(_ context: String) -> String? {
        let prefix: String
        if let range = context.range(of: Cloze.gap) {
            prefix = String(context[context.startIndex..<range.lowerBound])
        } else {
            prefix = context
        }
        let trimmed = Array(TextScanning.trim(prefix))
        var start = trimmed.count
        while start > 0 && TextScanning.isWordChar(trimmed[start - 1]) {
            start -= 1
        }
        guard start < trimmed.count else { return nil }
        let word = String(trimmed[start...]).lowercased()
        return subjects.contains(word) ? word : nil
    }

    /// `normalizeProduction`: lowercase, straight apostrophes, no trailing punctuation, contractions
    /// expanded (`'d` / `'s` resolved from the expected answer and rule), and a repeated subject
    /// right before the gap removed (`they'd called` → `had called`).
    public static func normalize(_ value: String, item: ProductionItem) -> String {
        let target = item.answer.lowercased()
        let perfect = item.rule.contains("perfect") || containsWord(target, "has") || containsWord(target, "have") || containsWord(target, "had")
        var text = TextScanning.straightenApostrophes(TextScanning.trim(value.lowercased()))
        text = TextScanning.removingTrailing(trailingPunctuation, from: text)
        text = TextNormalizer.expandUnambiguousContractions(text)
        let dReplacement: String
        if containsWord(target, "would") {
            dReplacement = " would"
        } else if containsWord(target, "had") {
            dReplacement = " had"
        } else if item.rule.contains("conditional") {
            dReplacement = " would"
        } else {
            dReplacement = " had"
        }
        text = TextScanning.replaceToken(text, "'d", with: dReplacement, leftBoundary: false)
        text = TextScanning.replaceToken(text, "'s", with: perfect ? " has" : " is", leftBoundary: false)
        text = TextScanning.trim(TextScanning.collapseWhitespace(text))
        if let subject = subjectBeforeGap(item.context), text.hasPrefix(subject + " ") {
            text = String(text.dropFirst(subject.count + 1))
        }
        return text
    }

    /// `gradeProduction`. Order: correct form → known distractor (its diagnosis) → spelling slip
    /// (edit distance ≤ min(2, ⌊len/3⌋) without changing auxiliaries or negation) → general error.
    public static func grade(_ answer: String, item: ProductionItem) -> ProductionResult {
        let value = normalize(answer, item: item)
        let targets = ([item.answer] + item.acceptedAnswers).map { normalize($0, item: item) }
        if !value.isEmpty && targets.contains(value) {
            return ProductionResult(correct: true, spellingCorrect: true, diagnosis: nil, explanation: item.explanation)
        }
        if !value.isEmpty, let wrong = item.distractors.first(where: { normalize($0.form, item: item) == value }) {
            return ProductionResult(correct: false, spellingCorrect: true, diagnosis: ProductionResultDiagnosis(wrong.diagnosis), explanation: wrong.explanation)
        }
        func grammarTokens(_ text: String) -> [String] {
            text.split(separator: " ").map(String.init).filter { auxiliaries.contains($0) || $0 == "not" }
        }
        func grammarChanged(_ target: String) -> Bool {
            let actual = grammarTokens(value)
            let expected = grammarTokens(target)
            return actual.contains { !expected.contains($0) } || expected.contains("not") != actual.contains("not")
        }
        if !value.isEmpty {
            let typo = targets.contains { target in
                !grammarChanged(target) && TextNormalizer.levenshtein(value, target) <= min(2, target.count / 3)
            }
            if typo {
                return ProductionResult(
                    correct: true,
                    spellingCorrect: false,
                    diagnosis: .spelling,
                    explanation: "Popraw pisownię: „\(item.answer)”. \(item.explanation)"
                )
            }
        }
        return ProductionResult(correct: false, spellingCorrect: true, diagnosis: .general, explanation: item.explanation)
    }

    /// `checkPracticeInput`: typed answer of a practice question, graded against the key and saved
    /// alternatives. Grammar uses `englishAnswerKey` (contractions), idioms `answerKey` plus the
    /// reviewed Polish equivalents of an idiom that literally appears in the context.
    public static func checkPracticeInput(_ item: PracticeQuestion, value: String, variants: AnswerVariants = .builtIn) -> PracticeInputResult {
        let key: (String) -> String = item.category == .grammar ? TextNormalizer.englishAnswerKey : TextNormalizer.answerKey
        let answer = key(value)
        var targets = [item.correctOption] + (item.acceptedAnswers ?? [])
        if item.category == .idiom {
            let context = TextNormalizer.answerKey(item.context)
            let first = targets.first ?? ""
            let idiomTerms = variants.polishSenseVariants.map { $0.term }.filter { $0.contains(" ") }.uniqued()
            for term in idiomTerms where context.contains(TextNormalizer.answerKey(term)) {
                targets.append(contentsOf: VocabularyGrader.polishAnswers(term: term, translation: first, variants: variants))
            }
        }
        let correct = !answer.isEmpty && targets.contains { !$0.isEmpty && key($0) == answer }
        let optionCount = max(1, item.options.count)
        return PracticeInputResult(correct: correct, choice: correct ? item.answer : (item.answer + 1) % optionCount)
    }
}
