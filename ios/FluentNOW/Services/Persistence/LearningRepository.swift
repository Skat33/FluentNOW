import Foundation
import SwiftData
import os
import FluentKit

/// Ustawienia + kolekcje + flaga demo w jednym rekordzie.
struct SettingsPayload: Codable, Equatable {
    var settings: LearnerSettings
    var collections: [String]
    var demo: Bool
}

/// Mapowanie encji SwiftData ↔ `LearnerState` w tle (`ModelActor`).
///
/// - wczytanie: dekodowanie rekordów, pominięcie uszkodzonych (log, nigdy crash), scalenie duplikatów
///   (`StateSync.mergeDuplicateWords`), migracja i kompaktowanie recenzji,
/// - zapis przyrostowy: porównanie z ostatnio zapisaną wersją (cache), zapis tylko zmian,
///   partiami po `batchSize`; po błędzie cache jest odbudowywany z magazynu (nic nie ginie).
@ModelActor
actor LearningRepository {
    private var wordRecords: [String: WordRecord] = [:]
    private var savedWords: [String: Word] = [:]
    private var reviewRecords: [String: ReviewRecord] = [:]
    private var historyRecords: [String: HistoryRecord] = [:]
    private var historyPayloads: [String: Data] = [:]
    private var sessionRecords: [String: SessionRecord] = [:]
    private var sessionPayloads: [String: Data] = [:]
    private var settingsRecord: SettingsRecord?
    private var settingsPayload: Data?

    static let batchSize = 400
    private static let log = Logger(subsystem: "pl.fluentnow.app", category: "LearningRepository")

    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    // MARK: - Wczytanie

    /// Identyfikatory słów obecnych w magazynie (także nieczytelnych rekordów).
    func knownWordIDs() -> Set<String> {
        Set(wordRecords.keys)
    }

    func load(now: Timestamp) throws -> PersistenceLoadResult {
        let snapshot = try fetchAll()
        // Zapis scalonych duplikatów (usunięcie nadmiarowych rekordów) od razu.
        if modelContext.hasChanges {
            try modelContext.save()
        }
        let migrated = StateMigration.migrate(snapshot.state)
        let compacted = StateSync.compactReviews(migrated, now: now)
        return PersistenceLoadResult(
            state: compacted,
            skippedRecords: snapshot.skipped,
            mergedDuplicates: snapshot.duplicates
        )
    }

    private struct Snapshot {
        var state: LearnerState
        var skipped: Int
        var duplicates: Int
    }

    /// Pobiera wszystkie rekordy, wypełnia cache i składa „surowy” stan.
    private func fetchAll() throws -> Snapshot {
        resetCache()
        let decoder = JSONDecoder()
        var skipped = 0
        var duplicates = 0

        // Słowa
        let wordRows = try modelContext.fetch(FetchDescriptor<WordRecord>())
        var grouped: [String: [WordRecord]] = [:]
        for row in wordRows {
            grouped[row.wordId, default: []].append(row)
        }
        var orderedWords: [(word: Word, created: Double, position: Int)] = []
        for (wordID, rows) in grouped {
            var decoded: [(record: WordRecord, word: Word)] = []
            for row in rows {
                if let word = try? decoder.decode(Word.self, from: row.payload), word.id == wordID {
                    decoded.append((row, word))
                } else {
                    skipped += 1
                    Self.log.error("Skipping unreadable word record \(wordID, privacy: .public)")
                }
            }
            guard let first = decoded.first else {
                // Wszystkie kopie nieczytelne: rekord zostaje w magazynie (nie kasujemy danych), ale go nie śledzimy.
                continue
            }
            var word = first.word
            if decoded.count > 1 {
                duplicates += decoded.count - 1
                word = StateSync.mergeDuplicateWords(decoded.map { $0.word }).first ?? first.word
                for extra in decoded.dropFirst() {
                    modelContext.delete(extra.record)
                }
            }
            wordRecords[wordID] = first.record
            // Cache = zawartość zachowanego rekordu, więc scalona wersja zostanie zapisana przy najbliższym zapisie.
            savedWords[wordID] = first.word
            orderedWords.append((word, first.record.created, first.record.position))
        }
        orderedWords.sort { lhs, rhs in
            if lhs.created != rhs.created { return lhs.created > rhs.created }
            if lhs.position != rhs.position { return lhs.position < rhs.position }
            return lhs.word.id < rhs.word.id
        }

        // Recenzje
        var reviews: [Review] = []
        for row in try modelContext.fetch(FetchDescriptor<ReviewRecord>()) {
            if reviewRecords[row.reviewId] != nil {
                duplicates += 1
                modelContext.delete(row)
                continue
            }
            guard let review = try? decoder.decode(Review.self, from: row.payload) else {
                skipped += 1
                continue
            }
            reviewRecords[row.reviewId] = row
            reviews.append(review)
        }
        reviews.sort { $0.at < $1.at }

        // Historie
        var readingHistory: [ReadingHistoryEntry] = []
        var practiceHistory: [PracticeHistoryEntry] = []
        var productionHistory: [ProductionHistoryEntry] = []
        var summaries: [String: ReviewSummary] = [:]
        var grammarSeen: [String: Double] = [:]
        for row in try modelContext.fetch(FetchDescriptor<HistoryRecord>()) {
            let key = Self.historyKey(row.kind, row.entryId)
            let isDuplicate = historyRecords[key] != nil
            var readable = true
            switch HistoryKind(rawValue: row.kind) {
            case .reading:
                if let entry = try? decoder.decode(ReadingHistoryEntry.self, from: row.payload) {
                    if !isDuplicate { readingHistory.append(entry) }
                } else { readable = false }
            case .practice:
                if let entry = try? decoder.decode(PracticeHistoryEntry.self, from: row.payload) {
                    if !isDuplicate { practiceHistory.append(entry) }
                } else { readable = false }
            case .production:
                if let entry = try? decoder.decode(ProductionHistoryEntry.self, from: row.payload) {
                    if !isDuplicate { productionHistory.append(entry) }
                } else { readable = false }
            case .summary:
                if let entry = try? decoder.decode(ReviewSummary.self, from: row.payload) {
                    let saved = summaries[entry.day]
                    summaries[entry.day] = ReviewSummary(
                        day: entry.day,
                        count: max(entry.count, saved?.count ?? 0),
                        correct: max(entry.correct, saved?.correct ?? 0)
                    )
                } else { readable = false }
            case .grammarSeen:
                if let entry = try? decoder.decode([String: Double].self, from: row.payload) {
                    for (task, time) in entry {
                        grammarSeen[task] = max(grammarSeen[task] ?? 0, time)
                    }
                } else { readable = false }
            case nil:
                readable = false
            }
            if !readable {
                skipped += 1
                continue
            }
            if isDuplicate {
                duplicates += 1
                modelContext.delete(row)
                // Payload zachowanego rekordu nie odpowiada już scaleniu — wymuś przepisanie.
                historyPayloads[key] = Data()
                continue
            }
            historyRecords[key] = row
            historyPayloads[key] = row.payload
        }

        // Sesje
        var sessionData: [SessionKind: Data] = [:]
        for row in try modelContext.fetch(FetchDescriptor<SessionRecord>()) {
            guard let kind = SessionKind(rawValue: row.kind) else { continue }
            if let existing = sessionRecords[row.kind] {
                duplicates += 1
                if existing.updatedAt >= row.updatedAt {
                    modelContext.delete(row)
                    continue
                }
                modelContext.delete(existing)
            }
            sessionRecords[row.kind] = row
            sessionPayloads[row.kind] = row.payload ?? Data()
            if let payload = row.payload {
                sessionData[kind] = payload
            } else {
                sessionData[kind] = nil
            }
        }

        // Ustawienia
        var settingsValue = SettingsPayload(settings: LearnerSettings(), collections: [], demo: false)
        var collections: [String] = []
        for row in try modelContext.fetch(FetchDescriptor<SettingsRecord>()) {
            guard let payload = try? decoder.decode(SettingsPayload.self, from: row.payload) else {
                skipped += 1
                continue
            }
            collections.append(contentsOf: payload.collections)
            if let existing = settingsRecord {
                duplicates += 1
                if existing.updatedAt >= row.updatedAt {
                    modelContext.delete(row)
                    continue
                }
                modelContext.delete(existing)
            }
            settingsRecord = row
            settingsPayload = row.payload
            settingsValue = payload
        }
        var uniqueCollections: [String] = []
        for name in settingsValue.collections + collections where !uniqueCollections.contains(name) {
            uniqueCollections.append(name)
        }
        if uniqueCollections != settingsValue.collections {
            settingsPayload = Data()   // wymuś zapis scalonej listy kolekcji
        }

        let combined = decode(CombinedSession.self, sessionData[.combined], decoder, &skipped)
        let vocabulary = decode(VocabSession.self, sessionData[.vocabulary], decoder, &skipped)
        let reading = decode(ReadingSession.self, sessionData[.reading], decoder, &skipped)
        let practice = decode(PracticeSession.self, sessionData[.practice], decoder, &skipped)
        let production = decode(ProductionSession.self, sessionData[.production], decoder, &skipped)
        let state = LearnerState(
            combined: combined,
            grammarSeen: grammarSeen,
            words: orderedWords.map { $0.word },
            collections: uniqueCollections,
            reviews: reviews,
            reviewSummaries: summaries.values.sorted { $0.day < $1.day },
            settings: settingsValue.settings,
            session: vocabulary,
            reading: reading,
            readingHistory: readingHistory.sorted { $0.at < $1.at },
            practice: practice,
            production: production,
            productionHistory: productionHistory.sorted { $0.at < $1.at },
            practiceHistory: practiceHistory.sorted { $0.at < $1.at },
            demo: settingsValue.demo
        )
        return Snapshot(state: state, skipped: skipped, duplicates: duplicates)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data?, _ decoder: JSONDecoder, _ skipped: inout Int) -> T? {
        guard let data, !data.isEmpty else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            skipped += 1
            return nil
        }
    }

    private func resetCache() {
        wordRecords = [:]
        savedWords = [:]
        reviewRecords = [:]
        historyRecords = [:]
        historyPayloads = [:]
        sessionRecords = [:]
        sessionPayloads = [:]
        settingsRecord = nil
        settingsPayload = nil
    }

    // MARK: - Zapis

    /// Zapis przyrostowy. Po błędzie: wycofanie kontekstu i odbudowa cache z magazynu,
    /// tak by ponowienie zapisało wszystkie niezapisane zmiany.
    func save(_ state: LearnerState) throws {
        do {
            try applyChanges(state)
        } catch {
            modelContext.rollback()
            Self.log.error("Save failed, rebuilding cache: \(error.localizedDescription, privacy: .public)")
            _ = try? fetchAll()
            throw PersistenceError.saveFailed(error.localizedDescription)
        }
    }

    private func applyChanges(_ state: LearnerState) throws {
        let encoder = makeEncoder()
        var pending = 0
        func tick() throws {
            pending += 1
            if pending >= Self.batchSize {
                try modelContext.save()
                pending = 0
            }
        }

        // Słowa
        var present = Set<String>()
        for (index, word) in state.words.enumerated() {
            guard present.insert(word.id).inserted else { continue }
            if let saved = savedWords[word.id], saved == word { continue }
            let payload = try encoder.encode(word)
            let updated = word.updatedAt ?? word.created
            if let record = wordRecords[word.id] {
                record.en = word.en
                record.collection = word.collection
                record.archived = word.archived
                record.created = word.created
                record.updatedAt = updated
                record.payload = payload
            } else {
                let record = WordRecord(
                    wordId: word.id,
                    en: word.en,
                    collection: word.collection,
                    archived: word.archived,
                    created: word.created,
                    position: index,
                    updatedAt: updated,
                    payload: payload
                )
                modelContext.insert(record)
                wordRecords[word.id] = record
            }
            savedWords[word.id] = word
            try tick()
        }
        for (wordID, record) in wordRecords where !present.contains(wordID) {
            modelContext.delete(record)
            wordRecords[wordID] = nil
            savedWords[wordID] = nil
            try tick()
        }

        // Recenzje (dopisywane; usuwane po kompaktowaniu)
        var reviewIDs = Set<String>()
        for review in state.reviews {
            reviewIDs.insert(review.id)
            guard reviewRecords[review.id] == nil else { continue }
            let record = ReviewRecord(
                reviewId: review.id,
                wordId: review.wordId,
                meaningId: review.meaningId,
                at: review.at,
                payload: try encoder.encode(review)
            )
            modelContext.insert(record)
            reviewRecords[review.id] = record
            try tick()
        }
        for (reviewID, record) in reviewRecords where !reviewIDs.contains(reviewID) {
            modelContext.delete(record)
            reviewRecords[reviewID] = nil
            try tick()
        }

        // Historie
        var historyKeys = Set<String>()
        func upsertHistory(kind: HistoryKind, entryID: String, at: Timestamp, payload: Data) throws {
            let key = Self.historyKey(kind.rawValue, entryID)
            historyKeys.insert(key)
            if historyPayloads[key] == payload { return }
            if let record = historyRecords[key] {
                record.at = at
                record.payload = payload
            } else {
                let record = HistoryRecord(kind: kind.rawValue, entryId: entryID, at: at, payload: payload)
                modelContext.insert(record)
                historyRecords[key] = record
            }
            historyPayloads[key] = payload
            try tick()
        }
        for entry in state.readingHistory {
            try upsertHistory(kind: .reading, entryID: entry.id, at: entry.at, payload: try encoder.encode(entry))
        }
        for entry in state.practiceHistory {
            try upsertHistory(kind: .practice, entryID: entry.id, at: entry.at, payload: try encoder.encode(entry))
        }
        for entry in state.productionHistory {
            try upsertHistory(kind: .production, entryID: entry.id, at: entry.at, payload: try encoder.encode(entry))
        }
        for summary in state.reviewSummaries {
            try upsertHistory(kind: .summary, entryID: summary.day, at: 0, payload: try encoder.encode(summary))
        }
        if !state.grammarSeen.isEmpty {
            try upsertHistory(kind: .grammarSeen, entryID: "all", at: 0, payload: try encoder.encode(state.grammarSeen))
        }
        for (key, record) in historyRecords where !historyKeys.contains(key) {
            modelContext.delete(record)
            historyRecords[key] = nil
            historyPayloads[key] = nil
            try tick()
        }

        // Sesje
        let now = Date().timeIntervalSince1970 * 1000
        try upsertSession(.vocabulary, state.session.map { try encoder.encode($0) }, now: now)
        try upsertSession(.combined, state.combined.map { try encoder.encode($0) }, now: now)
        try upsertSession(.reading, state.reading.map { try encoder.encode($0) }, now: now)
        try upsertSession(.practice, state.practice.map { try encoder.encode($0) }, now: now)
        try upsertSession(.production, state.production.map { try encoder.encode($0) }, now: now)

        // Ustawienia
        let settings = try encoder.encode(SettingsPayload(settings: state.settings, collections: state.collections, demo: state.demo))
        if settingsPayload != settings {
            if let record = settingsRecord {
                record.payload = settings
                record.updatedAt = now
            } else {
                let record = SettingsRecord(updatedAt: now, payload: settings)
                modelContext.insert(record)
                settingsRecord = record
            }
            settingsPayload = settings
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    private func upsertSession(_ kind: SessionKind, _ payload: Data?, now: Double) throws {
        let comparable = payload ?? Data()
        if let saved = sessionPayloads[kind.rawValue], saved == comparable { return }
        if sessionPayloads[kind.rawValue] == nil, payload == nil { return }   // brak sesji i brak rekordu
        if let record = sessionRecords[kind.rawValue] {
            record.payload = payload
            record.updatedAt = now
        } else {
            let record = SessionRecord(kind: kind.rawValue, updatedAt: now, payload: payload)
            modelContext.insert(record)
            sessionRecords[kind.rawValue] = record
        }
        sessionPayloads[kind.rawValue] = comparable
    }

    // MARK: - Usuwanie

    /// Usuwa wszystkie rekordy pojedynczo (usunięcia synchronizują się z iCloud — operacje wsadowe nie).
    func deleteAll() throws {
        var count = 0
        func remove<T: PersistentModel>(_ type: T.Type) throws {
            for row in try modelContext.fetch(FetchDescriptor<T>()) {
                modelContext.delete(row)
                count += 1
                if count % Self.batchSize == 0 {
                    try modelContext.save()
                }
            }
        }
        try remove(WordRecord.self)
        try remove(ReviewRecord.self)
        try remove(HistoryRecord.self)
        try remove(SessionRecord.self)
        try remove(SettingsRecord.self)
        try modelContext.save()
        resetCache()
    }

    private static func historyKey(_ kind: String, _ entryID: String) -> String {
        kind + ":" + entryID
    }
}
