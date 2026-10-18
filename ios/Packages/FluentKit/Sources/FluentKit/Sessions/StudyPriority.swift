import Foundation

/// Priority of starred words (`Word.important`, the star in the dictionary) when sessions and
/// flashcard decks are built. A boost, not a reorder: due reviews keep their order by due date
/// (or errors); a star only breaks ties — which makes starred meanings first among new ones,
/// since every new meaning has the same due date (0).
public enum StudyPriority {
    /// Strict ordering predicate: `true` when `lhs` is starred and `rhs` is not.
    /// Use as the last key of a sort (with `stableSorted`, so equal elements keep their order).
    public static func starredFirst(_ lhs: Word, _ rhs: Word) -> Bool {
        lhs.important && !rhs.important
    }

    /// Fisher–Yates shuffle with an injected generator (deterministic in tests).
    public static func shuffled<T, G: RandomNumberGenerator>(_ items: [T], using rng: inout G) -> [T] {
        var result = items
        var index = result.count - 1
        while index > 0 {
            let other = rng.nextIndex(below: index + 1)
            result.swapAt(index, other)
            index -= 1
        }
        return result
    }
}
