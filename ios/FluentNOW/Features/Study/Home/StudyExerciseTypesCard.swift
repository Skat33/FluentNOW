import SwiftUI
import FluentKit

/// „Ćwicz wybrany typ” (FEEDBACK-5 J1): kafelek dla każdego typu ćwiczenia słówek → krótka sesja
/// (5 / 10 min) tylko z tym typem (`SingleTypeSession`): najpierw słowa do powtórki, potem znane,
/// na końcu nowe. Kafelek pokazuje, dla ilu słów da się zbudować ćwiczenie (liczone poza głównym
/// wątkiem); bez słów dotknięcie wyjaśnia, czego brakuje. „Słowo i zdjęcie” — wyszarzone „W budowie”.
struct StudyExerciseTypesCard: View {
    @Binding var minutes: Int
    let collection: String?
    let startingType: ExerciseType?
    let notice: String?
    let onStart: (ExerciseType) -> Void
    let onPictures: () -> Void
    let onDismissNotice: () -> Void

    @Environment(LearningStore.self) private var store
    @State private var availability: SingleTypeAvailability?

    var body: some View {
        Card(spacing: Spacing.m) {
            SectionHeader("Ćwicz wybrany typ", subtitle: subtitle)
            StudyExerciseMinutesPicker(minutes: $minutes)
            StudyExerciseTypeGrid(
                availability: availability,
                startingType: startingType,
                onStart: onStart,
                onPictures: onPictures
            )
            if let notice {
                StudyExerciseTypeNotice(message: notice, onDismiss: onDismissNotice)
            }
        }
        .task(id: availabilityKey) { await updateAvailability() }
    }

    private var subtitle: String {
        let base = "Krótka sesja z jednym rodzajem ćwiczenia: najpierw słowa do powtórki, potem znane, na końcu nowe."
        guard let collection, !collection.isEmpty else { return base }
        return base + " Kolekcja: „\(collection)”."
    }

    private var availabilityKey: String {
        "\(store.revision)|\(collection ?? "")|\(store.loadPhase == .ready)"
    }

    /// Liczba słów dla każdego typu — na migawce stanu, poza głównym wątkiem.
    private func updateAvailability() async {
        guard store.loadPhase == .ready else { return }
        let limitedTo = collection
        let computed = await store.compute { (state: LearnerState) -> SingleTypeAvailability in
            SingleTypeSession.availability(state: state, collection: limitedTo)
        }
        guard !Task.isCancelled else { return }
        availability = computed
    }
}

/// 5 / 10 minut.
private struct StudyExerciseMinutesPicker: View {
    @Binding var minutes: Int

    var body: some View {
        Picker("Długość sesji jednego typu", selection: $minutes) {
            ForEach(SingleTypeSession.durations, id: \.self) { (value: Int) in
                Text("\(value) minut").tag(value)
            }
        }
        .pickerStyle(.segmented)
        .fluentSensoryFeedback(FluentHaptic.selection, trigger: minutes)
    }
}

/// Siatka kafelków typów (+ „Słowo i zdjęcie”).
private struct StudyExerciseTypeGrid: View {
    let availability: SingleTypeAvailability?
    let startingType: ExerciseType?
    let onStart: (ExerciseType) -> Void
    let onPictures: () -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: Spacing.s)], spacing: Spacing.s) {
            ForEach(SingleTypeSession.types, id: \.self) { (type: ExerciseType) in
                StudyExerciseTypeTile(
                    type: type,
                    count: availability?.count(for: type),
                    isStarting: startingType == type,
                    isBusy: startingType != nil
                ) {
                    onStart(type)
                }
            }
            StudyExercisePictureTile(action: onPictures)
        }
    }
}

/// Kafelek jednego typu: ikona, nazwa, opis i liczba dostępnych słów.
private struct StudyExerciseTypeTile: View {
    let type: ExerciseType
    /// `nil` — jeszcze liczone.
    let count: Int?
    let isStarting: Bool
    let isBusy: Bool
    let action: () -> Void

    private var isEmpty: Bool { count == 0 }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .top) {
                    Image(systemName: type.practiceSystemImage)
                        .font(FluentFont.title)
                        .foregroundStyle(isEmpty ? Palette.inkSecondary : Palette.accent)
                        .accessibilityHidden(true)
                    Spacer(minLength: Spacing.xs)
                    if isStarting {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityHidden(true)
                    }
                }
                Text(type.practiceTitle)
                    .font(FluentFont.headline)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(type.practiceDescription)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.leading)
                Text(countText)
                    .font(FluentFont.caption.weight(.semibold))
                    .foregroundStyle(isEmpty ? Palette.inkSecondary : Palette.accent)
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
            .opacity(isEmpty ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(type.practiceTitle))
        .accessibilityValue(Text(countText))
        .accessibilityHint(Text(isEmpty ? "Wyjaśnia, czego brakuje do tego ćwiczenia" : type.practiceDescription))
        .accessibilityAddTraits(.isButton)
    }

    private var countText: String {
        guard let count else { return "Liczę słowa…" }
        return StudySingleTypeText.availability(count)
    }
}

/// „Słowo i zdjęcie”: wyszarzone „W budowie” (I2), dotknięcie — krótka informacja; po
/// odblokowaniu (`PictureExercise.isEnabled`) uruchamia tryb „Słowa i obrazki”.
private struct StudyExercisePictureTile: View {
    let action: () -> Void

    private var locked: Bool { !PictureExercise.isEnabled }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Image(systemName: ExerciseType.picture.practiceSystemImage)
                    .font(FluentFont.title)
                    .foregroundStyle(locked ? Palette.inkTertiary : Palette.accent)
                    .accessibilityHidden(true)
                Text(ExerciseType.picture.practiceTitle)
                    .font(FluentFont.headline)
                    .foregroundStyle(locked ? Palette.inkSecondary : Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(ExerciseType.picture.practiceDescription)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.inkSecondary)
                    .multilineTextAlignment(.leading)
                if locked {
                    TagChip("W budowie", systemImage: "hammer", tone: .warning)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .padding(Spacing.m)
            .background(locked ? Palette.surfaceMuted : Palette.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(Palette.separator, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(locked ? "\(ExerciseType.picture.practiceTitle), w budowie" : ExerciseType.picture.practiceTitle))
        .accessibilityHint(Text(locked ? "Pokazuje informację o planowanych ilustracjach" : ExerciseType.picture.practiceDescription))
        .accessibilityAddTraits(.isButton)
    }
}

/// Komunikat pod kafelkami (np. brak słów dla wybranego typu) — widoczny tuż przy kafelku.
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
                startingType: nil,
                notice: "„Zrozum ze słuchu” potrzebuje zdań z polskim tłumaczeniem.",
                onStart: { (_: ExerciseType) -> Void in },
                onPictures: {},
                onDismissNotice: {}
            )
            .padding(Spacing.screen)
        }
        .background(Palette.background)
    }
}

#Preview("Ćwicz wybrany typ") {
    StudyExerciseTypesCardPreview()
        .fluentPreviewEnvironment()
}
