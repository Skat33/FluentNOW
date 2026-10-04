import SwiftUI

/// Siatka odstępów (wielokrotności 4 pt). Używaj wyłącznie tych wartości.
enum Spacing {
    /// 4 — odstęp ikona–tekst w małych elementach, wnętrze odznaki.
    static let xxs: CGFloat = 4
    /// 8 — odstęp między powiązanymi elementami (etykieta–wartość, chipy).
    static let xs: CGFloat = 8
    /// 12 — odstęp między wierszami w karcie.
    static let s: CGFloat = 12
    /// 16 — wewnętrzny margines karty, margines ekranu na iPhonie.
    static let m: CGFloat = 16
    /// 24 — odstęp między sekcjami ekranu.
    static let l: CGFloat = 24
    /// 32 — duże odstępy (stan pusty, karta hero).
    static let xl: CGFloat = 32
    /// 48 — oddech nad/pod ilustracją stanu pustego.
    static let xxl: CGFloat = 48

    /// Margines poziomy treści ekranu.
    static let screen: CGFloat = 16
    /// Maksymalna szerokość czytelnej kolumny tekstu (iPad / poziomo).
    static let readableWidth: CGFloat = 640
}

/// Promienie zaokrągleń (zawsze `style: .continuous`).
enum Radius {
    /// 6 — odznaki CEFR, małe znaczniki.
    static let badge: CGFloat = 6
    /// 10 — chipy prostokątne, pola tekstowe w karcie.
    static let small: CGFloat = 10
    /// 14 — przyciski (iOS 17–25), kafelki statystyk wewnątrz kart.
    static let medium: CGFloat = 14
    /// 20 — karty.
    static let card: CGFloat = 20
    /// 28 — karta hero (sesja), arkusze własne.
    static let hero: CGFloat = 28
}

/// Minimalne rozmiary zgodne z HIG.
enum HitTarget {
    /// Minimalny bok obszaru dotyku.
    static let minimum: CGFloat = 44
    /// Wysokość głównego przycisku na iOS 17–25.
    static let buttonHeight: CGFloat = 50
}

/// Cienie. Na ciemnym tle cienie są niewidoczne — tam separację daje kolor powierzchni i obrys.
enum Elevation {
    case flat
    /// Karta na tle ekranu.
    case card
    /// Element unoszący się (przeciągana fiszka, pływający przycisk).
    case raised

    var color: Color {
        switch self {
        case .flat: return .clear
        case .card: return Elevation.shadowColor.opacity(0.06)
        case .raised: return Elevation.shadowColor.opacity(0.14)
        }
    }

    var radius: CGFloat {
        switch self {
        case .flat: return 0
        case .card: return 10
        case .raised: return 20
        }
    }

    var y: CGFloat {
        switch self {
        case .flat: return 0
        case .card: return 3
        case .raised: return 10
        }
    }

    /// Fioletowawy cień jak na stronie (`#6033be`), w trybie ciemnym czarny.
    private static let shadowColor = Palette.dynamic(light: 0x4A2A9E, dark: 0x000000)
}

extension View {
    /// Cień z systemu `Elevation`.
    func fluentShadow(_ elevation: Elevation) -> some View {
        shadow(color: elevation.color, radius: elevation.radius, x: 0, y: elevation.y)
    }
}
