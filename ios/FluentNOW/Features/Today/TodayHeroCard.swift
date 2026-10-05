import SwiftUI
import FluentKit

/// Fioletowa karta sesji z pierścieniem dziennego celu: „Zaczynam naukę” jednym dotknięciem
/// (codzienna mieszanka) albo „Wznów sesję”, gdy jakaś czeka.
struct TodayHeroCard: View {
    let goal: DailyGoalProgress
    let dueCount: Int
    let newCount: Int
    let resume: TodayResume?

    @Environment(AppRouter.self) private var router
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var title: String {
        if resume != nil { return "Twoja sesja czeka" }
        if goal.isReached { return "Cel osiągnięty" }
        if dueCount > 0 { return "Czas na powtórkę" }
        return "Zaczynamy?"
    }

    private var subtitle: String {
        if let resume {
            return "Ukończono \(resume.done) z \(resume.total) zadań. Kolejność jest zapisana."
        }
        if goal.isReached {
            return "Świetna robota. Krótka sesja ponad plan też się liczy."
        }
        var parts: [String] = []
        if dueCount > 0 { parts.append("\(dueCount) do powtórki") }
        if newCount > 0 { parts.append(LibraryText.count(newCount, one: "nowe znaczenie", few: "nowe znaczenia", many: "nowych znaczeń")) }
        let detail = parts.isEmpty ? "powtórki i nowe słowa" : parts.joined(separator: " · ")
        return "Około 10 minut · \(detail)"
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Spacing.m))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Spacing.m))
        layout {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text("Sesja na dziś")
                    .fluentEyebrow()
                    .foregroundStyle(Palette.heroInkSecondary)
                Text(title)
                    .font(FluentFont.heroTitle)
                    .foregroundStyle(Palette.onAccent)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.heroInkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                TodayStartButton(title: resume == nil ? "Zaczynam naukę" : "Wznów sesję") {
                    router.startStudy(resume == nil ? .daily : .resumeLast)
                }
                .padding(.top, Spacing.xs)
            }
            Spacer(minLength: 0)
            TodayGoalRing(goal: goal)
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HeroBackground())
        .clipShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))
        .fluentShadow(.raised)
    }
}

/// Biały przycisk na fioletowej karcie (jedyna główna akcja ekranu).
private struct TodayStartButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "play.fill")
                .font(FluentFont.button)
                .foregroundStyle(Palette.accentFill)
                .padding(.horizontal, Spacing.m)
                .frame(minHeight: HitTarget.minimum)
                .background(Color.white, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TodayGoalRing: View {
    let goal: DailyGoalProgress

    var body: some View {
        ProgressRing(
            progress: goal.fraction,
            lineWidth: 8,
            tint: Palette.heroRingProgress,
            track: Palette.heroRingTrack,
            accessibilityLabel: "Dzienny cel: \(goal.done) z \(goal.goal) zadań"
        ) {
            VStack(spacing: 0) {
                Text("\(goal.done)")
                    .font(FluentFont.numberMedium)
                    .foregroundStyle(Palette.onAccent)
                    .contentTransition(.numericText())
                Text("z \(goal.goal)")
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.heroInkSecondary)
            }
        }
        .frame(width: 104, height: 104)
    }
}

/// Kafelki: powtórki, seria, słownik, opanowane.
struct TodayStatsGrid: View {
    let overview: StatsOverview

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
            StatTile(title: "Powtórki na dziś", value: "\(overview.dueMeanings)", systemImage: "arrow.clockwise",
                     caption: overview.newMeanings > 0 ? "+ \(overview.newMeanings) nowych" : nil)
            StatTile(title: "Seria", value: LibraryText.days(overview.streak), systemImage: "flame",
                     caption: overview.streak > 0 ? "nie przerywaj" : "zacznij dziś", tone: .warning)
            StatTile(title: "Słów w słowniku", value: "\(overview.wordCount)", systemImage: "books.vertical",
                     caption: LibraryText.meanings(overview.meaningCount), tone: .info)
            StatTile(title: "Opanowane znaczenia", value: "\(overview.masteredMeanings)", systemImage: "checkmark.seal",
                     caption: overview.totalAnswers > 0 ? "skuteczność \(overview.accuracy)%" : nil, tone: .success)
        }
    }
}
