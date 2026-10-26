import XCTest
import FluentKit
@testable import FluentNOW

/// Czyste funkcje ekranów (Features) — testy dopisane przez code-qa (backlog: „Testy jednostkowe
/// czystych funkcji z obszaru ui-library”). `@MainActor`, bo część funkcji to statyczne metody
/// typów `View` (w SDK iOS 18+ izolowane do głównego aktora).
@MainActor
final class FeaturePureFunctionTests: XCTestCase {

    // MARK: Odmiana i formatowanie

    func testPolishPluralForms() {
        for (count, expected) in [(1, "słowo"), (2, "słowa"), (4, "słowa"), (5, "słów"), (12, "słów"), (14, "słów"), (22, "słowa"), (25, "słów"), (0, "słów"), (-3, "słowa")] {
            XCTAssertEqual(LibraryText.plural(count, one: "słowo", few: "słowa", many: "słów"), expected, "\(count)")
            XCTAssertEqual(StudyFormat.plural(count, one: "słowo", few: "słowa", many: "słów"), expected, "\(count)")
        }
        XCTAssertEqual(LibraryText.words(3), "3 słowa")
        XCTAssertEqual(LibraryText.meanings(5), "5 znaczeń")
        XCTAssertEqual(StudyFormat.tasks(1), "1 zadanie")
        XCTAssertEqual(StudyFormat.exercises(13), "13 ćwiczeń")
    }

    func testStudyClockAndDuration() {
        XCTAssertEqual(StudyFormat.clock(0), "00:00")
        XCTAssertEqual(StudyFormat.clock(65), "01:05")
        XCTAssertEqual(StudyFormat.clock(-5), "00:00")
        XCTAssertEqual(StudyFormat.clock(3_600), "60:00")
        XCTAssertEqual(StudyFormat.duration(45), "45 s")
        XCTAssertEqual(StudyFormat.duration(200), "3 min 20 s")
        XCTAssertEqual(StudyFormat.duration(180), "3 min")
        XCTAssertEqual(StudyFormat.duration(.nan), "0 s")
        XCTAssertEqual(StudyFormat.duration(-1), "0 s")
        XCTAssertEqual(StudyFormat.letter(0), "A")
        XCTAssertEqual(StudyFormat.letter(9), "10")
        XCTAssertEqual(StudyFormat.percent(1, of: 3), 33)
        XCTAssertEqual(StudyFormat.percent(1, of: 0), 0)
    }

    // MARK: Kolekcje

    func testCollectionNameIssues() {
        XCTAssertNotNil(CollectionMutations.nameIssue("   ", existing: []))
        XCTAssertNotNil(CollectionMutations.nameIssue(String(repeating: "a", count: 61), existing: []))
        XCTAssertNotNil(CollectionMutations.nameIssue("lotnisko", existing: ["Lotnisko"]))
        XCTAssertNil(CollectionMutations.nameIssue("Lotnisko", existing: ["Lotnisko"], current: "Lotnisko"), "własna nazwa przy edycji")
        XCTAssertNil(CollectionMutations.nameIssue("Hotel", existing: ["Lotnisko"]))
    }

    func testCollectionRenameMovesWordsAndMergesNames() {
        var state = LearnerState(
            words: [
                ServicesTestSupport.word("a", en: "gate", pl: "bramka"),
                ServicesTestSupport.word("b", en: "tip", pl: "napiwek", archived: true)
            ],
            collections: ["Test", "Inna"]
        )
        CollectionMutations.rename(&state, from: "Test", to: "  Podróże ", now: 99)
        XCTAssertEqual(state.words.map(\.collection), ["Podróże", "Podróże"], "także słowa w archiwum")
        XCTAssertEqual(state.words.map(\.updatedAt), [99, 99])
        XCTAssertEqual(state.collections, ["Podróże", "Inna"])
        // Zmiana na istniejącą nazwę scala kolekcje (bez duplikatu).
        CollectionMutations.rename(&state, from: "Podróże", to: "Inna", now: 100)
        XCTAssertEqual(state.collections, ["Inna"])
        // Pusta nazwa — bez zmian.
        let before = state
        CollectionMutations.rename(&state, from: "Inna", to: "  ", now: 101)
        XCTAssertEqual(state, before)
    }

    func testCollectionDeleteKeepsWordsInFallback() {
        var state = LearnerState(words: [ServicesTestSupport.word("a", en: "gate", pl: "bramka")], collections: ["Test"])
        CollectionMutations.delete(&state, name: "Test", now: 5)
        XCTAssertEqual(state.words.count, 1, "słowa nie są usuwane")
        XCTAssertEqual(state.words[0].collection, VocabularyMerger.defaultCollection)
        XCTAssertEqual(state.collections, [VocabularyMerger.defaultCollection])
        XCTAssertEqual(CollectionMutations.fallbackName(forDeleting: VocabularyMerger.defaultCollection), "Inne")
    }

    // MARK: Nauka

    func testDecodeStudyModesSkipsUnknownAndDuplicates() {
        XCTAssertEqual(StudyHomeView.decodeModes("mixed,reading,mixed,bogus,language-mix"), [.mixed, .reading, .languageMix])
        XCTAssertEqual(StudyHomeView.decodeModes(""), [])
    }

