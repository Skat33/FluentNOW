import SwiftUI

/// Wiersz wyboru w kreatorze: ikona, tytuł, opis i znacznik (pole wyboru albo przycisk radiowy).
/// Wybór = kolor + znacznik + cecha `.isSelected` (nie sam kolor).
struct OnboardingOptionRow: View {
    let title: String
    let detail: String?
    let systemImage: String?
    let isSelected: Bool
    let isMultiple: Bool
    let action: () -> Void

    private var indicator: String {
        if isMultiple { return isSelected ? "checkmark.square.fill" : "square" }
        return isSelected ? "largecircle.fill.circle" : "circle"
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                OnboardingRowIcon(systemImage: systemImage, isSelected: isSelected)
                OnboardingRowText(title: title, detail: detail)
                Spacer(minLength: Spacing.xs)
                Image(systemName: indicator)
                    .font(FluentFont.headline)
                    .foregroundStyle(isSelected ? Palette.accent : Palette.inkTertiary)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, minHeight: HitTarget.minimum, alignment: .leading)
            .background(isSelected ? Palette.accentSoft : Palette.surface, in: shape)
            .overlay(shape.stroke(isSelected ? Palette.accent : Palette.separator, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct OnboardingRowIcon: View {
    let systemImage: String?
    let isSelected: Bool

    var body: some View {
        if let systemImage {
            Image(systemName: systemImage)
                .font(FluentFont.headline)
                .foregroundStyle(isSelected ? Palette.accent : Palette.inkSecondary)
                .frame(width: 28)
                .accessibilityHidden(true)
        }
    }
}

private struct OnboardingRowText: View {
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FluentFont.bodyEmphasized)
                .foregroundStyle(Palette.ink)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Kafelek w siatce zainteresowań.
struct OnboardingTile: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : systemImage)
                    .font(.system(.title2, design: .default, weight: .regular))
                    .foregroundStyle(isSelected ? Palette.onAccent : Palette.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(FluentFont.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Palette.onAccent : Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(isSelected ? Palette.accentFill : Palette.surface, in: shape)
            .overlay(shape.stroke(isSelected ? Palette.accentFill : Palette.separator, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
