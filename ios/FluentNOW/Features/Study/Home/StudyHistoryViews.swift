import SwiftUI
import FluentKit

/// Ostatnie wyniki (czytanie, zestawy, produkcja) + przejście do pełnej historii.
struct StudyRecentHistoryCard: View {
    let state: LearnerState

    var body: some View {
        let lines = StudyHistoryScreen.allLines(state, limit: 3)
        if !lines.isEmpty {
            Card {
                SectionHeader("Ostatnie ćwiczenia")
                ForEach(lines) { line in
                    StudyHistoryRow(line: line)
                }
                NavigationLink(value: StudyRoute.history) {
                    Label("Cała historia", systemImage: "clock.arrow.circlepath")
                        .font(FluentFont.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: HitTarget.minimum)
                }
            }
        }
    }
}

/// Pełna historia ćwiczeń poza sesjami słownictwa.
struct StudyHistoryScreen: View {
    @Environment(LearningStore.self) private var store

    var body: some View {
        let state = store.state
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if StudyHistoryScreen.allLines(state, limit: 1).isEmpty {
                    EmptyStateView(
                        systemImage: "clock",
                        title: "Historia jest jeszcze pusta",
                        message: "Tu pojawią się wyniki czytanek, zestawów gramatyki, idiomów i produkcji."
                    )
                }
                StudyHistoryList(title: "Czytanie", lines: StudyHistoryLine.reading(state.readingHistory, limit: 30))
                StudyHistoryList(title: "Gramatyka", lines: StudyHistoryLine.practice(state.practiceHistory, kind: .grammar, limit: 30))
                StudyHistoryList(title: "Idiomy", lines: StudyHistoryLine.practice(state.practiceHistory, kind: .idioms, limit: 30))
                StudyHistoryList(title: "Miks językowy", lines: StudyHistoryLine.practice(state.practiceHistory, kind: .mixed, limit: 30))
                StudyHistoryList(title: "Produkcja gramatyczna", lines: StudyHistoryLine.production(state.productionHistory, limit: 30))
            }
            .frame(maxWidth: Spacing.readableWidth)
            .frame(maxWidth: .infinity)
            .padding(Spacing.screen)
        }
        .background(Palette.background)
        .navigationTitle("Historia ćwiczeń")
        .navigationBarTitleDisplayMode(.inline)
    }

    static func allLines(_ state: LearnerState, limit: Int) -> [StudyHistoryLine] {
        let merged = StudyHistoryLine.reading(state.readingHistory, limit: limit)
            + StudyHistoryLine.practice(state.practiceHistory, kind: nil, limit: limit)
            + StudyHistoryLine.production(state.productionHistory, limit: limit)
        return Array(merged.sorted { $0.at > $1.at }.prefix(limit))
    }
}

private struct StudyHistoryRow: View {
    let line: StudyHistoryLine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(line.title)
                    .font(FluentFont.body)
                    .foregroundStyle(Palette.ink)
                Text(StudyFormat.date(line.at))
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)
            Text("\(line.correct)/\(line.total)")
                .font(FluentFont.numberSmall)
                .foregroundStyle(Palette.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Historia ćwiczeń") {
    NavigationStack {
        StudyHistoryScreen()
    }
    .fluentPreviewEnvironment()
}

#Preview("Ostatnie ćwiczenia") {
    NavigationStack {
        ScrollView {
            StudyRecentHistoryCard(state: LearnerState(readingHistory: [
                ReadingHistoryEntry(id: "r1", at: 1_700_000_000_000, level: "A2", correct: 4, total: 5, title: "A Day at the Airport")
            ]))
            .padding(Spacing.screen)
        }
        .background(Palette.background)
    }
    .fluentPreviewEnvironment()
}
