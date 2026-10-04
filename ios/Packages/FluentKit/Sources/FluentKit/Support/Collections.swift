import Foundation

extension Array {
    /// Stable sort (equal elements keep their original order), like `Array.prototype.sort` in JS.
    /// `areInIncreasingOrder` must be a strict weak ordering.
    func stableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        let indexed = self.enumerated().map { (offset: $0.offset, element: $0.element) }
        let sorted = indexed.sorted { left, right in
            if areInIncreasingOrder(left.element, right.element) { return true }
            if areInIncreasingOrder(right.element, left.element) { return false }
            return left.offset < right.offset
        }
        return sorted.map { $0.element }
    }

    /// Safe subscript: `nil` when the index is out of range.
    subscript(safe index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}

extension Array where Element: Hashable {
    /// Removes duplicates keeping the first occurrence (`[...new Set(array)]` in JS).
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        var result: [Element] = []
        result.reserveCapacity(count)
        for element in self where seen.insert(element).inserted {
            result.append(element)
        }
        return result
    }
}

/// Three-way comparison helper used to port JS comparators (`a - b || c - d`).
@inline(__always)
func compareValues<T: Comparable>(_ left: T, _ right: T) -> Int {
    left < right ? -1 : (left > right ? 1 : 0)
}
