import Foundation

/// Pre-normalised `AnswerVariants` for fast, repeated lookups of accepted Polish answer keys
/// (same semantics as `VocabularyGrader.polishAnswers`, but returns `answerKey`s).
/// Build once per variants file; used by distractor selection and pair detection.
public struct PolishAnswerIndex: Sendable, Hashable {
    /// Term key → variant groups (keys).
    private let groups: [String: [Set<String>]]
    /// Aspect pairs (keys).
    private let aspects: [Set<String>]

    public init(_ variants: AnswerVariants = .builtIn) {
        var groups: [String: [Set<String>]] = [:]
        for group in variants.polishSenseVariants {
            let keys = Set(group.variants.map(TextNormalizer.answerKey).filter { !$0.isEmpty })
            groups[TextNormalizer.answerKey(group.term), default: []].append(keys)
        }
        self.groups = groups
        self.aspects = variants.polishAspectPairs.map { Set($0.map(TextNormalizer.answerKey).filter { !$0.isEmpty }) }
    }

    /// Keys of the translation, its parts (split on `, ; /`) and saved alternatives.
    public static func baseKeys(translation: String, saved: [String] = []) -> Set<String> {
        var keys = Set<String>()
        keys.insert(TextNormalizer.answerKey(translation))
        for part in translation.split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "/" }) {
            keys.insert(TextNormalizer.answerKey(String(part)))
        }
        for value in saved {
            keys.insert(TextNormalizer.answerKey(value))
        }
        keys.remove("")
        return keys
    }

    /// All accepted answer keys for a sense: base keys + anchored reviewed variants + aspect pairs.
    public func keys(term: String, translation: String, saved: [String] = []) -> Set<String> {
        let anchors = PolishAnswerIndex.baseKeys(translation: translation, saved: saved)
        var result = anchors
        for group in groups[TextNormalizer.answerKey(term)] ?? [] where !group.isDisjoint(with: anchors) {
            result.formUnion(group)
        }
        for pair in aspects where !pair.isDisjoint(with: anchors) {
            result.formUnion(pair)
        }
        return result
    }
}
