import SwiftUI

// Liquid Glass (iOS 26) z eleganckim zamiennikiem dla iOS 17–25.
//
// Zweryfikowane w dokumentacji Apple (SDK iOS 26):
//   func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape()) -> some View
//   struct Glass { static var regular, clear, identity; func tint(_ color: Color?) -> Glass; func interactive(_ isEnabled: Bool = true) -> Glass }
//   struct GlassEffectContainer<Content: View> { init(spacing: CGFloat? = nil, content: () -> Content) }
//
// Zasada HIG: szkło jest dla warstwy nawigacji i kontrolek unoszących się nad treścią
// (pływające przyciski, paski narzędzi, odtwarzacz), NIE dla samej treści (karty listy).

/// Szkło na iOS 26, materiał `.ultraThinMaterial` + obrys na starszych systemach.
private struct FluentGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(Glass.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content
                .background {
                    ZStack {
                        shape.fill(.ultraThinMaterial)
                        if let tint {
                            shape.fill(tint.opacity(0.22))
                        }
                    }
                }
                .overlay {
                    shape.stroke(Palette.separator.opacity(0.7), lineWidth: 0.5)
                }
        }
    }
}

/// Styl tła karty treści.
enum CardStyle: Hashable {
    /// Jednolita powierzchnia z obrysem i delikatnym cieniem (domyślnie — treść).
    case solid
    /// Wyciszona powierzchnia (karta zagnieżdżona w karcie, sekcja drugorzędna).
    case muted
    /// Delikatnie zabarwiona powierzchnia (np. karta wyróżniona akcentem).
    case tinted(ToneColors)
    /// Szkło (tylko elementy unoszące się nad treścią, np. panel nad obrazem/gradientem).
    case glass
}

private struct FluentCardBackgroundModifier: ViewModifier {
    let style: CardStyle
    let cornerRadius: CGFloat

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .solid:
            content
                .background(Palette.surface, in: shape)
                .overlay { shape.strokeBorder(Palette.separator, lineWidth: 1) }
                .fluentShadow(.card)
        case .muted:
            content.background(Palette.surfaceMuted, in: shape)
        case .tinted(let tone):
            content
                .background(tone.background, in: shape)
                .overlay { shape.strokeBorder(tone.foreground.opacity(0.18), lineWidth: 1) }
        case .glass:
            content.modifier(FluentGlassModifier(shape: shape, tint: nil, interactive: false))
        }
    }
}

extension View {
    /// Szkło w kształcie zaokrąglonego prostokąta (`Radius.card`).
    func fluentGlass(tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(FluentGlassModifier(
            shape: RoundedRectangle(cornerRadius: Radius.card, style: .continuous),
            tint: tint,
            interactive: interactive
        ))
    }

    /// Szkło w podanym kształcie (np. `Capsule()`, `Circle()`).
    func fluentGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(FluentGlassModifier(shape: shape, tint: tint, interactive: interactive))
    }

    /// Tło karty treści. Domyślnie jednolite (czytelność ponad efekt), `.glass` tylko dla warstwy pływającej.
    func fluentCardBackground(_ style: CardStyle = .solid, cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(FluentCardBackgroundModifier(style: style, cornerRadius: cornerRadius))
    }
}

/// Grupuje elementy ze szkłem, by na iOS 26 łączyły się i morfowały (`GlassEffectContainer`).
/// Na iOS 17–25 po prostu zwraca treść.
struct FluentGlassContainer<Content: View>: View {
    private let spacing: CGFloat?
    private let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

#Preview("Szkło i karty") {
    ScrollView {
        VStack(spacing: Spacing.m) {
            Text("Karta jednolita")
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fluentCardBackground()
            Text("Karta wyciszona")
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fluentCardBackground(.muted)
            Text("Karta zabarwiona")
                .padding(Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fluentCardBackground(.tinted(.accent))
            ZStack {
                HeroBackground()
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
                FluentGlassContainer(spacing: Spacing.s) {
                    HStack(spacing: Spacing.s) {
                        Label("Szkło", systemImage: "sparkles")
                            .padding(.horizontal, Spacing.m)
                            .padding(.vertical, Spacing.s)
                            .fluentGlass(in: Capsule(), interactive: true)
                        Image(systemName: "speaker.wave.2.fill")
                            .frame(width: 44, height: 44)
                            .fluentGlass(in: Circle(), tint: Palette.accentFill, interactive: true)
                    }
                }
            }
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
}
