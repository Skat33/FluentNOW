import Foundation

/// A word of the built-in base offered to the test (an entry of a loaded topic file).
public struct AssessmentBankEntry: Sendable, Hashable {
    public var entry: TopicEntry
    /// `<topic>/<entry>` (`ContentReference.rawValue`).
    public var reference: String
    public var topicName: String
    public var categoryName: String?
    public var scene: String?
    /// The topic is one of the learner's own topics (or a topic of the study profile).
    public var fromLearnerTopics: Bool

    public init(entry: TopicEntry, reference: String, topicName: String, categoryName: String? = nil, scene: String? = nil, fromLearnerTopics: Bool) {
        self.entry = entry
        self.reference = reference
        self.topicName = topicName
        self.categoryName = categoryName
        self.scene = scene
        self.fromLearnerTopics = fromLearnerTopics
    }
}

/// Content the app loads for a test (off the main thread).
public struct AssessmentContent: Sendable, Hashable {
    public var bankEntries: [AssessmentBankEntry]
    /// Grammar items of the base level (`PracticeContent.productionPool(level:)`).
    public var grammarPool: [ProductionItem]
    public var readings: ReadingBank

    public init(bankEntries: [AssessmentBankEntry] = [], grammarPool: [ProductionItem] = [], readings: ReadingBank = ReadingBank()) {
        self.bankEntries = bankEntries
        self.grammarPool = grammarPool
        self.readings = readings
    }
}

/// Builds the level test (FEEDBACK-6 K4): the band, the ordered pool of words (own words of the
/// band first — practiced ones before new ones — then frequent base words, topics of the learner
/// first), grammar and a short reading of the base level, and the planned blocks.
/// Deterministic for a given random generator.
public enum AssessmentBuilder {
    /// Prefix of word / meaning ids of base words inside a test (never collides with UUIDs).
    public static let bankPrefix = "test:"
    /// Base words kept per tier (the session stores them, so it can be resumed offline). A test
    /// asks about 27 meanings; a streak can keep it on one tier, so a tier holds enough for all.
    public static let maxBankPerTier = 30
    public static let maxBankStretch = 6
    /// Example sentences kept per base word (keeps the saved test small).
    public static let maxBankExamples = 3
    /// Own meanings kept in the pool (references only).
    public static let maxOwnedCandidates = 240
    /// A test with fewer questions is not offered.
    public static let minimumQuestions = 8
    /// Topic files the app loads for base words.
    public static let topicLimit = 8
    /// A test result newer than this is used as the base level while the vocabulary estimate is
    /// still uncertain.
    public static let recentTestDays: Double = 90

    // MARK: Level

    /// Base level: `ProfileLevel.estimate` (`LevelEstimator`, or the interview / quick test while
    /// there is no history); a recent test result wins over an uncertain estimate.
    public static func baseLevel(_ state: LearnerState, now: Timestamp) -> String {
        let estimate = ProfileLevel.estimate(state)
        if estimate.confidence != .high,
           let last = state.assessmentHistory.max(by: { (a: AssessmentHistoryEntry, b: AssessmentHistoryEntry) -> Bool in a.at < b.at }),
           CEFR.isValid(last.level),
           now - last.at <= recentTestDays * TimeConstants.dayMs {
            return last.level
        }
        return CEFR.isValid(estimate.level) ? estimate.level : "A2"
    }

    /// The band of the test for the learner.
    public static func band(_ state: LearnerState, now: Timestamp) -> AssessmentBand {
        AssessmentBand(base: baseLevel(state, now: now))
    }

    // MARK: Topics

