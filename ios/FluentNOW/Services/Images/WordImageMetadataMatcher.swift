import Foundation

/// How strongly the title and tags of a photo point to the word (layer 1 of the verification).
enum WordImageMetadataMatch: Int, Codable, Sendable, Comparable {
    /// Neither the title nor the tags name the word (or they name another sense / a drawing).
    case unmatched = 0
    /// Only a user tag names the word (Flickr tags are often about the camera or the trip).
    case weak = 1
    /// The title names the word as the subject, or a machine tag (≥ 90 %) does.
    case strong = 2

    static func < (lhs: WordImageMetadataMatch, rhs: WordImageMetadataMatch) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Result of checking one photo's title and tags.
struct WordImageMetadataEvaluation: Sendable, Equatable {
    var match: WordImageMetadataMatch
    /// Ranking score (higher = better candidate).
    var score: Int
    /// Short English code for diagnostics (`title`, `machine-tag`, `drawing`, `other-sense`…).
    var note: String
}

/// Title / tag matching of Openverse results (pure, testable).
///
/// Live data (2026-10-18) showed why a plain „title or tag contains the query” check let wrong
/// photos through: „2021-phone-favourites-089” (a fireplace shot *with* a phone), „Phone Booth”,
/// „Mickey Mouse” toys, „Apple Mac” computers, Hubble's „Bat Shadow”, „Apple tree”, vintage bat
/// etchings tagged as photographs.
enum WordImageMetadataMatcher {
    /// Sources with clean, captioned stock photos (titles such as „Mobile Phone”, „Crane Bird”).
    static let curatedSources: Set<String> = ["stocksnap", "rawpixel", "wikimedia"]

    /// Phrases that describe how the photo was taken, not what it shows (text in parentheses —
    /// „Thunderhole (cell phone)” — is dropped before matching as well).
    static let cameraPhrases: [[String]] = [
        ["phone", "favourites"], ["phone", "favorites"], ["cell", "phone", "pic"], ["cellphone", "pic"],
        ["phone", "pic"], ["phone", "pics"], ["iphone", "photo"], ["iphone", "pic"], ["shot", "on", "iphone"],
        ["shot", "on", "phone"], ["shot", "with", "iphone"], ["taken", "with"], ["mobile", "upload"],
        ["camera", "phone"], ["phoneography"], ["via", "instagram"], ["instagram"], ["phone", "dump"]
    ]

    /// Nouns that make „<word> X” a different thing („apple tree”, „bat shadow”, „phone booth”).
    static let compoundHeads: Set<String> = Set([
        "tree", "trees", "pie", "pies", "juice", "shadow", "lemur", "bird", "booth", "box", "case", "cover",
        "holder", "stand", "charger", "logo", "store", "shop", "sign", "costume", "toy", "toys", "cake",
        "sauce", "cactus", "pattern", "print", "sticker", "wallpaper", "background", "nebula", "festival",
        "day", "week", "ornament", "decoration", "figurine", "statue", "sculpture", "model", "drawing",
        "illustration", "painting", "mural", "museum", "street", "road", "river", "lake", "park", "house",
        "farm", "orchard", "blossom", "blossoms", "flower", "flowers", "field", "fields", "lighthouse",
        "pass", "kit", "eggs", "neon", "balloon", "balloons", "factory", "plant", "company", "brand", "club"
    ] as [String])

    /// Words before the term that turn it into a character, brand or toy.
    static let compoundModifiers: Set<String> = Set([
        "mickey", "minnie", "mighty", "lego", "toy", "origami", "cartoon", "stuffed", "plush", "crab", "sea"
    ] as [String])

    /// Signs of a drawing, print or render (category `photograph` is not always right).
    static let drawingWords: Set<String> = Set([
        "illustration", "illustrations", "drawing", "drawings", "etching", "engraving", "sketch", "painting",
        "watercolor", "watercolour", "cartoon", "vector", "clipart", "lithograph", "chromolithograph",
        "woodcut", "render", "rendering", "3d", "lego", "emoji", "icon", "logo", "diagram", "poster",
        "origami", "infographic", "mural", "embroidery", "papercraft", "figurine", "toy"
    ] as [String])

    /// Words that mean people are the subject (penalised for things).
    static let peopleWords: Set<String> = Set([
        "man", "woman", "girl", "boy", "people", "person", "portrait", "selfie", "guy", "lady", "child", "kid",
        "couple", "family", "crowd", "model", "mayor", "ceo", "officer", "minister", "president"
    ] as [String])

