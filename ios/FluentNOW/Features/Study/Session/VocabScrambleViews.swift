import SwiftUI
import FluentKit

// „Ułóż zdanie” (rozsypanka, FEEDBACK-4 I2): kafelki słów → zdanie. Wielkość liter i interpunkcja
// nie mają znaczenia (FluentKit `SentenceScramble`).

/// Treść zadania: polecenie, liczba słów-pułapek, po odpowiedzi — zdanie z tłumaczeniem.
struct VocabScramblePrompt: View {
    let model: VocabExerciseModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StudyQuestionLabel(text: "Ułóż zdanie ze słowem „\(model.content.word.en)”")
            if !model.isFinished {
                Text(instruction)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                StudyExampleSentence(text: model.content.example, focus: model.content.focus)
                StudyPairTranslation(pair: model.content.pair)
            }
        }
    }

    private var instruction: String {
        let decoys = model.content.scramble?.decoyCount ?? 0
        let base = "Dotykaj słów w odpowiedniej kolejności. Dotknięcie słowa w zdaniu odkłada je z powrotem."
        switch decoys {
        case 0: return base
        case 1: return base + " Uwaga: jedno słowo nie pasuje do zdania."
        default: return base + " Uwaga: \(decoys) słowa nie pasują do zdania."
        }
    }
}

/// Zdanie w budowie, pula kafelków, podpowiedź (tłumaczenie), „Wyczyść” i „Sprawdź”.
struct VocabScrambleArea: View {
    let model: VocabExerciseModel

    @Environment(AppPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            if model.phase == .retry {
                FeedbackPanel(
                    kind: .almost,
                    title: "Jeszcze nie",
                    message: "Poprawny początek został — ułóż resztę zdania.",
                    playsHaptic: preferences.hapticsEnabled
                )
            }
            VocabScrambleAnswerLine(model: model, onRemove: remove)
            if !model.isFinished {
                VocabScramblePool(tiles: model.availableScrambleTiles, onPlace: place)
                if model.scrambleHintShown, let translation = model.content.scramble?.translation, !translation.isEmpty {
                    StudyHintBox(lines: ["Tłumaczenie: \(translation)"])
                }
                VocabScrambleActions(model: model)
            }
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.placedTiles.count)
    }

    private func place(_ id: Int) {
        withAnimation(Motion.resolved(Motion.tap, reduceMotion: reduceMotion, fallback: nil)) {
            model.placeTile(id)
        }
    }

    private func remove(_ id: Int) {
        withAnimation(Motion.resolved(Motion.tap, reduceMotion: reduceMotion, fallback: nil)) {
            model.removeTile(id)
        }
    }
}

