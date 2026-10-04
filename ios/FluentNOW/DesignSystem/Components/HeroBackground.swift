import SwiftUI

/// Tło fioletowej karty sesji („Zaczynam naukę”).
/// iOS 18+: delikatny `MeshGradient`; iOS 17: gradient liniowy jak na stronie (110°).
struct HeroBackground: View {
    var body: some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2<Float>(0, 0), SIMD2<Float>(0.5, 0), SIMD2<Float>(1, 0),
                    SIMD2<Float>(0, 0.5), SIMD2<Float>(0.62, 0.42), SIMD2<Float>(1, 0.5),
                    SIMD2<Float>(0, 1), SIMD2<Float>(0.5, 1), SIMD2<Float>(1, 1)
                ],
                colors: [
                    Palette.heroStart, Palette.heroStart, Palette.heroEnd,
                    Palette.heroStart, Palette.heroGlow, Palette.heroEnd,
                    Palette.heroStart, Palette.heroEnd, Palette.heroEnd
                ]
            )
        } else {
            LinearGradient(
                colors: [Palette.heroStart, Palette.heroEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

#Preview("Tło karty sesji") {
    HeroBackground()
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
        .padding()
}
