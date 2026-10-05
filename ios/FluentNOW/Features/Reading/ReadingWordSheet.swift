import SwiftUI
import FluentKit

/// Podgląd słowa z mojego słownika dotkniętego w tekście czytanki.
struct ReadingWordSheet: View {
    let wordID: String

    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                if let word = store.word(id: wordID) {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        HStack(alignment: .center, spacing: Spacing.s) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(word.en)
                                    .font(FluentFont.flashcardTerm)
                                    .foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !word.ipa.isEmpty {
                                    Text(word.ipa)
                                        .font(FluentFont.ipa)
                                        .foregroundStyle(Palette.inkSecondary)
                                }
                            }
                            Spacer(minLength: Spacing.xs)
                            SpeakButton(isSpeaking: speech.isSpeaking) { speech.speak(word.en) }
                        }
                        Text("Masz to słowo w swoim słowniku. Wybierz znaczenie pasujące do tekstu.")
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(word.meanings) { meaning in
                            ReadingMeaningRow(word: word, meaning: meaning)
                        }
                    }
                    .padding(Spacing.screen)
                } else {
                    EmptyStateView(
                        systemImage: "questionmark.circle",
                        title: "Nie znaleziono słowa",
                        message: "Mogło zostać usunięte z Twojego słownika."
                    )
                }
            }
            .background(Palette.background)
            .navigationTitle("Twoje słowo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gotowe") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct ReadingMeaningRow: View {
    let word: Word
    let meaning: Meaning

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
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

#Preview("Słowo z czytanki") {
    ReadingWordSheet(wordID: "preview")
        .fluentPreviewEnvironment()
}
