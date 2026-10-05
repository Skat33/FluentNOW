import SwiftUI
import FluentKit

/// Pasek filtrów listy słów: menu (sortowanie, poziom, kolekcja) + chipy statusu.
struct WordFilterBar: View {
    @Binding var filter: WordListFilter
    let collections: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.xs) {
                WordFilterMenu(filter: $filter, collections: collections)
                ForEach(WordStatusFilter.allCases) { status in
                    TagChip(status.title, systemImage: status.systemImage, isSelected: filter.status == status) {
                        filter.status = status
                    }
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.xxs)
        }
    }
}

private struct WordFilterMenu: View {
    @Binding var filter: WordListFilter
    let collections: [String]

    private var activeCount: Int {
        (filter.level == nil ? 0 : 1) + (filter.collection == nil ? 0 : 1)
    }

    var body: some View {
        Menu {
            Picker("Sortowanie", selection: $filter.sort) {
                ForEach(WordSortOrder.allCases) { order in
                    Text(order.title).tag(order)
                }
            }
            Picker("Poziom", selection: $filter.level) {
                Text("Wszystkie poziomy").tag(String?.none)
                ForEach(CEFR.levels, id: \.self) { level in
                    Text(level).tag(String?.some(level))
                }
            }
            .pickerStyle(.menu)
            Picker("Kolekcja", selection: $filter.collection) {
                Text("Wszystkie kolekcje").tag(String?.none)
                ForEach(collections, id: \.self) { name in
                    Text(name).tag(String?.some(name))
                }
            }
            .pickerStyle(.menu)
            if activeCount > 0 {
                Button("Wyczyść poziom i kolekcję", role: .destructive) {
                    filter.level = nil
                    filter.collection = nil
                }
            }
        } label: {
            Label(activeCount > 0 ? "Filtry (\(activeCount))" : "Filtry", systemImage: "line.3.horizontal.decrease.circle")
                .font(FluentFont.subheadline.weight(.semibold))
                .foregroundStyle(activeCount > 0 ? Palette.onAccent : Palette.ink)
                .padding(.horizontal, Spacing.s)
                .padding(.vertical, Spacing.xs)
                .background(activeCount > 0 ? Palette.accentFill : Palette.surfaceMuted, in: Capsule())
                .frame(minHeight: HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("Filtry i sortowanie"))
    }
}

private struct WordFilterBarPreviewHost: View {
    @State private var filter = WordListFilter()

    var body: some View {
        WordFilterBar(filter: $filter, collections: ["Lotnisko", "Codzienne rozmowy"])
            .background(Palette.background)
    }
}

#Preview("Filtry słownika") {
    WordFilterBarPreviewHost()
}
