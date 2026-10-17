import SwiftUI
import FluentKit

/// Arkusz słowa dotkniętego w czytance (G1): tłumaczenie w kontekście TEGO tekstu (słowniczek
/// czytanki), forma bazowa, wymowa z odsłuchem, zdanie z tekstu, moje znaczenia (z zaznaczeniem
/// pasującego albo niepewności) i „Dodaj do nauki” dla słów, których nie mam.
struct ReadingWordSheet: View {
    let selection: ReadingTermSelection

    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech
    @Environment(\.dismiss) private var dismiss
    @State private var showsAddWord = false

    private var entry: ReadingGlossaryEntry? { selection.entry }
    private var word: Word? { selection.wordID.flatMap { store.word(id: $0) } }
    private var headword: String { entry?.lemma ?? word?.en ?? selection.surface }

    private var ipa: String? {
        if let ipa = entry?.ipa, !ipa.isEmpty { return ipa }
        if let ipa = word?.ipa, !ipa.isEmpty { return ipa }
        return nil
    }

    private var choice: ReadingMeaningChoice? {
        guard let word else { return nil }
        return ReadingMeaningMatcher.choose(word: word, sentence: selection.sentence, entry: entry)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    ReadingTermHeader(term: headword, ipa: ipa, isSpeaking: speech.isSpeaking) { (slow: Bool) in
                        speech.speak(headword, slow: slow)
                    }
                    ReadingContextCard(selection: selection, headword: headword, translation: contextTranslation, isGuess: isGuess) {
                        speech.speak(selection.sentence)
                    }
                    if let word {
                        ReadingOwnMeanings(word: word, choice: choice ?? ReadingMeaningChoice(meaningId: nil, isConfident: false), hasGlossary: entry != nil)
                    }
                    if let entry, shouldOfferAdd {
                        ReadingAddSection(entry: entry, isOwnWord: word != nil) {
                            showsAddWord = true
                        }
                    }
                }
                .padding(Spacing.screen)
            }
            .background(Palette.background)
            .navigationTitle(word == nil ? "Słowo z tekstu" : "Twoje słowo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showsAddWord) {
            AddWordRootScreen(prefill: headword)
        }
    }

    /// Tłumaczenie w kontekście: ze słowniczka; bez niego — wybrane z moich znaczeń.
    private var contextTranslation: String? {
        if let entry { return entry.translation }
        guard let word, let id = choice?.meaningId else { return nil }
        return word.meanings.first(where: { $0.id == id })?.translation
    }

    /// Tłumaczenie bez słowniczka, wybrane z niepewnością.
    private var isGuess: Bool {
        entry == nil && choice?.isConfident != true
    }

    /// „Dodaj do nauki” dla słów, których nie mam, albo gdy brakuje mi znaczenia z tego tekstu.
    private var shouldOfferAdd: Bool {
        guard word != nil else { return true }
        return choice?.meaningId == nil && entry?.ref != nil
    }
}

/// Hasło, wymowa, odsłuch (zwykły i wolny).
private struct ReadingTermHeader: View {
    let term: String
    let ipa: String?
    let isSpeaking: Bool
    let onSpeak: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(term)
                    .font(FluentFont.flashcardTerm)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let ipa {
                    Text(ipa)
                        .font(FluentFont.ipa)
                        .foregroundStyle(Palette.inkSecondary)
                        .accessibilityLabel(Text("Wymowa: \(ipa)"))
                }
            }
            Spacer(minLength: Spacing.xs)
            SpeakButton(isSpeaking: isSpeaking, accessibilityLabel: "Odsłuchaj \(term)") { onSpeak(false) }
            SpeakButton(style: .slow, accessibilityLabel: "Odsłuchaj wolniej") { onSpeak(true) }
        }
    }
}

/// „W tym tekście”: tłumaczenie w kontekście, forma z tekstu i bazowa, zdanie z odsłuchem.
private struct ReadingContextCard: View {
    let selection: ReadingTermSelection
    let headword: String
    let translation: String?
    let isGuess: Bool
    let onSpeakSentence: () -> Void

    var body: some View {
        Card(style: .tinted(.accent), spacing: Spacing.xs) {
            Text("W tym tekście")
                .fluentEyebrow()
                .foregroundStyle(Palette.accentSoftInk)
            Text(translationText)
                .font(FluentFont.title)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if showsForms {
                Text("Forma w tekście: **\(selection.surface)** · forma bazowa: **\(headword)**")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !selection.sentence.isEmpty {
                HStack(alignment: .top, spacing: Spacing.xs) {
                    HighlightedText(selection.sentence, focus: selection.surface)
                        .font(FluentFont.reading)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SpeakButton(size: .small, accessibilityLabel: "Odsłuchaj zdanie", action: onSpeakSentence)
                }
            }
        }
    }

    private var translationText: String {
        guard let translation else { return "Znaczenie zależy od kontekstu — sprawdź poniżej" }
        return isGuess ? "Prawdopodobnie: \(translation)" : translation
    }

    private var showsForms: Bool {
        selection.surface.lowercased() != headword.lowercased()
    }
}

/// Moje znaczenia słowa: pasujące do tekstu na górze, albo wszystkie z informacją o niepewności.
private struct ReadingOwnMeanings: View {
    let word: Word
    let choice: ReadingMeaningChoice
    let hasGlossary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("W Twoim słowniku")
                .font(FluentFont.headline)
                .foregroundStyle(Palette.ink)
            if choice.meaningId == nil || !choice.isConfident {
                Text(uncertaintyText)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(ordered) { meaning in
                ReadingMeaningRow(word: word, meaning: meaning, mark: mark(for: meaning))
            }
        }
    }

