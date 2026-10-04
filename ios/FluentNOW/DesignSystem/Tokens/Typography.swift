import SwiftUI

/// Typografia oparta o `Font.TextStyle` — każdy styl skaluje się z Dynamic Type.
/// Liczby (wyniki, liczniki, czas) używają kroju `.rounded` i cyfr o stałej szerokości.
enum FluentFont {
    /// Tytuł ekranu powitalnego / podsumowania sesji („Mały krok za Tobą.”).
    static let display = Font.system(.largeTitle, design: .default, weight: .bold)
    /// Nagłówek karty hero („Zaczynamy?”).
    static let heroTitle = Font.system(.title, design: .default, weight: .bold)
    /// Tytuł sekcji/karty.
    static let title = Font.system(.title3, design: .default, weight: .semibold)
    /// Nagłówek grupy w ekranie.
    static let headline = Font.system(.headline, design: .default, weight: .semibold)
    /// Treść.
    static let body = Font.system(.body)
    /// Treść wyróżniona (np. hasło na liście).
    static let bodyEmphasized = Font.system(.body, design: .default, weight: .semibold)
    /// Tekst pomocniczy.
    static let callout = Font.system(.callout)
    static let subheadline = Font.system(.subheadline)
    static let footnote = Font.system(.footnote)
    static let caption = Font.system(.caption)
    /// Mała etykieta wersalikami (np. „SESJA NA DZIŚ”) — używaj z `.textCase(.uppercase)` i `tracking`.
    static let eyebrow = Font.system(.caption, design: .default, weight: .semibold)
    /// Etykieta przycisku.
    static let button = Font.system(.body, design: .default, weight: .semibold)

    /// Słowo angielskie w fiszce — duże, czytelne.
    static let flashcardTerm = Font.system(.largeTitle, design: .default, weight: .semibold)
    /// Zdanie przykładowe w ćwiczeniu.
    static let sentence = Font.system(.title3, design: .default, weight: .regular)
    /// Wymowa IPA.
    static let ipa = Font.system(.callout, design: .default, weight: .regular)
    /// Tekst czytanki — krój szeryfowy dla długiego czytania.
    static let reading = Font.system(.body, design: .serif)

    // MARK: Liczby

    /// Duża liczba (pierścień celu, kafelek statystyki).
    static let numberLarge = Font.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit()
    /// Średnia liczba (kafelek statystyki).
    static let numberMedium = Font.system(.title2, design: .rounded, weight: .semibold).monospacedDigit()
    /// Mała liczba (procent przy pasku umiejętności, licznik czasu).
    static let numberSmall = Font.system(.subheadline, design: .rounded, weight: .semibold).monospacedDigit()
}

extension Text {
    /// Etykieta „eyebrow”: mała, pogrubiona, wersaliki z rozstrzeleniem.
    func fluentEyebrow() -> some View {
        self.font(FluentFont.eyebrow)
            .tracking(1.1)
            .textCase(.uppercase)
    }
}
