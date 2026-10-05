import SwiftUI
import FluentKit

/// Lista kolekcji — osadzana w karcie „Słownik” (segment „Kolekcje”), więc bez własnego
/// `NavigationStack` i bez `navigationTitle`. Trasy rejestruje `WordsRootScreen`.
struct CollectionsRootScreen: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var overview: CollectionsOverview?
    @State private var isCreating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                if let overview {
                    if overview.collections.isEmpty {
                        EmptyStateView(
                            systemImage: "square.stack.3d.up",
                            title: "Nie masz jeszcze kolekcji",
                            message: "Dodaj temat słówek — kolekcja powstanie automatycznie. Możesz też założyć własną.",
                            actionTitle: "Przeglądaj tematy"
                        ) {
                            router.openLibrary(.topics)
                        }
                    } else {
                        SectionHeader("Twoje kolekcje", subtitle: "Porządkuj słowa tak, jak myślisz o świecie.")
                        CollectionGrid(collections: overview.collections)
                        CollectionPairsBanner(count: overview.confusableCount) {
                            router.startStudy(StudyLaunchRequest(modes: ["pairs"]))
                        }
                    }
                } else {
                    CollectionGrid(collections: CollectionsRootScreen.placeholders)
                        .redacted(reason: .placeholder)
                        .accessibilityLabel(Text("Wczytywanie kolekcji"))
                }
                SecondaryButton("Nowa kolekcja", systemImage: "folder.badge.plus") {
                    isCreating = true
                }
            }
            .padding(Spacing.screen)
        }
        .background(Palette.background)
        .task(id: store.revision) {
            let now = store.now()
            let computed = await store.compute { state in
                CollectionBuilder.overview(state: state, now: now)
            }
            guard !Task.isCancelled else { return }
            overview = computed
        }
        .collectionNameAlert(
            isPresented: $isCreating,
            title: "Nowa kolekcja",
            existing: overview?.collections.map { $0.name } ?? [],
            confirmTitle: "Utwórz"
        ) { name in
            store.update(.edit) { CollectionMutations.create(&$0, name: name) }
        }
    }

    static let placeholders: [CollectionSummary] = (0..<3).map { index in
        CollectionSummary(name: "Kolekcja \(index + 1)", wordCount: 10, meaningCount: 12, averageMastery: 40,
                          masteredMeanings: 2, newMeanings: 3, dueMeanings: 1)
    }
}

/// Siatka kart kolekcji (adaptacyjna — iPhone 1 kolumna, iPad więcej).
struct CollectionGrid: View {
    let collections: [CollectionSummary]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: Spacing.s)], spacing: Spacing.s) {
            ForEach(collections) { summary in
                NavigationLink(value: CollectionRoute.detail(name: summary.name)) {
                    CollectionCard(summary: summary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Karta kolekcji: nazwa, liczba słów, postęp.
struct CollectionCard: View {
    let summary: CollectionSummary

    var body: some View {
        let tone = Palette.collectionTone(named: summary.name)
        Card {
            HStack(spacing: Spacing.s) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(FluentFont.headline)
                    .foregroundStyle(tone.foreground)
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                    .background(tone.background, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(summary.name)
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Text(CollectionCard.subtitle(summary))
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(FluentFont.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkTertiary)
                    .accessibilityHidden(true)
            }
            LinearProgressBar(progress: Double(summary.averageMastery) / 100, tint: tone.foreground)
            Text("Opanowanie \(summary.averageMastery)%")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    static func subtitle(_ summary: CollectionSummary) -> String {
        var parts = [LibraryText.words(summary.wordCount)]
        if summary.dueMeanings > 0 { parts.append("\(summary.dueMeanings) do powtórki") }
        if summary.newMeanings > 0 {
            parts.append(LibraryText.count(summary.newMeanings, one: "nowe", few: "nowe", many: "nowych"))
        }
        return parts.joined(separator: " · ")
    }
}

/// „Podobne słowa, inna historia” — sesja par.
private struct CollectionPairsBanner: View {
    let count: Int
    let onPractice: () -> Void

    var body: some View {
        Card(style: .tinted(.accent)) {
            Label {
                Text("Podobne słowa, inna historia")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
            } icon: {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(Palette.accent)
            }
            Text(message)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if count != 0 {
                SecondaryButton("Poćwicz różnice", systemImage: "arrow.right", fillsWidth: false, action: onPractice)
            }
        }
    }

    private var message: String {
        if count > 0 { return "Wykryliśmy \(LibraryText.meanings(count)), które łatwo pomylić z innymi z Twojego słownika." }
        if count < 0 { return "Automatycznie wykryte podobne znaczenia z Twojego słownika." }
        return "Gdy dodasz słowa o podobnym znaczeniu lub brzmieniu, pojawią się tu do porównania."
    }
}

#Preview("Kolekcje") {
    NavigationStack {
        CollectionsRootScreen()
            .libraryNavigationDestinations()
    }
    .fluentPreviewEnvironment()
}
