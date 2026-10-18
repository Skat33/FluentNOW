import SwiftUI
import FluentKit

/// Pełna analiza w „Postępach”: poziom z zakresem i uczciwym opisem pewności, mocne i słabe
/// umiejętności, tempo nauki, obszary tematyczne oraz wejście do „Polecanych słówek”.
/// Dane: `LearnerAnalyzer.analyze` liczone w `StatsSnapshot` (poza głównym wątkiem).
struct StatsAnalysisSection: View {
    let analysis: LearnerAnalysis

    var body: some View {
        StatsAnalysisLevelCard(level: analysis.level)
        StatsAnalysisSkillsCard(analysis: analysis)
        StatsAnalysisPaceCard(pace: analysis.pace)
        StatsAnalysisAreasCard(analysis: analysis)
        StatsUsefulWordsLink()
    }
}

/// Poziom: zakres, cel, opis pewności.
private struct StatsAnalysisLevelCard: View {
    let level: LevelAssessment

    var body: some View {
        Card {
            SectionHeader("Szacowany poziom")
            HStack(alignment: .center, spacing: Spacing.s) {
                Text(level.rangeText)
                    .font(FluentFont.numberLarge)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(AnalysisDisplayText.capitalized(level.confidence.namePl))
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.ink)
                    if level.confidence != .insufficient {
                        Text("Następny cel: \(level.targetLevel)")
                            .font(FluentFont.subheadline)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
            Text(level.descriptionPl)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(LevelAssessment.scopeNotePl)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Mocne i słabe strony (+ niećwiczone umiejętności).
private struct StatsAnalysisSkillsCard: View {
    let analysis: LearnerAnalysis

    var body: some View {
        if !analysis.skills.isEmpty || !analysis.untestedSkills.isEmpty {
            Card {
                SectionHeader("Mocne i słabe strony", subtitle: "Porównanie umiejętności ćwiczonych na co najmniej \(LearnerAnalyzer.minSkillMeanings) znaczeniach.")
                StatsSkillGroup(title: "Mocne strony", systemImage: "hand.thumbsup", tone: .success, skills: analysis.strongSkills)
                StatsSkillGroup(title: "Do poprawy", systemImage: "wrench.adjustable", tone: .warning, skills: analysis.weakSkills)
                if let note = StatsAnalysisText.skillsNote(analysis) {
                    StatsAnalysisNote(text: note)
                }
                if let untested = StatsAnalysisText.untested(analysis) {
                    StatsAnalysisNote(text: untested)
                }
            }
        }
    }
}

/// Drobny opis pod kartą.
private struct StatsAnalysisNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(FluentFont.footnote)
            .foregroundStyle(Palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Grupa umiejętności z paskami.
private struct StatsSkillGroup: View {
    let title: String
    let systemImage: String
    let tone: ToneColors
    let skills: [SkillInsight]

    var body: some View {
        if !skills.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Label(title, systemImage: systemImage)
                    .font(FluentFont.subheadline.weight(.semibold))
                    .foregroundStyle(tone.foreground)
                ForEach(skills) { (insight: SkillInsight) in
                    StatsSkillInsightRow(insight: insight)
                }
            }
        }
    }
}

private struct StatsSkillInsightRow: View {
    let insight: SkillInsight

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            SkillBar(title: insight.skill.namePl, score: Double(insight.average))
            Text(StatsAnalysisText.skillCaption(insight))
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
    }
}

/// Tempo: nowe znaczenia w 4 tygodniach, regularność, opanowane.
private struct StatsAnalysisPaceCard: View {
    let pace: LearningPace

    var body: some View {
        Card {
            SectionHeader("Tempo nauki", subtitle: AnalysisDisplayText.capitalized(pace.summaryPl))
            HStack(alignment: .bottom, spacing: Spacing.xs) {
                ForEach(pace.newMeaningsByWeek.indices, id: \.self) { (index: Int) in
                    StatsPaceBar(
                        value: pace.newMeaningsByWeek[index],
                        maxValue: pace.newMeaningsByWeek.max() ?? 0,
                        label: StatsAnalysisText.weekLabel(index: index, count: pace.newMeaningsByWeek.count)
                    )
                }
            }
            .frame(height: 96)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(StatsAnalysisText.paceAccessibility(pace)))
            HStack(spacing: Spacing.s) {
                StatTile(title: "Regularność (14 dni)", value: "\(pace.activeDays)/\(pace.windowDays)", systemImage: "calendar",
                         caption: pace.regularity.namePl, tone: .info)
                StatTile(title: "Opanowane w 4 tyg.", value: "\(pace.masteredRecently)", systemImage: "checkmark.seal",
                         caption: nil, tone: .success)
            }
        }
    }
}

/// Słupek tygodnia (bez Swift Charts — 4 wartości).
private struct StatsPaceBar: View {
    let value: Int
    let maxValue: Int
    let label: String

