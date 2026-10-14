import SwiftUI
import FluentKit

/// Pierwsze uruchomienie: wybierz poziom i 1–3 sytuacje (skróty wyszukiwania tematu) → słowa dodane
/// → pierwsza sesja. Tematy nie są katalogiem (F1) — sytuacje to zapytania, które wyszukiwanie
/// tematu zamienia na temat z bazy (najlepiej pasująca kategoria najpierw).
struct TodayOnboardingView: View {
    /// Trwa dodawanie słów — stan trzyma ekran Dzisiaj, żeby onboarding (z paskiem postępu)
    /// nie zniknął po pierwszej partii słów (słownik przestaje być pusty w trakcie dodawania).
    @Binding var isAdding: Bool

    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @Environment(AppPreferences.self) private var preferences
    @Environment(AppRouter.self) private var router

    @State private var level = "A2"
    @State private var chosen: [String] = []
    @State private var progress: Double = 0
    @State private var errorMessage: String?

    static let maxTopics = 3
    /// Ile wpisów na sytuację dodać na start (od najistotniejszych) — resztę znajdziesz w „Szukaj tematu”.
    static let entriesPerTopic = 30

    /// Skróty sytuacji na start (każdy trafia w temat wbudowanej bazy — test w FluentKit).
    static let situations = [
        "przedstawianie się", "small talk", "w sklepie", "zakupy spożywcze", "w restauracji", "w kawiarni",
        "na lotnisku", "w hotelu", "pytanie o drogę", "u lekarza", "rozmowa o pracę", "rodzina"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            TodayOnboardingHeader()
            if let errorMessage {
                ErrorBanner(message: errorMessage, onDismiss: { self.errorMessage = nil })
            }
            TodayOnboardingLevelCard(level: $level)
            TodayOnboardingSituationsCard(chosen: $chosen, maxTopics: TodayOnboardingView.maxTopics)
            actions
        }
    }

    @ViewBuilder
    private var actions: some View {
        if isAdding {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Przygotowuję Twoje słowa…")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                LinearProgressBar(progress: progress)
            }
            .accessibilityElement(children: .combine)
        } else {
            PrimaryButton(chosen.isEmpty ? "Wybierz co najmniej 1 sytuację" : "Dodaj słowa i zacznij", systemImage: "sparkles") {
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

    /// Wpisy na start: poziom do jednego powyżej wybranego, w kolejności tematu.
    static func starterEntryIDs(_ topic: TopicFile, level: String) -> [String] {
        starterEntryIDs(topic.allEntries, level: level)
    }

    /// Wpisy na start z listy (np. kolejność wyników wyszukiwania): poziom ≤ wybrany + 1, maks. `entriesPerTopic`.
    static func starterEntryIDs(_ entries: [TopicEntry], level: String) -> [String] {
        let limit = (CEFR.index(of: level) ?? 1) + 1
        let fitting = entries.filter { (entry: TopicEntry) -> Bool in
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
        let queries = chosen
        for (offset, query) in queries.enumerated() {
            do {
                added += try await addSituation(query, offset: offset, count: queries.count)
            } catch {
                errorMessage = "Nie udało się dodać słów dla „\(query)”: \(error.localizedDescription)"
            }
        }
        isAdding = false
        guard added > 0 else {
            if errorMessage == nil {
                errorMessage = "Nie znaleziono słów dla wybranych sytuacji. Spróbuj innych albo pomiń ten krok."
            }
            return
        }
        preferences.hasCompletedOnboarding = true
        router.startStudy(.daily)
    }

    /// Zapytanie → najlepszy temat → najistotniejsze wpisy (sekcje wyszukiwania) → dodanie w tle.
    private func addSituation(_ query: String, offset: Int, count: Int) async throws -> Int {
        let content = env.content
        let matches = await content.rankTopics(query, limit: 4)
        guard let best = matches.first, best.confidence.isGood else { return 0 }
        let sections = try await content.topicResultSections(primary: best, matches: [best])
        let topic = try await content.topic(id: best.topicID)
        let ordered = sections.filter { $0.topicID == topic.id }.flatMap { $0.entries }
        let ids = TodayOnboardingView.starterEntryIDs(ordered, level: level)
        let outcome = await TopicAdder.add(topic: topic, entryIDs: ids, store: store) { (value: Double) in
            progress = (Double(offset) + value) / Double(count)
        }
        await content.rememberQuery(query, topicID: best.topicID, categoryID: best.focusCategoryIDs.first, now: store.now())
        return outcome.addedMeanings
    }
}

private struct TodayOnboardingHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Witaj w FluentNOW")
                .font(FluentFont.display)
                .foregroundStyle(Palette.ink)
            Text("Dwa szybkie wybory i zaczynamy. Wszystko działa bez internetu.")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
        }
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
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: level)
    }
}

/// Skróty sytuacji (zamiast listy wszystkich tematów).
private struct TodayOnboardingSituationsCard: View {
    @Binding var chosen: [String]
    let maxTopics: Int

    var body: some View {
        Card {
            SectionHeader("2. Sytuacje na start", subtitle: "Wybierz od 1 do \(maxTopics). Każdą inną znajdziesz później przyciskiem + → „Szukaj tematu”.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Spacing.xs)], spacing: Spacing.xs) {
                ForEach(TodayOnboardingView.situations, id: \.self) { (situation: String) in
                    TodayOnboardingSituationChip(
                        title: situation,
                        isSelected: chosen.contains(situation),
                        isDisabled: !chosen.contains(situation) && chosen.count >= maxTopics
                    ) {
                        toggle(situation)
                    }
                }
            }
        }
    }

    private func toggle(_ situation: String) {
        if let position = chosen.firstIndex(of: situation) {
            chosen.remove(at: position)
        } else if chosen.count < maxTopics {
            chosen.append(situation)
        }
    }
}

private struct TodayOnboardingSituationChip: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "magnifyingglass")
                    .accessibilityHidden(true)
                Text(title)
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
