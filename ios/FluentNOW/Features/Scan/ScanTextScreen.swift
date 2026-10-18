import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import FluentKit

/// Stan listy słów z zeskanowanego tekstu.
enum ScanPhase: Hashable {
    case idle
    case analyzing
    case empty
    case results([ScannedWord])
}

/// „Skanuj tekst” (I3): aparat na żywo (VisionKit, z wyróżnianiem tekstu) albo zdjęcie z galerii
/// (Vision OCR, działa też na symulatorze) → lista słów w formie bazowej z oznaczeniem
/// „Masz już” / „W bazie” → dotknięcie słowa wywołuje `onPick(hasło)` i zamyka ekran.
///
/// `text` to rozpoznany tekst — wiązanie, żeby po powrocie do skanera lista była nadal widoczna
/// (np. kilka słów z jednej strony po kolei). Ekran ma WŁASNY `NavigationStack` (prezentowany jako arkusz).
struct ScanTextScreen: View {
    @Binding var text: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @Environment(LearningStore.self) private var store

    @State private var availability: LiveScanAvailability = .unsupported
    @State private var visibleTexts: [String] = []
    @State private var phase: ScanPhase = .idle
    @State private var photoItem: PhotosPickerItem?
    @State private var isReadingPhoto = false
    @State private var photoError: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Skanuj tekst")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .onAppear { availability = LiveScanAvailability.current() }
        .task(id: text) { await analyze() }
        .onChange(of: photoItem) { (_: PhotosPickerItem?, newValue: PhotosPickerItem?) in
            Task { await loadPhoto(newValue) }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScanSourceSection(
                availability: availability,
                visibleCount: visibleTexts.count,
                photoItem: $photoItem,
                isReadingPhoto: isReadingPhoto,
                photoError: photoError,
                onTap: handleTap,
                onVisibleTextChange: { (texts: [String]) in visibleTexts = texts },
                onUnavailable: { availability = .unavailable },
                onUseFrame: useWholeFrame,
                onRequestCamera: { Task { await requestCamera() } }
            )
            ScanResultsList(phase: phase, onPick: pick)
        }
        .background(Palette.background)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Zamknij") { dismiss() }
        }
        if !text.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                Button("Wyczyść") { text = "" }
            }
        }
    }

    // MARK: Akcje

    private func pick(_ term: String) {
        onPick(term)
        dismiss()
    }

    /// Dotknięcie w podglądzie: jedno słowo → od razu szybkie dodawanie; linia → jej słowa na liście.
    private func handleTap(_ transcript: String) {
        if let lemma = TextScanAnalyzer.singleLemma(in: transcript) {
            pick(lemma)
        } else {
            text = transcript
        }
    }

    private func useWholeFrame() {
        guard !visibleTexts.isEmpty else { return }
        text = visibleTexts.joined(separator: "\n")
    }

    private func requestCamera() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        availability = LiveScanAvailability.current()
    }

    private func analyze() async {
        let current = text
        guard !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .idle
            return
        }
        phase = .analyzing
        let tokens: [ScannedToken] = await Task.detached(priority: .userInitiated) { () -> [ScannedToken] in
            TextScanAnalyzer.tokens(in: current)
        }.value
        guard !Task.isCancelled else { return }
        let owned: OwnedVocabulary = await store.compute { (state: LearnerState) -> OwnedVocabulary in
            OwnedVocabulary(state)
        }
        let words: [ScannedWord] = await TextScanClassifier.classify(tokens, owned: owned, content: env.content)
        guard !Task.isCancelled else { return }
        phase = words.isEmpty ? .empty : .results(words)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isReadingPhoto = true
        photoError = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoTextError.unreadableImage
            }
            let recognized = try await PhotoTextRecognizer.recognize(imageData: data)
            if recognized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                photoError = "Na zdjęciu nie znaleziono tekstu. Spróbuj wyraźniejszego zdjęcia."
            } else {
                text = recognized
            }
        } catch {
            photoError = error.localizedDescription
        }
        isReadingPhoto = false
        photoItem = nil
    }
}

/// Źródło tekstu: aparat (lub komunikat, dlaczego go nie ma) i wybór zdjęcia.
private struct ScanSourceSection: View {
    let availability: LiveScanAvailability
    let visibleCount: Int
    @Binding var photoItem: PhotosPickerItem?
    let isReadingPhoto: Bool
    let photoError: String?
    let onTap: (String) -> Void
    let onVisibleTextChange: ([String]) -> Void
    let onUnavailable: () -> Void
    let onUseFrame: () -> Void
    let onRequestCamera: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ScanCameraArea(
                availability: availability,
                visibleCount: visibleCount,
                onTap: onTap,
                onVisibleTextChange: onVisibleTextChange,
                onUnavailable: onUnavailable,
                onUseFrame: onUseFrame,
                onRequestCamera: onRequestCamera
            )
            ScanPhotoButton(photoItem: $photoItem, isReadingPhoto: isReadingPhoto)
            if let photoError {
                Text(photoError)
                    .font(FluentFont.footnote)
                    .foregroundStyle(Palette.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: Spacing.readableWidth)
        .padding(.horizontal, Spacing.screen)
        .padding(.vertical, Spacing.s)
        .frame(maxWidth: .infinity)
    }
}

