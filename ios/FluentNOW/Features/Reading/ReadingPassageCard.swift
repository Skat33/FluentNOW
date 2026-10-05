import SwiftUI
import FluentKit

/// Tekst czytanki: czytelna typografia (krój szeryfowy, Dynamic Type, kolumna `readableWidth`),
/// słowa z mojego słownika podkreślone (`ReadingTokenizer`) — dotknięcie pokazuje znaczenia,
/// odsłuch całości i pojedynczych akapitów.
struct ReadingPassageCard: View {
    let reading: Reading
    /// W sesji łączonej tekst można zwinąć (to samo pytanie widzi się kilka razy).
    var collapsible: Bool = false

    @Environment(LearningStore.self) private var store
    @Environment(SpeechService.self) private var speech
    @State private var paragraphs: [AttributedString]?
    @State private var selectedWord: ReadingWordSelection?
    @State private var isExpanded = true

    var body: some View {
        Card(spacing: Spacing.m) {
            ReadingPassageHeader(reading: reading, isSpeaking: speech.isSpeaking) {
                speech.speak(reading.paragraphs.joined(separator: "\n"))
            }
            if collapsible {
                DisclosureGroup(isExpanded: $isExpanded) {
                    paragraphList
                        .padding(.top, Spacing.xs)
                } label: {
                    Text(isExpanded ? "Zwiń tekst" : "Pokaż tekst")
                        .font(FluentFont.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                }
                .tint(Palette.accent)
            } else {
                paragraphList
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            guard let id = ReadingWordLink.wordID(from: url) else { return .systemAction }
            selectedWord = ReadingWordSelection(id: id)
            return .handled
        })
        .sheet(item: $selectedWord) { selection in
            ReadingWordSheet(wordID: selection.id)
        }
        .task(id: "\(reading.id):\(store.state.words.count)") {
            let source = reading.paragraphs
            let tokens = await store.compute { state in
                source.map { ReadingTokenizer.tokens(text: $0, words: state.words) }
            }
            paragraphs = tokens.map(ReadingWordLink.attributed(tokens:))
        }
    }

    private var paragraphList: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(Array(reading.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                ReadingParagraphView(
                    text: paragraphs?.studyItem(at: index) ?? AttributedString(paragraph),
                    plain: paragraph
                )
            }
        }
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
            Text("\(wordCount) słów · \(reading.questions.count) pytań. Podkreślone słowa są w Twoim słowniku — dotknij ich, aby zobaczyć znaczenia.")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var wordCount: Int {
        reading.paragraphs.reduce(0) { total, paragraph in
            total + paragraph.split(whereSeparator: { $0.isWhitespace }).count
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

/// Wybrane słowo (arkusz z tłumaczeniem).
struct ReadingWordSelection: Identifiable, Hashable {
    let id: String
}

/// Linki słów słownika w tekście (`fluentnow-word://open/<id>`), obsługiwane lokalnie przez `openURL`.
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

    static func attributed(tokens: [ReadingToken]) -> AttributedString {
        var result = AttributedString()
        for token in tokens {
            var piece = AttributedString(token.text)
            if let wordID = token.wordId, let url = url(for: wordID) {
                piece.link = url
                piece[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle.single
                piece[AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Palette.accent
            }
            result.append(piece)
        }
        return result
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
            questions: []
        ))
        .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
