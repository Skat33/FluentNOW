import Foundation

/// Result of adding suggested meanings to the learner's vocabulary.
public struct MergeResult: Sendable, Hashable {
    public var state: LearnerState
    /// Ids of newly created meanings.
    public var addedMeaningIDs: [String]
    /// Number of selected meanings skipped because the learner already has them (progress kept).
    public var skippedExisting: Int

    public init(state: LearnerState, addedMeaningIDs: [String], skippedExisting: Int) {
        self.state = state
        self.addedMeaningIDs = addedMeaningIDs
        self.skippedExisting = skippedExisting
    }
}

/// Adding words from lookups and built-in content (tutor-local.ts `mergeSuggestions`,
/// `resolveExistingCollection`) plus conversions of content entries.
public enum VocabularyMerger {
    /// Default collection when nothing else is known.
    public static let defaultCollection = "Codzienne rozmowy"

    // MARK: Collections

    private static func collectionCore(_ value: String) -> String {
        var core = TextScanning.foldPolish(TextNormalizer.normalize(value))
        for prefix in ["w ", "we ", "na ", "do ", "o ", "u ", "z ", "ze ", "dla "] where core.hasPrefix(prefix) {
            core = String(core.dropFirst(prefix.count))
            break
        }
        let filtered = core.filter { c in
            (c.isASCII && (c.isLetter || c.isNumber)) || c == " "
        }
        return TextScanning.trim(String(filtered))
    }

    private static func sameCollectionSubject(_ left: String, _ right: String) -> Bool {
        let a = collectionCore(left)
        let b = collectionCore(right)
        if a.isEmpty || b.isEmpty { return false }
        if a == b { return true }
        let longest = max(a.count, b.count)
        if min(a.count, b.count) < 5 { return false }
        return TextNormalizer.levenshtein(a, b) <= max(1, Int(Double(longest) * 0.18))
    }

    /// An existing collection about the same subject („Restauracja” → „W restauracji”), or `nil`.
    public static func resolveExistingCollection(_ collections: [String], suggested: String, topic: String? = nil) -> String? {
        let targets = [suggested, topic ?? ""].filter { !TextScanning.trim($0).isEmpty }
        return collections.first { collection in
            targets.contains { sameCollectionSubject(collection, $0) }
        }
    }

    // MARK: Merge

