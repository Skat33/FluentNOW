import Foundation

/// What the learner already has (G6): built-in entry references and term + translation pairs of
/// active (non-archived) words — the same rule `VocabularyMerger` uses to skip duplicates, so an
/// entry marked „Masz już” would indeed not be added again.
public struct OwnedVocabulary: Sendable, Hashable {
    /// `Meaning.contentRef` values.
    public var references: Set<String>
    /// `"<term key>|<translation key>"`.
    public var pairs: Set<String>
    /// Normalised terms.
    public var terms: Set<String>

    public init(references: Set<String> = [], pairs: Set<String> = [], terms: Set<String> = []) {
        self.references = references
        self.pairs = pairs
        self.terms = terms
    }

    public init(_ state: LearnerState) {
        self.init(words: state.words)
    }

    public init(words: [Word]) {
        var references = Set<String>()
        var pairs = Set<String>()
        var terms = Set<String>()
        for word in words where !word.archived {
            let term = OwnedVocabulary.termKey(word.en)
            if !term.isEmpty { terms.insert(term) }
            for meaning in word.meanings {
                for reference in meaning.allContentRefs { references.insert(reference) }
                pairs.insert(term + "|" + OwnedVocabulary.translationKey(meaning.translation))
            }
        }
        self.init(references: references, pairs: pairs, terms: terms)
    }

    public static let empty = OwnedVocabulary()

    public static func termKey(_ term: String) -> String {
        TextNormalizer.normalize(term)
    }

    public static func translationKey(_ translation: String) -> String {
        TextNormalizer.normalize(TextNormalizer.withoutDialectLabel(translation))
    }

    /// `true` when the entry (by reference) or the same term with the same translation is owned.
    public func contains(reference: String?, term: String, translation: String) -> Bool {
        if let reference, !reference.isEmpty, references.contains(reference) { return true }
        return pairs.contains(OwnedVocabulary.termKey(term) + "|" + OwnedVocabulary.translationKey(translation))
    }

    /// `true` when the learner has any meaning of the term.
    public func containsTerm(_ term: String) -> Bool {
        terms.contains(OwnedVocabulary.termKey(term))
    }

    /// Owned entries among topic entries (`reference(entry)` gives the entry's content reference).
    public func ownedReferences(_ entries: [(reference: String, entry: TopicEntry)]) -> Set<String> {
        var result = Set<String>()
        for item in entries where contains(reference: item.reference, term: item.entry.term, translation: item.entry.translation) {
            result.insert(item.reference)
        }
        return result
    }
}
