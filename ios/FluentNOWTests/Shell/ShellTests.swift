import XCTest
@testable import FluentNOW

/// Testy powłoki (design-shell): parsowanie deep linków, router, logika komponentów bez UI.
final class DeepLinkTests: XCTestCase {

    private func link(_ string: String) -> DeepLink? {
        guard let url = URL(string: string) else { return nil }
        return DeepLink(url: url)
    }

    func testTabs() {
        XCTAssertEqual(link("fluentnow://today"), .tab(.today))
        XCTAssertEqual(link("fluentnow://progress"), .tab(.progress))
        XCTAssertEqual(link("fluentnow://stats"), .tab(.progress))
        XCTAssertEqual(link("fluentnow://settings"), .tab(.settings))
        XCTAssertEqual(link("fluentnow://study"), .tab(.study))
        XCTAssertEqual(link("FLUENTNOW://TODAY"), .tab(.today))
    }

    func testLibrary() {
        XCTAssertEqual(link("fluentnow://words"), .library(.words, nil))
        XCTAssertEqual(link("fluentnow://words/w-123"), .library(.words, .word(id: "w-123")))
        // F1: tematy otwierają wyszukiwanie tematu (arkusz „+”), nie katalog w Słowniku.
        XCTAssertEqual(link("fluentnow://topics/airport"), .topicSearch(query: nil, topicID: "airport"))
        XCTAssertEqual(link("fluentnow://topics?q=na%20lotnisku"), .topicSearch(query: "na lotnisku", topicID: nil))
        XCTAssertEqual(link("fluentnow://collections/Lotnisko%20i%20podr%C3%B3%C5%BCe"),
                       .library(.collections, .collection(name: "Lotnisko i podróże")))
        XCTAssertEqual(link("fluentnow://recommended"), .library(.recommended, nil))
        XCTAssertEqual(link("fluentnow://useful"), .library(.recommended, nil))
    }

    func testLibrarySectionsStayBackwardCompatible() {
        // Surowe wartości są kontraktem (deep linki, ewentualny zapis wyboru) — nie zmieniamy istniejących.
        XCTAssertEqual(LibrarySection(rawValue: "words"), .words)
        XCTAssertEqual(LibrarySection(rawValue: "collections"), .collections)
        XCTAssertEqual(LibrarySection(rawValue: "topics"), .topics)
        XCTAssertEqual(LibrarySection(rawValue: "recommended"), .recommended)
        XCTAssertEqual(LibrarySection.browsable, [.words, .collections, .recommended])
        XCTAssertFalse(LibrarySection.browsable.contains(.topics))
    }

    func testStudyStart() {
        XCTAssertEqual(
            link("fluentnow://study/start?mode=mixed&mode=reading&mode=mixed&minutes=10"),
            .study(StudyLaunchRequest(modes: ["mixed", "reading"], minutes: 10))
        )
        XCTAssertEqual(
            link("fluentnow://study/start?mode=language-mix&minutes=7"),
            .study(StudyLaunchRequest(modes: ["language-mix"], minutes: nil)),
            "Niedozwolony czas → nil"
        )
        XCTAssertEqual(
            link("fluentnow://study/start?mode=DROP%20TABLE&collection=Lotnisko"),
            .study(StudyLaunchRequest(modes: ["mixed"], collection: "Lotnisko")),
            "Niepoprawny tryb jest pomijany, pusta lista → mixed"
        )
        XCTAssertEqual(link("fluentnow://study/resume"), .study(.resumeLast))
        XCTAssertNil(link("fluentnow://study/explode"))
    }

    func testQuickAdd() {
        XCTAssertEqual(link("fluentnow://add?text=borrow"), .quickAdd(prefill: "borrow"))
        XCTAssertEqual(link("fluentnow://add?text=%20%20"), .quickAdd(prefill: nil))
        XCTAssertEqual(link("fluentnow://add"), .quickAdd(prefill: nil))
        let long = String(repeating: "a", count: 500)
        XCTAssertEqual(link("fluentnow://add?text=\(long)"), .quickAdd(prefill: String(repeating: "a", count: DeepLink.maxParameterLength)))
    }

    func testRejectsForeignAndUnknown() {
        XCTAssertNil(link("https://today"))
        XCTAssertNil(link("fluentnow://"))
        XCTAssertNil(link("fluentnow://unknown"))
    }
}

@MainActor
final class AppRouterTests: XCTestCase {

    func testStartStudySwitchesTabAndIsConsumedOnce() {
        let router = AppRouter()
        router.presentQuickAdd(prefill: "x")
        router.startStudy(.mistakes)
        XCTAssertEqual(router.selectedTab, .study)
        XCTAssertNil(router.activeSheet)
        XCTAssertEqual(router.consumeStudyLaunch(), .mistakes)
        XCTAssertNil(router.consumeStudyLaunch())
    }

