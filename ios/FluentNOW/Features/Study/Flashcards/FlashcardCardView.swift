import SwiftUI
import FluentKit

/// Karta fiszki: przód (słowo, wymowa, zdanie), tył (znaczenie, tłumaczenie zdania, definicja).
/// Dotknięcie odwraca kartę; przesunięcie w prawo = pamiętam, w lewo = nie pamiętam — zapis i od
/// razu następna karta (bez panelu wyniku, jak FEEDBACK-1 F3).
struct FlashcardCardView: View {
    let card: FlashcardCard
    let revealed: Bool
    let onFlip: () -> Void
    let onDecision: (Bool) -> Void

    @Environment(LearningStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    private static let threshold: CGFloat = 110

    var body: some View {
        if let found = store.state.word(id: card.wordId), let meaning = found.meaning(id: card.meaningId) {
            cardBody(word: found, meaning: meaning)
        } else {
            // Słowo usunięte w międzyczasie — model zaraz je pominie.
            EmptyView()
        }
    }

    private func cardBody(word: Word, meaning: Meaning) -> some View {
        FlashcardFaces(word: word, meaning: meaning, example: card.example, revealed: revealed)
            .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
            .padding(Spacing.l)
            .fluentCardBackground(.solid, cornerRadius: Radius.card)
            .overlay(alignment: .topTrailing) {
                FlashcardSwipeBadge(offset: offset)
                    .padding(Spacing.m)
            }
            .fluentShadow(offset == 0 ? .card : .raised)
            .offset(x: offset)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(offset / 40)))
            .contentShape(Rectangle())
            .onTapGesture { onFlip() }
            // Równoległy gest: pionowe przewijanie ScrollView działa dalej (reagujemy tylko na ruch poziomy).
            .simultaneousGesture(drag)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text(revealed ? "Wybierz: pamiętam albo nie pamiętam." : "Dotknij dwukrotnie, aby odwrócić kartę."))
            .accessibilityAction(named: Text(revealed ? "Zakryj znaczenie" : "Odwróć kartę")) { onFlip() }
            .accessibilityAction(named: Text("Pamiętam")) { onDecision(true) }
            .accessibilityAction(named: Text("Nie pamiętam")) { onDecision(false) }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { (value: DragGesture.Value) in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                offset = value.translation.width
            }
            .onEnded { (value: DragGesture.Value) in
                let width = value.translation.width
                if abs(width) >= FlashcardCardView.threshold && abs(width) > abs(value.translation.height) {
                    offset = 0
                    onDecision(width > 0)
                } else {
                    withAnimation(Motion.resolved(Motion.standard, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
                        offset = 0
                    }
                }
            }
    }
}

/// Treść karty (przód i — po odwróceniu — tył).
private struct FlashcardFaces: View {
    let word: Word
    let meaning: Meaning
    let example: Int
    let revealed: Bool

    @Environment(SpeechService.self) private var speech

    var body: some View {
        let pair = examplePair
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .center, spacing: Spacing.s) {
                Text(word.en)
                    .font(FluentFont.flashcardTerm)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.xs)
                SpeakButton(isSpeaking: speech.isSpeaking) { speech.speak(word.en) }
            }
            if !word.ipa.isEmpty {
                Text(word.ipa)
                    .font(FluentFont.ipa)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if let pair {
                StudyExampleSentence(text: pair.en, focus: pair.focusEn)
            }
            if revealed {
                FlashcardBack(word: word, meaning: meaning, pair: pair)
                    .transition(.opacity)
            } else {
                Label("Dotknij, aby zobaczyć znaczenie", systemImage: "hand.tap")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.top, Spacing.xs)
            }
        }
    }

    private var examplePair: ExamplePair? {
        guard !meaning.examples.isEmpty else { return nil }
        let count = meaning.examples.count
        let index = ((example % count) + count) % count
        return VocabularyGrader.examplePair(word: word, meaning: meaning, index: index)
    }
}

private struct FlashcardBack: View {
    let word: Word
    let meaning: Meaning
    let pair: ExamplePair?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(meaning.translation)
                .font(FluentFont.title)
                .foregroundStyle(Palette.accent)
                .fixedSize(horizontal: false, vertical: true)
            StudyPairTranslation(pair: pair)
            if !meaning.definition.isEmpty {
                Text(meaning.definition)
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluentCardBackground(.muted, cornerRadius: Radius.medium)
    }
}

/// Znacznik kierunku przesunięcia (kolor + ikona + tekst).
private struct FlashcardSwipeBadge: View {
    let offset: CGFloat

    var body: some View {
        if abs(offset) > 30 {
            let remembered = offset > 0
            Label(remembered ? "Pamiętam" : "Nie pamiętam", systemImage: remembered ? "checkmark" : "arrow.uturn.left")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(remembered ? Palette.success : Palette.warning)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xxs)
                .fluentCardBackground(.tinted(remembered ? .success : .warning), cornerRadius: Radius.small)
                .opacity(min(1, Double(abs(offset)) / 110))
                .accessibilityHidden(true)
        }
    }
}
