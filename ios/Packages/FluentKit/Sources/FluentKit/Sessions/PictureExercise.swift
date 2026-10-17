import Foundation

/// A meaning whose photo should be fetched in the background (G2).
public struct PictureCandidate: Sendable, Hashable, Identifiable {
    public var wordId: String
    public var meaningId: String
    public var term: String
    /// Search phrase for the photo service (term without labels, articles and placeholders).
    public var query: String

    public init(wordId: String, meaningId: String, term: String, query: String) {
        self.wordId = wordId
        self.meaningId = meaningId
        self.term = term
        self.query = query
    }

    public var id: String { meaningId }
}

/// Rules of the „Słowo i zdjęcie” exercise (G2): which meanings can be photographed, what to
/// search for, which distractors are clearly different. The photos themselves come from the app
/// (internet only, cached on disk) — FluentKit only gets the set of meanings with a cached photo.
public enum PictureExercise {
    /// Number of photos shown (the right one + 3 distractors).
    public static let optionCount = 4

    /// Topic files whose nouns are mostly things that can be photographed. Words added from other
    /// built-in topics (emotions, meetings, law…) never get a photo exercise.
    public static let concreteTopics: Set<String> = [
        "airport", "animals", "art-museum", "babies", "beach-vacation", "beauty-hairdresser",
        "board-games-puzzles", "body-parts", "books-reading", "cafe-bakery", "camping-hiking",
        "car-problems", "car-rental", "city-life", "cleaning-chores", "clothes-fashion",
        "colors-shapes-sizes", "computers-internet", "concerts-festivals", "cooking", "cruise-ferry",
        "cycling", "dentist", "drinks-bar", "driving", "emergencies-safety", "farming-countryside",
        "fast-food-takeaway", "fitness-gym", "flight", "football", "fruits-vegetables",
        "furniture-household", "garden-plants", "grocery-shopping", "hobbies-crafts",
        "holidays-traditions", "hospital-emergency", "hotel", "house-rooms", "materials-objects",
        "meat-fish-dairy", "moving-house", "music", "natural-disasters", "nature-landscape",
        "office-work", "parties-celebrations", "pets", "pharmacy", "photography", "post-office",
        "public-transport", "repairs-diy", "restaurant", "school", "shopping-clothes",
        "shopping-mall", "smartphones-apps", "space-astronomy", "sports", "theater", "train-travel",
        "weather", "wedding", "starter"
    ]

    /// Nouns that cannot be shown on a photo even in a concrete topic.
    static let abstractNouns: Set<String> = [
        "time", "idea", "love", "fear", "anger", "joy", "hope", "luck", "fun", "help", "advice",
        "information", "news", "problem", "issue", "question", "answer", "reason", "result", "chance",
        "change", "choice", "decision", "experience", "knowledge", "skill", "habit", "mistake",
        "delay", "trip", "journey", "booking", "reservation", "price", "cost", "fee", "discount",
        "deal", "refund", "service", "quality", "size", "type", "kind", "way", "rule", "law", "right",
        "risk", "safety", "danger", "health", "pain", "illness", "disease", "symptom", "diet",
        "flavor", "taste", "smell", "sound", "noise", "silence", "weather", "climate", "temperature",
        "season", "day", "week", "month", "year", "hour", "minute", "second", "moment", "morning",
        "evening", "night", "weekend", "holiday", "vacation", "break", "rest", "sleep", "dream",
        "memory", "mood", "feeling", "emotion", "stress", "rush", "hurry", "trouble", "accident",
        "emergency", "damage", "repair", "maintenance", "upgrade", "update", "version", "account",
        "password", "access", "connection", "signal", "data", "file", "message", "content", "trend",
        "style", "fashion", "look", "shape", "color", "pattern", "gender", "age", "career", "job",
        "work", "task", "goal", "plan", "schedule", "deadline", "budget", "profit", "loss", "debt",
        "interest", "tax", "income", "salary", "policy", "insurance", "permission", "request",
        "complaint", "apology", "thanks", "praise", "respect", "trust", "patience", "attention",
        "level", "score", "point", "goal kick", "win", "victory", "defeat", "draw", "tie", "match",
        "game", "round", "turn", "move", "step", "rhythm", "melody", "harmony", "tone", "speed",
        "distance", "direction", "location", "place", "area", "space", "stay", "visit", "departure",
        "arrival", "check-in", "checkout", "layover", "connection flight", "boarding", "takeoff",
        "landing", "turbulence", "jet lag", "nature", "environment", "pollution", "energy", "power",
        "claim", "standby", "rate", "charge", "warning", "forecast", "high", "low", "degree",
        "overtime", "workload", "commute", "draft", "report", "glitch", "typo", "settings", "storage",
        "bars", "roaming", "hotspot", "virus", "bug", "software", "program", "network", "internet",
        "cookies", "contact", "autocorrect", "warranty", "filter", "vacancy", "deposit",
        "incidentals", "amenities", "accommodations", "view", "mode", "reset", "detox", "purchase",
        "history", "limit", "number", "nine-to-five", "day off", "work hours", "final call",
        "harvest", "pesticide"
    ]

