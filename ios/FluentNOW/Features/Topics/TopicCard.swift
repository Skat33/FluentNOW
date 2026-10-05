import SwiftUI
import FluentKit

/// Karta tematu: ikona, nazwa PL/EN, liczba słów, rozkład CEFR, ile już dodano.
struct TopicCard: View {
    let topic: TopicSummary
    let added: Int

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: Spacing.s) {
                Image(systemName: topic.symbol.isEmpty ? "text.book.closed" : topic.symbol)
                    .font(FluentFont.title)
                    .foregroundStyle(Palette.accent)
                    .frame(width: 48, height: 48)
                    .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(topic.namePl)
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    if !topic.nameEn.isEmpty {
                        Text(topic.nameEn)
                            .font(FluentFont.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    if !topic.summaryPl.isEmpty {
                        Text(topic.summaryPl)
                            .font(FluentFont.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            CEFRDistributionBar(levels: topic.levels, total: topic.entryCount)
            HStack {
                Text(LibraryText.words(topic.entryCount))
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
                Spacer()
                if added > 0 {
                    Label(added >= topic.entryCount ? "Wszystkie dodane" : "Dodano \(added)", systemImage: "checkmark.circle.fill")
                        .font(FluentFont.caption)
                        .foregroundStyle(Palette.success)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Pasek rozkładu poziomów CEFR (A zieleń, B niebieski, C bursztyn) z opisem dla VoiceOver.
struct CEFRDistributionBar: View {
    let levels: [String: Int]
    let total: Int

    struct Segment: Identifiable {
        let level: String
        let count: Int
        var id: String { level }
    }

    private var segments: [Segment] {
        CEFR.levels.compactMap { level -> Segment? in
            let count = levels[level] ?? 0
            return count > 0 ? Segment(level: level, count: count) : nil
        }
    }

    var body: some View {
        let parts = segments
        let sum = max(1, parts.reduce(0) { $0 + $1.count })
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(parts) { part in
                        Rectangle()
                            .fill(CEFRTone.tone(for: part.level).foreground)
                            .frame(width: max(2, (proxy.size.width - CGFloat(parts.count) * 2) * CGFloat(part.count) / CGFloat(sum)))
                    }
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            Text(parts.map { "\($0.level) \($0.count)" }.joined(separator: " · "))
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Poziomy: " + parts.map { "\($0.level): \($0.count)" }.joined(separator: ", ")))
    }
}
