import SwiftUI

/// Wynik jednej umiejętności (0–100). `score == nil` = umiejętność jeszcze nie ćwiczona → „—”
/// (jak na stronie: niećwiczone umiejętności nie udają zera).
///
/// ```swift
/// SkillBar(skill: .recall, score: meaning.scores[.recall]?.value)
/// ```
struct SkillBar: View {
    private let title: String
    private let systemImage: String?
    private let score: Double?
    private let tint: Color

    init(skill: SkillTone, score: Double?) {
        self.title = skill.title
        self.systemImage = skill.systemImage
        self.score = score
        self.tint = skill.color
    }

    init(title: String, score: Double?, tint: Color = Palette.accent, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
        self.score = score
        self.tint = tint
    }

    /// Tekst wyniku: „72%” albo „—”.
    static func scoreText(_ score: Double?) -> String {
        guard let score, score.isFinite else { return "—" }
        let rounded = Int(min(max(score, 0), 100).rounded())
        return "\(rounded)%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs + 2) {
            HStack(spacing: Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(FluentFont.footnote)
                        .foregroundStyle(tint)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: Spacing.xs)
                Text(Self.scoreText(score))
                    .font(FluentFont.numberSmall)
                    .foregroundStyle(score == nil ? Palette.inkSecondary : Palette.ink)
            }
            LinearProgressBar(progress: (score ?? 0) / 100, tint: tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(accessibilityValueText))
    }

    private var accessibilityValueText: String {
        guard let score, score.isFinite else { return "jeszcze nie ćwiczono" }
        return "\(Int(min(max(score, 0), 100).rounded())) procent"
    }
}

#Preview("Paski umiejętności") {
    Card {
        SkillBar(skill: .recognition, score: 82)
        SkillBar(skill: .recall, score: 54)
        SkillBar(skill: .spelling, score: 31)
        SkillBar(skill: .listening, score: nil)
        SkillBar(skill: .usage, score: 8)
    }
    .padding(Spacing.screen)
    .background(Palette.background)
}