    private var fraction: CGFloat {
        guard maxValue > 0 else { return 0 }
        return CGFloat(value) / CGFloat(maxValue)
    }

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text("\(value)")
                .font(FluentFont.numberSmall)
                .foregroundStyle(Palette.ink)
            GeometryReader { (proxy: GeometryProxy) in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
                        .fill(Palette.accent)
                        .frame(height: max(4, proxy.size.height * fraction))
                }
            }
            Text(label)
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Obszary tematyczne: największe, najmocniejszy i najsłabszy.
private struct StatsAnalysisAreasCard: View {
    let analysis: LearnerAnalysis

    var body: some View {
        if !analysis.topicAreas.isEmpty {
            Card {
                SectionHeader("Obszary tematyczne", subtitle: StatsAnalysisText.areasSubtitle(analysis))
                ForEach(analysis.topicAreas) { (area: TopicArea) in
                    StatsAreaRow(area: area)
                }
            }
        }
    }
}

private struct StatsAreaRow: View {
    let area: TopicArea

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text(area.name)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Spacing.xs)
                Text("\(LibraryText.meanings(area.meanings)) · \(area.averageMastery)%")
                    .font(FluentFont.numberSmall)
                    .foregroundStyle(Palette.inkSecondary)
            }
            LinearProgressBar(progress: Double(area.averageMastery) / 100)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Wejście do pełnej listy „Polecane słówka” (Słownik → segment „Polecane”).
private struct StatsUsefulWordsLink: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Card(style: .tinted(.accent)) {
            Text("Polecane słówka")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
            Text("Często używane słowa z bazy, dopasowane do Twojego poziomu i tematów. Dodasz je jednym dotknięciem.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                router.openLibrary(.recommended)
            } label: {
                UsefulWordsMoreLabel(title: "Zobacz propozycje")
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Otwiera Słownik, segment Polecane"))
        }
    }
}

enum StatsAnalysisText {
    /// „Średnio 67% · skuteczność 92% (30 dni)”.
    static func skillCaption(_ insight: SkillInsight) -> String {
        var text = "Średnio \(insight.average)% w \(LibraryText.meanings(insight.meanings))"
        if let accuracy = insight.recentAccuracy {
            text += " · skuteczność \(accuracy)% w ostatnich 30 dniach"
        }
        return text
    }

    /// „3 tyg. temu” … „Ten tydz.”.
    static func weekLabel(index: Int, count: Int) -> String {
        let weeksAgo = count - 1 - index
        switch weeksAgo {
        case 0: return "Ten tydz."
        case 1: return "Tydz. temu"
        default: return "\(weeksAgo) tyg. temu"
        }
    }

    static func skillsNote(_ analysis: LearnerAnalysis) -> String? {
        guard analysis.strongSkills.isEmpty && analysis.weakSkills.isEmpty else { return nil }
        if analysis.skills.count < 2 {
            return "Za mało danych, żeby porównać umiejętności — poćwicz różne typy zadań."
        }
        return "Umiejętności są na podobnym poziomie — bez wyraźnie słabszej strony."
    }

    static func untested(_ analysis: LearnerAnalysis) -> String? {
        guard !analysis.untestedSkills.isEmpty else { return nil }
        let names = analysis.untestedSkills.map { (skill: Skill) -> String in skill.namePl }
        return "Jeszcze nie ćwiczone: \(names.joined(separator: ", "))."
    }

    static func paceAccessibility(_ pace: LearningPace) -> String {
        let values = pace.newMeaningsByWeek.map { (value: Int) -> String in String(value) }
        return "Nowe znaczenia w kolejnych tygodniach, od najstarszego: \(values.joined(separator: ", "))"
    }

    static func areasSubtitle(_ analysis: LearnerAnalysis) -> String? {
        var parts: [String] = []
        if let strongest = analysis.strongestArea {
            parts.append("Najlepiej: \(strongest.name)")
        }
        if let weakest = analysis.weakestArea {
            parts.append("Najwięcej do zrobienia: \(weakest.name)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
