import SwiftUI
import FluentKit

/// Wczytanie banku zadań na poziomie docelowym użytkownika (`LevelEstimator`).
@MainActor
enum PracticeContentLoader {
    struct Loaded: Sendable {
        let content: PracticeContent
        let level: String
    }

    static func load(store: LearningStore, library: ContentLibrary) async throws -> Loaded {
        let level = await store.compute { state in
            LevelEstimator.estimatedLevel(state).targetLevel
        }
        let content = try await library.practiceContent(level: level)
        return Loaded(content: content, level: level)
    }

    static func errorMessage(_ error: Error) -> String {
        let detail = (error as? LocalizedError)?.errorDescription ?? ""
        let base = "Nie udało się wczytać zadań. Twoje dane są bezpieczne — spróbuj ponownie."
        return detail.isEmpty ? base : "\(base) (\(detail))"
    }
}

/// Zdanie z luką `________` (kontekst ćwiczenia). VoiceOver czyta lukę jako „luka”.
struct PracticeContextText: View {
    let context: String

    var body: some View {
        Text(context)
            .font(FluentFont.sentence)
            .foregroundStyle(Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fluentCardBackground(.muted, cornerRadius: Radius.medium)
            .accessibilityLabel(Text(PracticeContextText.spoken(context)))
    }

    static func spoken(_ text: String) -> String {
        var result = ""
        var inGap = false
        for character in text {
            if character == "_" {
                if !inGap { result += " luka " }
                inGap = true
            } else {
                inGap = false
                result.append(character)
            }
        }
        return result
    }
}

/// Wprowadzenie do zestawu (przed startem).
struct PracticeIntroCard: View {
    let eyebrow: String
    let title: String
    let message: String
    let buttonTitle: String
    let isLoading: Bool
    let onStart: () -> Void

    var body: some View {
        Card(padding: Spacing.l, spacing: Spacing.m) {
            Text(eyebrow)
                .fluentEyebrow()
                .foregroundStyle(Palette.accent)
            Text(title)
                .font(FluentFont.display)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(isLoading ? "Przygotowuję zadania…" : buttonTitle, systemImage: "play.fill", isLoading: isLoading, action: onStart)
        }
    }
}

/// Wynik ukończonego zestawu.
struct PracticeResultCard: View {
    let correct: Int
    let total: Int
    let message: String
    let buttonTitle: String
    let isLoading: Bool
    let onNext: () -> Void

    @Environment(AppPreferences.self) private var preferences
    @State private var appeared = false

    var body: some View {
        Card(padding: Spacing.l, spacing: Spacing.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(.largeTitle))
                .foregroundStyle(Palette.success)
                .accessibilityHidden(true)
            Text("\(correct) / \(total) poprawnych odpowiedzi")
                .font(FluentFont.title)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ProgressRing(progress: ProgressMath.fraction(correct, of: total), lineWidth: 8, tint: Palette.success, accessibilityLabel: "Wynik zestawu")
                .frame(width: 72, height: 72)
            Text(message)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(buttonTitle, systemImage: "arrow.clockwise", isLoading: isLoading, action: onNext)
        }
        .onAppear { appeared = true }
        .sensoryFeedback(FluentHaptic.answerCorrect, trigger: appeared) { old, new in
            preferences.hapticsEnabled && !old && new
        }
    }
}

/// Wiersz historii (czytanie, zestawy, produkcja).
struct StudyHistoryLine: Identifiable, Hashable {
    let id: String
    let title: String
    let level: String
    let correct: Int
    let total: Int
    let at: Timestamp
}

/// Ostatnie wyniki — „podsumowania i historia”.
struct StudyHistoryList: View {
    let title: String
    let lines: [StudyHistoryLine]

    var body: some View {
        if !lines.isEmpty {
            Card {
                SectionHeader(title)
                ForEach(lines) { line in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.title)
                                .font(FluentFont.body)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(StudyFormat.date(line.at))
                                .font(FluentFont.caption)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                        Spacer(minLength: Spacing.xs)
                        LevelBadge(level: line.level)
                        Text("\(line.correct)/\(line.total)")
                            .font(FluentFont.numberSmall)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

extension StudyHistoryLine {
    static func practice(_ entries: [PracticeHistoryEntry], kind: PracticeKind?, limit: Int = 5) -> [StudyHistoryLine] {
        entries
            .filter { kind == nil || $0.kind == kind }
            .sorted { $0.at > $1.at }
            .prefix(limit)
            .map { StudyHistoryLine(id: "p-\($0.id)-\($0.at)", title: $0.title, level: $0.level, correct: $0.correct, total: $0.total, at: $0.at) }
    }

    static func production(_ entries: [ProductionHistoryEntry], limit: Int = 5) -> [StudyHistoryLine] {
        entries
            .sorted { $0.at > $1.at }
            .prefix(limit)
            .map { StudyHistoryLine(id: "g-\($0.id)-\($0.at)", title: $0.title, level: $0.level, correct: $0.correct, total: $0.total, at: $0.at) }
    }

    static func reading(_ entries: [ReadingHistoryEntry], limit: Int = 5) -> [StudyHistoryLine] {
        entries
            .sorted { $0.at > $1.at }
            .prefix(limit)
            .map { StudyHistoryLine(id: "r-\($0.id)-\($0.at)", title: $0.title ?? "Czytanka", level: $0.level, correct: $0.correct, total: $0.total, at: $0.at) }
    }
}

#Preview("Elementy ćwiczeń") {
    ScrollView {
        VStack(spacing: Spacing.l) {
            PracticeContextText(context: "On Saturdays, we usually ________ (pakować) the bags for the trip.")
            PracticeIntroCard(eyebrow: "Poziom B1", title: "Gramatyka", message: "Ponad 300 zdań na Twoim poziomie.", buttonTitle: "Rozpocznij zestaw", isLoading: false) {}
            PracticeResultCard(correct: 5, total: 6, message: "Zestaw zapisaliśmy w historii.", buttonTitle: "Następny zestaw", isLoading: false) {}
            StudyHistoryList(title: "Ostatnie zestawy", lines: [StudyHistoryLine(id: "1", title: "Gramatyka B1", level: "B1", correct: 5, total: 6, at: 1_700_000_000_000)])
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
