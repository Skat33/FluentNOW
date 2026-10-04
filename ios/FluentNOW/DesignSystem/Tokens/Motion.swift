import SwiftUI

/// Ruch: krótkie, sprężyste animacje. Przy włączonym „Ogranicz ruch” animacje
/// przestrzenne (sprężyny, skalowanie, przesuwanie) zastępujemy przenikaniem lub brakiem animacji.
enum Motion {
    /// 0,18 s — reakcja na dotyk (naciśnięcie, zaznaczenie).
    static let tap = Animation.snappy(duration: 0.18)
    /// 0,3 s — zmiana stanu w obrębie ekranu (rozwinięcie, informacja zwrotna).
    static let standard = Animation.spring(duration: 0.3, bounce: 0.12)
    /// 0,45 s — przejście między zadaniami, pojawienie się karty.
    static let emphasized = Animation.spring(duration: 0.45, bounce: 0.18)
    /// 0,8 s — wypełnianie pierścienia/pasków postępu.
    static let progress = Animation.smooth(duration: 0.8)
    /// Zamiennik dla „Ogranicz ruch”: samo przenikanie.
    static let reducedFade = Animation.easeInOut(duration: 0.2)

    /// Animacja z uwzględnieniem „Ogranicz ruch” (`nil` = bez animacji).
    static func resolved(_ animation: Animation, reduceMotion: Bool, fallback: Animation? = nil) -> Animation? {
        reduceMotion ? fallback : animation
    }

    /// Przejście treści: przesunięcie + przenikanie lub (Ogranicz ruch) tylko przenikanie.
    static func contentTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

/// Animuje zmianę `value`, respektując „Ogranicz ruch”.
private struct FluentAnimationModifier<Value: Equatable>: ViewModifier {
    let animation: Animation
    let fallback: Animation?
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(Motion.resolved(animation, reduceMotion: reduceMotion, fallback: fallback), value: value)
    }
}

extension View {
    /// Jak `.animation(_:value:)`, ale przy „Ogranicz ruch” używa `fallback` (domyślnie brak animacji).
    func fluentAnimation<Value: Equatable>(_ animation: Animation = Motion.standard, fallback: Animation? = nil, value: Value) -> some View {
        modifier(FluentAnimationModifier(animation: animation, fallback: fallback, value: value))
    }
}
