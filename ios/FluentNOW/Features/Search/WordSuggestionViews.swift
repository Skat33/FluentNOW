import SwiftUI
import FluentKit

/// Wiersz podpowiedzi słownika (FEEDBACK-9 N3): hasło, tłumaczenia (to samo znaczenie z kilku
/// tematów raz — jak `SenseGrouping`), poziom, „Masz już” + wyszarzenie, gdy użytkownik ma
/// wszystkie pokazane znaczenia.
struct WordSuggestionRow: View {
    let suggestion: SearchSuggestion
    let ownedCount: Int

    private var total: Int { suggestion.translations.count }
    private var isOwned: Bool { total > 0 && ownedCount >= total }

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(suggestion.term)
                        .font(FluentFont.bodyEmphasized)
                        .foregroundStyle(Palette.ink)
                    if isOwned {
                        OwnedVocabularyBadge()
                    }
                }
                if !suggestion.translations.isEmpty {
                    Text(suggestion.translations.joined(separator: " · "))
                        .font(FluentFont.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(2)
                }
                if ownedCount > 0 && !isOwned {
                    Text("Masz już \(ownedCount) z \(total) znaczeń")
                        .font(FluentFont.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer(minLength: Spacing.xs)
            LevelBadge(level: suggestion.level)
            Image(systemName: "chevron.right")
                .font(FluentFont.footnote.weight(.semibold))
                .foregroundStyle(Palette.inkTertiary)
                .accessibilityHidden(true)
        }
        .contentShape(Rectangle())
        .frame(minHeight: HitTarget.minimum)
        .ownedVocabularyDimmed(isOwned)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Pokazuje znaczenia do wyboru"))
    }
}

/// Sekcje podpowiedzi w formularzu: „Czy chodziło Ci o…?” (literówka), „Propozycje”
/// (dokładne → prefiks EN → PL → wewnątrz frazy), „Podobne słowa” (nic innego nie pasuje).
struct WordSuggestionSections: View {
    let result: SearchSuggestionResult
    let owned: OwnedVocabulary
    let query: String
    let onSelect: (SearchSuggestion) -> Void

    var body: some View {
        if !result.corrections.isEmpty {
            Section {
                WordSuggestionRows(items: result.corrections, owned: owned, onSelect: onSelect)
            } header: {
                Text("Czy chodziło Ci o…?")
            } footer: {
                if result.matches.isEmpty {
                    Text("Nie ma „\(query)” w słowniku — może to literówka.")
                }
            }
        }
        if !result.matches.isEmpty {
            Section("Propozycje") {
                WordSuggestionRows(items: result.matches, owned: owned, onSelect: onSelect)
            }
        }
        if !result.similar.isEmpty {
            Section {
                WordSuggestionRows(items: result.similar, owned: owned, onSelect: onSelect)
            } header: {
                Text("Podobne słowa")
            }
        }
    }
}

/// Wiersze-przyciski podpowiedzi.
struct WordSuggestionRows: View {
    let items: [SearchSuggestion]
    let owned: OwnedVocabulary
    let onSelect: (SearchSuggestion) -> Void

    var body: some View {
        ForEach(items) { (item: SearchSuggestion) in
            Button {
                onSelect(item)
            } label: {
                WordSuggestionRow(suggestion: item, ownedCount: item.ownedTranslationCount(in: owned))
            }
            .buttonStyle(.plain)
        }
    }
}
