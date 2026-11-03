import Foundation
import FluentKit

/// „Twoje typowe błędy” (FEEDBACK-10 P1): wpisy dziennika błędów z zakończonego zadania
/// słownikowego — pierwsza błędna odpowiedź (także gdy druga próba się udała), sklasyfikowana
/// przez FluentKit (`MistakeClassifier`). Pusto, gdy pierwsza odpowiedź była poprawna, w teście
/// poziomu i dla fiszek (tam nie ma podanej odpowiedzi).
@MainActor
enum StudyMistakeCapture {
    /// - Parameter idBase: identyfikator recenzji zadania (wpis dostaje `<idBase>-m<n>`).
    static func entries(from model: VocabExerciseModel, now: Timestamp, idBase: String) -> [MistakeEntry] {
        guard !model.isAssessment else { return [] }
        let content = model.content
        let context = content.example
        func make(_ analysis: MistakeAnalysis, expected: String, given: String, number: Int = 0, wordID: String? = nil, meaningID: String? = nil) -> MistakeEntry {
            MistakeLog.entry(
                id: "\(idBase)-m\(number)",
                at: now,
                exercise: model.type,
                analysis: analysis,
                expected: expected,
                given: given,
                wordId: wordID ?? content.word.id,
                meaningId: meaningID ?? content.meaning.id,
                example: content.exampleIndex,
                context: context
            )
        }
        switch model.type {
        case .flashcard:
            return []
        case .scramble:
            guard let tiles = model.firstWrongTiles, let board = content.scramble,
                  let analysis = MistakeClassifier.classify(expectedTokens: board.answer, givenTokens: tiles) else { return [] }
            return [make(analysis, expected: board.answer.joined(separator: " "), given: tiles.joined(separator: " "))]
        case .recall, .cloze, .dictation:
            guard let given = model.firstWrongAnswer else { return [] }
            let expected = MistakeClassifier.closest(to: given, among: content.accepted) ?? content.gradingWord.en
            let pos = content.meaning.effectivePos(in: content.word).lowercased()
            let isVerb = pos.contains("czasownik") || pos.contains("verb")
            guard let analysis = MistakeClassifier.classify(expected: expected, given: given, focusIsVerb: isVerb) else { return [] }
            return [make(analysis, expected: expected, given: given)]
        case .meaning:
            guard let given = model.firstWrongAnswer else { return [] }
            let expected = content.meaning.translation
            if model.firstWrongWasChoice {
                return [make(MistakeAnalysis(kind: .meaning), expected: expected, given: given)]
            }
            let closest = MistakeClassifier.closest(to: given, among: content.accepted) ?? expected
            guard let analysis = MistakeClassifier.classifyPolish(expected: closest, given: given) else { return [] }
            return [make(analysis, expected: closest, given: given)]
        case .picture:
            guard let given = model.firstWrongAnswer else { return [] }
            return [make(MistakeAnalysis(kind: .meaning), expected: content.word.en, given: given)]
        case .listeningChoice:
            guard let given = model.firstWrongAnswer else { return [] }
            let expected = ListeningChoice.translation(meaning: content.meaning, exampleIndex: content.exampleIndex) ?? content.meaning.translation
            return [make(MistakeAnalysis(kind: .meaning), expected: expected, given: given)]
        case .matchPairs:
            return pairEntries(model: model, make: make)
        }
    }

    /// „Dopasuj pary”: jeden wpis na znaczenie z błędną parą (oczekiwane i wybrane tłumaczenie).
    private static func pairEntries(
        model: VocabExerciseModel,
        make: (MistakeAnalysis, String, String, Int, String?, String?) -> MistakeEntry
    ) -> [MistakeEntry] {
        guard let board = model.content.pairs else { return [] }
        var result: [MistakeEntry] = []
        for (number, item) in board.english.enumerated() {
            guard let chosenID = model.wrongPairs[item.meaningId],
                  let chosen = board.polish.first(where: { (other: MatchPairItem) -> Bool in other.meaningId == chosenID }) else { continue }
            result.append(make(MistakeAnalysis(kind: .meaning), item.translation, chosen.translation, number, item.wordId, item.meaningId))
        }
        return result
    }
}
