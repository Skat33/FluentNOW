import Foundation

/// One derivation between two words of a family: `derived` = `base` + affix (with spelling changes).
public struct WordFamilyLink: Sendable, Hashable {
    public var base: String
    public var derived: String
    /// The affix, e.g. `-ion`, `-ly`, `un-`.
    public var affix: String

    public init(base: String, derived: String, affix: String) {
        self.base = base
        self.derived = derived
        self.affix = affix
    }
}

/// A relative of a word: `distance` 1 = direct derivation (decide → decision),
/// 2 = through one other word (comfort → comfortable → comfortably).
public struct WordFamilyMember: Sendable, Hashable {
    public var key: String
    public var distance: Int

    public init(key: String, distance: Int) {
        self.key = key
        self.distance = distance
    }
}

/// Word families (FEEDBACK-3 H4): a morphological heuristic over single-word dictionary keys.
///
/// A word is linked to a base when stripping a known English suffix (with the usual spelling
/// changes: e-drop, y → i, doubled consonant) or prefix gives another dictionary word. Noisy
/// affixes are checked against the Polish translation (agent nouns `-er`/`-or` need a verb base;
/// negating prefixes need „nie…/bez…”; `re-` needs „ponownie/prze…/od…”; `mis-` needs „źle”),
/// short bases are not allowed for one- and two-letter suffixes (unless the consonant doubled:
/// win → winner), and accidental pairs are listed in `falsePairs` (corner/corn, party/part, …).
public enum WordFamily {
    /// Extra check of a link (uses the Polish translations of the dictionary).
    enum Condition: Sendable {
        case none
        /// The base must be a verb (Polish infinitive), e.g. drive → driver.
        case verbBase
        /// The derived word must be a negation in Polish, e.g. patient → impatient („niecierpliwy”).
        case negative
        /// The derived word must mean „again / re-”, e.g. heat → reheat („odgrzać”).
        case repetition
        /// The derived word must mean „wrongly”, e.g. pronounce → mispronounce („źle wymawiać”).
        case wrongly
    }

    struct SuffixRule: Sendable {
        let suffix: String
        /// Possible endings of the base that replace the suffix ("" = plain removal).
        let baseEndings: [String]
        let condition: Condition
    }

    struct PrefixRule: Sendable {
        let prefix: String
        let condition: Condition
    }

    struct BaseCandidate: Sendable, Hashable {
        let base: String
        let affix: String
        let condition: Condition
    }

