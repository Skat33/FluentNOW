import Foundation
import FluentKit
#if canImport(FoundationModels) && !FLUENT_DISABLE_FOUNDATION_MODELS
import FoundationModels
#endif

/// Dostępność modelu Apple na urządzeniu (iOS 26+, Apple Intelligence włączona i pobrana).
enum AppleOnDeviceSupport {
    /// `true`, gdy model systemowy jest gotowy do użycia.
    static var isAvailable: Bool {
        #if canImport(FoundationModels) && !FLUENT_DISABLE_FOUNDATION_MODELS
        if #available(iOS 26.0, *) {
            return AppleOnDeviceAssistant.modelIsAvailable
        }
        #endif
        return false
    }

    /// Powód niedostępności po polsku (do Ustawień).
    static var unavailableReasonPl: String {
        #if canImport(FoundationModels) && !FLUENT_DISABLE_FOUNDATION_MODELS
        if #available(iOS 26.0, *) {
            return AppleOnDeviceAssistant.unavailableReasonPl
        }
        #endif
        return "Wymaga iOS 26 i urządzenia z Apple Intelligence."
    }
}

#if canImport(FoundationModels) && !FLUENT_DISABLE_FOUNDATION_MODELS

/// Asystent na modelu Apple (Foundation Models) — prywatnie, bez internetu.
/// Generowanie strukturalne (`@Generable`), wynik walidowany jak każda treść AI.
@available(iOS 26.0, *)
struct AppleOnDeviceAssistant: LanguageAssistant {
    static var modelIsAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    static var unavailableReasonPl: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return ""
        case .unavailable(.deviceNotEligible):
            return "To urządzenie nie obsługuje Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Włącz Apple Intelligence w Ustawieniach systemu."
        case .unavailable(.modelNotReady):
            return "Model Apple jest jeszcze pobierany. Spróbuj później."
        case .unavailable:
            return "Model Apple jest teraz niedostępny."
        }
    }

    func lookup(term: String) async throws -> Lookup {
        guard Self.modelIsAvailable else { throw AssistantError.unavailable(Self.unavailableReasonPl) }
        let session = LanguageModelSession(instructions: AssistantPrompts.system + AssistantPrompts.lookup)
        let generated: GeneratedLookup
        do {
            let response = try await session.respond(
                to: AssistantPrompts.lookupPayload(term: term),
                generating: GeneratedLookup.self
            )
            generated = response.content
        } catch is CancellationError {
            throw AssistantError.cancelled
        } catch {
            throw AssistantError.invalidResponse(error.localizedDescription)
        }
        return try AssistantValidation.sanitize(generated.lookup(term: term), term: term)
    }

    func grade(_ request: GradeRequest) async throws -> Grade? {
        guard Self.modelIsAvailable else { return nil }
        let session = LanguageModelSession(instructions: AssistantPrompts.system + AssistantPrompts.grade(type: request.exerciseType))
        do {
            let response = try await session.respond(
                to: AssistantPrompts.gradePayload(request),
                generating: GeneratedGrade.self
            )
            let content = response.content
            return AssistantValidation.grade(
                verdict: content.verdict,
                explanation: content.explanation,
                spellingCorrect: content.spellingCorrect
            )
        } catch {
            return nil
        }
    }

    // MARK: Tematy (F1) — krótsza lista (mały kontekst modelu), walidacja jak dla Gemini

    func topicDraft(query: String) async throws -> TopicDraft {
        guard Self.modelIsAvailable else { throw AssistantError.unavailable(Self.unavailableReasonPl) }
        let session = LanguageModelSession(instructions: AssistantPrompts.system + AssistantPrompts.topicListCompact)
        do {
            let response = try await session.respond(
                to: AssistantPrompts.topicListPayload(query: query),
                generating: GeneratedTopicList.self
            )
            return response.content.draft
        } catch is CancellationError {
            throw AssistantError.cancelled
        } catch {
            throw AssistantError.invalidResponse(error.localizedDescription)
        }
    }

    func topicDetails(topicName: String, items: [TopicHydrationRequestItem]) async throws -> [TopicHydrationItem] {
        guard Self.modelIsAvailable else { throw AssistantError.unavailable(Self.unavailableReasonPl) }
        guard !items.isEmpty else { return [] }
        let session = LanguageModelSession(instructions: AssistantPrompts.system + AssistantPrompts.topicDetails)
        do {
            let response = try await session.respond(
                to: AssistantPrompts.topicDetailsPayload(topicName: topicName, items: items),
                generating: GeneratedTopicDetails.self
            )
            return response.content.items.map { $0.item }
        } catch is CancellationError {
            throw AssistantError.cancelled
        } catch {
            throw AssistantError.invalidResponse(error.localizedDescription)
        }
    }
}