    /// `mergeSuggestions`: adds the selected senses of a lookup. A sense the learner already has
    /// (same term and translation in a non-archived word) is skipped, so progress is never reset.
    /// Built-in content meanings are created **without** `enrichment` (all examples usable offline).
    public static func mergeSuggestions(
        _ state: LearnerState,
        lookup: Lookup,
        indices: [Int],
        collectionOverride: String? = nil,
        now: Timestamp,
        makeID: () -> String = { UUID().uuidString.lowercased() }
    ) -> MergeResult {
        var next = state
        var added: [String] = []
        var skipped = 0
        let termKey = TextNormalizer.normalize(lookup.term)
        let chosen: [SenseSuggestion] = indices.compactMap { lookup.meanings[safe: $0] }.map { (suggestion: SenseSuggestion) -> SenseSuggestion in
            var copy = suggestion
            copy.translation = TextNormalizer.withoutDialectLabel(suggestion.translation)
            return copy
        }
        for sense in chosen {
            let translationKey = TextNormalizer.normalize(sense.translation)
            let alreadyKnown = next.words.contains { word in
                !word.archived && TextNormalizer.normalize(word.en) == termKey
                    && word.meanings.contains { TextNormalizer.normalize($0.translation) == translationKey }
            }
            if alreadyKnown {
                skipped += 1
                continue
            }
            var collection: String
            if let override = collectionOverride.map(TextScanning.trim), !override.isEmpty {
                collection = next.collections.first { TextNormalizer.normalize($0) == TextNormalizer.normalize(override) } ?? override
            } else {
                collection = resolveExistingCollection(next.collections, suggested: sense.collection, topic: sense.topic) ?? sense.collection
            }
            if TextScanning.trim(collection).isEmpty { collection = defaultCollection }
            if !next.collections.contains(collection) { next.collections.append(collection) }

            var wordIndex = next.words.firstIndex { word in
                !word.archived && TextNormalizer.normalize(word.en) == termKey && word.collection == collection
            }
            if wordIndex == nil {
                let word = Word(
                    id: makeID(),
                    en: lookup.term,
                    ipa: lookup.ipa,
                    pos: sense.pos,
                    level: sense.level,
                    collection: collection,
                    tags: [],
                    source: lookup.source == .ai ? "Asystent AI — propozycje do weryfikacji" : "Baza FluentNOW",
                    note: lookup.note,
                    forms: lookup.forms,
                    collocations: lookup.collocations,
                    synonyms: lookup.synonyms,
                    antonyms: lookup.antonyms,
                    created: now,
                    updatedAt: now,
                    meanings: []
                )
                next.words.insert(word, at: 0)
                wordIndex = 0
            }
            guard let index = wordIndex else { continue }
            if next.words[index].meanings.contains(where: { TextNormalizer.normalize($0.translation) == translationKey }) {
                skipped += 1
                continue
            }
            let meaningID = makeID()
            let meaning = Meaning(
                id: meaningID,
                topic: sense.topic,
                scene: sense.scene,
                exampleTranslations: sense.examples.map { $0.pl },
                exampleFocusEn: sense.examples.map { $0.focusEn },
                exampleFocusPl: sense.examples.map { $0.focusPl },
                acceptedAnswers: sense.acceptedAnswers,
                acceptedTranslations: sense.acceptedTranslations,
                level: sense.level.isEmpty ? nil : sense.level,
                levelConfidence: sense.levelConfidence,
                levelReason: sense.levelReason,
                spokenFrequency: sense.spokenFrequency,
                pos: sense.pos.isEmpty ? nil : sense.pos,
                translation: sense.translation,
                definition: sense.definition,
                examples: sense.examples.map { $0.en },
                context: sense.context,
                register: sense.register,
                natural: sense.natural,
                scores: SkillScores(),
                contentRef: sense.contentRef
            )
            next.words[index].meanings.append(meaning)
            next.words[index].updatedAt = now
            added.append(meaningID)
        }
        return MergeResult(state: next, addedMeaningIDs: added, skippedExisting: skipped)
    }

    // MARK: Content conversions

    /// A built-in entry as a sense suggestion. `collection` = topic name, `topic` = category name,
    /// `scene` = category scene.
    public static func suggestion(from entry: TopicEntry, topicName: String, categoryName: String? = nil, scene: String? = nil, reference: String? = nil) -> SenseSuggestion {
        SenseSuggestion(
            topic: categoryName,
            scene: scene,
            translation: entry.translation,
            definition: entry.definition,
            pos: entry.pos,
            level: entry.level,
            spokenFrequency: entry.frequency,
            context: entry.contextPl,
            register: entry.register,
            natural: entry.natural,
            collection: topicName,
            examples: entry.examples,
            acceptedTranslations: entry.acceptedTranslations,
            acceptedAnswers: entry.acceptedAnswers,
            contentRef: reference
        )
    }

    /// A lookup made of one or more entries of the same term (several senses).
    public static func lookup(term: String, entries: [(entry: TopicEntry, suggestion: SenseSuggestion)]) -> Lookup {
        let first = entries.first?.entry
        return Lookup(
            exists: !entries.isEmpty,
            term: first?.term ?? term,
            ipa: first?.ipa ?? "",
            forms: first?.forms ?? "",
            collocations: first?.collocations ?? "",
            synonyms: first?.synonyms ?? "",
            antonyms: first?.antonyms ?? "",
            note: first?.notePl ?? "",
            alternatives: [],
            meanings: entries.map { $0.suggestion },
            source: .starter
        )
    }

