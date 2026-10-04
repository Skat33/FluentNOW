import SwiftUI

/// Pewność odpowiedzi 1–3 (jak na stronie: „Niepewnie / Całkiem dobrze / Bardzo pewnie”).
/// `rawValue` to wartość przekazywana do algorytmu powtórek (FluentKit `confidence: Int`).
enum ConfidenceLevel: Int, CaseIterable, Identifiable, Hashable {
    case unsure = 1
    case fair = 2
    case sure = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .unsure: return "Niepewnie"
        case .fair: return "Całkiem dobrze"
        case .sure: return "Bardzo pewnie"
        }
    }

    var systemImage: String {
        switch self {
        case .unsure: return "questionmark.circle"
        case .fair: return "hand.thumbsup"
        case .sure: return "checkmark.seal"
        }
    }

    /// Bezpieczne mapowanie z liczby (spoza 1…3 → `.fair`, domyślna wartość strony).
    init(clamping value: Int) {
        self = ConfidenceLevel(rawValue: value) ?? .fair
    }
}

/// Wybór pewności po odpowiedzi. Przy dużych rozmiarach tekstu układa opcje pionowo.
///
/// ```swift
/// @State private var confidence: ConfidenceLevel = .fair
/// ConfidencePicker(selection: $confidence)
/// // zapis: store.answer(..., confidence: confidence.rawValue)
/// ```
struct ConfidencePicker: View {
    @Binding private var selection: ConfidenceLevel
    private let title: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(selection: Binding<ConfidenceLevel>, title: String? = "Na ile czujesz się pewnie?") {
        self._selection = selection
        self.title = title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let title {
                Text(title)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
            }
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Spacing.xxs))
                : AnyLayout(HStackLayout(spacing: Spacing.xxs))
            layout {
                ForEach(ConfidenceLevel.allCases) { level in
                    ConfidenceOption(level: level, isSelected: level == selection) {
                        selection = level
                    }
                }
            }
            .padding(Spacing.xxs)
            .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .sensoryFeedback(FluentHaptic.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title ?? "Pewność odpowiedzi"))
    }
}

private struct ConfidenceOption: View {
    let level: ConfidenceLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(level.title)
                .font(.system(.subheadline, design: .default, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Palette.accentSoftInk : Palette.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
                .padding(.horizontal, Spacing.xxs)
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                            .fill(Palette.surfaceElevated)
                            .overlay {
                                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                    .strokeBorder(Palette.accent.opacity(0.5), lineWidth: 1.5)
                            }
                            .fluentShadow(.card)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ConfidencePickerPreviewDemo: View {
    @State private var confidence: ConfidenceLevel = .fair

    var body: some View {
        VStack(spacing: Spacing.l) {
            ConfidencePicker(selection: $confidence)
            Text("Wybrano: \(confidence.rawValue)")
        }
        .padding(Spacing.screen)
        .background(Palette.background)
    }
}

#Preview("Wybór pewności") {
    ConfidencePickerPreviewDemo()
}
