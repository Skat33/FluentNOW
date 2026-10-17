import SwiftUI
import FluentKit

/// Tekst czytanki: czytelna typografia (krój szeryfowy, Dynamic Type, kolumna `readableWidth`).
/// Podświetlenia (G1): słowa z mojego słownika — tło i ciągłe podkreślenie; słowa przydatne ze
/// słowniczka kontekstowego — podkreślenie kropkowane. Dotknięcie otwiera arkusz z tłumaczeniem
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
                ReadingHighlightLegend(hasOwnWords: layout.hasOwnWords, hasUsefulWords: layout.hasUsefulWords)
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

/// Legenda podświetleń (nie tylko kolorem: tło + linia ciągła vs linia kropkowana).
private struct ReadingHighlightLegend: View {
    let hasOwnWords: Bool
    let hasUsefulWords: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            if hasOwnWords {
                legendRow(sample: ReadingHighlightStyle.sample("słowo", kind: .own), text: "z Twojego słownika")
            }
            if hasUsefulWords {
                legendRow(sample: ReadingHighlightStyle.sample("słowo", kind: .useful), text: "warte nauki")
            }
            Text("Dotknij wyróżnionego słowa, aby zobaczyć tłumaczenie w tym tekście.")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func legendRow(sample: AttributedString, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(sample)
                .font(FluentFont.footnote)
            Text("— \(text)")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
        }
    }
}

/// Akapit z przyciskiem odsłuchu.
private struct ReadingParagraphView: View {
    let text: AttributedString
    let plain: String

    @Environment(SpeechService.self) private var speech

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Text(text)
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