    /// Checks one photo against the term (title + user tags + machine tags).
    static func evaluate(_ record: WordImageRecord, profile: WordImageTermProfile) -> WordImageMetadataEvaluation {
        let titleTokens = cleanedTokens(record.title)
        let userTags = record.tags ?? []
        let machineTags = record.machineTags ?? []
        let tagTokens = Set(userTags.flatMap { (tag: String) -> [String] in WordImageText.tokens(tag) })
        let allTokens = Set(titleTokens).union(tagTokens)
        let termTokens = Set(profile.words)
        // Another sense or a brand („apple” + mac/iphone, „mouse” + mickey).
        // Plurals count too („Sandhill Crane” tagged „birds” is not a construction crane).
        let avoidHit = !profile.avoidWords.isEmpty && allTokens.contains { (token: String) -> Bool in
            profile.avoidWords.contains(token)
                || (token.count > 3 && token.hasSuffix("s") && profile.avoidWords.contains(String(token.dropLast())))
        }
        if avoidHit {
            return WordImageMetadataEvaluation(match: .unmatched, score: 0, note: "other-sense")
        }
        // A drawing / render / toy, unless the word itself is such a thing.
        let drawing = drawingWords.subtracting(termTokens)
        if !drawing.isDisjoint(with: allTokens) {
            return WordImageMetadataEvaluation(match: .unmatched, score: 0, note: "drawing")
        }
        let phrases = [profile.words] + profile.synonyms
        // „Crane Bird” is the bird sense, not a compound — words of the query are fine after the term.
        let allowed = Set(WordImageText.tokens(profile.query))
        let inTitle = phrases.contains { (phrase: [String]) -> Bool in
            containsSubject(titleTokens, phrase: phrase, allowedNext: allowed)
        }
        let inMachine = machineTags.contains { (tag: String) -> Bool in
            phrases.contains { (phrase: [String]) -> Bool in tagMatches(tag, phrase: phrase, allowedNext: allowed) }
        }
        // Tag soup (dozens of unrelated tags) proves nothing.
        let usableUserTags = userTags.count <= 40 ? userTags : []
        let inUserTags = usableUserTags.contains { (tag: String) -> Bool in
            phrases.contains { (phrase: [String]) -> Bool in tagMatches(tag, phrase: phrase, allowedNext: allowed) }
        }
        var score = 0
        var note = "none"
        if inTitle {
            score += 30
            note = "title"
            if titleTokens.filter({ (token: String) -> Bool in !token.isEmpty }).count <= 4 {
                score += 5
            }
        }
        if inMachine {
            score += 20
            if note == "none" { note = "machine-tag" }
        }
        if inUserTags {
            score += 10
            if note == "none" { note = "user-tag" }
        }
        let match: WordImageMetadataMatch = (inTitle || inMachine) ? .strong : (inUserTags ? .weak : .unmatched)
        guard match != .unmatched else {
            return WordImageMetadataEvaluation(match: .unmatched, score: 0, note: note)
        }
        if curatedSources.contains(record.provider.lowercased()) {
            score += 5
        }
        let personSubject = profile.subject == .person || profile.subject == .wearable
        if !personSubject, !peopleWords.subtracting(termTokens).isDisjoint(with: allTokens) {
            score -= 8
        }
        return WordImageMetadataEvaluation(match: match, score: score, note: note)
    }

    // MARK: Pieces (internal for tests)

    /// Title words without text in parentheses and with camera phrases blanked out (positions
    /// kept, so adjacency still works).
    static func cleanedTokens(_ title: String) -> [String] {
        var tokens = WordImageText.tokens(withoutParentheses(title))
        for phrase in cameraPhrases where !phrase.isEmpty && phrase.count <= tokens.count {
            var index = 0
            while index + phrase.count <= tokens.count {
                if Array(tokens[index..<(index + phrase.count)]) == phrase {
                    for position in index..<(index + phrase.count) {
                        tokens[position] = ""
                    }
                    index += phrase.count
                } else {
                    index += 1
                }
            }
        }
        return tokens
    }

    /// „Thunderhole (cell phone)” → „Thunderhole ” (an unclosed parenthesis cuts the rest).
    static func withoutParentheses(_ text: String) -> String {
        var result = ""
        var depth = 0
        for character in text {
            if character == "(" || character == "[" {
                depth += 1
            } else if character == ")" || character == "]" {
                depth = max(0, depth - 1)
            } else if depth == 0 {
                result.append(character)
            }
        }
        return result
    }

