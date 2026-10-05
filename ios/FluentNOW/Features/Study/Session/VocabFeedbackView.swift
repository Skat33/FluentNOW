import SwiftUI
import FluentKit

/// Wynik zadania słownikowego: panel informacji zwrotnej, wyjaśnienie z przykładem,
/// warianty odpowiedzi, „Powiedz to” i zgłoszenie błędu.
struct VocabFeedbackView: View {
    let model: VocabExerciseModel

    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        let summary = VocabFeedbackSummary(model: model)
        FeedbackPanel(
            kind: summary.kind,
            title: summary.title,
            message: summary.message,
            explanation: summary.explanation,
            playsHaptic: preferences.hapticsEnabled
        ) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if summary.offersTypoAcceptance {
                    SecondaryButton("Uznaj moją odpowiedź", systemImage: "checkmark", fillsWidth: false, action: model.acceptTypo)
                        .accessibilityHint(Text("Zadanie zostanie zaliczone z błędem pisowni."))
                }
                StudyExplanationDisclosure(correct: model.outcome?.correct ?? false) {
                    VocabExplanationDetails(content: model.content)
                }
                if model.content.accepted.count > 1 && model.type != .flashcard {
                    VocabAcceptedVariants(answers: model.content.accepted)
                }
                StudyPronunciationButton(expected: model.content.word.en)
                StudyReportButton(draft: model.content.reportDraft(answer: model.outcome?.value ?? model.answer))
            }
        }
    }
}

/// Teksty panelu wyniku wyliczone z oceny.
struct VocabFeedbackSummary {
    let kind: FeedbackKind
    let title: String
    let message: String
    let explanation: String?
    let offersTypoAcceptance: Bool

    @MainActor
    init(model: VocabExerciseModel) {
        let content = model.content
        let pairLine = "**\(VocabFeedbackSummary.escaped(content.word.en))** — \(VocabFeedbackSummary.escaped(content.meaning.translation))"
        let outcome = model.outcome
        let grade = model.grade

        if model.type == .flashcard {
            let remembered = outcome?.correct ?? false
            kind = remembered ? .correct : .info
            title = remembered ? "Pamiętasz" : "Wrócimy do tego słowa"
            message = pairLine
            explanation = nil
            offersTypoAcceptance = false
            return
        }

        let expected = VocabFeedbackSummary.escaped(content.expectedAnswer)
        if let closest = grade?.closestAnswer, grade?.isFailure == true {
            kind = .almost
            title = model.acceptedTypo ? "Zaliczone — popraw pisownię" : "Prawie — to literówka?"
            message = "Poprawnie: **\(VocabFeedbackSummary.escaped(closest))**"
            explanation = model.acceptedTypo ? nil : grade?.explanation
            offersTypoAcceptance = !model.acceptedTypo
            return
        }

        offersTypoAcceptance = false
        if outcome?.correct == true {
            if grade?.verdict == .uncertain {
                kind = .almost
                title = "Uznane z drobną uwagą"
            } else if outcome?.hinted == true {
                kind = .almost
                title = "Udało się z podpowiedzią"
            } else {
                kind = .correct
                title = "Dokładnie tak!"
            }
            message = pairLine
            explanation = grade?.source == .ai ? grade?.explanation : nil
        } else {
            kind = .incorrect
            title = "Nie tym razem"
            message = model.type == .meaning
                ? "Poprawnie: **\(expected)**"
                : "Poprawnie: **\(expected)** — \(VocabFeedbackSummary.escaped(content.meaning.translation))"
            let text = grade?.explanation ?? ""
            explanation = text.isEmpty ? "Sprawdź znaczenie użyte w tym kontekście." : text
        }
    }

    /// Znaki Markdown w treści użytkownika nie mogą zmienić formatowania.
    static func escaped(_ text: String) -> String {
        var result = ""
        for character in text {
            if "*_`[]\\".contains(character) {
                result.append("\\")
            }
            result.append(character)
        }
        return result
    }
}

/// Szczegóły w rozwijanym wyjaśnieniu: wymowa, zdanie, tłumaczenie, notatka, „W rozmowie”.
private struct VocabExplanationDetails: View {
    let content: VocabExerciseContent

    @Environment(SpeechService.self) private var speech

    var body: some View {
        if !content.word.ipa.isEmpty {
            Text(content.word.ipa)
                .font(FluentFont.ipa)
                .foregroundStyle(Palette.inkSecondary)
        }
        StudyExampleSentence(text: content.example, focus: content.focus)
        StudyPairTranslation(pair: content.pair)
        if !noteText.isEmpty {
            Text(noteText)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !content.example.isEmpty {
            Button {
                speech.speak(content.example)
            } label: {
                Label("Posłuchaj zdania", systemImage: "speaker.wave.2")
                    .font(FluentFont.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var noteText: String {
        let base = content.word.note.isEmpty ? content.meaning.definition : content.word.note
        guard !content.meaning.natural.isEmpty else { return base }
        return base.isEmpty ? "W rozmowie: \(content.meaning.natural)." : "\(base) W rozmowie: \(content.meaning.natural)."
    }
}

/// „Pokaż warianty” po sprawdzeniu — wszystkie akceptowane odpowiedzi.
private struct VocabAcceptedVariants: View {
    let answers: [String]

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            Text(answers.joined(separator: " · "))
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.xxs)
        } label: {
            Text("Pokaż warianty (\(answers.count))")
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
        }
        .tint(Palette.accent)
    }
}
