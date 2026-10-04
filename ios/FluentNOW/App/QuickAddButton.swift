import SwiftUI

/// Przycisk „+” do paska narzędzi (Dzisiaj, Słownik): otwiera arkusz szybkiego dodawania.
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
        .accessibilityLabel(Text("Dodaj słowo"))
        .keyboardShortcut("n", modifiers: .command)
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