private struct ScanCameraArea: View {
    let availability: LiveScanAvailability
    let visibleCount: Int
    let onTap: (String) -> Void
    let onVisibleTextChange: ([String]) -> Void
    let onUnavailable: () -> Void
    let onUseFrame: () -> Void
    let onRequestCamera: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch availability {
        case .ready:
            ScanLivePreview(
                visibleCount: visibleCount,
                onTap: onTap,
                onVisibleTextChange: onVisibleTextChange,
                onUnavailable: onUnavailable,
                onUseFrame: onUseFrame
            )
        case .needsPermission:
            ScanMessageCard(message: availability.messagePl, systemImage: "camera") {
                PrimaryButton("Włącz aparat", systemImage: "camera", action: onRequestCamera)
            }
        case .denied:
            ScanMessageCard(message: availability.messagePl, systemImage: "camera.badge.ellipsis") {
                SecondaryButton("Otwórz Ustawienia systemu", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                }
            }
        case .unsupported, .unavailable:
            ScanMessageCard(message: availability.messagePl, systemImage: "text.viewfinder") {
                EmptyView()
            }
        }
    }
}

/// Podgląd aparatu z przyciskiem „Użyj całego kadru”.
private struct ScanLivePreview: View {
    let visibleCount: Int
    let onTap: (String) -> Void
    let onVisibleTextChange: ([String]) -> Void
    let onUnavailable: () -> Void
    let onUseFrame: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            LiveTextScannerView(onTap: onTap, onVisibleTextChange: onVisibleTextChange, onUnavailable: onUnavailable)
                .frame(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .accessibilityLabel(Text("Podgląd aparatu"))
                .accessibilityHint(Text("Dotknij podświetlonego tekstu, aby dodać jego słowa"))
            Text(LiveScanAvailability.ready.messagePl)
                .font(FluentFont.footnote)
                .foregroundStyle(Palette.inkSecondary)
            SecondaryButton(visibleCount > 0 ? "Użyj całego kadru (\(visibleCount))" : "Użyj całego kadru",
                            systemImage: "text.viewfinder", action: onUseFrame)
                .disabled(visibleCount == 0)
        }
    }
}

private struct ScanMessageCard<Action: View>: View {
    let message: String
    let systemImage: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        Card(style: .muted) {
            Label {
                Text(message)
                    .font(FluentFont.subheadline)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(Palette.accent)
            }
            action()
        }
    }
}

private struct ScanPhotoButton: View {
    @Binding var photoItem: PhotosPickerItem?
    let isReadingPhoto: Bool

    var body: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            HStack(spacing: Spacing.xs) {
                if isReadingPhoto {
                    ProgressView()
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .accessibilityHidden(true)
                }
                Text(isReadingPhoto ? "Rozpoznaję tekst…" : "Wybierz zdjęcie z tekstem")
            }
            .frame(maxWidth: .infinity)
        }
        .fluentButtonStyle(.secondary)
        .disabled(isReadingPhoto)
    }
}

/// Lista słów z tekstu.
private struct ScanResultsList: View {
    let phase: ScanPhase
    let onPick: (String) -> Void

    var body: some View {
        switch phase {
        case .idle:
            ScanHint(text: "Zeskanuj stronę książki, menu albo napis — pokażemy słowa w formie podstawowej. Dotknij słowa, żeby je dodać.")
        case .analyzing:
            ProgressView("Szukam słów…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ScanHint(text: "Nie znaleziono angielskich słów. Spróbuj wyraźniejszego ujęcia lub innego fragmentu.")
        case .results(let words):
            ScanWordList(words: words, onPick: onPick)
        }
    }
}

private struct ScanHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(FluentFont.subheadline)
            .foregroundStyle(Palette.inkSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct ScanWordList: View {
    let words: [ScannedWord]
    let onPick: (String) -> Void

    private var newCount: Int { words.filter { $0.status != .owned }.count }
    private var ownedCount: Int { words.count - newCount }

    var body: some View {
        List {
            Section {
                ForEach(words) { (word: ScannedWord) in
                    Button {
                        onPick(word.lemma)
                    } label: {
                        ScanWordRow(word: word)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Do dodania: \(newCount) · Masz już: \(ownedCount)")
            } footer: {
                Text("Słowa są w formie podstawowej (np. „went” → „go”). Dotknij, aby otworzyć szybkie dodawanie.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

private struct ScanWordRow: View {
    let word: ScannedWord

    var body: some View {
        HStack(spacing: Spacing.s) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.lemma)
                    .font(FluentFont.bodyEmphasized)
                    .foregroundStyle(Palette.ink)
                if word.showsSurface {
                    Text("w tekście: \(word.surface)")
                        .font(FluentFont.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
            }
            Spacer(minLength: Spacing.xs)
            ScanStatusChip(status: word.status)
            Image(systemName: "plus.circle")
                .foregroundStyle(word.status == .owned ? Palette.inkTertiary : Palette.accent)
                .accessibilityHidden(true)
        }
        .frame(minHeight: HitTarget.minimum)
        .contentShape(Rectangle())
        .ownedVocabularyDimmed(word.status == .owned)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Otwiera szybkie dodawanie"))
    }
}

private struct ScanStatusChip: View {
    let status: ScannedWordStatus

    var body: some View {
        switch status {
        case .owned:
            OwnedVocabularyBadge()
        case .inBase:
            TagChip("W bazie", systemImage: "books.vertical", tone: .info)
        case .unknown:
            TagChip("Spoza bazy", tone: .neutral)
        }
    }
}
