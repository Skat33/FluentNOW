import Foundation

/// Answer options for „Wybierz znaczenie” (learning.ts `meaningOptions`).
public enum MeaningOptions {
    /// The correct translation plus up to three distractors, shuffled deterministically per task
    /// (the same task always shows the same order, also after re-rendering).
    ///
    /// Distractors come from the learner's other meanings and from `starterWords`, never repeat a
    /// translation, and prefer the same collection, the same part of speech and a close CEFR level.
    public static func options(
        state: LearnerState,
        word: Word,
        meaning: Meaning,
        task: VocabTask,
        starterWords: [Word] = [],
        answerIndex: PolishAnswerIndex = PolishAnswerIndex()
    ) -> [String] {
        options(
            index: MeaningOptionsIndex(state: state, starterWords: starterWords, answerIndex: answerIndex),
            word: word,
            meaning: meaning,
            task: task,
            sessionIndex: state.session?.index ?? -1,
            answerIndex: answerIndex
        )
    }

    /// The same as `options(state:…)` on a prebuilt `MeaningOptionsIndex` (FEEDBACK-10 P3): the
    /// answer keys of every candidate are computed once per state revision (off the main thread),
    /// so one task only compares sets. `sessionIndex` — `state.session?.index ?? -1` of the state
    /// the task belongs to (part of the shuffle seed).
    public static func options(
        index source: MeaningOptionsIndex,
        word: Word,
        meaning: Meaning,
        task: VocabTask,
        sessionIndex: Int,
        answerIndex: PolishAnswerIndex = PolishAnswerIndex()
    ) -> [String] {
        let correctKey = TextNormalizer.normalize(meaning.translation)
        // iOS improvement: a distractor must never be a second correct answer. Its translation and
        // accepted answers (with reviewed variants and aspect pairs) must not share any key with the
        // translation and accepted answers of the target — in both directions. Covers make
        // „zrobić, stworzyć” vs do „robić, wykonywać”, back down „wycofać się” vs back out, and the
        // near-synonyms of the core vocabulary (pity / shame „szkoda”, redundant / superfluous
        // „zbędny”, appease / placate „udobruchać”) also when they only share an accepted answer.
        let targetKeys = MeaningOptions.comparisonKeys(answerIndex.keys(term: word.en, translation: meaning.translation, saved: meaning.acceptedTranslations ?? []))
        var pool: [MeaningOptionsIndex.Candidate] = []
        var seenKeys = Set<String>()
        for candidate in source.candidates {
            if !candidate.isStarter && candidate.meaningID == meaning.id { continue }
            guard candidate.key != correctKey, !candidate.key.isEmpty, !seenKeys.contains(candidate.key) else { continue }
            guard candidate.answerKeys.isDisjoint(with: targetKeys) else { continue }
            seenKeys.insert(candidate.key)
            pool.append(candidate)
        }
        let targetPos = meaning.effectivePos(in: word)
        let targetLevel = CEFR.jsIndex(of: meaning.effectiveLevel(in: word))
        let targetCollection = word.collection
        func sameCollection(_ item: MeaningOptionsIndex.Candidate) -> Int { item.collection == targetCollection ? 1 : 0 }
        func samePos(_ item: MeaningOptionsIndex.Candidate) -> Int { item.pos == targetPos ? 1 : 0 }
        func levelDistance(_ item: MeaningOptionsIndex.Candidate) -> Int { abs(item.level - targetLevel) }
        let sorted = pool.stableSorted { (a: MeaningOptionsIndex.Candidate, b: MeaningOptionsIndex.Candidate) -> Bool in
            let collection = sameCollection(b) - sameCollection(a)
            if collection != 0 { return collection < 0 }
            let pos = samePos(b) - samePos(a)
            if pos != 0 { return pos < 0 }
            return levelDistance(a) < levelDistance(b)
        }
        var selected = [meaning.translation] + sorted.prefix(3).map { (item: MeaningOptionsIndex.Candidate) -> String in item.translation }
        var generator = SeededGenerator(seed: "\(task.wordId)\(task.meaningId)\(task.type.rawValue)\(task.example)\(sessionIndex)")
        var index = selected.count - 1
        while index > 0 {
            let target = generator.nextIndex(below: index + 1)
            selected.swapAt(index, target)
            index -= 1
        }
        return selected
    }

