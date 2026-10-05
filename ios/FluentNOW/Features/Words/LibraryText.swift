import Foundation

/// Pomocnicze teksty obszaru ui-library (odmiana liczebników po polsku).
enum LibraryText {
    /// Odmiana: 1 słowo, 2–4 słowa (poza 12–14), 5+ słów.
    static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let value = abs(count)
        if value == 1 { return one }
        let lastTwo = value % 100
        let last = value % 10
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return few }
        return many
    }

    /// „3 słowa”, „5 słów”.
    static func count(_ count: Int, one: String, few: String, many: String) -> String {
        "\(count) \(plural(count, one: one, few: few, many: many))"
    }

    static func words(_ count: Int) -> String {
        self.count(count, one: "słowo", few: "słowa", many: "słów")
    }

    static func meanings(_ count: Int) -> String {
        self.count(count, one: "znaczenie", few: "znaczenia", many: "znaczeń")
    }

    static func days(_ count: Int) -> String {
        "\(count) \(count == 1 ? "dzień" : "dni")"
    }
}
