import Foundation
import Observation
import FluentKit

/// Asystent językowy dla UI: wybór dostawcy z preferencji (z fallbackiem do `.offline`),
/// limit czasu 20 s, wynik AI zawsze walidowany i oznaczony `source = .ai`.
/// Aplikacja jest w pełni użyteczna bez AI — `grade` zwraca `nil`, gdy brak drugiej opinii.
@MainActor
@Observable
final class AssistantService {
    private(set) var isAppleOnDeviceAvailable: Bool
    private(set) var geminiStatus: GeminiConnectionStatus
    /// Trwa zapytanie do AI (np. wskaźnik w UI).
    private(set) var isWorking = false
    /// Modele Gemini dostępne dla klucza (po połączeniu) — do wyboru w Ustawieniach.
    private(set) var availableGeminiModels: [String] = []

    @ObservationIgnored private let preferences: AppPreferences
    @ObservationIgnored private let content: ContentLibrary
    @ObservationIgnored private let keychain: KeychainStore?
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let networkEnabled: Bool

    private static let geminiModelKey = "fluent.geminiModel"
    static let timeoutSeconds: Double = 20

    /// - Parameters:
    ///   - keychain: `nil` = bez pęku kluczy (podgląd, testy).
    ///   - networkEnabled: `false` w podglądzie (bez zapytań sieciowych i modelu Apple).
    init(
        preferences: AppPreferences,
        content: ContentLibrary,
        keychain: KeychainStore? = KeychainStore(),
        defaults: UserDefaults? = .standard,
        networkEnabled: Bool = true
    ) {
        self.preferences = preferences
        self.content = content
        self.keychain = keychain
        self.defaults = defaults
        self.networkEnabled = networkEnabled
        isAppleOnDeviceAvailable = networkEnabled ? AppleOnDeviceSupport.isAvailable : false
        let hasKey = ((try? keychain?.string(for: KeychainStore.geminiAccount)) ?? nil)?.isEmpty == false
        if hasKey {
            let model = defaults?.string(forKey: Self.geminiModelKey) ?? GeminiAssistant.defaultModels[0]
            geminiStatus = .connected(model: model)
        } else {
            geminiStatus = .notConfigured
        }
    }

    /// Dostawca faktycznie używany: wybór z preferencji, jeśli jest gotowy, inaczej `.offline`.
    var activeProvider: AssistantProvider {
        switch preferences.assistantProvider {
        case .offline:
            return .offline
        case .appleOnDevice:
            return isAppleOnDeviceAvailable ? .appleOnDevice : .offline
        case .gemini:
            if case .connected = geminiStatus { return .gemini }
            return .offline
        }
    }

    /// Wybrany model Gemini (po połączeniu).
    var geminiModel: String? {
        if case .connected(let model) = geminiStatus { return model }
        return nil
    }

    /// Powód niedostępności modelu Apple (do Ustawień).
    var appleOnDeviceUnavailableReason: String {
        AppleOnDeviceSupport.unavailableReasonPl
    }

    /// Odświeża dostępność modelu Apple (np. po powrocie z Ustawień systemu).
    func refreshAvailability() {
        guard networkEnabled else { return }
        isAppleOnDeviceAvailable = AppleOnDeviceSupport.isAvailable
    }

    // MARK: - Wyszukanie i ocena

