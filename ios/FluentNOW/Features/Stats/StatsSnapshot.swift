import Foundation
import FluentKit

/// Dane ekranu Postępy — liczone raz na zmianę stanu, poza głównym wątkiem (`store.compute`).
struct StatsSnapshot: Hashable, Sendable {
    var overview: StatsOverview
    var week: [DayActivity]
    var calendar: [DayActivity]
    var skills: [SkillAverage]
    var levels: [LevelProgress]
    var forecast: [ForecastDay]
    var gains: [WeeklyGain]
    var hardWords: [WordListRow]
    var reading: ExerciseTotals
    var practice: ExerciseTotals
    var estimate: LevelEstimate
    var goal: Int
    /// Pełna analiza (poziom z zakresem pewności, umiejętności, tempo, obszary) — `StatsAnalysisSection`.
    var analysis: LearnerAnalysis
    /// XP i poziom (G5) — `StatsProgressionSection`.
    var progression: ProgressionSummary

    static let calendarDays = 84
    static let gainWeeks = 8
    static let hardLimit = 5

    static func make(state: LearnerState, now: Timestamp, topics: TopicIndex? = nil) -> StatsSnapshot {
        let hard = ProgressStatistics.hardWords(state, limit: hardLimit, now: now).map { word -> WordListRow in
            let status = word.status(now: now)
            return WordListRow(
                id: word.id,
                en: word.en,
                translations: word.meanings.map { $0.translation }.joined(separator: " · "),
                level: word.level,
                status: status,
                mastery: word.mastery,
                meaningCount: word.meanings.count,
                collection: word.collection,
                isHard: status == .hard,
                isImportant: word.important,
                isArchived: word.archived
            )
        }
        return StatsSnapshot(
            overview: ProgressStatistics.overview(state, now: now),
            week: ProgressStatistics.week(state, now: now),
            calendar: ProgressStatistics.activityCalendar(state, days: calendarDays, now: now),
            skills: ProgressStatistics.skillAverages(state),
            levels: ProgressStatistics.levelProgress(state),
            forecast: ProgressStatistics.reviewForecast(state, days: 7, now: now),
            gains: ProgressStatistics.weeklyMasteryGains(state, weeks: gainWeeks, now: now),
            hardWords: hard,
            reading: ProgressStatistics.readingTotals(state),
            practice: ProgressStatistics.practiceTotals(state),
            estimate: LevelEstimator.estimatedLevel(state),
            goal: state.settings.goal,
            analysis: LearnerAnalyzer.analyze(state, topics: topics, now: now),
            progression: Progression.summary(state, now: now)
        )
    }
}

enum StatsText {
    /// Uczciwy opis pewności oszacowania poziomu.
    static func confidence(_ estimate: LevelEstimate) -> String {
        switch estimate.confidence {
        case .high:
            return "Oszacowanie dość pewne — opiera się na \(LibraryText.meanings(estimate.count)) z Twoich odpowiedzi."
        case .medium:
            return "Oszacowanie orientacyjne (\(LibraryText.meanings(estimate.count))). Im więcej ćwiczysz, tym będzie dokładniejsze."
        case .low:
            return "Na razie to tylko wstępna wskazówka — za mało ćwiczonych znaczeń (\(estimate.count)). To nie jest wynik egzaminu."
        }
    }

    static func percent(_ correct: Int, of total: Int) -> String {
        guard total > 0 else { return "—" }
        return "\(Int((Double(correct) / Double(total) * 100).rounded()))%"
    }
}
