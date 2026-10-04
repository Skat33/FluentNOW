import Foundation

/// Built-in practice banks needed to build grammar / idiom / production / reading tasks.
/// The app loads the files lazily (only the needed grammar level) and passes them in.
public struct PracticeContent: Sendable, Hashable {
    /// Merged `grammar/<level>.json` items.
    public var grammar: ProductionBank
    /// `exercises.json`.
    public var exercises: ProductionBank
    public var idioms: IdiomBank
    public var readings: ReadingBank
    /// Allowed constructions per level (from the grammar files).
    public var rules: [String: [String]]

    public init(grammar: ProductionBank = ProductionBank(), exercises: ProductionBank = ProductionBank(), idioms: IdiomBank = IdiomBank(), readings: ReadingBank = ReadingBank(), rules: [String: [String]] = [:]) {
        self.grammar = grammar
        self.exercises = exercises
        self.idioms = idioms
        self.readings = readings
        self.rules = rules
    }

    /// Builds content from the per-level grammar files.
    public init(grammarFiles: [GrammarLevelFile], exercises: ProductionBank, idioms: IdiomBank, readings: ReadingBank) {
        var rules: [String: [String]] = [:]
        for file in grammarFiles { rules[file.level] = file.rules }
        self.init(grammar: ProductionBank(grammarFiles: grammarFiles), exercises: exercises, idioms: idioms, readings: readings, rules: rules)
    }

    public static let empty = PracticeContent()

    /// A1…C2 stays, anything else falls back to A2 (web `productionRules[level] ? level : "A2"`).
    public static func resolvedLevel(_ level: String) -> String {
        CEFR.isValid(level) ? level : "A2"
    }

    /// `productionPool(level)`: `exercises[level]` + `grammar[level]`, every item with a `bankId`.
    /// Falls back to A2 when the level has no items loaded.
    public func productionPool(level: String) -> [ProductionItem] {
        let actual = PracticeContent.resolvedLevel(level)
        var pool = exercises.items(level: actual) + grammar.items(level: actual)
        if pool.isEmpty && actual != "A2" {
            pool = exercises.items(level: "A2") + grammar.items(level: "A2")
        }
        return pool.map { (item: ProductionItem) -> ProductionItem in
            var copy = item
            copy.bankId = GrammarSelector.taskID(item)
            return copy
        }
    }

    /// `idiomPool(level, variant)`: idiom questions whose three distractors rotate with `variant`
    /// (taken from the correct meanings of the other idioms of the level). `answer` is 0.
    public func idiomPool(level: String, variant: Int = 0) -> [PracticeQuestion] {
        var base = idioms.items(level: level)
        if base.isEmpty { base = idioms.items(level: "A2") }
        let meanings = base.map { $0.correctOption }
        var result: [PracticeQuestion] = []
        result.reserveCapacity(base.count)
        for index in base.indices {
            var question = base[index]
            let others = meanings.enumerated().filter { $0.offset != index }.map { $0.element }
            if !others.isEmpty {
                let start = PracticeBuilder.mod(variant * 5 + index * 3, others.count)
                let wrong = (0..<3).map { others[(start + $0) % others.count] }
                question.options = [meanings[index]] + wrong
                question.answer = 0
            }
            result.append(question)
        }
        return result
    }
}

/// Offline grammar, idiom and production sets (tutor-local.ts `starterPractice`,
/// production.ts `starterProduction`).
public enum PracticeBuilder {
    /// Extra wrong option for items with fewer than three distractors (web constant).
    private static let extraDistractors: [String: String] = [
        "are running": "is running", "visited": "visits", "Close": "to close", "have known": "has known",
        "was cooking": "were cooking", "would travel": "would travels", "are cleaned": "is cleaned",
        "had been flying": "has been flying", "had left": "has left", "has been studying": "have been studying",
        "would have helped": "would helped"
    ]

    /// Non-negative modulo.
    static func mod(_ value: Int, _ divisor: Int) -> Int {
        guard divisor > 0 else { return 0 }
        let remainder = value % divisor
        return remainder < 0 ? remainder + divisor : remainder
    }

    /// The hint in parentheses after the gap (`________ (pomóc)` → `pomóc`).
    static func gapHint(_ context: String) -> String? {
        guard let gapRange = context.range(of: "__") else { return nil }
        var index = gapRange.lowerBound
        while index < context.endIndex && context[index] == "_" { index = context.index(after: index) }
        while index < context.endIndex && context[index].isWhitespace { index = context.index(after: index) }
        guard index < context.endIndex, context[index] == "(" else { return nil }
        let start = context.index(after: index)
        guard let close = context[start...].firstIndex(of: ")") else { return nil }
        let hint = String(context[start..<close])
        return hint.isEmpty ? nil : hint
    }

