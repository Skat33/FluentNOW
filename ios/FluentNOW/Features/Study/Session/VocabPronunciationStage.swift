import SwiftUI
import FluentKit

// „Powiedz to zdanie na głos” (FEEDBACK-10 P2): po poprawnej rozsypance (i luce) — nagranie zdania,
// wynik słowo po słowie (FluentKit `PronunciationScoring`), „Posłuchaj”, „Spróbuj ponownie”,
// „Pomiń”. Wynik jest orientacyjny i nie zmienia opanowania. Etap nie blokuje „Dalej”.
// Sesja audio: przed nagraniem mowa milknie (`speech.stop()`), a `PronunciationService` przejmuje
// dźwięk przez `AudioFocus` (wyszukiwanie głosowe i mowa z innych miejsc kończą się same).

/// Miejsce etapu w karcie wyniku: etap, jednorazowa informacja o braku mikrofonu albo nic.
struct VocabPronunciationSlot: View {
    let model: VocabExerciseModel

    @Environment(PronunciationService.self) private var pronunciation
    @Environment(AppPreferences.self) private var preferences
    @AppStorage("study.pronunciationNoticeShown") private var noticeShown = false
    /// Informacja zostaje widoczna w tym zadaniu, choć zapis „pokazano” już nastąpił.
    @State private var noticeLatched = false

    /// Etap dotyczy tego zadania (ustawienie włączone, poprawna rozsypanka / luka, nie test).
    @MainActor
    static func applies(to model: VocabExerciseModel, enabled: Bool) -> Bool {
        guard enabled, !model.isAssessment, model.isFinished, model.outcome?.correct == true else { return false }
        guard model.type == .scramble || model.type == .cloze else { return false }
        return SentenceScramble.tokens(model.content.example).count >= 2
    }

    private var isBlocked: Bool {
        pronunciation.permission == .denied || pronunciation.permission == .unavailable
    }

    var body: some View {
        if VocabPronunciationSlot.applies(to: model, enabled: preferences.pronunciationPracticeEnabled) {
            if !isBlocked {
                VocabPronunciationStage(sentence: model.content.example)
            } else if !noticeShown || noticeLatched {
                VocabPronunciationNotice(unavailable: pronunciation.permission == .unavailable)
                    .onAppear {
                        noticeLatched = true
                        noticeShown = true
                    }
            }
        }
    }
}

/// Jednorazowa informacja: etap wymowy jest pomijany (brak zgody / brak rozpoznawania mowy).
private struct VocabPronunciationNotice: View {
    let unavailable: Bool

    var body: some View {
        Label {
            Text(unavailable
                 ? "Pomijamy mówienie zdań na głos — rozpoznawanie mowy nie jest dostępne na tym urządzeniu."
                 : "Pomijamy mówienie zdań na głos — brak zgody na mikrofon. Włączysz ją w Ustawieniach systemu, a etap wyłączysz w Ustawieniach aplikacji (Wymowa).")
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "mic.slash")
        }
        .font(FluentFont.footnote)
        .foregroundStyle(Palette.inkSecondary)
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluentCardBackground(.muted, cornerRadius: Radius.small)
    }
}

/// Etap: zdanie, nagranie, wynik słowo po słowie, „Posłuchaj”, „Spróbuj ponownie”, „Pomiń”.
struct VocabPronunciationStage: View {
    let sentence: String

    @Environment(PronunciationService.self) private var pronunciation
    @Environment(SpeechService.self) private var speech
    @State private var score: PronunciationScore?
    @State private var message: String?
    @State private var isWorking = false
    @State private var skipped = false
    /// Licznik prób (haptyka wyniku, ogłoszenie VoiceOver).
    @State private var attempts = 0

    /// Dłuższe zdania potrzebują więcej czasu niż słowo (6 s).
    private static let maxDuration: TimeInterval = 12

