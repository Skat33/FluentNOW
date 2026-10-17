import Foundation
import Observation
import FluentKit

/// Etap ekranu „Fiszki”.
enum FlashcardDeckPhase: Equatable {
    /// Wybór talii (kolekcja, rozmiar, liczniki).
    case setup
    /// Karty po kolei.
    case running
    /// Krótkie podsumowanie.
    case finished
}

/// Model trybu „Fiszki” (G3): talia z FluentKit (`FlashcardDeckBuilder`), kolejność i powroty
/// zapomnianych kart w `FlashcardRun`, każda decyzja zapisywana od razu
/// (`FlashcardDeckBuilder.record` w `store.update(.answer)`, umiejętność rozpoznawania).
/// Talia żyje w pamięci — przerwa nie gubi odpowiedzi, bo każda jest już zapisana.
@MainActor
@Observable
final class FlashcardDeckModel {
    let store: LearningStore
    var collection: String?
    var size: Int = 20

    private(set) var phase: FlashcardDeckPhase = .setup
    private(set) var counts = FlashcardDeckCounts()
    private(set) var run = FlashcardRun(cards: [])
    /// Tył bieżącej karty jest widoczny.
    private(set) var revealed = false
    /// Przód bieżącej karty po polsku (losowo dla każdej karty — H3); tył w drugim języku.
    private(set) var frontIsPolish = false
    /// „Pokaż przykład” — zdanie z tłumaczeniem, tylko na życzenie (H3).
    private(set) var exampleShown = false
    /// Licznik decyzji (haptyka, animacja przejścia).
    private(set) var decisions = 0
    private(set) var isPreparing = false
    private(set) var notice: String?

    @ObservationIgnored private var cardShownAt = Date()
    @ObservationIgnored private var runSeconds: Double = 0

    init(store: LearningStore, collection: String?) {
        self.store = store
        self.collection = collection
    }

    var currentCard: FlashcardCard? { run.currentCard }

    /// „Karta 3 z 20”.
    var position: (index: Int, total: Int) {
        (min(run.index + 1, max(1, run.cards.count)), run.cards.count)
    }

    var collections: [String] {
        store.state.collections
    }

    // MARK: Akcje

    /// Liczniki grup dla bieżącej kolekcji (poza głównym wątkiem).
    func refreshCounts() async {
        let limitedTo = collection
        let now = store.now()
        counts = await store.compute { (state: LearnerState) -> FlashcardDeckCounts in
            FlashcardDeckBuilder.counts(state: state, collection: limitedTo, now: now)
        }
    }

    /// Buduje talię i pokazuje pierwszą kartę.
    func start() async {
        guard !isPreparing else { return }
        isPreparing = true
        notice = nil
        let limitedTo = collection
        let limit = max(1, size)
        let now = store.now()
        let cards = await store.compute { (state: LearnerState) -> [FlashcardCard] in
            FlashcardDeckBuilder.makeDeck(state: state, collection: limitedTo, limit: limit, now: now)
        }
        isPreparing = false
        guard !cards.isEmpty else {
            notice = collection == nil
                ? "Na razie nie ma kart do powtórki ani nowych słów. Dodaj słowa albo wróć później."
                : "W tej kolekcji nie ma teraz kart do powtórki ani nowych słów."
            return
        }
        begin(with: cards)
    }

    /// „Jeszcze raz te, których nie pamiętasz” — talia z kart oznaczonych „Nie pamiętam”.
    func restartWithForgotten() {
        let ids = run.forgottenMeaningIDs
        var cards: [FlashcardCard] = []
        for meaningID in ids {
            guard let found = store.state.wordAndMeaning(meaningID: meaningID) else { continue }
            let original = run.cards.first { (card: FlashcardCard) -> Bool in card.meaningId == meaningID }
            cards.append(FlashcardCard(
                wordId: found.word.id,
                meaningId: meaningID,
                example: (original?.example ?? 0) + 1,
                group: .hard
            ))
        }
        guard !cards.isEmpty else { return }
        begin(with: cards)
    }

    func backToSetup() {
        phase = .setup
        run = FlashcardRun(cards: [])
        revealed = false
        exampleShown = false
    }

    /// Dotknięcie karty: obrót na drugą stronę (i z powrotem).
    func flip() {
        guard phase == .running, currentCard != nil else { return }
        revealed.toggle()
        if !revealed {
            exampleShown = false
        }
    }

    /// „Pokaż przykład” / „Ukryj przykład” (dostępne po odwróceniu karty).
    func toggleExample() {
        guard phase == .running, revealed else { return }
        exampleShown.toggle()
    }

    /// Pamiętam / nie pamiętam: zapis i od razu następna karta (jak F3).
    func answer(remembered: Bool) {
        guard phase == .running, let card = currentCard else { return }
        let seconds = max(0.1, Date().timeIntervalSince(cardShownAt))
        let now = store.now()
        let reviewID = UUID().uuidString.lowercased()
        store.update(.answer) { (state: inout LearnerState) -> Void in
            state = FlashcardDeckBuilder.record(state, card: card, remembered: remembered, seconds: seconds, now: now, reviewID: reviewID)
        }
        runSeconds += seconds
        run.answer(remembered: remembered)
        run.dropMissing(in: store.state)
        decisions += 1
        showNextCard()
        if run.isFinished {
            phase = .finished
        }
    }

    /// Karty usunięte w międzyczasie (inne urządzenie) — wypadają z talii.
    func syncWithStore() {
        guard phase == .running else { return }
        run.dropMissing(in: store.state)
        if run.isFinished {
            phase = .finished
        }
    }

    // MARK: Podsumowanie

    var summaryLines: FlashcardSummaryData {
        FlashcardSummaryData(
            remembered: run.remembered,
            forgotten: run.forgotten,
            seconds: runSeconds,
            forgottenWords: run.forgottenMeaningIDs.compactMap { (meaningID: String) -> FlashcardSummaryData.Line? in
                guard let found = store.state.wordAndMeaning(meaningID: meaningID) else { return nil }
                return FlashcardSummaryData.Line(id: meaningID, term: found.word.en, translation: found.meaning.translation)
            }
        )
    }

    // MARK: Prywatne

    private func begin(with cards: [FlashcardCard]) {
        run = FlashcardRun(cards: cards)
        runSeconds = 0
        showNextCard()
        phase = .running
    }

    /// Nowa karta: przód zakryty, bez przykładu, język przodu losowany (PL albo EN).
    private func showNextCard() {
        revealed = false
        exampleShown = false
        frontIsPolish = Bool.random()
        cardShownAt = Date()
    }
}

/// Dane krótkiego podsumowania talii.
struct FlashcardSummaryData: Equatable {
    struct Line: Identifiable, Equatable {
        var id: String
        var term: String
        var translation: String
    }

    var remembered: Int
    var forgotten: Int
    var seconds: Double
    var forgottenWords: [Line]

    var total: Int { remembered + forgotten }
}
