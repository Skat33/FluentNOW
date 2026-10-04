import SwiftUI

/// Wizualna tożsamość pięciu umiejętności znaczenia (kolor, ikona, polska nazwa).
///
/// Surowe wartości są identyczne z kluczami `Skill` strony / FluentKit
/// (`recognition`, `recall`, `spelling`, `listening`, `usage`), więc mapowanie
/// z modelu to `SkillTone(rawValue: skill.rawValue)`. Design system celowo nie importuje FluentKit.
enum SkillTone: String, CaseIterable, Identifiable, Hashable {
    case recognition
    case recall
    case spelling
    case listening
    case usage

    var id: String { rawValue }

    /// Nazwa jak na stronie (`skillNames`).
    var title: String {
        switch self {
        case .recognition: return "Rozpoznawanie"
        case .recall: return "Przypominanie"
        case .spelling: return "Pisownia"
        case .listening: return "Słuchanie"
        case .usage: return "Użycie w zdaniu"
        }
    }

    var systemImage: String {
        switch self {
        case .recognition: return "eye"
        case .recall: return "brain.head.profile"
        case .spelling: return "textformat.abc"
        case .listening: return "ear"
        case .usage: return "text.quote"
        }
    }

    /// Kolor grafiki (pasek, punkt wykresu) — ≥ 3:1 na powierzchni w obu trybach.
    var color: Color {
        switch self {
        case .recognition: return SkillTone.recognitionColor
        case .recall: return SkillTone.recallColor
        case .spelling: return SkillTone.spellingColor
        case .listening: return SkillTone.listeningColor
        case .usage: return SkillTone.usageColor
        }
    }

    private static let recognitionColor = Palette.dynamic(light: 0x7A55C4, dark: 0xB79AF0)
    private static let recallColor = Palette.dynamic(light: 0x4F74AD, dark: 0x93B3E6)
    private static let spellingColor = Palette.dynamic(light: 0xA87437, dark: 0xE2B47F)
    private static let listeningColor = Palette.dynamic(light: 0x3F8670, dark: 0x86CDB2)
    private static let usageColor = Palette.dynamic(light: 0xA85C74, dark: 0xE7A2BA)
}

/// Kolorystyka poziomów CEFR: A — zieleń, B — niebieski/fiolet, C — bursztyn.
enum CEFRTone {
    static let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]

    /// Normalizuje zapis poziomu („b1 ”, „B1”) do „B1”; nieznany → `nil`.
    static func normalized(_ level: String) -> String? {
        let value = level.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return levels.contains(value) ? value : nil
    }

    static func tone(for level: String) -> ToneColors {
        guard let value = normalized(level), let first = value.first else { return .neutral }
        switch first {
        case "A": return .success
        case "B": return .info
        case "C": return .warning
        default: return .neutral
        }
    }
}
