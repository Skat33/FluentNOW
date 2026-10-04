import SwiftUI

/// Rodzaje przycisków aplikacji.
enum FluentButtonKind: Hashable {
    /// Główna akcja ekranu (jedna na ekran): fiolet, na iOS 26 `.glassProminent`.
    case primary
    /// Akcja drugorzędna: delikatny fiolet, na iOS 26 `.glass`.
    case secondary
    /// Akcja niszcząca (np. „Usuń kolekcję”) — czerwień, zawsze z potwierdzeniem.
    case destructive
}

/// Główny przycisk dla iOS 17–25: wypełnienie `accentFill`, biały tekst, skala przy naciśnięciu.
struct FluentPrimaryButtonStyle: ButtonStyle {
    var tint: Color = Palette.accentFill

    func makeBody(configuration: Configuration) -> some View {
        FluentFilledButtonBody(configuration: configuration, fill: tint, foreground: Palette.onAccent)
    }
}

/// Przycisk drugorzędny dla iOS 17–25: miękkie tło akcentu, fioletowy tekst.
struct FluentSecondaryButtonStyle: ButtonStyle {
    var tone: ToneColors = .accent

    func makeBody(configuration: Configuration) -> some View {
        FluentFilledButtonBody(configuration: configuration, fill: tone.background, foreground: tone.foreground)
    }
}

/// Wspólne ciało przycisków iOS 17–25 (osobny widok, aby móc czytać środowisko).
private struct FluentFilledButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    let foreground: Color

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(FluentFont.button)
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            .frame(minHeight: HitTarget.buttonHeight)
            .background(fill, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

/// Wybiera styl przycisku zależnie od systemu: iOS 26 → Liquid Glass, wcześniej własne style.
private struct FluentButtonStyleModifier: ViewModifier {
    let kind: FluentButtonKind

    @ViewBuilder
    func body(content: Content) -> some View {
        switch kind {
        case .primary:
            if #available(iOS 26.0, *) {
                content
                    .buttonStyle(.glassProminent)
                    .tint(Palette.accentFill)
                    .controlSize(.large)
            } else {
                content.buttonStyle(FluentPrimaryButtonStyle())
            }
        case .secondary:
            if #available(iOS 26.0, *) {
                content
                    .buttonStyle(.glass)
                    .tint(Palette.accent)
                    .controlSize(.large)
            } else {
                content.buttonStyle(FluentSecondaryButtonStyle())
            }
        case .destructive:
            if #available(iOS 26.0, *) {
                content
                    .buttonStyle(.glass)
                    .tint(Palette.danger)
                    .controlSize(.large)
            } else {
                content.buttonStyle(FluentSecondaryButtonStyle(tone: .danger))
            }
        }
    }
}

extension View {
    /// Styl przycisku FluentNOW (Liquid Glass na iOS 26, własny styl na iOS 17–25).
    func fluentButtonStyle(_ kind: FluentButtonKind = .primary) -> some View {
        modifier(FluentButtonStyleModifier(kind: kind))
    }
}

#Preview("Style przycisków") {
    VStack(spacing: Spacing.m) {
        Button("Zaczynam naukę") {}
            .fluentButtonStyle(.primary)
        Button("Pokaż podpowiedź") {}
            .fluentButtonStyle(.secondary)
        Button("Usuń kolekcję", role: .destructive) {}
            .fluentButtonStyle(.destructive)
        Button("Nieaktywny") {}
            .fluentButtonStyle(.primary)
            .disabled(true)
    }
    .padding(Spacing.screen)
    .background(Palette.background)
}
