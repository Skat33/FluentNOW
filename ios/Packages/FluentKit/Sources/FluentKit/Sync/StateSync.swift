import Foundation

/// Merging of learner states from two devices / imports and history compaction (state-sync.ts).
public enum StateSync {
    /// Reviews older than this many days are folded into daily summaries.
    public static let reviewRetentionDays: Double = 90

    /// `yyyy-MM-dd` of a timestamp in UTC (web `toISOString().slice(0, 10)`).
    public static func utcDay(_ timestamp: Timestamp) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date(timestamp: timestamp))
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return pad(year, 4) + "-" + pad(month, 2) + "-" + pad(day, 2)
    }

    static func pad(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return text.count >= width ? text : String(repeating: "0", count: width - text.count) + text
    }

    /// `compactReviews`: keeps the last 90 days of reviews; older real reviews become per-day
    /// summaries (demo reviews are dropped).
    public static func compactReviews(_ state: LearnerState, now: Timestamp) -> LearnerState {
        var next = state
        let cutoff = now - reviewRetentionDays * TimeConstants.dayMs
        var summaries: [String: ReviewSummary] = [:]
        for summary in state.reviewSummaries { summaries[summary.day] = summary }
        var recent: [Review] = []
        recent.reserveCapacity(state.reviews.count)
        for review in state.reviews {
            if review.at >= cutoff {
                recent.append(review)
                continue
            }
            if review.demo { continue }
            let day = utcDay(review.at)
            var summary = summaries[day] ?? ReviewSummary(day: day, count: 0, correct: 0)
            summary.count += 1
            summary.correct += (review.correct && !review.hint) ? 1 : 0
            summaries[day] = summary
        }
        next.reviews = recent
        next.reviewSummaries = summaries.values.sorted { $0.day < $1.day }
        return next
    }

    /// Merges two copies of the same word (`local` wins ties). The newer edit (`updatedAt`, or
    /// `created`) wins the word fields. For meanings with the same id and identity (term and
    /// translation unchanged): used examples are united, a larger example bank saved on the other
    /// device is kept, and — iOS improvement — skill scores are merged per skill taking the score
    /// answered most recently, so progress made on either device is never lost.
    public static func mergeWord(_ local: Word, _ remote: Word) -> Word {
        let localTime = (local.updatedAt ?? 0) != 0 ? (local.updatedAt ?? 0) : local.created
        let remoteTime = (remote.updatedAt ?? 0) != 0 ? (remote.updatedAt ?? 0) : remote.created
        let winner = localTime >= remoteTime ? local : remote
        let other = localTime >= remoteTime ? remote : local
        var merged = winner
        merged.meanings = winner.meanings.map { (meaning: Meaning) -> Meaning in
            guard let previous = other.meanings.first(where: { $0.id == meaning.id }),
                  winner.en == other.en, meaning.translation == previous.translation else { return meaning }
            var result = meaning
            result.scores = mergeScores(meaning.scores, previous.scores)
            guard meaning.topic == previous.topic, meaning.scene == previous.scene else { return result }
            let larger = meaning.examples.count >= previous.examples.count ? meaning : previous
            let smaller = meaning.examples.count >= previous.examples.count ? previous : meaning
            for (index, text) in smaller.examples.enumerated() where larger.examples[safe: index] != text {
                return result
            }
            let used = ((meaning.usedExamples ?? []) + (previous.usedExamples ?? []))
                .uniqued()
                .filter { $0 >= 0 && $0 < larger.examples.count }
            if meaning.enrichment != nil && previous.enrichment != nil {
                result.examples = larger.examples
                result.exampleTranslations = larger.exampleTranslations
                result.exampleFocusEn = larger.exampleFocusEn
                result.exampleFocusPl = larger.exampleFocusPl
                result.enrichment = larger.enrichment
            }
            if !used.isEmpty { result.usedExamples = used }
            return result
        }
        return merged
    }

    /// Per skill: the score with the later `last` answer, carrying its whole FSRS state
    /// (stability, difficulty, reps, lapses) — states of two devices are never mixed field by field.
    /// Ties keep `primary`, unless only `secondary` already has an FSRS state (the same answer
    /// saved by a newer app version).
    static func mergeScores(_ primary: SkillScores, _ secondary: SkillScores) -> SkillScores {
        var result = primary
        for (skill, score) in secondary.entries {
            if let mine = result[skill] {
                if score.last > mine.last
                    || (score.last == mine.last && mine.memoryState == nil && score.memoryState != nil) {
                    result[skill] = score
                }
            } else {
                result[skill] = score
            }
        }
        return result
    }

    /// Collapses words sharing an id (e.g. duplicate CloudKit records) with `mergeWord`;
    /// the first occurrence keeps its position.
    public static func mergeDuplicateWords(_ words: [Word]) -> [Word] {
        var order: [String] = []
        var byID: [String: Word] = [:]
        for word in words {
            if let existing = byID[word.id] {
                byID[word.id] = mergeWord(existing, word)
            } else {
                order.append(word.id)
                byID[word.id] = word
            }
        }
        return order.compactMap { byID[$0] }
    }

    /// `mergeStates`: union of words (per-word merge), reviews and histories (by id, sorted by
    /// time), collections, summaries (max per day) and grammar exposure (max). Settings and the
    /// paused vocabulary session / reading come from `local`; practice and production from
    /// `local` when present, else `remote`; the combined session is chosen by progress.
    public static func mergeStates(local: LearnerState, remote: LearnerState) -> LearnerState {
        var merged = local

        // Combined session: same id → more progress wins (index, then answers, then time).
        let a = local.combined
        let b = remote.combined
        if let a, let b, a.id == b.id {
            if a.index != b.index {
                merged.combined = a.index > b.index ? a : b
            } else if a.answeredCount != b.answeredCount {
                merged.combined = a.answeredCount > b.answeredCount ? a : b
            } else {
                merged.combined = a.updatedAt >= b.updatedAt ? a : b
            }
        } else if (a?.updatedAt ?? 0) >= (b?.updatedAt ?? 0) {
            merged.combined = a ?? b
        } else {
            merged.combined = b
        }

        // Words: remote order first, local-only words appended.
        var order: [String] = []
        var words: [String: Word] = [:]
        for word in remote.words {
            if let existing = words[word.id] {
                words[word.id] = mergeWord(existing, word)
            } else {
                order.append(word.id)
                words[word.id] = word
            }
        }
        for word in local.words {
            if let saved = words[word.id] {
                words[word.id] = mergeWord(word, saved)
            } else {
                order.append(word.id)
                words[word.id] = word
            }
        }
        merged.words = order.compactMap { words[$0] }

        merged.reviews = unionByID(remote.reviews, local.reviews, id: { $0.id }).stableSorted { $0.at < $1.at }
        merged.readingHistory = unionByID(remote.readingHistory, local.readingHistory, id: { $0.id }).stableSorted { $0.at < $1.at }
        merged.practiceHistory = unionByID(remote.practiceHistory, local.practiceHistory, id: { $0.id }).stableSorted { $0.at < $1.at }
        merged.productionHistory = unionByID(remote.productionHistory, local.productionHistory, id: { $0.id }).stableSorted { $0.at < $1.at }
        // Level test (K4): histories united by id; the test in progress chosen by progress.
        merged.assessmentHistory = unionByID(remote.assessmentHistory, local.assessmentHistory, id: { $0.id }).stableSorted { $0.at < $1.at }
        merged.assessment = mergeAssessment(local: local.assessment, remote: remote.assessment, history: merged.assessmentHistory)

        var summaries: [String: ReviewSummary] = [:]
        for item in remote.reviewSummaries { summaries[item.day] = item }
        for item in local.reviewSummaries {
            let saved = summaries[item.day]
            summaries[item.day] = ReviewSummary(
                day: item.day,
                count: max(item.count, saved?.count ?? 0),
                correct: max(item.correct, saved?.correct ?? 0)
            )
        }
        merged.reviewSummaries = summaries.values.sorted { $0.day < $1.day }

        var seen = remote.grammarSeen
        for (key, value) in local.grammarSeen {
            seen[key] = max(seen[key] ?? 0, value)
        }
        merged.grammarSeen = seen
        merged.collections = (remote.collections + local.collections).uniqued()
        merged.practice = local.practice ?? remote.practice
        merged.production = local.production ?? remote.production
        // Study profile (G4): the more recently edited copy wins (a profile set up on another
        // device is never lost because this device has none).
        merged.settings.profile = LearnerProfile.newer(local.settings.profile, remote.settings.profile)
        // Avatar and nickname (J3): merged on their own `updatedAt`, independently of the profile.
        merged.settings.avatar = LearnerAvatar.newer(local.settings.avatar, remote.settings.avatar)
        return merged
    }

    /// The level test of two copies: the same test → a finished copy wins, then more answers, then
    /// the newer edit; different tests → the newer one. An unfinished copy of a test that is already
    /// in the history (finished on the other device) is dropped.
    static func mergeAssessment(local: AssessmentSession?, remote: AssessmentSession?, history: [AssessmentHistoryEntry]) -> AssessmentSession? {
        let chosen: AssessmentSession?
        if let a = local, let b = remote, a.id == b.id {
            if (a.completedAt != nil) != (b.completedAt != nil) {
                chosen = a.completedAt != nil ? a : b
            } else if a.index != b.index {
                chosen = a.index > b.index ? a : b
            } else {
                chosen = a.updatedAt >= b.updatedAt ? a : b
            }
        } else if (local?.updatedAt ?? 0) >= (remote?.updatedAt ?? 0) {
            chosen = local ?? remote
        } else {
            chosen = remote
        }
        guard let session = chosen else { return nil }
        if session.completedAt == nil && history.contains(where: { (entry: AssessmentHistoryEntry) -> Bool in entry.id == session.id }) {
            return nil
        }
        return session
    }

    /// Union keyed by id; entries of `preferred` replace those of `base` in place.
    static func unionByID<T>(_ base: [T], _ preferred: [T], id: (T) -> String) -> [T] {
        var order: [String] = []
        var values: [String: T] = [:]
        for item in base + preferred {
            let key = id(item)
            if values[key] == nil { order.append(key) }
            values[key] = item
        }
        return order.compactMap { values[$0] }
    }
}
