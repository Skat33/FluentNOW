import SwiftUI
import FluentKit

/// Lista wpisów tematu z filtrem poziomów i zaznaczaniem.
struct TopicEntriesList: View {
    let topic: TopicFile
    @Binding var levels: Set<String>
    @Binding var selection: Set<String>
    let added: Set<String>
    let onPreview: (TopicEntry) -> Void

    private func isAdded(_ entry: TopicEntry) -> Bool {
        added.contains(ContentReference(file: topic.id, entryID: entry.id).rawValue)
    }

    private func visible(_ category: TopicCategory) -> [TopicEntry] {
        category.entries.filter { entry in
            entry.level.isEmpty || levels.contains(entry.level)
        }
    }

    /// Wpisy widoczne i jeszcze niedodane (te można zaznaczyć).
    private func selectable(_ entries: [TopicEntry]) -> [String] {
        entries.filter { !isAdded($0) }.map { $0.id }
    }

    var body: some View {
        List {
            Section {
                TopicHeaderCard(topic: topic, levels: $levels) {
                    let ids = topic.categories.flatMap { selectable(visible($0)) }
                    selection.formUnion(ids)
                } onClear: {
                    selection.removeAll()
                }
                .listRowInsets(EdgeInsets(top: Spacing.s, leading: 0, bottom: Spacing.s, trailing: 0))
                .listRowBackground(Color.clear)
            }
            ForEach(topic.categories) { category in
                let entries = visible(category)
                if !entries.isEmpty {
                    Section {
                        ForEach(entries) { entry in
                            TopicEntryRow(
                                entry: entry,
                                isSelected: selection.contains(entry.id),
                                isAdded: isAdded(entry),
                                onToggle: { toggle(entry.id) },
                                onPreview: { onPreview(entry) }
                            )
                        }
                    } header: {
                        TopicCategoryHeader(
                            category: category,
                            allSelected: selectable(entries).allSatisfy { selection.contains($0) },
                            hasSelectable: !selectable(entries).isEmpty
                        ) {
                            let ids = selectable(entries)
                            if ids.allSatisfy({ selection.contains($0) }) {
                                selection.subtract(ids)
                            } else {
                                selection.formUnion(ids)
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }
}

/// Opis tematu, filtr poziomów i zaznaczanie wszystkiego.
private struct TopicHeaderCard: View {
    let topic: TopicFile
    @Binding var levels: Set<String>
    let onSelectAll: () -> Void
    let onClear: () -> Void

    private var levelCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for entry in topic.allEntries { counts[entry.level, default: 0] += 1 }
        return counts
    }

    var body: some View {
        Card {
            if !topic.summaryPl.isEmpty {
                Text(topic.summaryPl)
                    .font(FluentFont.callout)
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            CEFRDistributionBar(levels: levelCounts, total: topic.entryCount)
            Text("Pokaż poziomy")
                .fluentEyebrow()
                .foregroundStyle(Palette.inkSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.xs) {
                    ForEach(CEFR.levels, id: \.self) { level in
                        TagChip(level, isSelected: levels.contains(level)) {
                            if levels.contains(level) {
                                if levels.count > 1 { levels.remove(level) }
                            } else {
                                levels.insert(level)
                            }
                        }
                    }
                }
            }
            HStack(spacing: Spacing.s) {
                SecondaryButton("Zaznacz widoczne", systemImage: "checkmark.circle", fillsWidth: false, action: onSelectAll)
                Button("Odznacz", action: onClear)
                    .font(FluentFont.button)
                    .frame(minHeight: HitTarget.minimum)
            }
        }
        .padding(.horizontal, Spacing.screen)
    }
}

private struct TopicCategoryHeader: View {
    let category: TopicCategory
    let allSelected: Bool
    let hasSelectable: Bool
    let onToggleAll: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.namePl)
                if !category.scenePl.isEmpty {
                    Text(category.scenePl)
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
                    .accessibilityLabel(Text(allSelected ? "Odznacz kategorię \(category.namePl)" : "Zaznacz kategorię \(category.namePl)"))
            }
        }
    }
}

/// Wiersz wpisu: pole wyboru + hasło, tłumaczenie, poziom; przycisk podglądu.
struct TopicEntryRow: View {
    let entry: TopicEntry
    let isSelected: Bool
    let isAdded: Bool
    let onToggle: () -> Void
    let onPreview: () -> Void

    var body: some View {
        HStack(spacing: Spacing.s) {
            Button(action: onToggle) {
                HStack(spacing: Spacing.s) {
                    Image(systemName: isAdded ? "checkmark.circle.fill" : (isSelected ? "checkmark.square.fill" : "square"))
                        .font(FluentFont.headline)
                        .foregroundStyle(isAdded ? Palette.success : (isSelected ? Palette.accent : Palette.inkSecondary))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.term)
                            .font(FluentFont.bodyEmphasized)
                            .foregroundStyle(Palette.ink)
                        Text(isAdded ? "\(entry.translation) · już w słowniku" : entry.translation)
                            .font(FluentFont.subheadline)
                            .foregroundStyle(Palette.inkSecondary)
                    }
                    Spacer(minLength: Spacing.xs)
                    LevelBadge(level: entry.level)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(isAdded)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityHint(Text(isAdded ? "Już dodane do nauki" : "Zaznacz do dodania"))
            Button(action: onPreview) {
                Image(systemName: "info.circle")
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.accent)
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("Podgląd: \(entry.term)"))
        }
    }
}
