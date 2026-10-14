import Foundation

// MARK: - Level

/// How much the level estimate can be trusted (own measure, finer than `LevelEstimate.confidence`).
public enum AnalysisConfidence: String, Sendable, Hashable, CaseIterable {
    /// No meanings with a CEFR level — nothing to estimate.
    case insufficient
    case low
    case medium
    case high

    /// Polish label.
    public var namePl: String {
        switch self {
        case .insufficient: return "brak danych"
        case .low: return "niska pewność"
        case .medium: return "średnia pewność"
        case .high: return "wysoka pewność"
        }
    }
}

/// Estimated CEFR level with an honest uncertainty range.
public struct LevelAssessment: Sendable, Hashable {
    /// `LevelEstimator.estimatedLevel` (the level used for practice content and recommendations).
    public var estimate: LevelEstimate
    /// Mastery-weighted average level index (0 = A1 … 5 = C2).
    public var score: Double
    /// Lower and upper end of the plausible range (equal when the estimate is reliable).
    public var lowerLevel: String
    public var upperLevel: String
    public var confidence: AnalysisConfidence
    /// Meanings with mastery ≥ 40 (the „practiced” sample of `LevelEstimator`).
    public var practicedMeanings: Int
    /// All answers (without demo history, with compacted summaries).
    public var totalAnswers: Int

    public init(estimate: LevelEstimate, score: Double, lowerLevel: String, upperLevel: String, confidence: AnalysisConfidence, practicedMeanings: Int, totalAnswers: Int) {
        self.estimate = estimate
        self.score = score
        self.lowerLevel = lowerLevel
        self.upperLevel = upperLevel
        self.confidence = confidence
        self.practicedMeanings = practicedMeanings
        self.totalAnswers = totalAnswers
    }

    /// Estimated level („B1”).
    public var level: String { estimate.level }

    /// Next level („B2”).
    public var targetLevel: String { estimate.targetLevel }

    /// „B1”, „A2–B1” or „—” when there is no data.
    public var rangeText: String {
        if confidence == .insufficient { return "—" }
        return lowerLevel == upperLevel ? lowerLevel : "\(lowerLevel)–\(upperLevel)"
    }

    /// Honest Polish description of how reliable the estimate is.
    public var descriptionPl: String {
        switch confidence {
        case .insufficient:
            return "Za mało danych, żeby ocenić poziom. Dodaj słowa i zrób kilka sesji."
        case .low:
            if practicedMeanings == 0 {
                return "Wstępna wskazówka z poziomów dodanych słów — jeszcze bez Twoich wyników. To nie jest wynik egzaminu."
            }
            return "Wstępna wskazówka: na razie tylko \(AnalysisText.meanings(practicedMeanings)) dobrze ćwiczonych. Wynik może się jeszcze wyraźnie zmienić."
        case .medium:
            return "Szacunek orientacyjny na podstawie \(AnalysisText.meanings(practicedMeanings)) ćwiczonych regularnie. Z każdą sesją będzie dokładniejszy."
        case .high:
            return "Dość pewny szacunek: \(AnalysisText.meanings(practicedMeanings)) dobrze ćwiczonych i \(AnalysisText.answers(totalAnswers))."
        }
    }

    /// What the estimate does and does not measure.
    public static let scopeNotePl = "Ocena dotyczy słownictwa, które ćwiczysz — nie gramatyki ani mówienia."
}

// MARK: - Skills

/// One mastery skill with its average score and recent accuracy.
public struct SkillInsight: Sendable, Hashable, Identifiable {
    public var skill: Skill
    /// Average score (0–100) over meanings that practiced the skill.
    public var average: Int
    /// Number of meanings that practiced the skill.
    public var meanings: Int
    /// Answers for this skill in the recent window.
    public var recentAnswers: Int
    /// Independent correct answers in percent (only with enough recent answers).
    public var recentAccuracy: Int?
    /// Combined measure used to compare skills (average, mixed with accuracy when known).
    public var strength: Int
    public var id: Skill { skill }

    public init(skill: Skill, average: Int, meanings: Int, recentAnswers: Int, recentAccuracy: Int?, strength: Int) {
        self.skill = skill
        self.average = average
        self.meanings = meanings
        self.recentAnswers = recentAnswers
        self.recentAccuracy = recentAccuracy
        self.strength = strength
    }
}