    func testResumeItemsListOnlyUnfinishedSessions() {
        var state = PreviewData.state()
        XCTAssertEqual(StudyResumeItem.items(in: state).count, 1, "przerwana sesja słówek z danych podglądu")
        if var session = state.session {
            session.index = session.tasks.count
            state.session = session
        }
        XCTAssertTrue(StudyResumeItem.items(in: state).isEmpty, "ukończona sesja nie jest do wznowienia")
        XCTAssertTrue(StudyResumeItem.items(in: LearnerState()).isEmpty)
    }

    // MARK: Dodawanie słów

    func testAddWordCandidatesGroupByTerm() {
        let hits = [
            SearchHit(entry: DictionaryIndex.Entry(term: "board", translation: "deska", level: "A2", reference: "home/a"), match: .exact),
            SearchHit(entry: DictionaryIndex.Entry(term: "boarding pass", translation: "karta pokładowa", level: "A2", reference: "airport/b"), match: .prefix),
            SearchHit(entry: DictionaryIndex.Entry(term: "board", translation: "wejść na pokład", level: "B1", reference: "airport/c"), match: .exact),
            SearchHit(entry: DictionaryIndex.Entry(term: "Board", translation: "deska", level: "A2", reference: "home/d"), match: .exact)
        ]
        let candidates = AddWordCandidate.group(hits)
        XCTAssertEqual(candidates.map(\.term), ["board", "boarding pass"])
        XCTAssertEqual(candidates.first?.translations, ["deska", "wejść na pokład"])
        XCTAssertEqual(candidates.first?.isPolishMatch, false)
    }

    func testKnownSenseIndicesIgnoreArchivedAndDialectLabels() {
        let lookup = Lookup(term: "Check", meanings: [
            SenseSuggestion(translation: "rachunek (AmE)"),
            SenseSuggestion(translation: "sprawdzić")
        ])
        let owned = ServicesTestSupport.word("c", en: "check", pl: "rachunek")
        XCTAssertEqual(AddWordLogic.knownSenseIndices(lookup, words: [owned]), [0])
        let archived = ServicesTestSupport.word("c2", en: "check", pl: "sprawdzić", archived: true)
        XCTAssertEqual(AddWordLogic.knownSenseIndices(lookup, words: [archived]), [])
    }

    /// FEEDBACK-8 M3: zgrupowane znaczenie jest „Masz już”, gdy użytkownik ma którykolwiek z wpisów.
    func testKnownSenseIndicesSeeGroupedEntries() {
        var owned = ServicesTestSupport.word("w", en: "weigh", pl: "zważyć")
        owned.meanings[0].contentRef = "b/b.weigh"
        let lookup = Lookup(term: "weigh", meanings: [
            SenseSuggestion(translation: "ważyć", contentRef: "a/a.weigh", mergedContentRefs: ["b/b.weigh"]),
            SenseSuggestion(translation: "przeważać", contentRef: "c/c.weigh")
        ])
        XCTAssertEqual(AddWordLogic.knownSenseIndices(lookup, words: [owned]), [0])
    }

    func testAddWordCandidateTranslationsAreUniqueAfterNormalisation() {
        let hits = [
            SearchHit(entry: DictionaryIndex.Entry(term: "catch up", translation: "nadrobić zaległości", level: "B1", reference: "a/1"), match: .exact),
            SearchHit(entry: DictionaryIndex.Entry(term: "catch up", translation: "Nadrobić zaległości.", level: "B1", reference: "b/2"), match: .exact),
            SearchHit(entry: DictionaryIndex.Entry(term: "catch up", translation: "dogonić", level: "A2", reference: "c/3"), match: .exact)
        ]
        XCTAssertEqual(AddWordCandidate.group(hits).first?.translations, ["nadrobić zaległości", "dogonić"])
    }

    func testSanitizedAssistantLookupMarksAIAndDropsBrokenFocus() {
        let lookup = Lookup(term: "gate", meanings: [
            SenseSuggestion(translation: "bramka", level: "X9", examples: [
                ExamplePair(en: "Go to gate 12.", pl: "Idź do bramki 12.", focusEn: "door", focusPl: "bramki")
            ]),
            SenseSuggestion(translation: "   ")
        ], source: .starter)
        let clean = AddWordLogic.sanitizedAssistantLookup(lookup)
        XCTAssertEqual(clean.source, .ai)
        XCTAssertEqual(clean.meanings.count, 1)
        XCTAssertEqual(clean.meanings[0].level, "")
        XCTAssertEqual(clean.meanings[0].examples.first?.focusEn, "", "wyróżnienie spoza zdania jest usuwane")
        XCTAssertEqual(clean.meanings[0].examples.first?.focusPl, "bramki")
    }

    // MARK: Ustawienia i czytanie

    func testImportLooksLikeJSON() {
        XCTAssertTrue(SettingsImportText.looksLikeJSON(Data("  \n{\"version\":1}".utf8)))
        XCTAssertTrue(SettingsImportText.looksLikeJSON(Data([0xEF, 0xBB, 0xBF, 0x7B])), "BOM + {")
        XCTAssertFalse(SettingsImportText.looksLikeJSON(Data("english,polish".utf8)))
        XCTAssertFalse(SettingsImportText.looksLikeJSON(Data()))
    }

    func testReadingWordLinkRoundTrip() throws {
        for id in ["preview.gate", "w-123", "a b", "0f8c2d4e-1a2b-4c3d-9e8f-123456789abc"] {
            let url = try XCTUnwrap(ReadingWordLink.url(for: id))
            XCTAssertEqual(ReadingWordLink.wordID(from: url), id)
        }
        XCTAssertNil(ReadingWordLink.wordID(from: try XCTUnwrap(URL(string: "https://example.com/x"))))
    }
}
