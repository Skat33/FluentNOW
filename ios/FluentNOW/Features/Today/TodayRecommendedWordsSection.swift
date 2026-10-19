import SwiftUI

/// FEEDBACK-5 J2: polecane słówka nie mają już własnej sekcji na Dzisiaj — mieszkają w Słowniku
/// (segment „Polecane”). Tu został tylko dyskretny link w stylu „Pełna analiza w Postępach”.
/// Wspólne widoki listy są w `Features/Stats/UsefulWordsComponents.swift`.
struct TodayRecommendedWordsLink: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button {
            router.openLibrary(.recommended)
        } label: {
            UsefulWordsMoreLabel(title: "Polecane słówka")
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Otwiera Słownik, segment Polecane"))
    }
}