    /// Topic files to load for base words: topics the learner's words come from (most words
    /// first), topics of the study profile, then topics with the most entries in the band.
    public static func topicIDs(state: LearnerState, index: TopicIndex, band: AssessmentBand, limit: Int = topicLimit) -> [String] {
        let known = Set(index.topics.map { (summary: TopicSummary) -> String in summary.id })
        var ordered: [String] = []
        func add(_ id: String) {
            guard ordered.count < limit, known.contains(id), !ordered.contains(id) else { return }
            ordered.append(id)
        }
        for id in learnerTopicIDs(state) { add(id) }
        if let profile = state.settings.profile {
            let weights = profile.topicWeights()
            let sorted = weights.keys.sorted { (a: String, b: String) -> Bool in
                let wa = weights[a] ?? 0
                let wb = weights[b] ?? 0
                return wa != wb ? wa > wb : a < b
            }
            for id in sorted { add(id) }
        }
        let levels = [band.lower, band.base]
        let byBand = index.topics.sorted { (a: TopicSummary, b: TopicSummary) -> Bool in
            let ca = levels.reduce(0) { (sum: Int, level: String) -> Int in sum + (a.levels[level] ?? 0) }
            let cb = levels.reduce(0) { (sum: Int, level: String) -> Int in sum + (b.levels[level] ?? 0) }
            return ca != cb ? ca > cb : a.id < b.id
        }
        for summary in byBand { add(summary.id) }
        return ordered
    }

    /// Topics of the learner's own words (content references), most words first. Starter and core
    /// vocabulary shards are not topics.
    public static func learnerTopicIDs(_ state: LearnerState) -> [String] {
        var counts: [String: Int] = [:]
        for word in state.words where !word.archived {
            for meaning in word.meanings {
                guard let raw = meaning.contentRef, let reference = ContentReference(raw), !reference.isStarter, !reference.isCore else { continue }
                counts[reference.file, default: 0] += 1
            }
        }
        return counts.keys.sorted { (a: String, b: String) -> Bool in
            let ca = counts[a] ?? 0
            let cb = counts[b] ?? 0
            return ca != cb ? ca > cb : a < b
        }
    }

    /// Entries of a topic that may appear in the test: level in the band (or one above), frequent
    /// in spoken English, with at least one example. Also for a core vocabulary shard
    /// (`CoreVocabulary`): its categories are CEFR bands, not situations, so core words get no
    /// category nor scene (like `VocabularyMerger.addTopicEntries`).
    public static func bankEntries(topic: TopicFile, band: AssessmentBand, fromLearnerTopics: Bool) -> [AssessmentBankEntry] {
        let isCore = CoreVocabulary.isCore(topic)
        var result: [AssessmentBankEntry] = []
        for category in topic.categories {
            for entry in category.entries where isUsable(entry, band: band) {
                result.append(AssessmentBankEntry(
                    entry: entry,
                    reference: ContentReference(file: topic.id, entryID: entry.id).rawValue,
                    topicName: topic.namePl,
                    categoryName: isCore || category.namePl.isEmpty ? nil : category.namePl,
                    scene: isCore || category.scenePl.isEmpty ? nil : category.scenePl,
                    fromLearnerTopics: fromLearnerTopics
                ))
            }
        }
        return result
    }

    // MARK: Core vocabulary

    /// Core shards loaded for a test (each ~500 entries; three give hundreds of words per tier).
    public static let coreFileLimit = 3

    /// Core shards (`core-cNN`) to load for base words: those with the most frequent entries of the
    /// band's lower and upper tier according to the dictionary index (no shard is decoded for
    /// this), most first; shards without such entries are skipped. Without index records for the
    /// available shards: the first `limit` shards (they hold the most frequent words).
    public static func coreFileIDs(entries: [DictionaryIndex.Entry], band: AssessmentBand, available: [String], limit: Int = coreFileLimit) -> [String] {
        let files = available.filter { (id: String) -> Bool in CoreVocabulary.isCoreFile(id) }
        guard limit > 0, !files.isEmpty else { return [] }
        let known = Set(files)
        var counts: [String: Int] = [:]
        var indexed = Set<String>()
        for entry in entries {
            guard let reference = entry.contentReference, reference.isCore, known.contains(reference.file) else { continue }
            indexed.insert(reference.file)
            guard let tier = band.tier(of: entry.level), tier != .stretch,
                  let frequency = entry.spokenFrequency, frequency == .veryCommon || frequency == .common else { continue }
            counts[reference.file, default: 0] += 1
        }
        guard !indexed.isEmpty else { return Array(files.sorted().prefix(limit)) }
        let ranked = counts.keys.sorted { (a: String, b: String) -> Bool in
            let ca = counts[a] ?? 0
            let cb = counts[b] ?? 0
            return ca != cb ? ca > cb : a < b
        }
        return Array(ranked.prefix(limit))
    }

