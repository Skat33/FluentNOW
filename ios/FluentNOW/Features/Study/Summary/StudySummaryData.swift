import Foundation
import FluentKit

/// Dane ekranu „Mały krok za Tobą.” (sesja słownictwa i sesja łączona).
struct StudySummaryData: Equatable {
    struct SkillCount: Identifiable, Equatable {
        let skill: Skill
        let count: Int
        var id: String { skill.rawValue }
    }

    struct WordLine: Identifiable, Equatable {
        let id: String
        let term: String
        let detail: String
    }

    struct ModeLine: Identifiable, Equatable {
        let mode: StudyMode
        let correct: Int
        let total: Int
        var id: String { mode.rawValue }
    }

    var total: Int
    var correct: Int
    var seconds: Double
    var skills: [SkillCount]
    /// Słowa, których opanowanie wzrosło (z wartością przyrostu).
    var grown: [WordLine]
    /// Słowa do powtórki (błędne odpowiedzi w tej sesji).
    var toReview: [WordLine]
    var modeLines: [ModeLine]
    /// Odpowiedzi tej sesji i prefiks wpisów historii sesji łączonej — do „+XP” (G5,
    /// `Progression.sessionGain`, liczone w tle przez `StudySummaryXPBadge`).
    var reviewIDs: [String] = []
    var historyIDPrefix: String?

    var percent: Int { StudyFormat.percent(correct, of: total) }

    /// Buduje podsumowanie z recenzji zapisanych w tym uruchomieniu (`Review.before/after` = opanowanie znaczenia).
    static func make(
        state: LearnerState,
        total: Int,
        correct: Int,
        seconds: Double,
        reviewIDs: [String],
        modeLines: [ModeLine]
    ) -> StudySummaryData {
        let wanted = Set(reviewIDs)
        let window = state.reviews.suffix(max(200, reviewIDs.count * 3))
        let reviews = window.filter { wanted.contains($0.id) }

        var skillCounts: [Skill: Int] = [:]
        var gains: [String: Int] = [:]
        var gainOrder: [String] = []
        var missed: [String] = []
        for review in reviews {
            skillCounts[review.skill, default: 0] += 1
            let delta = review.after - review.before
            if delta > 0 {
                if gains[review.meaningId] == nil { gainOrder.append(review.meaningId) }
                gains[review.meaningId, default: 0] += delta
            }
            if !review.correct && !missed.contains(review.meaningId) {
                missed.append(review.meaningId)
            }
        }

        let skills = Skill.allCases.compactMap { skill -> SkillCount? in
            guard let count = skillCounts[skill], count > 0 else { return nil }
            return SkillCount(skill: skill, count: count)
        }
        let grown = gainOrder
            .sorted { (gains[$0] ?? 0) > (gains[$1] ?? 0) }
            .prefix(5)
            .compactMap { meaningID -> WordLine? in
                guard let pair = state.wordAndMeaning(meaningID: meaningID) else { return nil }
                return WordLine(id: meaningID, term: pair.word.en, detail: "+\(gains[meaningID] ?? 0)% · \(pair.meaning.translation)")
            }
        let toReview = missed.prefix(6).compactMap { meaningID -> WordLine? in
            guard let pair = state.wordAndMeaning(meaningID: meaningID) else { return nil }
            return WordLine(id: meaningID, term: pair.word.en, detail: pair.meaning.translation)
        }
        return StudySummaryData(
            total: total,
            correct: correct,
            seconds: seconds,
            skills: skills,
            grown: Array(grown),
            toReview: Array(toReview),
            modeLines: modeLines,
            reviewIDs: reviewIDs,
            historyIDPrefix: combinedHistoryPrefix(state, modeLines: modeLines)
        )
    }

    /// Sesja łączona zapisuje wpisy historii o id `"<id sesji>:<tryb>"` przy zakończeniu.
    private static func combinedHistoryPrefix(_ state: LearnerState, modeLines: [ModeLine]) -> String? {
        guard !modeLines.isEmpty, let combined = state.combined, combined.completedAt != nil else { return nil }
        return "\(combined.id):"
    }
}