/// Ułożone słowa (po odpowiedzi: zielone albo czerwone).
private struct VocabScrambleAnswerLine: View {
    let model: VocabExerciseModel
    let onRemove: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Twoje zdanie")
                .fluentEyebrow()
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityHidden(true)
            Group {
                if model.placedTiles.isEmpty {
                    Text("Dotknij pierwszego słowa poniżej.")
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(maxWidth: .infinity, minHeight: HitTarget.minimum, alignment: .leading)
                } else {
                    StudyTileFlow(spacing: Spacing.xs) {
                        ForEach(Array(model.placedScrambleTiles.enumerated()), id: \.element.id) { index, tile in
                            StudyWordTile(
                                text: tile.text,
                                style: tileStyle,
                                isEnabled: !model.isFinished,
                                accessibilityText: "\(tile.text), słowo \(index + 1) w zdaniu",
                                accessibilityHintText: "Odkłada słowo z powrotem"
                            ) {
                                onRemove(tile.id)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surfaceMuted, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
    }

    private var tileStyle: StudyWordTile.Style {
        guard model.isFinished else { return .placed }
        return (model.outcome?.correct ?? false) ? .correct : .wrong
    }
}

/// Kafelki do wyboru.
private struct VocabScramblePool: View {
    let tiles: [ScrambleTile]
    let onPlace: (Int) -> Void

    var body: some View {
        StudyTileFlow(spacing: Spacing.xs) {
            ForEach(tiles) { (tile: ScrambleTile) in
                StudyWordTile(
                    text: tile.text,
                    style: .idle,
                    isEnabled: true,
                    accessibilityText: tile.text,
                    accessibilityHintText: "Dodaje słowo na koniec zdania"
                ) {
                    onPlace(tile.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Słowa do ułożenia"))
    }
}

/// „Podpowiedź” (tłumaczenie), „Wyczyść”, w drugiej próbie „Pokaż odpowiedź”, „Sprawdź”.
private struct VocabScrambleActions: View {
    let model: VocabExerciseModel

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.m) {
                helpButtons
                Spacer(minLength: Spacing.xs)
                checkButton(fillsWidth: false)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                checkButton(fillsWidth: true)
                helpButtons
            }
        }
    }

    @ViewBuilder
    private var helpButtons: some View {
        if !model.scrambleHintShown, let translation = model.content.scramble?.translation, !translation.isEmpty {
            StudyHintButton(title: "Podpowiedź") { model.showScrambleHint() }
        }
        if !model.placedTiles.isEmpty {
            Button("Wyczyść", action: model.clearTiles)
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: HitTarget.minimum)
                .accessibilityHint(Text("Wszystkie słowa wracają do puli"))
        }
        if model.phase == .retry {
            Button("Pokaż odpowiedź", action: model.giveUp)
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: HitTarget.minimum)
        }
    }

    private func checkButton(fillsWidth: Bool) -> some View {
        PrimaryButton("Sprawdź", systemImage: "arrow.right", fillsWidth: fillsWidth, action: model.checkScramble)
            .disabled(!model.canCheckScramble)
            .keyboardShortcut(.defaultAction)
    }
}

// MARK: - Wspólne kafelki

/// Kafelek słowa (rozsypanka, dopasuj pary). Bez szkła i transformacji 3D — zwykłe tło.
struct StudyWordTile: View {
    enum Style { case idle, placed, selected, correct, wrong, matched }

    let text: String
    let style: Style
    let isEnabled: Bool
    let accessibilityText: String
    let accessibilityHintText: String
    /// Kafelek na całą szerokość kolumny (dopasuj pary).
    var fillsWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(FluentFont.bodyEmphasized)
                .foregroundStyle(foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .frame(minWidth: HitTarget.minimum, maxWidth: fillsWidth ? CGFloat.infinity : nil, minHeight: HitTarget.minimum)
                .background(background, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(border, lineWidth: style == .idle ? 1 : 1.5)
                }
                .contentShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityHint(Text(accessibilityHintText))
        .accessibilityAddTraits(style == .selected ? .isSelected : [])
    }

    private var foreground: Color {
        switch style {
        case .idle, .placed: return Palette.ink
        case .selected: return Palette.accentSoftInk
        case .correct, .matched: return Palette.success
        case .wrong: return Palette.danger
        }
    }

    private var background: Color {
        switch style {
        case .idle, .placed: return Palette.surface
        case .selected: return Palette.accentSoft
        case .correct, .matched: return Palette.successSoft
        case .wrong: return Palette.dangerSoft
        }
    }

    private var border: Color {
        switch style {
        case .idle: return Palette.separator
        case .placed: return Palette.accent.opacity(0.5)
        case .selected: return Palette.accent
        case .correct, .matched: return Palette.success
        case .wrong: return Palette.danger
        }
    }
}

/// Układ „w wierszach” (zawijanie kafelków jak tekst). Bez dzielenia przez szerokość — przy
/// nieskończonej propozycji wszystko w jednym wierszu (żadnej geometrii NaN).
struct StudyTileFlow: Layout {
    var spacing: CGFloat = Spacing.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangement(width: bounds.width, subviews: subviews)
        for index in subviews.indices {
            guard index < result.frames.count else { break }
            let frame = result.frames[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func arrangement(width: CGFloat?, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        let limit: CGFloat = {
            guard let width, width.isFinite, width > 0 else { return .greatestFiniteMagnitude }
            return width
        }()
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > limit {
                size = subview.sizeThatFits(ProposedViewSize(width: limit, height: nil))
                size.width = min(size.width, limit)
            }
            if x > 0 && x + size.width > limit {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxRowWidth = max(maxRowWidth, x - spacing)
        }
        let height = frames.isEmpty ? 0 : y + rowHeight
        let totalWidth = limit == .greatestFiniteMagnitude ? maxRowWidth : min(limit, max(maxRowWidth, 0))
        return (frames, CGSize(width: max(0, totalWidth), height: max(0, height)))
    }
}
