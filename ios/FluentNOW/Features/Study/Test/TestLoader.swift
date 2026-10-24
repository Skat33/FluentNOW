import Foundation
import FluentKit

/// Przygotowanie testu (K4): wczytanie treści (tematy z pasma, gramatyka i czytanki poziomu
/// bazowego) z `ContentLibrary` i zbudowanie testu w FluentKit (`AssessmentBuilder.make`) poza
/// głównym wątkiem.
enum TestLoader {
    enum Failure: Error, Equatable {
        /// Za mało materiału (np. brak treści w pakiecie aplikacji).
        case notEnoughContent
    }

    /// Nowy test dla bieżącego stanu (nie zapisuje go — robi to model ekranu).
    @MainActor
    static func makeSession(store: LearningStore, content: ContentLibrary) async -> Result<AssessmentSession, Failure> {
        let state: LearnerState = store.state
        let now: Timestamp = store.now()
        let band: AssessmentBand = AssessmentBuilder.band(state, now: now)
        let bank: [AssessmentBankEntry] = await bankEntries(state: state, band: band, content: content)
        var grammarPool: [ProductionItem] = []
        var readings = ReadingBank()
        if let practice = try? await content.practiceContent(level: band.base) {
            grammarPool = practice.productionPool(level: band.base)
            readings = practice.readings
        }
        let assessmentContent = AssessmentContent(bankEntries: bank, grammarPool: grammarPool, readings: readings)
        let id: String = UUID().uuidString.lowercased()
        let built: AssessmentSession? = await Task.detached(priority: .userInitiated) { () -> AssessmentSession? in
            var generator = SystemRandomNumberGenerator()
            return AssessmentBuilder.make(state: state, content: assessmentContent, now: now, id: id, using: &generator)
        }.value
        guard let built else { return .failure(.notEnoughContent) }
        return .success(built)
    }

    /// Słowa z bazy: tematy ucznia i profilu, potem tematy z największą liczbą słów z pasma.
    private static func bankEntries(state: LearnerState, band: AssessmentBand, content: ContentLibrary) async -> [AssessmentBankEntry] {
        guard let index = try? await content.topicIndex() else { return [] }
        let ids: [String] = AssessmentBuilder.topicIDs(state: state, index: index, band: band)
        var learnerTopics = Set(AssessmentBuilder.learnerTopicIDs(state))
        if let profile = state.settings.profile {
            for topicID in profile.topicWeights().keys {
                learnerTopics.insert(topicID)
            }
        }
        var entries: [AssessmentBankEntry] = []
        for topicID in ids {
            guard let topic = try? await content.topic(id: topicID) else { continue }
            entries.append(contentsOf: AssessmentBuilder.bankEntries(topic: topic, band: band, fromLearnerTopics: learnerTopics.contains(topicID)))
        }
        return entries
    }

    /// „Dodaj nowe słowa do nauki”: wpisy z bazy (po referencjach) dodane do słownika, każdy do
    /// kolekcji swojego tematu. Zwraca liczbę dodanych znaczeń.
    @MainActor
    static func addBankWords(references: [String], store: LearningStore, content: ContentLibrary) async -> Int {
        var byTopic: [String: [String]] = [:]
        var order: [String] = []
        for raw in references {
            guard let reference = ContentReference(raw), !reference.isStarter else { continue }
            if byTopic[reference.file] == nil { order.append(reference.file) }
            byTopic[reference.file, default: []].append(reference.entryID)
        }
        var added = 0
        for file in order {
            guard let entryIDs = byTopic[file], let topic = try? await content.topic(id: file) else { continue }
            let now: Timestamp = store.now()
            let count: Int = store.update(.bulk) { (state: inout LearnerState) -> Int in
                let result = VocabularyMerger.addTopicEntries(state, topic: topic, entryIDs: entryIDs, now: now)
                state = result.state
                return result.addedMeaningIDs.count
            }
            added += count
        }
        return added
    }
}