    static let suffixRules: [SuffixRule] = [
        SuffixRule(suffix: "ation", baseEndings: ["", "e", "ate"], condition: .none),
        SuffixRule(suffix: "ition", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ication", baseEndings: ["y"], condition: .none),
        SuffixRule(suffix: "ion", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ision", baseEndings: ["ide"], condition: .none),
        SuffixRule(suffix: "usion", baseEndings: ["ude", "use"], condition: .none),
        SuffixRule(suffix: "ission", baseEndings: ["it"], condition: .none),
        SuffixRule(suffix: "ption", baseEndings: ["be", "ve"], condition: .none),
        SuffixRule(suffix: "anation", baseEndings: ["ain"], condition: .none),
        SuffixRule(suffix: "ment", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ness", baseEndings: [""], condition: .none),
        SuffixRule(suffix: "iness", baseEndings: ["y"], condition: .none),
        SuffixRule(suffix: "ity", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ality", baseEndings: ["al"], condition: .none),
        SuffixRule(suffix: "ility", baseEndings: ["le", "ile"], condition: .none),
        SuffixRule(suffix: "er", baseEndings: ["", "e"], condition: .verbBase),
        SuffixRule(suffix: "or", baseEndings: ["", "e"], condition: .verbBase),
        SuffixRule(suffix: "ier", baseEndings: ["y"], condition: .verbBase),
        SuffixRule(suffix: "ist", baseEndings: ["", "e", "y"], condition: .none),
        SuffixRule(suffix: "ful", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "iful", baseEndings: ["y"], condition: .none),
        SuffixRule(suffix: "less", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ous", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ious", baseEndings: ["y"], condition: .none),
        SuffixRule(suffix: "ive", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ative", baseEndings: ["", "e", "ate"], condition: .none),
        SuffixRule(suffix: "sive", baseEndings: ["d", "de"], condition: .none),
        SuffixRule(suffix: "able", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "iable", baseEndings: ["y"], condition: .none),
        SuffixRule(suffix: "ible", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "al", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ial", baseEndings: ["y"], condition: .none),
        SuffixRule(suffix: "ical", baseEndings: ["ic", "y"], condition: .none),
        SuffixRule(suffix: "ly", baseEndings: ["", "le"], condition: .none),
        SuffixRule(suffix: "ily", baseEndings: ["y"], condition: .none),
        SuffixRule(suffix: "ally", baseEndings: ["", "al"], condition: .none),
        SuffixRule(suffix: "bly", baseEndings: ["ble"], condition: .none),
        SuffixRule(suffix: "ize", baseEndings: ["", "e", "y"], condition: .none),
        SuffixRule(suffix: "en", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "y", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ic", baseEndings: ["", "e", "y"], condition: .none),
        SuffixRule(suffix: "ance", baseEndings: ["", "e", "ant"], condition: .none),
        SuffixRule(suffix: "ence", baseEndings: ["", "e", "ent"], condition: .none),
        SuffixRule(suffix: "ancy", baseEndings: ["ant"], condition: .none),
        SuffixRule(suffix: "ency", baseEndings: ["ent"], condition: .none),
        SuffixRule(suffix: "ship", baseEndings: [""], condition: .none),
        SuffixRule(suffix: "hood", baseEndings: [""], condition: .none),
        SuffixRule(suffix: "th", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ty", baseEndings: [""], condition: .none),
        SuffixRule(suffix: "ure", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "age", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "iage", baseEndings: ["y"], condition: .none),
        SuffixRule(suffix: "ant", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ent", baseEndings: ["", "e"], condition: .none),
        SuffixRule(suffix: "ee", baseEndings: [""], condition: .none),
        SuffixRule(suffix: "ing", baseEndings: ["", "e"], condition: .none)
    ]

    static let prefixRules: [PrefixRule] = [
        PrefixRule(prefix: "un", condition: .none),
        PrefixRule(prefix: "dis", condition: .negative),
        PrefixRule(prefix: "in", condition: .negative),
        PrefixRule(prefix: "im", condition: .negative),
        PrefixRule(prefix: "ir", condition: .negative),
        PrefixRule(prefix: "il", condition: .negative),
        PrefixRule(prefix: "re", condition: .repetition),
        PrefixRule(prefix: "mis", condition: .wrongly)
    ]

    /// Pairs that look derived but are not one family for a learner (`derived|base`),
    /// found by reviewing every link the rules produce on `dictionary-index.json`.
    public static let falsePairs: Set<String> = [
        "apply|apple", "carry|car", "copy|cope", "bitter|bite", "copper|cope", "sewer|sew", "sweater|sweat",
        "pastor|paste", "counter|count", "drawer|draw", "dresser|dress", "stretcher|stretch",
        "festival|festive", "final|fine", "signal|sign", "sectional|section", "dental|dent",
        "currency|current", "grateful|grate", "organic|organ", "organize|organ", "rustic|rust",
        "rustic|rusty", "audition|audit", "mission|miss", "passion|pass", "petition|petite", "petition|pet",
        "portion|port", "recession|recess", "version|verse", "position|pose", "tradition|trade",
        "cavity|cave", "university|universe", "objective|object", "commission|commit",
        "conservative|conserve", "flexible|flex", "finally|fin", "linen|line", "pollen|poll", "baby|babe",
        "belly|bell", "bully|bull", "directory|director", "musty|must", "party|part", "policy|police",
        "ready|read", "scary|scar", "shiny|shin", "story|store", "sunday|sundae", "tidy|tide",
        "treaty|treat", "early|ear", "earth|ear", "reply|rep",
        "report|port", "request|quest", "research|search", "resign|sign", "resort|sort", "restore|store",
        "retire|tire", "retired|tired", "revenue|venue", "review|view", "release|lease", "reliable|liable",
        "recover|cover", "reflex|flex", "reform|form", "resolve|solve", "recall|call", "reproduce|produce",
        "discard|card", "discharge|charge", "discount|count", "discover|cover", "dissolve|solve",
        "inside|side", "install|stall", "insure|sure", "invoice|voice", "import|port", "impose|pose",
        "improve|prove", "implant|plant", "missing|sing", "mistake|take", "uncover|cover",
        "caption|cave", "indie|die", "comforter|comfort", "caring|car", "bandage|band", "cabbage|cab",
        "message|mess", "burpee|burp", "referee|refer", "fluent|flu", "mature|mat", "pasture|past",
        "pasture|paste", "posture|post", "padding|pad", "happening|happen",
        "return|turn", "majority|major"
    ]

    /// Polish verbs whose infinitive ends in „-c” (most end in „-ć”).
    static let polishVerbsInC: [String] = ["biec", "móc", "piec", "wlec", "strzec", "rzec", "ciec", "tłuc", "siec"]

    /// A key the heuristic works on: one lowercase ASCII word of at least 3 letters.
    public static func isWordKey(_ key: String) -> Bool {
        key.utf8.count >= 3 && key.utf8.allSatisfy { (unit: UInt8) -> Bool in unit >= 97 && unit <= 122 }
    }

    /// Possible bases of `word` (each is a family link if it is also a dictionary word and the
    /// condition holds). Empty for keys that are not single words.
    static func baseCandidates(of word: String) -> [BaseCandidate] {
        guard isWordKey(word) else { return [] }
        var result: [BaseCandidate] = []
        let length = word.count
        for rule in suffixRules where word.hasSuffix(rule.suffix) {
            let stemLength = length - rule.suffix.count
            guard stemLength >= 2 else { continue }
            let stem = String(word.prefix(stemLength))
            // One- and two-letter suffixes are noisy on short words (ear → early, leg → legal).
            let minimumBase = rule.suffix.count <= 2 ? 4 : 3
            let affix = "-" + rule.suffix
            for ending in rule.baseEndings {
                let base = stem + ending
                if base != word && base.count >= minimumBase {
                    result.append(BaseCandidate(base: base, affix: affix, condition: rule.condition))
                }
            }
            // Doubled final consonant: win → winner, chat → chatty, cancel → cancellation.
            let letters = Array(stem.utf8)
            if letters.count >= 3, let last = letters.last, letters[letters.count - 2] == last, !Self.isVowelLike(last) {
                let base = String(stem.dropLast())
                if base.count >= 3 {
                    result.append(BaseCandidate(base: base, affix: affix, condition: rule.condition))
                }
            }
        }
        for rule in prefixRules where word.hasPrefix(rule.prefix) && length - rule.prefix.count >= 3 {
            let base = String(word.dropFirst(rule.prefix.count))
            result.append(BaseCandidate(base: base, affix: rule.prefix + "-", condition: rule.condition))
        }
        return result
    }

    /// Possible bases of a word (for diagnostics and tests).
    public static func possibleBases(of word: String) -> [String] {
        baseCandidates(of: word).map { $0.base }
    }

    /// a, e, i, o, u, w, x, y — letters that do not double before a suffix.
    private static func isVowelLike(_ unit: UInt8) -> Bool {
        switch unit {
        case 97, 101, 105, 111, 117, 119, 120, 121: return true
        default: return false
        }
    }

    /// Whether a candidate link is accepted. Translations: Polish meanings of each word
    /// (empty when unknown — then conditions that need them fail).
    static func accepts(_ candidate: BaseCandidate, derived: String, baseTranslations: [String], derivedTranslations: [String]) -> Bool {
        if falsePairs.contains(derived + "|" + candidate.base) { return false }
        switch candidate.condition {
        case .none:
            return true
        case .verbBase:
            return baseTranslations.contains { (text: String) -> Bool in isPolishVerb(text) }
        case .negative:
            return derivedTranslations.contains { (text: String) -> Bool in isPolishNegative(text) }
        case .repetition:
            return derivedTranslations.contains { (text: String) -> Bool in isPolishRepetition(text) }
        case .wrongly:
            return derivedTranslations.contains { (text: String) -> Bool in isPolishWrongly(text) }
        }
    }

    /// All family links between the given words (`key` → Polish translations of its meanings).
    public static func links(translations: [String: [String]]) -> [WordFamilyLink] {
        var result: [WordFamilyLink] = []
        for word in translations.keys.sorted() {
            var seen = Set<String>()
            let own = translations[word] ?? []
            for candidate in baseCandidates(of: word) {
                guard let baseTranslations = translations[candidate.base], !seen.contains(candidate.base) else { continue }
                guard accepts(candidate, derived: word, baseTranslations: baseTranslations, derivedTranslations: own) else { continue }
                seen.insert(candidate.base)
                result.append(WordFamilyLink(base: candidate.base, derived: word, affix: candidate.affix))
            }
        }
        return result
    }

    // MARK: Polish part-of-speech hints

    /// Lowercase words of a Polish translation without parenthesised notes.
    static func polishTokens(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var depth = 0
        for character in text.lowercased() {
            if character == "(" {
                depth += 1
            } else if character == ")" {
                depth = max(0, depth - 1)
            } else if depth == 0 && character.isLetter {
                current.append(character)
                continue
            }
            if !current.isEmpty {
                tokens.append(current)
                current = ""
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// „zdecydować (się)”, „biec” — a Polish infinitive.
    public static func isPolishVerb(_ translation: String) -> Bool {
        guard let first = polishTokens(translation).first(where: { (token: String) -> Bool in token != "się" }) else { return false }
        if first.hasSuffix("ć") { return true }
        return polishVerbsInC.contains { (verb: String) -> Bool in first.hasSuffix(verb) }
    }

    /// „niecierpliwy”, „nie zgadzać się”, „bez motywacji”.
    static func isPolishNegative(_ translation: String) -> Bool {
        polishTokens(translation).contains { (token: String) -> Bool in
            token == "nie" || token == "bez" || (token.count > 5 && (token.hasPrefix("nie") || token.hasPrefix("bez")))
        }
    }

    /// „ponownie podłączyć”, „przebukować”, „odgrzać”, „renegocjować”.
    static func isPolishRepetition(_ translation: String) -> Bool {
        let tokens = polishTokens(translation)
        if tokens.contains(where: { (token: String) -> Bool in token == "ponownie" || token == "znowu" || token == "zmienić" }) {
            return true
        }
        guard let first = tokens.first else { return false }
        return first.hasPrefix("prze") || first.hasPrefix("od") || first.hasPrefix("re")
    }

    /// „źle wymawiać”, „wprowadzać w błąd”.
    static func isPolishWrongly(_ translation: String) -> Bool {
        polishTokens(translation).contains { (token: String) -> Bool in
            token == "źle" || token.hasPrefix("błąd") || token.hasPrefix("błęd")
        }
    }

    // MARK: Forms

    /// Past participles from a word's `forms` („break – broke – broken” → ["broken"]) — they are
    /// often adjectives of their own (broken, frozen, stolen). Only single words ending in „n”.
    public static func participles(fromForms forms: String, of key: String) -> [String] {
        guard !forms.isEmpty else { return [] }
        var result: [String] = []
        var token = ""
        func flush() {
            if token.count >= 4, token != key, token.hasSuffix("n"), isWordKey(token), !result.contains(token) {
                result.append(token)
            }
            token = ""
        }
        for character in forms.lowercased() {
            if let ascii = character.asciiValue, ascii >= 97, ascii <= 122 {
                token.append(character)
            } else {
                flush()
            }
        }
        flush()
        return result
    }
}

/// Family links of the built-in dictionary, built once (off the main thread) from
/// `dictionary-index.json`; every lookup afterwards is a few dictionary reads (well under 1 ms).
public struct WordFamilyIndex: Sendable {
    /// Word → directly linked words (sorted).
    private let neighbors: [String: [String]]
    /// Words of the dictionary (single-word keys) → Polish translations.
    private let translations: [String: [String]]
    /// Base strings that are not dictionary words → dictionary words derived from them (for a
    /// learner's own word that the dictionary does not have: useful → usefulness).
    private let derivedFromUnknown: [String: [String]]
    /// Number of links.
    public let linkCount: Int

    public init(entries: [DictionaryIndex.Entry]) {
        var map: [String: [String]] = [:]
        for entry in entries {
            let key = entry.key.isEmpty ? TextNormalizer.searchKey(entry.term) : entry.key
            guard WordFamily.isWordKey(key) else { continue }
            map[key, default: []].append(entry.translation)
        }
        self.init(translations: map)
    }

    /// `translations`: single-word key → Polish translations of its meanings.
    public init(translations: [String: [String]]) {
        var words: [String: [String]] = [:]
        for (key, values) in translations where WordFamily.isWordKey(key) {
            words[key] = values
        }
        let links = WordFamily.links(translations: words)
        var adjacency: [String: Set<String>] = [:]
        for link in links {
            adjacency[link.base, default: []].insert(link.derived)
            adjacency[link.derived, default: []].insert(link.base)
        }
        var sorted: [String: [String]] = [:]
        for (key, values) in adjacency {
            sorted[key] = values.sorted()
        }
        var unknown: [String: Set<String>] = [:]
        for word in words.keys {
            let own = words[word] ?? []
            for candidate in WordFamily.baseCandidates(of: word) where words[candidate.base] == nil {
                // The base's translation is unknown, so a verb base cannot be checked.
                guard candidate.condition != .verbBase,
                      WordFamily.accepts(candidate, derived: word, baseTranslations: [], derivedTranslations: own) else { continue }
                unknown[candidate.base, default: []].insert(word)
            }
        }
        var unknownSorted: [String: [String]] = [:]
        for (key, values) in unknown {
            unknownSorted[key] = values.sorted()
        }
        neighbors = sorted
        self.translations = words
        derivedFromUnknown = unknownSorted
        linkCount = links.count
    }

    /// Number of single-word dictionary keys.
    public var wordCount: Int { translations.count }

    /// Number of words that belong to some family.
    public var familyWordCount: Int { neighbors.count }

    public func contains(_ key: String) -> Bool {
        translations[key] != nil
    }

    /// Directly linked dictionary words (sorted). Works also for a key the dictionary does not
    /// have (a learner's own word): its bases and derivations that are dictionary words.
    public func relatives(of key: String) -> [String] {
        if translations[key] != nil {
            return neighbors[key] ?? []
        }
        guard WordFamily.isWordKey(key) else { return [] }
        var found = Set<String>(derivedFromUnknown[key] ?? [])
        for candidate in WordFamily.baseCandidates(of: key) {
            guard let baseTranslations = translations[candidate.base] else { continue }
            if WordFamily.accepts(candidate, derived: key, baseTranslations: baseTranslations, derivedTranslations: []) {
                found.insert(candidate.base)
            }
        }
        found.remove(key)
        return found.sorted()
    }

    /// The family of a word up to `maxDistance` links away (without the word itself), closest
    /// first, then alphabetically. decide → [decision]; comfort → [comfortable, comfortably²].
    public func family(of key: String, maxDistance: Int = 2) -> [WordFamilyMember] {
        guard maxDistance > 0 else { return [] }
        var distances: [String: Int] = [key: 0]
        var result: [WordFamilyMember] = []
        var frontier = [key]
        var distance = 1
        while distance <= maxDistance && !frontier.isEmpty {
            var next: [String] = []
            for word in frontier {
                let linked = distance == 1 ? relatives(of: word) : (neighbors[word] ?? [])
                for relative in linked where distances[relative] == nil {
                    distances[relative] = distance
                    next.append(relative)
                }
            }
            next.sort()
            for word in next {
                result.append(WordFamilyMember(key: word, distance: distance))
            }
            frontier = next
            distance += 1
        }
        return result
    }

    /// Whether two words are in one family (at most `maxDistance` links apart).
    public func areRelated(_ first: String, _ second: String, maxDistance: Int = 2) -> Bool {
        first != second && family(of: first, maxDistance: maxDistance).contains { (member: WordFamilyMember) -> Bool in member.key == second }
    }
}
