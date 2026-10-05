import Foundation
import XCTest
import SwiftData
import FluentKit
@testable import FluentNOW

/// Wspólne narzędzia testów warstwy platform-services.
enum ServicesTestSupport {
    /// `ios/` wyliczone z położenia tego pliku (`ios/FluentNOWTests/Services/…`).
    static var iosRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Katalog treści w repozytorium (`ios/FluentNOW/Resources/Content`).
    static var contentRoot: URL {
        iosRoot.appendingPathComponent("FluentNOW/Resources/Content", isDirectory: true)
    }

    /// Eksport strony w wersji 31 (fixture FluentKit).
    static func webFixtureData() throws -> Data {
        let url = iosRoot.appendingPathComponent("Packages/FluentKit/Tests/FluentKitTests/Fixtures/state-v31.json")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("Brak pliku fixture: \(url.path)")
        }
        return try Data(contentsOf: url)
    }

    static func makeRepository() throws -> (LearningRepository, ModelContainer) {
        let container = try PersistenceController.makeInMemoryContainer()
        return (LearningRepository(modelContainer: container), container)
    }

    @MainActor
    static func makeStore(
        initial: LearnerState? = nil,
        persistence: InMemoryPersistence = InMemoryPersistence()
    ) -> LearningStore {
        LearningStore(
            persistence: persistence,
            syncMonitor: SyncMonitor(mode: .fixed(.localOnly("test"))),
            initialState: initial,
            fixedNow: PreviewData.now
        )
    }

    /// Proste słowo z jednym znaczeniem.
    static func word(_ id: String, en: String, pl: String, created: Timestamp = PreviewData.now, archived: Bool = false) -> Word {
        Word(
            id: id,
            en: en,
            collection: "Test",
            archived: archived,
            created: created,
            updatedAt: created,
            meanings: [Meaning(id: "\(id).m1", translation: pl, examples: ["I need this \(en) now."])]
        )
    }
}
