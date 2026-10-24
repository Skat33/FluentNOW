import SwiftUI
import FluentKit

/// „Czytanie i gramatyka” (FEEDBACK-6 K1): po usunięciu sekcji „Ile masz czasu?” to jedyne
/// wejście do czytania, gramatyki, idiomów, miksu językowego i produkcji. Każdy kafelek uruchamia
/// jeden tryb (bez łączenia i losowania). Kafelek z przerwaną sesją ma znacznik „Przerwane”;
/// dotknięcie pokazuje wybór „Kontynuuj” / „Zacznij od nowa” (obsługa w `StudyHomeView`).
struct StudyMoreActivitiesCard: View {
    /// Zajęcia z przerwaną sesją.
    let paused: Set<StudyActivity>
    /// Zajęcie, którego nowa sesja właśnie się przygotowuje.
    let starting: StudyActivity?
    let onOpen: (StudyActivity) -> Void

    var body: some View {
        Card(spacing: Spacing.m) {
            SectionHeader("Czytanie i gramatyka", subtitle: "Teksty i zestawy z banku na Twoim poziomie — działają od razu, także bez słów i bez internetu.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
                ForEach(StudyMoreActivity.all) { (item: StudyMoreActivity) in
                    StudyMoreActivityTile(
                        item: item,
                        isPaused: paused.contains(item.activity),
                        isStarting: starting == item.activity,
                        isBusy: starting != nil
                    ) {
                        onOpen(item.activity)
                    }
                }
            }
        }
    }
}

/// Kafelek zajęcia: tryb nauki (`StudyMode`) + zajęcie do wznawiania (`StudyActivity`).
struct StudyMoreActivity: Identifiable, Hashable {
    let activity: StudyActivity
    let mode: StudyMode

    var id: StudyActivity { activity }

    var title: String {
        switch activity {
        case .production: return "Produkcja"
        case .practice(let kind): return kind.studyTitle
        case .reading, .singleType, .flashcards: return activity.title
        }
    }

    static let all: [StudyMoreActivity] = [
        StudyMoreActivity(activity: .reading, mode: .reading),
        StudyMoreActivity(activity: .practice(.grammar), mode: .grammar),
        StudyMoreActivity(activity: .practice(.idioms), mode: .idioms),
        StudyMoreActivity(activity: .practice(.mixed), mode: .languageMix),
        StudyMoreActivity(activity: .production, mode: .production)
    ]
}

private struct StudyMoreActivityTile: View {
    let item: StudyMoreActivity
    let isPaused: Bool
    let isStarting: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .top) {
                    Image(systemName: item.mode.studySystemImage)
                        .font(FluentFont.title)
                        .foregroundStyle(Palette.accent)
                        .accessibilityHidden(true)
                    Spacer(minLength: Spacing.xs)
                    if isStarting {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                    }
                }
                Text(item.title)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(item.mode.studyDescription)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.leading)
                if isPaused {
                    TagChip("Przerwane", systemImage: "pause.circle", tone: .accent)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(Spacing.m)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(Palette.separator, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isPaused ? "\(item.title), przerwane" : item.title))
        .accessibilityHint(Text(isPaused ? "Pozwala dokończyć albo zacząć od nowa" : item.mode.studyDescription))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Czytanie i gramatyka") {
    ScrollView {
        StudyMoreActivitiesCard(paused: [.reading], starting: nil, onOpen: { (_: StudyActivity) -> Void in })
            .padding(Spacing.screen)
    }
    .background(Palette.background)
    .fluentPreviewEnvironment()
}
