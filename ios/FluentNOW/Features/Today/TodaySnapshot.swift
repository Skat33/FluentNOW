import Foundation
import FluentKit

/// Przerwana sesja do wznowienia.
struct TodayResume: Hashable, Sendable {
    let done: Int
    let total: Int
    let isCombined: Bool
}

/// Wszystko, czego potrzebuje ekran Dzisiaj — liczone raz na zmianę stanu, poza głównym wątkiem.
struct TodaySnapshot: Hashable, Sendable {
    var goal: DailyGoalProgress
    var overview: StatsOverview
    var week: [DayActivity]
    var collections: [CollectionSummary]
    var recent: [WordListRow]
    var resume: TodayResume?
    var recommendations: [Recommendation]
    /// Analiza w tle (poziom z pewnością, tempo, mocne/słabe strony) — karta `TodayAnalysisCard`.
    var analysis: LearnerAnalysis
    /// XP i poziom (G5) — pasek `TodayXPCard`, liczone z historii (`Progression.summary`).
    var progression: ProgressionSummary

    static let collectionLimit = 3
    static let recentLimit = 4

    static func make(state: LearnerState, candidates: [Recommendation], now: Timestamp) -> TodaySnapshot {
        let overview = ProgressStatistics.overview(state, now: now)
        let collections = WordListBuilder.allCollections(state)
            .map { CollectionBuilder.summary(state: state, name: $0, now: now) }
            .filter { $0.meaningCount > 0 }
            .sorted { lhs, rhs in
                // Najpierw te z powtórkami, potem w toku (nieopanowane), potem reszta.
                if (lhs.dueMeanings > 0) != (rhs.dueMeanings > 0) { return lhs.dueMeanings > 0 }
                if (lhs.averageMastery < 100) != (rhs.averageMastery < 100) { return lhs.averageMastery < 100 }
                return lhs.wordCount > rhs.wordCount
            }
        var recentFilter = WordListFilter()
        recentFilter.sort = .recent
        let recent = WordListBuilder.build(state: state, query: "", filter: recentFilter, now: now)
            .sections.flatMap { $0.rows }
        return TodaySnapshot(
            goal: ProgressStatistics.dailyGoal(state, now: now),
            overview: overview,
            week: ProgressStatistics.week(state, now: now),
            collections: Array(collections.prefix(collectionLimit)),
            recent: Array(recent.prefix(recentLimit)),
            resume: resume(state),
            recommendations: candidates.isEmpty ? [] : LevelEstimator.recommendations(state, candidates: candidates),
            analysis: LearnerAnalyzer.analyze(state, topics: nil, now: now),
            progression: Progression.summary(state, now: now)
        )
    }

    static func resume(_ state: LearnerState) -> TodayResume? {
        if let combined = state.combined, combined.completedAt == nil, combined.index < combined.tasks.count {
            return TodayResume(done: combined.index, total: combined.tasks.count, isCombined: true)
        }
        if let session = state.session, !session.isFinished, !session.tasks.isEmpty {
            return TodayResume(done: min(session.index, session.tasks.count), total: session.tasks.count, isCombined: false)
        }
        return nil
    }
}
