import Foundation
import FluentKit

/// Dostawca asystenta językowego (wybór w Ustawieniach, per urządzenie).
enum AssistantProvider: String, CaseIterable, Identifiable, Codable {
    case offline
    case appleOnDevice
    case gemini

    var id: String { rawValue }

    var namePl: String {
        switch self {
        case .offline: return "Bez AI (wbudowana baza)"
        case .appleOnDevice: return "Apple Intelligence (na urządzeniu)"
        case .gemini: return "Google Gemini (Twój klucz)"
        }
    }

    /// Krótki opis do listy wyboru.
    var detailPl: String {
        switch self {
        case .offline:
            return "Działa zawsze i bez internetu. Słowa spoza bazy dodasz ręcznie."
        case .appleOnDevice:
            return "Model językowy Apple działa na iPhonie — prywatnie i bez internetu. Wymaga iOS 26 i włączonej Apple Intelligence."
        case .gemini:
            return "Zapytania trafiają do Google z Twoim kluczem API. Klucz jest przechowywany tylko w pęku kluczy tego urządzenia."
        }
    }
}

/// Stan połączenia z Gemini.
enum GeminiConnectionStatus: Equatable {
    case notConfigured
    case connected(model: String)
    case error(String)
}

/// Błędy asystenta (polskie komunikaty, z kodem HTTP tam, gdzie ma sens).
enum AssistantError: Error, LocalizedError, Equatable {
    case unavailable(String)
    case notFound(String)
    case invalidResponse(String)
    case http(status: Int, message: String)
    case network(String)
    case timeout
    case missingKey
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason):
            return reason
        case .notFound(let term):
            return "Nie znaleziono znaczeń dla „\(term)”. Możesz dodać słowo ręcznie."
        case .invalidResponse(let detail):
            return "Asystent zwrócił niepoprawną odpowiedź (\(detail)). Spróbuj ponownie albo dodaj słowo ręcznie."
        case .http(let status, let message):
            return "Błąd serwera AI (HTTP \(status)): \(message)"
        case .network(let detail):
            return "Brak połączenia z asystentem: \(detail)"
        case .timeout:
            return "Asystent nie odpowiedział w ciągu 20 sekund. Spróbuj ponownie."
        case .missingKey:
            return "Brak klucza API Gemini. Dodaj go w Ustawieniach → Asystent AI."
        case .cancelled:
            return "Przerwano."
        }
    }
}

/// Wspólny interfejs dostawców AI. Wszystkie metody wołane poza głównym wątkiem
/// (implementacje są `Sendable`). Wynik AI jest zawsze propozycją — walidowaną przed użyciem.
protocol LanguageAssistant: Sendable {
    /// Wyszukanie słowa spoza wbudowanej bazy. Zwraca `Lookup` z `source = .ai`.
    func lookup(term: String) async throws -> Lookup
    /// Ocena niejednoznacznej odpowiedzi. `nil` = brak zdania (zostaje ocena lokalna).
    func grade(_ request: GradeRequest) async throws -> Grade?
}

/// Dane do oceny odpowiedzi przez AI (wartości `Sendable`).
struct GradeRequest: Sendable, Hashable {
    var answer: String
    var term: String
    var translation: String
    var definition: String
    var acceptedAnswers: [String]
    var exerciseType: ExerciseType
    var context: String

    init(answer: String, word: Word, meaning: Meaning, exerciseType: ExerciseType, context: String) {
        self.answer = answer
        self.term = word.en
        self.translation = meaning.translation
        self.definition = meaning.definition
        self.acceptedAnswers = VocabularyGrader.vocabularyAnswers(word: word, meaning: meaning, type: exerciseType)
        self.exerciseType = exerciseType
        self.context = context
    }

    /// Kierunek odpowiedzi: `true` gdy uczący pisze po angielsku.
    var expectsEnglish: Bool {
        exerciseType != .meaning
    }
}
