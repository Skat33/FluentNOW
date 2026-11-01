import Foundation

/// Kind of a decoy tile in „Ułóż zdanie” (FEEDBACK-9 N1). The order is the priority used when
/// a board needs fewer decoys than there are candidates.
public enum ScrambleDecoyKind: Int, Sendable, Hashable, CaseIterable {
    /// Another form of a verb of the sentence that is ungrammatical in its place (went → gone).
    case verbForm
    /// A preposition learners confuse in a fixed phrase (depend on → from, at night → on).
    case preposition
    /// „a” ↔ „an” — only when the sentence has no other determiner.
    case article
    /// A content word from another example of the same entry.
    case sameEntry
    /// A content word from an example of another word of the learner (last resort).
    case otherWord
}

/// One decoy word with the reason it was chosen (tests, diagnostics).
public struct ScrambleDecoy: Sendable, Hashable {
    public var text: String
    public var kind: ScrambleDecoyKind

    public init(text: String, kind: ScrambleDecoyKind) {
        self.text = text
        self.kind = kind
    }
}

/// Decoy words for „Ułóż zdanie” (FEEDBACK-9 N1). Every grammatical decoy is **unambiguously
/// wrong** in place of the word it was made from — a decoy may never let the learner build
/// another correct translation of the Polish sentence:
/// - verb forms only from a table of irregular verbs and only where the other form cannot stand
///   (a bare participle without „have/be”, a past form after „to”/a modal, a base form after
///   „have/be”); `be`, `have`, `do`, `get` and verbs with variant forms (learned/learnt) are left out;
/// - prepositions only in fixed phrases where the decoy is a typical Polish learner's mistake
///   (depend on → from, afraid of → from, at night → on, on Monday → in);
/// - „a”/„an” only swapped with each other and only when the sentence has no other determiner
///   (otherwise „an” could replace „my” and build a correct sentence);
/// - never an extra „the” — an added article is often correct.
enum ScrambleDecoys {
    // MARK: Irregular verbs

    struct IrregularVerb: Hashable {
        let base: String
        let past: String
        let participle: String

        /// Past and participle differ from each other and from the base (go / went / gone).
        var hasStrictForms: Bool {
            past != base && participle != base && participle != past
        }
    }

    /// Base, past simple, past participle (American English). Left out on purpose: be, have, do,
    /// get (gotten/got), verbs with variant forms (learn, dream, burn, spell, show, dive, wake,
    /// prove, shrink, sink, spring, hang, shine), homographs whose other form is another word
    /// (find → found, grind → ground, lie/lay, fall → „the fallen”, ring → rung, saw, bear, wind)
    /// and verbs whose three forms are the same (put, cut, let…).
    private static let rawVerbs: [String] = [
        "arise arose arisen", "become became become", "begin began begun", "bite bit bitten",
        "blow blew blown", "break broke broken", "choose chose chosen", "come came come",
        "draw drew drawn", "drink drank drunk", "drive drove driven", "eat ate eaten",
        "fly flew flown", "forbid forbade forbidden", "forget forgot forgotten",
        "forgive forgave forgiven", "freeze froze frozen", "give gave given", "go went gone",
        "grow grew grown", "hide hid hidden", "know knew known", "mistake mistook mistaken",
        "overcome overcame overcome", "ride rode ridden", "rise rose risen", "run ran run",
        "see saw seen", "shake shook shaken", "sing sang sung", "speak spoke spoken",
        "steal stole stolen", "swim swam swum", "take took taken", "tear tore torn",
        "throw threw thrown", "undertake undertook undertaken", "wear wore worn",
        "withdraw withdrew withdrawn", "write wrote written",
        "bend bent bent", "bleed bled bled", "bring brought brought", "build built built",
        "buy bought bought", "catch caught caught", "deal dealt dealt", "dig dug dug",
        "feed fed fed", "feel felt felt", "fight fought fought", "flee fled fled",
        "hear heard heard", "hold held held", "keep kept kept", "lead led led",
        "leave left left", "lend lent lent", "lose lost lost", "make made made",
        "mean meant meant", "meet met met", "pay paid paid", "say said said", "sell sold sold",
        "send sent sent", "shoot shot shot", "sit sat sat", "sleep slept slept",
        "spend spent spent", "stand stood stood", "stick stuck stuck", "strike struck struck",
        "teach taught taught", "tell told told", "think thought thought",
        "understand understood understood", "win won won"
    ]

    static let irregularVerbs: [IrregularVerb] = rawVerbs.compactMap { (line: String) -> IrregularVerb? in
        let parts = line.split(separator: " ").map { (part: Substring) -> String in String(part) }
        guard parts.count == 3 else { return nil }
        return IrregularVerb(base: parts[0], past: parts[1], participle: parts[2])
    }

