import SwiftUI
import FluentKit

/// Nagłówek szczegółów: hasło, IPA, wymowa (normalna i wolna), poziom, status, kolekcja, tagi.
struct WordDetailHeader: View {
    let word: Word
    let now: Timestamp

    @Environment(SpeechService.self) private var speech

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: Spacing.s) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(word.en)
                        .font(FluentFont.display)
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
                SpeakButton(style: .slow) { speech.speak(word.en, slow: true) }
            }
            WordHeaderChips(word: word, now: now)
        }
    }
}

private struct WordHeaderChips: View {
    let word: Word
    let now: Timestamp

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                LevelBadge(level: word.level)
                WordStatusLabel(status: word.status(now: now))
                    .padding(.horizontal, Spacing.xs)
                if word.important {
                    TagChip("Ważne", systemImage: "star.fill", tone: .warning)
                }
                TagChip(word.collection, systemImage: "square.stack.3d.up", tone: Palette.collectionTone(named: word.collection))
                ForEach(word.tags, id: \.self) { tag in
                    TagChip(tag)
                }
            }
        }
    }
}

/// Jedno znaczenie: tłumaczenie, opis, wyniki 5 umiejętności („—” dla niećwiczonych), przykłady.
struct WordMeaningCard: View {
    let word: Word
    let meaning: Meaning
    let number: Int
    let total: Int

    @State private var showsAllExamples = false

    private var examples: [ExamplePair] {
        meaning.examples.indices.compactMap { VocabularyGrader.examplePair(word: word, meaning: meaning, index: $0) }
    }

    var body: some View {
        Card(spacing: Spacing.m) {
            WordMeaningTitle(word: word, meaning: meaning, number: number, total: total)
            WordMeaningSkills(meaning: meaning)
            let pairs = examples
            if !pairs.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text("Przykłady")
                        .fluentEyebrow()
                        .foregroundStyle(Palette.inkSecondary)
                    ForEach(Array(pairs.prefix(showsAllExamples ? pairs.count : 3).enumerated()), id: \.offset) { _, pair in
                        WordExampleRow(pair: pair)
                    }
                    if pairs.count > 3 {
                        Button(showsAllExamples ? "Pokaż mniej" : "Pokaż wszystkie (\(pairs.count))") {
                            showsAllExamples.toggle()
                        }
                        .font(FluentFont.button)
                        .frame(minHeight: HitTarget.minimum)
                    }
                }
            }
        }
    }
}

private struct WordMeaningTitle: View {
    let word: Word
    let meaning: Meaning
    let number: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if total > 1 {
                Text("Znaczenie \(number) z \(total)")
                    .fluentEyebrow()
                    .foregroundStyle(Palette.inkSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(meaning.translation)
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Spacing.xs)
                LevelBadge(level: meaning.effectiveLevel(in: word))
            }
            let details = [meaning.effectivePos(in: word), meaning.register == "neutralny" ? "" : meaning.register]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !details.isEmpty {
                Text(details)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if !meaning.definition.isEmpty {
                Text(meaning.definition)
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !meaning.context.isEmpty {
                Label(meaning.context, systemImage: "text.bubble")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            if !meaning.natural.isEmpty {
                Label("Potocznie: \(meaning.natural)", systemImage: "quote.bubble")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }
}

private struct WordMeaningSkills: View {
    let meaning: Meaning

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            ForEach(SkillTone.allCases) { tone in
                SkillBar(skill: tone, score: WordMeaningSkills.score(meaning, tone))
            }
        }
    }

    /// Wynik umiejętności 0–100 albo `nil` (jeszcze nie ćwiczona → „—”).
    static func score(_ meaning: Meaning, _ tone: SkillTone) -> Double? {
        guard let skill = Skill(rawValue: tone.rawValue), let score = meaning.scores[skill] else { return nil }
        return Double(score.value)
    }
}

private struct WordExampleRow: View {
    let pair: ExamplePair

    @Environment(SpeechService.self) private var speech

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HighlightedText(pair.en, focus: pair.focusEn.isEmpty ? nil : pair.focusEn)
                    .font(FluentFont.body)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !pair.pl.isEmpty {
                    HighlightedText(pair.pl, focus: pair.focusPl.isEmpty ? nil : pair.focusPl, highlight: Palette.inkSecondary)
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            SpeakButton(size: .small, accessibilityLabel: "Odtwórz przykład") { speech.speak(pair.en) }
        }
    }
}

/// Formy, kolokacje, synonimy, antonimy, notatka, źródło.
struct WordExtrasCard: View {
    let word: Word

    private var rows: [WordExtraRow] {
        [
            WordExtraRow(title: "Formy", value: word.forms),
            WordExtraRow(title: "Kolokacje", value: word.collocations),
            WordExtraRow(title: "Synonimy", value: word.synonyms),
            WordExtraRow(title: "Antonimy", value: word.antonyms),
            WordExtraRow(title: "Notatka", value: word.note),
            WordExtraRow(title: "Źródło", value: word.source)
        ].filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        let items = rows
        if !items.isEmpty {
            Card {
                SectionHeader("Więcej o słowie")
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

private struct WordExtraRow: Identifiable {
    let title: String
    let value: String
    var id: String { title }
}

/// Następna powtórka i data dodania.
struct WordScheduleCard: View {
    let word: Word
    let now: Timestamp

    private var nextDue: Timestamp? {
        word.meanings.filter { !$0.isNew }.map { $0.due }.min()
    }

    var body: some View {
        Card {
            SectionHeader("Powtórki")
            if word.archived {
                Text("Słowo jest w archiwum — nie pojawia się w sesjach.")
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
            } else if let due = nextDue {
                if due <= now {
                    Label("Czeka na powtórkę już teraz", systemImage: "clock.badge.exclamationmark")
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.warning)
                } else {
                    Label("Następna powtórka \(Date(timestamp: due).formatted(.relative(presentation: .named)))",
                          systemImage: "calendar.badge.clock")
                        .font(FluentFont.callout)
                        .foregroundStyle(Palette.ink)
                }
            } else {
                Label("Jeszcze nie ćwiczone — pojawi się w najbliższej sesji", systemImage: "sparkle")
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
            }
            Text("Dodano \(Date(timestamp: word.created).formatted(date: .long, time: .omitted))")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
        }
    }
}
