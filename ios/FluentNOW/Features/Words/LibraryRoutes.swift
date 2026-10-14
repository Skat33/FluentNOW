import SwiftUI

/// Trasy obszaru Słownika (ui-library). Rejestrowane raz na stos karty przez
/// `.libraryNavigationDestinations()` w korzeniach: Dzisiaj, Słownik, Postępy.
/// Ekrany osadzone (Kolekcje) NIE rejestrują ich ponownie.
/// Tematy nie mają już trasy (F1) — otwiera się je w arkuszu „+” (`router.presentTopicSearch`).
enum WordRoute: Hashable {
    case detail(id: String)
}

enum CollectionRoute: Hashable {
    case detail(name: String)
}

extension View {
    /// Rejestruje cele nawigacji Słownika (słowo, kolekcja) w bieżącym `NavigationStack`.
    func libraryNavigationDestinations() -> some View {
        self
            .navigationDestination(for: WordRoute.self) { route in
                switch route {
                case .detail(let id):
                    WordDetailScreen(wordID: id)
                }
            }
            .navigationDestination(for: CollectionRoute.self) { route in
                switch route {
                case .detail(let name):
                    CollectionDetailScreen(name: name)
                }
            }
    }
}