// MARK: - Pace

/// How regularly the learner studied in the recent window.
public enum StudyRegularity: String, Sendable, Hashable, CaseIterable {
    case inactive
    case occasional
    case regular
    case daily

    /// Polish label.
    public var namePl: String {
        switch self {
        case .inactive: return "brak nauki"
        case .occasional: return "od czasu do czasu"
        case .regular: return "regularnie"
        case .daily: return "prawie codziennie"
        }
    }
}

/// Learning pace: new meanings per week, answers, regularity.
public struct LearningPace: Sendable, Hashable {
    /// New meanings (first answer ever) per 7-day window, oldest first; the last one ends now.
    public var newMeaningsByWeek: [Int]
    /// Average of `newMeaningsByWeek`.
    public var newMeaningsPerWeek: Double
    /// Average answers per week over the same windows.
    public var answersPerWeek: Double
    /// Days with at least one answer in the last `windowDays` days.
    public var activeDays: Int
    public var windowDays: Int
    public var regularity: StudyRegularity
    /// Meanings that crossed the mastery threshold over the same weeks.
    public var masteredRecently: Int

    public init(newMeaningsByWeek: [Int], newMeaningsPerWeek: Double, answersPerWeek: Double, activeDays: Int, windowDays: Int, regularity: StudyRegularity, masteredRecently: Int) {
        self.newMeaningsByWeek = newMeaningsByWeek
        self.newMeaningsPerWeek = newMeaningsPerWeek
        self.answersPerWeek = answersPerWeek
        self.activeDays = activeDays
        self.windowDays = windowDays
        self.regularity = regularity
        self.masteredRecently = masteredRecently
    }

    /// Rounded new meanings per week.
    public var roundedNewPerWeek: Int { jsRoundInt(newMeaningsPerWeek) }

    /// Short Polish summary („≈ 12 nowych znaczeń tygodniowo · nauka w 9 z 14 dni”).
    public var summaryPl: String {
        if regularity == .inactive && answersPerWeek == 0 {
            return "Brak nauki w ostatnich tygodniach — krótka sesja dziś pomoże wrócić do rytmu."
        }
        let newPart: String
        if newMeaningsPerWeek <= 0 {
            newPart = "bez nowych znaczeń w ostatnich tygodniach"
        } else if newMeaningsPerWeek < 1 {
            newPart = "mniej niż 1 nowe znaczenie tygodniowo"
        } else {
            let value = roundedNewPerWeek
            newPart = "≈ \(value) \(AnalysisText.plural(value, one: "nowe znaczenie", few: "nowe znaczenia", many: "nowych znaczeń")) tygodniowo"
        }
        return "\(newPart) · nauka w \(activeDays) z \(windowDays) dni"
    }
}

// MARK: - Topic areas

/// A thematic area of the learner's vocabulary (built-in topic or own collection).
public struct TopicArea: Sendable, Hashable, Identifiable {
    /// Topic id, or `collection:<name>` for words without a built-in topic.
    public var id: String
    public var name: String
    /// Topic group id ("" for collections).
    public var group: String
    public var meanings: Int
    public var averageMastery: Int
    public var mastered: Int

    public init(id: String, name: String, group: String, meanings: Int, averageMastery: Int, mastered: Int) {
        self.id = id
        self.name = name
        self.group = group
        self.meanings = meanings
        self.averageMastery = averageMastery
        self.mastered = mastered
    }
}

// MARK: - Analysis

/// Background analysis of the learner (level, skills, pace, topics). Pure value — compute it off
/// the main thread (`LearnerAnalyzer.analyze`) and refresh it when the state changes.
public struct LearnerAnalysis: Sendable, Hashable {
    public var level: LevelAssessment
    /// Mastery skills with enough data, in `Skill.masterySkills` order.
    public var skills: [SkillInsight]
    /// Up to 2 clearly stronger skills (strongest first).
    public var strongSkills: [SkillInsight]
    /// Up to 2 clearly weaker skills (weakest first).
    public var weakSkills: [SkillInsight]
    /// Mastery skills never practiced (only when something was practiced).
    public var untestedSkills: [Skill]
    public var pace: LearningPace
    /// Largest areas first (max `LearnerAnalyzer.areaLimit`).
    public var topicAreas: [TopicArea]
    /// Best / worst mastered area among areas with enough meanings.
    public var strongestArea: TopicArea?
    public var weakestArea: TopicArea?