    func testHandleURL() throws {
        let router = AppRouter()
        XCTAssertTrue(router.handle(url: try XCTUnwrap(URL(string: "fluentnow://words/w-1"))))
        XCTAssertEqual(router.selectedTab, .words)
        XCTAssertEqual(router.librarySection, .words)
        XCTAssertEqual(router.consumeLibraryDestination(), .word(id: "w-1"))
        XCTAssertTrue(router.handle(url: try XCTUnwrap(URL(string: "fluentnow://topics/airport"))))
        XCTAssertEqual(router.activeSheet, .topicSearch(query: nil, topicID: "airport"))
        router.openLibrary(.topics)
        XCTAssertEqual(router.activeSheet, .topicSearch(query: nil, topicID: nil), "Stary segment Tematy → wyszukiwanie tematu")
        XCTAssertFalse(router.handle(url: try XCTUnwrap(URL(string: "fluentnow://nope"))))
    }

    func testOpenRecommendedSegmentFromRoot() throws {
        let router = AppRouter()
        router.push(WordRoute.detail(id: "w-1"), on: .words)
        router.select(.today)
        router.presentQuickAdd()
        router.openLibrary(.recommended)
        XCTAssertEqual(router.selectedTab, .words)
        XCTAssertEqual(router.librarySection, .recommended)
        XCTAssertTrue(router.wordsPath.isEmpty, "Polecane zawsze od korzenia Słownika")
        XCTAssertNil(router.activeSheet)
        XCTAssertNil(router.consumeLibraryDestination())

        router.librarySection = .words
        XCTAssertTrue(router.handle(url: try XCTUnwrap(URL(string: "fluentnow://recommended"))))
        XCTAssertEqual(router.librarySection, .recommended)
    }

    func testPushAndPop() {
        let router = AppRouter()
        router.push("detail", on: .words)
        XCTAssertEqual(router.selectedTab, .words)
        XCTAssertEqual(router.wordsPath.count, 1)
        router.pop(on: .words)
        XCTAssertTrue(router.wordsPath.isEmpty)
        router.pop(on: .words) // pusty stos — bez crasha
        XCTAssertTrue(router.wordsPath.isEmpty)
    }

    func testSelectSameTabPopsToRoot() {
        let router = AppRouter()
        router.push(1, on: .today)
        router.select(.today)
        XCTAssertTrue(router.todayPath.isEmpty)
    }
}

final class DesignSystemLogicTests: XCTestCase {

    func testHighlightSplitCaseAndDiacriticInsensitive() {
        let parts = HighlightedText.split("Could you LEND me your pen?", focus: "lend me")
        XCTAssertEqual(parts?.before, "Could you ")
        XCTAssertEqual(parts?.match, "LEND me")
        XCTAssertEqual(parts?.after, " your pen?")

        let pl = HighlightedText.split("Czy możesz pożyczyć mi długopis?", focus: "pozyczyc mi")
        XCTAssertEqual(pl?.match, "pożyczyć mi")
    }

    func testHighlightSafeWithoutMatch() {
        XCTAssertNil(HighlightedText.split("Hello", focus: "xyz"))
        XCTAssertNil(HighlightedText.split("Hello", focus: "   "))
        XCTAssertNil(HighlightedText.split("Hello", focus: nil))
        XCTAssertNil(HighlightedText.split("", focus: "a"))
        let plain = HighlightedText.attributed("Hello", focus: "xyz", highlight: nil)
        XCTAssertEqual(String(plain.characters), "Hello")
        let emphasized = HighlightedText.attributed("Say hello now", focus: "hello", highlight: nil)
        XCTAssertEqual(String(emphasized.characters), "Say hello now")
    }

    func testScoreTextAndClamping() {
        XCTAssertEqual(SkillBar.scoreText(nil), "—")
        XCTAssertEqual(SkillBar.scoreText(Double.nan), "—")
        XCTAssertEqual(SkillBar.scoreText(71.6), "72%")
        XCTAssertEqual(SkillBar.scoreText(140), "100%")
        XCTAssertEqual(ProgressMath.clamped(Double.infinity), 0)
        XCTAssertEqual(ProgressMath.clamped(-1), 0)
        XCTAssertEqual(ProgressMath.clamped(1.5), 1)
        XCTAssertEqual(ProgressMath.fraction(3, of: 0), 0)
        XCTAssertEqual(ProgressMath.fraction(5, of: 10), 0.5)
    }

    func testTonesAreSafeForAnyIndex() {
        XCTAssertEqual(Palette.safeIndex(-1, count: 6), 5)
        XCTAssertEqual(Palette.safeIndex(13, count: 6), 1)
        XCTAssertEqual(Palette.safeIndex(3, count: 0), 0)
        XCTAssertEqual(Palette.collectionTone(named: "Lotnisko"), Palette.collectionTone(named: "Lotnisko"))
        XCTAssertEqual(CEFRTone.normalized(" b1 "), "B1")
        XCTAssertNil(CEFRTone.normalized("D1"))
        XCTAssertEqual(ConfidenceLevel(clamping: 9), .fair)
        XCTAssertEqual(ConfidenceLevel(clamping: 3), .sure)
    }
}
