import XCTest
import FluentKit
@testable import FluentNOW

/// FEEDBACK-9 N3 po stronie aplikacji: wyszukiwanie głosowe (logika bez mikrofonu), dodatki
/// wyszukiwania w Słowniku i `ContentLibrary.suggestions` na prawdziwej treści.
@MainActor
final class SmartSearchAppTests: XCTestCase {

    // MARK: Wyszukiwanie głosowe

    func testTranscriptCleanup() {
        XCTAssertEqual(VoiceSearchController.cleaned("  Boarding pass. "), "boarding pass")
        XCTAssertEqual(VoiceSearchController.cleaned("Zażółć?!"), "zażółć")
        XCTAssertEqual(VoiceSearchController.cleaned("…"), "")
        XCTAssertEqual(VoiceSearchController.cleaned("don't"), "don't")
    }

    func testLanguagesAndFields() {
        XCTAssertEqual(VoiceSearchLanguage.english.toggled, .polish)
        XCTAssertEqual(VoiceSearchLanguage.polish.toggled, .english)
        XCTAssertEqual(VoiceSearchLanguage.english.rawValue, "en-US")
        XCTAssertEqual(VoiceSearchLanguage.polish.rawValue, "pl-PL")
        XCTAssertEqual(VoiceSearchField.addWord.defaultLanguage, .english)
        XCTAssertEqual(VoiceSearchField.dictionary.defaultLanguage, .english)
        XCTAssertEqual(VoiceSearchField.topic.defaultLanguage, .polish)
        let keys = Set([VoiceSearchField.addWord, .dictionary, .topic].map { $0.storageKey })
        XCTAssertEqual(keys.count, 3, "każde pole pamięta własny język")
    }

    func testControllerStartsIdleAndStopIsSafeWithoutAudio() {
        let voice = VoiceSearchController()
        XCTAssertEqual(voice.state, .idle)
        XCTAssertFalse(voice.isActive)
        voice.stop()
        voice.cancel()
        XCTAssertEqual(voice.state, .idle)
        XCTAssertNil(VoiceSearchStatus.text(for: voice))
        XCTAssertTrue(VoiceSearchIssue.permissionDenied.offersSettings)
        XCTAssertFalse(VoiceSearchIssue.unavailable(.polish).offersSettings)
        XCTAssertTrue(VoiceSearchIssue.unavailable(.polish).message.contains("po polsku"))
    }

    // MARK: Słownik

    func testOwnCorrectionsOnlyWhenNothingMatched() {
        var state = LearnerState()
        state.words = [
            ServicesTestSupport.word("h", en: "house", pl: "dom"),
            ServicesTestSupport.word("b", en: "borrow", pl: "pożyczyć"),
            ServicesTestSupport.word("a", en: "hose", pl: "wąż ogrodowy", archived: true)
        ]
        let extras = WordSearchExtras.local(state: state, query: "hosue", needsCorrections: true)
        XCTAssertEqual(extras.ownCorrections, ["house"], "zarchiwizowane pominięte")
        XCTAssertEqual(WordSearchExtras.local(state: state, query: "pozyczyc", needsCorrections: true).ownCorrections, [], "bez polskich znaków to nie literówka")
        XCTAssertEqual(WordSearchExtras.local(state: state, query: "pozyczyx", needsCorrections: true).ownCorrections, ["pożyczyć"])
        XCTAssertTrue(WordSearchExtras.local(state: state, query: "hosue", needsCorrections: false).ownCorrections.isEmpty)
        XCTAssertTrue(extras.owned.containsTerm("house"))
    }

    func testBuiltInSuggestionsSkipOwnedWords() {
        let car = SearchSuggestion(term: "car", key: "car", translations: ["samochód"], level: "A1", match: .exact, distance: 0,
                                   entries: [DictionaryIndex.Entry(term: "car", translation: "samochód", reference: "t/car")])
        let card = SearchSuggestion(term: "card", key: "card", translations: ["karta"], level: "A1", match: .prefix, distance: 0,
                                    entries: [DictionaryIndex.Entry(term: "card", translation: "karta", reference: "t/card")])
        var extras = WordSearchExtras()
        extras.builtIn = SearchSuggestionResult(query: "car", matches: [car, card])
        extras.owned = OwnedVocabulary(references: ["t/car"])
        XCTAssertEqual(extras.builtInItems(hasOwnMatches: true).map { $0.term }, ["card"])
        extras.owned = OwnedVocabulary(references: ["t/car", "t/card"])
        XCTAssertTrue(extras.builtInItems(hasOwnMatches: false).isEmpty)
    }

    // MARK: ContentLibrary

    func testLibrarySuggestionsOnRepositoryContent() async throws {
        let root = ServicesTestSupport.contentRoot
        guard FileManager.default.fileExists(atPath: root.appendingPathComponent("dictionary-index.json").path) else {
            throw XCTSkip("Brak treści w \(root.path)")
        }
        let library = ContentLibrary(rootURL: root)
        let typo = await library.suggestions("recieve")
        XCTAssertEqual(typo.corrections.first?.term, "receive")
        let polish = await library.suggestions("samochod")
        XCTAssertEqual(polish.matches.first?.term, "car")
        XCTAssertLessThanOrEqual(polish.matches.count, 8)
        let none = await library.suggestions("   ")
        XCTAssertTrue(none.isEmpty)
    }
}
