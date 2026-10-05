import SwiftUI
import FluentKit

/// Korzeń karty „Postępy”. Kontrakt powłoki: inicjalizator bez argumentów, bez własnego `NavigationStack`.
/// Wszystkie liczby z `ProgressStatistics` (FluentKit), liczone poza `body` i poza głównym wątkiem.
struct StatsRootScreen: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var snapshot: StatsSnapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if let snapshot {
                    if snapshot.overview.meaningCount == 0 && snapshot.overview.totalAnswers == 0 {
                        EmptyStateView(
                            systemImage: "chart.bar.xaxis",
                            title: "Tu zobaczysz swój postęp",
                            message: "Dodaj słowa i zrób pierwszą sesję — wykresy pojawią się od razu.",
                            actionTitle: "Przeglądaj tematy"
                        ) {
                            router.openLibrary(.topics)
                        }
                    } else {
                        StatsContent(snapshot: snapshot)
                    }
                } else {
                    LoadingStateView("Liczę statystyki…")
                }
            }
            .frame(maxWidth: Spacing.readableWidth)
            .padding(Spacing.screen)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle("Postępy")
        .libraryNavigationDestinations()
        .task(id: store.revision) {
            let now = store.now()
            let computed = await store.compute { state in
                StatsSnapshot.make(state: state, now: now)
            }
            guard !Task.isCancelled else { return }
            snapshot = computed
        }
    }
}

private struct StatsContent: View {
    let snapshot: StatsSnapshot

    @Environment(AppRouter.self) private var router

    var body: some View {
        StatsOverviewGrid(overview: snapshot.overview)
        StatsLevelEstimateCard(estimate: snapshot.estimate)
        TodayWeekCard(week: snapshot.week, goal: snapshot.goal)
        StatsActivityCalendar(days: snapshot.calendar)
        StatsHardWordsCard(rows: snapshot.hardWords) {
            router.startStudy(.mistakes)
        }
        StatsSkillsCard(skills: snapshot.skills)
        StatsLevelsCard(levels: snapshot.levels)
        StatsGainsChart(gains: snapshot.gains)
        StatsForecastChart(forecast: snapshot.forecast)
        StatsExerciseTotalsCard(reading: snapshot.reading, practice: snapshot.practice)
    }
}

/// Liczby nagłówkowe.
private struct StatsOverviewGrid: View {
    let overview: StatsOverview

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
            StatTile(title: "Opanowane znaczenia", value: "\(overview.masteredMeanings)", systemImage: "checkmark.seal",
                     caption: "z \(overview.meaningCount)", tone: .success)
            StatTile(title: "Skuteczność", value: overview.totalAnswers > 0 ? "\(overview.accuracy)%" : "—",
                     systemImage: "target", caption: "\(overview.totalAnswers) odpowiedzi")
            StatTile(title: "Seria", value: LibraryText.days(overview.streak), systemImage: "flame", tone: .warning)
            StatTile(title: "Do powtórki", value: "\(overview.dueMeanings)", systemImage: "arrow.clockwise",
                     caption: overview.newMeanings > 0 ? "+ \(overview.newMeanings) nowych" : nil, tone: .info)
        }
    }
}

/// Szacowany poziom CEFR z uczciwym opisem pewności.
private struct StatsLevelEstimateCard: View {
    let estimate: LevelEstimate

    var body: some View {
        Card {
            SectionHeader("Szacowany poziom")
            HStack(spacing: Spacing.s) {
                Text(estimate.count > 0 ? estimate.level : "—")
                    .font(FluentFont.numberLarge)
                    .foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Następny cel: \(estimate.targetLevel)")
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.ink)
                    Text(StatsText.confidence(estimate))
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// „Warto do nich wrócić” — trudne słowa → sesja pomyłek.
private struct StatsHardWordsCard: View {
    let rows: [WordListRow]
    let onPractice: () -> Void

    var body: some View {
        if !rows.isEmpty {
            Card {
                SectionHeader("Warto do nich wrócić", subtitle: "Słowa z pomyłkami lub długimi odpowiedziami.")
                ForEach(rows) { row in
                    NavigationLink(value: WordRoute.detail(id: row.id)) {
                        HStack {
                            WordRowView(row: row)
                            Image(systemName: "chevron.right")
                                .font(FluentFont.footnote.weight(.semibold))
                                .foregroundStyle(Palette.inkTertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                PrimaryButton("Przećwicz pomyłki", systemImage: "lightbulb", action: onPractice)
            }
        }
    }
}

/// Średnie umiejętności („—” dla niećwiczonych).
private struct StatsSkillsCard: View {
    let skills: [SkillAverage]

    var body: some View {
        Card {
            SectionHeader("Umiejętności", subtitle: "Średnia ćwiczonych znaczeń")
            ForEach(SkillTone.allCases) { tone in
                SkillBar(skill: tone, score: score(for: tone))
            }
        }
    }

    private func score(for tone: SkillTone) -> Double? {
        guard let average = skills.first(where: { $0.skill.rawValue == tone.rawValue })?.average else { return nil }
        return Double(average)
    }
}

/// Postęp według poziomu CEFR.
private struct StatsLevelsCard: View {
    let levels: [LevelProgress]

    var body: some View {
        let visible = levels.filter { $0.meaningCount > 0 }
        if !visible.isEmpty {
            Card {
                SectionHeader("Postęp według poziomu")
                ForEach(visible) { level in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        HStack {
                            LevelBadge(level: level.level)
                            Text("\(level.mastered) z \(LibraryText.meanings(level.meaningCount)) opanowane")
                                .font(FluentFont.subheadline)
                                .foregroundStyle(Palette.ink)
                            Spacer(minLength: 0)
                            Text("\(level.average)%")
                                .font(FluentFont.numberSmall)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        LinearProgressBar(progress: Double(level.average) / 100,
                                          tint: CEFRTone.tone(for: level.level).foreground)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Wyniki czytania i gramatyki.
private struct StatsExerciseTotalsCard: View {
    let reading: ExerciseTotals
    let practice: ExerciseTotals

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
            StatTile(title: "Czytanie", value: StatsText.percent(reading.correct, of: reading.total),
                     systemImage: "book", caption: "ukończone teksty: \(reading.sets)", tone: .info)
            StatTile(title: "Gramatyka i idiomy", value: StatsText.percent(practice.correct, of: practice.total),
                     systemImage: "text.badge.checkmark", caption: "ukończone zestawy: \(practice.sets)", tone: .accent)
        }
    }
}

#Preview("Postępy") {
    NavigationStack {
        StatsRootScreen()
    }
    .fluentPreviewEnvironment()
}