    /// `true` when `phrase` occurs in `tokens` as the subject: whole words (last word in any
    /// singular/plural form, or the words joined — „cellphone”), not followed by a noun that makes
    /// it another thing (unless that noun is in `allowedNext`) and not preceded by a
    /// character/brand word.
    static func containsSubject(_ tokens: [String], phrase: [String], allowedNext: Set<String> = []) -> Bool {
        guard let last = phrase.last, !tokens.isEmpty else { return false }
        let lastForms = WordImageText.forms(of: last)
        let joined = phrase.joined()
        let joinedForms = phrase.count > 1 ? WordImageText.forms(of: joined) : []
        for start in tokens.indices {
            var end = start
            if phrase.count > 1, joinedForms.contains(tokens[start]) {
                end = start
            } else {
                guard start + phrase.count <= tokens.count else { continue }
                var matches = true
                for (offset, word) in phrase.enumerated() {
                    let token = tokens[start + offset]
                    let ok = offset == phrase.count - 1 ? lastForms.contains(token) : token == word
                    if !ok {
                        matches = false
                        break
                    }
                }
                guard matches else { continue }
                end = start + phrase.count - 1
            }
            let next = end + 1 < tokens.count ? tokens[end + 1] : ""
            let previous = start > 0 ? tokens[start - 1] : ""
            let compound = compoundHeads.contains(next) && !allowedNext.contains(next)
            if compound || compoundModifiers.contains(previous) {
                continue
            }
            return true
        }
        return false
    }

    /// A tag names the phrase: the same words („cell phone”, „mobile phone”), the joined form
    /// („cellphone”) or the phrase plus one qualifier („bat animal”, not „bat shadow”).
    static func tagMatches(_ tag: String, phrase: [String], allowedNext: Set<String> = []) -> Bool {
        let tokens = WordImageText.tokens(tag)
        guard !tokens.isEmpty, tokens.count <= phrase.count + 1 else { return false }
        if tokens.count == 1 && phrase.count > 1 {
            return WordImageText.forms(of: phrase.joined()).contains(tokens[0])
        }
        return containsSubject(tokens, phrase: phrase, allowedNext: allowedNext)
    }
}

/// Layer 1 applied to a whole search: keeps photos whose title/tags name the word and orders
/// them best first (stock titles, machine tags, curated sources).
enum WordImageCandidateFilter {
    /// - Parameter requireStrong: `true` when Vision cannot confirm the word later (no identifier
    ///   in its taxonomy) — then a user tag alone is not enough.
    static func rank(_ records: [WordImageRecord], profile: WordImageTermProfile, requireStrong: Bool) -> [WordImageRecord] {
        let minimum: WordImageMetadataMatch = requireStrong ? .strong : .weak
        var scored: [Scored] = []
        var seen = Set<String>()
        for (index, record) in records.enumerated() where !seen.contains(record.id) {
            seen.insert(record.id)
            let evaluation = WordImageMetadataMatcher.evaluate(record, profile: profile)
            guard evaluation.match >= minimum else { continue }
            scored.append(Scored(record: record, score: evaluation.score, index: index))
        }
        scored.sort { (lhs: Scored, rhs: Scored) -> Bool in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.index < rhs.index
        }
        return scored.map { (item: Scored) -> WordImageRecord in item.record }
    }

    private struct Scored {
        var record: WordImageRecord
        var score: Int
        var index: Int
    }
}

/// One Openverse search of an attempt.
struct WordImageQueryPlan: Sendable, Equatable {
    var query: String
    /// `nil` = all sources.
    var sources: [String]?
}

/// Search attempts of one meaning (each attempt is one search; after the last one without a
/// verified photo the meaning is marked „bez zdjęcia” for good).
enum WordImageQueryPlanner {
    static let maxAttempts = 3

    /// 0: refined query on curated stock sources (clean captions: „Mobile Phone”, „Crane Bird”);
    /// 1: the same query on all sources; 2: a synonym or the plain term, all sources.
    static func plan(attempt: Int, profile: WordImageTermProfile) -> WordImageQueryPlan? {
        switch attempt {
        case 0:
            return WordImageQueryPlan(query: profile.query, sources: WordImageMetadataMatcher.curatedSources.sorted())
        case 1:
            return WordImageQueryPlan(query: profile.query, sources: nil)
        case 2:
            guard let alternative = profile.alternativeQuery, !alternative.isEmpty, alternative != profile.query else { return nil }
            return WordImageQueryPlan(query: alternative, sources: nil)
        default:
            return nil
        }
    }
}
