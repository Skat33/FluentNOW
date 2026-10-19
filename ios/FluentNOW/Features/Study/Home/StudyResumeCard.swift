import SwiftUI
import FluentKit

/// Przerwana sesja do wznowienia (kafelek na ekranie Nauka).
struct StudyResumeItem: Identifiable, Hashable {
    let flow: StudyFlow
    let title: String
    let detail: String
    let progress: Double

    var id: String { flow.id }

    /// Wszystkie niedokończone sesje w stanie (sesja łączona i słownictwo najpierw — jak strona).
    static func items(in state: LearnerState) -> [StudyResumeItem] {
        var result: [StudyResumeItem] = []
        if let combined = state.combined, combined.completedAt == nil, combined.index < combined.tasks.count {
            result.append(StudyResumeItem(
                flow: .combined,
                title: "Twoja sesja łączona czeka",
                detail: "Ukończono \(combined.index) z \(StudyFormat.tasks(combined.tasks.count)). Kolejność jest zapisana.",
                progress: ProgressMath.fraction(combined.index, of: combined.tasks.count)
            ))
        }
        if let session = state.session, !session.isFinished, !session.tasks.isEmpty {
            // „Ćwicz wybrany typ” (J1) — nazwa typu zamiast „Codziennej mieszanki”.
            let name = StudySingleTypeText.sessionTitle(mode: session.mode) ?? session.studyMode.namePl
            result.append(StudyResumeItem(
                flow: .vocabulary,
                title: "Twoja sesja czeka",
                detail: "\(name) · ukończono \(session.index) z \(StudyFormat.exercises(session.tasks.count)).",
                progress: ProgressMath.fraction(session.index, of: session.tasks.count)
            ))
        }
        if let reading = state.reading, !reading.submitted {
            result.append(StudyResumeItem(
                flow: .reading(autoStart: false),
                title: "Czytanka czeka",
                detail: "„\(reading.reading.title)” · \(reading.reading.level)",
                progress: 0
            ))
        }
        if let practice = state.practice, practice.completedAt == nil, !practice.set.items.isEmpty {
            result.append(StudyResumeItem(
                flow: .practice(practice.set.kind, autoStart: false),
                title: "Zestaw: \(practice.set.kind.studyTitle)",
                detail: "Pytanie \(min(practice.index + 1, practice.set.items.count)) z \(practice.set.items.count) · \(practice.set.level)",
                progress: ProgressMath.fraction(practice.index, of: practice.set.items.count)
            ))
        }
        if let production = state.production, production.completedAt == nil, !production.set.items.isEmpty {
            result.append(StudyResumeItem(
                flow: .production(autoStart: false),
                title: "Produkcja gramatyczna czeka",
                detail: "Zadanie \(min(production.index + 1, production.set.items.count)) z \(production.set.items.count) · \(production.set.level)",
                progress: ProgressMath.fraction(production.index, of: production.set.items.count)
            ))
        }
        return result
    }
}

struct StudyResumeCard: View {
    let item: StudyResumeItem
    let onContinue: () -> Void

    var body: some View {
        Card(style: .tinted(.accent)) {
            HStack(alignment: .top, spacing: Spacing.s) {
                Image(systemName: "pause.circle.fill")
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(item.title)
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.ink)
                    Text(item.detail)
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if item.progress > 0 {
                LinearProgressBar(progress: item.progress)
            }
            SecondaryButton("Kontynuuj", systemImage: "play.fill", action: onContinue)
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Wznowienie") {
    StudyResumeCard(item: StudyResumeItem(flow: .vocabulary, title: "Twoja sesja czeka", detail: "Codzienna mieszanka · ukończono 3 z 12 ćwiczeń.", progress: 0.25)) {}
        .padding(Spacing.screen)
        .background(Palette.background)
        .fluentPreviewEnvironment()
}
