import SwiftUI
import FluentKit

/// „Ćwiczenia” (FEEDBACK-8 M2): jedna siatka wszystkich rodzajów zajęć — typy słownictwa,
/// „Słowo i zdjęcie” (W budowie), codzienna mieszanka, tryb pomyłek, słowa w parach, czytanie,
/// gramatyka, idiomy, miks językowy, produkcja. **Wybór pojedynczy**: dotknięcie kafelka = start
/// tego jednego ćwiczenia (łączenie rodzajów jest tylko w Teście). Kafelek z przerwaną sesją ma
/// znacznik „Przerwane” (okno „Kontynuuj / Zacznij od nowa” obsługuje `StudyHomeView`). Kafelek
/// słownictwa bez słów nie jest wyłączony: pokazuje „Brak słów”, a dotknięcie wyjaśnia, czego
/// brakuje. Długość 5 / 10 min dotyczy ćwiczeń słownictwa.
struct StudyExerciseTypesCard: View {
    @Binding var minutes: Int
    let collection: String?
    /// Zajęcie, którego sesja właśnie się przygotowuje.
    let starting: StudyActivity?
    /// Coś się uruchamia (kafelki chwilowo nieaktywne).
    let isBusy: Bool
    let notice: String?
    /// Zajęcia z przerwaną sesją (znacznik „Przerwane”).
    let paused: Set<StudyActivity>
    let onOpen: (StudyActivity) -> Void
    let onPictures: () -> Void
    let onDismissNotice: () -> Void

    @Environment(LearningStore.self) private var store
    @State private var availability: StudyExerciseAvailability?

    var body: some View {
        Card(spacing: Spacing.m) {
            SectionHeader("Ćwiczenia", subtitle: subtitle)
            StudyExerciseMinutesPicker(minutes: $minutes)
            if let notice {
                StudyExerciseTypeNotice(message: notice, onDismiss: onDismissNotice)
            }
            StudyExerciseGrid(
                availability: availability,
                starting: starting,
                isBusy: isBusy,
                paused: paused,
                onOpen: onOpen,
                onPictures: onPictures
            )
        }
        .task(id: availabilityKey) { await updateAvailability() }
    }

    private var subtitle: String {
        let base = "Dotknij kafelka, aby zacząć jedno ćwiczenie. Różne rodzaje zadań naraz sprawdzisz w Teście."
        guard let collection, !collection.isEmpty else { return base }
        return base + " Kolekcja: „\(collection)”."
    }

    private var availabilityKey: String {
        "\(store.revision)|\(collection ?? "")|\(store.loadPhase == .ready)"
    }

    /// Liczba słów dla kafelków słownictwa — na migawce stanu, poza głównym wątkiem.
    private func updateAvailability() async {
        guard store.loadPhase == .ready else { return }
        let limitedTo = collection
        let computed = await store.compute { (state: LearnerState) -> StudyExerciseAvailability in
            StudyExerciseAvailability.make(state: state, collection: limitedTo)
        }
        guard !Task.isCancelled else { return }
        availability = computed
    }
}

/// 5 / 10 minut (ćwiczenia słownictwa).
private struct StudyExerciseMinutesPicker: View {
    @Binding var minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Picker("Długość ćwiczeń słownictwa", selection: $minutes) {
                ForEach(SingleTypeSession.durations, id: \.self) { (value: Int) in
                    Text("\(value) minut").tag(value)
                }
            }
            .pickerStyle(.segmented)
            .fluentSensoryFeedback(FluentHaptic.selection, trigger: minutes)
            Text("Długość dotyczy ćwiczeń ze słówkami.")
                .font(FluentFont.caption)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Jedna siatka z nagłówkami grup.
private struct StudyExerciseGrid: View {
    let availability: StudyExerciseAvailability?
    let starting: StudyActivity?
    let isBusy: Bool
    let paused: Set<StudyActivity>
    let onOpen: (StudyActivity) -> Void
    let onPictures: () -> Void

    private let columns: [GridItem] = [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: Spacing.s) {
            ForEach(StudyExerciseGroup.all) { (group: StudyExerciseGroup) in
                Section {
                    ForEach(group.tiles) { (tile: StudyExerciseTile) in
                        tileView(tile)
                    }
                } header: {
                    StudyExerciseGroupHeader(title: group.title)
                }
            }
        }
    }

    private func tileView(_ tile: StudyExerciseTile) -> some View {
        let activity: StudyActivity? = tile.activity
        let isStarting: Bool = activity != nil && activity == starting
        let isPaused: Bool = activity.map { (value: StudyActivity) -> Bool in paused.contains(value) } ?? false
        return StudyExerciseTileView(
            tile: tile,
            count: availability?.count(for: tile),
            needsWords: StudyExerciseTileView.needsWords(tile),
            isStarting: isStarting,
            isBusy: isBusy,
            isPaused: isPaused
        ) {
            if let activity {
                onOpen(activity)
            } else {
                onPictures()
            }
        }
    }
}

