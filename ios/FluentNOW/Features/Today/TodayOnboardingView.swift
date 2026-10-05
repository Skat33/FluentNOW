import SwiftUI
import FluentKit

/// Pierwsze uruchomienie: wybierz poziom i 1–3 tematy → słowa dodane → pierwsza sesja.
struct TodayOnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(AppRouter.self) private var router

    @State private var level = "A2"
    @State private var index: TopicIndex?
    @State private var chosen: [String] = []
    @State private var isAdding = false
    @State private var progress: Double = 0
    @State private var errorMessage: String?

    static let maxTopics = 3
    /// Ile wpisów na temat dodać na start (od najczęstszych w mowie) — reszta czeka w temacie.
    static let entriesPerTopic = 30

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Witaj w FluentNOW")
                    .font(FluentFont.display)
                    .foregroundStyle(Palette.ink)
                Text("Dwa szybkie wybory i zaczynamy. Wszystko działa bez internetu.")
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if let errorMessage {
                ErrorBanner(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }
            TodayOnboardingLevelCard(level: $level)
            TodayOnboardingTopicsCard(index: index, chosen: $chosen, maxTopics: TodayOnboardingView.maxTopics)
            if isAdding {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Przygotowuję Twoje słowa…")
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.ink)
                    LinearProgressBar(progress: progress)
                }
                .accessibilityElement(children: .combine)
            } else {
                PrimaryButton(chosen.isEmpty ? "Wybierz co najmniej 1 temat" : "Dodaj słowa i zacznij", systemImage: "sparkles") {
                    Task { await start() }
                }
                .disabled(chosen.isEmpty)
                Button("Pomiń — dodam słowa sam") {
                    preferences.hasCompletedOnboarding = true
                }
                .font(FluentFont.button)
                .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
            }
        }
        .task {
            guard index == nil else { return }
            index = try? await env.content.topicIndex()
            if index == nil {
                errorMessage = "Nie udało się wczytać tematów. Możesz pominąć ten krok i dodać słowa ręcznie."
            }
        }
    }

    /// Wpisy na start: poziom do jednego powyżej wybranego, w kolejności tematu.
    static func starterEntryIDs(_ topic: TopicFile, level: String) -> [String] {
        let limit = (CEFR.index(of: level) ?? 1) + 1
        let fitting = topic.allEntries.filter { entry in
            guard let entryLevel = CEFR.index(of: entry.level) else { return true }
            return entryLevel <= limit
        }
        return Array(fitting.prefix(entriesPerTopic)).map { $0.id }
    }

    private func start() async {
        guard !chosen.isEmpty, !isAdding else { return }
        isAdding = true
        progress = 0
        var added = 0
        let topics = chosen
        for (offset, topicID) in topics.enumerated() {
            do {
                let topic = try await env.content.topic(id: topicID)
                let ids = TodayOnboardingView.starterEntryIDs(topic, level: level)
                let outcome = await TopicAdder.add(topic: topic, entryIDs: ids, store: store) { value in
                    progress = (Double(offset) + value) / Double(topics.count)
                }
                added += outcome.addedMeanings
            } catch {
                errorMessage = "Nie udało się dodać tematu: \(error.localizedDescription)"
            }
        }
        isAdding = false
        guard added > 0 else { return }
        preferences.hasCompletedOnboarding = true
        router.startStudy(.daily)
    }
}

private struct TodayOnboardingLevelCard: View {
    @Binding var level: String

    private static let descriptions: [String: String] = [
        "A1": "Zaczynam od zera",
        "A2": "Proste rozmowy i podróże",
        "B1": "Radzę sobie w codziennych sytuacjach",
        "B2": "Swobodnie, ale chcę precyzji",
        "C1": "Zaawansowany, szlifuję niuanse",
        "C2": "Prawie jak native"
    ]

    var body: some View {
        Card {
            SectionHeader("1. Twój poziom", subtitle: "Dobierzemy słowa — możesz to zmienić w każdej chwili.")
            ForEach(CEFR.levels, id: \.self) { item in
                Button {
                    level = item
                } label: {
                    HStack(spacing: Spacing.s) {
                        Image(systemName: level == item ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(level == item ? Palette.accent : Palette.inkSecondary)
                            .accessibilityHidden(true)
                        LevelBadge(level: item)
                        Text(TodayOnboardingLevelCard.descriptions[item] ?? "")
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(level == item ? .isSelected : [])
            }
        }
        .sensoryFeedback(FluentHaptic.selection, trigger: level)
    }
}

private struct TodayOnboardingTopicsCard: View {
    let index: TopicIndex?
    @Binding var chosen: [String]
    let maxTopics: Int

    var body: some View {
        Card {
            SectionHeader("2. Tematy na start", subtitle: "Wybierz od 1 do \(maxTopics). Kolejne dodasz w Słowniku.")
            if let index {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Spacing.xs)], spacing: Spacing.xs) {
                    ForEach(index.topics) { topic in
                        TodayOnboardingTopicChip(
                            topic: topic,
                            isSelected: chosen.contains(topic.id),
                            isDisabled: !chosen.contains(topic.id) && chosen.count >= maxTopics
                        ) {
                            toggle(topic.id)
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func toggle(_ id: String) {
        if let position = chosen.firstIndex(of: id) {
            chosen.remove(at: position)
        } else if chosen.count < maxTopics {
            chosen.append(id)
        }
    }
}

private struct TodayOnboardingTopicChip: View {
    let topic: TopicSummary
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: topic.symbol.isEmpty ? "text.book.closed" : topic.symbol)
                    .accessibilityHidden(true)
                Text(topic.namePl)
                    .font(FluentFont.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Palette.onAccent : Palette.ink)
            .padding(.horizontal, Spacing.s)
            .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
            .background(isSelected ? Palette.accentFill : Palette.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
