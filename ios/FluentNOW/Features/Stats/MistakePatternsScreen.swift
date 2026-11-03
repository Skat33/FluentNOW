import SwiftUI
import FluentKit

// „Twoje typowe błędy” (FEEDBACK-10 P1): grupy błędów z dziennika (`MistakeLog.patterns`) z krótkim
// wyjaśnieniem po polsku, przykładami z ćwiczeń i „Przećwicz” (sesja `MistakePractice` przez router).
// Bez szkła — karty treści są jednolite (DESIGN §6).

extension MistakeKind {
    /// Ikona rodzaju błędu (SF Symbols).
    var statsSystemImage: String {
        switch self {
        case .verbForm: return "arrow.triangle.branch"
        case .preposition: return "arrow.left.and.right"
        case .article: return "a.circle"
        case .typo: return "character.cursor.ibeam"
        case .otherWord: return "arrow.left.arrow.right"
        case .wordOrder: return "arrow.up.arrow.down"
        case .meaning: return "questionmark.bubble"
        }
    }
}

/// Karta w Postępach: trzy najczęstsze rodzaje błędów → pełny ekran.
struct StatsMistakesCard: View {
    let patterns: [MistakePattern]

    var body: some View {
        if !patterns.isEmpty {
            Card {
                SectionHeader("Twoje typowe błędy", subtitle: "Na podstawie ostatnich pomyłek w ćwiczeniach.")
                ForEach(Array(patterns.prefix(3))) { (pattern: MistakePattern) in
                    NavigationLink(value: StatsRoute.mistakes) {
                        MistakePatternRow(pattern: pattern)
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink(value: StatsRoute.mistakes) {
                    HStack(spacing: Spacing.xs) {
                        Text("Wyjaśnienia i ćwiczenia")
                            .font(FluentFont.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(FluentFont.footnote.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Wiersz grupy: ikona, „Mylisz in / on / at”, rodzaj i liczba.
private struct MistakePatternRow: View {
    let pattern: MistakePattern

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Image(systemName: pattern.kind.statsSystemImage)
                .font(FluentFont.headline)
                .foregroundStyle(Palette.accent)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(pattern.headlinePl)
                    .font(FluentFont.bodyEmphasized)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(pattern.kind.namePl) · \(pattern.countPl)")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: Spacing.xs)
            Image(systemName: "chevron.right")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkTertiary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: HitTarget.minimum)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(pattern.summaryPl))
        .accessibilityHint(Text("Pokazuje wyjaśnienie i przykłady"))
    }
}

/// Pełny ekran „Twoje typowe błędy” (trasa `StatsRoute.mistakes`).
struct MistakePatternsScreen: View {
    @Environment(LearningStore.self) private var store
    @Environment(AppRouter.self) private var router

    @State private var patterns: [MistakePattern]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                content
            }
            .frame(maxWidth: Spacing.readableWidth)
            .padding(Spacing.screen)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .navigationTitle("Twoje typowe błędy")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: store.revision) { await refresh() }
    }

    @ViewBuilder
    private var content: some View {
        if let patterns {
            if patterns.isEmpty {
                EmptyStateView(
                    systemImage: "checkmark.seal",
                    title: "Na razie bez typowych błędów",
                    message: "Gdy pomylisz się w ćwiczeniu, zapiszemy, co poszło nie tak — formę czasownika, przyimek, literówkę — i pokażemy, co warto powtórzyć."
                )
            } else {
                MistakePatternsIntro(total: patterns.reduce(0) { (sum: Int, item: MistakePattern) -> Int in sum + item.count }) {
                    practice(nil)
                }
                ForEach(patterns) { (pattern: MistakePattern) in
                    MistakePatternCard(pattern: pattern) {
                        practice(pattern.kind)
                    }
                }
            }
        } else {
            LoadingStateView("Zbieram Twoje błędy…")
        }
    }

    private func refresh() async {
        let computed: [MistakePattern] = await store.compute { (state: LearnerState) -> [MistakePattern] in
            MistakeLog.patterns(state.mistakes)
        }
        guard !Task.isCancelled else { return }
        patterns = computed
    }

    /// „Przećwicz” — sesja słownictwa z błędów (ekran Nauka konsumuje prośbę routera).
    private func practice(_ kind: MistakeKind?) {
        router.startStudy(StudyLaunchRequest(modes: [MistakePractice.launchMode(for: kind)], minutes: 5))
    }
}

/// Nagłówek ekranu: ile błędów i jedna główna akcja.
private struct MistakePatternsIntro: View {
    let total: Int
    let onPractice: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Zebraliśmy \(total) \(MistakePatternsText.mistakes(total)) z ćwiczeń. Każdy rodzaj ma krótkie wyjaśnienie i przykłady, a „Przećwicz” ułoży sesję z tych słów i zdań.")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("Przećwicz wszystkie", systemImage: "arrow.counterclockwise", action: onPractice)
        }
    }
}

/// Karta jednej grupy: nagłówek, wyjaśnienie, przykłady, „Przećwicz”.
private struct MistakePatternCard: View {
    let pattern: MistakePattern
    let onPractice: () -> Void

    var body: some View {
        Card(spacing: Spacing.s) {
            Label {
                Text(pattern.kind.namePl)
            } icon: {
                Image(systemName: pattern.kind.statsSystemImage)
            }
            .font(FluentFont.eyebrow)
            .textCase(.uppercase)
            .foregroundStyle(Palette.accent)
            .accessibilityHidden(true)
            Text(pattern.summaryPl)
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(pattern.kind.explanationPl)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if !pattern.examples.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(pattern.examples) { (entry: MistakeEntry) in
                        MistakeExampleRow(entry: entry)
                    }
                }
            }
            SecondaryButton("Przećwicz", systemImage: "arrow.counterclockwise", fillsWidth: false, action: onPractice)
                .accessibilityHint(Text("Krótka sesja ze słowami i zdaniami, w których pojawił się ten błąd"))
        }
    }
}

