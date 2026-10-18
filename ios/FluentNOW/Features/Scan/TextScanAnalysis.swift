import Foundation
import NaturalLanguage
import FluentKit

/// Słowo z zeskanowanego tekstu: forma bazowa (lemat), forma z tekstu i status.
struct ScannedWord: Identifiable, Hashable, Sendable {
    /// Forma bazowa małymi literami („went” → „go”) — hasło dla szybkiego dodawania.
    let lemma: String
    /// Pierwsza forma, w jakiej słowo wystąpiło w tekście.
    let surface: String
    /// Ile razy wystąpiło w tekście.
    let occurrences: Int
    var status: ScannedWordStatus

    var id: String { lemma }

    /// `true`, gdy forma z tekstu różni się od formy bazowej (pokazujemy „w tekście: …”).
    var showsSurface: Bool { surface.lowercased() != lemma }
}

/// Czy użytkownik ma słowo, czy jest ono we wbudowanej bazie.
enum ScannedWordStatus: Int, Hashable, Sendable, Comparable {
    /// Jest w bazie, użytkownik go nie ma — najciekawsze.
    case inBase = 0
    /// Spoza bazy — można dodać z AI lub ręcznie.
    case unknown = 1
    /// „Masz już” — wyszarzone na końcu listy.
    case owned = 2

