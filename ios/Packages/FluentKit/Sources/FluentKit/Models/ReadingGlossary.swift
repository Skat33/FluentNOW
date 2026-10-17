import Foundation

/// One entry of a reading's contextual glossary (`readings.json` → `glossary`, CONTENT-SCHEMA §5.4).
/// The translation is the meaning used **in this passage**, not a general dictionary sense.
public struct ReadingGlossaryEntry: Codable, Sendable, Hashable {
    /// The form exactly as it appears in the passage ("booked", "took a photo").
    public var form: String
    /// Base form ("book", "take a photo").
    public var lemma: String
    /// Polish translation in the sense of this passage.
    public var translation: String
    /// General American IPA of the lemma, e.g. `/bʊk/`.
    public var ipa: String?
    /// Reference to a built-in entry with the same meaning (`<topic file>/<entry id>` or `starter/<id>`).
    public var ref: String?

    public init(form: String, lemma: String, translation: String, ipa: String? = nil, ref: String? = nil) {
        self.form = form
        self.lemma = lemma
        self.translation = translation
        self.ipa = ipa
        self.ref = ref
    }

    enum CodingKeys: String, CodingKey {
        case form, lemma, translation, ipa, ref
    }

    /// Lenient: missing `lemma` falls back to `form`; an entry without `form` or `translation` is
    /// rejected (and skipped by the reading's lossy decoding).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let form = TextScanning.trim(c.lenientString(.form))
        let translation = TextScanning.trim(c.lenientString(.translation))
        guard !form.isEmpty, !translation.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .form, in: c, debugDescription: "Pusta pozycja słowniczka")
        }
        let lemma = TextScanning.trim(c.lenientString(.lemma))
        self.form = form
        self.lemma = lemma.isEmpty ? form : lemma
        self.translation = translation
        self.ipa = Self.nonEmpty(c.lenientOptionalString(.ipa))
        self.ref = Self.nonEmpty(c.lenientOptionalString(.ref))
    }

    /// Parsed `ref` (`nil` when absent or malformed).
    public var contentReference: ContentReference? {
        guard let ref else { return nil }
        return ContentReference(ref)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = TextScanning.trim(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}

public extension Reading {
    /// The glossary entry at `index`, or `nil` when out of range.
    func glossaryEntry(at index: Int) -> ReadingGlossaryEntry? {
        glossary[safe: index]
    }
}
