import Foundation
import FluentKit

/// Treść szybkiego testu poziomu: `dictionary-index.json` i `grammar/{A2,B1,B2}.json` z pakietu
/// aplikacji, dekodowane poza głównym wątkiem (jednorazowo, tylko gdy użytkownik wybierze test).
enum OnboardingContentLoader {
    static func placementQuestions(seed: UInt64, bundle: Bundle = .main) async -> [PlacementQuestion] {
        guard let root = bundle.url(forResource: "Content", withExtension: nil) else { return [] }
        let task = Task.detached(priority: .userInitiated) { () -> [PlacementQuestion] in
            OnboardingContentLoader.buildQuestions(root: root, seed: seed)
        }
        return await task.value
    }

    private static func buildQuestions(root: URL, seed: UInt64) -> [PlacementQuestion] {
        let dictionaryURL = root.appendingPathComponent("dictionary-index.json")
        guard let data = try? Data(contentsOf: dictionaryURL, options: [.mappedIfSafe]),
              let index = try? ContentDecoder.dictionaryIndex(from: data) else { return [] }
        var grammar: [String: [ProductionItem]] = [:]
        for level in PlacementTest.grammarLevels {
            let url = root.appendingPathComponent("grammar/\(level).json")
            if let levelData = try? Data(contentsOf: url, options: [.mappedIfSafe]),
               let file = try? ContentDecoder.grammarLevel(from: levelData) {
                grammar[level] = file.items
            }
        }
        return PlacementTest.makeQuestions(dictionary: index.entries, grammar: grammar, seed: seed)
    }
}
