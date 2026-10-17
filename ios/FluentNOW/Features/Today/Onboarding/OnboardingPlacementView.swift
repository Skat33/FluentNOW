import SwiftUI
import FluentKit

/// Szybki test poziomu (krok „Twój poziom”): 12 pytań, odpowiedź przechodzi od razu dalej,
/// na końcu wynik i propozycja poziomu.
struct OnboardingPlacementView: View {
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            content
            Button("Wróć do wyboru poziomu") {
                model.cancelPlacement()
            }
            .font(FluentFont.button)
            .frame(maxWidth: .infinity, minHeight: HitTarget.minimum)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.placementPhase {
        case .idle, .loading:
            LoadingStateView("Przygotowuję pytania…")
        case .unavailable:
            EmptyStateView(
                systemImage: "exclamationmark.triangle",
                title: "Test jest chwilowo niedostępny",
                message: "Wybierz opis poziomu — zmienisz go później w Ustawieniach."
            )
        case .running:
            if let question = model.currentQuestion {
                OnboardingPlacementQuestionCard(
                    question: question,
                    number: model.questionIndex + 1,
                    total: model.questions.count
                ) { (option: Int) in
                    model.answer(option)
                }
                .id(question.id)
            }
        case .finished(let result):
            OnboardingPlacementResultCard(result: result) {
                model.acceptPlacement(result)
            }
        }
    }
}

private struct OnboardingPlacementQuestionCard: View {
    let question: PlacementQuestion
    let number: Int
    let total: Int
    let onAnswer: (Int) -> Void

    @Environment(SpeechService.self) private var speech

    var body: some View {
        Card {
            HStack {
                Text("Pytanie \(number) z \(total)")
                    .fluentEyebrow()
                    .foregroundStyle(Palette.accent)
                Spacer(minLength: 0)
                LevelBadge(level: question.level)
                    .accessibilityHidden(true)
            }
            LinearProgressBar(progress: Double(number - 1) / Double(max(1, total)))
            prompt
            VStack(spacing: Spacing.xs) {
                ForEach(Array(question.options.enumerated()), id: \.offset) { (item: (offset: Int, element: String)) in
                    OnboardingPlacementOption(
                        title: item.element,
                        isDontKnow: item.offset == question.options.count - 1
                    ) {
                        onAnswer(item.offset)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var prompt: some View {
        switch question.kind {
        case .vocabulary:
            HStack(spacing: Spacing.xs) {
                Text("Co znaczy „\(question.prompt)”?")
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                SpeakButton(size: .small, accessibilityLabel: "Odtwórz wymowę „\(question.prompt)”") {
                    speech.speak(question.prompt)
                }
            }
        case .grammar:
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Wybierz właściwą formę")
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                Text(question.prompt)
                    .font(FluentFont.sentence)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !question.hint.isEmpty {
                    Text(question.hint)
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct OnboardingPlacementOption: View {
    let title: String
    let isDontKnow: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(isDontKnow ? FluentFont.callout : FluentFont.body)
                .foregroundStyle(isDontKnow ? Palette.inkSecondary : Palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(Spacing.s)
                .frame(maxWidth: .infinity, minHeight: HitTarget.minimum, alignment: .leading)
                .background(isDontKnow ? Palette.background : Palette.surfaceMuted,
                            in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingPlacementResultCard: View {
    let result: PlacementResult
    let onAccept: () -> Void

    var body: some View {
        Card(style: .tinted(.accent)) {
            Text("Wynik testu")
                .fluentEyebrow()
                .foregroundStyle(Palette.accent)
            HStack(spacing: Spacing.s) {
                LevelBadge(level: result.level)
                Text(result.summaryPl)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("To szybka wskazówka, nie egzamin. Gdy zaczniesz ćwiczyć, poziom będzie liczony z Twoich odpowiedzi.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton("Przyjmij poziom \(result.level)", systemImage: "checkmark", action: onAccept)
        }
        .accessibilityElement(children: .contain)
    }
}
