import SwiftUI

/// Wybór motywu w Ustawieniach (system/jasny/ciemny), jak `theme` na stronie.
/// Zastosowanie: `.preferredColorScheme(appearance.colorScheme)` na korzeniu sceny.
enum AppAppearance: String, CaseIterable, Identifiable, Hashable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Jak w systemie"
        case .light: return "Jasny"
        case .dark: return "Ciemny"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    /// `nil` = podążaj za systemem.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
