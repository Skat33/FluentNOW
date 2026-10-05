import SwiftUI
import FluentKit

/// Dolny pasek ekranu tematu: „Dodaj N słów do nauki”, postęp dodawania, podsumowanie.
struct TopicAddBar: View {
    let selectedCount: Int
    let isAdding: Bool
    let progress: Double
    let outcome: TopicAddOutcome?
    let onAdd: () -> Void
    let onPractice: () -> Void
    let onDismissOutcome: () -> Void

    var body: some View {
        VStack(spacing: Spacing.s) {
            if isAdding {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Dodawanie słów… \(Int((ProgressMath.clamped(progress) * 100).rounded()))%")
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.ink)
                    LinearProgressBar(progress: progress)
                }
                .accessibilityElement(children: .combine)
            } else if let outcome, selectedCount == 0 {
                TopicOutcomeView(outcome: outcome, onPractice: onPractice, onDismiss: onDismissOutcome)
            } else {
                PrimaryButton(title, systemImage: "plus.circle.fill", action: onAdd)
                    .disabled(selectedCount == 0)
            }
        }
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.s)
        .background(.bar)
    }

    private var title: String {
        selectedCount == 0
            ? "Zaznacz słowa do nauki"
            : "Dodaj \(LibraryText.words(selectedCount)) do nauki"
    }
}

private struct TopicOutcomeView: View {
    let outcome: TopicAddOutcome
    let onPractice: () -> Void
    let onDismiss: () -> Void

    private var message: String {
        if outcome.addedMeanings == 0 {
            return "Te słowa już masz w słowniku — postęp został zachowany."
        }
        var text = "Dodano \(LibraryText.meanings(outcome.addedMeanings)) do kolekcji „\(outcome.collection)”."
        if outcome.skippedExisting > 0 {
            text += " Pominięto \(outcome.skippedExisting) — już były w słowniku, postęp zachowany."
        }
        return text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(alignment: .top) {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.success)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(FluentFont.footnote.weight(.semibold))
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Zamknij podsumowanie"))
            }
            if outcome.addedMeanings > 0 {
                PrimaryButton("Ćwicz teraz", systemImage: "play.fill", action: onPractice)
            }
        }
    }
}
