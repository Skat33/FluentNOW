import SwiftUI
import FluentKit

/// Tekst czytanki: czytelna typografia (krój szeryfowy, Dynamic Type, kolumna `readableWidth`).
/// Wyróżnienia (FEEDBACK-8 M1, `ReadingHighlightStyle`): sam kolor i grubość, bez podkreśleń i teł —
/// słowniczek (akcent), polecane do nauki (pogrubione, morskie), moje słowa (półgrube, pomarańczowe);
/// legenda z próbkami pod tytułem. Używane na etapie czytania (obu trybów) i w przeglądzie. Dotknięcie otwiera arkusz z tłumaczeniem
/// w kontekście tego tekstu. Po pytaniach fragmenty-dowody (`evidence`) są wyróżnione markerem.
struct ReadingPassageCard: View {
    let reading: Reading
    /// Fragmenty-dowody do wyróżnienia (etap wyników); puste = bez wyróżnień.
    var evidence: [String] = []

    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech
    @Environment(AppEnvironment.self) private var env
    @State private var layout: ReadingPassageLayout?
    @State private var selection: ReadingTermSelection?

    var body: some View {
        Card(spacing: Spacing.m) {
            ReadingPassageHeader(reading: reading, isSpeaking: speech.isSpeaking) {
                speech.speak(reading.paragraphs.joined(separator: "\n"))
            }
            if let layout, layout.hasHighlights {
                ReadingHighlightLegend(kinds: layout.kinds)
            }
            paragraphList
        }
        .environment(\.openURL, OpenURLAction { url in
            handle(url)
        })
        .sheet(item: $selection) { selection in
            ReadingWordSheet(selection: selection)
        }
        .task(id: "\(reading.id):\(store.revision):\(evidence.count)") {
            await rebuild()
        }
    }

    private var paragraphList: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(Array(reading.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                ReadingParagraphView(
                    text: layout?.attributed.studyItem(at: index) ?? AttributedString(paragraph),
                    links: layout?.links.studyItem(at: index),
                    plain: paragraph
                )
            }
        }
    }

    /// Tokeny liczone poza głównym wątkiem; słowniczek z czytanki lub — dla starszych zapisów
    /// sesji bez słowniczka — z banku po `id`.
    private func rebuild() async {
        var glossary = reading.glossary
        if glossary.isEmpty, let bank = try? await env.content.readingBank() {
            glossary = bank.readings.first(where: { $0.id == reading.id })?.glossary ?? []
        }
        guard !Task.isCancelled else { return }
        let paragraphs = reading.paragraphs
        let evidence = self.evidence
        let usedGlossary = glossary
        let tokens = await store.compute { (state: LearnerState) -> ReadingPassageTokens in
            ReadingPassageTokens.make(paragraphs: paragraphs, words: state.words, glossary: usedGlossary, evidence: evidence)
        }
        guard !Task.isCancelled else { return }
        layout = ReadingPassageLayout(tokens: tokens)
    }

    private func handle(_ url: URL) -> OpenURLAction.Result {
        guard let link = ReadingTermLink(url: url), let layout else { return .systemAction }
        guard let selected = layout.selection(paragraph: link.paragraph, token: link.token, paragraphs: reading.paragraphs) else {
            return .handled
        }
        selection = selected
        return .handled
    }
}

/// Nagłówek czytanki: poziom, źródło, tytuł, liczba słów i pytań, odsłuch całości.
private struct ReadingPassageHeader: View {
    let reading: Reading
    let isSpeaking: Bool
    let onSpeak: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                LevelBadge(level: reading.level)
                TagChip(reading.source == .ai ? "Tekst AI" : "Bank czytanek", tone: .neutral)
                Spacer(minLength: Spacing.xs)
                SpeakButton(isSpeaking: isSpeaking, accessibilityLabel: "Odsłuchaj cały tekst", action: onSpeak)
            }
            Text(reading.title)
                .font(FluentFont.title)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("\(wordCount) słów · \(reading.questions.count) pytań")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
        }
    }

    private var wordCount: Int {
        reading.paragraphs.reduce(0) { total, paragraph in
            total + paragraph.split(whereSeparator: { $0.isWhitespace }).count
        }
    }
}