/// Przykład: poprawnie / Twoja odpowiedź (kolor + ikona + tekst) i zdanie z ćwiczenia.
private struct MistakeExampleRow: View {
    let entry: MistakeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            MistakeExampleLine(
                systemImage: "checkmark.circle.fill",
                label: "Poprawnie",
                text: MistakePatternsText.expected(entry),
                color: Palette.success
            )
            MistakeExampleLine(
                systemImage: "xmark.circle.fill",
                label: "Twoja odpowiedź",
                text: MistakePatternsText.given(entry),
                color: Palette.danger
            )
            if !entry.context.isEmpty && entry.exercise != .scramble {
                Text(entry.context)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluentCardBackground(.muted, cornerRadius: Radius.small)
        .accessibilityElement(children: .combine)
    }
}

private struct MistakeExampleLine: View {
    let systemImage: String
    let label: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(FluentFont.footnote)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(attributed)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// „Twoja odpowiedź: **went**” — etykieta zwykłym krojem, odpowiedź pogrubiona.
    private var attributed: AttributedString {
        var prefix = AttributedString("\(label): ")
        prefix[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Palette.inkSecondary
        var answer = AttributedString(text)
        answer.inlinePresentationIntent = .stronglyEmphasized
        prefix.append(answer)
        return prefix
    }
}

/// Teksty ekranu (odmiana, skrócone odpowiedzi).
enum MistakePatternsText {
    /// „1 błąd”, „3 błędy”, „5 błędów”.
    static func mistakes(_ count: Int) -> String {
        StudyFormat.plural(count, one: "błąd", few: "błędy", many: "błędów")
    }

    /// Oczekiwana odpowiedź: całe zdanie przy kolejności, inaczej różniący się fragment, gdy jest.
    static func expected(_ entry: MistakeEntry) -> String {
        if entry.kind == .wordOrder || entry.expectedPart.isEmpty { return entry.expected }
        return entry.exercise == .scramble ? entry.expected : entry.expectedPart
    }

    /// Odpowiedź ucznia w tej samej formie co `expected`.
    static func given(_ entry: MistakeEntry) -> String {
        if entry.kind == .wordOrder || entry.givenPart.isEmpty { return entry.given }
        return entry.exercise == .scramble ? entry.given : entry.givenPart
    }
}