    var body: some View {
        if skipped {
            EmptyView()
        } else {
            Card(spacing: Spacing.s) {
                VocabPronunciationHeader()
                VocabPronunciationSentence(sentence: sentence, score: score)
                status
                VocabPronunciationActions(
                    isListening: pronunciation.isListening,
                    isBusy: isWorking && !pronunciation.isListening,
                    hasResult: score != nil,
                    onRecord: record,
                    onListen: listen,
                    onSkip: skip
                )
            }
            .fluentSensoryFeedback(resultHaptic, trigger: attempts)
            .onDisappear {
                if pronunciation.isListening {
                    pronunciation.stop()
                }
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if pronunciation.isListening {
            Text(pronunciation.liveTranscript.isEmpty ? "Słucham… powiedz całe zdanie." : pronunciation.liveTranscript)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        } else if let score {
            VocabPronunciationVerdict(score: score)
        }
        if let message {
            Text(message)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var resultHaptic: SensoryFeedback {
        guard let score else { return FluentHaptic.selection }
        return score.fraction >= 0.9 ? FluentHaptic.answerCorrect : FluentHaptic.answerAlmost
    }

    // MARK: Akcje

    private func record() {
        if pronunciation.isListening {
            pronunciation.stop()
            return
        }
        guard !isWorking else { return }
        isWorking = true
        message = nil
        Task { @MainActor in
            defer { isWorking = false }
            var permission = pronunciation.permission
            if permission == .unknown {
                permission = await pronunciation.requestPermission()
            }
            guard permission == .granted else {
                message = permission == .unavailable
                    ? "Rozpoznawanie mowy nie jest dostępne na tym urządzeniu — możesz pominąć ten etap."
                    : "Bez zgody na mikrofon i rozpoznawanie mowy etap jest pomijany. Zgodę włączysz w Ustawieniach systemu."
                return
            }
            guard pronunciation.isInputAvailable else {
                message = "Mikrofon jest teraz zajęty (np. trwa rozmowa). Spróbuj za chwilę albo pomiń."
                return
            }
            speech.stop()
            do {
                let heard = try await pronunciation.listen(expected: sentence, maxDuration: VocabPronunciationStage.maxDuration)
                let result = PronunciationScoring.score(expected: sentence, heard: heard.transcript)
                score = result
                attempts += 1
                AccessibilityNotification.Announcement(VocabPronunciationText.announcement(result)).post()
            } catch {
                message = (error as? LocalizedError)?.errorDescription ?? "Nie udało się nagrać wymowy. Spróbuj ponownie w cichszym miejscu."
            }
        }
    }

    private func listen() {
        if pronunciation.isListening {
            pronunciation.stop()
        }
        speech.speak(sentence)
    }

    private func skip() {
        if pronunciation.isListening {
            pronunciation.stop()
        }
        skipped = true
        let text: String = "Pominięto mówienie zdania"
        AccessibilityNotification.Announcement(text).post()
    }
}

private struct VocabPronunciationHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Label("Powiedz to zdanie na głos", systemImage: "waveform")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Nieobowiązkowe — wynik nie wpływa na postęp.")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
    }
}

/// Zdanie: przed nagraniem zwykły tekst, po nagraniu słowa rozpoznane (zielone) i do powtórzenia
/// (pomarańczowe, podkreślone — kolor nie jest jedynym nośnikiem informacji).
private struct VocabPronunciationSentence: View {
    let sentence: String
    let score: PronunciationScore?

    var body: some View {
        if let score {
            Text(VocabPronunciationText.attributed(score))
                .font(FluentFont.sentence)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(VocabPronunciationText.wordsLabel(score)))
        } else {
            Text(sentence)
                .font(FluentFont.sentence)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct VocabPronunciationVerdict: View {
    let score: PronunciationScore

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(score.verdictPl)
                .font(FluentFont.callout.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Text("Rozpoznane słowa: \(score.heardCount) z \(score.total). Wynik orientacyjny — rozpoznawanie mowy nie jest egzaminatorem.")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// „Nagraj / Zakończ / Spróbuj ponownie”, „Posłuchaj”, „Pomiń”.
private struct VocabPronunciationActions: View {
    let isListening: Bool
    let isBusy: Bool
    let hasResult: Bool
    let onRecord: () -> Void
    let onListen: () -> Void
    let onSkip: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.s) { buttons }
            VStack(alignment: .leading, spacing: Spacing.xs) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        SecondaryButton(recordTitle, systemImage: isListening ? "stop.circle" : "mic", isLoading: isBusy, fillsWidth: false, action: onRecord)
            .accessibilityHint(Text(isListening ? "Kończy nagrywanie" : "Nagrywa Twoją wymowę zdania"))
        SecondaryButton("Posłuchaj", systemImage: "speaker.wave.2", fillsWidth: false, action: onListen)
            .accessibilityHint(Text("Odtwarza wzorcową wymowę zdania"))
        Button(action: onSkip) {
            Text("Pomiń")
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
                .frame(minHeight: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Ukrywa ćwiczenie wymowy w tym zadaniu"))
    }

    private var recordTitle: String {
        if isListening { return "Zakończ" }
        return hasResult ? "Spróbuj ponownie" : "Nagraj"
    }
}

/// Teksty i atrybuty etapu wymowy.
enum VocabPronunciationText {
    /// Słowa zdania: rozpoznane w kolorze sukcesu, pozostałe w kolorze ostrzeżenia z podkreśleniem.
    static func attributed(_ score: PronunciationScore) -> AttributedString {
        var result = AttributedString()
        for (index, word) in score.words.enumerated() {
            if index > 0 {
                result.append(AttributedString(" "))
            }
            var piece = AttributedString(word.text)
            piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = word.heard ? Palette.success : Palette.warning
            if !word.heard {
                piece[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle.single
                piece.inlinePresentationIntent = .stronglyEmphasized
            }
            result.append(piece)
        }
        return result
    }

    /// VoiceOver: zdanie i słowa do powtórzenia.
    static func wordsLabel(_ score: PronunciationScore) -> String {
        let sentence = score.words.map { (word: PronunciationWord) -> String in word.text }.joined(separator: " ")
        let missed = score.missedWords
        if missed.isEmpty {
            return "\(sentence). Wszystkie słowa rozpoznane."
        }
        return "\(sentence). Do powtórzenia: \(missed.joined(separator: ", "))."
    }

    /// Ogłoszenie po nagraniu.
    static func announcement(_ score: PronunciationScore) -> String {
        let missed = score.missedWords
        guard !missed.isEmpty, !score.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return score.verdictPl }
        return "\(score.verdictPl) Do powtórzenia: \(missed.joined(separator: ", "))."
    }
}
