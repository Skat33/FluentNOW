import SwiftUI
import FluentKit

// „Ułóż zdanie” (rozsypanka, FEEDBACK-4 I2, FEEDBACK-9 N1): polskie zdanie zawsze nad kafelkami,
// kafelki słów (z 1–3 słowami-pułapkami) → zdanie po angielsku. Wielkość liter i interpunkcja
// nie mają znaczenia; poprawne są dokładnie słowa zdania (FluentKit `SentenceScramble`).

/// Treść zadania: polecenie, polskie zdanie do przełożenia, liczba zbędnych słów; po odpowiedzi —
/// angielskie zdanie (polskie zostaje nad nim).
struct VocabScramblePrompt: View {
    let model: VocabExerciseModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            StudyQuestionLabel(text: "Ułóż po angielsku zdanie ze słowem „\(model.content.word.en)”")
            VocabScrambleSource(content: model.content)
            if model.isFinished {
                StudyExampleSentence(text: model.content.example, focus: model.content.focus)
            } else {
                Text(VocabScrambleText.instruction(decoys: model.scrambleDecoyCount))
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Teksty rozsypanki (polska odmiana liczebnika).
enum VocabScrambleText {
    static func instruction(decoys: Int) -> String {
        let base = "Dotykaj słów w kolejności zdania. Dotknięcie słowa w zdaniu odkłada je z powrotem."
        switch decoys {
        case ..<1: return base
        case 1: return base + " Jedno słowo jest zbędne — zostaw je w puli."
        default: return base + " \(decoys) słowa są zbędne — zostaw je w puli."
        }
    }

    /// Etykieta VoiceOver puli: „Słowa do ułożenia, w tym 2 zbędne”.
    static func poolLabel(decoys: Int) -> String {
        switch decoys {
        case ..<1: return "Słowa do ułożenia"
        case 1: return "Słowa do ułożenia, w tym jedno zbędne"
        default: return "Słowa do ułożenia, w tym \(decoys) zbędne"
        }
    }

    /// Polskie zdanie do przełożenia: tłumaczenie przykładu, a bez niego — znaczenie słowa.
    static func sourceSentence(content: VocabExerciseContent) -> String {
        if let pair = content.pair, !pair.pl.isEmpty { return pair.pl }
        let translation = content.scramble?.translation ?? ""
        return translation.isEmpty ? content.meaning.translation : translation
    }
}

/// Polskie zdanie nad kafelkami — zawsze widoczne (także w teście); nie jest podpowiedzią.
private struct VocabScrambleSource: View {
    let content: VocabExerciseContent

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(eyebrow)
                .fluentEyebrow()
                .foregroundStyle(Palette.inkSecondary)
            sentence
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Lekko zabarwione tło — odróżnia zdanie do przełożenia od pola „Twoje zdanie”.
        .fluentCardBackground(.tinted(.accent), cornerRadius: Radius.medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    private var eyebrow: String {
        hasSentence ? "Po polsku" : "Znaczenie słowa"
    }

    private var hasSentence: Bool {
        if let pair = content.pair, !pair.pl.isEmpty { return true }
        return !(content.scramble?.translation ?? "").isEmpty
    }

    @ViewBuilder
    private var sentence: some View {
        if let pair = content.pair, !pair.pl.isEmpty {
            HighlightedText(pair.pl, focus: pair.focusPl, highlight: Palette.accentSoftInk)
                .font(FluentFont.sentence)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(VocabScrambleText.sourceSentence(content: content))
                .font(FluentFont.sentence)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accessibilityText: String {
        let text = VocabScrambleText.sourceSentence(content: content)
        return hasSentence ? "Zdanie po polsku: \(text)" : "Znaczenie słowa: \(text)"
    }
}

/// Zdanie w budowie, pula kafelków (ze słowami-pułapkami), „Wyczyść” i „Sprawdź”.
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
                    message: retryMessage,
                    playsHaptic: preferences.hapticsEnabled
                )
            }
            VocabScrambleAnswerLine(model: model, onRemove: remove)
            if !model.isFinished {
                VocabScramblePool(tiles: model.availableScrambleTiles, decoys: model.scrambleDecoyCount, onPlace: place)
                VocabScrambleActions(model: model)
            }
        }
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: model.placedTiles.count)
    }

    private var retryMessage: String {
        let base = "Poprawny początek został — ułóż resztę zdania."
        return model.scrambleDecoyCount > 0 ? base + " Zbędne słowa zostaw w puli." : base
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
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity, minHeight: HitTarget.minimum, alignment: .leading)
                } else {
                    StudyTileFlow(spacing: Spacing.xs) {
                        ForEach(Array(model.placedScrambleTiles.enumerated()), id: \.element.id) { (entry: (offset: Int, element: ScrambleTile)) in
                            StudyWordTile(
                                text: entry.element.text,
                                style: tileStyle,
                                isEnabled: !model.isFinished,
                                accessibilityText: "\(entry.element.text), słowo \(entry.offset + 1) w zdaniu",
                                accessibilityHintText: "Odkłada słowo z powrotem do puli"
                            ) {
                                onRemove(entry.element.id)
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

/// Kafelki do wyboru (słowa zdania i pułapki — nieodróżnialne przed sprawdzeniem).
private struct VocabScramblePool: View {
    let tiles: [ScrambleTile]
    let decoys: Int
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
        .accessibilityLabel(Text(VocabScrambleText.poolLabel(decoys: decoys)))
    }
}

/// „Wyczyść”, w drugiej próbie „Pokaż odpowiedź”, „Sprawdź”.
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
        // Zawsze w tym samym miejscu (nieaktywne przy pustym zdaniu) — układ nie skacze.
        Button(action: model.clearTiles) {
            Label("Wyczyść", systemImage: "arrow.uturn.backward")
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(model.placedTiles.isEmpty ? Palette.inkSecondary : Palette.accent)
                .frame(minHeight: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.placedTiles.isEmpty)
        .accessibilityHint(Text("Wszystkie słowa wracają do puli"))
        if model.phase == .retry {
            Button("Pokaż odpowiedź", action: model.giveUp)
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: HitTarget.minimum)
        }
    }

    /// W teście (K4) bez „Sprawdź” — zdanie zatwierdza „Dalej” ekranu testu.
    @ViewBuilder
    private func checkButton(fillsWidth: Bool) -> some View {
        if !model.isAssessment {
            PrimaryButton("Sprawdź", systemImage: "arrow.right", fillsWidth: fillsWidth, action: model.checkScramble)
                .disabled(!model.canCheckScramble)
                .keyboardShortcut(.defaultAction)
        }
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
