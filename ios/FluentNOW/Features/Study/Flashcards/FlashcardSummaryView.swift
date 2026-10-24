import SwiftUI
import FluentKit

/// Krótkie podsumowanie talii (własne dla fiszek — podsumowanie sesji ma osobny ekran).
struct FlashcardSummaryView: View {
    let data: FlashcardSummaryData
    let onRepeatForgotten: () -> Void
    let onNewDeck: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Talia za Tobą")
                    .fluentEyebrow()
                    .foregroundStyle(Palette.accent)
                Text(headline)
                    .font(FluentFont.display)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Spacing.s) {
                StatTile(title: "Pamiętasz", value: "\(data.remembered)", systemImage: "checkmark", caption: nil, tone: .success)
                StatTile(title: "Do powtórki", value: "\(data.forgotten)", systemImage: "arrow.uturn.left", caption: nil, tone: .warning)
            }

            if !data.forgottenWords.isEmpty {
                FlashcardForgottenList(lines: data.forgottenWords)
            }

            Text("Czas: \(StudyFormat.duration(data.seconds)). Odpowiedzi są już zapisane — słowa wrócą w powtórkach.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: Spacing.xs) {
                if !data.forgottenWords.isEmpty {
                    SecondaryButton("Jeszcze raz te, których nie pamiętasz", systemImage: "arrow.counterclockwise", action: onRepeatForgotten)
                }
                SecondaryButton("Nowa talia", systemImage: "rectangle.stack", action: onNewDeck)
                PrimaryButton("Zakończ", systemImage: "checkmark", action: onFinish)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .fluentSensoryFeedback(FluentHaptic.answerCorrect, trigger: data.total)
        .onAppear {
            AccessibilityNotification.Announcement("\(headline) Pamiętasz \(data.remembered) z \(data.total).").post()
        }
    }

    private var headline: String {
        guard data.total > 0 else { return "Gotowe." }
        if data.forgotten == 0 { return "Wszystko pamiętasz." }
        return "Mały krok za Tobą."
    }
}

private struct FlashcardForgottenList: View {
    let lines: [FlashcardSummaryData.Line]

    var body: some View {
        Card(spacing: Spacing.s) {
            SectionHeader("Warto do nich wrócić")
            ForEach(lines.prefix(10)) { (line: FlashcardSummaryData.Line) in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Text(line.term)
                        .font(FluentFont.bodyEmphasized)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: Spacing.xs)
                    Text(line.translation)
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.inkSecondary)
                        .multilineTextAlignment(.trailing)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// Karta „Fiszki” na ekranie Nauka: liczniki talii i wejście w osobny tryb.
/// `pausedText` (FEEDBACK-6 K1): przerwana talia — znacznik „Przerwane”; dotknięcie „Otwórz
/// fiszki” pokazuje wtedy wybór „Kontynuuj” / „Zacznij od nowa”.
struct StudyFlashcardsCard: View {
    let counts: FlashcardDeckCounts?
    var pausedText: String? = nil
    let onOpen: () -> Void

    var body: some View {
        Card(spacing: Spacing.m) {
            SectionHeader("Fiszki", subtitle: subtitle)
            if let counts {
                FlashcardCountsRow(counts: counts)
            }
            if let pausedText {
                TagChip("Przerwane · \(pausedText)", systemImage: "pause.circle", tone: .accent)
            }
            SecondaryButton("Otwórz fiszki", systemImage: "rectangle.on.rectangle.angled", action: onOpen)
        }
    }

    private var subtitle: String {
        guard let counts else { return "Odwróć kartę, przesuń: pamiętam albo jeszcze nie." }
        if counts.total == 0 { return "Na teraz wszystko powtórzone." }
        return "Do powtórki, nowe i trudne — we własnym tempie."
    }
}

#Preview("Fiszki — podsumowanie") {
    ScrollView {
        FlashcardSummaryView(
            data: FlashcardSummaryData(
                remembered: 14,
                forgotten: 3,
                seconds: 185,
                forgottenWords: [
                    FlashcardSummaryData.Line(id: "1", term: "boarding pass", translation: "karta pokładowa"),
                    FlashcardSummaryData.Line(id: "2", term: "carry-on", translation: "bagaż podręczny")
                ]
            ),
            onRepeatForgotten: {},
            onNewDeck: {},
            onFinish: {}
        )
        .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}

#Preview("Fiszki — ekran") {
    NavigationStack {
        FlashcardDeckScreen(collection: nil)
    }
    .fluentPreviewEnvironment()
}
