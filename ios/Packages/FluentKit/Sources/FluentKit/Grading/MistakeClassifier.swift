import Foundation

/// What went wrong in one answer: the kind and the differing parts („gone” → „went”).
public struct MistakeAnalysis: Sendable, Hashable {
    public var kind: MistakeKind
    /// The expected word(s) that the learner missed (lower case; empty for word order / whole answers).
    public var expectedPart: String
    /// The learner's word(s) in their place.
    public var givenPart: String

    public init(kind: MistakeKind, expectedPart: String = "", givenPart: String = "") {
        self.kind = kind
        self.expectedPart = expectedPart
        self.givenPart = givenPart
    }
}

/// Classifies wrong answers for „Twoje typowe błędy” (FEEDBACK-10 P1). Pure functions:
/// - a token diff of expected and given answers (multiset difference, order kept);
/// - verb forms from the irregular verb table of `ScrambleDecoys` plus `be/have/do/get` and verbs
///   with variant forms, and regular `-ed` / `-ing` endings (a plain `-s` is also a plural noun, so
///   it counts only when the answer is a verb — `focusIsVerb`);
/// - prepositions and articles from fixed lists;
/// - typos with the thresholds of `FuzzyMatcher` (search „Czy chodziło Ci o…?” uses the same).
public enum MistakeClassifier {
    /// Prepositions (and particles) learners confuse.
    public static let prepositions: Set<String> = [
        "in", "on", "at", "to", "for", "from", "of", "with", "by", "about", "into", "onto", "over",
        "under", "after", "before", "during", "since", "until", "till", "between", "among", "through",
        "across", "toward", "towards", "against", "without", "within", "around", "behind", "beside",
        "besides", "near", "off", "up", "down", "out", "inside", "outside", "along", "upon", "like",
        "per", "via", "past", "beyond", "above", "below", "beneath", "except", "opposite"
    ]

    /// Articles.
    public static let articles: Set<String> = ["a", "an", "the"]

    // MARK: Answers

    /// An English answer against the expected one (word, phrase or sentence). `nil` when both are
    /// the same answer (case, punctuation and unambiguous contractions ignored).
    /// - Parameter focusIsVerb: the expected answer is a verb — then „work” / „works” is a verb
    ///   form, not a typo.
    public static func classify(expected: String, given: String, focusIsVerb: Bool = false) -> MistakeAnalysis? {
        let expectedWords = words(expected)
        let givenWords = words(given)
        guard expectedWords != givenWords else { return nil }
        guard !expectedWords.isEmpty, !givenWords.isEmpty else {
            return MistakeAnalysis(kind: .otherWord, expectedPart: expectedWords.joined(separator: " "), givenPart: givenWords.joined(separator: " "))
        }
        guard var analysis = classify(expectedTokens: expectedWords, givenTokens: givenWords, focusIsVerb: focusIsVerb) else {
            return nil
        }
        // „lookforward to”, „icecream” — the whole answer is one slip away.
        if analysis.kind == .otherWord && isTypo(expected: expectedWords.joined(separator: " "), given: givenWords.joined(separator: " ")) {
            analysis.kind = .typo
        }
        return analysis
    }

    /// Tiles of „Ułóż zdanie” (or words of any answer): the same words in another order →
    /// `.wordOrder`; otherwise the most telling kind among the swapped words (`MistakeKind` order).
    /// `nil` when the sequences are equal.
    public static func classify(expectedTokens: [String], givenTokens: [String], focusIsVerb: Bool = false) -> MistakeAnalysis? {
        let expected = expectedTokens.map { (token: String) -> String in SentenceScramble.key(token) }.filter { (key: String) -> Bool in !key.isEmpty }
        let given = givenTokens.map { (token: String) -> String in SentenceScramble.key(token) }.filter { (key: String) -> Bool in !key.isEmpty }
        guard expected != given else { return nil }
        let missing = difference(expected, minus: given)
        let extra = difference(given, minus: expected)
        if missing.isEmpty && extra.isEmpty {
            return MistakeAnalysis(kind: .wordOrder)
        }
        var kinds: [MistakeKind] = []
        let paired = min(missing.count, extra.count)
        for index in 0..<paired {
            kinds.append(classifyWord(expected: missing[index], given: extra[index], focusIsVerb: focusIsVerb) ?? .otherWord)
        }
        // A word left out or added without a counterpart („the” added, „to” missing).
        for leftover in Array(missing.dropFirst(paired)) + Array(extra.dropFirst(paired)) {
            if articles.contains(leftover) {
                kinds.append(.article)
            } else if prepositions.contains(leftover) {
                kinds.append(.preposition)
            } else {
                kinds.append(.otherWord)
            }
        }
        let kind = kinds.min { (a: MistakeKind, b: MistakeKind) -> Bool in a.rank < b.rank } ?? .otherWord
        return MistakeAnalysis(kind: kind, expectedPart: missing.joined(separator: " "), givenPart: extra.joined(separator: " "))
    }

