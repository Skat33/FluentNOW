import Foundation
import FluentKit

/// „Polecane słówka” po dodaniu (G6): słowo dodane z listy nie znika od razu — zostaje na swoim
/// miejscu wyszarzone z „Masz już”, a wolne miejsca wypełnia nowa lista. Po opuszczeniu ekranu
/// lista liczy się od nowa (ranking i tak pomija posiadane słowa).
enum UsefulWordsOwnership {
    /// - Parameters:
    ///   - previous: lista pokazywana dotąd.
    ///   - fresh: nowy wynik rankingu (bez posiadanych słów).
    ///   - kept: id słów dodanych w tym widoku.
    static func merged(previous: UsefulWordsResult?, fresh: UsefulWordsResult, kept: Set<String>, limit: Int) -> UsefulWordsResult {
        guard let previous, !kept.isEmpty else { return fresh }
        var queue = fresh.suggestions.filter { !kept.contains($0.id) }
        var result: [UsefulWordSuggestion] = []
        var used = Set<String>()
        for item in previous.suggestions {
            if kept.contains(item.id) {
                result.append(item)
                used.insert(item.id)
                continue
            }
            while let next = queue.first {
                queue.removeFirst()
                if !used.contains(next.id) {
                    used.insert(next.id)
                    result.append(next)
                    break
                }
            }
        }
        let cap = max(limit, result.count)
        for item in queue {
            guard result.count < cap else { break }
            if !used.contains(item.id) {
                used.insert(item.id)
                result.append(item)
            }
        }
        var details = fresh.details
        for item in result where details[item.id] == nil {
            if let detail = previous.details[item.id] { details[item.id] = detail }
        }
        return UsefulWordsResult(suggestions: result, details: details, level: fresh.level, targetLevel: fresh.targetLevel)
    }
}
