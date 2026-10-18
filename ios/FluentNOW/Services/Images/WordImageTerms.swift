import Foundation
import FluentKit

/// What a photo of the word is expected to show — decides which Vision classes contradict it
/// (an insect is fine for „bee”, never for „phone”).
enum WordImageSubject: String, Codable, Sendable, CaseIterable {
    /// Things: furniture, tools, devices, vehicles (default).
    case object
    /// Clothes and accessories (people in the photo are fine).
    case wearable
    /// Food and drinks.
    case food
    /// Animals.
    case animal
    /// Plants, trees, flowers.
    case plant
    /// Places, buildings, landscapes, weather.
    case place
    /// Body parts, babies, people doing sports (people in the photo are fine).
    case person
    /// Works of art, instruments on stage, museum objects.
    case artwork
}

/// Context of one meaning used to disambiguate the search (computed from `LearnerState` off the
/// main thread by `WordImagePrefetchBatch`, stored with the assignment).
struct WordImageContext: Sendable, Hashable, Codable {
    /// Topic file (`computers-internet`) or the meaning's own topic.
    var topic: String?
    /// Polish translation of the meaning („mysz komputerowa”).
    var translation: String

    init(topic: String? = nil, translation: String = "") {
        self.topic = topic
        self.translation = translation
    }

    init(meaning: Meaning) {
        if let raw = meaning.contentRef, let reference = ContentReference(raw) {
            topic = reference.file
        } else {
            topic = meaning.topic
        }
        translation = meaning.translation
    }
}

/// Small text helpers (pure; FluentKit's own folding helpers are internal to the package).
enum WordImageText {
    /// Lowercased words: letters and digits only, everything else separates words.
    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { (character: Character) -> Bool in
                !(character.isLetter || character.isNumber)
            })
            .map { (part: Substring) -> String in String(part) }
    }

    /// Lowercased Polish without diacritics („Żuraw” → „zuraw”, „łódź” → „lodz”).
    static func foldPolish(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "ł", with: "l")
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
    }

    private static let irregularPairs: [(String, String)] = [
        ("mouse", "mice"), ("man", "men"), ("woman", "women"), ("child", "children"),
        ("tooth", "teeth"), ("foot", "feet"), ("goose", "geese"), ("person", "people"),
        ("knife", "knives"), ("leaf", "leaves"), ("loaf", "loaves"), ("wolf", "wolves"),
        ("shelf", "shelves"), ("half", "halves"), ("calf", "calves"), ("scarf", "scarves"),
        ("thief", "thieves"), ("wife", "wives"), ("life", "lives"), ("ox", "oxen"),
        ("cactus", "cacti"), ("tomato", "tomatoes"), ("potato", "potatoes"), ("hero", "heroes")
    ]

    /// Plural → singular and singular → plural of irregular nouns.
    private static let irregular: [String: String] = {
        var map: [String: String] = [:]
        for (singular, plural) in irregularPairs {
            map[singular] = plural
            map[plural] = singular
        }
        return map
    }()

    /// The word itself plus likely singular / plural forms („box” → box, boxes; „cherries” →
    /// cherries, cherry). Over-generation is harmless: forms are only compared with photo titles.
    static func forms(of word: String) -> Set<String> {
        var result: Set<String> = [word]
        guard word.count >= 2 else { return result }
        if let other = irregular[word] {
            result.insert(other)
        }
        let vowels = "aeiou"
        if word.hasSuffix("y"), let before = word.dropLast().last, !vowels.contains(before) {
            result.insert(String(word.dropLast()) + "ies")
        } else if word.hasSuffix("s") || word.hasSuffix("x") || word.hasSuffix("z") || word.hasSuffix("ch") || word.hasSuffix("sh") {
            result.insert(word + "es")
        } else {
            result.insert(word + "s")
        }
        if word.hasSuffix("ies") && word.count > 4 {
            result.insert(String(word.dropLast(3)) + "y")
        } else if word.hasSuffix("es") && word.count > 3 {
            result.insert(String(word.dropLast(2)))
            result.insert(String(word.dropLast()))
        } else if word.hasSuffix("s") && !word.hasSuffix("ss") && word.count > 3 {
            result.insert(String(word.dropLast()))
        }
        return result
    }
}