    /// Wyszukanie słowa spoza wbudowanej bazy (wynik `source = .ai`).
    /// Przy dostawcy `.offline` przeszukuje tylko bazę i rzuca `AssistantError.notFound`.
    func lookup(term: String) async throws -> Lookup {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AssistantError.notFound(term) }
        let assistant = try makeAssistant(for: activeProvider)
        isWorking = true
        defer { isWorking = false }
        return try await Self.withTimeout(Self.timeoutSeconds) {
            try await assistant.lookup(term: trimmed)
        }
    }

    /// Druga opinia AI dla niejednoznacznej odpowiedzi. `nil` = brak/timeout/błąd → zostaje ocena lokalna.
    func grade(answer: String, word: Word, meaning: Meaning, exerciseType: ExerciseType, context: String) async -> Grade? {
        let provider = activeProvider
        guard provider != .offline else { return nil }
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        guard let assistant = try? makeAssistant(for: provider) else { return nil }
        let request = GradeRequest(answer: answer, word: word, meaning: meaning, exerciseType: exerciseType, context: context)
        isWorking = true
        defer { isWorking = false }
        do {
            return try await Self.withTimeout(Self.timeoutSeconds) {
                try await assistant.grade(request)
            }
        } catch {
            return nil
        }
    }

    // MARK: - Gemini

    /// Sprawdza klucz (lista modeli Google), zapisuje go w pęku kluczy i ustawia dostawcę na Gemini.
    func connectGemini(apiKey: String) async throws {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard GeminiAssistant.isPlausibleKey(key) else {
            let error = AssistantError.unavailable("Klucz wygląda na niepoprawny. Skopiuj go w całości z Google AI Studio.")
            geminiStatus = .error(error.errorDescription ?? "")
            throw error
        }
        guard networkEnabled else {
            throw AssistantError.unavailable("Połączenie z Gemini jest niedostępne w podglądzie.")
        }
        isWorking = true
        defer { isWorking = false }
        let gemini = GeminiAssistant(apiKey: key, preferredModel: geminiModel)
        do {
            let available = try await gemini.listModels()
            let compatible = GeminiAssistant.compatibleModels(available)
            guard let model = gemini.models.first(where: { compatible.contains($0) }) ?? compatible.first else {
                throw AssistantError.http(status: 404, message: "Gemini nie udostępnia teraz zgodnego modelu Flash dla tego klucza.")
            }
            if let keychain {
                try keychain.set(key, for: KeychainStore.geminiAccount)
            }
            defaults?.set(model, forKey: Self.geminiModelKey)
            availableGeminiModels = compatible
            geminiStatus = .connected(model: model)
            preferences.assistantProvider = .gemini
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            geminiStatus = .error(message)
            throw error
        }
    }

    /// Zmiana modelu Gemini (z listy `availableGeminiModels`).
    func selectGeminiModel(_ model: String) {
        guard case .connected = geminiStatus, !model.isEmpty else { return }
        defaults?.set(model, forKey: Self.geminiModelKey)
        geminiStatus = .connected(model: model)
    }

    /// Usuwa klucz z pęku kluczy i wraca do trybu bez AI (jeśli Gemini był wybrany).
    func disconnectGemini() {
        keychain?.remove(KeychainStore.geminiAccount)
        defaults?.removeObject(forKey: Self.geminiModelKey)
        availableGeminiModels = []
        geminiStatus = .notConfigured
        if preferences.assistantProvider == .gemini {
            preferences.assistantProvider = .offline
        }
    }

    // MARK: - Implementacja

    private func makeAssistant(for provider: AssistantProvider) throws -> any LanguageAssistant {
        switch provider {
        case .offline:
            return OfflineAssistant(content: content)
        case .appleOnDevice:
            #if canImport(FoundationModels) && !FLUENT_DISABLE_FOUNDATION_MODELS
            if #available(iOS 26.0, *), networkEnabled {
                return AppleOnDeviceAssistant()
            }
            #endif
            throw AssistantError.unavailable(AppleOnDeviceSupport.unavailableReasonPl)
        case .gemini:
            guard networkEnabled else { throw AssistantError.unavailable("Gemini jest niedostępne w podglądzie.") }
            guard let key = (try? keychain?.string(for: KeychainStore.geminiAccount)) ?? nil, !key.isEmpty else {
                throw AssistantError.missingKey
            }
            return GeminiAssistant(apiKey: key, preferredModel: geminiModel)
        }
    }

    /// Wykonuje operację z limitem czasu (`AssistantError.timeout`).
    nonisolated static func withTimeout<T: Sendable>(
        _ seconds: Double,
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AssistantError.timeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else {
                throw AssistantError.timeout
            }
            return first
        }
    }
}
