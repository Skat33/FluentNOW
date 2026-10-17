import Foundation
import UIKit
import FluentKit

/// Ćwiczenie ze zdjęciami nie ma sensu z czytnikiem ekranu — wtedy zadanie pokazujemy jako
/// „Wybierz znaczenie” (ta sama umiejętność: rozpoznawanie).
@MainActor
enum StudyPictureAccessibility {
    static var prefersTextExercise: Bool {
        UIAccessibility.isVoiceOverRunning
    }
}

/// One photo of the „Słowo i zdjęcie” exercise.
struct StudyPictureOption: Identifiable, Hashable {
    var meaningId: String
    var wordId: String
    /// English word the photo shows.
    var term: String
    /// Polish meaning (shown after the answer under every photo).
    var translation: String
    var image: WordImage
    var isCorrect: Bool

    var id: String { meaningId }
}

/// Builds the four photos of a task from the photo cache (G2). Distractors and their order are
/// deterministic per task key, so a resumed session shows the same set.
@MainActor
enum StudyPictureLoader {
    /// `nil` when the photos cannot be shown right now (target or distractors not cached) — the
    /// task is then shown as „Wybierz znaczenie”.
    static func options(for content: VocabExerciseContent, key: String, state: LearnerState, images: WordImageService) async -> [StudyPictureOption]? {
        let cached = await images.cachedMeaningIDs()
        guard cached.contains(content.meaning.id) else { return nil }
        let target = WordMeaning(word: content.word, meaning: content.meaning)
        let pool = PictureExercise.cachedItems(state: state, cached: cached)
        var generator = SeededGenerator(seed: key)
        let distractors = PictureExercise.distractors(for: target, pool: pool, using: &generator)
        guard distractors.count == PictureExercise.optionCount - 1 else { return nil }
        let order = PictureExercise.optionOrder(
            target: target.meaning.id,
            distractors: distractors.map { (item: WordMeaning) -> String in item.meaning.id },
            seed: key
        )
        guard let photos = await images.images(for: order) else { return nil }
        let items = [target] + distractors
        var result: [StudyPictureOption] = []
        for photo in photos {
            guard let item = items.first(where: { (candidate: WordMeaning) -> Bool in candidate.meaning.id == photo.meaningId }) else {
                return nil
            }
            result.append(StudyPictureOption(
                meaningId: item.meaning.id,
                wordId: item.word.id,
                term: item.word.en,
                translation: item.meaning.translation,
                image: photo,
                isCorrect: item.meaning.id == target.meaning.id
            ))
        }
        return result.count == PictureExercise.optionCount ? result : nil
    }
}
