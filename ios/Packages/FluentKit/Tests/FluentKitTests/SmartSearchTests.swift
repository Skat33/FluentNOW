import Foundation
import XCTest
@testable import FluentKit

/// FEEDBACK-9 N3: podpowiedzi podczas pisania, literówki („Czy chodziło Ci o…?”), polskie znaki,
/// ranking i wydajność wyszukiwania słownika.
final class SmartSearchTests: XCTestCase {
    private func entry(_ term: String, _ translation: String, level: String = "A2", frequency: String = "common", ref: String) -> DictionaryIndex.Entry {
        DictionaryIndex.Entry(term: term, translation: translation, level: level, frequency: frequency, reference: ref)
    }

    private var fixture: [DictionaryIndex.Entry] {
        [
            entry("car", "samochód", level: "A1", frequency: "very_common", ref: "transport/car"),
            entry("card", "karta", level: "A1", frequency: "very_common", ref: "money/card"),
            entry("career", "kariera", level: "B1", ref: "work/career"),
            entry("carrot", "marchewka", level: "A1", frequency: "less_common", ref: "food/carrot"),
            entry("sports car", "samochód sportowy", level: "B1", frequency: "less_common", ref: "transport/sports-car"),
            entry("rental car", "wypożyczony samochód", level: "A2", ref: "travel/rental-car"),
            entry("receive", "otrzymać, otrzymywać", level: "A2", frequency: "very_common", ref: "core-c01/core.receive"),
            entry("believe", "wierzyć", level: "A1", frequency: "very_common", ref: "core-c01/core.believe"),
            entry("accommodation", "zakwaterowanie", level: "B1", ref: "hotel/accommodation"),
            entry("turn yellow", "zażółcić się", level: "B2", frequency: "rare", ref: "colors/turn-yellow"),
            entry("catch up", "nadrobić zaległości", level: "B1", ref: "school/catch-up"),
            entry("catch up", "nadrobić zaległości", level: "B1", ref: "work/catch-up"),
            entry("catch up", "nadrobić zaległości", level: "B1", frequency: "very_common", ref: "core-c03/core.catch-up"),
            entry("catch up", "dogonić", level: "B1", ref: "sport/catch-up-2"),
            entry("check", "rachunek (AmE)", level: "A2", ref: "restaurant/check"),
            entry("borrow", "pożyczyć", level: "A2", frequency: "very_common", ref: "starter/starter.borrow"),
            entry("lend", "pożyczyć komuś", level: "A2", ref: "starter/starter.lend"),
            entry("house", "dom (budynek)", level: "A1", frequency: "very_common", ref: "home/house"),
            entry("home", "dom", level: "A1", frequency: "very_common", ref: "home/home"),
            entry("domain", "dziedzina", level: "C1", frequency: "less_common", ref: "core-c05/core.domain")
        ]
    }

    // MARK: FuzzyMatcher

    func testThresholdsDependOnLength() {
        XCTAssertEqual(FuzzyMatcher.maxDistance(forLength: 2), 0)
        XCTAssertEqual(FuzzyMatcher.maxDistance(forLength: 3), 1)
        XCTAssertEqual(FuzzyMatcher.maxDistance(forLength: 5), 1)
        XCTAssertEqual(FuzzyMatcher.maxDistance(forLength: 6), 2)
        XCTAssertEqual(FuzzyMatcher.maxDistance(forLength: 14), 2)
        XCTAssertEqual(FuzzyMatcher.looseDistance(forLength: 3), 0)
        XCTAssertEqual(FuzzyMatcher.looseDistance(forLength: 5), 1)
        XCTAssertEqual(FuzzyMatcher.looseDistance(forLength: 8), 2)
        XCTAssertEqual(FuzzyMatcher.looseDistance(forLength: 11), 3)
    }

    func testDamerauDistanceCountsTranspositionAsOneEdit() {
        XCTAssertEqual(FuzzyMatcher.distance("recieve", "receive", limit: 2), 1)
        XCTAssertEqual(FuzzyMatcher.distance("teh", "the", limit: 1), 1)
        XCTAssertEqual(FuzzyMatcher.distance("hpuse", "house", limit: 1), 1)
        XCTAssertEqual(FuzzyMatcher.distance("acomodation", "accommodation", limit: 2), 2)
        XCTAssertNil(FuzzyMatcher.distance("kitten", "sitting", limit: 2))
        XCTAssertEqual(FuzzyMatcher.distance("kitten", "sitting", limit: 3), 3)
        XCTAssertEqual(FuzzyMatcher.distance("", "abc", limit: 3), 3)
        XCTAssertNil(FuzzyMatcher.distance("abc", "", limit: 2))
        XCTAssertNil(FuzzyMatcher.distance("abc", "abd", limit: -1))
    }

