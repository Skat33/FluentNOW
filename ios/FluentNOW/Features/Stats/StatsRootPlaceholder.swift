import SwiftUI

/// ZAŚLEPKA (design-shell) — fala 2 zastąpi ją ekranem Postępów (Swift Charts).
struct StatsRootPlaceholder: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                SectionHeader("Umiejętności", subtitle: "Średnia ćwiczonych znaczeń")
                Card {
                    ForEach(SkillTone.allCases) { skill in
                        SkillBar(skill: skill, score: nil)
                    }
                }
            }
            .padding(Spacing.screen)
        }
        .navigationTitle("Postępy")
    }
}

#Preview("Postępy — zaślepka") {
    NavigationStack {
        StatsRootPlaceholder()
    }
}
