import SwiftUI
import FluentKit

/// Pełny ekran trybu „Fiszki” (G3): wybór talii → karty → krótkie podsumowanie.
struct FlashcardDeckScreen: View {
    let collection: String?

    @Environment(LearningStore.self) private var store
    @State private var model: FlashcardDeckModel?

    var body: some View {
        Group {
            if let model {
                FlashcardDeckContent(model: model)
            } else {
                LoadingStateView("Przygotowuję fiszki…")
            }
        }
        .task {
            if model == nil {
                let created = FlashcardDeckModel(store: store, collection: collection)
                model = created
                await created.refreshCounts()
            }
        }
    }
}

private struct FlashcardDeckContent: View {
    @Bindable var model: FlashcardDeckModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                phaseContent
            }
            .frame(maxWidth: Spacing.readableWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.m)
        }
        .onChange(of: model.store.revision) { _, _ in
            model.syncWithStore()
        }
        .fluentSensoryFeedback(FluentHaptic.swipeCommit, trigger: model.decisions)
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch model.phase {
        case .setup:
            FlashcardSetupView(model: model)
        case .running:
            FlashcardRunView(model: model)
        case .finished:
            FlashcardSummaryView(
                data: model.summaryLines,
                onRepeatForgotten: { withTransition { model.restartWithForgotten() } },
                onNewDeck: { withTransition { model.backToSetup() } },
                onFinish: { dismiss() }
            )
        }
    }

    private func withTransition(_ change: () -> Void) {
        withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            change()
        }
    }
}

// MARK: - Wybór talii

private struct FlashcardSetupView: View {
    @Bindable var model: FlashcardDeckModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Fiszki")
                    .fluentEyebrow()
                    .foregroundStyle(Palette.accent)
                Text("Odwróć kartę, przesuń i dalej")
                    .font(FluentFont.display)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Na przodzie słowo po polsku albo po angielsku — dotknij, żeby obrócić kartę. W prawo — pamiętam, w lewo — jeszcze nie. Najpierw powtórki, potem nowe, na końcu trudne.")
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)

            if let notice = model.notice {
                Card(style: .tinted(.info)) {
                    Text(notice)
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Card(spacing: Spacing.m) {
                FlashcardCountsRow(counts: model.counts)
                FlashcardCollectionPicker(model: model)
                Picker("Liczba kart", selection: $model.size) {
                    ForEach(FlashcardDeckBuilder.sizes, id: \.self) { (value: Int) in
                        Text("\(value) kart").tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.size)
                PrimaryButton("Zacznij", systemImage: "play.fill", isLoading: model.isPreparing) {
                    Task { await model.start() }
                }
                .disabled(model.counts.total == 0)
            }
        }
        .task(id: model.collection ?? "") {
            await model.refreshCounts()
        }
    }
}

/// Do powtórki · nowe · trudne.
struct FlashcardCountsRow: View {
    let counts: FlashcardDeckCounts

    var body: some View {
        HStack(spacing: Spacing.s) {
            FlashcardCountTile(title: FlashcardGroup.due.namePl, value: counts.due, systemImage: "arrow.clockwise")
            FlashcardCountTile(title: FlashcardGroup.new.namePl, value: counts.new, systemImage: "sparkles")
            FlashcardCountTile(title: FlashcardGroup.hard.namePl, value: counts.hard, systemImage: "flame")
        }
    }
}

private struct FlashcardCountTile: View {
    let title: String
    let value: Int
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Image(systemName: systemImage)
                .foregroundStyle(Palette.accent)
                .accessibilityHidden(true)
            Text("\(value)")
                .font(FluentFont.numberMedium)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
            Text(title)
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.s)
        .fluentCardBackground(.muted, cornerRadius: Radius.medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title): \(value)"))
    }
}

/// Filtr kolekcji („Wszystkie” albo jedna).
private struct FlashcardCollectionPicker: View {
    @Bindable var model: FlashcardDeckModel

    var body: some View {
        if !model.collections.isEmpty {
            Picker("Kolekcja", selection: $model.collection) {
                Text("Wszystkie kolekcje").tag(String?.none)
                ForEach(model.collections, id: \.self) { (name: String) in
                    Text(name).tag(String?.some(name))
                }
            }
            .pickerStyle(.menu)
            .tint(Palette.accent)
        }
    }
}

// MARK: - Karty

private struct FlashcardRunView: View {
    let model: FlashcardDeckModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            FlashcardProgressHeader(model: model)
            if let card = model.currentCard {
                FlashcardCardView(
                    card: card,
                    revealed: model.revealed,
                    frontIsPolish: model.frontIsPolish,
                    onFlip: { flip() },
                    onDecision: { (remembered: Bool) in decide(remembered) }
                )
                .id(card.id)
                .transition(Motion.contentTransition(reduceMotion: reduceMotion))
                if model.revealed {
                    FlashcardExampleView(card: card, isShown: model.exampleShown, onToggle: { toggleExample() })
                        .transition(.opacity)
                }
                FlashcardDecisionButtons(onDecision: { (remembered: Bool) in decide(remembered) })
            }
            Text("Każdą odpowiedź zapisujemy od razu — możesz przerwać w dowolnej chwili.")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    /// Obrót karty: płynny, bez sprężynowania (sprężyna „przekręcałaby” kartę ponad 180°).
    private func flip() {
        withAnimation(Motion.resolved(Animation.easeInOut(duration: 0.4), reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            model.flip()
        }
    }

    private func toggleExample() {
        withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            model.toggleExample()
        }
    }

    private func decide(_ remembered: Bool) {
        withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
            model.answer(remembered: remembered)
        }
    }
}

/// „Karta 3 z 20” + pasek + grupa bieżącej karty.
private struct FlashcardProgressHeader: View {
    let model: FlashcardDeckModel

    var body: some View {
        let position = model.position
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("Karta \(position.index) z \(position.total)")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
                Spacer(minLength: Spacing.xs)
                if let group = model.currentCard?.group {
                    TagChip(model.currentCard?.attempt == 1 ? "Jeszcze raz" : group.namePl)
                }
            }
            LinearProgressBar(progress: position.total > 0 ? Double(position.index - 1) / Double(position.total) : 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// „Jeszcze nie” / „Pamiętam” (Enter = pamiętam, ← = jeszcze nie).
private struct FlashcardDecisionButtons: View {
    let onDecision: (Bool) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.s) { buttons }
            VStack(spacing: Spacing.xs) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        SecondaryButton("Jeszcze nie", systemImage: "arrow.left") { onDecision(false) }
            .keyboardShortcut(.leftArrow, modifiers: [])
        PrimaryButton("Pamiętam", systemImage: "checkmark") { onDecision(true) }
            .keyboardShortcut(.defaultAction)
    }
}