    func testPolishLettersAreFoldedBeforeComparing() {
        XCTAssertEqual(FuzzyMatcher.distance("zażółć", "zazolc", limit: 1), 0)
        XCTAssertEqual(FuzzyMatcher.distance("Łódź", "lodz", limit: 1), 0)
        XCTAssertEqual(FuzzyMatcher.distance("pożyczyc", "pozyczyć", limit: 1), 0)
    }

    func testDistanceIsConsistentWithLevenshtein() {
        let words = ["house", "horse", "mouse", "hose", "houses", "use", "shoe", "hoarse", "us", "h"]
        for a in words {
            for b in words {
                let expected = TextNormalizer.levenshtein(a, b)
                // A transposition is one edit instead of two, so OSA ≤ Levenshtein ≤ 2 × OSA.
                if let value = FuzzyMatcher.distance(a, b, limit: 6) {
                    XCTAssertLessThanOrEqual(value, expected, "\(a) / \(b)")
                    XCTAssertGreaterThanOrEqual(value * 2, expected, "\(a) / \(b)")
                } else {
                    XCTFail("\(a) / \(b) should be within 6")
                }
            }
        }
    }

    func testSharedStartPrefilter() {
        XCTAssertTrue(FuzzyMatcher.sharesStart(Array("ouse".utf8), Array("house".utf8)), "brak pierwszej litery")
        XCTAssertTrue(FuzzyMatcher.sharesStart(Array("hpuse".utf8), Array("house".utf8)))
        XCTAssertTrue(FuzzyMatcher.sharesStart(Array("ohuse".utf8), Array("house".utf8)), "zamienione litery")
        XCTAssertTrue(FuzzyMatcher.sharesStart(Array("mouse".utf8), Array("house".utf8)))
        XCTAssertFalse(FuzzyMatcher.sharesStart(Array("xyz".utf8), Array("house".utf8)))
        XCTAssertFalse(FuzzyMatcher.sharesStart([], Array("house".utf8)))
    }

    func testClosestAmongOwnWords() {
        let own = ["house", "horse", "mouse", "Hose", "home"]
        XCTAssertEqual(FuzzyMatcher.closest(to: "hous", in: own), ["house"])
        // „hosue”: „house” (zamiana liter) i „Hose” (brak litery) — po 1 edycji, w kolejności listy.
        XCTAssertEqual(FuzzyMatcher.closest(to: "hosue", in: own), ["house", "Hose"])
        XCTAssertTrue(FuzzyMatcher.closest(to: "house", in: own).allSatisfy { $0 != "house" }, "dokładne trafienie nie jest poprawką")
        XCTAssertTrue(FuzzyMatcher.closest(to: "ho", in: own).isEmpty, "za krótkie zapytanie")
    }

    func testFuzzyIndexMergesKeysAndOrdersByDistance() {
        let index = FuzzyIndex(keys: [(key: "house", payload: 0), (key: "house", payload: 1), (key: "horse", payload: 2), (key: "hose", payload: 3)])
        XCTAssertEqual(index.count, 3)
        let found = index.matches(Array("hous".utf8), maxDistance: 2)
        XCTAssertEqual(found.first?.payload, [0, 1])
        XCTAssertEqual(found.first?.distance, 1)
        XCTAssertTrue(index.matches(Array("house".utf8), maxDistance: 1).allSatisfy { $0.payload != [0, 1] }, "bez trafienia dokładnego")
        XCTAssertTrue(index.matches(Array("hous".utf8), maxDistance: 0).isEmpty)
    }

    // MARK: Suggestions

    func testSuggestionOrderExactPrefixPolishPhrase() {
        let search = ContentSearch(entries: fixture)
        let result = search.suggestions("car")
        XCTAssertEqual(result.matches.first?.term, "car")
        XCTAssertEqual(result.matches.first?.match, .exact)
        let kinds = result.matches.map { $0.match }
        XCTAssertEqual(kinds, kinds.sorted(), "kolejność: dokładne → prefiks EN → PL → wewnątrz frazy")
        XCTAssertEqual(Array(result.matches.map { $0.term }.prefix(3)), ["car", "card", "career"], "częstsze i krótsze pierwsze")
        XCTAssertEqual(result.matches.last?.match, .wordPrefix, "„sports car” / „rental car” na końcu")
        XCTAssertTrue(result.corrections.isEmpty)
        XCTAssertTrue(result.similar.isEmpty)
    }