    static func isUsable(_ entry: TopicEntry, band: AssessmentBand) -> Bool {
        guard band.tier(of: entry.level) != nil else { return false }
        guard let frequency = entry.frequency, frequency == .veryCommon || frequency == .common else { return false }
        guard !TextScanning.trim(entry.term).isEmpty, !TextScanning.trim(entry.translation).isEmpty else { return false }
        return entry.examples.contains { (pair: ExamplePair) -> Bool in !TextScanning.trim(pair.en).isEmpty }
    }

    // MARK: Building

    /// A new test, or `nil` when fewer than `minimumQuestions` questions can be built.
    public static func make<G: RandomNumberGenerator>(
        state: LearnerState,
        content: AssessmentContent,
        now: Timestamp,
        id: String,
        using rng: inout G
    ) -> AssessmentSession? {
        let testBand = band(state, now: now)
        let owned = ownedCandidates(state, band: testBand, using: &rng)
        let bank = bankCandidates(content.bankEntries, band: testBand, owned: OwnedVocabulary(state), using: &rng)
        let grammar = grammarQuestions(state, pool: content.grammarPool, now: now, using: &rng)
        let reading = testReading(state, bank: content.readings, band: testBand)
        var session = AssessmentSession(
            id: id,
            band: testBand,
            startedAt: now,
            slots: [],
            candidates: owned + bank.candidates,
            bankWords: bank.words,
            grammar: grammar,
            reading: reading
        )
        let working = AssessmentEngine.workingState(state, session: session)
        session.slots = plannedSlots(session, working: working)
        guard session.slots.count >= minimumQuestions else { return nil }
        session = AssessmentEngine.prepareCurrent(session, state: state)
        guard !session.isFinished, session.slots.count >= minimumQuestions else { return nil }
        return session
    }

    /// Own meanings of the band with a usable example: practiced ones (shuffled) before new ones.
    static func ownedCandidates<G: RandomNumberGenerator>(_ state: LearnerState, band: AssessmentBand, using rng: inout G) -> [AssessmentCandidate] {
        var practiced: [AssessmentCandidate] = []
        var fresh: [AssessmentCandidate] = []
        for word in state.words where !word.archived && !word.id.hasPrefix(bankPrefix) {
            for meaning in word.meanings where ExamplePool.availableCount(meaning) > 0 {
                let level = meaning.effectiveLevel(in: word)
                guard band.tier(of: level) != nil else { continue }
                let candidate = AssessmentCandidate(wordId: word.id, meaningId: meaning.id, level: level, owned: true, contentRef: meaning.contentRef)
                if meaning.scores.isEmpty {
                    fresh.append(candidate)
                } else {
                    practiced.append(candidate)
                }
            }
        }
        let first = AssessmentBuilder.randomOrder(practiced, using: &rng)
        let second = AssessmentBuilder.randomOrder(fresh, using: &rng)
        let ordered = first + second
        return Array(ordered.prefix(maxOwnedCandidates))
    }