    /// A Polish answer (typed in „Wybierz znaczenie”): a typo within `FuzzyMatcher` thresholds
    /// (diacritics ignored), otherwise a wrong meaning. `nil` when both are the same answer.
    public static func classifyPolish(expected: String, given: String) -> MistakeAnalysis? {
        let expectedKey = TextNormalizer.answerKey(expected)
        let givenKey = TextNormalizer.answerKey(given)
        guard expectedKey != givenKey else { return nil }
        if isTypo(expected: expectedKey, given: givenKey) {
            return MistakeAnalysis(kind: .typo, expectedPart: expectedKey, givenPart: givenKey)
        }
        return MistakeAnalysis(kind: .meaning)
    }

    /// One word against another (comparison keys). `nil` when they are the same word.
    public static func classifyWord(expected: String, given: String, focusIsVerb: Bool = false) -> MistakeKind? {
        let left = SentenceScramble.key(expected)
        let right = SentenceScramble.key(given)
        guard left != right else { return nil }
        if areVerbForms(left, right, allowPlainS: focusIsVerb) { return .verbForm }
        if prepositions.contains(left) && prepositions.contains(right) { return .preposition }
        if articles.contains(left) && articles.contains(right) { return .article }
        if isTypo(expected: left, given: right) { return .typo }
        return .otherWord
    }

    /// `true` when `given` is `expected` with a slip: at most `FuzzyMatcher.maxDistance` edits
    /// (adjacent letters swapped = one edit) for the length of `expected`, and not the same key.
    public static func isTypo(expected: String, given: String) -> Bool {
        let key = TextNormalizer.searchKey(expected)
        let allowed = FuzzyMatcher.maxDistance(forLength: key.utf8.count)
        guard allowed > 0, let distance = FuzzyMatcher.distance(expected, given, limit: allowed) else { return false }
        return distance > 0
    }

    /// The accepted answer closest to `given` (fewest edits after `englishAnswerKey`); ties keep
    /// the first. `nil` for an empty list.
    public static func closest(to given: String, among answers: [String]) -> String? {
        let key = TextNormalizer.englishAnswerKey(given)
        var best: (answer: String, distance: Int)?
        for answer in answers {
            let distance = TextNormalizer.levenshtein(key, TextNormalizer.englishAnswerKey(answer))
            if best == nil || distance < (best?.distance ?? Int.max) {
                best = (answer: answer, distance: distance)
            }
        }
        return best?.answer
    }

    /// One-line Polish feedback for a typed answer („To inna forma tego czasownika…”), or `nil`
    /// when the kind has no specific hint.
    public static func feedbackPl(_ analysis: MistakeAnalysis) -> String? {
        let expected = analysis.expectedPart
        let given = analysis.givenPart
        let hasParts = !expected.isEmpty && !given.isEmpty
        switch analysis.kind {
        case .verbForm:
            return hasParts ? "To inna forma tego czasownika: potrzebna jest „\(expected)”, a nie „\(given)”." : "To inna forma tego czasownika."
        case .preposition:
            return hasParts ? "Sprawdź przyimek: w tym połączeniu jest „\(expected)”, a nie „\(given)”." : "Sprawdź przyimek w tym połączeniu."
        case .article:
            return hasParts ? "Sprawdź przedimek: „\(expected)”, a nie „\(given)”." : "Sprawdź przedimek."
        case .typo, .otherWord, .wordOrder, .meaning:
            return nil
        }
    }

    // MARK: Words

    /// Comparison words of free text: `englishAnswerKey` (contractions expanded), split at spaces,
    /// edge punctuation removed.
    static func words(_ text: String) -> [String] {
        SentenceScramble.tokens(TextNormalizer.englishAnswerKey(text))
            .map { (token: String) -> String in SentenceScramble.key(token) }
            .filter { (key: String) -> Bool in !key.isEmpty }
    }

    /// Elements of `left` not matched by an element of `right` (multiset difference, order kept).
    static func difference(_ left: [String], minus right: [String]) -> [String] {
        var available: [String: Int] = [:]
        for item in right {
            available[item, default: 0] += 1
        }
        var result: [String] = []
        for item in left {
            if let count = available[item], count > 0 {
                available[item] = count - 1
            } else {
                result.append(item)
            }
        }
        return result
    }

