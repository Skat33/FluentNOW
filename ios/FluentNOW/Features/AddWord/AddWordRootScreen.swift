import SwiftUI

/// Arkusz szybkiego dodawania (prezentowany przez `RootView` dla `AppSheet.quickAdd`).
/// Kontrakt powłoki: `init(prefill: String?)`; arkusz ma WŁASNY `NavigationStack` (pasek z „Anuluj”/„Zapisz”).
/// Zamknięcie: `router.dismissSheet()` lub `@Environment(\.dismiss)`.
/// Fala 2 (ui-library): zastąp `body` docelowym ekranem i usuń `AddWordRootPlaceholder`.
struct AddWordRootScreen: View {
    let prefill: String?

    init(prefill: String? = nil) {
        self.prefill = prefill
    }

    var body: some View {
        AddWordRootPlaceholder(prefill: prefill)
    }
}
