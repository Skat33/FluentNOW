import Foundation
import FluentKit

/// Edytowalna kopia słowa na czas trwania formularza (nie żyje dłużej niż arkusz).
/// Pola nieedytowalne (wyniki, historia przykładów, warianty odpowiedzi) są zachowywane z oryginału.
struct WordDraft: Equatable {
    struct ExampleDraft: Equatable, Identifiable {
        var id = UUID()
        var en = ""
        var pl = ""
        var focusEn = ""
        var focusPl = ""
    }

    struct MeaningDraft: Equatable, Identifiable {
        /// Id istniejącego znaczenia albo nowe (`isNew`).
        var id: String
        var isNew: Bool
        var translation = ""
        var definition = ""
        var pos = ""
        var level = ""
        var register = "neutralny"
        var context = ""
        var examples: [ExampleDraft] = [ExampleDraft()]
    }

    static let registers = ["neutralny", "potoczny", "formalny", "specjalistyczny", "slangowy"]
    static let partsOfSpeech = ["rzeczownik", "czasownik", "czasownik frazowy", "przymiotnik", "przysłówek",
                                "zwrot", "idiom", "przyimek", "spójnik", "zaimek", "wykrzyknik", "liczebnik"]
    static let maxTermLength = 80
    /// Zastępnik zwracany przez bezpieczne powiązania formularza (nigdy nie jest zapisywany).
    static let placeholderMeaning = MeaningDraft(id: "", isNew: true)

    var en: String
    var ipa: String
    var pos: String
    var level: String
    var collection: String
    var tags: String
    var note: String
    var forms: String
    var collocations: String
    var synonyms: String
    var antonyms: String
    var meanings: [MeaningDraft]

    init(word: Word) {
        en = word.en
        ipa = word.ipa
        pos = word.pos
        level = word.level
        collection = word.collection
        tags = word.tags.joined(separator: ", ")
        note = word.note
        forms = word.forms
        collocations = word.collocations
        synonyms = word.synonyms
        antonyms = word.antonyms
        meanings = word.meanings.map { meaning in
            let examples = meaning.examples.indices.map { index in
                ExampleDraft(
                    en: meaning.examples[index],
                    pl: meaning.exampleTranslations?.libraryItem(at: index) ?? "",
                    focusEn: meaning.exampleFocusEn?.libraryItem(at: index) ?? "",
                    focusPl: meaning.exampleFocusPl?.libraryItem(at: index) ?? ""
                )
            }
            return MeaningDraft(
                id: meaning.id,
                isNew: false,
                translation: meaning.translation,
                definition: meaning.definition,
                pos: meaning.pos ?? "",
                level: meaning.level ?? "",
                register: meaning.register,
                context: meaning.context,
                examples: examples.isEmpty ? [ExampleDraft()] : examples
            )
        }
    }

    static func newMeaning() -> MeaningDraft {
        MeaningDraft(id: UUID().uuidString.lowercased(), isNew: true)
    }

    // MARK: Walidacja

    /// Komunikaty błędów (puste = można zapisać). Reguła strony: każde znaczenie ma tłumaczenie
    /// i co najmniej jeden przykład.
    var issues: [String] {
        var result: [String] = []
        let term = en.trimmingCharacters(in: .whitespacesAndNewlines)
        if term.isEmpty { result.append("Wpisz słowo lub zwrot po angielsku.") }
        if term.count > WordDraft.maxTermLength { result.append("Hasło może mieć najwyżej \(WordDraft.maxTermLength) znaków.") }
        if collection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { result.append("Podaj nazwę kolekcji.") }
        if meanings.isEmpty { result.append("Słowo musi mieć co najmniej jedno znaczenie.") }
        for (offset, meaning) in meanings.enumerated() {
            let label = meanings.count > 1 ? "Znaczenie \(offset + 1): " : ""
            result.append(contentsOf: WordDraft.issues(of: meaning).map { label + $0 })
        }
        return result
    }

    static func issues(of meaning: MeaningDraft) -> [String] {
        var result: [String] = []
        if meaning.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result.append("dodaj tłumaczenie.")
        }
        let filled = meaning.examples.filter { !$0.en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if filled.isEmpty { result.append("dodaj co najmniej jeden przykład.") }
        for example in filled {
            if let issue = focusIssue(example) { result.append(issue) }
        }
        return result
    }

    /// Wyróżniony fragment musi występować w zdaniu (inaczej luka w ćwiczeniu nie powstanie).
    static func focusIssue(_ example: ExampleDraft) -> String? {
        let focusEn = example.focusEn.trimmingCharacters(in: .whitespacesAndNewlines)
        if !focusEn.isEmpty && example.en.range(of: focusEn, options: [.caseInsensitive, .diacriticInsensitive]) == nil {
            return "fragment „\(focusEn)” nie występuje w przykładzie."
        }
        let focusPl = example.focusPl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !focusPl.isEmpty && example.pl.range(of: focusPl, options: [.caseInsensitive]) == nil {
            return "fragment „\(focusPl)” nie występuje w tłumaczeniu przykładu."
        }
        return nil
    }

    // MARK: Zapis

    /// Buduje zaktualizowane słowo. Zmiana tłumaczenia/hasła czyści zapisane warianty odpowiedzi
    /// (przestałyby pasować); wyniki umiejętności znaczeń zostają.
    func applied(to original: Word, now: Timestamp) -> Word {
        var word = original
        let trimmedEn = WordDraft.clean(en)
        let termChanged = TextNormalizer.normalize(trimmedEn) != TextNormalizer.normalize(original.en)
        word.en = trimmedEn
        word.ipa = WordDraft.clean(ipa)
        word.pos = pos
        word.level = level
        word.collection = WordDraft.clean(collection)
        word.tags = tags.split(separator: ",").map { WordDraft.clean(String($0)) }.filter { !$0.isEmpty }
        word.note = WordDraft.clean(note)
        word.forms = WordDraft.clean(forms)
        word.collocations = WordDraft.clean(collocations)
        word.synonyms = WordDraft.clean(synonyms)
        word.antonyms = WordDraft.clean(antonyms)
        word.updatedAt = now
        word.meanings = meanings.map { draft in
            var meaning = original.meaning(id: draft.id) ?? Meaning(id: draft.id, translation: "")
            let translation = WordDraft.clean(draft.translation)
            if TextNormalizer.normalize(translation) != TextNormalizer.normalize(meaning.translation) {
                meaning.acceptedTranslations = nil
            }
            if termChanged { meaning.acceptedAnswers = nil }
            meaning.translation = translation
            meaning.definition = WordDraft.clean(draft.definition)
            meaning.pos = draft.pos.isEmpty ? nil : draft.pos
            meaning.level = draft.level.isEmpty ? nil : draft.level
            meaning.register = draft.register
            meaning.context = WordDraft.clean(draft.context)
            let examples = draft.examples.filter { !WordDraft.clean($0.en).isEmpty }
            let oldExamples = meaning.examples
            meaning.examples = examples.map { WordDraft.clean($0.en) }
            meaning.exampleTranslations = examples.map { WordDraft.clean($0.pl) }
            meaning.exampleFocusEn = examples.map { WordDraft.clean($0.focusEn) }
            meaning.exampleFocusPl = examples.map { WordDraft.clean($0.focusPl) }
            if meaning.examples != oldExamples {
                // Indeksy wykorzystanych przykładów mogą wskazywać już inne zdania.
                meaning.usedExamples = nil
            }
            return meaning
        }
        return word
    }

    static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Array {
    func libraryItem(at index: Int) -> Element? {
        index >= 0 && index < count ? self[index] : nil
    }
}
