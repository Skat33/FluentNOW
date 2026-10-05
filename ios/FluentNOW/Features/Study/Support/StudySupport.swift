import Foundation
import FluentKit

extension Array {
    /// Bezpieczny odczyt elementu (`nil` poza zakresem). Nazwa z prefiksem obszaru —
    /// `subscript(safe:)` z FluentKit jest wewnętrzny dla pakietu.
    func studyItem(at index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}

/// Formatowanie tekstów ekranów nauki (liczby, czas, odmiana).
enum StudyFormat {
    /// `mm:ss` (licznik czasu zadania).
    static func clock(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        let minutes = safe / 60
        let rest = safe % 60
        return (minutes < 10 ? "0" : "") + "\(minutes):" + (rest < 10 ? "0" : "") + "\(rest)"
    }

    /// Czas sesji słownie: „45 s”, „3 min 20 s”.
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0 s" }
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let rest = total % 60
        if minutes == 0 { return "\(rest) s" }
        return rest == 0 ? "\(minutes) min" : "\(minutes) min \(rest) s"
    }

    /// Litera opcji ABCD (dalej numer).
    static func letter(_ index: Int) -> String {
        ["A", "B", "C", "D", "E", "F"].studyItem(at: index) ?? "\(index + 1)"
    }

    /// Procent zaokrąglony; 0 przy pustej całości.
    static func percent(_ part: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(part) / Double(total) * 100).rounded())
    }

    /// Polska odmiana liczebnika: 1 zadanie, 2–4 zadania, 5+ zadań (12–14 → zadań).
    static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let value = abs(count)
        if value == 1 { return one }
        let lastDigit = value % 10
        let lastTwo = value % 100
        if (2...4).contains(lastDigit) && !(12...14).contains(lastTwo) { return few }
        return many
    }

    /// „6 zadań”, „1 zadanie”.
    static func tasks(_ count: Int) -> String {
        "\(count) " + plural(count, one: "zadanie", few: "zadania", many: "zadań")
    }

    /// „3 ćwiczenia”, „5 ćwiczeń”.
    static func exercises(_ count: Int) -> String {
        "\(count) " + plural(count, one: "ćwiczenie", few: "ćwiczenia", many: "ćwiczeń")
    }

    /// „5 znaków”, „3 znaki”.
    static func characters(_ count: Int) -> String {
        "\(count) " + plural(count, one: "znak", few: "znaki", many: "znaków")
    }

    /// Data z historii (ms od epoki) — krótko, po polsku.
    static func date(_ timestamp: Timestamp) -> String {
        Date(timestamp: timestamp).formatted(
            .dateTime.day().month(.abbreviated).locale(Locale(identifier: "pl_PL"))
        )
    }

    /// Przycięty tekst wpisany przez użytkownika (limit 500 znaków jak na stronie).
    static func limitedInput(_ text: String) -> String {
        text.count > 500 ? String(text.prefix(500)) : text
    }
}

/// Zasoby potrzebne do oceniania i dystraktorów, wczytywane raz na sesję z `ContentLibrary`.
struct StudyResources: Sendable {
    var variants: AnswerVariants
    var answerIndex: PolishAnswerIndex
    var starterWords: [Word]

    /// Wartości wbudowane — używane, zanim aktor treści odpowie.
    static let fallback = StudyResources(variants: .builtIn, answerIndex: PolishAnswerIndex(), starterWords: [])

    static func load(from content: ContentLibrary) async -> StudyResources {
        async let variants = content.answerVariants()
        async let index = content.polishAnswerIndex()
        async let starters = content.starterWords()
        return await StudyResources(variants: variants, answerIndex: index, starterWords: starters)
    }
}

/// Wynik zadania gotowy do zapisu (słownictwo lub pytanie).
struct StudyAnswerOutcome: Equatable {
    var value: String
    var correct: Bool
    var hinted: Bool
    var spellingCorrect: Bool
    var seconds: Double
    var explanation: String
}

/// Identyfikatory przewijania w ekranach ćwiczeń.
enum StudyScrollID {
    static let top = "study.top"
    static let feedback = "study.feedback"
}
