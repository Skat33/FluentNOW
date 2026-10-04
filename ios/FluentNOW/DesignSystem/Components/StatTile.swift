import SwiftUI

/// Kafelek statystyki: ikona, duża liczba, opis (np. „Seria · 5 dni”).
///
/// ```swift
/// StatTile(title: "Powtórki na dziś", value: "12", systemImage: "arrow.clockwise", tone: .accent)
/// ```
struct StatTile: View {
    private let title: String
    private let value: String
    private let systemImage: String
    private let caption: String?
    private let tone: ToneColors

    init(title: String, value: String, systemImage: String, caption: String? = nil, tone: ToneColors = .accent) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.caption = caption
        self.tone = tone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(.body, design: .default, weight: .semibold))
                .foregroundStyle(tone.foreground)
                .frame(width: 34, height: 34)
                .background(tone.background, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .accessibilityHidden(true)
            Text(value)
                .font(FluentFont.numberMedium)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let caption {
                Text(caption)
                    .font(FluentFont.caption)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.m)
        .fluentCardBackground()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(caption.map { "\(value), \($0)" } ?? value))
    }
}

#Preview("Kafelki statystyk") {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
        StatTile(title: "Powtórki na dziś", value: "12", systemImage: "arrow.clockwise")
        StatTile(title: "Seria", value: "5 dni", systemImage: "flame", tone: .warning)
        StatTile(title: "Opanowane", value: "86", systemImage: "checkmark.seal", caption: "+7 w tym tygodniu", tone: .success)
        StatTile(title: "Szacowany poziom", value: "B1", systemImage: "graduationcap", tone: .info)
    }
    .padding(Spacing.screen)
    .background(Palette.background)
}
