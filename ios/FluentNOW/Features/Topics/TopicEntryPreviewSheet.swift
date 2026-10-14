import SwiftUI
import FluentKit

/// Podgląd wpisu tematu: wymowa, tłumaczenie, definicja, przykłady, formy, kolokacje.
struct TopicEntryPreviewSheet: View {
    let entry: TopicEntry
    let isAdded: Bool
    let isSelected: Bool
    let onToggle: () -> Void
    /// Szkic AI — szczegóły (wymowa, przykłady) powstaną przy dodawaniu.
    var isDraft: Bool = false

    @Environment(SpeechService.self) private var speech
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    TopicEntryPreviewHeader(entry: entry)
                    if isDraft {
                        Label("Propozycja AI. Wymowę, definicję i przykłady asystent przygotuje, gdy dodasz to słowo do nauki.", systemImage: "sparkles")
                            .font(FluentFont.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !entry.examples.isEmpty {
                        Card {
                            SectionHeader("Przykłady")
                            ForEach(Array(entry.examples.enumerated()), id: \.offset) { _, pair in
                                HStack(alignment: .top, spacing: Spacing.xs) {
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        HighlightedText(pair.en, focus: pair.focusEn)
                                            .font(FluentFont.body)
                                            .foregroundStyle(Palette.ink)
                                            .fixedSize(horizontal: false, vertical: true)
                                        HighlightedText(pair.pl, focus: pair.focusPl, highlight: Palette.inkSecondary)
                                            .font(FluentFont.subheadline)
                                            .foregroundStyle(Palette.inkSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                    SpeakButton(size: .small, accessibilityLabel: "Odtwórz przykład") {
                                        speech.speak(pair.en)
                                    }
                                }
                            }
                        }
                    }
                    TopicEntryDetails(entry: entry)
                }
                .padding(Spacing.screen)
            }
            .background(Palette.background)
            .navigationTitle(entry.term)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !isAdded {
                        Button(isSelected ? "Odznacz" : "Zaznacz") {
                            onToggle()
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct TopicEntryPreviewHeader: View {
    let entry: TopicEntry

    @Environment(SpeechService.self) private var speech

    var body: some View {
        Card {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(entry.term)
                        .font(FluentFont.flashcardTerm)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !entry.ipa.isEmpty {
                        Text(entry.ipa)
                            .font(FluentFont.ipa)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
                Spacer(minLength: Spacing.xs)
                SpeakButton(isSpeaking: speech.isSpeaking) { speech.speak(entry.term) }
                SpeakButton(style: .slow) { speech.speak(entry.term, slow: true) }
            }
            HStack(spacing: Spacing.xs) {
                LevelBadge(level: entry.level)
                if !entry.pos.isEmpty { TagChip(entry.pos) }
                if let frequency = entry.frequency { TagChip(frequency.namePl) }
            }
            Text(entry.translation)
                .font(FluentFont.title)
                .foregroundStyle(Palette.ink)
            if !entry.definition.isEmpty {
                Text(entry.definition)
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !entry.contextPl.isEmpty {
                Label(entry.contextPl, systemImage: "text.bubble")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

private struct TopicEntryDetails: View {
    let entry: TopicEntry

    private var rows: [TopicDetailRow] {
        [
            TopicDetailRow(title: "Formy", value: entry.forms),
            TopicDetailRow(title: "Kolokacje", value: entry.collocations),
            TopicDetailRow(title: "Synonimy", value: entry.synonyms),
            TopicDetailRow(title: "Antonimy", value: entry.antonyms),
            TopicDetailRow(title: "Potocznie", value: entry.natural),
            TopicDetailRow(title: "Uwaga", value: entry.notePl)
        ].filter { !$0.value.isEmpty }
    }

    var body: some View {
        let items = rows
        if !items.isEmpty {
            Card {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(item.title)
                            .fluentEyebrow()
                            .foregroundStyle(Palette.inkSecondary)
                        Text(item.value)
                            .font(FluentFont.callout)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct TopicDetailRow: Identifiable {
    let title: String
    let value: String
    var id: String { title }
}