    static func < (lhs: ScannedWordStatus, rhs: ScannedWordStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Słowo z tekstu przed sprawdzeniem statusu.
struct ScannedToken: Hashable, Sendable {
    let lemma: String
    let surface: String
    let occurrences: Int
}

/// Tokenizacja i formy bazowe (NaturalLanguage `NLTagger`, schemat `.lemma`, język angielski).
/// Czyste funkcje bez stanu — wywoływane poza głównym wątkiem.
enum TextScanAnalyzer {
    /// Najwyżej tyle różnych słów z jednego tekstu (długie strony nie blokują listy).
    static let maxWords = 300

    /// Słowa funkcyjne pomijane na liście (rodzajniki, zaimki, spójniki, przyimki, formy „be”).
    static let skipped: Set<String> = [
        "a", "an", "the", "and", "or", "but", "if", "of", "to", "in", "on", "at", "by", "for", "with", "from",
        "as", "is", "am", "are", "was", "were", "be", "been", "being", "it", "its", "i", "you", "he", "she",
        "we", "they", "me", "him", "her", "us", "them", "my", "your", "his", "our", "their", "this", "that",
        "these", "those", "not", "no", "so", "do", "does", "did", "s", "t", "ll", "re", "ve", "d", "m"
    ]

    /// Unikalne słowa w kolejności pierwszego wystąpienia.
    static func tokens(in text: String) -> [ScannedToken] {
        let cleaned = text.replacingOccurrences(of: "\u{2019}", with: "'")
        guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = cleaned
        let whole = cleaned.startIndex..<cleaned.endIndex
        tagger.setLanguage(.english, range: whole)
        var order: [String] = []
        var surfaces: [String: String] = [:]
        var counts: [String: Int] = [:]
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        tagger.enumerateTags(in: whole, unit: .word, scheme: .lemma, options: options) { (tag: NLTag?, range: Range<String.Index>) -> Bool in
            let surface = String(cleaned[range])
            guard isWordLike(surface) else { return true }
            let lemma = normalizedLemma(tag?.rawValue, surface: surface)
            guard lemma.count >= 2, !skipped.contains(lemma) else { return true }
            if counts[lemma] == nil {
                guard order.count < maxWords else { return true }
                order.append(lemma)
                surfaces[lemma] = surface
            }
            counts[lemma, default: 0] += 1
            return true
        }
        return order.map { (lemma: String) -> ScannedToken in
            ScannedToken(lemma: lemma, surface: surfaces[lemma] ?? lemma, occurrences: counts[lemma] ?? 1)
        }
    }

    /// Litery łacińskie z ewentualnym apostrofem lub łącznikiem w środku (bez liczb, adresów, symboli).
    static func isWordLike(_ text: String) -> Bool {
        guard let first = text.first, first.isASCII, first.isLetter else { return false }
        for character in text {
            if character.isASCII && character.isLetter { continue }
            if character == "'" || character == "-" { continue }
            return false
        }
        return true
    }

    /// Lemat małymi literami; brak lematu (słowo nieznane modelowi) → forma z tekstu. Dopełniacz
    /// i skrócenia („teacher's”, „don't”) bez końcówki po apostrofie.
    static func normalizedLemma(_ lemma: String?, surface: String) -> String {
        var value = (lemma?.isEmpty == false ? lemma ?? surface : surface).lowercased()
        if let apostrophe = value.firstIndex(of: "'") {
            value = String(value[value.startIndex..<apostrophe])
        }
        return value.trimmingCharacters(in: CharacterSet(charactersIn: "-'"))
    }

    /// Jedno słowo w transkrypcji (dotknięcie pojedynczego słowa w podglądzie aparatu).
    static func singleLemma(in text: String) -> String? {
        let found = tokens(in: text)
        guard found.count == 1, let only = found.first else { return nil }
        let words = text.split(whereSeparator: { $0.isWhitespace })
        return words.count == 1 ? only.lemma : nil
    }
}

/// Status słów: „Masz już” (`OwnedVocabulary`) i „W bazie” (dokładne trafienie w słowniku wbudowanym).
enum TextScanClassifier {
    /// Ile czekamy na indeks słownika budowany w tle przy pierwszym użyciu.
    static let indexWaitAttempts = 20

    static func classify(_ tokens: [ScannedToken], owned: OwnedVocabulary, content: ContentLibrary) async -> [ScannedWord] {
        guard !tokens.isEmpty else { return [] }
        let indexReady = await waitForSearchIndex(content)
        var result: [ScannedWord] = []
        result.reserveCapacity(tokens.count)
        for token in tokens {
            if Task.isCancelled { return result }
            let status: ScannedWordStatus
            if owned.containsTerm(token.lemma) || owned.containsTerm(token.surface) {
                status = .owned
            } else if indexReady, await isInBase(token, content: content) {
                status = .inBase
            } else {
                status = .unknown
            }
            result.append(ScannedWord(lemma: token.lemma, surface: token.surface, occurrences: token.occurrences, status: status))
        }
        // Stabilnie: najpierw „w bazie”, potem spoza bazy, na końcu „Masz już”; w grupie kolejność z tekstu.
        let indexed = result.enumerated().map { (offset: $0.offset, word: $0.element) }
        return indexed.sorted { (lhs: (offset: Int, word: ScannedWord), rhs: (offset: Int, word: ScannedWord)) -> Bool in
            if lhs.word.status != rhs.word.status { return lhs.word.status < rhs.word.status }
            return lhs.offset < rhs.offset
        }.map { $0.word }
    }

    private static func isInBase(_ token: ScannedToken, content: ContentLibrary) async -> Bool {
        let hits: [SearchHit] = await content.search(token.lemma, limit: 3)
        if hits.contains(where: { $0.match == .exact }) { return true }
        guard token.surface.lowercased() != token.lemma else { return false }
        let surfaceHits: [SearchHit] = await content.search(token.surface, limit: 3)
        return surfaceHits.contains(where: { $0.match == .exact })
    }

    /// Pierwsze wyszukiwanie uruchamia budowę indeksu; czekamy najwyżej ~3 s.
    private static func waitForSearchIndex(_ content: ContentLibrary) async -> Bool {
        if await content.isSearchReady { return true }
        _ = await content.search("a", limit: 1)
        for _ in 0..<indexWaitAttempts {
            if await content.isSearchReady { return true }
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return false }
        }
        return await content.isSearchReady
    }
}
