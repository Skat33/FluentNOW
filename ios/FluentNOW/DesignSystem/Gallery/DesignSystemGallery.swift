import SwiftUI

/// Galeria wszystkich komponentów design systemu na jednym ekranie — do przeglądu wizualnego
/// (jasny/ciemny, Dynamic Type, iOS 17 vs 26). Dostępna z Ustawień (zaślepka) i w podglądzie.
struct DesignSystemGallery: View {
    @State private var confidence: ConfidenceLevel = .fair
    @State private var chipSelected = true
    @State private var progress = 0.6

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                GallerySection(title: "Kolory") { PaletteSwatches() }
                GallerySection(title: "Przyciski") {
                    PrimaryButton("Zaczynam naukę", systemImage: "play.fill") {}
                    SecondaryButton("Pokaż podpowiedź", systemImage: "lightbulb") {}
                    SecondaryButton("Usuń", systemImage: "trash", role: .destructive) {}
                }
                GallerySection(title: "Postęp") {
                    HStack(spacing: Spacing.l) {
                        ProgressRing(progress: progress, lineWidth: 10, accessibilityLabel: "Dzienny cel") {
                            Text("\(Int(progress * 10))")
                                .font(FluentFont.numberMedium)
                        }
                        .frame(width: 96, height: 96)
                        VStack(alignment: .leading, spacing: Spacing.s) {
                            Slider(value: $progress, in: 0...1)
                            LinearProgressBar(progress: progress)
                        }
                    }
                    ForEach(SkillTone.allCases) { skill in
                        SkillBar(skill: skill, score: skill == .listening ? nil : progress * 100)
                    }
                }
                GallerySection(title: "Statystyki") {
                    HStack(spacing: Spacing.s) {
                        StatTile(title: "Powtórki", value: "12", systemImage: "arrow.clockwise")
                        StatTile(title: "Seria", value: "5 dni", systemImage: "flame", tone: .warning)
                    }
                }
                GallerySection(title: "Odznaki i chipy") {
                    HStack { ForEach(CEFRTone.levels, id: \.self) { LevelBadge(level: $0) } }
                    HStack {
                        TagChip("rzeczownik")
                        TagChip("Trudne", systemImage: "flame", isSelected: chipSelected) { chipSelected.toggle() }
                    }
                }
                GallerySection(title: "Ćwiczenie") {
                    HStack(spacing: Spacing.s) {
                        HighlightedText("Could you lend me your pen?", focus: "lend me")
                            .font(FluentFont.sentence)
                        Spacer()
                        SpeakButton {}
                    }
                    ConfidencePicker(selection: $confidence)
                    FeedbackPanel(kind: .correct, message: "Could you **lend** me your pen?", playsHaptic: false)
                    FeedbackPanel(kind: .incorrect, message: "Poprawnie: **borrow**", explanation: "Pożyczyć OD kogoś.", playsHaptic: false)
                }
                GallerySection(title: "Stany") {
                    ErrorBanner(message: "Nie udało się zapisać zmian.", onRetry: {}, onDismiss: {})
                    LoadingStateView()
                    EmptyStateView(systemImage: "tray", title: "Pusto", message: "Nic tu jeszcze nie ma.")
                }
            }
            .padding(Spacing.screen)
        }
        .background(Palette.background)
        .navigationTitle("Galeria")
    }
}

private struct GallerySection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            SectionHeader(title)
            content
        }
    }
}

private struct PaletteSwatches: View {
    private let swatches: [(String, Color)] = [
        ("background", Palette.background),
        ("surface", Palette.surface),
        ("surfaceMuted", Palette.surfaceMuted),
        ("ink", Palette.ink),
        ("inkSecondary", Palette.inkSecondary),
        ("accent", Palette.accent),
        ("accentFill", Palette.accentFill),
        ("accentSoft", Palette.accentSoft),
        ("success", Palette.success),
        ("warning", Palette.warning),
        ("danger", Palette.danger),
        ("info", Palette.info)
    ]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.xs)], spacing: Spacing.xs) {
            ForEach(swatches.indices, id: \.self) { index in
                VStack(spacing: Spacing.xxs) {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .fill(swatches[index].1)
                        .frame(height: 44)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                                .strokeBorder(Palette.separator, lineWidth: 1)
                        }
                    Text(swatches[index].0)
                        .font(FluentFont.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
        }
    }
}

#Preview("Galeria — jasny") {
    NavigationStack { DesignSystemGallery() }
}

#Preview("Galeria — ciemny, duży tekst") {
    NavigationStack { DesignSystemGallery() }
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.accessibility2)
}
