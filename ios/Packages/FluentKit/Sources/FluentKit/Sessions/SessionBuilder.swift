import Foundation

/// Builds vocabulary sessions (learning.ts `makeSession`, `allowedTaskTypes`, `chooseType`).
public enum SessionBuilder {
    /// Session lengths offered in the UI (minutes).
    public static let durations = [5, 10, 15]

    /// Exercise types allowed by the progression of a meaning, or `nil` when every session type is
    /// allowed: the meaning exercise first (G3 — flashcards are no longer drawn into sessions; the
    /// first contact shows the four Polish options straight away), then recall, cloze and
    /// dictation as skills get practiced. The picture exercise is added by `chooseType` wherever
    /// the meaning exercise is allowed after the first contact (it needs a cached photo).
    public static func allowedTaskTypes(_ meaning: Meaning) -> [ExerciseType]? {
        let scores = meaning.scores
        if scores[.recognition] == nil { return [.meaning] }
        if (scores[.recognition]?.correct ?? 0) < 2 { return [.meaning] }
        if scores[.recall] == nil { return [.recall, .meaning] }
        if scores[.usage] == nil { return [.cloze, .recall] }
        if scores[.listening] == nil { return [.dictation, .meaning] }
        return nil
    }

    /// `true` for the very first contact with a meaning (never practiced for recognition): the
    /// meaning exercise then shows its options at once and choosing one is not counted as a hint.
    public static func isFirstContact(_ meaning: Meaning) -> Bool {
        meaning.scores[.recognition] == nil
    }

    /// Format of a failed task when it returns at the end of the session: the usual rotation
    /// (`ExerciseType.retryType`) while the meaning's progression allows it, otherwise another
    /// allowed type (a new word that failed its first meaning exercise gets the meaning exercise
    /// again with another sentence, not a dictation).
    public static func retryType(after type: ExerciseType, meaning: Meaning) -> ExerciseType {
        let rotated = type.retryType
        guard let allowed = allowedTaskTypes(meaning), !allowed.isEmpty else { return rotated }
        if allowed.contains(rotated) { return rotated }
        return allowed.first(where: { $0 != type }) ?? allowed[0]
    }

