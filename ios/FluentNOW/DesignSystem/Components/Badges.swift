import SwiftUI

/// Odznaka poziomu CEFR (A1–C2). Nieznany poziom → szara odznaka z oryginalnym tekstem;
/// pusty poziom → nic nie jest rysowane.
///
/// ```swift
/// LevelBadge(level: word.level)
/// ```
struct LevelBadge: View {
    private let level: String

    init(level: String) {
        self.level = level
    }

    var body: some View {
        let trimmed = level.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let tone = CEFRTone.tone(for: trimmed)
            Text(CEFRTone.normalized(trimmed) ?? trimmed)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(tone.foreground)
                .padding(.horizontal, Spacing.xs - 2)
                .padding(.vertical, 2)
                .background(tone.background, in: RoundedRectangle(cornerRadius: Radius.badge, style: .continuous))
                .accessibilityLabel(Text("Poziom \(CEFRTone.normalized(trimmed) ?? trimmed)"))
        }
    }
}

/// Chip/etykieta: tag, filtr, kolekcja, część mowy.
///
/// ```swift
/// TagChip("rzeczownik")                                   // etykieta
/// TagChip("Lotnisko", systemImage: "airplane", tone: Palette.collectionTone(named: "Lotnisko"))
/// TagChip("Trudne", isSelected: filter.hard) { filter.hard.toggle() }   // filtr
/// ```
struct TagChip: View {
    private let title: String
    private let systemImage: String?
    private let tone: ToneColors
    private let isSelected: Bool
    private let action: (() -> Void)?

    /// Etykieta statyczna.
    init(_ title: String, systemImage: String? = nil, tone: ToneColors = .neutral) {
        self.title = title
        self.systemImage = systemImage
        self.tone = tone
        self.isSelected = false
        self.action = nil
    }

    /// Chip wybieralny (filtr). Zaznaczony = tło akcentu.
    init(_ title: String, systemImage: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.tone = .accent
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        if let action {
            Button(action: action) {
                chipLabel(foreground: isSelected ? Palette.onAccent : Palette.ink,
                          background: isSelected ? Palette.accentFill : Palette.surfaceMuted)
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .fluentSensoryFeedback(FluentHaptic.selection, trigger: isSelected)
        } else {
            chipLabel(foreground: tone.foreground, background: tone.background)
        }
    }

    private func chipLabel(foreground: Color, background: Color) -> some View {
        HStack(spacing: Spacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(title)
                .lineLimit(1)
        }
        .font(.system(.footnote, design: .default, weight: .medium))
        .foregroundStyle(foreground)
        .padding(.horizontal, Spacing.s - 2)
        .padding(.vertical, Spacing.xxs + 2)
        .background(background, in: Capsule())
    }
}

#Preview("Odznaki i chipy") {
    VStack(alignment: .leading, spacing: Spacing.m) {
        HStack {
            ForEach(CEFRTone.levels, id: \.self) { LevelBadge(level: $0) }
            LevelBadge(level: "?")
        }
        HStack {
            TagChip("rzeczownik")
            TagChip("Lotnisko", systemImage: "airplane", tone: Palette.collectionTone(named: "Lotnisko"))
            TagChip("formalne", tone: .warning)
        }
        HStack {
            TagChip("Wszystkie", isSelected: true) {}
            TagChip("Trudne", systemImage: "flame", isSelected: false) {}
            TagChip("Archiwum", isSelected: false) {}
        }
    }
    .padding(Spacing.screen)
    .background(Palette.background)
}
