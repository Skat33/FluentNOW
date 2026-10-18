import Foundation

/// Local grading of vocabulary answers (tutor-local.ts `vocabularyAnswers`, `localGrade`;
/// answer-variants.ts `polishAnswers`). Never calls AI.
///
/// Policy (web v38/v41): accepted variants are matched after normalisation (case, spaces,
/// Polish diacritics, trailing punctuation, unambiguous English contractions). A typo or an
/// unknown variant is **not** accepted automatically; instead `Grade.closestAnswer` tells the UI
/// which answer the learner probably meant, so it can offer „Uznaj moją odpowiedź” (then record
/// the answer as correct with `spellingCorrect: false`). Dictation stays exact.
public enum VocabularyGrader {
    /// Polish answers accepted for the meaning exercise: the translation, its parts split on
    /// `, ; /`, saved alternatives, reviewed sense variants anchored by those, and aspect pairs.
    public static func polishAnswers(term: String, translation: String, saved: [String] = [], variants: AnswerVariants = .builtIn) -> [String] {
        var base: [String] = [TextNormalizer.withoutDialectLabel(translation)]
        let parts = translation.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "/" })
        base.append(contentsOf: parts.map { TextNormalizer.withoutDialectLabel(String($0)) })
        base.append(contentsOf: saved)
        let anchors = Set(base.map(TextNormalizer.answerKey))
        let termKey = TextNormalizer.answerKey(term)
        var reviewed: [String] = []
        for group in variants.polishSenseVariants where TextNormalizer.answerKey(group.term) == termKey {
            if group.variants.contains(where: { anchors.contains(TextNormalizer.answerKey($0)) }) {
                reviewed.append(contentsOf: group.variants)
            }
        }
        var aspects: [String] = []
        for pair in variants.polishAspectPairs where pair.contains(where: { anchors.contains(TextNormalizer.answerKey($0)) }) {
            aspects.append(contentsOf: pair)
        }
        return (base + reviewed + aspects)
            .map { TextScanning.trim($0) }
            .filter { !$0.isEmpty }
            .uniqued()
    }

    /// Normalised keys (`answerKey`) of everything `polishAnswers` would accept.
    public static func polishAnswerKeys(term: String, translation: String, saved: [String] = [], index: PolishAnswerIndex) -> Set<String> {
        index.keys(term: term, translation: translation, saved: saved)
    }

    /// `true` when the meaning is a reviewed sense of the term (its translation anchors one of
    /// the term's `polishSenseVariants` groups). Only then do `englishAliases` apply, so
    /// „lend someone” is never accepted for an unrelated sense of *lend*.
    static func isKnownSense(word: Word, meaning: Meaning, variants: AnswerVariants) -> Bool {
        let termKey = TextNormalizer.answerKey(word.en)
        var anchors = Set<String>([TextNormalizer.answerKey(meaning.translation)])
        for part in meaning.translation.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "/" }) {
            anchors.insert(TextNormalizer.answerKey(String(part)))
        }
        return variants.polishSenseVariants.contains { group in
            TextNormalizer.answerKey(group.term) == termKey
                && group.variants.contains { anchors.contains(TextNormalizer.answerKey($0)) }
        }
    }

    /// Answers accepted for a vocabulary task (`vocabularyAnswers`).
    ///
    /// - meaning (3): Polish answers;
    /// - flashcard (0), cloze (2), dictation (4): the word itself (for cloze pass the word with
    ///   `en` replaced by the inflected form in the sentence — see `gradingWord`);
    /// - recall (1): the word, saved alternatives, reviewed aliases and `to …` for verbs.
    public static func vocabularyAnswers(word: Word, meaning: Meaning, type: ExerciseType, variants: AnswerVariants = .builtIn) -> [String] {
        switch type {
        case .meaning, .matchPairs:
            return polishAnswers(term: word.en, translation: meaning.translation, saved: meaning.acceptedTranslations ?? [], variants: variants)
        case .flashcard, .cloze, .dictation, .picture, .scramble, .listeningChoice:
            return [word.en]
        case .recall:
            var answers = [word.en] + (meaning.acceptedAnswers ?? [])
            if isKnownSense(word: word, meaning: meaning, variants: variants) {
                answers.append(contentsOf: variants.englishAliases[TextNormalizer.normalize(word.en)] ?? [])
            }
            let pos = meaning.effectivePos(in: word).lowercased()
            if pos.contains("czasownik") || pos.contains("verb") {
                let withTo = answers.filter { !$0.lowercased().hasPrefix("to ") }.map { "to \($0)" }
                answers.append(contentsOf: withTo)
            }
            return answers.uniqued()
        }
    }

    /// The word to grade against: for cloze, `en` is replaced by the form used in the sentence
    /// („borrowed”), exactly like the web app.
    /// The index uses the same wrapping as the screen (`task.example % examples.count`, web
    /// `examples[task.example % examples.length]`), so an index past the end grades the sentence
    /// that is actually shown.
    public static func gradingWord(word: Word, meaning: Meaning, task: VocabTask) -> Word {
        guard task.type == .cloze, !meaning.examples.isEmpty else { return word }
        let index = exampleIndex(task.example, in: meaning)
        guard let sentence = meaning.examples[safe: index] else { return word }
        let focusSaved = meaning.exampleFocusEn?[safe: index] ?? ""
        let focus = focusSaved.isEmpty ? word.en : focusSaved
        var copy = word
        copy.en = Cloze.span(in: sentence, focus: focus)?.match ?? focus
        return copy
    }

    /// Index of the example shown for a task: `rawIndex % examples.count` (non-negative),
    /// 0 when the meaning has no examples. Same rule as the web (`examples[i % length]`).
    public static func exampleIndex(_ rawIndex: Int, in meaning: Meaning) -> Int {
        let count = meaning.examples.count
        guard count > 0 else { return 0 }
        return ((rawIndex % count) + count) % count
    }

    /// `localGrade`: compares a typed answer with the accepted answers.
    public static func localGrade(answer: String, word: Word, meaning: Meaning, type: ExerciseType, variants: AnswerVariants = .builtIn) -> Grade {
        let key: (String) -> String = type == .meaning ? TextNormalizer.answerKey : TextNormalizer.englishAnswerKey
        let actual = key(answer)
        let accepted = vocabularyAnswers(word: word, meaning: meaning, type: type, variants: variants)
        let acceptedKeys = accepted.map(key)
        if !actual.isEmpty && acceptedKeys.contains(actual) {
            return Grade(
                verdict: .correct,
                explanation: "To poprawny wariant dla tego znaczenia. Wielkość liter, końcowa interpunkcja i polskie znaki nie wpływają na ocenę.",
                spellingCorrect: true,
                source: .local
            )
        }
        // Fallback: inner punctuation, notes in parentheses and `;`-glued variants in the content
        // (e.g. „zerwać się (o połączeniu)”, „było, minęło”) must not make a correct answer fail.
        let looseActual = TextNormalizer.stripInnerPunctuation(actual)
        if !looseActual.isEmpty {
            let looseAccepted: [String] = accepted.flatMap { (variant: String) -> [String] in
                TextNormalizer.looseKeys(variant, using: key)
            }
            if looseAccepted.contains(looseActual) {
                return Grade(
                    verdict: .correct,
                    explanation: "To poprawny wariant dla tego znaczenia. Interpunkcja, wielkość liter i polskie znaki nie wpływają na ocenę.",
                    spellingCorrect: true,
                    source: .local
                )
            }
        }
        let enKey = TextNormalizer.normalize(word.en)
        let swapped = (enKey == "lend" && actual.hasPrefix("borrow")) || (enKey == "borrow" && actual.hasPrefix("lend"))
        var closest: String?
        if !actual.isEmpty && !swapped {
            var best = Int.max
            for (index, candidate) in acceptedKeys.enumerated() {
                let length = candidate.count
                let allowed = length >= 8 ? 2 : (length >= 4 ? 1 : 0)
                guard allowed > 0 else { continue }
                let distance = TextNormalizer.levenshtein(actual, candidate)
                if distance > 0 && distance <= allowed && distance < best {
                    best = distance
                    closest = accepted[index]
                }
            }
        }
        let explanation: String
        if swapped {
            explanation = "Lend oznacza pożyczyć coś komuś, a borrow — pożyczyć coś od kogoś."
        } else if let closest {
            explanation = "Prawie dobrze — to wygląda na literówkę. Poprawna pisownia: „\(closest)”."
        } else {
            explanation = "Odpowiedź nie pasuje do zapisanych poprawnych wariantów tego zadania. Jeśli brakuje prawidłowego wariantu, zgłoś błąd."
        }
        return Grade(verdict: .incorrect, explanation: explanation, spellingCorrect: false, source: .local, closestAnswer: closest)
    }

    /// The example pair (sentence + translation + focus) of a meaning, or `nil` when the
    /// translation of that example is not stored.
    public static func examplePair(word: Word, meaning: Meaning, index: Int) -> ExamplePair? {
        guard let en = meaning.examples[safe: index], !en.isEmpty else { return nil }
        guard let pl = meaning.exampleTranslations?[safe: index], !pl.isEmpty else { return nil }
        let focusEn = meaning.exampleFocusEn?[safe: index] ?? ""
        let focusPl = meaning.exampleFocusPl?[safe: index] ?? ""
        return ExamplePair(
            en: en,
            pl: pl,
            focusEn: focusEn.isEmpty ? word.en : focusEn,
            focusPl: focusPl.isEmpty ? meaning.translation : focusPl
        )
    }
}
