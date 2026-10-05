import Foundation
import FluentKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Dostępność modelu Apple na urządzeniu (iOS 26+, Apple Intelligence włączona i pobrana).
enum AppleOnDeviceSupport {
    /// `true`, gdy model systemowy jest gotowy do użycia.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AppleOnDeviceAssistant.modelIsAvailable
        }
        #endif
        return false
    }

    /// Powód niedostępności po polsku (do Ustawień).
    static var unavailableReasonPl: String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return AppleOnDeviceAssistant.unavailableReasonPl
        }
        #endif
        return "Wymaga iOS 26 i urządzenia z Apple Intelligence."
    }
}

#if canImport(FoundationModels)

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
