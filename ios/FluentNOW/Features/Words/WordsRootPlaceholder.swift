import SwiftUI

/// ZAŚLEPKA (design-shell) — fala 2 zastąpi ją Słownikiem. Pokazuje architekturę karty:
/// segmenty Słowa / Kolekcje / Tematy powiązane z `AppRouter.librarySection`.
struct WordsRootPlaceholder: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            Picker("Widok słownika", selection: $router.librarySection) {
                ForEach(LibrarySection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.xs)

            switch router.librarySection {
            case .words:
                ScrollView {
                    EmptyStateView(
                        systemImage: "text.book.closed",
                        title: "Twój słownik jest pusty",
                        message: "Dodaj pierwsze słowo lub cały temat — nauka zacznie się od razu.",
                        actionTitle: "Dodaj słowo"
                    ) {
                        router.presentQuickAdd()
                    }
                }
            case .collections:
                CollectionsRootScreen()
            case .topics:
                TopicsRootScreen()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle("Słownik")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { QuickAddButton() }
        }
    }
}

#Preview("Słownik — zaślepka") {
    NavigationStack {
        WordsRootPlaceholder()
    }
    .environment(AppRouter())
}
