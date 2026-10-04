import SwiftUI
import UIKit

/// Semantyczne kolory FluentNOW. Każdy kolor ma wariant jasny i ciemny
/// (rozwiązywany dynamicznie przez `UITraitCollection`), a pary tekst/tło
/// spełniają WCAG AA (≥ 4.5:1 dla tekstu, ≥ 3:1 dla grafiki) w obu trybach.
///
/// Zasada: w widokach używaj ról (`Palette.ink`, `Palette.accent`), nigdy surowych wartości hex.
enum Palette {

    // MARK: Tła i powierzchnie

    /// Tło ekranu (chłodna biel / głęboki granat).
    static let background = dynamic(light: 0xF7F8FC, dark: 0x151620)
    /// Powierzchnia karty na tle ekranu.
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x1D1E2B)
    /// Powierzchnia unosząca się nad kartami (popover, element przeciągany, pole w karcie).
    static let surfaceElevated = dynamic(light: 0xFFFFFF, dark: 0x252634)
    /// Wyciszona powierzchnia: tor paska postępu, nieaktywne pole, tło segmentu.
    static let surfaceMuted = dynamic(light: 0xF1F2F7, dark: 0x292A39)
    /// Linia podziału i obrys kart.
    static let separator = dynamic(light: 0xE9E9F1, dark: 0x323342)

    // MARK: Tekst

    /// Główny, „atramentowy” tekst (14:1 na tle).
    static let ink = dynamic(light: 0x242536, dark: 0xEEEEF6)
    /// Tekst pomocniczy (≥ 4.6:1 na wszystkich powierzchniach).
    static let inkSecondary = dynamic(light: 0x6B6C7D, dark: 0xA2A3B5)
    /// Tylko placeholdery i elementy dekoracyjne — nie dla treści do przeczytania.
    static let inkTertiary = dynamic(light: 0x9A9BAB, dark: 0x6F7083)

    // MARK: Akcent (fiolet = główna akcja)

    /// Fiolet jako kolor tekstu/ikon na powierzchniach (linki, wybrane elementy).
    static let accent = dynamic(light: 0x7451D8, dark: 0xB39CF5)
    /// Wypełnienie głównego przycisku i fioletowych kart (biały tekst ≥ 4.7:1).
    static let accentFill = dynamic(light: 0x7451D8, dark: 0x7C5CE0)
    /// Tekst/ikony na `accentFill`.
    static let onAccent = Color.white
    /// Delikatne tło akcentu (wybrany chip, odznaka, podświetlenie).
    static let accentSoft = dynamic(light: 0xF0EAFB, dark: 0x372B50)
    /// Tekst na `accentSoft`.
    static let accentSoftInk = dynamic(light: 0x6243BD, dark: 0xC6A7FF)

    // MARK: Stany

    static let success = dynamic(light: 0x2C7A58, dark: 0x8BD1AF)
    static let successSoft = dynamic(light: 0xE9F5EF, dark: 0x233D35)
    static let warning = dynamic(light: 0x94601F, dark: 0xE4B477)
    static let warningSoft = dynamic(light: 0xFFF3DF, dark: 0x483628)
    static let danger = dynamic(light: 0xB23B33, dark: 0xFF8F86)
    static let dangerSoft = dynamic(light: 0xFDECEB, dark: 0x49252B)
    static let info = dynamic(light: 0x3F6FAE, dark: 0xABC4E8)
    static let infoSoft = dynamic(light: 0xEAF1FA, dark: 0x26354A)

    // MARK: Karta sesji (hero)

    /// Kolory gradientu fioletowej karty sesji (biały tekst ≥ 4.5:1 na obu końcach).
    static let heroStart = dynamic(light: 0x6A46CF, dark: 0x5B3CC0)
    static let heroEnd = dynamic(light: 0x7552D8, dark: 0x7452D6)
    static let heroGlow = dynamic(light: 0x7D5BDC, dark: 0x6E4FD0)
    /// Tekst drugorzędny na karcie sesji.
    static let heroInkSecondary = Color.white.opacity(0.9)
    /// Tor pierścienia celu na karcie sesji.
    static let heroRingTrack = Color.white.opacity(0.18)
    /// Postęp pierścienia celu na karcie sesji.
    static let heroRingProgress = dynamic(light: 0xE1D4FF, dark: 0xE1D4FF)

    // MARK: Wykresy (Swift Charts) — kolejność serii jak na stronie (--chart-1…5)

    static let chart: [Color] = [
        dynamic(light: 0x7451D8, dark: 0xA68AEE),
        dynamic(light: 0x4E9B87, dark: 0x7AC1B0),
        dynamic(light: 0xC0843F, dark: 0xE2AA76),
        dynamic(light: 0x5F75C4, dark: 0x8B9CDB),
        dynamic(light: 0x9A84C9, dark: 0xB1A1D6)
    ]

    /// Kolor serii wykresu; indeks poza zakresem zawija się (nigdy nie wychodzi poza tablicę).
    static func chartColor(_ index: Int) -> Color {
        chart[safeIndex(index, count: chart.count)]
    }

    // MARK: Kolekcje (kropka/ikona kolekcji, 6 tonów jak `.color-0…5` na stronie)

    static let collectionTones: [ToneColors] = [
        ToneColors(foreground: dynamic(light: 0x7A55BC, dark: 0xC6A7FF), background: dynamic(light: 0xF2EAFB, dark: 0x372B50)),
        ToneColors(foreground: dynamic(light: 0x8F6630, dark: 0xE4B477), background: dynamic(light: 0xFCF0DF, dark: 0x483628)),
        ToneColors(foreground: dynamic(light: 0x377459, dark: 0x8BD1AF), background: dynamic(light: 0xEAF4EE, dark: 0x233D35)),
        ToneColors(foreground: dynamic(light: 0x46699A, dark: 0xABC4E8), background: dynamic(light: 0xEAF1FA, dark: 0x26354A)),
        ToneColors(foreground: dynamic(light: 0x9A5167, dark: 0xE2A4BD), background: dynamic(light: 0xF7EAF0, dark: 0x452C37)),
        ToneColors(foreground: dynamic(light: 0x8C6235, dark: 0xDAB38E), background: dynamic(light: 0xF8EFE5, dark: 0x45382D))
    ]

    /// Ton kolekcji dla dowolnego (również ujemnego) indeksu.
    static func collectionTone(_ index: Int) -> ToneColors {
        collectionTones[safeIndex(index, count: collectionTones.count)]
    }

    /// Stabilny ton kolekcji na podstawie nazwy (ta sama nazwa → zawsze ten sam kolor,
    /// niezależnie od uruchomienia — nie używamy `hashValue`, który jest losowany per proces).
    static func collectionTone(named name: String) -> ToneColors {
        var hash: UInt32 = 5381
        for scalar in name.unicodeScalars {
            hash = (hash &* 33) &+ scalar.value
        }
        return collectionTone(Int(hash % UInt32(collectionTones.count)))
    }

    // MARK: Pomocnicze

    static func safeIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let remainder = index % count
        return remainder >= 0 ? remainder : remainder + count
    }

    /// Kolor dynamiczny jasny/ciemny z wartości 0xRRGGBB.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(fluentHex: dark) : UIColor(fluentHex: light)
        })
    }
}

/// Para kolorów tekst/tło dla odznak, chipów i ikon kategorii.
struct ToneColors: Hashable {
    let foreground: Color
    let background: Color
}

extension ToneColors {
    static let accent = ToneColors(foreground: Palette.accentSoftInk, background: Palette.accentSoft)
    static let neutral = ToneColors(foreground: Palette.inkSecondary, background: Palette.surfaceMuted)
    static let success = ToneColors(foreground: Palette.success, background: Palette.successSoft)
    static let warning = ToneColors(foreground: Palette.warning, background: Palette.warningSoft)
    static let danger = ToneColors(foreground: Palette.danger, background: Palette.dangerSoft)
    static let info = ToneColors(foreground: Palette.info, background: Palette.infoSoft)
}

extension UIColor {
    /// Kolor z wartości 0xRRGGBB (sRGB). Nazwa z prefiksem, by nie kolidować z innymi rozszerzeniami.
    fileprivate convenience init(fluentHex hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
