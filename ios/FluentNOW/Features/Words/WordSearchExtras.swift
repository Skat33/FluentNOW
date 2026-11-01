import SwiftUI
import FluentKit

/// Dodatki wyszukiwania w Słowniku (FEEDBACK-9 N3): „Czy chodziło Ci o…?” wśród własnych słów
/// (gdy nic nie pasuje) i podpowiedzi z wbudowanego słownika (do dodania jednym dotknięciem).
struct WordSearchExtras: Sendable, Equatable {
    /// Własne hasła / tłumaczenia bliskie zapytaniu (literówka).
    var ownCorrections: [String] = []
    /// Migawka słownika użytkownika — „Masz już” w podpowiedziach z bazy.
    var owned: OwnedVocabulary = .empty
    /// Podpowiedzi z wbudowanego słownika.
    var builtIn: SearchSuggestionResult = .empty

    static let empty = WordSearchExtras()

    /// Część liczona na migawce stanu (`store.compute`, poza głównym wątkiem).
    static func local(state: LearnerState, query: String, needsCorrections: Bool) -> WordSearchExtras {
        var extras = WordSearchExtras()
        extras.owned = OwnedVocabulary(state)
        guard needsCorrections else { return extras }
        var candidates: [String] = []
        for word in state.words where !word.archived {
            candidates.append(word.en)
            for meaning in word.meanings where !meaning.translation.isEmpty {
                candidates.append(meaning.translation)
            }
        }
        extras.ownCorrections = FuzzyMatcher.closest(to: query, in: candidates, limit: 3)
        return extras
    }

    /// Hasła z bazy, których użytkownik jeszcze nie ma w całości: przy trafieniach we własnym
    /// słowniku najwyżej 3, bez trafień 5; bez propozycji — poprawki literówek.
    func builtInItems(hasOwnMatches: Bool) -> [SearchSuggestion] {
        let limit = hasOwnMatches ? 3 : 5
        let fresh = builtIn.matches.filter { (item: SearchSuggestion) -> Bool in !item.isFullyOwned(in: owned) }
        if !fresh.isEmpty { return Array(fresh.prefix(limit)) }
        let corrections = builtIn.corrections.filter { (item: SearchSuggestion) -> Bool in !item.isFullyOwned(in: owned) }
        return Array(corrections.prefix(limit))
    }
}

/// Sekcje dodatków pod listą słów.
struct WordSearchExtrasSections: View {
    let extras: WordSearchExtras
    let hasOwnMatches: Bool
    let onUseCorrection: (String) -> Void
    let onAddBuiltIn: (SearchSuggestion) -> Void

    var body: some View {
        if !hasOwnMatches && !extras.ownCorrections.isEmpty {
            Section("Czy chodziło Ci o…?") {
                ForEach(extras.ownCorrections, id: \.self) { (term: String) in
                    Button {
                        onUseCorrection(term)
                    } label: {
                        Label(term, systemImage: "arrow.uturn.right")
                            .frame(minHeight: HitTarget.minimum, alignment: .leading)
                    }
                }
            }
        }
        let items = extras.builtInItems(hasOwnMatches: hasOwnMatches)
        if !items.isEmpty {
            Section {
                WordSuggestionRows(items: items, owned: extras.owned, onSelect: onAddBuiltIn)
            } header: {
                Text("Dodaj ze słownika")
            } footer: {
                Text("Słowa z wbudowanej bazy, których jeszcze nie masz. Dotknij, żeby wybrać znaczenie.")
            }
        }
    }
}
