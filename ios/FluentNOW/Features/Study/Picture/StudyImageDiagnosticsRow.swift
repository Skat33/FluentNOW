import SwiftUI
import FluentKit

/// Diagnostyka zdjęć „Słowo i zdjęcie” (H2) — jeden wiersz w Ustawieniach → „Twoje dane należą do
/// Ciebie”: ile słów ma zdjęcie, ile czeka w kolejce, stan pobierania i ostatni błąd.
struct StudyImageDiagnosticsRow: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store
    @State private var info: StudyImageDiagnosticsInfo?

    var body: some View {
        let prefetcher = WordImagePrefetcher.shared(store: store, images: env.images)
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Zdjęcia do ćwiczeń")
                ForEach(lines(status: prefetcher.statusText), id: \.self) { (line: String) in
                    Text(line)
                        .font(FluentFont.footnote)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } icon: {
            Image(systemName: "photo.on.rectangle")
        }
        .accessibilityElement(children: .combine)
        .task(id: refreshKey(prefetcher)) {
            info = await StudyImageDiagnosticsInfo.load(store: store, images: env.images)
        }
    }

    /// Odświeżenie po zmianie słów, nowych zdjęciach albo końcu serii pobierania.
    private func refreshKey(_ prefetcher: WordImagePrefetcher) -> String {
        let stop = prefetcher.lastStop.map { (value: WordImagePrefetchReport.Stop) -> String in String(describing: value) } ?? "-"
        return "\(store.revision)|\(prefetcher.cachedCount)|\(stop)|\(prefetcher.statusText)"
    }

    private func lines(status: String) -> [String] {
        guard let info else { return ["Sprawdzam…"] }
        var result = [
            "Ze zdjęciem: \(StudyPicturesCard.words(info.diagnostics.cachedCount)) · w kolejce: \(info.queued) · bez pasującego zdjęcia: \(info.diagnostics.emptyCount)",
            Self.verificationLine(info.diagnostics),
            "Dziś: \(info.diagnostics.searchesToday) z \(WordImageService.maxSearchesPerDay) wyszukiwań, \(info.diagnostics.downloadsToday) pobrań"
        ]
        if !info.diagnostics.networkEnabled {
            result.append("Pobieranie wyłączone (podgląd).")
        }
        if !status.isEmpty {
            result.append(status)
        }
        if info.diagnostics.lastRunAt > 0 {
            let date = Date(timeIntervalSince1970: info.diagnostics.lastRunAt / 1_000)
            result.append("Ostatnie pobieranie: \(date.formatted(date: .abbreviated, time: .shortened))")
        }
        if let error = info.diagnostics.lastError, !error.isEmpty {
            result.append("Ostatni błąd: \(error)")
        } else if info.diagnostics.lastRunAt > 0 {
            result.append("Ostatni błąd: brak")
        }
        if info.diagnostics.blockedUntil > FluentClock.now() {
            let until = Date(timeIntervalSince1970: info.diagnostics.blockedUntil / 1_000)
            result.append("Przerwa serwisu do \(until.formatted(date: .omitted, time: .shortened))")
        }
        return result
    }

    /// „Weryfikacja: odrzucone 12 · bez zdjęcia na stałe 40 · do sprawdzenia 3”.
    static func verificationLine(_ diagnostics: WordImageDiagnostics) -> String {
        var line = "Weryfikacja: odrzucone \(diagnostics.verificationRejections) · bez zdjęcia na stałe \(diagnostics.noPhotoCount)"
        if diagnostics.awaitingCheckCount > 0 {
            line += " · do sprawdzenia \(diagnostics.awaitingCheckCount)"
        }
        return line
    }
}

/// Liczby diagnostyki: z aktora zdjęć + kolejka liczona na migawce stanu (poza głównym wątkiem).
struct StudyImageDiagnosticsInfo: Sendable, Equatable {
    var diagnostics: WordImageDiagnostics
    /// Znaczenia, które da się pokazać na zdjęciu, a nie mają jeszcze zdjęcia ani pustego wyniku.
    var queued: Int

    @MainActor
    static func load(store: LearningStore, images: WordImageService) async -> StudyImageDiagnosticsInfo {
        let diagnostics = await images.diagnostics()
        let settled = await images.settledMeaningIDs()
        let queued = await store.compute { (state: LearnerState) -> Int in
            PictureExercise.pendingCount(state: state, excluding: settled)
        }
        return StudyImageDiagnosticsInfo(diagnostics: diagnostics, queued: queued)
    }
}
