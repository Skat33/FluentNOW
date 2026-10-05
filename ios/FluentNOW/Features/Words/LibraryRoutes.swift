import SwiftUI

/// Trasy obszaru Słownika (ui-library). Rejestrowane raz na stos karty przez
/// `.libraryNavigationDestinations()` w korzeniach: Dzisiaj, Słownik, Postępy.
/// Ekrany osadzone (Kolekcje, Tematy) NIE rejestrują ich ponownie.
enum WordRoute: Hashable {
    case detail(id: String)
}

enum CollectionRoute: Hashable {
    case detail(name: String)
}

enum TopicRoute: Hashable {
    case detail(id: String)
}

extension View {
    /// Rejestruje cele nawigacji Słownika (słowo, kolekcja, temat) w bieżącym `NavigationStack`.
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
            .navigationDestination(for: TopicRoute.self) { route in
                switch route {
                case .detail(let id):
                    TopicDetailScreen(topicID: id)
                }
            }
    }
}
