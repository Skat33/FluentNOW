import SwiftUI
import FluentKit

// MARK: - Pusty ekran

/// Przykładowe zapytania (skróty) — zamiast listy wszystkich tematów.
struct TopicExamplesSection: View {
    let onSelect: (String) -> Void

    var body: some View {
        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: Spacing.xs)], alignment: .leading, spacing: Spacing.xs) {
                ForEach(TopicSearchModel.exampleQueries, id: \.self) { (example: String) in
                    TagChip(example, systemImage: "magnifyingglass", isSelected: false) {
                        onSelect(example)
                    }
                }
            }
            .padding(.vertical, Spacing.xxs)
        } header: {
            Text("Na przykład")
        } footer: {
            Text("Bez internetu szukamy we wbudowanej bazie. Z włączonym AI przygotujemy też tematy, których w niej nie ma.")
        }
    }
}

// MARK: - Wyniki

/// Nagłówek wyników, sekcje wpisów i alternatywy.
struct TopicResultsContent: View {
    let model: TopicSearchModel
    let onPreview: (TopicPreviewItem) -> Void

    var body: some View {
        TopicResultsHeaderSection(model: model)
        ForEach(model.visibleSections) { (section: TopicResultSection) in
            TopicResultSectionView(section: section, model: model, onPreview: onPreview)
        }
        TopicAlternativesSection(model: model)
    }
}

/// Temat, rozkład poziomów, filtr poziomów, zaznaczanie, uwagi.
private struct TopicResultsHeaderSection: View {
    let model: TopicSearchModel

    var body: some View {
        Section {
            if let primary = model.primary {
                TopicHeaderTitle(suggestion: primary, total: model.totalEntries)
            }
            if let notice = model.notice {
                Label(notice, systemImage: "sparkles")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error = model.addError {
                ErrorBanner(message: error, onDismiss: { model.dismissOutcome() })
            }
            CEFRDistributionBar(levels: model.levelCounts, total: model.totalEntries)
            TopicLevelFilter(model: model)
            HStack(spacing: Spacing.s) {
                SecondaryButton("Zaznacz widoczne", systemImage: "checkmark.circle", fillsWidth: false) {
                    model.selectVisible()
                }
                Button("Odznacz") { model.selection.removeAll() }
                    .font(FluentFont.button)
                    .frame(minHeight: HitTarget.minimum)
                    .buttonStyle(.borderless)
                    .disabled(model.selection.isEmpty)
            }
        }
    }
}

private struct TopicHeaderTitle: View {
    let suggestion: TopicSuggestion
    let total: Int

    private var subtitle: String {
        var parts: [String] = []
        if !suggestion.focusNames.isEmpty {
            parts.append("Najlepiej pasuje: \(suggestion.focusNames.joined(separator: ", "))")
        }
        parts.append(LibraryText.count(total, one: "słowo lub zwrot", few: "słowa i zwroty", many: "słów i zwrotów"))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: suggestion.symbol.isEmpty ? "text.book.closed" : suggestion.symbol)
                .font(FluentFont.title)
                .foregroundStyle(Palette.accent)
                .frame(width: 44, height: 44)
                .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text(suggestion.namePl)
                        .font(FluentFont.headline)
                        .foregroundStyle(Palette.ink)
                    if suggestion.match.isGenerated {
                        TagChip("AI", systemImage: "sparkles", tone: .accent)
                    }
                }
                Text(subtitle)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TopicLevelFilter: View {
    let model: TopicSearchModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                ForEach(CEFR.levels, id: \.self) { (level: String) in
                    TagChip(level, isSelected: model.levels.contains(level)) {
                        model.toggleLevel(level)
                    }
                }
            }
        }
        .accessibilityLabel(Text("Pokaż poziomy"))
    }
}

/// Jedna sekcja wyników (kategoria).
private struct TopicResultSectionView: View {
    let section: TopicResultSection
    let model: TopicSearchModel
    let onPreview: (TopicPreviewItem) -> Void

    private var selectable: [String] {
        section.entries.map { section.reference(of: $0) }.filter { !model.isAdded($0) }
    }

    var body: some View {
        Section {
            ForEach(section.entries) { (entry: TopicEntry) in
                TopicResultRow(section: section, entry: entry, model: model, onPreview: onPreview)
            }
        } header: {
            TopicSectionHeader(
                section: section,
                allSelected: selectable.allSatisfy { model.selection.contains($0) },
                hasSelectable: !selectable.isEmpty,
                onToggleAll: { model.toggleSection(section) }
            )
        }
    }
}

private struct TopicResultRow: View {
    let section: TopicResultSection
    let entry: TopicEntry
    let model: TopicSearchModel
    let onPreview: (TopicPreviewItem) -> Void

    private var reference: String { section.reference(of: entry) }

    var body: some View {
        TopicEntryRow(
            entry: entry,
            isSelected: model.selection.contains(reference),
            isAdded: model.isAdded(reference),
            isDraft: model.isDraft(entry),
            onToggle: { model.toggle(reference) },
            onPreview: { onPreview(TopicPreviewItem(entry: entry, reference: reference)) }
        )
    }
}

private struct TopicSectionHeader: View {
    let section: TopicResultSection
    let allSelected: Bool
    let hasSelectable: Bool
    let onToggleAll: () -> Void

