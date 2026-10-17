import SwiftUI
import FluentKit

/// Podsumowanie sesji — „Mały krok za Tobą.”
struct StudySummaryView: View {
    let data: StudySummaryData
    /// `nil` = bez przycisku „Jeszcze 5 minut”.
    var onExtend: (() -> Void)?
    var isExtending: Bool = false
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var preferences
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Spacing.l) {
            StudySummaryHeader()
            StudySummaryXPBadge(reviewIDs: data.reviewIDs, historyIDPrefix: data.historyIDPrefix)
            StudySummaryStats(data: data)
            if !data.modeLines.isEmpty {
                StudySummaryModes(lines: data.modeLines)
            }
            if !data.skills.isEmpty {
                StudySummarySkills(skills: data.skills)
            }
            if !data.grown.isEmpty {
                StudySummaryWordList(title: "Te słowa urosły", systemImage: "arrow.up.right", lines: data.grown)
            }
            if !data.toReview.isEmpty {
                StudySummaryWordList(title: "Warto do nich wrócić", systemImage: "arrow.clockwise", lines: data.toReview)
            }
            Text("Kolejne terminy powtórek są już dopasowane do Twoich odpowiedzi.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Spacing.s) {
                if let onExtend {
                    PrimaryButton("Jeszcze 5 minut", systemImage: "plus.circle", isLoading: isExtending, action: onExtend)
                    SecondaryButton("Zakończ", systemImage: "checkmark", action: onFinish)
                } else {
                    PrimaryButton("Zakończ", systemImage: "checkmark", action: onFinish)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.97)
        .onAppear {
            withAnimation(Motion.resolved(Motion.emphasized, reduceMotion: reduceMotion, fallback: Motion.reducedFade)) {
                appeared = true
            }
            AccessibilityNotification.Announcement("Sesja ukończona. \(data.correct) z \(data.total) poprawnych.").post()
        }
        .sensoryFeedback(FluentHaptic.answerCorrect, trigger: appeared) { old, new in
            preferences.hapticsEnabled && !old && new
        }
    }
}

private struct StudySummaryHeader: View {
    var body: some View {
        VStack(spacing: Spacing.s) {
            Image(systemName: "checkmark")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 84, height: 84)
                .background(Palette.accentFill, in: Circle())
                .accessibilityHidden(true)
            Text("Dobra robota")
                .fluentEyebrow()
                .foregroundStyle(Palette.accent)
            Text("Mały krok za Tobą.")
                .font(FluentFont.display)
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("Zrobiłeś dziś coś dobrego dla swojego angielskiego.")
                .font(FluentFont.callout)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }
}

private struct StudySummaryStats: View {
    let data: StudySummaryData

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Spacing.s)], spacing: Spacing.s) {
            StatTile(title: "Zadania", value: "\(data.total)", systemImage: "square.stack", tone: .accent)
            StatTile(title: "Samodzielnie poprawne", value: "\(data.correct)", systemImage: "checkmark.circle", tone: .success)
            StatTile(title: "Skuteczność", value: "\(data.percent)%", systemImage: "target", tone: .info)
            if data.seconds > 0 {
                StatTile(title: "Czas", value: StudyFormat.duration(data.seconds), systemImage: "clock", tone: .neutral)
            }
        }
    }
}

private struct StudySummaryModes: View {
    let lines: [StudySummaryData.ModeLine]

    var body: some View {
        Card {
            SectionHeader("Rodzaje ćwiczeń")
            ForEach(lines) { line in
                HStack {
                    Label(line.mode.namePl, systemImage: line.mode.studySystemImage)
                        .font(FluentFont.body)
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: Spacing.xs)
                    Text("\(line.correct) / \(line.total)")
                        .font(FluentFont.numberSmall)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct StudySummarySkills: View {
    let skills: [StudySummaryData.SkillCount]

    var body: some View {
        Card {
            SectionHeader("Ćwiczone umiejętności")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.xs) { chips }
                VStack(alignment: .leading, spacing: Spacing.xs) { chips }
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(skills) { item in
            TagChip("\(item.skill.namePl) · \(item.count)", systemImage: SkillTone(rawValue: item.skill.rawValue)?.systemImage, tone: .accent)
        }
    }
}

private struct StudySummaryWordList: View {
    let title: String
    let systemImage: String
    let lines: [StudySummaryData.WordLine]

    var body: some View {
        Card {
            Label(title, systemImage: systemImage)
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(lines) { line in
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.term)
                        .font(FluentFont.bodyEmphasized)
                        .foregroundStyle(Palette.ink)
                    Text(line.detail)
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview("Podsumowanie sesji") {
    ScrollView {
        StudySummaryView(
            data: StudySummaryData(
                total: 12,
                correct: 9,
                seconds: 312,
                skills: [.init(skill: .recall, count: 4), .init(skill: .usage, count: 3)],
                grown: [.init(id: "1", term: "borrow", detail: "+12% · pożyczyć (od kogoś)")],
                toReview: [.init(id: "2", term: "lend", detail: "pożyczyć (komuś)")],
                modeLines: []
            ),
            onExtend: {},
            onFinish: {}
        )
        .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
