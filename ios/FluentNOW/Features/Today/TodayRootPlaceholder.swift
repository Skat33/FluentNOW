import SwiftUI

/// ZAŚLEPKA (design-shell) — fala 2 zastąpi ją ekranem Dzisiaj. Pokazuje docelowy układ:
/// fioletowa karta sesji z pierścieniem celu, kafelki statystyk, sekcje.
struct TodayRootPlaceholder: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                TodayHeroPlaceholder {
                    router.startStudy(.daily)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
                    StatTile(title: "Powtórki na dziś", value: "0", systemImage: "arrow.clockwise")
                    StatTile(title: "Seria", value: "0 dni", systemImage: "flame", tone: .warning)
                }
                SectionHeader("Twoje kolekcje", actionTitle: "Wszystkie") {
                    router.openLibrary(.collections)
                }
                EmptyStateView(
                    systemImage: "square.stack.3d.up",
                    title: "Brak kolekcji",
                    message: "Dodaj temat słówek, a kolekcja powstanie automatycznie.",
                    actionTitle: "Przeglądaj tematy"
                ) {
                    router.openLibrary(.topics)
                }
            }
            .padding(Spacing.screen)
        }
        .navigationTitle("Dzisiaj")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { QuickAddButton() }
        }
    }
}

/// Fioletowa karta sesji (wzór dla ui-library).
private struct TodayHeroPlaceholder: View {
    let onStart: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Sesja na dziś")
                    .fluentEyebrow()
                    .foregroundStyle(Palette.heroInkSecondary)
                Text("Zaczynamy?")
                    .font(FluentFont.heroTitle)
                    .foregroundStyle(Palette.onAccent)
                Text("Około 10 minut · powtórki i nowe słowa")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.heroInkSecondary)
                Button(action: onStart) {
                    Label("Zaczynam naukę", systemImage: "play.fill")
                        .font(FluentFont.button)
                        .foregroundStyle(Palette.accentFill)
                        .padding(.horizontal, Spacing.m)
                        .frame(minHeight: HitTarget.minimum)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, Spacing.xs)
            }
            Spacer(minLength: 0)
            ProgressRing(
                progress: 0.3,
                lineWidth: 8,
                tint: Palette.heroRingProgress,
                track: Palette.heroRingTrack,
                accessibilityLabel: "Dzienny cel"
            ) {
                VStack(spacing: 0) {
                    Text("3")
                        .font(FluentFont.numberMedium)
                        .foregroundStyle(Palette.onAccent)
                    Text("z 10")
                        .font(FluentFont.caption)
                        .foregroundStyle(Palette.heroInkSecondary)
                }
            }
            .frame(width: 96, height: 96)
        }
        .padding(Spacing.l)
        .background(HeroBackground())
        .clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
        .fluentShadow(.raised)
    }
}

#Preview("Dzisiaj — zaślepka") {
    NavigationStack {
        TodayRootPlaceholder()
    }
    .environment(AppRouter())
}
