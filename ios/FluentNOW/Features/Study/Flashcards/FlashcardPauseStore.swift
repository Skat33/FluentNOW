import Foundation
import FluentKit

/// Przerwana talia fiszek (FEEDBACK-6 K1): zapisana na tym urządzeniu po każdej decyzji, żeby po
/// powrocie dało się wybrać „Kontynuuj, gdzie skończyłem” albo „Zacznij od nowa”.
/// Odpowiedzi i tak są już zapisane w nauce (`FlashcardDeckBuilder.record`) — tu jest tylko
/// kolejność kart i licznik.
struct FlashcardPausedDeck: Codable, Hashable {
    var run: FlashcardRun
    var collection: String?
    /// Czas spędzony nad talią przed przerwą (do podsumowania).
    var seconds: Double
    var savedAt: Double

    /// „Karta 4 z 20”.
    var positionText: String {
        "Karta \(min(run.index + 1, max(1, run.cards.count))) z \(run.cards.count)"
    }
}

/// Zapis przerwanej talii w `UserDefaults` (małe dane, JSON). `defaults == nil` — bez zapisu (testy).
enum FlashcardPauseStore {
    static let runKey = "flashcards.pausedRun"
    /// Przykłady porzuconej talii („Zacznij od nowa”) — pomijane w następnej talii.
    static let avoidKey = "flashcards.avoidExamples"

    /// Przerwana, niedokończona talia (z co najmniej jedną decyzją); uszkodzony zapis = brak.
    static func load(_ defaults: UserDefaults? = .standard) -> FlashcardPausedDeck? {
        guard let data = defaults?.data(forKey: runKey),
              let paused = try? JSONDecoder().decode(FlashcardPausedDeck.self, from: data),
              !paused.run.isFinished, paused.run.index > 0 else { return nil }
        return paused
    }

    static func save(_ paused: FlashcardPausedDeck, _ defaults: UserDefaults? = .standard) {
        guard let defaults else { return }
        guard !paused.run.isFinished, let data = try? JSONEncoder().encode(paused) else {
            defaults.removeObject(forKey: runKey)
            return
        }
        defaults.set(data, forKey: runKey)
    }

    static func clear(_ defaults: UserDefaults? = .standard) {
        defaults?.removeObject(forKey: runKey)
    }

    /// „Zacznij od nowa”: porzuca przerwaną talię i zapamiętuje jej przykłady, żeby nowa talia
    /// pokazała inne zdania. Bez przerwanej talii nic nie zmienia.
    static func abandon(_ defaults: UserDefaults? = .standard) {
        guard let defaults else { return }
        guard let paused = load(defaults) else {
            clear(defaults)
            return
        }
        var stored: [String: [Int]] = [:]
        for (meaningID, examples) in FreshStart.examples(in: paused.run.cards) {
            stored[meaningID] = examples.sorted()
        }
        if let data = try? JSONEncoder().encode(stored) {
            defaults.set(data, forKey: avoidKey)
        }
        clear(defaults)
    }

    /// Przykłady do pominięcia w budowanej właśnie talii (jednorazowo — odczyt je usuwa).
    static func takeAvoidedExamples(_ defaults: UserDefaults? = .standard) -> [String: Set<Int>] {
        guard let defaults, let data = defaults.data(forKey: avoidKey) else { return [:] }
        defaults.removeObject(forKey: avoidKey)
        guard let stored = try? JSONDecoder().decode([String: [Int]].self, from: data) else { return [:] }
        var result: [String: Set<Int>] = [:]
        for (meaningID, examples) in stored {
            result[meaningID] = Set(examples)
        }
        return result
    }
}
