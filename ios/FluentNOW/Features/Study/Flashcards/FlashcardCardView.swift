import SwiftUI
import FluentKit

/// Karta fiszki jak w Quizlecie (FEEDBACK-3 H3): na przodzie sam wyraz — losowo po polsku albo po
/// angielsku, duża czcionka, nic więcej. Dotknięcie obraca kartę (obrót 3D; przy „Ogranicz ruch”
/// przenikanie) — na drugiej stronie odpowiednik w drugim języku, przy angielskim przycisk
/// odsłuchu. Przesunięcie w prawo = pamiętam, w lewo = jeszcze nie — zapis i od razu następna karta.
struct FlashcardCardView: View {
    let card: FlashcardCard
    let revealed: Bool
    let frontIsPolish: Bool
    let onFlip: () -> Void
    let onDecision: (Bool) -> Void

    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0

    private static let threshold: CGFloat = 110

    var body: some View {
        if let found = store.state.word(id: card.wordId), let meaning = found.meaning(id: card.meaningId) {
            cardBody(faces: FlashcardFaces(word: found, meaning: meaning, frontIsPolish: frontIsPolish))
        } else {
            // Słowo usunięte w międzyczasie — model zaraz je pominie.
            EmptyView()
        }
    }

    private func cardBody(faces: FlashcardFaces) -> some View {
        FlashcardFlip(
            angle: reduceMotion ? 0 : (revealed ? 180 : 0),
            revealed: revealed,
            reduceMotion: reduceMotion,
            front: faces.front,
            back: faces.back
        )
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(revealed ? "\(faces.front.text) — \(faces.back.text)" : faces.front.text))
        .accessibilityHint(Text(revealed ? "Wybierz: pamiętam albo jeszcze nie." : "Dotknij dwukrotnie, aby odwrócić kartę."))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onFlip() }
        .accessibilityAction(named: Text("Odtwórz wymowę")) { speech.speak(faces.englishText) }
        .accessibilityAction(named: Text("Pamiętam")) { onDecision(true) }
        .accessibilityAction(named: Text("Jeszcze nie")) { onDecision(false) }
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

/// Jedna strona karty: tekst i język.
struct FlashcardFace: Equatable {
    var text: String
    var isEnglish: Bool
}

/// Przód i tył karty dla wylosowanego języka przodu.
struct FlashcardFaces {
    let front: FlashcardFace
    let back: FlashcardFace

    init(word: Word, meaning: Meaning, frontIsPolish: Bool) {
        let english = FlashcardFace(text: word.en, isEnglish: true)
        let polish = FlashcardFace(text: meaning.translation, isEnglish: false)
        front = frontIsPolish ? polish : english
        back = frontIsPolish ? english : polish
    }

    var englishText: String { front.isEnglish ? front.text : back.text }
}

/// Obrót karty wokół osi pionowej. `angle` jest animowany (`Animatable`), więc strona zmienia się
/// dokładnie w połowie obrotu (90°); tył jest odbity, żeby po obrocie czytał się normalnie.
/// Przy „Ogranicz ruch” kąt zostaje 0, a strony przenikają się (animacja przezroczystości).
private struct FlashcardFlip: View, Animatable {
    var angle: Double
    let revealed: Bool
    let reduceMotion: Bool
    let front: FlashcardFace
    let back: FlashcardFace

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    private var showsBack: Bool {
        reduceMotion ? revealed : angle >= 90
    }

    var body: some View {
        ZStack {
            FlashcardSideView(face: front, showsAudio: false, isFront: true)
                .opacity(showsBack ? 0 : 1)
                .allowsHitTesting(!showsBack)
            FlashcardSideView(face: back, showsAudio: back.isEnglish, isFront: false)
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                .opacity(showsBack ? 1 : 0)
                .allowsHitTesting(showsBack)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}

/// Strona karty: sam wyraz dużą czcionką; na angielskim tyle — przycisk odsłuchu.
private struct FlashcardSideView: View {
    let face: FlashcardFace
    let showsAudio: Bool
    let isFront: Bool

    @Environment(SpeechService.self) private var speech

    var body: some View {
        VStack(spacing: Spacing.m) {
            Text(face.text)
                .font(FluentFont.flashcardTerm)
                .foregroundStyle(isFront ? Palette.ink : Palette.accent)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
            if showsAudio {
                SpeakButton(isSpeaking: speech.isSpeaking) { speech.speak(face.text) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 260)
        .padding(Spacing.l)
        .fluentCardBackground(isFront ? .solid : .muted, cornerRadius: Radius.card)
    }
}

/// „Pokaż przykład” pod odwróconą kartą (H3): zdanie z tłumaczeniem dopiero na życzenie.
struct FlashcardExampleView: View {
    let card: FlashcardCard
    let isShown: Bool
    let onToggle: () -> Void

    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech

    var body: some View {
        if let pair = examplePair {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Button(action: onToggle) {
                    Label(isShown ? "Ukryj przykład" : "Pokaż przykład", systemImage: isShown ? "chevron.up" : "text.quote")
                        .font(FluentFont.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: HitTarget.minimum)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if isShown {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        HStack(alignment: .top, spacing: Spacing.s) {
                            StudyExampleSentence(text: pair.en, focus: pair.focusEn)
                            Spacer(minLength: Spacing.xs)
                            SpeakButton(size: .small, isSpeaking: speech.isSpeaking, accessibilityLabel: "Posłuchaj zdania") {
                                speech.speak(pair.en)
                            }
                        }
                        StudyPairTranslation(pair: pair)
                    }
                    .padding(Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fluentCardBackground(.muted, cornerRadius: Radius.medium)
                    .transition(.opacity)
                }
            }
        }
    }

    private var examplePair: ExamplePair? {
        guard let word = store.state.word(id: card.wordId), let meaning = word.meaning(id: card.meaningId),
              !meaning.examples.isEmpty else { return nil }
        let count = meaning.examples.count
        let index = ((card.example % count) + count) % count
        guard let found = VocabularyGrader.examplePair(word: word, meaning: meaning, index: index),
              !found.en.isEmpty else { return nil }
        return found
    }
}

/// Znacznik kierunku przesunięcia (kolor + ikona + tekst).
private struct FlashcardSwipeBadge: View {
    let offset: CGFloat

    var body: some View {
        if abs(offset) > 30 {
            let remembered = offset > 0
            Label(remembered ? "Pamiętam" : "Jeszcze nie", systemImage: remembered ? "checkmark" : "arrow.uturn.left")
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
