import SwiftUI
import FluentKit

// „Dopasuj pary” (FEEDBACK-4 I2): pięć angielskich słów ↔ pięć polskich tłumaczeń. Błędna para
// krótko miga (bez ruchu — tylko kolor, więc „Ogranicz ruch” nie ma czego wyłączać) i liczy
// pomyłkę dla obu znaczeń; haptyka przez `fluentSensoryFeedback` (ustawienie „Wibracje”).

/// Polecenie i licznik połączonych par.
struct VocabPairsPrompt: View {
    let model: VocabExerciseModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            StudyQuestionLabel(text: "Połącz angielskie słowa z polskimi tłumaczeniami")
            Text("Połączone: \(model.matchedPairs.count) z \(model.content.pairItems.count)")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .contentTransition(.numericText())
        }
    }
}

/// Plansza: dwie kolumny (przy dużym tekście — jedna pod drugą).
struct VocabPairsBoard: View {
    let model: VocabExerciseModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    englishColumn
                    polishColumn
                }
            } else {
                HStack(alignment: .top, spacing: Spacing.s) {
                    englishColumn
                    polishColumn
                }
            }
        }
        .fluentSensoryFeedback(FluentHaptic.answerIncorrect, trigger: model.pairMistakeCount)
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.matchedPairs.count)
        .task(id: model.pairFlash?.id ?? 0) {
            guard let flash = model.pairFlash else { return }
            AccessibilityNotification.Announcement("To nie jest para").post()
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(Motion.resolved(Motion.tap, reduceMotion: reduceMotion, fallback: nil)) {
                model.clearPairFlash(flash.id)
            }
        }
        .onChange(of: model.matchedPairs.count) { (_: Int, _: Int) in
            announceLastMatch()
        }
    }

    private var englishColumn: some View {
        VocabPairsColumn(
            title: "Angielski",
            items: model.content.pairs?.english ?? [],
            side: .english,
            model: model
        )
    }

    private var polishColumn: some View {
        VocabPairsColumn(
            title: "Polski",
            items: model.content.pairs?.polish ?? [],
            side: .polish,
            model: model
        )
    }

    private func announceLastMatch() {
        guard let last = model.matchedPairs.last,
              let item = model.content.pairItems.first(where: { (item: MatchPairItem) -> Bool in item.meaningId == last }) else { return }
        AccessibilityNotification.Announcement("Para: \(item.term) — \(item.translation)").post()
    }
}

/// Jedna kolumna planszy.
private struct VocabPairsColumn: View {
    enum Side { case english, polish }

    let title: String
    let items: [MatchPairItem]
    let side: Side
    let model: VocabExerciseModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .fluentEyebrow()
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(items) { (item: MatchPairItem) in
                StudyWordTile(
                    text: side == .english ? item.term : item.translation,
                    style: style(for: item),
                    isEnabled: !model.isFinished && !model.matchedPairs.contains(item.meaningId),
                    accessibilityText: accessibilityText(for: item),
                    accessibilityHintText: side == .english ? "Zaznacza słowo; potem wybierz tłumaczenie" : "Zaznacza tłumaczenie; potem wybierz słowo",
                    fillsWidth: true
                ) {
                    tap(item)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tap(_ item: MatchPairItem) {
        withAnimation(Motion.resolved(Motion.tap, reduceMotion: reduceMotion, fallback: nil)) {
            switch side {
            case .english: model.tapEnglish(item.meaningId)
            case .polish: model.tapPolish(item.meaningId)
            }
        }
    }

    private func style(for item: MatchPairItem) -> StudyWordTile.Style {
        if model.matchedPairs.contains(item.meaningId) { return .matched }
        if let flash = model.pairFlash {
            let flashed = side == .english ? flash.englishID : flash.polishID
            if flashed == item.meaningId { return .wrong }
        }
        let selected = side == .english ? model.selectedEnglish : model.selectedPolish
        return selected == item.meaningId ? .selected : .idle
    }

    private func accessibilityText(for item: MatchPairItem) -> String {
        let text = side == .english ? item.term : item.translation
        let language = side == .english ? "angielskie" : "polskie"
        if model.matchedPairs.contains(item.meaningId) {
            return "\(text), \(language), połączone"
        }
        return "\(text), \(language)"
    }
}

/// Po zakończeniu: wszystkie pary i pomyłki per słowo.
struct VocabPairsResultList: View {
    let model: VocabExerciseModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(model.content.pairItems) { (item: MatchPairItem) in
                VocabPairsResultRow(item: item, mistakes: model.pairMistakes[item.meaningId] ?? 0)
            }
        }
    }
}

private struct VocabPairsResultRow: View {
    let item: MatchPairItem
    let mistakes: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Image(systemName: mistakes == 0 ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                .foregroundStyle(mistakes == 0 ? Palette.success : Palette.warning)
                .accessibilityHidden(true)
            Text("**\(item.term)** — \(item.translation)")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)
            if mistakes > 0 {
                Text(VocabPairsResultRow.mistakesText(mistakes))
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.warning)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// „1 pomyłka”, „2 pomyłki”, „5 pomyłek”.
    static func mistakesText(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if count == 1 { return "1 pomyłka" }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "\(count) pomyłki" }
        return "\(count) pomyłek"
    }
}
