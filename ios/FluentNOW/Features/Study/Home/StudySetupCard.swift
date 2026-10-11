import SwiftUI
import FluentKit

/// „Ile masz czasu?” + rodzaje ćwiczeń (wielokrotny wybór) + losowa kolejność + start.
struct StudySetupCard: View {
    @Binding var minutes: Int
    @Binding var selected: [StudyMode]
    @Binding var random: Bool
    let hasWords: Bool
    let collection: String?
    let estimate: String
    let isStarting: Bool
    let onClearCollection: () -> Void
    let onStart: () -> Void

    var body: some View {
        Card(spacing: Spacing.m) {
            SectionHeader("Ile masz czasu?")
            Picker("Ile masz czasu?", selection: $minutes) {
                ForEach([5, 10, 15], id: \.self) { value in
                    Text("\(value) minut").tag(value)
                }
            }
            .pickerStyle(.segmented)
            .fluentSensoryFeedback(FluentHaptic.selection, trigger: minutes)

            Text(selectionInfo)
                .font(FluentFont.subheadline)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let collection {
                TagChip("Kolekcja: \(collection) ✕", systemImage: "folder", isSelected: true, action: onClearCollection)
                    .accessibilityHint(Text("Usuwa ograniczenie do kolekcji"))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
                ForEach(StudyMode.allCases, id: \.self) { mode in
                    StudyModeCard(
                        mode: mode,
                        isSelected: selected.contains(mode),
                        disabledReason: mode.isVocabulary && !hasWords ? "Najpierw dodaj kilka słów lub temat." : nil
                    ) {
                        toggle(mode)
                    }
                }
            }

            if selected.count > 1 {
                Toggle(isOn: $random) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Losuj kolejność ćwiczeń")
                            .font(FluentFont.body)
                            .foregroundStyle(Palette.ink)
                        Text("Przeplataj zadania z wybranych rodzajów. Bez losowania są pogrupowane według rodzaju.")
                            .font(FluentFont.footnote)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .tint(Palette.accent)
            }

            Label(estimate, systemImage: "clock")
                .font(FluentFont.subheadline)
                .foregroundStyle(Palette.inkSecondary)
            PrimaryButton(
                selected.isEmpty ? "Wybierz ćwiczenie" : "Rozpocznij sesję",
                systemImage: "play.fill",
                isLoading: isStarting,
                action: onStart
            )
            .disabled(selected.isEmpty)
        }
    }

    private var selectionInfo: String {
        guard selected.count > 1 else { return "Zaznacz jeden lub kilka rodzajów ćwiczeń." }
        let kinds = StudyFormat.plural(selected.count, one: "rodzaj", few: "rodzaje", many: "rodzajów")
        return "Wybrano \(selected.count) \(kinds) — połączymy je w jednej sesji."
    }

    private func toggle(_ mode: StudyMode) {
        if let index = selected.firstIndex(of: mode) {
            selected.remove(at: index)
        } else {
            selected.append(mode)
        }
    }
}

private struct StudySetupCardPreview: View {
    @State private var minutes = 10
    @State private var selected: [StudyMode] = [.mixed, .reading]
    @State private var random = true

    var body: some View {
        ScrollView {
            StudySetupCard(
                minutes: $minutes,
                selected: $selected,
                random: $random,
                hasWords: true,
                collection: "Lotnisko",
                estimate: "Około 10 min · 16 zadań",
                isStarting: false,
                onClearCollection: {},
                onStart: {}
            )
            .padding(Spacing.screen)
        }
        .background(Palette.background)
    }
}

#Preview("Wybór sesji") {
    StudySetupCardPreview()
        .fluentPreviewEnvironment()
}