    private static let verbsByBase: [String: IrregularVerb] = makeIndex(\IrregularVerb.base)
    private static let verbsByPast: [String: IrregularVerb] = makeIndex(\IrregularVerb.past)
    private static let verbsByParticiple: [String: IrregularVerb] = makeIndex(\IrregularVerb.participle)

    private static func makeIndex(_ path: KeyPath<IrregularVerb, String>) -> [String: IrregularVerb] {
        var result: [String: IrregularVerb] = [:]
        for verb in irregularVerbs where result[verb[keyPath: path]] == nil {
            result[verb[keyPath: path]] = verb
        }
        return result
    }

    /// A participle that is also a common noun or adjective on its own („a drunk”) — never a decoy
    /// for the base form.
    private static let standaloneParticiples: Set<String> = ["drunk"]
    /// A past form that is also a common adjective („my phone is broke”) — the participle gets the
    /// base form as its decoy instead.
    private static let adjectivePasts: Set<String> = ["broke"]

    /// Words after which only the base form of a verb can follow.
    private static let baseContext: Set<String> = [
        "to", "can", "could", "will", "would", "should", "must", "may", "might", "shall", "cannot",
        "can't", "won't", "wouldn't", "couldn't", "shouldn't", "mustn't", "don't", "doesn't",
        "didn't", "let's", "i'll", "you'll", "we'll", "they'll", "he'll", "she'll", "it'll"
    ]

    /// Words after which a participle (or an -ing form) follows, never the base or past form.
    private static let participleContext: Set<String> = [
        "have", "has", "had", "having", "i've", "you've", "we've", "they've", "haven't", "hasn't",
        "hadn't", "is", "are", "was", "were", "be", "been", "being", "am", "i'm", "you're", "we're",
        "they're", "isn't", "aren't", "wasn't", "weren't", "it's", "he's", "she's", "that's",
        "get", "gets", "got", "getting"
    ]

    /// Forms of „be” before an -ing form.
    private static let progressiveContext: Set<String> = [
        "is", "are", "was", "were", "be", "been", "am", "i'm", "you're", "we're", "they're", "isn't",
        "aren't", "wasn't", "weren't", "it's", "he's", "she's", "that's", "there's"
    ]

    /// Base form for a third-person „-s” form („goes” → „go”, „flies” → „fly”).
    private static func baseOfThirdPerson(_ key: String) -> IrregularVerb? {
        guard key.count > 2, key.hasSuffix("s") else { return nil }
        var candidates: [String] = [String(key.dropLast())]
        if key.hasSuffix("es") { candidates.append(String(key.dropLast(2))) }
        if key.hasSuffix("ies") { candidates.append(String(key.dropLast(3)) + "y") }
        for candidate in candidates {
            if let verb = verbsByBase[candidate] { return verb }
        }
        return nil
    }

    /// Base form for an „-ing” form („taking” → „take”, „swimming” → „swim”).
    private static func baseOfIngForm(_ key: String) -> IrregularVerb? {
        guard key.count > 4, key.hasSuffix("ing") else { return nil }
        let stem = String(key.dropLast(3))
        var candidates: [String] = [stem, stem + "e"]
        if let last = stem.last, stem.dropLast().last == last {
            candidates.append(String(stem.dropLast()))
        }
        if stem.hasSuffix("y") {
            candidates.append(String(stem.dropLast()) + "ie")
        }
        for candidate in candidates {
            if let verb = verbsByBase[candidate] { return verb }
        }
        return nil
    }

    /// The verb-form decoy for one token (`previous` — key of the word before it, or "").
    static func verbFormDecoy(for key: String, previous: String) -> String? {
        if let verb = verbsByBase[key] {
            if verb.hasStrictForms, !standaloneParticiples.contains(verb.participle) {
                return verb.participle
            }
            if baseContext.contains(previous), verb.past != verb.base {
                return verb.past
            }
            if participleContext.contains(previous), verb.participle == verb.base, verb.past != verb.base {
                return verb.past
            }
            return nil
        }
        if let verb = verbsByPast[key], verb.hasStrictForms {
            return verb.participle
        }
        if let verb = verbsByParticiple[key] {
            if verb.hasStrictForms {
                return adjectivePasts.contains(verb.past) ? verb.base : verb.past
            }
            // made / left / met: base after „have/be” is always wrong.
            if participleContext.contains(previous), verb.participle == verb.past {
                return verb.base
            }
            return nil
        }
        if let verb = baseOfThirdPerson(key), verb.hasStrictForms, !standaloneParticiples.contains(verb.participle) {
            return verb.participle
        }
        if let verb = baseOfIngForm(key) {
            if verb.hasStrictForms {
                return verb.past
            }
            if progressiveContext.contains(previous) {
                return verb.participle == verb.base ? verb.past : verb.base
            }
        }
        return nil
    }

