import SwiftUI

/// Przycisk „Skanuj tekst” do paska narzędzi (Słownik, I3). Wybrane słowo otwiera szybkie
/// dodawanie z wpisanym hasłem — dopiero PO zamknięciu arkusza skanera (`onDismiss`), żeby
/// nie prezentować dwóch arkuszy naraz. Rozpoznany tekst zostaje do ponownego otwarcia.
struct ScanToolbarButton: View {
    @Environment(AppRouter.self) private var router

    @State private var isScanning = false
    @State private var scannedText = ""
    @State private var pendingTerm: String?

    var body: some View {
        Button {
            pendingTerm = nil
            isScanning = true
        } label: {
            Image(systemName: "text.viewfinder")
        }
        .accessibilityLabel(Text("Skanuj tekst"))
        .sheet(isPresented: $isScanning, onDismiss: openPendingTerm) {
            ScanTextScreen(text: $scannedText) { (term: String) in
                pendingTerm = term
            }
        }
    }

    private func openPendingTerm() {
        guard let term = pendingTerm else { return }
        pendingTerm = nil
        router.presentQuickAdd(prefill: term)
    }
}
