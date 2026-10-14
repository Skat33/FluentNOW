import SwiftUI

/// „Mała podpowiedź” pod polem odpowiedzi. Kolejne poziomy podpowiedzi (`HintSet` z FluentKit)
/// pojawiają się jeden pod drugim.
struct StudyHintBox: View {
    let lines: [String]

    init(lines: [String]) {
        self.lines = lines
    }

    init(text: String) {
        self.lines = [text]
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(Palette.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Mała podpowiedź")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                ForEach(lines.indices, id: \.self) { (index: Int) in
                    Text(lines[index])
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.m)
        .fluentCardBackground(.tinted(.warning), cornerRadius: Radius.medium)
        .accessibilityElement(children: .combine)
    }
}

/// Przycisk tekstowy „Podpowiedź” / „Więcej podpowiedzi” (rozwija `StudyHintBox`;
/// użycie oznacza odpowiedź z podpowiedzią).
struct StudyHintButton: View {
    var title: String = "Podpowiedź"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "lightbulb")
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Odpowiedź zostanie zapisana jako udzielona z podpowiedzią."))
    }
}

/// Odsłuch zdania zadania. Przed sprawdzeniem luka jest cicha (`[[gap]]` obsługuje `SpeechService`),
/// po sprawdzeniu słychać zdanie z poprawną odpowiedzią.
struct StudySentenceAudioButton: View {
    let text: String
    let solved: Bool

    @Environment(SpeechService.self) private var speech

    var body: some View {
        if !text.isEmpty {
            Button {
                speech.speak(text)
            } label: {
                Label(solved ? "Posłuchaj poprawnego zdania" : "Posłuchaj zadania", systemImage: "speaker.wave.2")
                    .font(FluentFont.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(solved
                ? "Odsłuchaj zdanie z poprawną odpowiedzią"
                : "Odsłuchaj treść zadania; luka pozostanie pusta"))
        }
    }
}

/// „Wyjaśnienie i poprawna odpowiedź” — rozwinięte przy błędnej odpowiedzi, zwinięte przy poprawnej
/// (jak `AnswerExplanation` strony).
struct StudyExplanationDisclosure<Content: View>: View {
    let correct: Bool
    let content: Content

    @State private var isExpanded: Bool

    init(correct: Bool, @ViewBuilder content: () -> Content) {
        self.correct = correct
        self.content = content()
        self._isExpanded = State(initialValue: !correct)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Spacing.xs)
        } label: {
            Text(correct ? "Dlaczego ta odpowiedź jest poprawna?" : "Wyjaśnienie i poprawna odpowiedź")
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
        }
        .tint(Palette.accent)
    }
}

#Preview("Pomoce w ćwiczeniu") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.m) {
            StudyHintBox(lines: ["Część mowy: czasownik.\nLiczba słów: 1.\nAngielska definicja: To take something that you will give back.", "Pierwsze litery: b _ _ _ _ _"])
            StudyHintButton {}
            StudyHintButton(title: "Więcej podpowiedzi") {}
            StudySentenceAudioButton(text: "Can I [[gap]] your pen?", solved: false)
            StudyExplanationDisclosure(correct: false) {
                Text("„Borrow” = pożyczyć od kogoś.")
            }
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