@available(iOS 26.0, *)
@Generable(description: "Vocabulary inventory of a situation for a Polish learner of American English")
struct GeneratedTopicList {
    @Guide(description: "Canonical Polish topic name in nominative")
    var topic: String
    @Guide(description: "English topic name")
    var nameEn: String
    @Guide(description: "One short Polish sentence describing the topic")
    var summaryPl: String
    @Guide(description: "Group id: basics, travel, food, home, health, work, education, technology, money, services, people, daily, leisure, nature, society or communication")
    var group: String
    @Guide(description: "4-6 categories named in Polish, essential vocabulary first")
    var categories: [GeneratedTopicCategory]

    var draft: TopicDraft {
        TopicDraft(
            topic: topic,
            nameEn: nameEn,
            summaryPl: summaryPl,
            group: group,
            categories: categories.map { $0.draft }
        )
    }
}

@available(iOS 26.0, *)
@Generable(description: "A category of the topic")
struct GeneratedTopicCategory {
    @Guide(description: "Category name in Polish")
    var name: String
    @Guide(description: "One Polish sentence describing the place and moment")
    var scene: String
    @Guide(description: "5-10 items, most common first")
    var items: [GeneratedTopicItem]

    var draft: TopicDraftCategory {
        TopicDraftCategory(name: name, scene: scene, items: items.map { $0.draft })
    }
}

@available(iOS 26.0, *)
@Generable(description: "An English word or phrase of the topic")
struct GeneratedTopicItem {
    @Guide(description: "English dictionary form in lowercase")
    var term: String
    @Guide(description: "Short Polish translation of this sense")
    var pl: String
    @Guide(description: "Polish part of speech: rzeczownik, czasownik, czasownik frazowy, przymiotnik, przysłówek, zwrot or idiom")
    var pos: String
    @Guide(description: "CEFR level: A1, A2, B1, B2, C1 or C2")
    var level: String
    @Guide(description: "very_common, common, less_common or rare")
    var spokenFrequency: String

    var draft: TopicDraftItem {
        TopicDraftItem(term: term, translation: pl, pos: pos, level: level, frequency: spokenFrequency)
    }
}

@available(iOS 26.0, *)
@Generable(description: "Details of the supplied topic items, one per item in the same order")
struct GeneratedTopicDetails {
    var items: [GeneratedTopicDetail]
}

@available(iOS 26.0, *)
@Generable(description: "Details of one topic item")
struct GeneratedTopicDetail {
    @Guide(description: "The supplied term, unchanged")
    var term: String
    @Guide(description: "General American IPA in slashes, or empty")
    var ipa: String
    @Guide(description: "Simple English definition, one sentence, at most 140 characters")
    var definition: String
    @Guide(description: "neutralny, potoczny, formalny, specjalistyczny or slangowy")
    var register: String
    @Guide(description: "When it is used, in Polish, at most 80 characters")
    var contextPl: String
    @Guide(description: "Irregular forms or plural, or empty")
    var forms: String
    @Guide(description: "Common collocations separated by semicolons, or empty")
    var collocations: String
    @Guide(description: "Exactly two example sentences set in the supplied scene")
    var examples: [GeneratedExample]
    @Guide(description: "English recall variants including the term")
    var acceptedAnswers: [String]
    @Guide(description: "1-8 natural Polish equivalents including the supplied translation")
    var acceptedTranslations: [String]

