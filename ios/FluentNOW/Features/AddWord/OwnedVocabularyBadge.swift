import SwiftUI

/// Oznaczenie „Masz już” (G6) — wpis, który użytkownik ma w słowniku: ikona ✓ + tekst
/// (nie sam kolor). Używane w szybkim dodawaniu, wynikach „Szukaj tematu” i polecanych słówkach.
struct OwnedVocabularyBadge: View {
    var body: some View {
        TagChip("Masz już", systemImage: "checkmark", tone: .success)
            .accessibilityLabel(Text("Masz już w słowniku"))
    }
}

/// Wyszarzenie wiersza z wpisem, który użytkownik już ma.
struct OwnedVocabularyDimming: ViewModifier {
    let isOwned: Bool

    func body(content: Content) -> some View {
        content.opacity(isOwned ? 0.55 : 1)
    }
}

extension View {
    /// Wyszarza wiersz posiadanego wpisu (G6).
    func ownedVocabularyDimmed(_ isOwned: Bool) -> some View {
        modifier(OwnedVocabularyDimming(isOwned: isOwned))
    }
}