/// Legenda wyróżnień pod tytułem (FEEDBACK-8 M1): kolorowe próbki (kolor + grubość) i jedna
/// wskazówka „dotknij słowa”. W wąskim miejscu lub przy rozmiarach dostępności — próbki w kolumnie
/// z krótkim opisem.
private struct ReadingHighlightLegend: View {
    let kinds: [ReadingHighlightStyle.Kind]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            samples
            Text("Dotknij wyróżnionego słowa, aby zobaczyć tłumaczenie w tym tekście.")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
    }

    @ViewBuilder
    private var samples: some View {
        if dynamicTypeSize.isAccessibilitySize {
            describedColumn
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.m) {
                    ForEach(kinds, id: \.self) { (kind: ReadingHighlightStyle.Kind) in
                        Text(ReadingHighlightStyle.sample(ReadingHighlightStyle.sampleWord(kind), kind: kind))
                    }
                }
                describedColumn
            }
        }
    }

    private var describedColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            ForEach(kinds, id: \.self) { (kind: ReadingHighlightStyle.Kind) in
                ReadingLegendRow(kind: kind)
            }
        }
    }

    private var accessibilityText: String {
        let parts: [String] = kinds.map { (kind: ReadingHighlightStyle.Kind) -> String in
            ReadingHighlightStyle.accessibilityText(kind)
        }
        return (parts + ["Dotknij wyróżnionego słowa, aby zobaczyć tłumaczenie w tym tekście."]).joined(separator: ". ")
    }
}

/// Wiersz legendy: próbka + krótki opis.
private struct ReadingLegendRow: View {
    let kind: ReadingHighlightStyle.Kind

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            Text(ReadingHighlightStyle.sample(ReadingHighlightStyle.sampleWord(kind), kind: kind))
            Text("— \(ReadingHighlightStyle.legendText(kind))")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Akapit z przyciskiem odsłuchu. Z podświetleniami — dwie warstwy (`ReadingHighlightedText`,
/// K3): kolory słów nie znikają pod kolorem linków.
private struct ReadingParagraphView: View {
    let text: AttributedString
    /// Warstwa linków (`nil` — tekst jeszcze bez podświetleń).
    let links: AttributedString?
    let plain: String

    @Environment(SpeechService.self) private var speech

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            paragraphText
                .font(FluentFont.reading)
                .foregroundStyle(Palette.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                speech.speak(plain)
            } label: {
                Image(systemName: "speaker.wave.1")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.accent)
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Odsłuchaj akapit"))
        }
    }

    @ViewBuilder
    private var paragraphText: some View {
        if let links {
            ReadingHighlightedText(display: text, links: links)
        } else {
            Text(text)
        }
    }
}

/// Linki słów słownika w tekście (`fluentnow-word://open/<id>`), obsługiwane lokalnie przez `openURL`.
/// Zachowane dla zgodności (testy, inne ekrany); czytanka używa `ReadingTermLink`.
enum ReadingWordLink {
    static let scheme = "fluentnow-word"

    static func url(for wordID: String) -> URL? {
        guard let encoded = wordID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return URL(string: "\(scheme)://open/\(encoded)")
    }

    static func wordID(from url: URL) -> String? {
        guard url.scheme == scheme else { return nil }
        let id = url.lastPathComponent
        return id.isEmpty || id == "/" ? nil : id
    }
}

#Preview("Czytanka") {
    ScrollView {
        ReadingPassageCard(reading: Reading(
            id: "preview",
            title: "A Day at the Airport",
            level: "A2",
            paragraphs: [
                "Anna arrived at the airport two hours early. She printed her boarding pass and checked her bag.",
                "At the gate, she bought a coffee and waited for the announcement."
            ],
            questions: [],
            glossary: [
                ReadingGlossaryEntry(form: "boarding pass", lemma: "boarding pass", translation: "karta pokładowa", ipa: "/ˈbɔːrdɪŋ ˌpæs/"),
                ReadingGlossaryEntry(form: "announcement", lemma: "announcement", translation: "komunikat", ipa: "/əˈnaʊnsmənt/")
            ]
        ), evidence: ["She printed her boarding pass"])
        .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