    /// Frequent base words of the band the learner does not have (learner topics first), at most
    /// `maxBankPerTier` per tier, converted to test words.
    static func bankCandidates<G: RandomNumberGenerator>(_ entries: [AssessmentBankEntry], band: AssessmentBand, owned: OwnedVocabulary, using rng: inout G) -> (candidates: [AssessmentCandidate], words: [Word]) {
        var seenReferences = Set<String>()
        var seenTerms = Set<String>()
        var mine: [AssessmentBankEntry] = []
        var others: [AssessmentBankEntry] = []
        for item in entries where isUsable(item.entry, band: band) {
            let termKey = OwnedVocabulary.termKey(item.entry.term)
            guard !owned.contains(reference: item.reference, term: item.entry.term, translation: item.entry.translation),
                  !owned.containsTerm(item.entry.term),
                  seenReferences.insert(item.reference).inserted,
                  seenTerms.insert(termKey).inserted else { continue }
            if item.fromLearnerTopics {
                mine.append(item)
            } else {
                others.append(item)
            }
        }
        let first = AssessmentBuilder.randomOrder(mine, using: &rng)
        let second = AssessmentBuilder.randomOrder(others, using: &rng)
        let ordered = first + second
        var perTier: [AssessmentTier: Int] = [:]
        var candidates: [AssessmentCandidate] = []
        var words: [Word] = []
        for item in ordered {
            guard let tier = band.tier(of: item.entry.level) else { continue }
            let limit = tier == .stretch ? maxBankStretch : maxBankPerTier
            guard (perTier[tier] ?? 0) < limit else { continue }
            perTier[tier, default: 0] += 1
            let word = bankWord(item)
            words.append(word)
            candidates.append(AssessmentCandidate(wordId: word.id, meaningId: word.id, level: item.entry.level, owned: false, contentRef: item.reference))
        }
        return (candidates, words)
    }

    /// A base entry as a temporary word of the test (id `test:<reference>`; one meaning with the
    /// same id). Never written to the vocabulary.
    public static func bankWord(_ item: AssessmentBankEntry) -> Word {
        var entry = item.entry
        entry.examples = Array(entry.examples.prefix(maxBankExamples))
        let id = bankPrefix + item.reference
        let meaning = Meaning(
            id: id,
            topic: item.categoryName,
            scene: item.scene,
            exampleTranslations: entry.examples.map { (pair: ExamplePair) -> String in pair.pl },
            exampleFocusEn: entry.examples.map { (pair: ExamplePair) -> String in pair.focusEn },
            exampleFocusPl: entry.examples.map { (pair: ExamplePair) -> String in pair.focusPl },
            acceptedAnswers: entry.acceptedAnswers,
            acceptedTranslations: entry.acceptedTranslations,
            level: entry.level,
            spokenFrequency: entry.frequency,
            pos: entry.pos.isEmpty ? nil : entry.pos,
            translation: TextNormalizer.withoutDialectLabel(entry.translation),
            definition: entry.definition,
            examples: entry.examples.map { (pair: ExamplePair) -> String in pair.en },
            context: entry.contextPl,
            register: entry.register,
            natural: entry.natural,
            contentRef: item.reference
        )
        return Word(
            id: id,
            en: entry.term,
            ipa: entry.ipa,
            pos: entry.pos,
            level: entry.level,
            collection: item.topicName,
            source: "Baza FluentNOW",
            note: entry.notePl,
            forms: entry.forms,
            collocations: entry.collocations,
            synonyms: entry.synonyms,
            antonyms: entry.antonyms,
            created: 0,
            meanings: [meaning]
        )
    }

    /// `true` for word / meaning ids of base words inside a test.
    public static func isBankID(_ id: String) -> Bool {
        id.hasPrefix(bankPrefix)
    }

    /// Grammar questions of the base level: unseen bank tasks first (`GrammarSelector`), multiple
    /// choice with shuffled options and without the construction name (it would give the answer away).
    static func grammarQuestions<G: RandomNumberGenerator>(_ state: LearnerState, pool: [ProductionItem], now: Timestamp, using rng: inout G) -> [PracticeQuestion] {
        guard !pool.isEmpty else { return [] }
        let variant = rng.nextIndex(below: 1000)
        let items = GrammarSelector.selectItems(pool, count: AssessmentBlock.grammar.plannedCount, seen: GrammarSelector.selectionSeen(state, now: now), variant: variant)
        var questions: [PracticeQuestion] = []
        for item in items {
            var question = PracticeBuilder.practiceQuestion(from: item)
            question.format = .choice
            question.prompt = "Wybierz formę, która pasuje do kontekstu."
            questions.append(AssessmentBuilder.shuffledOptions(question, using: &rng))
        }
        return questions
    }

