import SwiftUI
import FluentKit

/// Karta „Test” na ekranie Nauka (FEEDBACK-6 K4; układ wstawia study-layout jako `StudyTestCard()`).
/// Sama otwiera pełny ekran testu. Stany: brak testu → „Rozpocznij test”; przerwany test →
/// „Kontynuuj test” / „Porzuć”; ukończony, niezamknięty wynik → „Zobacz wynik”.
struct StudyTestCard: View {
    @Environment(LearningStore.self) private var store

    @State private var isPresented = false
    @State private var confirmsAbandon = false

    init() {}

    var body: some View {
        let info = TestCardInfo(state: store.state, now: store.now())
        Card(spacing: Spacing.m) {
            TestCardHeader(info: info)
            Text(info.description)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let last = info.lastLine {
                Label(last, systemImage: "clock.arrow.circlepath")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            TestCardButtons(status: info.status, onOpen: { isPresented = true }, onAbandon: { confirmsAbandon = true })
        }
        .fullScreenCover(isPresented: $isPresented) {
            StudyTestScreen()
        }
        // FEEDBACK-8 M6: wybór na środku ekranu (alert), jak „Kontynuuj / Zacznij od nowa”.
        .alert("Porzucić test?", isPresented: $confirmsAbandon) {
            Button("Porzuć test", role: .destructive) { abandon() }
            Button("Anuluj", role: .cancel) {}
        } message: {
            Text("Wyniku nie będzie, ale odpowiedzi na Twoje słowa zostają w historii powtórek.")
        }
    }

    private func abandon() {
        store.update(.session) { (state: inout LearnerState) -> Void in
            state = AssessmentEngine.abandon(state)
        }
    }
}

/// Stan karty wyliczony z `LearnerState` (lekko — bez budowania testu).
private struct TestCardInfo {
    enum Status: Equatable {
        case none
        case paused(answered: Int, total: Int)
        case finished
    }

    let status: Status
    let band: AssessmentBand
    let lastLine: String?

    init(state: LearnerState, now: Timestamp) {
        if let session = state.assessment {
            band = session.band
            status = session.completedAt != nil ? .finished : .paused(answered: session.index, total: session.total)
        } else {
            band = AssessmentBuilder.band(state, now: now)
            status = .none
        }
        if let last = state.assessmentHistory.max(by: { (a: AssessmentHistoryEntry, b: AssessmentHistoryEntry) -> Bool in a.at < b.at }) {
            lastLine = "Ostatnio: \(StudyFormat.date(last.at)) · \(last.percent)% · poziom \(last.level)"
        } else {
            lastLine = nil
        }
    }

    var subtitle: String {
        switch status {
        case .none: return "Ok. 30 pytań · ok. 18 min · poziom \(band.rangeText)"
        case .paused(let answered, let total): return "Przerwany: \(answered) z \(total) pytań"
        case .finished: return "Ukończony — wynik czeka"
        }
    }

    var description: String {
        switch status {
        case .none:
            return "Każdy typ zadania po kolei, dopasowany do Twojego poziomu. Bez podpowiedzi i bez cofania — poprawne odpowiedzi zobaczysz na końcu."
        case .paused:
            return "Dokończ od bieżącego pytania. Odpowiedzi, których już udzieliłeś, są zapisane."
        case .finished:
            return "Zobacz wynik, szacowany poziom i listę błędów."
        }
    }
}

private struct TestCardHeader: View {
    let info: TestCardInfo

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            Image(systemName: "checklist")
                .font(FluentFont.title)
                .foregroundStyle(Palette.accent)
                .frame(width: 44, height: 44)
                .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Test")
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(info.subtitle)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TestCardButtons: View {
    let status: TestCardInfo.Status
    let onOpen: () -> Void
    let onAbandon: () -> Void

    var body: some View {
        switch status {
        case .none:
            PrimaryButton("Rozpocznij test", systemImage: "play.fill", action: onOpen)
        case .paused:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s) { pausedButtons }
                VStack(spacing: Spacing.xs) { pausedButtons }
            }
        case .finished:
            PrimaryButton("Zobacz wynik", systemImage: "chart.bar", action: onOpen)
        }
    }

    @ViewBuilder
    private var pausedButtons: some View {
        PrimaryButton("Kontynuuj test", systemImage: "play.fill", action: onOpen)
        SecondaryButton("Porzuć", systemImage: "xmark", role: .destructive, action: onAbandon)
    }
}

#Preview("Karta testu") {
    ScrollView {
        StudyTestCard()
            .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
