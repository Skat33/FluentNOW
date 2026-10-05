import Foundation
import FluentKit

/// Filtr statusu listy słów (chipy pod wyszukiwarką).
enum WordStatusFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all, new, learning, hard, mastered, needsRefresh, important, archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Wszystkie"
        case .new: return "Nowe"
        case .learning: return "Uczę się"
        case .hard: return "Trudne"
        case .mastered: return "Opanowane"
        case .needsRefresh: return "Do odświeżenia"
        case .important: return "Ważne"
        case .archived: return "Archiwum"
        }
    }

    var systemImage: String? {
        switch self {
        case .hard: return "flame"
        case .important: return "star"
        case .archived: return "archivebox"
        default: return nil
        }
    }
}

/// Sortowanie listy słów.
enum WordSortOrder: String, CaseIterable, Identifiable, Hashable, Sendable {
    case recent, alphabetical, hardest, dueSoon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Ostatnio dodane"
        case .alphabetical: return "Alfabetycznie"
        case .hardest: return "Najtrudniejsze"
        case .dueSoon: return "Najbliższa powtórka"
        }
    }
}

struct WordListFilter: Hashable, Sendable {
    var status: WordStatusFilter = .all
    /// `nil` = wszystkie poziomy.
    var level: String?
    /// `nil` = wszystkie kolekcje.
    var collection: String?
    var sort: WordSortOrder = .recent

    var isDefault: Bool {
        status == .all && level == nil && collection == nil
    }
}

/// Lekki model wiersza (bez całego `Word`), liczony poza głównym wątkiem.
struct WordListRow: Identifiable, Hashable, Sendable {
    let id: String
    let en: String
    let translations: String
    let level: String
    let status: WordStatus
    let mastery: Int
    let meaningCount: Int
    let collection: String
    let isHard: Bool
    let isImportant: Bool
    let isArchived: Bool
}

struct WordListSection: Identifiable, Hashable, Sendable {
    let id: String
    let title: String?
    let rows: [WordListRow]
}

struct WordListResult: Hashable, Sendable {
    var sections: [WordListSection] = []
    var matchCount: Int = 0
    var totalActive: Int = 0
    var collections: [String] = []

    static let empty = WordListResult()
}

/// Klucz zadania `.task(id:)` — zmiana dowolnego pola przelicza listę (z debounce).
struct WordListQuery: Hashable, Sendable {
    var revision: Int
    var text: String
    var filter: WordListFilter
}

/// Czyste przeliczenie listy słownika (wywoływane w `store.compute`).
enum WordListBuilder {
    static func build(state: LearnerState, query: String, filter: WordListFilter, now: Timestamp) -> WordListResult {
        let key = searchKey(query)
        var rows: [(row: WordListRow, word: Word)] = []
        rows.reserveCapacity(state.words.count)
        for word in state.words {
            let status = word.status(now: now)
            guard matches(word: word, status: status, filter: filter) else { continue }
            if !key.isEmpty && !matches(word: word, key: key) { continue }
            rows.append((makeRow(word, status: status), word))
        }
        let sorted = sort(rows, by: filter.sort)
        return WordListResult(
            sections: sections(sorted.map { $0.row }, sort: filter.sort),
            matchCount: sorted.count,
            totalActive: state.words.reduce(0) { $0 + ($1.archived ? 0 : 1) },
            collections: allCollections(state)
        )
    }

    /// Kolekcje z listy stanu i z samych słów (bez duplikatów, kolejność stanu najpierw).
    static func allCollections(_ state: LearnerState) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in state.collections + state.words.map({ $0.collection }) {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }

    static func searchKey(_ text: String) -> String {
        TextNormalizer.searchKey(text.lowercased())
    }

    // MARK: Prywatne

    private static func matches(word: Word, status: WordStatus, filter: WordListFilter) -> Bool {
        if let collection = filter.collection, word.collection != collection { return false }
        if let level = filter.level {
            let levels = word.meanings.map { $0.effectiveLevel(in: word) } + [word.level]
            if !levels.contains(level) { return false }
        }
        switch filter.status {
        case .all: return !word.archived
        case .archived: return word.archived
        case .important: return !word.archived && word.important
        case .new: return status == .new
        case .learning: return status == .learning
        case .hard: return status == .hard
        case .mastered: return status == .mastered
        case .needsRefresh: return status == .needsRefresh
        }
    }

    private static func matches(word: Word, key: String) -> Bool {
        if searchKey(word.en).contains(key) { return true }
        for meaning in word.meanings where searchKey(meaning.translation).contains(key) {
            return true
        }
        return word.tags.contains { searchKey($0).contains(key) }
    }

    private static func makeRow(_ word: Word, status: WordStatus) -> WordListRow {
        let translations = word.meanings.map { $0.translation }.filter { !$0.isEmpty }
        let level = word.level.isEmpty ? (word.meanings.first?.level ?? "") : word.level
        return WordListRow(
            id: word.id,
            en: word.en,
            translations: translations.joined(separator: " · "),
            level: level,
            status: status,
            mastery: word.mastery,
            meaningCount: word.meanings.count,
            collection: word.collection,
            isHard: status == .hard,
            isImportant: word.important,
            isArchived: word.archived
        )
    }

    private static func sort(_ rows: [(row: WordListRow, word: Word)], by order: WordSortOrder) -> [(row: WordListRow, word: Word)] {
        switch order {
        case .recent:
            // Kolejność stanu = najnowsze najpierw; sortowanie stabilne po dacie utworzenia.
            return rows.enumerated()
                .sorted { lhs, rhs in
                    if lhs.element.word.created != rhs.element.word.created {
                        return lhs.element.word.created > rhs.element.word.created
                    }
                    return lhs.offset < rhs.offset
                }
                .map { $0.element }
        case .alphabetical:
            return rows.sorted { lhs, rhs in
                lhs.row.en.localizedCaseInsensitiveCompare(rhs.row.en) == .orderedAscending
            }
        case .hardest:
            return rows.sorted { lhs, rhs in
                if lhs.row.isHard != rhs.row.isHard { return lhs.row.isHard }
                if lhs.row.mastery != rhs.row.mastery { return lhs.row.mastery < rhs.row.mastery }
                return lhs.row.en < rhs.row.en
            }
        case .dueSoon:
            return rows.sorted { lhs, rhs in
                let left = nextDue(lhs.word)
                let right = nextDue(rhs.word)
                if left != right { return left < right }
                return lhs.row.en < rhs.row.en
            }
        }
    }

    /// Najbliższy termin ćwiczonego znaczenia; nowe słowa na końcu.
    private static func nextDue(_ word: Word) -> Timestamp {
        let dues = word.meanings.filter { !$0.isNew }.map { $0.due }
        return dues.min() ?? .greatestFiniteMagnitude
    }

    private static func sections(_ rows: [WordListRow], sort: WordSortOrder) -> [WordListSection] {
        guard sort == .alphabetical else {
            return rows.isEmpty ? [] : [WordListSection(id: "all", title: nil, rows: rows)]
        }
        var result: [WordListSection] = []
        var current: [WordListRow] = []
        var currentLetter = ""
        for row in rows {
            let letter = row.en.first.map { String($0).uppercased() } ?? "#"
            if letter != currentLetter, !current.isEmpty {
                result.append(WordListSection(id: "\(result.count)-\(currentLetter)", title: currentLetter, rows: current))
                current = []
            }
            currentLetter = letter
            current.append(row)
        }
        if !current.isEmpty {
            result.append(WordListSection(id: "\(result.count)-\(currentLetter)", title: currentLetter, rows: current))
        }
        return result
    }
}
