import Foundation

/// Additive migration of decoded states (learning.ts `migrateState`) plus iOS repairs.
/// Run after every decode (import, persistence load, sync). Idempotent.
public enum StateMigration {
    /// `migrateState`: normalises translations, enrichment and scores, removes unfinished session
    /// tasks whose meaning / example no longer exists, fills defaults of newer versions and
    /// recovers grammar exposure of visible legacy items.
    public static func migrate(_ input: LearnerState) -> LearnerState {
        var state = input
        // iOS repair: duplicate word ids (e.g. two CloudKit records) are merged, never dropped.
        if Set(state.words.map { $0.id }).count != state.words.count {
            state.words = StateSync.mergeDuplicateWords(state.words)
        }
        for wordIndex in state.words.indices {
            for meaningIndex in state.words[wordIndex].meanings.indices {
                var meaning = state.words[wordIndex].meanings[meaningIndex]
                meaning.translation = TextNormalizer.withoutDialectLabel(meaning.translation)
                if var enrichment = meaning.enrichment {
                    if let round = enrichment.round { enrichment.round = max(0, min(5, round)) }
                    enrichment.groups = enrichment.groups.uniqued()
                    enrichment.retryAt = max(0, enrichment.retryAt)
                    meaning.enrichment = enrichment
                }
                meaning.topic = trimmedOrNil(meaning.topic)
                meaning.scene = trimmedOrNil(meaning.scene)
                var scores = meaning.scores
                for (skill, score) in meaning.scores.entries {
                    var fixed = score
                    fixed.interval = min(90, finiteNonNegative(score.interval))
                    fixed.value = Mastery.fromInterval(fixed.interval)
                    scores[skill] = fixed
                }
                meaning.scores = scores
                if let used = meaning.usedExamples {
                    meaning.usedExamples = used.filter { $0 >= 0 }.uniqued()
                }
                state.words[wordIndex].meanings[meaningIndex] = meaning
            }
        }

        if var session = state.session {
            let index = min(max(0, session.index), session.tasks.count)
            let done = Array(session.tasks.prefix(index))
            let pending = session.tasks.dropFirst(index).filter { task in
                guard let word = state.words.first(where: { $0.id == task.wordId && !$0.archived }),
                      let meaning = word.meaning(id: task.meaningId) else { return false }
                return task.example < ExamplePool.availableCount(meaning)
            }
            session.tasks = done + pending
            session.index = index
            session.correct = min(session.correct, index)
            // A completed prefix that references deleted meanings is only history (its answers are
            // already scored). Keep the session while something is left to resume — deleting a word
            // already answered must not throw away the rest of a paused session (code-qa).
            // A finished session whose prefix is broken is dropped, as before.
            let prefixValid = done.allSatisfy { task in state.word(id: task.wordId)?.meaning(id: task.meaningId) != nil }
            state.session = (prefixValid || !pending.isEmpty) ? session : nil
        }

        if var practice = state.practice {
            let count = practice.set.items.count
            if count == 0 {
                state.practice = nil
            } else {
                var written = practice.writtenAnswers ?? []
                while written.count < count { written.append("") }
                practice.writtenAnswers = Array(written.prefix(count))
                var answers = practice.answers
                while answers.count < count { answers.append(-1) }
                practice.answers = Array(answers.prefix(count))
                practice.index = min(max(0, practice.index), count - 1)
                state.practice = practice
            }
        }

        if var production = state.production {
            let count = production.set.items.count
            if count == 0 {
                state.production = nil
            } else {
                while production.answers.count < count { production.answers.append("") }
                while production.results.count < count { production.results.append(nil) }
                production.answers = Array(production.answers.prefix(count))
                production.results = Array(production.results.prefix(count))
                production.index = min(max(0, production.index), count - 1)
                state.production = production
            }
        }

        if var combined = state.combined {
            combined.index = min(max(0, combined.index), combined.tasks.count)
            state.combined = combined.tasks.isEmpty ? nil : combined
        }

        if let reading = state.reading, reading.reading.questions.isEmpty {
            state.reading = nil
        }

        // Recover currently visible legacy items without inventing past exposures.
        if let production = state.production {
            for item in production.set.items.prefix(production.index + 1) {
                if let bankId = item.bankId, !bankId.isEmpty, state.grammarSeen[bankId] == nil {
                    state.grammarSeen[bankId] = 1
                }
            }
        }
        if let practice = state.practice {
            for item in practice.set.items.prefix(practice.index + 1) where item.category == .grammar {
                if let bankId = item.bankId, !bankId.isEmpty, state.grammarSeen[bankId] == nil {
                    state.grammarSeen[bankId] = 1
                }
            }
        }
        state.collections = state.collections.filter { !TextScanning.trim($0).isEmpty }.uniqued()
        return state
    }

    private static func trimmedOrNil(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = TextScanning.trim(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}