    // MARK: Prepositions

    private struct CollocationRule {
        let previous: Set<String>
        let preposition: String
        let decoy: String
    }

    /// Fixed phrases with a typical Polish learner's mistake as the decoy.
    private static let collocations: [CollocationRule] = [
        CollocationRule(previous: ["depend", "depends", "depended", "depending", "dependent"], preposition: "on", decoy: "from"),
        CollocationRule(previous: ["rely", "relies", "relied", "relying", "reliant"], preposition: "on", decoy: "from"),
        CollocationRule(previous: ["insist", "insists", "insisted", "insisting"], preposition: "on", decoy: "for"),
        CollocationRule(previous: ["keen"], preposition: "on", decoy: "in"),
        CollocationRule(previous: ["interested"], preposition: "in", decoy: "on"),
        CollocationRule(previous: ["afraid", "scared", "frightened", "terrified"], preposition: "of", decoy: "from"),
        CollocationRule(previous: ["proud"], preposition: "of", decoy: "from"),
        CollocationRule(previous: ["consist", "consists", "consisted", "consisting"], preposition: "of", decoy: "from"),
        CollocationRule(previous: ["capable"], preposition: "of", decoy: "to"),
        CollocationRule(previous: ["fond"], preposition: "of", decoy: "for"),
        CollocationRule(previous: ["different"], preposition: "from", decoy: "of"),
        CollocationRule(previous: ["responsible"], preposition: "for", decoy: "of"),
        CollocationRule(previous: ["similar"], preposition: "to", decoy: "with"),
        CollocationRule(previous: ["listen", "listens", "listened", "listening"], preposition: "to", decoy: "of"),
        CollocationRule(previous: ["arrive", "arrives", "arrived", "arriving"], preposition: "at", decoy: "to"),
        CollocationRule(previous: ["arrive", "arrives", "arrived", "arriving"], preposition: "in", decoy: "to")
    ]

    private static let lookForms: Set<String> = ["look", "looks", "looked", "looking"]

    private static let weekdays: Set<String> = [
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "mondays", "tuesdays", "wednesdays", "thursdays", "fridays", "saturdays", "sundays", "weekends"
    ]
    private static let monthsAndSeasons: Set<String> = [
        "january", "february", "march", "april", "may", "june", "july", "august", "september",
        "october", "november", "december", "spring", "summer", "autumn", "winter"
    ]
    private static let atTimeWords: Set<String> = ["night", "noon", "midnight", "dawn", "dusk", "sunrise", "sunset"]
    private static let partsOfDay: Set<String> = ["morning", "afternoon", "evening"]

    /// The preposition decoy for the token at `index` of `keys` (all lower-case tile keys).
    static func prepositionDecoy(keys: [String], at index: Int) -> String? {
        guard let key = keys[safe: index] else { return nil }
        let previous = index > 0 ? (keys[safe: index - 1] ?? "") : ""
        let next = keys[safe: index + 1] ?? ""
        let afterNext = keys[safe: index + 2] ?? ""
        for rule in collocations where rule.preposition == key && rule.previous.contains(previous) {
            return rule.decoy
        }
        // look forward to → for
        if key == "to", previous == "forward", index > 1, let verb = keys[safe: index - 2], lookForms.contains(verb) {
            return "for"
        }
        switch key {
        case "at":
            if atTimeWords.contains(next) || next.first?.isNumber == true { return "on" }
        case "on":
            if weekdays.contains(next) { return "in" }
        case "in":
            if monthsAndSeasons.contains(next) || isYear(next) { return "on" }
            if next == "the" && partsOfDay.contains(afterNext) { return "at" }
        default:
            break
        }
        return nil
    }

    private static func isYear(_ key: String) -> Bool {
        key.count == 4 && key.allSatisfy { (character: Character) -> Bool in character.isNumber }
    }

    // MARK: Articles

    private static let determiners: Set<String> = [
        "the", "my", "your", "his", "her", "its", "our", "their", "this", "that", "these", "those",
        "some", "any", "no", "every", "each", "another"
    ]

    /// „a” ↔ „an” — only with exactly one indefinite article and no other determiner.
    static func articleDecoy(keys: [String]) -> String? {
        let articles = keys.filter { (key: String) -> Bool in key == "a" || key == "an" }
        guard articles.count == 1, let article = articles.first,
              !keys.contains(where: { (key: String) -> Bool in determiners.contains(key) }) else { return nil }
        return article == "a" ? "an" : "a"
    }

