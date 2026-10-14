import SwiftUI

/// Przycisk „+” do paska narzędzi (Dzisiaj, Słownik): jeden punkt wejścia do dodawania.
/// Dotknięcie otwiera arkusz z wyborem „Dodaj słowo” / „Szukaj tematu” (przełącznik u góry);
/// przytrzymanie pokazuje oba warianty od razu. ⌘N = dodaj słowo.
///
/// ```swift
/// .toolbar { ToolbarItem(placement: .primaryAction) { QuickAddButton() } }
/// ```
struct QuickAddButton: View {
    @Environment(AppRouter.self) private var router
    private let prefill: String?

    init(prefill: String? = nil) {
        self.prefill = prefill
    }

    var body: some View {
        Button {
            router.presentQuickAdd(prefill: prefill)
        } label: {
            Image(systemName: "plus")
                .fontWeight(.semibold)
        }
        .accessibilityLabel(Text("Dodaj słowo lub temat"))
        .keyboardShortcut("n", modifiers: .command)
        .contextMenu {
            Button {
                router.presentQuickAdd(prefill: prefill)
            } label: {
                Label("Dodaj słowo", systemImage: "character.book.closed")
            }
            Button {
                router.presentTopicSearch()
            } label: {
                Label("Szukaj tematu", systemImage: "text.magnifyingglass")
            }
        }
    }
}

#Preview("Przycisk dodawania") {
    NavigationStack {
        Text("Ekran")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { QuickAddButton() }
            }
    }
    .environment(AppRouter())
}
