import SwiftUI

/// Pasek postępu sesji: „Twój mały krok · 3 / 12” + pasek.
struct StudySessionHeader: View {
    let title: String
    let index: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .fluentEyebrow()
                    .foregroundStyle(Palette.inkSecondary)
                Spacer(minLength: Spacing.xs)
                Text("\(min(index + 1, max(total, 1))) / \(max(total, 1))")
                    .font(FluentFont.numberSmall)
                    .foregroundStyle(Palette.ink)
                    .contentTransition(.numericText())
            }
            LinearProgressBar(progress: ProgressMath.fraction(index, of: total))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("Zadanie \(min(index + 1, max(total, 1))) z \(max(total, 1))"))
    }
}

/// Licznik czasu zadania: liczy od 00:00, zatrzymuje się po odpowiedzi.
/// VoiceOver nie odczytuje go na bieżąco; po zatrzymaniu podaje czas odpowiedzi raz.
struct StudyElapsedClock: View {
    let startedAt: Date
    let stoppedSeconds: Double?

    var body: some View {
        Group {
            if let stoppedSeconds {
                label(seconds: StudyElapsedClock.wholeSeconds(stoppedSeconds))
                    .accessibilityLabel(Text("Czas odpowiedzi: \(StudyElapsedClock.wholeSeconds(stoppedSeconds)) s"))
            } else {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    label(seconds: StudyElapsedClock.wholeSeconds(context.date.timeIntervalSince(startedAt)))
                }
                .accessibilityHidden(true)
            }
        }
    }

    /// Pełne sekundy (bez pułapki `Int(NaN)`).
    static func wholeSeconds(_ value: Double) -> Int {
        guard value.isFinite, value > 0 else { return 0 }
        return Int(min(value, 86_400))
    }

    private func label(seconds: Int) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "clock")
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(StudyFormat.clock(seconds))
                .font(FluentFont.numberSmall)
        }
        .foregroundStyle(Palette.inkSecondary)
    }
}

#Preview("Nagłówek sesji") {
    VStack(spacing: Spacing.l) {
        StudySessionHeader(title: "Twój mały krok", index: 3, total: 12)
        StudyElapsedClock(startedAt: Date(), stoppedSeconds: nil)
        StudyElapsedClock(startedAt: Date(), stoppedSeconds: 14)
    }
    .padding(Spacing.screen)
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
