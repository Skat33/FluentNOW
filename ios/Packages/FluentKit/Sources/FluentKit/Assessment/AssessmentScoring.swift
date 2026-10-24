import Foundation

/// Points out of a number of questions.
public struct AssessmentScore: Sendable, Hashable {
    public var points: Double
    public var total: Int

    public init(points: Double = 0, total: Int = 0) {
        self.points = finiteNonNegative(points)
        self.total = max(0, total)
    }

    /// Share 0…1 (0 without questions).
    public var ratio: Double {
        total > 0 ? min(1, points / Double(total)) : 0
    }

    /// 0–100, rounded like the web.
    public var percent: Int {
        total > 0 ? min(100, max(0, jsRoundInt(ratio * 100))) : 0
    }

    /// „3,5/4” style text with at most one decimal.
    public var pointsText: String {
        let rounded = (points * 10).rounded() / 10
        let text = rounded == rounded.rounded() ? String(Int(rounded)) : String(format: "%.1f", rounded).replacingOccurrences(of: ".", with: ",")
        return "\(text)/\(total)"
    }

    mutating func add(_ value: Double) {
        points += finiteNonNegative(value)
        total += 1
    }
}

/// Score of one block.
public struct AssessmentBlockScore: Sendable, Hashable, Identifiable {
    public var block: AssessmentBlock
    public var score: AssessmentScore
    public var id: String { block.rawValue }

    public init(block: AssessmentBlock, score: AssessmentScore) {
        self.block = block
        self.score = score
    }
}

/// Score of one skill.
public struct AssessmentSkillScore: Sendable, Hashable, Identifiable {
    public var skill: AssessmentSkill
    public var score: AssessmentScore
    public var id: String { skill.rawValue }

    public init(skill: AssessmentSkill, score: AssessmentScore) {
        self.skill = skill
        self.score = score
    }
}

/// How the answers relate to the base level.
public enum AssessmentVerdict: String, Sendable, Hashable {
    /// Too few answers for any conclusion.
    case uncertain
    /// The base level is solid and the questions above it went well too.
    case above
    /// The base level is solid.
    case solid
    /// The base level holds (with gaps).
    case confirmed
    /// The lower part of the band holds, the base level is still being built.
    case below
    /// Many questions of the whole band were difficult.
    case belowBand
}

/// Level estimated from the test, with an honest description.
public struct AssessmentLevelResult: Sendable, Hashable {
    /// CEFR level stored in the history.
    public var level: String
    /// Text to show („B1”, „A2 lub niżej”).
    public var levelText: String
    public var verdict: AssessmentVerdict
    public var descriptionPl: String
    /// Scores per tier (lower / base / above).
    public var lower: AssessmentScore
    public var upper: AssessmentScore
    public var stretch: AssessmentScore

    public init(level: String, levelText: String, verdict: AssessmentVerdict, descriptionPl: String, lower: AssessmentScore, upper: AssessmentScore, stretch: AssessmentScore) {
        self.level = level
        self.levelText = levelText
        self.verdict = verdict
        self.descriptionPl = descriptionPl
        self.lower = lower
        self.upper = upper
        self.stretch = stretch
    }
}

/// A wrong answer with the right one.
public struct AssessmentMistake: Sendable, Hashable, Identifiable {
    public var id: String
    public var block: AssessmentBlock
    public var prompt: String
    public var given: String
    public var expected: String
    /// The learner's own word (`false`: a base word, or grammar / reading).
    public var owned: Bool
    public var wordId: String?
    public var contentRef: String?

    public init(id: String, block: AssessmentBlock, prompt: String, given: String, expected: String, owned: Bool, wordId: String? = nil, contentRef: String? = nil) {
        self.id = id
        self.block = block
        self.prompt = prompt
        self.given = given
        self.expected = expected
        self.owned = owned
        self.wordId = wordId
        self.contentRef = contentRef
    }
}

/// Everything shown on the result screen.
public struct AssessmentResult: Sendable, Hashable {
    public var overall: AssessmentScore
    public var blocks: [AssessmentBlockScore]
    public var skills: [AssessmentSkillScore]
    public var level: AssessmentLevelResult
    public var mistakes: [AssessmentMistake]
    public var seconds: Double