    private var eyebrow: String? {
        switch section.kind {
        case .focus: return "Najlepiej pasuje"
        case .topic: return nil
        case .related: return "Z innego tematu"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(FluentFont.caption.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                }
                Text(section.title)
                if !section.subtitle.isEmpty {
                    Text(section.subtitle)
                        .font(FluentFont.caption)
                        .textCase(nil)
                }
            }
            Spacer()
            if hasSelectable {
                Button(allSelected ? "Odznacz" : "Zaznacz", action: onToggleAll)
                    .font(FluentFont.footnote.weight(.semibold))
                    .textCase(nil)
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text(allSelected ? "Odznacz kategorię \(section.title)" : "Zaznacz kategorię \(section.title)"))
            }
        }
    }
}

/// „Nie o to chodziło?” — inne pasujące tematy, nowy temat z AI, zapomnienie zapytania.
private struct TopicAlternativesSection: View {
    let model: TopicSearchModel

    private var isSavedMatch: Bool {
        model.primary?.match.reason == .savedQuery && !model.trimmedQuery.isEmpty
    }

    var body: some View {
        if !model.alternatives.isEmpty || model.canGenerate || isSavedMatch {
            Section {
                ForEach(model.alternatives) { (suggestion: TopicSuggestion) in
                    TopicSuggestionRow(suggestion: suggestion) {
                        Task { await model.choose(suggestion) }
                    }
                }
                if model.canGenerate && !model.trimmedQuery.isEmpty {
                    Button {
                        model.generate()
                    } label: {
                        Label("Utwórz nowy temat „\(model.trimmedQuery)” z AI", systemImage: "sparkles")
                    }
                    .disabled(model.isBusy)
                }
                if isSavedMatch {
                    Button {
                        Task { await model.rejectMatch() }
                    } label: {
                        Label("To nie ten temat — szukaj od nowa", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(model.isBusy)
                }
            } header: {
                Text("Nie o to chodziło?")
            }
        }
    }
}

// MARK: - Brak dopasowania, generowanie, błąd

struct TopicNoMatchContent: View {
    let model: TopicSearchModel

    @Environment(AppRouter.self) private var router

    var body: some View {
        Section {
            Text("Nie mamy jeszcze tematu „\(model.trimmedQuery)”.")
                .font(FluentFont.bodyEmphasized)
                .foregroundStyle(Palette.ink)
            if model.canGenerate {
                PrimaryButton("Utwórz temat z AI", systemImage: "sparkles") {
                    model.generate()
                }
                Text("Asystent przygotuje listę słów i zwrotów tej sytuacji. Temat zostanie zapisany na urządzeniu, więc kolejne wyszukiwanie będzie natychmiastowe.")
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Label(AssistantError.topicsNeedAI, systemImage: "sparkles")
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Otwórz ustawienia AI") {
                    router.dismissSheet()
                    router.push(SettingsRoute.assistant, on: .settings)
                }
            }
        }
        TopicSuggestionsSection(model: model, title: "Najbliższe tematy z bazy")
    }
}

/// Lista propozycji tematów (słabsze dopasowania).
struct TopicSuggestionsSection: View {
    let model: TopicSearchModel
    let title: String

    var body: some View {
        if !model.suggestions.isEmpty {
            Section(title) {
                ForEach(model.suggestions) { (suggestion: TopicSuggestion) in
                    TopicSuggestionRow(suggestion: suggestion) {
                        Task { await model.choose(suggestion) }
                    }
                }
            }
        }
    }
}

private struct TopicSuggestionRow: View {
    let suggestion: TopicSuggestion
    let action: () -> Void

    private var detail: String {
        var parts: [String] = []
        if !suggestion.focusNames.isEmpty { parts.append(suggestion.focusNames.joined(separator: ", ")) }
        parts.append(LibraryText.words(suggestion.entryCount))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                Image(systemName: suggestion.symbol.isEmpty ? "text.book.closed" : suggestion.symbol)
                    .foregroundStyle(Palette.accent)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.namePl)
                        .font(FluentFont.bodyEmphasized)
                        .foregroundStyle(Palette.ink)
                    Text(detail)
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Spacer(minLength: Spacing.xs)
                if suggestion.match.isGenerated {
                    TagChip("AI", tone: .accent)
                }
                Image(systemName: "chevron.right")
                    .font(FluentFont.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: HitTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Pokazuje słowa tego tematu"))
    }
}

struct TopicGeneratingSection: View {
    let query: String
    let onCancel: () -> Void

    var body: some View {
        Section {
            HStack(spacing: Spacing.s) {
                ProgressView()
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("AI układa listę słów dla „\(query)”…")
                        .font(FluentFont.bodyEmphasized)
                        .foregroundStyle(Palette.ink)
                    Text("Zwykle trwa to do minuty. Najważniejsze słowa będą na górze.")
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            Button("Przerwij", role: .cancel, action: onCancel)
        }
    }
}

struct TopicFailedContent: View {
    let model: TopicSearchModel
    let message: String

    private var retry: (() -> Void)? {
        model.canGenerate ? { model.generate() } : nil
    }

    var body: some View {
        Section {
            ErrorBanner(
                title: "Nie udało się przygotować tematu",
                message: message,
                onRetry: retry
            )
        }
        TopicSuggestionsSection(model: model, title: "Najbliższe tematy z bazy")
    }
}

// MARK: - Rozkład poziomów

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
        CEFR.levels.compactMap { (level: String) -> Segment? in
            let count = levels[level] ?? 0
            return count > 0 ? Segment(level: level, count: count) : nil
        }
    }

    var body: some View {
        let parts = segments
        let sum = max(1, parts.reduce(0) { $0 + $1.count })
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            GeometryReader { (proxy: GeometryProxy) in
                HStack(spacing: 2) {
                    ForEach(parts) { (part: Segment) in
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
