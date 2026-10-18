import SwiftUI

/// „Skanuj tekst” w szybkim dodawaniu (I3): otwiera skaner (aparat / zdjęcie), a wybrane słowo
/// (forma bazowa) trafia do pola wyszukiwania. Rozpoznany tekst zostaje w pamięci tego widoku,
/// więc po dodaniu jednego słowa można wrócić do listy i wybrać kolejne.
struct AddWordScanSection: View {
    let onPick: (String) -> Void

    @State private var isScanning = false
    @State private var scannedText = ""

    var body: some View {
        Section {
            Button {
                isScanning = true
            } label: {
                Label(scannedText.isEmpty ? "Skanuj tekst" : "Wróć do zeskanowanego tekstu", systemImage: "text.viewfinder")
            }
            .sheet(isPresented: $isScanning) {
                ScanTextScreen(text: $scannedText, onPick: onPick)
            }
        } footer: {
            Text("Aparatem lub ze zdjęcia — słowa z tekstu w formie podstawowej, z oznaczeniem tych, które już masz.")
        }
    }
}