    public init(overall: AssessmentScore, blocks: [AssessmentBlockScore], skills: [AssessmentSkillScore], level: AssessmentLevelResult, mistakes: [AssessmentMistake], seconds: Double) {
        self.overall = overall
        self.blocks = blocks
        self.skills = skills
        self.level = level
        self.mistakes = mistakes
        self.seconds = seconds
    }

    /// Number of the learner's own words with a mistake.
    public var wrongOwnedCount: Int {
        Set(mistakes.filter { (mistake: AssessmentMistake) -> Bool in mistake.owned }.compactMap { (mistake: AssessmentMistake) -> String? in mistake.wordId }).count
    }
}

/// Scoring of the level test (pure).
public enum AssessmentScoring {
    /// Answers below this count give no level conclusion.
    public static let minimumAnswersForLevel = 10
    /// Share of the base level needed to confirm it.
    public static let confirmShare = 0.6
    /// Share of the base level that counts as solid.
    public static let solidShare = 0.8
    /// Share of the stretch questions (at least two) that suggests the next level.
    public static let stretchShare = 0.66

    public static func result(_ session: AssessmentSession) -> AssessmentResult {
        var overall = AssessmentScore()
        var blocks: [AssessmentBlock: AssessmentScore] = [:]
        var skills: [AssessmentSkill: AssessmentScore] = [:]
        var tiers: [AssessmentTier: AssessmentScore] = [:]
        var mistakes: [AssessmentMistake] = []
        for (position, answer) in session.answers.enumerated() {
            guard let question = session.questions[safe: position] else { continue }
            overall.add(answer.points)
            blocks[question.block, default: AssessmentScore()].add(answer.points)
            skills[question.block.skill, default: AssessmentScore()].add(answer.points)
            tiers[question.tier, default: AssessmentScore()].add(answer.points)
            mistakes.append(contentsOf: mistakeList(answer, block: question.block, position: position))
        }
        let blockScores = AssessmentBlock.allCases.compactMap { (block: AssessmentBlock) -> AssessmentBlockScore? in
            blocks[block].map { (score: AssessmentScore) -> AssessmentBlockScore in AssessmentBlockScore(block: block, score: score) }
        }
        let skillScores = AssessmentSkill.allCases.compactMap { (skill: AssessmentSkill) -> AssessmentSkillScore? in
            skills[skill].map { (score: AssessmentScore) -> AssessmentSkillScore in AssessmentSkillScore(skill: skill, score: score) }
        }
        let level = estimateLevel(
            band: session.band,
            overall: overall,
            lower: tiers[.lower] ?? AssessmentScore(),
            upper: tiers[.upper] ?? AssessmentScore(),
            stretch: tiers[.stretch] ?? AssessmentScore()
        )
        return AssessmentResult(overall: overall, blocks: blockScores, skills: skillScores, level: level, mistakes: mistakes, seconds: session.activeSeconds)
    }

    static func mistakeList(_ answer: AssessmentAnswer, block: AssessmentBlock, position: Int) -> [AssessmentMistake] {
        let given = TextScanning.trim(answer.value).isEmpty ? "(brak odpowiedzi)" : answer.value
        if !answer.items.isEmpty {
            let isBoard = answer.items.count > 1
            var list: [AssessmentMistake] = []
            for (offset, item) in answer.items.enumerated() where !item.correct {
                list.append(AssessmentMistake(
                    id: "\(position)-\(offset)",
                    block: block,
                    prompt: item.prompt,
                    given: isBoard ? "pomyłka w parze" : given,
                    expected: item.expected,
                    owned: item.owned,
                    wordId: item.wordId,
                    contentRef: item.contentRef
                ))
            }
            return list
        }
        guard !answer.correct else { return [] }
        return [AssessmentMistake(id: "\(position)", block: block, prompt: answer.prompt, given: given, expected: answer.expected, owned: false)]
    }

