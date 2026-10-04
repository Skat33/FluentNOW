import SwiftUI

/// ZAŚLEPKA (design-shell) — fala 2 zastąpi ją listą kolekcji.
struct CollectionsRootPlaceholder: View {
    var body: some View {
        ScrollView {
            EmptyStateView(
                systemImage: "square.stack.3d.up",
                title: "Kolekcje",
                message: "Tu pojawią się Twoje kolekcje z postępem i przyciskiem „Ćwicz tę kolekcję”."
            )
        }
    }
}

#Preview("Kolekcje — zaślepka") {
    CollectionsRootPlaceholder()
        .background(Palette.background)
}