    public init(level: LevelAssessment, skills: [SkillInsight], strongSkills: [SkillInsight], weakSkills: [SkillInsight], untestedSkills: [Skill], pace: LearningPace, topicAreas: [TopicArea], strongestArea: TopicArea?, weakestArea: TopicArea?) {
        self.level = level
        self.skills = skills
        self.strongSkills = strongSkills
        self.weakSkills = weakSkills
        self.untestedSkills = untestedSkills
        self.pace = pace
        self.topicAreas = topicAreas
        self.strongestArea = strongestArea
        self.weakestArea = weakestArea
    }

    /// `false` for a learner without words and answers (nothing to show).
    public var hasData: Bool {
        level.confidence != .insufficient || pace.answersPerWeek > 0
    }

    /// „Mocna strona: Rozpoznawanie · Do poprawy: Pisownia”, `nil` without a clear difference.
    public var skillsSummaryPl: String? {
        var parts: [String] = []
        if let strong = strongSkills.first {
            parts.append("Mocna strona: \(strong.skill.namePl)")
        }
        if let weak = weakSkills.first {
            parts.append("Do poprawy: \(weak.skill.namePl)")
        } else if let untested = untestedSkills.first {
            parts.append("Jeszcze nie ćwiczone: \(untested.namePl)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Pure analysis functions (no clock or randomness inside — `now` and `calendar` are injected).
public enum LearnerAnalyzer {
    /// Maximum number of topic areas in the analysis.
    public static let areaLimit = 6
    /// A skill needs this many practiced meanings to be compared.
    public static let minSkillMeanings = 3
    /// Recent accuracy is used only with at least this many answers.
    public static let minAccuracyAnswers = 10
    /// An area needs this many meanings to be called strongest / weakest.
    public static let minAreaMeanings = 5

    /// The full analysis.
    public static func analyze(_ state: LearnerState, topics: TopicIndex? = nil, now: Timestamp, calendar: Calendar = .current) -> LearnerAnalysis {
        let skills = skillInsights(state, now: now)
        let split = splitSkills(skills)
        let areas = topicAreas(state, topics: topics)
        let eligibleAreas = areas.filter { $0.meanings >= minAreaMeanings }
        let strongest = eligibleAreas.stableSorted { $0.averageMastery > $1.averageMastery }.first
        let weakest = eligibleAreas.stableSorted { $0.averageMastery < $1.averageMastery }.first
        return LearnerAnalysis(
            level: assessLevel(state),
            skills: skills,
            strongSkills: split.strong,
            weakSkills: split.weak,
            untestedSkills: untestedSkills(state),
            pace: pace(state, now: now, calendar: calendar),
            topicAreas: Array(areas.prefix(areaLimit)),
            strongestArea: strongest,
            weakestArea: (weakest?.id == strongest?.id) ? nil : weakest
        )
    }

    // MARK: Level

    private struct LevelSample {
        let level: Int
        let score: Int
    }

    /// Level with an uncertainty range. The level itself is exactly `LevelEstimator.estimatedLevel`.
    public static func assessLevel(_ state: LearnerState) -> LevelAssessment {
        let estimate = LevelEstimator.estimatedLevel(state)
        var available: [LevelSample] = []
        for word in state.words where !word.archived {
            for meaning in word.meanings {
                if let index = CEFR.index(of: meaning.effectiveLevel(in: word)) {
                    available.append(LevelSample(level: index, score: Mastery.of(meaning)))
                }
            }
        }
        let practiced = available.filter { $0.score >= 40 }
        let sample: [LevelSample] = practiced.isEmpty
            ? available.map { (item: LevelSample) -> LevelSample in LevelSample(level: item.level, score: max(10, item.score)) }
            : practiced
        let total = sample.reduce(0.0) { $0 + Double($1.score) }
        let weighted = sample.reduce(0.0) { $0 + Double($1.level * $1.score) }
        let score = total > 0 ? weighted / total : 0
        let answers = answerCount(state)

        let confidence: AnalysisConfidence
        if available.isEmpty {
            confidence = .insufficient
        } else if practiced.count < 10 || answers < 40 {
            confidence = .low
        } else if practiced.count < 30 || answers < 150 {
            confidence = .medium
        } else {
            confidence = .high
        }

        let width: Double
        switch confidence {
        case .insufficient, .high: width = 0
        case .low: width = 0.75
        case .medium: width = 0.4
        }
        let maxIndex = CEFR.levels.count - 1
        let estimateIndex = CEFR.index(of: estimate.level) ?? 0
        let lower = min(estimateIndex, min(maxIndex, max(0, jsRoundInt(score - width))))
        let upper = max(estimateIndex, min(maxIndex, max(0, jsRoundInt(score + width))))
        return LevelAssessment(
            estimate: estimate,
            score: score,
            lowerLevel: CEFR.levels[lower],
            upperLevel: CEFR.levels[upper],
            confidence: confidence,
            practicedMeanings: practiced.count,
            totalAnswers: answers
        )
    }

    /// Real answers (demo excluded) plus compacted summaries.
    static func answerCount(_ state: LearnerState) -> Int {
        let recent = state.reviews.reduce(0) { $0 + ($1.demo ? 0 : 1) }
        return recent + state.reviewSummaries.reduce(0) { $0 + $1.count }
    }

    // MARK: Skills

    /// Mastery skills practiced on at least `minSkillMeanings` meanings, with recent accuracy.
    public static func skillInsights(_ state: LearnerState, now: Timestamp, windowDays: Int = 30) -> [SkillInsight] {
        let averages = ProgressStatistics.skillAverages(state)
        let start = now - Double(max(1, windowDays)) * TimeConstants.dayMs
        var counts: [Skill: Int] = [:]
        var correct: [Skill: Int] = [:]
        for review in state.reviews where !review.demo && review.at > start && review.at <= now {
            counts[review.skill, default: 0] += 1
            if review.correct && !review.hint { correct[review.skill, default: 0] += 1 }
        }
        var result: [SkillInsight] = []
        for skill in Skill.masterySkills {
            guard let item = averages.first(where: { $0.skill == skill }),
                  let average = item.average,
                  item.count >= minSkillMeanings else { continue }
            let answers = counts[skill] ?? 0
            var accuracy: Int?
            if answers >= minAccuracyAnswers {
                accuracy = jsRoundInt(Double(correct[skill] ?? 0) / Double(answers) * 100)
            }
            let strength = accuracy.map { jsRoundInt(Double(average + $0) / 2) } ?? average
            result.append(SkillInsight(skill: skill, average: average, meanings: item.count, recentAnswers: answers, recentAccuracy: accuracy, strength: strength))
        }
        return result
    }

    /// Clearly stronger / weaker skills (at least 5 points from the mean of compared skills).
    public static func splitSkills(_ skills: [SkillInsight]) -> (strong: [SkillInsight], weak: [SkillInsight]) {
        guard skills.count >= 2 else { return ([], []) }
        let mean = Double(skills.reduce(0) { $0 + $1.strength }) / Double(skills.count)
        let strong = skills
            .filter { Double($0.strength) >= mean + 5 && $0.strength >= 40 }
            .stableSorted { $0.strength > $1.strength }
        let strongIDs = Set(strong.prefix(2).map { $0.skill })
        let weak = skills
            .filter { Double($0.strength) <= mean - 5 && !strongIDs.contains($0.skill) }
            .stableSorted { $0.strength < $1.strength }
        return (Array(strong.prefix(2)), Array(weak.prefix(2)))
    }

    /// Mastery skills no meaning has practiced yet (empty when nothing was practiced at all).
    public static func untestedSkills(_ state: LearnerState) -> [Skill] {
        var practiced = Set<Skill>()
        var any = false
        for word in state.words where !word.archived {
            for meaning in word.meanings where !meaning.scores.isEmpty {
                any = true
                for skill in meaning.scores.skills { practiced.insert(skill) }
            }
        }
        guard any else { return [] }
        return Skill.masterySkills.filter { !practiced.contains($0) }
    }

    // MARK: Pace

    /// Pace over the last `weeks` 7-day windows; regularity over the last 14 days.
    public static func pace(_ state: LearnerState, now: Timestamp, weeks: Int = 4, calendar: Calendar = .current) -> LearningPace {
        let weekCount = max(1, weeks)
        let weekMs = 7 * TimeConstants.dayMs
        let start = now - Double(weekCount) * weekMs

        // First answer of every meaning (a meaning whose earliest kept answer started from mastery 0
        // is new then; older meanings whose history was compacted have `before > 0`).
        var first: [String: (at: Timestamp, before: Int)] = [:]
        var answers = 0
        for review in state.reviews where !review.demo {
            if review.at > start && review.at <= now { answers += 1 }
            if let existing = first[review.meaningId], existing.at <= review.at { continue }
            first[review.meaningId] = (at: review.at, before: review.before)
        }
        var buckets = [Int](repeating: 0, count: weekCount)
        for item in first.values where item.before == 0 && item.at > start && item.at <= now {
            let age = Int((now - item.at) / weekMs)
            let index = weekCount - 1 - min(weekCount - 1, max(0, age))
            buckets[index] += 1
        }
        let windowDays = 14
        let activeDays = ProgressStatistics.activity(state, days: windowDays, now: now, calendar: calendar)
            .filter { $0.count > 0 }.count
        let regularity: StudyRegularity
        switch activeDays {
        case 0: regularity = .inactive
        case 1...4: regularity = .occasional
        case 5...10: regularity = .regular
        default: regularity = .daily
        }
        let totalNew = buckets.reduce(0, +)
        return LearningPace(
            newMeaningsByWeek: buckets,
            newMeaningsPerWeek: Double(totalNew) / Double(weekCount),
            answersPerWeek: Double(answers) / Double(weekCount),
            activeDays: activeDays,
            windowDays: windowDays,
            regularity: regularity,
            masteredRecently: ProgressStatistics.masteryGains(state, from: start, to: now)
        )
    }

    // MARK: Topic areas

    /// Meanings grouped by built-in topic (`contentRef`), otherwise by collection; largest first.
    public static func topicAreas(_ state: LearnerState, topics: TopicIndex?) -> [TopicArea] {
        var summaries: [String: TopicSummary] = [:]
        for topic in topics?.topics ?? [] where summaries[topic.id] == nil {
            summaries[topic.id] = topic
        }
        var names: [String: String] = [:]
        var groups: [String: String] = [:]
        var masteries: [String: [Int]] = [:]
        var order: [String] = []
        for word in state.words where !word.archived {
            for meaning in word.meanings {
                let id: String
                let name: String
                let group: String
                if let raw = meaning.contentRef, let ref = ContentReference(raw), !ref.isStarter, let summary = summaries[ref.file] {
                    id = summary.id
                    name = summary.namePl
                    group = summary.group
                } else {
                    let collection = TextScanning.trim(word.collection)
                    id = "collection:\(collection)"
                    name = collection.isEmpty ? "Bez kolekcji" : collection
                    group = ""
                }
                if masteries[id] == nil {
                    order.append(id)
                    names[id] = name
                    groups[id] = group
                }
                masteries[id, default: []].append(Mastery.of(meaning))
            }
        }
        let areas = order.map { (id: String) -> TopicArea in
            let values = masteries[id] ?? []
            let average = values.isEmpty ? 0 : jsRoundInt(Double(values.reduce(0, +)) / Double(values.count))
            return TopicArea(
                id: id,
                name: names[id] ?? id,
                group: groups[id] ?? "",
                meanings: values.count,
                averageMastery: average,
                mastered: values.filter { $0 >= Mastery.masteredThreshold }.count
            )
        }
        return areas.stableSorted { lhs, rhs in
            if lhs.meanings != rhs.meanings { return lhs.meanings > rhs.meanings }
            return lhs.name < rhs.name
        }
    }
}

/// Polish texts with plural forms used by the analysis.
enum AnalysisText {
    /// 1 → one, 2–4 (not 12–14) → few, otherwise many.
    static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let value = abs(count)
        if value == 1 { return one }
        let lastTwo = value % 100
        let last = value % 10
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return few }
        return many
    }

    static func meanings(_ count: Int) -> String {
        "\(count) \(plural(count, one: "znaczenie", few: "znaczenia", many: "znaczeń"))"
    }

    static func answers(_ count: Int) -> String {
        "\(count) \(plural(count, one: "odpowiedź", few: "odpowiedzi", many: "odpowiedzi"))"
    }
}
