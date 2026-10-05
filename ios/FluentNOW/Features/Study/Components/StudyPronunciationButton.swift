import SwiftUI

/// „Powiedz to” — orientacyjne sprawdzenie wymowy (rozpoznawanie mowy na urządzeniu).
/// Wynik nie wpływa na opanowanie słowa (jak na stronie: wymowa nie liczy się do postępu).
struct StudyPronunciationButton: View {
    let expected: String

    @Environment(PronunciationService.self) private var pronunciation
    @State private var result: PronunciationResult?
    @State private var message: String?
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button(action: toggle) {
                Label(buttonTitle, systemImage: pronunciation.isListening ? "stop.circle" : "mic")
                    .font(FluentFont.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: HitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isUnavailable || (isWorking && !pronunciation.isListening))
            .accessibilityHint(Text("Nagrywa Twoją wymowę i porównuje ją z wzorcem. Nie wpływa na postęp."))

            if pronunciation.isListening && !pronunciation.liveTranscript.isEmpty {
                Text(pronunciation.liveTranscript)
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityHidden(true)
            }
            if let result {
                StudyPronunciationResultView(result: result)
            } else if let message {
                Text(message)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onDisappear {
            if pronunciation.isListening {
                pronunciation.stop()
            }
        }
    }

    private var isUnavailable: Bool {
        pronunciation.permission == .unavailable || pronunciation.permission == .denied
    }

    private var buttonTitle: String {
        switch pronunciation.permission {
        case .unavailable: return "Sprawdzanie wymowy niedostępne"
        case .denied: return "Brak zgody na mikrofon"
        default: return pronunciation.isListening ? "Zakończ nagrywanie" : "Powiedz to"
        }
    }

    private func toggle() {
        if pronunciation.isListening {
            pronunciation.stop()
            return
        }
        guard !isWorking else { return }
        isWorking = true
        result = nil
        message = nil
        Task { @MainActor in
            defer { isWorking = false }
            var permission = pronunciation.permission
            if permission == .unknown {
                permission = await pronunciation.requestPermission()
            }
            guard permission == .granted else {
                message = permission == .unavailable
                    ? "Rozpoznawanie mowy nie jest dostępne na tym urządzeniu."
                    : "Aby sprawdzić wymowę, zezwól na mikrofon i rozpoznawanie mowy w Ustawieniach systemu."
                return
            }
            do {
                let heard = try await pronunciation.listen(expected: expected)
                result = heard
                AccessibilityNotification.Announcement(heard.verdictPl).post()
            } catch {
                message = "Nie udało się nagrać wymowy. Spróbuj ponownie w cichszym miejscu."
            }
        }
    }
}

/// Wynik orientacyjny wymowy z uczciwym opisem.
private struct StudyPronunciationResultView: View {
    let result: PronunciationResult

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(result.verdictPl)
                .font(FluentFont.callout.weight(.semibold))
                .foregroundStyle(Palette.ink)
            if !result.transcript.isEmpty {
                Text("Usłyszeliśmy: „\(result.transcript)”")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Text("Wynik orientacyjny — rozpoznawanie mowy nie jest egzaminatorem i nie wpływa na Twój postęp.")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluentCardBackground(.muted, cornerRadius: Radius.small)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Powiedz to") {
    StudyPronunciationButton(expected: "boarding pass")
        .padding(Spacing.screen)
        .background(Palette.background)
        .fluentPreviewEnvironment()
}
