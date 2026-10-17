import SwiftUI
import FluentKit

/// „+XP” w podsumowaniu sesji (G5): XP tej sesji liczone w tle z historii
/// (`Progression.sessionGain`) i krótkie pojawienie się (bez animacji przy „Ogranicz ruch”).
/// Awans na nowy poziom — dodatkowa linia z rangą.
struct StudySummaryXPBadge: View {
    let reviewIDs: [String]
    let historyIDPrefix: String?

    @Environment(LearningStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var gain: XPSessionGain?
    @State private var shown = false

    var body: some View {
        // `VStack` (nie `Group`) — pusty `Group` nie uruchamia `.task`.
        VStack(spacing: 0) {
            if let gain, gain.xp > 0 {
                StudySummaryXPContent(gain: gain)
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown || reduceMotion ? 1 : 0.85)
                    .onAppear { reveal() }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard gain == nil, !reviewIDs.isEmpty || historyIDPrefix != nil else { return }
        let ids = reviewIDs
        let prefix = historyIDPrefix
        let computed: XPSessionGain = await store.compute { (state: LearnerState) -> XPSessionGain in
            Progression.sessionGain(state, reviewIDs: ids, historyIDPrefix: prefix)
        }
        guard !Task.isCancelled else { return }
        gain = computed
        if computed.xp > 0 {
            AccessibilityNotification.Announcement(StudySummaryXPText.announcement(computed)).post()
        }
    }

    private func reveal() {
        let animation = Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)
        withAnimation(animation) {
            shown = true
        }
    }
}

private struct StudySummaryXPContent: View {
    let gain: XPSessionGain

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            Text(XPText.gain(gain.xp))
                .font(FluentFont.numberLarge)
                .foregroundStyle(Palette.accent)
            if gain.leveledUp {
                Label(StudySummaryXPText.levelUp(gain), systemImage: XPRank.rank(forLevel: gain.levelAfter).systemImage)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.success)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
        .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

enum StudySummaryXPText {
    static func levelUp(_ gain: XPSessionGain) -> String {
        let rank = XPRank.rank(forLevel: gain.levelAfter)
        if XPRank.rank(forLevel: gain.levelBefore) != rank {
            return "Nowy poziom \(gain.levelAfter) i ranga „\(rank.namePl)”"
        }
        return "Nowy poziom: \(gain.levelAfter)"
    }

    static func announcement(_ gain: XPSessionGain) -> String {
        var text = "Zdobyto \(gain.xp) punktów doświadczenia."
        if gain.leveledUp { text += " " + levelUp(gain) + "." }
        return text
    }
}