    /// Options in random order (the key follows its option).
    static func shuffledOptions<G: RandomNumberGenerator>(_ question: PracticeQuestion, using rng: inout G) -> PracticeQuestion {
        guard question.options.count > 1, question.answer >= 0, question.answer < question.options.count else { return question }
        let order = AssessmentBuilder.randomOrder(Array(question.options.indices), using: &rng)
        var copy = question
        copy.options = order.map { (index: Int) -> String in question.options[index] }
        copy.answer = order.firstIndex(of: question.answer) ?? 0
        return copy
    }

    /// A bank reading of the base level not used recently (readings of earlier tests count as
    /// read), with at most `AssessmentBlock.reading.plannedCount` questions.
    static func testReading(_ state: LearnerState, bank: ReadingBank, band: AssessmentBand) -> Reading? {
        guard !bank.readings.isEmpty else { return nil }
        var history = state.readingHistory
        for entry in state.assessmentHistory {
            guard let readingId = entry.readingId, !readingId.isEmpty else { continue }
            history.append(ReadingHistoryEntry(id: readingId, at: entry.at, level: entry.baseLevel, correct: 0, total: 0))
        }
        guard var reading = ReadingSelector.selectBankReading(level: band.base, history: history, bank: bank),
              !reading.questions.isEmpty else { return nil }
        reading.questions = Array(reading.questions.prefix(AssessmentBlock.reading.plannedCount))
        return reading
    }

    /// Planned blocks in the fixed order; a vocabulary block gets at most as many questions as
    /// there are meanings that can carry its exercise.
    static func plannedSlots(_ session: AssessmentSession, working: LearnerState) -> [AssessmentBlock] {
        let listeningReady = ListeningChoice.hasDistractorPool(working)
        var slots: [AssessmentBlock] = []
        for block in AssessmentBlock.allCases {
            let available: Int
            switch block {
            case .grammar:
                available = session.grammar.count
            case .reading:
                available = session.reading?.questions.count ?? 0
            case .matchPairs:
                available = pairableCount(session, working: working) >= MatchPairsExercise.minimumPairs ? 1 : 0
            case .meaning, .recall, .cloze, .scramble, .listening, .dictation:
                available = buildableCount(block, session: session, working: working, listeningReady: listeningReady, limit: block.plannedCount)
            }
            let count = min(block.plannedCount, available)
            if count > 0 {
                slots.append(contentsOf: Array(repeating: block, count: count))
            }
        }
        return slots
    }

    static func buildableCount(_ block: AssessmentBlock, session: AssessmentSession, working: LearnerState, listeningReady: Bool, limit: Int) -> Int {
        guard let type = block.exerciseType else { return 0 }
        var count = 0
        for candidate in session.candidates {
            guard let word = working.word(id: candidate.wordId), let meaning = word.meaning(id: candidate.meaningId) else { continue }
            let preferred = ExamplePool.nextUnusedExample(meaning, fallback: 0)
            if SingleTypeSession.buildableExample(type, word: word, meaning: meaning, preferred: preferred, listeningReady: listeningReady) != nil {
                count += 1
                if count >= limit { break }
            }
        }
        return count
    }

    static func pairableCount(_ session: AssessmentSession, working: LearnerState) -> Int {
        var members: [WordMeaning] = []
        for candidate in session.candidates {
            guard let word = working.word(id: candidate.wordId), let meaning = word.meaning(id: candidate.meaningId) else { continue }
            let item = WordMeaning(word: word, meaning: meaning)
            guard MatchPairsExercise.canJoinBoard(item),
                  members.allSatisfy({ (other: WordMeaning) -> Bool in MatchPairsExercise.areDistinct(other, item) }) else { continue }
            members.append(item)
            if members.count >= MatchPairsExercise.pairCount { break }
        }
        return members.count
    }

    /// Fisher–Yates with the injected generator.
    static func randomOrder<T, G: RandomNumberGenerator>(_ items: [T], using rng: inout G) -> [T] {
        var result = items
        var index = result.count - 1
        while index > 0 {
            result.swapAt(index, rng.nextIndex(below: index + 1))
            index -= 1
        }
        return result
    }
}
