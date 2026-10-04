import SwiftUI

/// Okrągły przycisk odtwarzania wymowy. Tylko UI — akcję (SpeechService) wstrzykuje ekran.
///
/// ```swift
/// SpeakButton(isSpeaking: speech.isSpeaking) { speech.speak(word.en) }
/// SpeakButton(style: .slow) { speech.speak(word.en, slow: true) }   // wolniej (żółw)
/// ```
struct SpeakButton: View {
    enum Style: Hashable {
        /// Zwykłe tempo.
        case normal
        /// Wolne tempo.
        case slow
    }

    enum Size: Hashable {
        /// 32 pt grafiki, obszar dotyku 44 pt (wiersz listy).
        case small
        /// 44 pt (fiszka, karta).
        case regular
        /// 64 pt (dyktando).
        case large

        var diameter: CGFloat {
            switch self {
            case .small: return 32
            case .regular: return 44
            case .large: return 64
            }
        }

        var font: Font {
            switch self {
            case .small: return .system(.footnote, design: .default, weight: .semibold)
            case .regular: return .system(.body, design: .default, weight: .semibold)
            case .large: return .system(.title2, design: .default, weight: .semibold)
            }
        }
    }

    private let style: Style
    private let size: Size
    private let isSpeaking: Bool
    private let accessibilityText: String
    private let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        style: Style = .normal,
        size: Size = .regular,
        isSpeaking: Bool = false,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.style = style
        self.size = size
        self.isSpeaking = isSpeaking
        self.accessibilityText = accessibilityLabel ?? (style == .slow ? "Odtwórz wolniej" : "Odtwórz wymowę")
        self.action = action
    }

    private var systemImage: String {
        switch style {
        case .normal: return "speaker.wave.2.fill"
        case .slow: return "tortoise.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(size.font)
                .symbolEffect(.variableColor.iterative, isActive: isSpeaking && !reduceMotion && style == .normal)
                .foregroundStyle(Palette.accent)
                .frame(width: size.diameter, height: size.diameter)
                .fluentGlass(in: Circle(), tint: Palette.accentSoft, interactive: true)
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityValue(isSpeaking ? Text("Odtwarzanie") : Text(""))
    }
}

#Preview("Przycisk wymowy") {
    HStack(spacing: Spacing.l) {
        SpeakButton(size: .small) {}
        SpeakButton(isSpeaking: true) {}
        SpeakButton(style: .slow) {}
        SpeakButton(size: .large) {}
    }
    .padding(Spacing.screen)
    .background(Palette.background)
}