    private var uncertaintyText: String {
        if choice.meaningId != nil {
            return "Nie mamy pewności, które znaczenie pasuje do tego zdania — zaznaczyliśmy najbardziej prawdopodobne."
        }
        if hasGlossary {
            return "Żadne z Twoich znaczeń nie odpowiada temu tekstowi — tłumaczenie powyżej pochodzi ze słowniczka czytanki."
        }
        return "Nie mamy pewności, które znaczenie pasuje do tego zdania — sprawdź wszystkie."
    }

    private var ordered: [Meaning] {
        guard let id = choice.meaningId, let chosen = word.meanings.first(where: { $0.id == id }) else { return word.meanings }
        return [chosen] + word.meanings.filter { $0.id != id }
    }

    private func mark(for meaning: Meaning) -> String? {
        guard meaning.id == choice.meaningId else { return nil }
        return choice.isConfident ? "Pasuje do tekstu" : "Prawdopodobnie"
    }
}

private struct ReadingMeaningRow: View {
    let word: Word
    let meaning: Meaning
    let mark: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                if let mark {
                    TagChip(mark, systemImage: "checkmark", tone: .success)
                }
                Text(meaning.translation)
                    .font(FluentFont.bodyEmphasized)
                    .foregroundStyle(Palette.ink)
                if !meaning.context.isEmpty {
                    Text(meaning.context)
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Spacing.xs)
            LevelBadge(level: meaning.effectiveLevel(in: word))
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fluentCardBackground(.solid, cornerRadius: Radius.medium)
        .accessibilityElement(children: .combine)
    }
}

/// „Dodaj do nauki”: wpis bazy (`ref`) dodawany od razu; bez `ref` — szybkie dodawanie z hasłem.
private struct ReadingAddSection: View {
    let entry: ReadingGlossaryEntry
    let isOwnWord: Bool
    let onOpenAddWord: () -> Void

    @Environment(LearningStore.self) private var store
    @Environment(AppEnvironment.self) private var env
    @State private var isAdding = false
    @State private var outcome: ReadingAddOutcome?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            switch state {
            case .done(let message):
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.success)
            case .failed:
                Text("Nie udało się wczytać wpisu z bazy. Spróbuj dodać słowo ręcznie.")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryButton("Dodaj ręcznie", systemImage: "plus", action: onOpenAddWord)
            case .ready:
                Text(isOwnWord ? "Tego znaczenia nie masz jeszcze w słowniku." : "To słowo warto znać na tym poziomie.")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(isOwnWord ? "Dodaj to znaczenie do nauki" : "Dodaj do nauki", systemImage: "plus", isLoading: isAdding) {
                    add()
                }
            }
        }
    }

    private enum SectionState {
        case ready
        case done(String)
        case failed
    }

    private var state: SectionState {
        switch outcome {
        case .added(let count)?:
            return .done(count > 1 ? "Dodano do nauki (\(count) znaczenia)" : "Dodano do nauki")
        case .alreadyKnown?:
            return .done("Masz już to znaczenie w słowniku")
        case .failed?:
            return .failed
        case nil:
            return ReadingGlossaryAdder.isAdded(entry, state: store.state) ? .done("Masz już to znaczenie w słowniku") : .ready
        }
    }

    private func add() {
        guard entry.ref != nil else {
            onOpenAddWord()
            return
        }
        guard !isAdding else { return }
        isAdding = true
        Task { @MainActor in
            let result = await ReadingGlossaryAdder.add(entry, store: store, content: env.content)
            isAdding = false
            outcome = result
            let message: String
            switch result {
            case .added: message = "Dodano do nauki"
            case .alreadyKnown: message = "Masz już to znaczenie w słowniku"
            case .failed: message = "Nie udało się dodać słowa"
            }
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

#Preview("Słowo z czytanki") {
    ReadingWordSheet(selection: ReadingTermSelection(
        id: "0:1",
        surface: "booked",
        sentence: "Ruby booked a table for six people at a restaurant.",
        entry: ReadingGlossaryEntry(form: "booked", lemma: "book", translation: "zarezerwować", ipa: "/bʊk/", ref: "restaurant/restaurant.book"),
        wordID: nil
    ))
    .fluentPreviewEnvironment()
}
