import SwiftUI
import FluentKit

/// 8. Podsumowanie: proponowany zestaw startowy (tematy do odznaczenia) i skrót odpowiedzi.
struct OnboardingSummaryStep: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            OnboardingStarterCard(model: model)
            OnboardingRecapCard(model: model)
            if let message = model.errorMessage {
                ErrorBanner(message: message, onDismiss: { model.errorMessage = nil })
            }
        }
    }
}

private struct OnboardingStarterCard: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        Card {
            SectionHeader("Słowa na start", subtitle: OnboardingSummaryText.proposal(model))
            if model.isPreparingSummary && model.starterTopics.isEmpty {
                LoadingStateView("Dobieram tematy…")
            }
            ForEach(model.starterTopics) { (item: OnboardingStarterTopic) in
                OnboardingOptionRow(
                    title: item.topic.namePl,
                    detail: item.topic.summaryPl,
                    systemImage: item.topic.symbol.isEmpty ? "text.book.closed" : item.topic.symbol,
                    isSelected: item.isSelected,
                    isMultiple: true
                ) {
                    model.toggleStarterTopic(item.id)
                }
                .disabled(model.isAdding)
            }
            if model.isAdding {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Przygotowuję Twoje słowa…")
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.ink)
                    LinearProgressBar(progress: model.progress)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct OnboardingRecapCard: View {
    let model: OnboardingModel

    var body: some View {
        Card(style: .muted) {
            SectionHeader("Twoje odpowiedzi", subtitle: "Zmienisz je w każdej chwili: Ustawienia → Twój profil nauki.")
            ForEach(OnboardingSummaryText.recap(model), id: \.title) { (line: OnboardingRecapLine) in
                OnboardingRecapRow(line: line)
            }
        }
    }
}

struct OnboardingRecapLine: Hashable {
    let title: String
    let value: String
    let systemImage: String
}

private struct OnboardingRecapRow: View {
    let line: OnboardingRecapLine

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            Image(systemName: line.systemImage)
                .foregroundStyle(Palette.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(line.title)
                .font(FluentFont.subheadline)
                .foregroundStyle(Palette.inkSecondary)
            Spacer(minLength: Spacing.xs)
            Text(line.value)
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

@MainActor
enum OnboardingSummaryText {
    static func proposal(_ model: OnboardingModel) -> String {
        let names = model.selectedStarterTopics.map { $0.namePl }
        guard !names.isEmpty else {
            return "Nie wybrano tematów — słowa dodasz później przyciskiem +."
        }
        let count = model.starterWordCount
        let words = LibraryText.count(count, one: "słowo", few: "słowa", many: "słów")
        return "Na start proponujemy \(words) z tematów: \(names.joined(separator: ", ")). Odznacz, czego nie chcesz."
    }

    static func recap(_ model: OnboardingModel) -> [OnboardingRecapLine] {
        let goals = model.goals.map { $0.namePl }.joined(separator: ", ")
        let interests = model.interests.map { $0.namePl }.joined(separator: ", ")
        let styles = model.styles.map { $0.namePl }.joined(separator: ", ")
        let level = model.selfLevel.map { (value: String) -> String in
            model.levelSource == .placementTest ? "\(value) (test)" : value
        } ?? "pominięty"
        return [
            OnboardingRecapLine(title: "Cele", value: goals.isEmpty ? "—" : goals, systemImage: "flag"),
            OnboardingRecapLine(title: "Poziom", value: level, systemImage: "chart.bar"),
            OnboardingRecapLine(title: "Zainteresowania", value: interests.isEmpty ? "—" : interests, systemImage: "heart"),
            OnboardingRecapLine(title: "Sposób nauki", value: styles.isEmpty ? "—" : styles, systemImage: "rectangle.on.rectangle"),
            OnboardingRecapLine(title: "Czas", value: "\(model.minutes) min dziennie", systemImage: "clock"),
            OnboardingRecapLine(title: "Przypomnienie", value: model.reminderEnabled ? model.reminderString : "wyłączone", systemImage: "bell"),
            OnboardingRecapLine(title: "Akcent", value: model.accent == "en-GB" ? "brytyjski" : "amerykański", systemImage: "speaker.wave.2")
        ]
    }
}
