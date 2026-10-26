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
        let correctKey = TextNormalizer.normalize(meaning.translation)
        // iOS improvement: a distractor must never be a second correct answer. Its translation and
        // accepted answers (with reviewed variants and aspect pairs) must not share any key with the
        // translation and accepted answers of the target — in both directions. Covers make
        // „zrobić, stworzyć” vs do „robić, wykonywać”, back down „wycofać się” vs back out, and the
        // near-synonyms of the core vocabulary (pity / shame „szkoda”, redundant / superfluous
        // „zbędny”, appease / placate „udobruchać”) also when they only share an accepted answer.
        let targetKeys = MeaningOptions.comparisonKeys(answerIndex.keys(term: word.en, translation: meaning.translation, saved: meaning.acceptedTranslations ?? []))
        var pool: [WordMeaning] = []
        var seenKeys = Set<String>()
        func consider(_ item: WordMeaning) {
            let key = TextNormalizer.normalize(item.meaning.translation)
            guard key != correctKey, !key.isEmpty, !seenKeys.contains(key) else { return }
            let candidateKeys = MeaningOptions.comparisonKeys(answerIndex.keys(
                term: item.word.en,
                translation: item.meaning.translation,
                saved: item.meaning.acceptedTranslations ?? []
            ))
            guard candidateKeys.isDisjoint(with: targetKeys) else { return }
            seenKeys.insert(key)
            pool.append(item)
        }
        for candidateWord in state.words {
            for candidateMeaning in candidateWord.meanings where candidateMeaning.id != meaning.id {
                consider(WordMeaning(word: candidateWord, meaning: candidateMeaning))
            }
        }
        for candidateWord in starterWords {
            for candidateMeaning in candidateWord.meanings {
                consider(WordMeaning(word: candidateWord, meaning: candidateMeaning))
            }
        }
        let targetPos = meaning.effectivePos(in: word)
        let targetLevel = CEFR.jsIndex(of: meaning.effectiveLevel(in: word))
        func sameCollection(_ item: WordMeaning) -> Int { item.word.collection == word.collection ? 1 : 0 }
        func samePos(_ item: WordMeaning) -> Int { item.meaning.effectivePos(in: item.word) == targetPos ? 1 : 0 }
        func levelDistance(_ item: WordMeaning) -> Int {
            abs(CEFR.jsIndex(of: item.meaning.effectiveLevel(in: item.word)) - targetLevel)
        }
        let sorted = pool.stableSorted { a, b in
            let collection = sameCollection(b) - sameCollection(a)
            if collection != 0 { return collection < 0 }
            let pos = samePos(b) - samePos(a)
            if pos != 0 { return pos < 0 }
            return levelDistance(a) < levelDistance(b)
        }
        var selected = [meaning.translation] + sorted.prefix(3).map { $0.meaning.translation }
        var generator = SeededGenerator(seed: "\(task.wordId)\(task.meaningId)\(task.type.rawValue)\(task.example)\(state.session?.index ?? -1)")
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
