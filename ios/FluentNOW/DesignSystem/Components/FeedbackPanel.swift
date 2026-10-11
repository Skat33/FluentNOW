import SwiftUI

/// Informacja zwrotna po odpowiedzi: wynik (poprawnie / prawie / błędnie / wskazówka),
/// opcjonalnie poprawna odpowiedź i wyjaśnienie, plus dowolna treść (np. przycisk „Pokaż warianty”).
/// Przy pojawieniu się wywołuje haptykę odpowiadającą wynikowi (`playsHaptic`).
///
/// ```swift
/// FeedbackPanel(kind: .incorrect,
///               message: "Poprawnie: I'd like to **borrow** your pen.",
///               explanation: "„Borrow” = pożyczyć OD kogoś. „Lend” = pożyczyć KOMUŚ.")
/// FeedbackPanel(kind: .correct) { SpeakButton { … } }
/// ```
/// `message` i `explanation` obsługują prosty Markdown (`**pogrubienie**`, `*kursywa*`).
struct FeedbackPanel<Accessory: View>: View {
    private let kind: FeedbackKind
    private let title: String
    private let message: String?
    private let explanation: String?
    private let playsHaptic: Bool
    private let accessory: Accessory

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fluentHapticsEnabled) private var hapticsEnabled

    init(
        kind: FeedbackKind,
        title: String? = nil,
        message: String? = nil,
        explanation: String? = nil,
        playsHaptic: Bool = true,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.kind = kind
        self.title = title ?? kind.defaultTitle
        self.message = message
        self.explanation = explanation
        self.playsHaptic = playsHaptic
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: kind.systemImage)
                    .font(FluentFont.title)
                    .foregroundStyle(kind.tone.foreground)
                    .symbolEffect(.bounce, value: reduceMotion ? false : hasAppeared)
                    .accessibilityHidden(true)
                Text(title)
                    .font(FluentFont.title)
                    .foregroundStyle(kind.tone.foreground)
                    .accessibilityAddTraits(.isHeader)
            }
            if let message, !message.isEmpty {
                Text(FeedbackPanelText.markdown(message))
                    .font(FluentFont.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let explanation, !explanation.isEmpty {
                Text(FeedbackPanelText.markdown(explanation))
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            accessory
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .fluentCardBackground(.tinted(kind.tone), cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .onAppear { hasAppeared = true }
        .sensoryFeedback(kind.haptic ?? FluentHaptic.selection, trigger: hasAppeared) { oldValue, newValue in
            playsHaptic && hapticsEnabled && kind.haptic != nil && !oldValue && newValue
        }
    }
}

extension FeedbackPanel where Accessory == EmptyView {
    init(
        kind: FeedbackKind,
        title: String? = nil,
        message: String? = nil,
        explanation: String? = nil,
        playsHaptic: Bool = true
    ) {
        self.init(kind: kind, title: title, message: message, explanation: explanation, playsHaptic: playsHaptic) {
            EmptyView()
        }
    }
}

/// Bezpieczne parsowanie Markdown (błąd parsowania → zwykły tekst, nigdy crash).
enum FeedbackPanelText {
    static func markdown(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let parsed = try? AttributedString(markdown: source, options: options) {
            return parsed
        }
        return AttributedString(source)
    }
}

#Preview("Informacja zwrotna") {
    ScrollView {
        VStack(spacing: Spacing.m) {
            FeedbackPanel(kind: .correct, message: "I'd like to **borrow** your pen.") {
                SpeakButton(size: .small) {}
            }
            FeedbackPanel(kind: .almost, message: "Drobna literówka: **recieve** → **receive**.")
            FeedbackPanel(
                kind: .incorrect,
                message: "Poprawnie: Could you **lend** me your pen?",
                explanation: "„Lend” = pożyczyć komuś. „Borrow” = pożyczyć od kogoś."
            )
            FeedbackPanel(kind: .info, message: "To słowo ma też znaczenie „brzeg rzeki”.")
        }
        .padding(Spacing.screen)
    }
    .background(Palette.background)
}