    func testPolishQueryWithAndWithoutDiacritics() {
        let search = ContentSearch(entries: fixture)
        for query in ["samochód", "samochod", "SAMOCHÓD"] {
            let result = search.suggestions(query)
            XCTAssertEqual(result.matches.first?.term, "car", query)
            XCTAssertEqual(result.matches.first?.match, .polishExact, query)
            XCTAssertTrue(result.matches.contains { $0.term == "sports car" && $0.match == .polish }, query)
        }
        XCTAssertEqual(search.suggestions("zazolc").matches.first?.term, "turn yellow")
        XCTAssertEqual(search.suggestions("zażółć").matches.first?.term, "turn yellow")
        XCTAssertEqual(search.suggestions("pozyczyc").matches.first?.term, "borrow")
        XCTAssertEqual(search.suggestions("pozyczyc").matches.first?.match, .polishExact)
        XCTAssertTrue(search.suggestions("pozyczyc").matches.contains { $0.term == "lend" })
        // Etykieta (AmE) nie przeszkadza w dopasowaniu całego tłumaczenia.
        XCTAssertEqual(search.suggestions("rachunek").matches.first?.match, .polishExact)
        // Alternatywy po przecinku są „całym tłumaczeniem”.
        XCTAssertEqual(search.suggestions("otrzymywać").matches.first?.term, "receive")
        XCTAssertEqual(search.suggestions("otrzymywać").matches.first?.match, .polishExact)
    }

    func testPolishExactBeatsEnglishPrefix() {
        let search = ContentSearch(entries: fixture)
        let terms = search.suggestions("dom").matches.map { $0.term }
        XCTAssertEqual(Array(terms.prefix(2)).sorted(), ["home", "house"])
        XCTAssertEqual(terms.last, "domain")
    }

    func testDuplicateSensesAreGroupedLikeSenseGrouping() {
        let search = ContentSearch(entries: fixture)
        let result = search.suggestions("catch up")
        XCTAssertEqual(result.matches.count, 1)
        XCTAssertEqual(result.matches.first?.entries.count, 4)
        XCTAssertEqual(result.matches.first?.translations.count, 2, "„nadrobić zaległości” raz + „dogonić”")
        XCTAssertEqual(result.matches.first?.translations.first, "nadrobić zaległości", "core (bardzo częste) pierwsze")
        XCTAssertEqual(search.suggestions("check").matches.first?.translations, ["rachunek"], "bez etykiety (AmE)")
    }

    func testOwnedMarkerCountsGroupedTranslationsOnce() {
        let search = ContentSearch(entries: fixture)
        guard let catchUp = search.suggestions("catch up").matches.first else { return XCTFail("brak „catch up”") }
        XCTAssertEqual(catchUp.ownedTranslationCount(in: .empty), 0)
        // Ma wpis z innego tematu — to samo znaczenie (FEEDBACK-8 M3) liczy się raz.
        let partly = OwnedVocabulary(references: ["work/catch-up"])
        XCTAssertEqual(catchUp.ownedTranslationCount(in: partly), 1)
        XCTAssertFalse(catchUp.isFullyOwned(in: partly))
        // Po haśle i tłumaczeniu (własne słowo bez odwołania do bazy).
        let both = OwnedVocabulary(references: ["core-c03/core.catch-up"], pairs: ["catch up|dogonić"])
        XCTAssertTrue(catchUp.isFullyOwned(in: both))
        guard let check = search.suggestions("check").matches.first else { return XCTFail("brak „check”") }
        XCTAssertTrue(check.isFullyOwned(in: OwnedVocabulary(pairs: ["check|rachunek"])), "etykieta (AmE) pomijana")
    }

    func testEnglishTyposGiveDidYouMean() {
        let search = ContentSearch(entries: fixture)
        let receive = search.suggestions("recieve")
        XCTAssertTrue(receive.matches.isEmpty)
        XCTAssertEqual(receive.corrections.first?.term, "receive")
        XCTAssertEqual(receive.corrections.first?.distance, 1)
        XCTAssertEqual(search.suggestions("beleive").corrections.first?.term, "believe")
        XCTAssertEqual(search.suggestions("hpuse").corrections.first?.term, "house")
        XCTAssertEqual(search.suggestions("acomodation").corrections.first?.term, "accommodation")
        XCTAssertTrue(search.suggestions("acomodation").similar.isEmpty)
        // Short words: one typo only.
        XCTAssertEqual(search.suggestions("carx").corrections.map { $0.term }.contains("car"), true)
        XCTAssertFalse(search.suggestions("cxrx").corrections.contains { $0.term == "car" })
    }

    func testPolishTypos() {
        let search = ContentSearch(entries: fixture)
        let result = search.suggestions("smochód")
        XCTAssertTrue(result.matches.isEmpty)
        XCTAssertEqual(result.corrections.first?.term, "car")
        XCTAssertEqual(search.suggestions("zakwaterownie").corrections.first?.term, "accommodation")
    }