    var item: TopicHydrationItem {
        TopicHydrationItem(
            term: term,
            ipa: ipa,
            definition: definition,
            register: register,
            contextPl: contextPl,
            forms: forms,
            collocations: collocations,
            examples: examples.map { ExamplePair(en: $0.en, pl: $0.pl, focusEn: $0.focusEn, focusPl: $0.focusPl) },
            acceptedAnswers: acceptedAnswers,
            acceptedTranslations: acceptedTranslations
        )
    }
}

@available(iOS 26.0, *)
@Generable(description: "Dictionary entry for an English word or phrase, for a Polish learner")
struct GeneratedLookup {
    @Guide(description: "false if the word does not exist or you are unsure")
    var exists: Bool
    var term: String
    @Guide(description: "General American IPA in slashes, or empty")
    var ipa: String
    @Guide(description: "Irregular forms, or empty")
    var forms: String
    @Guide(description: "Short note in Polish, or empty")
    var note: String
    @Guide(description: "Up to 3 real spelling alternatives when the word does not exist")
    var alternatives: [String]
    @Guide(description: "1-6 main distinct senses")
    var meanings: [GeneratedSense]

    func lookup(term fallbackTerm: String) -> Lookup {
        Lookup(
            exists: exists,
            term: term.isEmpty ? fallbackTerm : term,
            ipa: ipa,
            forms: forms,
            note: note,
            alternatives: alternatives,
            meanings: meanings.map { $0.suggestion },
            source: .ai
        )
    }
}

@available(iOS 26.0, *)
@Generable(description: "One sense of the word")
struct GeneratedSense {
    @Guide(description: "Short Polish translation of this sense")
    var translation: String
    @Guide(description: "Simple English definition, one sentence")
    var definition: String
    @Guide(description: "Polish part of speech, e.g. rzeczownik, czasownik, przymiotnik, zwrot")
    var pos: String
    @Guide(description: "CEFR level of this sense: A1, A2, B1, B2, C1 or C2")
    var level: String
    @Guide(description: "When it is used, in Polish")
    var context: String
    @Guide(description: "neutralny, potoczny, formalny, specjalistyczny or slangowy")
    var register: String
    @Guide(description: "Two natural example sentences with Polish translations")
    var examples: [GeneratedExample]
    @Guide(description: "English recall variants for this sense")
    var acceptedAnswers: [String]
    @Guide(description: "Natural Polish equivalents of this sense")
    var acceptedTranslations: [String]

    var suggestion: SenseSuggestion {
        SenseSuggestion(
            translation: translation,
            definition: definition,
            pos: pos,
            level: level,
            context: context,
            register: register,
            examples: examples.map { ExamplePair(en: $0.en, pl: $0.pl, focusEn: $0.focusEn, focusPl: $0.focusPl) },
            acceptedTranslations: acceptedTranslations,
            acceptedAnswers: acceptedAnswers
        )
    }
}

@available(iOS 26.0, *)
@Generable(description: "Example sentence pair")
struct GeneratedExample {
    var en: String
    var pl: String
    @Guide(description: "Exact substring of en with the word as used")
    var focusEn: String
    @Guide(description: "Exact substring of pl that translates the word")
    var focusPl: String
}

@available(iOS 26.0, *)
@Generable(description: "Grade of a learner's answer")
struct GeneratedGrade {
    @Guide(description: "correct, incorrect or uncertain")
    var verdict: String
    @Guide(description: "Short explanation in Polish")
    var explanation: String
    var spellingCorrect: Bool
}

#endif