    // MARK: Verb forms

    /// Verbs not in the decoy table (left out there on purpose) — every listed form maps to the
    /// first word.
    private static let extraVerbForms: [String] = [
        "be am is are was were been being", "have has had having", "do does did done doing",
        "get gets got gotten getting", "go goes went gone going", "find found", "grind ground",
        "lie lay lain lying", "lay laid", "fall fell fallen", "ring rang rung", "bear bore born borne",
        "wind wound", "learn learned learnt", "dream dreamed dreamt", "burn burned burnt",
        "spell spelled spelt", "show showed shown", "dive dived dove", "wake woke woken",
        "prove proved proven", "shrink shrank shrunk", "sink sank sunk", "spring sprang sprung",
        "hang hung hanged", "shine shone shined", "beat beaten", "light lit lighted", "slide slid",
        "spin spun", "swing swung", "sweep swept", "weep wept", "creep crept", "kneel knelt",
        "lean leaned leant", "leap leaped leapt", "seek sought", "feel felt", "dig dug",
        "say says said", "die died dying", "tie tied tying"
    ]

    /// Form → base forms (a form may belong to two verbs: „lay” — lie / lay).
    private static let irregularLemmas: [String: Set<String>] = {
        var map: [String: Set<String>] = [:]
        for verb in ScrambleDecoys.irregularVerbs {
            for form in [verb.base, verb.past, verb.participle] {
                map[form, default: []].insert(verb.base)
            }
        }
        for line in extraVerbForms {
            let forms = line.split(separator: " ").map { (part: Substring) -> String in String(part) }
            guard let base = forms.first else { continue }
            for form in forms {
                map[form, default: []].insert(base)
            }
        }
        return map
    }()

    /// Base forms of irregular verbs (third person „-s” of these is always a verb form).
    private static let irregularBases: Set<String> = {
        var bases = Set<String>()
        for verb in ScrambleDecoys.irregularVerbs {
            bases.insert(verb.base)
        }
        for line in extraVerbForms {
            if let base = line.split(separator: " ").first {
                bases.insert(String(base))
            }
        }
        return bases
    }()

    /// `true` when both words are forms of one verb (went / gone, make / made, work / worked,
    /// interested / interesting). A plain „-s” pair (work / works, car / cars) only with
    /// `allowPlainS` — it may be a plural noun.
    public static func areVerbForms(_ left: String, _ right: String, allowPlainS: Bool = false) -> Bool {
        let a = SentenceScramble.key(left)
        let b = SentenceScramble.key(right)
        guard a != b, !a.isEmpty, !b.isEmpty else { return false }
        if !lemmas(a, plainS: allowPlainS).isDisjoint(with: lemmas(b, plainS: allowPlainS)) {
            return true
        }
        return false
    }

    /// Possible base forms of a word: irregular table, third person of irregular verbs, regular
    /// `-ed` / `-ing` stems (and `-s` with `plainS`), and the word itself.
    static func lemmas(_ key: String, plainS: Bool = false) -> Set<String> {
        var result: Set<String> = [key]
        if let bases = irregularLemmas[key] {
            result.formUnion(bases)
        }
        let thirdPerson = sStems(key)
        for stem in thirdPerson where irregularBases.contains(stem) {
            result.insert(stem)
        }
        if plainS {
            result.formUnion(thirdPerson)
        }
        if key.count > 4 && key.hasSuffix("ing") {
            let stem = String(key.dropLast(3))
            result.insert(stem)
            result.insert(stem + "e")
            if let last = stem.last, stem.dropLast().last == last {
                result.insert(String(stem.dropLast()))
            }
            if stem.hasSuffix("y") {
                result.insert(String(stem.dropLast()) + "ie")
            }
        }
        if key.count > 3 && key.hasSuffix("ed") {
            let stem = String(key.dropLast(2))
            result.insert(stem)
            result.insert(String(key.dropLast()))
            if let last = stem.last, stem.dropLast().last == last {
                result.insert(String(stem.dropLast()))
            }
            if key.hasSuffix("ied") {
                result.insert(String(key.dropLast(3)) + "y")
            }
        }
        return result
    }

    /// Stems of a third-person „-s” form („goes” → go, „flies” → fly, „works” → work).
    private static func sStems(_ key: String) -> [String] {
        guard key.count > 2, key.hasSuffix("s"), !key.hasSuffix("ss") else { return [] }
        var stems: [String] = [String(key.dropLast())]
        if key.hasSuffix("es") { stems.append(String(key.dropLast(2))) }
        if key.hasSuffix("ies") { stems.append(String(key.dropLast(3)) + "y") }
        return stems
    }
}
