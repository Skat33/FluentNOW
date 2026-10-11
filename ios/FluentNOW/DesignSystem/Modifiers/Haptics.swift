import SwiftUI

/// Słownik haptyki FluentNOW. Haptykę wywołujemy deklaratywnie przez `.sensoryFeedback`
/// (iOS 17) — system sam respektuje ustawienie „Wibracje systemu”.
///
/// Użycie:
/// ```swift
/// .sensoryFeedback(FluentHaptic.answerCorrect, trigger: correctCount)
/// .sensoryFeedback(FluentHaptic.selection, trigger: selectedOption)
/// ```
enum FluentHaptic {
    /// Poprawna odpowiedź, zapisanie słowa, ukończenie sesji.
    static let answerCorrect: SensoryFeedback = .success
    /// Błędna odpowiedź (delikatnie — błąd jest częścią nauki).
    static let answerIncorrect: SensoryFeedback = .error
    /// „Prawie” / odpowiedź z podpowiedzią / ostrzeżenie.
    static let answerAlmost: SensoryFeedback = .warning
    /// Wybór opcji, przełączenie segmentu, chip filtra.
    static let selection: SensoryFeedback = .selection
    /// Przesunięcie fiszki poza próg, upuszczenie elementu.
    static let swipeCommit: SensoryFeedback = .impact(weight: .medium, intensity: 0.7)
    /// Osiągnięcie dziennego celu (pierścień zamknięty).
    static let goalReached: SensoryFeedback = .success
    /// Akcja niszcząca potwierdzona (usunięcie).
    static let destructive: SensoryFeedback = .warning
}

/// Rodzaj informacji zwrotnej po odpowiedzi — wspólny dla `FeedbackPanel` i haptyki.
enum FeedbackKind: String, Hashable, CaseIterable {
    case correct
    case almost
    case incorrect
    case info

    /// Haptyka odpowiadająca wynikowi (`nil` = bez wibracji).
    var haptic: SensoryFeedback? {
        switch self {
        case .correct: return FluentHaptic.answerCorrect
        case .almost: return FluentHaptic.answerAlmost
        case .incorrect: return FluentHaptic.answerIncorrect
        case .info: return nil
        }
    }

    var tone: ToneColors {
        switch self {
        case .correct: return .success
        case .almost: return .warning
        case .incorrect: return .danger
        case .info: return .info
        }
    }

    var systemImage: String {
        switch self {
        case .correct: return "checkmark.circle.fill"
        case .almost: return "exclamationmark.circle.fill"
        case .incorrect: return "xmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    /// Domyślny nagłówek panelu.
    var defaultTitle: String {
        switch self {
        case .correct: return "Dobrze!"
        case .almost: return "Prawie!"
        case .incorrect: return "Nie tym razem"
        case .info: return "Wskazówka"
        }
    }
}

// MARK: - Globalny przełącznik haptyki (Ustawienia → „Wibracje”)

/// Czy aplikacja ma odtwarzać haptykę. Ustawiane w korzeniu aplikacji z `AppPreferences.hapticsEnabled`
/// (`FluentNOWApp` → `AppearanceRoot`); domyślnie `true` (podglądy, testy).
/// Komponenty design systemu czytają tę wartość — dzięki temu nie zależą od serwisów aplikacji.
private struct FluentHapticsEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var fluentHapticsEnabled: Bool {
        get { self[FluentHapticsEnabledKey.self] }
        set { self[FluentHapticsEnabledKey.self] = newValue }
    }
}

/// `.sensoryFeedback`, który respektuje ustawienie haptyki z preferencji.
private struct FluentSensoryFeedbackModifier<Trigger: Equatable>: ViewModifier {
    let feedback: SensoryFeedback
    let trigger: Trigger
    @Environment(\.fluentHapticsEnabled) private var hapticsEnabled

    func body(content: Content) -> some View {
        content.sensoryFeedback(feedback, trigger: trigger) { _, _ in
            hapticsEnabled
        }
    }
}

extension View {
    /// Jak `.sensoryFeedback(_:trigger:)`, ale wyłączone, gdy użytkownik wyłączył haptykę w Ustawieniach.
    ///
    /// ```swift
    /// .fluentSensoryFeedback(FluentHaptic.selection, trigger: selectedOption)
    /// ```
    func fluentSensoryFeedback<Trigger: Equatable>(_ feedback: SensoryFeedback, trigger: Trigger) -> some View {
        modifier(FluentSensoryFeedbackModifier(feedback: feedback, trigger: trigger))
    }
}
