import SwiftUI

/// Bezpieczne przycinanie ułamka postępu.
enum ProgressMath {
    /// Wartość przycięta do 0…1 (NaN/∞ → 0).
    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    /// Ułamek `done / total` odporny na dzielenie przez zero.
    static func fraction(_ done: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return clamped(Double(done) / Double(total))
    }
}

/// Animowany pierścień postępu (dzienny cel). Wartość spoza 0…1 lub NaN jest bezpiecznie przycinana.
///
/// ```swift
/// ProgressRing(progress: Double(done) / Double(goal), accessibilityLabel: "Dzienny cel") {
///     VStack { Text("\(done)").font(FluentFont.numberLarge); Text("z \(goal) zadań") }
/// }
/// ProgressRing(progress: 0.4, lineWidth: 6)           // bez treści w środku
/// ```
struct ProgressRing<Center: View>: View {
    private let progress: Double
    private let lineWidth: CGFloat
    private let tint: Color
    private let track: Color
    private let accessibilityLabel: String
    private let center: Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: Double = 0

    init(
        progress: Double,
        lineWidth: CGFloat = 10,
        tint: Color = Palette.accent,
        track: Color = Palette.surfaceMuted,
        accessibilityLabel: String = "Postęp",
        @ViewBuilder center: () -> Center
    ) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.tint = tint
        self.track = track
        self.accessibilityLabel = accessibilityLabel
        self.center = center()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: displayed)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            center
                .padding(lineWidth)
        }
        .padding(lineWidth / 2)
        .onAppear { update(to: progress) }
        .onChange(of: progress) { _, newValue in
            update(to: newValue)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text("\(Int((ProgressMath.clamped(progress) * 100).rounded())) procent"))
    }

    private func update(to value: Double) {
        let target = ProgressMath.clamped(value)
        withAnimation(Motion.resolved(Motion.progress, reduceMotion: reduceMotion)) {
            displayed = target
        }
    }
}

extension ProgressRing where Center == EmptyView {
    /// Pierścień bez treści w środku.
    init(
        progress: Double,
        lineWidth: CGFloat = 10,
        tint: Color = Palette.accent,
        track: Color = Palette.surfaceMuted,
        accessibilityLabel: String = "Postęp"
    ) {
        self.init(progress: progress, lineWidth: lineWidth, tint: tint, track: track, accessibilityLabel: accessibilityLabel) {
            EmptyView()
        }
    }
}

/// Poziomy pasek postępu (umiejętności, postęp sesji, postęp kolekcji).
struct LinearProgressBar: View {
    private let progress: Double
    private let tint: Color
    private let track: Color
    private let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(progress: Double, tint: Color = Palette.accent, track: Color = Palette.surfaceMuted, height: CGFloat = 8) {
        self.progress = progress
        self.tint = tint
        self.track = track
        self.height = height
    }

    var body: some View {
        let fraction = ProgressMath.clamped(progress)
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(tint)
                    .frame(width: fraction > 0 ? max(height, proxy.size.width * fraction) : 0)
            }
        }
        .frame(height: height)
        .animation(Motion.resolved(Motion.progress, reduceMotion: reduceMotion), value: fraction)
        .accessibilityHidden(true)
    }
}

private struct ProgressRingPreviewDemo: View {
    @State private var done = 6
    private let goal = 10

    var body: some View {
        VStack(spacing: Spacing.l) {
            ProgressRing(progress: ProgressMath.fraction(done, of: goal), lineWidth: 12, accessibilityLabel: "Dzienny cel") {
                VStack(spacing: Spacing.xxs) {
                    Text("(done)")
                        .font(FluentFont.numberLarge)
                        .contentTransition(.numericText())
                    Text("z (goal) zadań")
                        .font(FluentFont.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .frame(width: 180, height: 180)
            ZStack {
                HeroBackground()
                ProgressRing(progress: 0.7, lineWidth: 8, tint: Palette.heroRingProgress, track: Palette.heroRingTrack)
                    .frame(width: 90, height: 90)
            }
            .frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
            LinearProgressBar(progress: ProgressMath.fraction(done, of: goal))
            Stepper("Zadania: (done)", value: $done, in: 0...12)
        }
        .padding(Spacing.screen)
    }
}

#Preview("Pierścień i pasek") {
    ProgressRingPreviewDemo()
}
