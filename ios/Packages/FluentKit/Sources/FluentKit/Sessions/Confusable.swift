import Foundation

/// A word together with one of its meanings.
public struct WordMeaning: Sendable, Hashable {
    public var word: Word
    public var meaning: Meaning

    public init(word: Word, meaning: Meaning) {
        self.word = word
        self.meaning = meaning
    }
}

/// Detection of easily confused vocabulary (borrow/lend, say/tell, make/do) for „Słowa w parach”.
public enum ConfusableDetector {
    /// Longest-first list of Polish endings removed by the web `polishStem`.
    private static let endings: [String] = ["ować", "ywać", "enie", "anie", "emu", "ami", "ach", "ego", "ić", "yć", "ać", "ą", "ę", "y", "i", "a", "u", "e"]

    /// Rough Polish stems of a translation (words of ≥ 4 letters after removing one ending).
    static func polishStems(_ value: String) -> [String] {
        TextNormalizer.normalize(value)
            .split(separator: " ")
            .map { stem(String($0)) }
            .filter { $0.count >= 4 }
    }

    private static func stem(_ word: String) -> String {
        // The web regex removes the longest listed ending (leftmost match anchored at the end).
        for ending in endings where word.hasSuffix(ending) {
            return String(word.dropLast(ending.count))
        }
        return word
    }

    private static func stemsMatch(_ left: String, _ right: String) -> Bool {
        if left == right { return true }
        guard min(left.count, right.count) >= 6 else { return false }
        return left.hasPrefix(right) || right.hasPrefix(left)
    }

    /// `confusable(a, b)`: different words whose Polish translations share a stem, or whose note
    /// mentions the other word.
    ///
    /// iOS addition: also confusable when the senses share an accepted Polish answer from the
    /// reviewed variants (make „zrobić” / do „robić” → both accept „robić”, „zrobić”), which the
    /// stem heuristic misses for short verbs.
    public static func confusable(_ a: WordMeaning, _ b: WordMeaning, answerIndex: PolishAnswerIndex = PolishAnswerIndex()) -> Bool {
        if a.word.id == b.word.id { return false }
        let left = Set(polishStems(a.meaning.translation))
        let right = polishStems(b.meaning.translation)
        if right.contains(where: { stem in left.contains(where: { stemsMatch($0, stem) }) }) { return true }
        if noteMentions(a.word, b.word) || noteMentions(b.word, a.word) { return true }
        return !answerKeys(a, answerIndex).isDisjoint(with: answerKeys(b, answerIndex))
    }

    static func answerKeys(_ item: WordMeaning, _ index: PolishAnswerIndex) -> Set<String> {
        index.keys(term: item.word.en, translation: item.meaning.translation, saved: item.meaning.acceptedTranslations ?? [])
    }

    private static func noteMentions(_ owner: Word, _ other: Word) -> Bool {
        let target = TextNormalizer.normalize(other.en)
        guard !target.isEmpty else { return false }
        return TextNormalizer.normalize(owner.note).contains(target)
    }

    /// Items that are confusable with at least one other item. Equivalent to
    /// `items.filter { item in items.contains { confusable(item, $0) } }` but indexed
    /// (no O(n²) scan over thousands of words).
    public static func itemsWithPartners(_ items: [WordMeaning], answerIndex: PolishAnswerIndex = PolishAnswerIndex()) -> [WordMeaning] {
        guard items.count > 1 else { return [] }
        let stems = items.map { polishStems($0.meaning.translation) }
        var hasPartner = Array(repeating: false, count: items.count)
        // Shared accepted Polish answers.
        var byAnswer: [String: [Int]] = [:]
        for (index, item) in items.enumerated() {
            for key in answerKeys(item, answerIndex) {
                byAnswer[key, default: []].append(index)
            }
        }
        for indices in byAnswer.values where indices.count > 1 {
            // Every item has a partner as soon as the group spans two different words.
            guard Set(indices.map { items[$0].word.id }).count > 1 else { continue }
            for index in indices { hasPartner[index] = true }
        }
        // Index: exact stem → item indices; 6-letter prefix of long stems → item indices.
        var exact: [String: [Int]] = [:]
        var prefixes: [String: [Int]] = [:]
        for (index, list) in stems.enumerated() {
            for stem in Set(list) {
                exact[stem, default: []].append(index)
                if stem.count >= 6 {
                    prefixes[String(stem.prefix(6)), default: []].append(index)
                }
            }
        }
        for (index, list) in stems.enumerated() where !hasPartner[index] {
            var candidates = Set<Int>()
            for stem in list {
                candidates.formUnion(exact[stem] ?? [])
                if stem.count >= 6 {
                    candidates.formUnion(prefixes[String(stem.prefix(6))] ?? [])
                }
            }
            for other in candidates where other != index && items[other].word.id != items[index].word.id {
                if stems[other].contains(where: { o in list.contains(where: { stemsMatch(o, $0) }) }) {
                    hasPartner[index] = true
                    hasPartner[other] = true
                    break
                }
            }
        }
        // Notes: only words with a non-empty note can mention another word.
        let normalizedEn = items.map { TextNormalizer.normalize($0.word.en) }
        for (index, item) in items.enumerated() {
            let note = TextNormalizer.normalize(item.word.note)
            guard !note.isEmpty else { continue }
            for (other, target) in normalizedEn.enumerated() where other != index && !target.isEmpty {
                if items[other].word.id != item.word.id && note.contains(target) {
                    hasPartner[index] = true
                    hasPartner[other] = true
                }
            }
        }
        var result: [WordMeaning] = []
        for (index, item) in items.enumerated() where hasPartner[index] {
            result.append(item)
        }
        return result
    }
}
