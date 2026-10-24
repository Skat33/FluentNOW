import SwiftUI
import FluentKit

/// Historia testów w Postępach (FEEDBACK-6 K4): data, wynik, szacowany poziom. Ostatnie wpisy
/// najpierw; brak testów — sekcja się nie pokazuje.
struct StatsTestHistorySection: View {
    @Environment(LearningStore.self) private var store

    /// Widocznych wpisów (reszta jest tylko w liczniku).
    static let visibleCount = 6

    var body: some View {
        let entries = StatsTestHistorySection.recent(store.state.assessmentHistory)
        if !entries.isEmpty {
            Card(spacing: Spacing.s) {
                SectionHeader("Historia testów", subtitle: subtitle(total: store.state.assessmentHistory.count))
                ForEach(entries) { (entry: AssessmentHistoryEntry) in
                    StatsTestHistoryRow(entry: entry)
                }
            }
        }
    }

    static func recent(_ history: [AssessmentHistoryEntry]) -> [AssessmentHistoryEntry] {
        Array(history.sorted { (a: AssessmentHistoryEntry, b: AssessmentHistoryEntry) -> Bool in a.at > b.at }.prefix(visibleCount))
    }

    private func subtitle(total: Int) -> String {
        let tests = StudyFormat.plural(total, one: "test", few: "testy", many: "testów")
        return "\(total) \(tests) · poziom szacowany z odpowiedzi w teście"
    }
}

private struct StatsTestHistoryRow: View {
    let entry: AssessmentHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(StudyFormat.date(entry.at))
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                LevelBadge(level: entry.level)
                Spacer(minLength: Spacing.xs)
                Text("\(entry.percent)%")
                    .font(FluentFont.numberSmall)
                    .foregroundStyle(Palette.ink)
            }
            LinearProgressBar(progress: Double(entry.percent) / 100, tint: CEFRTone.tone(for: entry.level).foreground)
            Text(detail)
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Test z \(StudyFormat.date(entry.at))"))
        .accessibilityValue(Text("Wynik \(entry.percent) procent, poziom \(entry.level)"))
    }

    private var detail: String {
        let minutes = max(1, Int((entry.seconds / 60).rounded()))
        let questions = StudyFormat.plural(entry.total, one: "pytanie", few: "pytania", many: "pytań")
        return "\(entry.total) \(questions) · \(minutes) min · test na poziomie \(entry.baseLevel)"
    }
}