/// Nagłówek grupy w siatce.
private struct StudyExerciseGroupHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .fluentEyebrow()
            .foregroundStyle(Palette.inkSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Kafelek jednego ćwiczenia: ikona, nazwa, opis, liczba słów (dla słownictwa), znaczniki.
/// Bez szkła — zwykła powierzchnia z obrysem (treść przewijana).
private struct StudyExerciseTileView: View {
    let tile: StudyExerciseTile
    /// Liczba słów; `nil` — liczona albo kafelek nie zależy od słów.
    let count: Int?
    /// Kafelek słownictwa (pokazuje liczbę słów).
    let needsWords: Bool
    let isStarting: Bool
    let isBusy: Bool
    let isPaused: Bool
    let action: () -> Void

    private var isLocked: Bool { tile == .pictures && !PictureExercise.isEnabled }
    private var isEmpty: Bool { needsWords && count == 0 }
    private var isMuted: Bool { isLocked || isEmpty }
    private let shape = RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)

    var body: some View {
        Button(action: action) {
            StudyExerciseTileLabel(
                tile: tile,
                statusText: statusText,
                isMuted: isMuted,
                isLocked: isLocked,
                isStarting: isStarting,
                isPaused: isPaused
            )
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(Spacing.m)
            .background(isMuted ? Palette.surfaceMuted : Palette.surface, in: shape)
            .overlay {
                shape.strokeBorder(Palette.separator, lineWidth: 1)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabelText))
        .accessibilityValue(Text(statusText ?? ""))
        .accessibilityHint(Text(accessibilityHintText))
        .accessibilityAddTraits(.isButton)
    }

    /// Kafelki zasilane słowami ucznia.
    static func needsWords(_ tile: StudyExerciseTile) -> Bool {
        switch tile {
        case .activity(.singleType), .activity(.vocabulary): return true
        case .activity, .pictures: return false
        }
    }

    /// „12 słów”, „Brak słów — dotknij, by sprawdzić dlaczego”, „Liczę słowa…”; `nil` bez linii.
    private var statusText: String? {
        guard needsWords else { return nil }
        guard let count else { return "Liczę słowa…" }
        return count > 0 ? StudyPicturesCard.words(count) : "Brak słów — dotknij, by sprawdzić dlaczego"
    }

    private var accessibilityLabelText: String {
        if isLocked { return "\(tile.title), w budowie" }
        return isPaused ? "\(tile.title), przerwane" : tile.title
    }

    private var accessibilityHintText: String {
        if isLocked { return "Pokazuje informację o planowanych ilustracjach" }
        if isPaused { return "Pozwala dokończyć przerwaną sesję albo zacząć od nowa" }
        if isEmpty { return "Wyjaśnia, czego brakuje do tego ćwiczenia" }
        return tile.detail
    }
}

/// Zawartość kafelka (osobny widok — krótkie `body`).
private struct StudyExerciseTileLabel: View {
    let tile: StudyExerciseTile
    let statusText: String?
    let isMuted: Bool
    let isLocked: Bool
    let isStarting: Bool
    let isPaused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top) {
                Image(systemName: tile.systemImage)
                    .font(FluentFont.title)
                    .foregroundStyle(isMuted ? Palette.inkSecondary : Palette.accent)
                    .accessibilityHidden(true)
                Spacer(minLength: Spacing.xs)
                if isStarting {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                }
            }
            Text(tile.title)
                .font(FluentFont.headline)
                .foregroundStyle(isLocked ? Palette.inkSecondary : Palette.ink)
                .multilineTextAlignment(.leading)
            Text(tile.detail)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .multilineTextAlignment(.leading)
            if let statusText {
                Text(statusText)
                    .font(FluentFont.caption.weight(.semibold))
                    .foregroundStyle(isMuted ? Palette.inkSecondary : Palette.accent)
                    .multilineTextAlignment(.leading)
            }
            if isLocked {
                TagChip("W budowie", systemImage: "hammer", tone: .warning)
            }
            if isPaused {
                TagChip("Przerwane", systemImage: "pause.circle", tone: .accent)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Komunikat nad kafelkami (np. brak słów dla wybranego ćwiczenia) — widoczny przy siatce.
private struct StudyExerciseTypeNotice: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Palette.info)
                .accessibilityHidden(true)
            Text(message)
                .font(FluentFont.callout)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(FluentFont.footnote.weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(width: HitTarget.minimum, height: HitTarget.minimum)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Zamknij komunikat"))
        }
        .padding(Spacing.s)
        .fluentCardBackground(.tinted(.info), cornerRadius: Radius.medium)
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityNotification.Announcement(message).post()
        }
    }
}

private struct StudyExerciseTypesCardPreview: View {
    @State private var minutes = 5

    var body: some View {
        ScrollView {
            StudyExerciseTypesCard(
                minutes: $minutes,
                collection: nil,
                starting: nil,
                isBusy: false,
                notice: "„Zrozum ze słuchu” potrzebuje zdań z polskim tłumaczeniem.",
                paused: [.reading, .vocabulary(.mixed)],
                onOpen: { (_: StudyActivity) -> Void in },
                onPictures: {},
                onDismissNotice: {}
            )
            .padding(Spacing.screen)
        }
        .background(Palette.background)
    }
}

#Preview("Ćwiczenia") {
    StudyExerciseTypesCardPreview()
        .fluentPreviewEnvironment()
}