    /// `true` when the example at `index` contains the focus word (a cloze can be built).
    public static func canCloze(word: Word, meaning: Meaning, exampleIndex index: Int) -> Bool {
        guard let sentence = meaning.examples[safe: index] else { return false }
        let focus = nonEmpty(meaning.exampleFocusEn?[safe: index]) ?? word.en
        return Cloze.text(sentence, focus: focus) != nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    /// Picks an exercise type for a meaning (`chooseType`). Never a flashcard; the picture
    /// exercise only when `pictureReady` (a photo of this meaning and enough distractors are
    /// cached) and the meaning is past its first contact.
    static func chooseType<G: RandomNumberGenerator>(word: Word, meaning: Meaning, exampleIndex: Int, pictureReady: Bool = false, using rng: inout G) -> ExerciseType {
        var type: ExerciseType
        if var progression = allowedTaskTypes(meaning), !progression.isEmpty {
            if pictureReady && !isFirstContact(meaning) && progression.contains(.meaning) {
                progression.append(.picture)
            }
            type = progression[rng.nextIndex(below: progression.count)]
        } else {
            // Earliest-due skill first; ties broken randomly (valid ordering via pre-drawn keys).
            let types = ExerciseType.sessionTypes.filter { (candidate: ExerciseType) -> Bool in
                candidate != .picture || pictureReady
            }
            let candidates = types.map { candidate -> (type: ExerciseType, due: Double, tie: Double) in
                (candidate, meaning.scores[candidate.skill]?.due ?? 0, rng.nextUnit())
            }
            let sorted = candidates.sorted { a, b in
                if a.due != b.due { return a.due < b.due }
                return a.tie < b.tie
            }
            type = sorted.first?.type ?? .meaning
        }
        if type == .cloze && !canCloze(word: word, meaning: meaning, exampleIndex: exampleIndex) {
            type = .recall
        }
        return type
    }

    /// `makeSession`: reviews first (earliest due; in mistakes mode most errors first), then new
    /// meanings, until the time budget is used. Tasks are interleaved by type.
    ///
    /// - Parameters:
    ///   - minutes: planned length (5 / 10 / 15).
    ///   - mode: `.mixed`, `.mistakes` or `.pairs` (other modes behave like `.mixed`).
    ///   - collection: restricts the session to one collection.
    ///   - pictureMeaningIDs: meanings whose photo exercise can be shown right now (photo and
    ///     three distractor photos already cached — see `PictureExercise.readyMeaningIDs`).
    ///     Empty (offline, nothing cached) = no picture tasks.
    public static func makeSession<G: RandomNumberGenerator>(
        state: LearnerState,
        minutes: Int,
        mode: StudyMode = .mixed,
        collection: String? = nil,
        pictureMeaningIDs: Set<String> = [],
        using rng: inout G
    ) -> VocabSession {
        if mode == .pictures {
            return makePictureSession(state: state, minutes: minutes, collection: collection, pictureMeaningIDs: pictureMeaningIDs, using: &rng)
        }
        let safeMinutes = max(1, minutes)
        var choices: [WordMeaning] = []
        for word in state.words where !word.archived && (collection == nil || word.collection == collection) {
            for meaning in word.meanings where ExamplePool.availableCount(meaning) > 0 {
                choices.append(WordMeaning(word: word, meaning: meaning))
            }
        }
        if mode == .mistakes {
            choices = choices.filter { item in
                item.word.hard || item.meaning.scores.values.contains { $0.wrong > 0 || $0.slow > 0 }
            }
        }
        if mode == .pairs {
            choices = ConfusableDetector.itemsWithPartners(choices)
        }
        // Starred words (`StudyPriority`): tie-break only — reviews keep their order by due date /
        // errors; new meanings (all due 0) get starred ones first.
        if mode == .mistakes {
            let keyed = choices.map { item in
                (item: item, errors: item.meaning.scores.values.reduce(0) { $0 + $1.wrong + $1.slow })
            }
            choices = keyed.stableSorted { (a: (item: WordMeaning, errors: Int), b: (item: WordMeaning, errors: Int)) -> Bool in
                if a.errors != b.errors { return a.errors > b.errors }
                return StudyPriority.starredFirst(a.item.word, b.item.word)
            }.map { $0.item }
        } else {
            let keyed = choices.map { (item: $0, due: Mastery.due($0.meaning)) }
            choices = keyed.stableSorted { (a: (item: WordMeaning, due: Timestamp), b: (item: WordMeaning, due: Timestamp)) -> Bool in
                if a.due != b.due { return a.due < b.due }
                return StudyPriority.starredFirst(a.item.word, b.item.word)
            }.map { $0.item }
        }
        let ordered: [WordMeaning]
        if mode == .pairs {
            ordered = choices
        } else {
            ordered = choices.filter { !$0.meaning.scores.isEmpty } + choices.filter { $0.meaning.scores.isEmpty }
        }

        var seenCounts: [String: Int] = [:]
        for review in state.reviews {
            seenCounts[review.meaningId, default: 0] += 1
        }

        var tasks: [VocabTask] = []
        var budget = safeMinutes * 60
        for item in ordered {
            let seen = seenCounts[item.meaning.id] ?? 0
            let example = ExamplePool.nextUnusedExample(item.meaning, fallback: seen)
            var type: ExerciseType = mode == .pairs
                ? .cloze
                : chooseType(
                    word: item.word,
                    meaning: item.meaning,
                    exampleIndex: example,
                    pictureReady: pictureMeaningIDs.contains(item.meaning.id),
                    using: &rng
                )
            if type == .cloze && !canCloze(word: item.word, meaning: item.meaning, exampleIndex: example) {
                if mode == .pairs { continue }
                type = .recall
            }
            if !tasks.isEmpty && budget - type.estimatedSeconds < 0 { continue }
            tasks.append(VocabTask(wordId: item.word.id, meaningId: item.meaning.id, type: type, example: example))
            budget -= type.estimatedSeconds
        }
        return VocabSession(
            tasks: TaskInterleaver.interleave(tasks),
            index: 0,
            correct: 0,
            minutes: safeMinutes,
            mode: (mode.isVocabulary ? mode : .mixed).rawValue
        )
    }

    /// „Słowa i obrazki” (FEEDBACK-3 H2): only „Słowo i zdjęcie” tasks, for meanings in
    /// `pictureMeaningIDs` (photo and three distractor photos already cached). The mode is chosen
    /// explicitly, so new meanings may take part too. Practiced meanings first (earliest due), then
    /// new ones; at most `minutes × 60 / 20 s` tasks, shown in random order. Empty when no photo is
    /// ready (the screen then explains that photos are still downloading).
    public static func makePictureSession<G: RandomNumberGenerator>(
        state: LearnerState,
        minutes: Int,
        collection: String? = nil,
        pictureMeaningIDs: Set<String>,
        using rng: inout G
    ) -> VocabSession {
        let safeMinutes = max(1, minutes)
        var practiced: [(item: WordMeaning, due: Timestamp)] = []
        var fresh: [WordMeaning] = []
        if !pictureMeaningIDs.isEmpty {
            for word in state.words where !word.archived && (collection == nil || word.collection == collection) {
                for meaning in word.meanings where pictureMeaningIDs.contains(meaning.id) {
                    let item = WordMeaning(word: word, meaning: meaning)
                    if meaning.scores.isEmpty {
                        fresh.append(item)
                    } else {
                        practiced.append((item: item, due: Mastery.due(meaning)))
                    }
                }
            }
        }
        let ordered = practiced.stableSorted { $0.due < $1.due }.map { $0.item } + fresh
        let limit = max(1, safeMinutes * 60 / ExerciseType.picture.estimatedSeconds)
        var seenCounts: [String: Int] = [:]
        for review in state.reviews {
            seenCounts[review.meaningId, default: 0] += 1
        }
        var tasks: [VocabTask] = ordered.prefix(limit).map { (item: WordMeaning) -> VocabTask in
            let example = ExamplePool.nextUnusedExample(item.meaning, fallback: seenCounts[item.meaning.id] ?? 0)
            return VocabTask(wordId: item.word.id, meaningId: item.meaning.id, type: .picture, example: example)
        }
        var index = tasks.count - 1
        while index > 0 {
            let other = rng.nextIndex(below: index + 1)
            tasks.swapAt(index, other)
            index -= 1
        }
        return VocabSession(
            tasks: tasks,
            index: 0,
            correct: 0,
            minutes: safeMinutes,
            mode: StudyMode.pictures.rawValue
        )
    }

    /// `makeSession` with the system random number generator.
    public static func makeSession(state: LearnerState, minutes: Int, mode: StudyMode = .mixed, collection: String? = nil, pictureMeaningIDs: Set<String> = []) -> VocabSession {
        var generator = SystemRandomNumberGenerator()
        return makeSession(state: state, minutes: minutes, mode: mode, collection: collection, pictureMeaningIDs: pictureMeaningIDs, using: &generator)
    }
}