    /// Answer keys plus their loose forms (`TextNormalizer.looseKeys`: without parenthetical notes
    /// and inner punctuation), so „szkoda (że)” and „szkoda” count as the same answer.
    public static func comparisonKeys(_ keys: Set<String>) -> Set<String> {
        var result = keys
        for key in keys {
            // Letters, spaces, hyphens and apostrophes only: the loose form is the key itself.
            let plain = key.allSatisfy { (character: Character) -> Bool in
                character.isLetter || character.isNumber || character == " " || character == "-" || character == "'"
            }
            if plain { continue }
            for loose in TextNormalizer.looseKeys(key, using: TextNormalizer.answerKey) {
                result.insert(loose)
            }
        }
        result.remove("")
        return result
    }

    /// `true` when a distractor sense could be a correct answer for the target sense: any shared
    /// key of translations and accepted answers, in either direction (see `options`).
    public static func overlaps(
        _ candidate: WordMeaning,
        target: WordMeaning,
        answerIndex: PolishAnswerIndex = PolishAnswerIndex()
    ) -> Bool {
        let targetKeys = comparisonKeys(answerIndex.keys(term: target.word.en, translation: target.meaning.translation, saved: target.meaning.acceptedTranslations ?? []))
        let candidateKeys = comparisonKeys(answerIndex.keys(term: candidate.word.en, translation: candidate.meaning.translation, saved: candidate.meaning.acceptedTranslations ?? []))
        return !candidateKeys.isDisjoint(with: targetKeys)
    }
}

/// Precomputed distractor candidates of „Wybierz znaczenie” (FEEDBACK-10 P3): the learner's
/// meanings, then the starter words, each with its normalised translation, answer keys
/// (`PolishAnswerIndex` + loose forms), collection, part of speech and level. Building it walks
/// every meaning once — do it off the main thread (`LearningStore.compute`) once per state
/// revision; `MeaningOptions.options(index:…)` then only compares sets.
public struct MeaningOptionsIndex: Sendable {
    public struct Candidate: Sendable, Hashable {
        public var meaningID: String
        public var translation: String
        /// `TextNormalizer.normalize(translation)`.
        public var key: String
        /// `MeaningOptions.comparisonKeys` of the accepted answers.
        public var answerKeys: Set<String>
        public var collection: String
        public var pos: String
        /// `CEFR.jsIndex` of the effective level.
        public var level: Int
        /// From the starter words (never excluded by meaning id).
        public var isStarter: Bool
    }

    public let candidates: [Candidate]

    public var count: Int { candidates.count }

    public init(state: LearnerState, starterWords: [Word] = [], answerIndex: PolishAnswerIndex = PolishAnswerIndex()) {
        var items: [Candidate] = []
        func add(_ word: Word, _ meaning: Meaning, starter: Bool) {
            items.append(Candidate(
                meaningID: meaning.id,
                translation: meaning.translation,
                key: TextNormalizer.normalize(meaning.translation),
                answerKeys: MeaningOptions.comparisonKeys(answerIndex.keys(
                    term: word.en,
                    translation: meaning.translation,
                    saved: meaning.acceptedTranslations ?? []
                )),
                collection: word.collection,
                pos: meaning.effectivePos(in: word),
                level: CEFR.jsIndex(of: meaning.effectiveLevel(in: word)),
                isStarter: starter
            ))
        }
        for word in state.words {
            for meaning in word.meanings {
                add(word, meaning, starter: false)
            }
        }
        for word in starterWords {
            for meaning in word.meanings {
                add(word, meaning, starter: true)
            }
        }
        candidates = items
    }
}
