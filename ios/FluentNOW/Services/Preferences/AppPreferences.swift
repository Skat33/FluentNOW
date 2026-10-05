import Foundation
import Observation

/// Preferencje urządzenia (UserDefaults) — nie są synchronizowane przez iCloud
/// i nie trafiają do eksportu. Ustawienia nauki (cel, pora przypomnienia, głos)
/// są w `LearnerState.settings` (synchronizowane).
@MainActor
@Observable
final class AppPreferences {
    var appearance: AppAppearance {
        didSet { write(appearance.rawValue, for: Keys.appearance) }
    }
    var remindersEnabled: Bool {
        didSet { write(remindersEnabled, for: Keys.remindersEnabled) }
    }
    var assistantProvider: AssistantProvider {
        didSet { write(assistantProvider.rawValue, for: Keys.assistantProvider) }
    }
    var hasCompletedOnboarding: Bool {
        didSet { write(hasCompletedOnboarding, for: Keys.onboarding) }
    }
    var hapticsEnabled: Bool {
        didSet { write(hapticsEnabled, for: Keys.haptics) }
    }

    @ObservationIgnored private let defaults: UserDefaults?

    private enum Keys {
        static let appearance = "fluent.appearance"
        static let remindersEnabled = "fluent.remindersEnabled"
        static let assistantProvider = "fluent.assistantProvider"
        static let onboarding = "fluent.hasCompletedOnboarding"
        static let haptics = "fluent.hapticsEnabled"
    }

    /// - Parameter defaults: `nil` = tylko w pamięci (podgląd, testy).
    init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        let stored = defaults
        appearance = stored?.string(forKey: Keys.appearance).flatMap(AppAppearance.init(rawValue:)) ?? .system
        remindersEnabled = stored?.object(forKey: Keys.remindersEnabled) as? Bool ?? false
        assistantProvider = stored?.string(forKey: Keys.assistantProvider).flatMap(AssistantProvider.init(rawValue:)) ?? .offline
        hasCompletedOnboarding = stored?.object(forKey: Keys.onboarding) as? Bool ?? false
        hapticsEnabled = stored?.object(forKey: Keys.haptics) as? Bool ?? true
    }

    /// Prefiksy kluczy UserDefaults innych obszarów, czyszczone przy „Usuń wszystkie dane”
    /// (`study.` — preferencje ekranów nauki, ui-learning).
    nonisolated static let resettableKeyPrefixes = ["study.", "fluent."]

    /// Przywraca wartości domyślne (używane przy „Usuń wszystkie dane”) i usuwa
    /// klucze UserDefaults z prefiksami `resettableKeyPrefixes` — nic nie zostaje.
    func resetToDefaults() {
        appearance = .system
        remindersEnabled = false
        assistantProvider = .offline
        hasCompletedOnboarding = false
        hapticsEnabled = true
        guard let defaults else { return }
        for key in defaults.dictionaryRepresentation().keys
        where Self.resettableKeyPrefixes.contains(where: { key.hasPrefix($0) }) {
            defaults.removeObject(forKey: key)
        }
    }

    private func write(_ value: Any, for key: String) {
        defaults?.set(value, forKey: key)
    }
}