    /// Level from the answers per part of the band. The test only covers `[base − 1, base]` and a
    /// few questions above, so it confirms or lowers the base level and at most suggests the next one.
    public static func estimateLevel(band: AssessmentBand, overall: AssessmentScore, lower: AssessmentScore, upper: AssessmentScore, stretch: AssessmentScore) -> AssessmentLevelResult {
        let base = band.base
        let range = band.rangeText
        let note = " To szacunek z \(overall.total) \(plural(overall.total, one: "pytania", few: "pytań", many: "pytań")) w paśmie \(range) — wskazówka do nauki, nie wynik egzaminu."
        func make(_ level: String, _ text: String, _ verdict: AssessmentVerdict, _ description: String) -> AssessmentLevelResult {
            AssessmentLevelResult(level: level, levelText: text, verdict: verdict, descriptionPl: description + note, lower: lower, upper: upper, stretch: stretch)
        }
        guard overall.total >= minimumAnswersForLevel else {
            return make(base, base, .uncertain, "Za mało odpowiedzi, żeby ocenić poziom — zostaje poziom \(base).")
        }
        // Base-level evidence: upper-tier words, grammar and the reading (all on the base level).
        let baseShare = upper.total > 0 ? upper.ratio : overall.ratio
        if baseShare >= solidShare {
            if let next = band.stretch, stretch.total >= 2, stretch.ratio >= stretchShare {
                return make(next, next, .above, "Pytania z poziomu \(base) poszły bardzo dobrze, a te z \(next) też w większości. Możesz śmiało sięgać po materiały \(next).")
            }
            return make(base, base, .solid, "Poziom \(base) masz dobrze opanowany.")
        }
        if baseShare >= confirmShare {
            return make(base, base, .confirmed, "Poziom \(base) się potwierdza, choć zostały luki — lista błędów pokazuje, co powtórzyć.")
        }
        let lowerLevel = band.lower
        if lowerLevel != base && (lower.total == 0 || lower.ratio >= confirmShare) {
            return make(lowerLevel, lowerLevel, .below, "Podstawy \(lowerLevel) są pewne, poziom \(base) jeszcze się buduje.")
        }
        let text = lowerLevel == "A1" ? "A1" : "\(lowerLevel) lub niżej"
        return make(lowerLevel, text, .belowBand, "Sporo pytań z pasma \(range) sprawiło trudność. Warto wrócić do podstaw i powtarzać słowa z listy błędów.")
    }

    /// Polish plural after a number in the genitive („z 1 pytania”, „z 30 pytań”).
    static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let value = abs(count)
        if value == 1 { return one }
        let last = value % 10
        let lastTwo = value % 100
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return few }
        return many
    }

    /// The history entry of a finished test.
    public static func historyEntry(_ session: AssessmentSession, result: AssessmentResult, at: Timestamp) -> AssessmentHistoryEntry {
        var skills: [String: Int] = [:]
        for item in result.skills {
            skills[item.skill.rawValue] = item.score.percent
        }
        return AssessmentHistoryEntry(
            id: session.id,
            at: at,
            baseLevel: session.band.base,
            level: result.level.level,
            percent: result.overall.percent,
            points: result.overall.points,
            total: result.overall.total,
            seconds: session.activeSeconds,
            readingId: session.reading?.id,
            skills: skills
        )
    }

    // MARK: Words after the test

    /// Own words with at least one wrong answer (in order of the test).
    public static func wrongOwnedWordIDs(_ session: AssessmentSession) -> [String] {
        var result: [String] = []
        for answer in session.answers {
            for item in answer.items where item.owned && !item.correct && !result.contains(item.wordId) {
                result.append(item.wordId)
            }
        }
        return result
    }

    /// Content references of base words answered wrong (for „Dodaj nowe słowa do nauki”).
    public static func wrongBankReferences(_ session: AssessmentSession) -> [String] {
        var result: [String] = []
        for answer in session.answers {
            for item in answer.items where !item.owned && !item.correct {
                guard let reference = item.contentRef, !reference.isEmpty, !result.contains(reference) else { continue }
                result.append(reference)
            }
        }
        return result
    }
}