    /// Adds built-in topic entries (e.g. a whole topic or category) to the vocabulary.
    /// Entries of the same term become meanings of one word. Existing senses keep their progress.
    public static func addTopicEntries(
        _ state: LearnerState,
        topic: TopicFile,
        entryIDs: [String]? = nil,
        collectionOverride: String? = nil,
        now: Timestamp,
        makeID: () -> String = { UUID().uuidString.lowercased() }
    ) -> MergeResult {
        let wanted = entryIDs.map { Set($0) }
        var groups: [String: [(entry: TopicEntry, suggestion: SenseSuggestion)]] = [:]
        var order: [String] = []
        // Core vocabulary (CoreVocabulary): categories are CEFR bands, not situations — no topic/scene.
        let isCore = CoreVocabulary.isCore(topic)
        for category in topic.categories {
            for entry in category.entries where wanted?.contains(entry.id) ?? true {
                let key = TextNormalizer.normalize(entry.term)
                let sense = Self.suggestion(
                    from: entry,
                    topicName: topic.namePl,
                    categoryName: isCore ? nil : category.namePl,
                    scene: isCore || category.scenePl.isEmpty ? nil : category.scenePl,
                    reference: ContentReference(file: topic.id, entryID: entry.id).rawValue
                )
                if groups[key] == nil { order.append(key) }
                groups[key, default: []].append((entry, sense))
            }
        }
        var result = MergeResult(state: state, addedMeaningIDs: [], skippedExisting: 0)
        // Insert in reverse so the first entry of the topic ends up first in the word list.
        for key in order.reversed() {
            guard let items = groups[key], let first = items.first else { continue }
            let combinedLookup = Self.lookup(term: first.entry.term, entries: items)
            let merged = mergeSuggestions(
                result.state,
                lookup: combinedLookup,
                indices: Array(items.indices),
                collectionOverride: collectionOverride ?? topic.namePl,
                now: now,
                makeID: makeID
            )
            result.state = merged.state
            result.addedMeaningIDs.append(contentsOf: merged.addedMeaningIDs)
            result.skippedExisting += merged.skippedExisting
        }
        return result
    }

    /// Converts starter entries to `Word`s (used as a distractor pool for `MeaningOptions`).
    public static func starterWords(_ entries: [TopicEntry]) -> [Word] {
        entries.map { entry in
            Word(
                id: entry.id,
                en: entry.term,
                ipa: entry.ipa,
                pos: entry.pos,
                level: entry.level,
                collection: entry.contextPl,
                source: "Baza FluentNOW",
                note: entry.notePl,
                forms: entry.forms,
                collocations: entry.collocations,
                synonyms: entry.synonyms,
                antonyms: entry.antonyms,
                created: 0,
                meanings: [Meaning(
                    id: entry.id,
                    exampleTranslations: entry.examples.map { $0.pl },
                    exampleFocusEn: entry.examples.map { $0.focusEn },
                    exampleFocusPl: entry.examples.map { $0.focusPl },
                    acceptedAnswers: entry.acceptedAnswers,
                    acceptedTranslations: entry.acceptedTranslations,
                    level: entry.level,
                    spokenFrequency: entry.frequency,
                    pos: entry.pos,
                    translation: entry.translation,
                    definition: entry.definition,
                    examples: entry.examples.map { $0.en },
                    context: entry.contextPl,
                    register: entry.register,
                    natural: entry.natural,
                    contentRef: "starter/\(entry.id)"
                )]
            )
        }
    }

    /// Meaning ids already in the vocabulary for each content reference (for „dodane” marks).
    public static func addedContentReferences(_ state: LearnerState) -> Set<String> {
        var result = Set<String>()
        for word in state.words where !word.archived {
            for meaning in word.meanings {
                if let reference = meaning.contentRef { result.insert(reference) }
            }
        }
        return result
    }
}
