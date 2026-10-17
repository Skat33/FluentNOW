import Foundation
import FluentKit

/// Propozycja hasła z wbudowanego słownika (rekordy tego samego hasła zgrupowane).
struct AddWordCandidate: Identifiable, Hashable, Sendable {
    let term: String
    let translations: [String]
    let level: String
    let isPolishMatch: Bool

    var id: String { term.lowercased() }

    /// Grupuje trafienia wyszukiwania po haśle, zachowując kolejność trafności.
    static func group(_ hits: [SearchHit]) -> [AddWordCandidate] {
        var order: [String] = []
        var grouped: [String: [SearchHit]] = [:]
        for hit in hits {
            let key = hit.entry.term.lowercased()
            if grouped[key] == nil { order.append(key) }
            grouped[key, default: []].append(hit)
        }
        return order.compactMap { key -> AddWordCandidate? in
            guard let group = grouped[key], let first = group.first else { return nil }
            var translations: [String] = []
            for hit in group where !translations.contains(hit.entry.translation) {
                translations.append(hit.entry.translation)
            }
            return AddWordCandidate(
                term: first.entry.term,
                translations: translations,
                level: first.entry.level,
                isPolishMatch: first.match == .polish
            )
        }
    }
}

/// Skąd pochodzą wyświetlane znaczenia.
enum AddWordLookupSource: Equatable {
    case builtIn
    case assistant
}

/// Ręcznie wpisane słowo (gdy nie ma go w bazie albo po edycji propozycji AI).
struct AddWordManualDraft: Equatable {
    var term = ""
    var translation = ""
    var pos = ""
    var level = ""
    var definition = ""
    var exampleEn = ""
    var examplePl = ""

    /// Komunikaty błędów (puste = można zapisać). Jak w edytorze słowa: tłumaczenie i przykład są wymagane.
    var issues: [String] {
        var result: [String] = []
        let term = WordDraft.clean(self.term)
        if term.isEmpty { result.append("Wpisz słowo lub zwrot po angielsku.") }
        if term.count > WordDraft.maxTermLength { result.append("Hasło może mieć najwyżej \(WordDraft.maxTermLength) znaków.") }
        if WordDraft.clean(translation).isEmpty { result.append("Dodaj polskie tłumaczenie.") }
        if WordDraft.clean(exampleEn).isEmpty { result.append("Dodaj przykładowe zdanie — bez niego nie powstaną ćwiczenia w kontekście.") }
        return result
    }

    init() {}

    init(term: String, sense: SenseSuggestion?) {
        self.term = term
        guard let sense else { return }
        translation = sense.translation
        pos = sense.pos
        level = CEFR.isValid(sense.level) ? sense.level : ""
        definition = sense.definition
        exampleEn = sense.examples.first?.en ?? ""
        examplePl = sense.examples.first?.pl ?? ""
    }

    /// Jednoznaczeniowy `Lookup` gotowy dla `VocabularyMerger.mergeSuggestions`.
    func lookup(collection: String) -> Lookup {
        let term = WordDraft.clean(self.term)
        let en = WordDraft.clean(exampleEn)
        let focusEn = en.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]).map { String(en[$0]) } ?? ""
        let sense = SenseSuggestion(
            translation: WordDraft.clean(translation),
            definition: WordDraft.clean(definition),
            pos: pos,
            level: level,
            collection: collection,
            examples: en.isEmpty ? [] : [ExamplePair(en: en, pl: WordDraft.clean(examplePl), focusEn: focusEn, focusPl: "")],
            acceptedAnswers: [term]
        )
        return Lookup(exists: true, term: term, meanings: [sense], source: .starter)
    }
}

/// Wynik dodania (do podsumowania „Dodano 3 znaczenia do kolekcji Lotnisko”).
struct AddWordOutcome: Equatable {
    var term: String
    var added: Int
    var skipped: Int
    var collection: String

    var message: String {
        if added == 0 {
            return "„\(term)” już jest w słowniku — postęp został zachowany."
        }
        var text = "Dodano \(LibraryText.meanings(added)) słowa „\(term)” do kolekcji „\(collection)”."
        if skipped > 0 { text += " Pominięto \(skipped) — już były w słowniku." }
        return text
    }
}

/// Logika dodawania (czyste funkcje na stanie, wywoływane w `store.update`).
enum AddWordLogic {
    static let manualSource = "Dodane ręcznie"

    /// Indeksy znaczeń, które użytkownik już ma (G6): to samo hasło i tłumaczenie albo ten sam
    /// wpis bazy (`contentRef`), poza archiwum — `OwnedVocabulary`.
    static func knownSenseIndices(_ lookup: Lookup, words: [Word]) -> Set<Int> {
        let owned = OwnedVocabulary(words: words)
        var result = Set<Int>()
        for (index, sense) in lookup.meanings.enumerated()
        where owned.contains(reference: sense.contentRef, term: lookup.term, translation: sense.translation) {
            result.insert(index)
        }
        return result
    }

    /// Propozycja AI: odrzuca znaczenia bez tłumaczenia, usuwa wyróżnienia, które nie są podciągami
    /// zdań (luka w ćwiczeniu by nie powstała). Wynik zawsze oznaczony `source = .ai`.
    static func sanitizedAssistantLookup(_ lookup: Lookup) -> Lookup {
        var copy = lookup
        copy.source = .ai
        copy.meanings = lookup.meanings.compactMap { sense -> SenseSuggestion? in
            guard !WordDraft.clean(sense.translation).isEmpty else { return nil }
            var fixed = sense
            fixed.level = CEFR.isValid(sense.level) ? sense.level : ""
            fixed.examples = sense.examples.compactMap { pair -> ExamplePair? in
                guard !WordDraft.clean(pair.en).isEmpty else { return nil }
                var checked = pair
                if !checked.focusEn.isEmpty && !checked.en.contains(checked.focusEn) { checked.focusEn = "" }
                if !checked.focusPl.isEmpty && !checked.pl.contains(checked.focusPl) { checked.focusPl = "" }
                return checked
            }
            return fixed
        }
        return copy
    }

    /// Dodaje wybrane znaczenia; zwraca podsumowanie.
    static func merge(
        _ state: inout LearnerState,
        lookup: Lookup,
        indices: [Int],
        collectionOverride: String?,
        markManual: Bool,
        now: Timestamp
    ) -> AddWordOutcome {
        let result = VocabularyMerger.mergeSuggestions(
            state, lookup: lookup, indices: indices, collectionOverride: collectionOverride, now: now
        )
        state = result.state
        var collection = collectionOverride ?? ""
        for meaningID in result.addedMeaningIDs {
            guard let found = state.wordAndMeaning(meaningID: meaningID) else { continue }
            collection = found.word.collection
            if markManual, found.word.created == now, let index = state.wordIndex(id: found.word.id) {
                state.words[index].source = manualSource
            }
        }
        return AddWordOutcome(
            term: lookup.term,
            added: result.addedMeaningIDs.count,
            skipped: result.skippedExisting,
            collection: collection.isEmpty ? VocabularyMerger.defaultCollection : collection
        )
    }
}