/// Everything the matching layers need to know about one word meaning: the term, its forms and
/// synonyms, the refined search query, the expected Vision labels and the subject class.
struct WordImageTermProfile: Sendable, Equatable {
    /// Search phrase without labels and articles, lowercased („cell phone”).
    var term: String
    /// Words of the term.
    var words: [String]
    /// Other phrasings that count as the same thing in titles and tags (synonyms).
    var synonyms: [[String]]
    /// Query sent to Openverse (term refined by the sense, e.g. „computer mouse”).
    var query: String
    /// Query of the last search attempt (synonym or plain term), `nil` = none.
    var alternativeQuery: String?
    var subject: WordImageSubject
    /// Vision identifiers that confirm the photo (hand-mapped synonyms + identifiers derived from
    /// the term; only those in the device taxonomy count).
    var expectedLabels: [String]
    /// Hand-mapped identifiers (trusted even when the taxonomy cannot be read).
    var mappedLabels: [String]
    /// Broader identifiers (hypernyms): accepted only together with a strong title/tag match.
    var relatedLabels: [String]
    /// Title/tag words that point to another sense (Apple computers for „apple”).
    var avoidWords: Set<String>
    /// The chosen sense cannot be photographed (Polish reason), `nil` = fine.
    var excludedReason: String?

    /// Profile of a term in a context. Pure and cheap (dictionary lookups).
    static func make(term rawTerm: String, context: WordImageContext?) -> WordImageTermProfile {
        let base = PictureExercise.searchQuery(term: rawTerm).lowercased()
        let words = WordImageText.tokens(base)
        let sense = WordImageSenses.sense(for: base, context: context)
        let mapped = sense?.labels ?? WordImageVisionLabels.mappedLabels(for: words)
        var expected = mapped
        for guess in WordImageVisionLabels.derivedLabels(for: words) where !expected.contains(guess) {
            expected.append(guess)
        }
        let resolvedSubject: WordImageSubject = sense?.subject
            ?? WordImageVisionLabels.subject(forLabels: mapped)
            ?? WordImageTermProfile.subject(forTopic: context?.topic)
            ?? .object
        let related = sense.map { (value: WordImageSense) -> [String] in value.related }
            ?? WordImageVisionLabels.defaultRelated(for: resolvedSubject)
        let synonyms = WordImageVisionLabels.synonyms(for: base).map { (phrase: String) -> [String] in
            WordImageText.tokens(phrase)
        }
        let query = sense?.query ?? base
        var alternative = sense?.alternative ?? WordImageVisionLabels.synonyms(for: base).first
        if alternative == nil && query != base {
            alternative = base
        }
        return WordImageTermProfile(
            term: base,
            words: words,
            synonyms: synonyms,
            query: query,
            alternativeQuery: alternative,
            subject: resolvedSubject,
            expectedLabels: expected,
            mappedLabels: mapped,
            relatedLabels: related,
            avoidWords: Set((sense?.avoid ?? []) + WordImageVisionLabels.avoidWords(for: base)),
            excludedReason: sense?.excluded
        )
    }

    /// Topic file → subject class (built-in topics; `nil` for mixed topics).
    static func subject(forTopic topic: String?) -> WordImageSubject? {
        guard let topic = topic?.lowercased(), !topic.isEmpty else { return nil }
        return topicSubjects[topic]
    }

    private static let topicSubjects: [String: WordImageSubject] = {
        let entries: [(String, WordImageSubject)] = [
            ("animals", .animal), ("pets", .animal),
            ("fruits-vegetables", .food), ("meat-fish-dairy", .food), ("cafe-bakery", .food),
            ("fast-food-takeaway", .food), ("drinks-bar", .food), ("grocery-shopping", .food),
            ("garden-plants", .plant),
            ("nature-landscape", .place), ("beach-vacation", .place), ("weather", .place),
            ("natural-disasters", .place), ("space-astronomy", .place), ("city-life", .place),
            ("camping-hiking", .place), ("farming-countryside", .place), ("house-rooms", .place),
            ("body-parts", .person), ("babies", .person), ("beauty-hairdresser", .person),
            ("dentist", .person), ("sports", .person), ("football", .person), ("cycling", .person),
            ("fitness-gym", .person),
            ("clothes-fashion", .wearable), ("shopping-clothes", .wearable), ("wedding", .wearable),
            ("art-museum", .artwork), ("theater", .artwork), ("music", .artwork), ("concerts-festivals", .artwork)
        ]
        return Dictionary(entries, uniquingKeysWith: { (first: WordImageSubject, _: WordImageSubject) -> WordImageSubject in first })
    }()
}
