import SwiftUI

/// ZAŚLEPKA (design-shell) — fala 2 zastąpi ją przeglądarką tematów.
struct TopicsRootPlaceholder: View {
    var body: some View {
        ScrollView {
            EmptyStateView(
                systemImage: "square.grid.2x2",
                title: "Tematy słówek",
                message: "Tu pojawią się wbudowane tematy — dodasz cały temat lub wybrane słowa w kilka sekund, offline."
            )
        }
    }
}

#Preview("Tematy — zaślepka") {
    TopicsRootPlaceholder()
        .background(Palette.background)
}
