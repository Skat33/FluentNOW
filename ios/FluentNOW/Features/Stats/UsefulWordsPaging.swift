import Foundation
import FluentKit

/// Słownik → Polecane (FEEDBACK-5 J2): zamiast nieskończonej listy — zestaw `setSize` słów
/// w stronach przewijanych poziomo. „Odśwież propozycje” losuje nowy zestaw z najlepszej części
/// tej samej puli rankingu (`UsefulWordsCatalog`, ziarno = tydzień), z pominięciem słów
/// pokazanych już w tym tygodniu. Czyste funkcje — stan trzyma ekran.
///
/// FEEDBACK-6 K2: strona mieści się na ekranie bez przewijania w pionie — liczba słów na stronie
/// (`minPageSize`…`pageSize`) zależy od dostępnej wysokości (`pageSize(forHeight:rowHeight:)`).
enum UsefulWordsPaging {
    /// Najwięcej słów na stronie.
    static let pageSize = 6
    /// Najmniej słów na stronie (mniej się nie mieści — wtedy strona się przewija).
    static let minPageSize = 3
    static let maxPages = 3
    /// Słów w jednym zestawie (wszystkie strony).
    static let setSize = pageSize * maxPages

    /// Słów na stronie dla wysokości obszaru listy (`rowHeight` — wysokość wiersza z odstępem);
    /// `nil`, gdy nie mieści się nawet `minPageSize` (bardzo duża czcionka — strona przewijana).
    static func pageSize(forHeight height: Double, rowHeight: Double) -> Int? {
        guard height.isFinite, rowHeight.isFinite, rowHeight > 0, height > 0 else { return nil }
        let fitting = Int((height / rowHeight).rounded(.down))
        guard fitting >= minPageSize else { return nil }
        return min(pageSize, fitting)
    }
    /// Pula rankingu, z której losowane są kolejne zestawy (kilka odświeżeń na tydzień).
    static let poolLimit = 72

    /// Numer tygodnia — ten sam co ziarno rankingu w `UsefulWordsLoader`.
    static func week(now: Timestamp) -> Int {
        now.isFinite ? Int(max(0, now) / (7 * TimeConstants.dayMs)) : 0
    }

    // MARK: Zapis identyfikatorów (UserDefaults)

    static func ids(_ raw: String) -> [String] {
        raw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    static func raw(_ ids: [String]) -> String {
        ids.joined(separator: "\n")
    }

    // MARK: Zestawy

    /// Pokazywany zestaw po świeżym rankingu (np. po dodaniu słowa): słowa dodane na tym ekranie
    /// (`owned`) zostają na swoich miejscach jako „Masz już”, słowa, których nie ma już w puli
    /// (np. dodane gdzie indziej), znikają, a wolne miejsca uzupełniają kolejne niepokazane
    /// słowa z puli (w kolejności rankingu). `storedIDs` — zestaw zapamiętany z poprzedniej wizyty
    /// (używany, gdy `current` jest pusty).
    static func refreshed(
        current: [UsefulWordSuggestion],
        storedIDs: [String],
        pool: [UsefulWordSuggestion],
        owned: Set<String>,
        shown: Set<String>
    ) -> [UsefulWordSuggestion] {
        var byID: [String: UsefulWordSuggestion] = [:]
        for item in pool where byID[item.id] == nil {
            byID[item.id] = item
        }
        var previous: [String: UsefulWordSuggestion] = [:]
        for item in current where previous[item.id] == nil {
            previous[item.id] = item
        }
        let base: [String] = current.isEmpty ? storedIDs : current.map { (item: UsefulWordSuggestion) -> String in item.id }
        var items: [UsefulWordSuggestion] = []
        var used = Set<String>()
        for id in base where !used.contains(id) && items.count < setSize {
            if let fresh = byID[id] {
                items.append(fresh)
                used.insert(id)
            } else if owned.contains(id), let kept = previous[id] {
                items.append(kept)
                used.insert(id)
            }
        }
        for item in pool where items.count < setSize && !used.contains(item.id) && !shown.contains(item.id) {
            items.append(item)
            used.insert(item.id)
        }
        return items
    }

    /// Wynik „Odśwież propozycje”.
    struct Draw {
        let items: [UsefulWordSuggestion]
        /// Słowa pokazane w tym tygodniu (bez nowego zestawu).
        let shown: Set<String>
        /// `true` — pula się wyczerpała, losowanie zaczęło się od nowa.
        let startedOver: Bool
    }

    /// Nowy zestaw: losowo `setSize` słów spośród najlepszych `2 × setSize` niepokazanych w tym
    /// tygodniu (w kolejności rankingu). Gdy niepokazanych zostało mniej niż jedna strona, pula
    /// zaczyna się od nowa (bez bieżącego zestawu, jeśli się da).
    static func nextSet<G: RandomNumberGenerator>(
        pool: [UsefulWordSuggestion],
        current: [UsefulWordSuggestion],
        shown: Set<String>,
        using rng: inout G
    ) -> Draw {
        let currentIDs = Set(current.map { (item: UsefulWordSuggestion) -> String in item.id })
        var seen = shown.union(currentIDs)
        var candidates = pool.filter { (item: UsefulWordSuggestion) -> Bool in !seen.contains(item.id) }
        var startedOver = false
        if candidates.count < pageSize {
            startedOver = true
            seen = currentIDs
            candidates = pool.filter { (item: UsefulWordSuggestion) -> Bool in !currentIDs.contains(item.id) }
            if candidates.count < pageSize {
                seen = []
                candidates = pool
            }
        }
        let window = Array(candidates.prefix(setSize * 2))
        let shuffled: [UsefulWordSuggestion] = StudyPriority.shuffled(window, using: &rng)
        let picked = Set(shuffled.prefix(setSize).map { (item: UsefulWordSuggestion) -> String in item.id })
        let items = window.filter { (item: UsefulWordSuggestion) -> Bool in picked.contains(item.id) }
        return Draw(items: items, shown: seen, startedOver: startedOver)
    }

    /// Podział na strony po `size` słów (domyślnie `pageSize`; poza zakresem — przycięte do
    /// `minPageSize…pageSize`).
    static func pages(_ items: [UsefulWordSuggestion], size: Int = pageSize) -> [[UsefulWordSuggestion]] {
        guard !items.isEmpty else { return [] }
        let step = min(pageSize, max(minPageSize, size))
        return stride(from: 0, to: items.count, by: step).map { (start: Int) -> [UsefulWordSuggestion] in
            Array(items[start..<min(start + step, items.count)])
        }
    }

    /// Strona, na której jest słowo o indeksie `firstIndex` zestawu, po zmianie rozmiaru strony
    /// (pierwsze widoczne słowo zostaje widoczne).
    static func page(containing firstIndex: Int, size: Int) -> Int {
        let step = min(pageSize, max(minPageSize, size))
        return max(0, firstIndex) / step
    }
}
