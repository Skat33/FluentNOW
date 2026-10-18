import SwiftUI
import FluentKit

/// Stan zdjęć do trybu „Słowa i obrazki” (H2), liczony poza głównym wątkiem.
struct StudyPicturesSnapshot: Sendable, Equatable {
    /// Znaczenia, które da się pokazać na zdjęciu (konkretne rzeczowniki).
    var picturable: Int
    /// Znaczenia ze zdjęciem na dysku.
    var cached: Int
    /// Znaczenia gotowe do ćwiczenia (zdjęcie + trzy wyraźnie różne zdjęcia-dystraktory).
    var ready: Int

    @MainActor
    static func make(store: LearningStore, images: WordImageService) async -> StudyPicturesSnapshot {
        let cachedIDs = await images.cachedMeaningIDs()
        // Words marked „bez zdjęcia” (excluded or nothing verified) do not count as waiting.
        let unavailable = await images.unavailableMeaningIDs()
        return await store.compute { (state: LearnerState) -> StudyPicturesSnapshot in
            StudyPicturesSnapshot(
                picturable: PictureExercise.pendingCount(state: state, excluding: unavailable),
                cached: PictureExercise.cachedItems(state: state, cached: cachedIDs).count,
                ready: PictureExercise.readyMeaningIDs(state: state, cached: cachedIDs).count
            )
        }
    }
}

/// Karta „Słowa i obrazki” na ekranie Nauka: ile słów ma już zdjęcia, postęp pobierania,
/// komunikat bez internetu i start trybu (same zadania „Słowo i zdjęcie”).
struct StudyPicturesCard: View {
    let snapshot: StudyPicturesSnapshot?
    let status: WordImagePrefetcher.Status
    let statusText: String
    let isStarting: Bool
    let onStart: () -> Void

    var body: some View {
        Card(spacing: Spacing.m) {
            SectionHeader(StudyMode.pictures.namePl, subtitle: subtitle)
            if let snapshot, snapshot.picturable > 0 {
                StudyPicturesProgress(snapshot: snapshot)
            }
            if !statusText.isEmpty {
                StudyPicturesStatusLine(status: status, text: statusText)
            }
            SecondaryButton("Ćwicz ze zdjęciami", systemImage: StudyMode.pictures.studySystemImage, isLoading: isStarting, action: onStart)
                .disabled((snapshot?.ready ?? 0) == 0)
        }
    }

    private var subtitle: String {
        guard let snapshot else { return "Angielskie słowo i cztery zdjęcia — wskaż właściwe." }
        if snapshot.picturable == 0 {
            return "Dodaj słowa z tematów o rzeczach (np. jedzenie, dom, zwierzęta) — do nich dobierzemy zdjęcia."
        }
        if snapshot.ready == 0 {
            return "Zdjęcia jeszcze się pobierają — ćwiczenie ruszy, gdy będą gotowe co najmniej \(PictureExercise.optionCount) różne."
        }
        return "Gotowe do ćwiczenia: \(StudyPicturesCard.words(snapshot.ready)). Angielskie słowo i cztery zdjęcia."
    }

    /// „1 słowo”, „3 słowa”, „5 słów”.
    static func words(_ count: Int) -> String {
        let lastTwo = count % 100
        let last = count % 10
        if count == 1 { return "1 słowo" }
        if (2...4).contains(last) && !(12...14).contains(lastTwo) { return "\(count) słowa" }
        return "\(count) słów"
    }
}

/// „Zdjęcia: 12 z 40 słów” + pasek.
private struct StudyPicturesProgress: View {
    let snapshot: StudyPicturesSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("Zdjęcia: \(min(snapshot.cached, snapshot.picturable)) z \(StudyPicturesCard.words(snapshot.picturable))")
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
            LinearProgressBar(progress: progress)
        }
        .accessibilityElement(children: .combine)
    }

    private var progress: Double {
        guard snapshot.picturable > 0 else { return 0 }
        return min(1, Double(snapshot.cached) / Double(snapshot.picturable))
    }
}

/// Pobieranie w tle / brak internetu / przerwa serwisu.
private struct StudyPicturesStatusLine: View {
    let status: WordImagePrefetcher.Status
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
            switch status {
            case .working:
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            case .offline:
                Image(systemName: "wifi.slash")
                    .foregroundStyle(Palette.warning)
                    .accessibilityHidden(true)
            case .waiting, .disabled, .idle:
                Image(systemName: "clock")
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