    func testNoCorrectionsWhenThereIsAPrefixMatch() {
        let search = ContentSearch(entries: fixture)
        XCTAssertTrue(search.suggestions("hous").corrections.isEmpty, "prefiks „house” wystarcza")
        XCTAssertEqual(search.suggestions("hous").matches.first?.term, "house")
    }

    func testSimilarWordsOnlyWhenNothingElseMatched() {
        let search = ContentSearch(entries: fixture)
        let loose = search.suggestions("acomodasion")
        XCTAssertTrue(loose.matches.isEmpty)
        XCTAssertTrue(loose.corrections.isEmpty)
        XCTAssertEqual(loose.similar.first?.term, "accommodation")
        let nothing = search.suggestions("qqqqzz")
        XCTAssertTrue(nothing.isEmpty)
        XCTAssertTrue(search.suggestions("   ").isEmpty)
        XCTAssertTrue(ContentSearch(entries: []).suggestions("car").isEmpty)
    }

    func testSingleLetterShowsCommonWordsFirstAndRespectsLimit() {
        let search = ContentSearch(entries: fixture)
        let result = search.suggestions("c", limit: 3)
        XCTAssertEqual(result.matches.count, 3)
        XCTAssertEqual(Array(result.matches.map { $0.term }.prefix(2)), ["car", "card"])
        XCTAssertFalse(result.matches.contains { $0.term == "carrot" }, "rzadsze słowo poza limitem")
    }

    func testSearchKeepsTypoFallbackWithNewThresholds() {
        let search = ContentSearch(entries: fixture)
        XCTAssertEqual(search.search("recieve").first?.entry.term, "receive")
        XCTAssertEqual(search.search("recieve").first?.match, .fuzzy)
        XCTAssertEqual(search.search("samochod").first?.match, .polishExact)
        XCTAssertTrue(search.search("samochod").first?.match.isPolish ?? false)
        XCTAssertFalse(SearchMatchKind.exact.isPolish)
    }

    // MARK: Performance

    func testSuggestionPerformanceOn15000Records() {
        var entries: [DictionaryIndex.Entry] = []
        let syllables = ["ka", "lo", "mi", "ter", "pas", "bor", "gan", "die", "son", "rel", "vu", "nex", "sta", "pri"]
        let polish = ["dom", "praca", "szkoła", "pożyczyć", "żółty", "samochód", "lotnisko", "kariera"]
        for index in 0..<15_000 {
            var term = ""
            var value = index
            for _ in 0..<3 {
                term += syllables[value % syllables.count]
                value /= syllables.count
            }
            if index % 5 == 0 { term += " " + syllables[(index / 7) % syllables.count] + "s" }
            let translation = polish[index % polish.count] + " " + syllables[(index / 3) % syllables.count]
            entries.append(DictionaryIndex.Entry(term: term, translation: translation, level: "B1", frequency: index % 3 == 0 ? "common" : "rare", reference: "t/\(index)"))
        }
        let buildStart = Date()
        let search = ContentSearch(entries: entries)
        XCTAssertLessThan(Date().timeIntervalSince(buildStart), 5.0)
        let queries = ["k", "ka", "kalo", "zolty", "żółty ka", "samochod", "kalomx", "borpasgn", "lotnsko", "praca", "zzzzzzzz", "terpasganx"]
        let start = Date()
        for query in queries { _ = search.suggestions(query) }
        let perQuery = Date().timeIntervalSince(start) / Double(queries.count)
        // Cel: < 30 ms na symulatorze (build Release/optymalizowany ≈ kilka ms); test w Debug z zapasem.
        XCTAssertLessThan(perQuery, 0.15)
    }

    /// Prawdziwy słownik (pomijany, gdy treść aplikacji nie leży obok pakietu).
    func testRealDictionaryTyposAndSpeed() throws {
        let dictionary = try ContentDecoder.dictionaryIndex(from: try TestData.contentData("dictionary-index.json"))
        let search = ContentSearch(index: dictionary)
        XCTAssertEqual(search.suggestions("recieve").corrections.first?.term, "receive")
        XCTAssertEqual(search.suggestions("neccessary").corrections.first?.term, "necessary")
        XCTAssertEqual(search.suggestions("pronounciation").corrections.first?.term, "pronunciation")
        XCTAssertEqual(search.suggestions("samochod").matches.first?.term, "car")
        XCTAssertEqual(search.suggestions("wiedziec").matches.first?.term, "know")
        let queries = ["c", "ca", "car", "dom", "kup", "recieve", "acomodasion", "zazolc", "brake down", "smochod"]
        let start = Date()
        for query in queries { _ = search.suggestions(query) }
        let perQuery = Date().timeIntervalSince(start) / Double(queries.count)
        XCTAssertLessThan(perQuery, 0.15)
    }
}