    /// English suffixes of abstract nouns (checked only on words longer than suffix + 3 letters).
    static let abstractSuffixes = [
        "tion", "sion", "ness", "ity", "ment", "ism", "ship", "hood", "ance", "ence", "ency",
        "ancy", "dom", "ology", "acy", "ure"
    ]

    /// Concrete-noun suffix exceptions (words that end like abstract nouns but are things).
    static let concreteExceptions: Set<String> = [
        "apartment", "basement", "pavement", "equipment", "instrument", "ornament", "garment",
        "compartment", "furniture", "picture", "sculpture", "station", "lotion", "potion", "onion",
        "cushion", "mansion", "pension", "television", "fountain", "ambulance", "fence", "license",
        "licence", "lettuce", "kingdom", "city", "spaceship", "ship", "airship", "hood", "dome",
        "creature", "vulture", "structure", "fixture", "moisture", "denture", "mixture"
    ]

    /// Polish endings of abstract nouns in the translation (`-ość`, `-izm`).
    static let polishAbstractSuffixes = ["osc", "izm"]

    // MARK: Eligibility

    /// `true` for a concrete noun that can be shown on a photo: part of speech „rzeczownik” /
    /// noun, at most three words, not on the abstract list or with an abstract suffix, and — for
    /// built-in words — from a concrete topic.
    public static func isPicturable(word: Word, meaning: Meaning) -> Bool {
        let pos = meaning.effectivePos(in: word).lowercased()
        guard pos.contains("rzeczownik") || pos == "noun" || pos.hasPrefix("noun") else { return false }
        if let raw = meaning.contentRef, let reference = ContentReference(raw) {
            guard concreteTopics.contains(reference.file) else { return false }
        }
        let term = searchQuery(term: word.en)
        let lowered = term.lowercased()
        guard !lowered.isEmpty, lowered.count <= 40 else { return false }
        let tokens = lowered.split(separator: " ")
        guard !tokens.isEmpty, tokens.count <= 3 else { return false }
        guard !abstractNouns.contains(lowered) else { return false }
        guard let head = tokens.last.map(String.init) else { return false }
        // „flight delay”, „parking space” — the head noun decides.
        if abstractNouns.contains(head) { return false }
        if !concreteExceptions.contains(head) && !concreteExceptions.contains(lowered) {
            for suffix in abstractSuffixes where head.count > suffix.count + 3 && head.hasSuffix(suffix) {
                return false
            }
        }
        let translation = TextScanning.foldPolish(TextNormalizer.withoutDialectLabel(meaning.translation))
        let firstPolish = translation
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "/" || $0 == "(" })
            .first
            .map { TextScanning.trim(String($0)) } ?? ""
        for suffix in polishAbstractSuffixes where firstPolish.count > suffix.count + 3 && firstPolish.hasSuffix(suffix) {
            return false
        }
        return true
    }

    /// Search phrase for a term: without `(AmE)`/`(BrE)`, parenthesised notes, leading articles
    /// and `sb`/`sth` placeholders.
    public static func searchQuery(term: String) -> String {
        var text = TextNormalizer.withoutDialectLabel(term)
        while let open = text.firstIndex(of: "("), let close = text[open...].firstIndex(of: ")") {
            text.removeSubrange(open...close)
        }
        var tokens = text
            .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" })
            .map(String.init)
            .filter { (token: String) -> Bool in
                let lowered = token.lowercased()
                return lowered != "sb" && lowered != "sth" && lowered != "someone" && lowered != "something"
            }
        if let first = tokens.first?.lowercased(), tokens.count > 1, first == "a" || first == "an" || first == "the" {
            tokens.removeFirst()
        }
        return TextScanning.trim(tokens.joined(separator: " "))
    }

    /// Background-download order (at most `limit`): meanings that can get a photo task now
    /// (past the first contact) by earliest due, then new ones in dictionary order. Archived words
    /// and meanings in `excluding` (already cached or known to have no usable photo) are skipped.
    public static func prefetchCandidates(state: LearnerState, excluding: Set<String> = [], limit: Int = 20) -> [PictureCandidate] {
        guard limit > 0 else { return [] }
        var practiced: [(candidate: PictureCandidate, due: Timestamp)] = []
        var fresh: [PictureCandidate] = []
        for word in state.words where !word.archived {
            for meaning in word.meanings where !excluding.contains(meaning.id) && isPicturable(word: word, meaning: meaning) {
                let query = searchQuery(term: word.en)
                let candidate = PictureCandidate(wordId: word.id, meaningId: meaning.id, term: word.en, query: query)
                if meaning.scores.isEmpty {
                    fresh.append(candidate)
                } else {
                    practiced.append((candidate: candidate, due: Mastery.due(meaning)))
                }
            }
        }
        let ordered = practiced.stableSorted { $0.due < $1.due }.map { $0.candidate } + fresh
        return Array(ordered.prefix(limit))
    }

    // MARK: Distractors

    /// Picturable meanings of the dictionary whose photo is cached (`cached` = meaning IDs).
    public static func cachedItems(state: LearnerState, cached: Set<String>) -> [WordMeaning] {
        guard !cached.isEmpty else { return [] }
        var items: [WordMeaning] = []
        for word in state.words where !word.archived {
            for meaning in word.meanings where cached.contains(meaning.id) && isPicturable(word: word, meaning: meaning) {
                items.append(WordMeaning(word: word, meaning: meaning))
            }
        }
        return items
    }

    /// Meanings that can be asked right now: a cached photo and at least three clearly different
    /// distractors with cached photos. Passed to `SessionBuilder.makeSession(pictureMeaningIDs:)`.
    public static func readyMeaningIDs(state: LearnerState, cached: Set<String>) -> Set<String> {
        let items = cachedItems(state: state, cached: cached)
        guard items.count >= optionCount else { return [] }
        var ready = Set<String>()
        for item in items {
            var valid = 0
            for other in items where isClearlyDifferent(item, other) {
                valid += 1
                if valid >= optionCount - 1 { break }
            }
            if valid >= optionCount - 1 {
                ready.insert(item.meaning.id)
            }
        }
        return ready
    }

    /// `true` when two meanings make an unambiguous pair of photos: different words, terms not
    /// contained in each other, different stems and different Polish translations.
    public static func isClearlyDifferent(_ a: WordMeaning, _ b: WordMeaning) -> Bool {
        guard a.word.id != b.word.id, a.meaning.id != b.meaning.id else { return false }
        let termA = TextNormalizer.normalize(searchQuery(term: a.word.en))
        let termB = TextNormalizer.normalize(searchQuery(term: b.word.en))
        guard !termA.isEmpty, !termB.isEmpty, termA != termB else { return false }
        if termA.contains(termB) || termB.contains(termA) { return false }
        if termA.count >= 4 && termB.count >= 4 && termA.prefix(4) == termB.prefix(4) { return false }
        let polishA = TextScanning.foldPolish(TextNormalizer.normalize(a.meaning.translation))
        let polishB = TextScanning.foldPolish(TextNormalizer.normalize(b.meaning.translation))
        if polishA == polishB { return false }
        let synonymsA = a.word.synonyms.lowercased()
        let synonymsB = b.word.synonyms.lowercased()
        if !synonymsA.isEmpty && containsWord(synonymsA, termB) { return false }
        if !synonymsB.isEmpty && containsWord(synonymsB, termA) { return false }
        return true
    }

    /// Up to `count` distractors from `pool`: clearly different from the target and from each
    /// other; up to two from the same topic or collection (plausible), the rest from elsewhere.
    public static func distractors<G: RandomNumberGenerator>(
        for target: WordMeaning,
        pool: [WordMeaning],
        count: Int = optionCount - 1,
        using rng: inout G
    ) -> [WordMeaning] {
        let valid = pool.filter { (item: WordMeaning) -> Bool in isClearlyDifferent(target, item) }
        let keyed = valid.map { (item: WordMeaning) -> (item: WordMeaning, key: Double) in
            (item: item, key: rng.nextUnit())
        }
        let shuffled = keyed.sorted { $0.key < $1.key }.map { $0.item }
        let sameGroup = shuffled.filter { (item: WordMeaning) -> Bool in isSameGroup(target, item) }
        let others = shuffled.filter { (item: WordMeaning) -> Bool in !isSameGroup(target, item) }
        var chosen: [WordMeaning] = []
        func take(from items: [WordMeaning], max limit: Int) {
            var taken = 0
            for item in items where chosen.count < count && taken < limit {
                guard chosen.allSatisfy({ (other: WordMeaning) -> Bool in isClearlyDifferent(other, item) }) else { continue }
                chosen.append(item)
                taken += 1
            }
        }
        take(from: sameGroup, max: 2)
        take(from: others, max: count)
        take(from: sameGroup, max: count)
        return chosen
    }

    /// The four options in a stable random order for one task (`seed` = task key), as meaning IDs.
    public static func optionOrder(target: String, distractors: [String], seed: String) -> [String] {
        var generator = SeededGenerator(seed: seed)
        let all = [target] + distractors
        let keyed = all.map { (id: String) -> (id: String, key: Double) in (id: id, key: generator.nextUnit()) }
        return keyed.sorted { $0.key < $1.key }.map { $0.id }
    }

    // MARK: Private

    private static func isSameGroup(_ a: WordMeaning, _ b: WordMeaning) -> Bool {
        if let topicA = a.meaning.topic, let topicB = b.meaning.topic, !topicA.isEmpty, topicA == topicB {
            return true
        }
        return !a.word.collection.isEmpty && a.word.collection == b.word.collection
    }

    private static func containsWord(_ text: String, _ word: String) -> Bool {
        let separators: (Character) -> Bool = { (character: Character) -> Bool in
            character == "," || character == ";" || character == "/" || character == " "
        }
        let parts = text.split(whereSeparator: separators).map { String($0) }
        let words = word.split(separator: " ").map { String($0) }
        guard words.count == 1, let single = words.first else {
            return text.contains(word)
        }
        return parts.contains(single)
    }
}