    // MARK: Content words

    /// Content words of `sentences` usable as decoys: lower-case, at least four letters, never a
    /// function word, a key already used or a word sharing a stem with a word of the sentence.
    static func contentWords(from sentences: [String], sentenceKeys: Set<String>, used: inout Set<String>) -> [String] {
        var result: [String] = []
        for sentence in sentences {
            for token in SentenceScramble.tokens(sentence) {
                let tokenKey = SentenceScramble.key(token)
                guard tokenKey.count >= 4, !SentenceScramble.functionWords.contains(tokenKey),
                      let firstCharacter = token.first, firstCharacter.isLowercase,
                      token.allSatisfy({ (character: Character) -> Bool in character.isLetter || character == "'" || character == "-" }),
                      !sharesStem(tokenKey, with: sentenceKeys),
                      used.insert(tokenKey).inserted else { continue }
                result.append(token)
            }
        }
        return result
    }

    /// `true` when the word and a word of the sentence start with the same four letters
    /// („borrowed” / „borrow”) — another form of a sentence word could be correct.
    static func sharesStem(_ key: String, with sentenceKeys: Set<String>) -> Bool {
        guard key.count >= 4 else { return false }
        let stem = key.prefix(4)
        return sentenceKeys.contains { (other: String) -> Bool in other.count >= 4 && other.prefix(4) == stem }
    }

    // MARK: Choice

    /// Decoys for a sentence (`answer` — the tile texts in order), at most `count`, in priority
    /// order: grammatical decoys first (forms of the focus expression before other words), then
    /// words from the entry's other examples, then words from `pool` (other words' examples).
    static func choose<G: RandomNumberGenerator>(
        answer: [String],
        focusKeys: Set<String>,
        entrySentences: [String],
        pool: [String],
        count: Int,
        using rng: inout G
    ) -> [ScrambleDecoy] {
        guard count > 0 else { return [] }
        let keys = answer.map { (token: String) -> String in SentenceScramble.key(token) }
        let sentenceKeys = Set(keys)
        var used = sentenceKeys
        var groups: [[ScrambleDecoy]] = []

        var focusForms: [ScrambleDecoy] = []
        var otherForms: [ScrambleDecoy] = []
        var prepositions: [ScrambleDecoy] = []
        for (index, key) in keys.enumerated() {
            let previous = index > 0 ? keys[index - 1] : ""
            if let form = verbFormDecoy(for: key, previous: previous), used.insert(form).inserted {
                let decoy = ScrambleDecoy(text: form, kind: .verbForm)
                if focusKeys.contains(key) { focusForms.append(decoy) } else { otherForms.append(decoy) }
            }
            if let preposition = prepositionDecoy(keys: keys, at: index), used.insert(preposition).inserted {
                prepositions.append(ScrambleDecoy(text: preposition, kind: .preposition))
            }
        }
        shuffle(&otherForms, using: &rng)
        shuffle(&prepositions, using: &rng)
        groups.append(focusForms + otherForms)
        groups.append(prepositions)
        if let article = articleDecoy(keys: keys), used.insert(article).inserted {
            groups.append([ScrambleDecoy(text: article, kind: .article)])
        }
        var entryWords = contentWords(from: entrySentences, sentenceKeys: sentenceKeys, used: &used)
        shuffle(&entryWords, using: &rng)
        groups.append(entryWords.map { (text: String) -> ScrambleDecoy in ScrambleDecoy(text: text, kind: .sameEntry) })
        var poolWords = contentWords(from: pool, sentenceKeys: sentenceKeys, used: &used)
        shuffle(&poolWords, using: &rng)
        groups.append(poolWords.map { (text: String) -> ScrambleDecoy in ScrambleDecoy(text: text, kind: .otherWord) })

        // Round robin over the groups: a board with two decoys shows two different kinds when it can.
        var chosen: [ScrambleDecoy] = []
        var round = 0
        while chosen.count < count {
            var added = false
            for group in groups where chosen.count < count {
                if let decoy = group[safe: round] {
                    chosen.append(decoy)
                    added = true
                }
            }
            if !added { break }
            round += 1
        }
        return chosen
    }

    private static func shuffle<T, G: RandomNumberGenerator>(_ items: inout [T], using rng: inout G) {
        var position = items.count - 1
        while position > 0 {
            let other = rng.nextIndex(below: position + 1)
            items.swapAt(position, other)
            position -= 1
        }
    }
}