    /// A production item shown as a multiple-choice / typed practice question.
    public static func practiceQuestion(from item: ProductionItem) -> PracticeQuestion {
        var wrong = item.distractors.map { $0.form }
        if wrong.count < 3 {
            wrong.append(extraDistractors[item.answer] ?? "to \(item.answer)")
        }
        var context = item.context
        if !item.hintPl.isEmpty, let range = context.range(of: " (\(item.hintPl))") {
            context.replaceSubrange(range, with: "")
        }
        return PracticeQuestion(
            format: nil,
            inputHint: gapHint(item.context) ?? item.rule,
            acceptedAnswers: item.acceptedAnswers,
            bankId: item.bankId,
            scenarioId: item.scenarioId,
            category: .grammar,
            prompt: "Wybierz formę pasującą do kontekstu. Konstrukcja: \(item.rule).",
            context: context,
            options: [item.answer] + Array(wrong.prefix(3)),
            answer: 0,
            explanation: item.explanation,
            translation: item.translation
        )
    }

    private static func pick(_ pool: [PracticeQuestion], count: Int, variant: Int, zeroOffset: Bool) -> [PracticeQuestion] {
        guard !pool.isEmpty, count > 0 else { return [] }
        let step = count == pool.count ? max(1, count - 1) : count
        let base = zeroOffset ? 0 : variant * step
        return (0..<count).map { (i: Int) -> PracticeQuestion in
            var item = pool[mod(base + i, pool.count)]
            let n = item.options.count
            guard n > 0 else { return item }
            let shift = mod(variant + i, 4) % n
            item.options = Array(item.options[shift...]) + Array(item.options[..<shift])
            item.answer = mod(item.answer - shift, n)
            return item
        }
    }

    /// `starterPractice`: 6 questions. `seen` (grammar exposure) makes grammar selection avoid
    /// repeats; mixed sets alternate grammar and idioms, with 2 typed grammar questions.
    public static func starterPractice(kind: PracticeKind, level: String, variant: Int = 0, seen: [String: Double]? = nil, content: PracticeContent) -> PracticeSet {
        let pool = content.productionPool(level: level)
        let selected: [ProductionItem]
        if let seen {
            selected = GrammarSelector.selectItems(pool, count: kind == .mixed ? 3 : 6, seen: seen, variant: variant)
        } else {
            selected = pool
        }
        let grammar = selected.map(practiceQuestion(from:))
        let idioms = content.idiomPool(level: level, variant: variant)
        var items: [PracticeQuestion]
        switch kind {
        case .grammar:
            items = pick(grammar, count: 6, variant: variant, zeroOffset: seen != nil)
        case .idioms:
            items = pick(idioms, count: 6, variant: variant, zeroOffset: false)
        case .mixed:
            let grammarItems = pick(grammar, count: 3, variant: variant, zeroOffset: seen != nil)
            let idiomItems = pick(idioms, count: 3, variant: variant, zeroOffset: false)
            items = []
            for (index, item) in grammarItems.enumerated() {
                items.append(item)
                if let idiom = idiomItems[safe: index] { items.append(idiom) }
            }
            for index in [0, 4] where index < items.count && items[index].category == .grammar {
                items[index].format = .input
                items[index].prompt = "Uzupełnij lukę odpowiednią angielską formą. Zwróć uwagę na czas i kontekst."
            }
        }
        return PracticeSet(id: "bank-v2-\(kind.rawValue)-\(level)-\(variant)", title: kind.namePl, level: level, kind: kind, items: items, source: .starter)
    }

    /// `starterProduction`: `count` gap-fill tasks of a level; with `seen`, unseen tasks first.
    public static func starterProduction(level: String, variant: Int = 0, count: Int = 4, seen: [String: Double]? = nil, content: PracticeContent) -> ProductionSet {
        let actual = PracticeContent.resolvedLevel(level)
        let pool = content.productionPool(level: actual)
        let size = max(1, count)
        guard !pool.isEmpty else {
            return ProductionSet(title: "Dobierz formę z kontekstu · \(actual)", level: actual, items: [])
        }
        let start = mod(max(0, variant) * size, pool.count)
        let items: [ProductionItem]
        if let seen {
            items = GrammarSelector.selectItems(pool, count: size, seen: seen, variant: variant)
        } else {
            items = (0..<min(size, pool.count)).map { pool[(start + $0) % pool.count] }
        }
        return ProductionSet(title: "Dobierz formę z kontekstu · \(actual) · zestaw \(start / size + 1)", level: actual, items: items)
    }
}
