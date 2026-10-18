import SwiftUI
import UIKit
import AVFoundation
import VisionKit

/// Czy skanowanie na żywo jest możliwe na tym urządzeniu i z obecnymi zgodami.
enum LiveScanAvailability: Hashable {
    /// Brak sprzętu (np. symulator, starszy iPhone) — tylko „Wybierz zdjęcie”.
    case unsupported
    /// Zgoda na aparat jeszcze nie była pytana.
    case needsPermission
    /// Użytkownik odmówił dostępu do aparatu.
    case denied
    /// Aparat ograniczony (np. Czas przed ekranem) lub chwilowo niedostępny.
    case unavailable
    case ready

    /// Odczyt bieżącego stanu (`DataScannerViewController.isSupported` / `isAvailable` + zgoda AVFoundation).
    @MainActor
    static func current() -> LiveScanAvailability {
        guard DataScannerViewController.isSupported else { return .unsupported }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            return .needsPermission
        case .denied:
            return .denied
        case .restricted:
            return .unavailable
        case .authorized:
            return DataScannerViewController.isAvailable ? .ready : .unavailable
        @unknown default:
            return DataScannerViewController.isAvailable ? .ready : .unavailable
        }
    }

    var messagePl: String {
        switch self {
        case .unsupported:
            return "To urządzenie nie obsługuje skanowania na żywo. Wybierz zdjęcie z tekstem — rozpoznamy je na urządzeniu."
        case .needsPermission:
            return "Skanowanie na żywo potrzebuje aparatu. Obraz jest analizowany na urządzeniu i nie jest zapisywany."
        case .denied:
            return "Brak dostępu do aparatu. Możesz go włączyć w Ustawieniach systemu albo wybrać zdjęcie z galerii."
        case .unavailable:
            return "Aparat jest teraz niedostępny (np. ograniczenia Czasu przed ekranem). Wybierz zdjęcie z galerii."
        case .ready:
            return "Dotknij podświetlonego tekstu albo użyj całego kadru."
        }
    }
}

/// Podgląd aparatu z wyróżnianiem tekstu (VisionKit `DataScannerViewController`).
/// - `onTap`: transkrypcja dotkniętego elementu (linia lub blok tekstu).
/// - `onVisibleTextChange`: transkrypcje wszystkich widocznych elementów (tylko gdy się zmienią).
/// - `onUnavailable`: skaner przestał działać (np. aparat zajęty, zgoda cofnięta).
struct LiveTextScannerView: UIViewControllerRepresentable {
    let onTap: (String) -> Void
    let onVisibleTextChange: ([String]) -> Void
    let onUnavailable: () -> Void

    func makeCoordinator() -> LiveTextScannerCoordinator {
        LiveTextScannerCoordinator(onTap: onTap, onVisibleTextChange: onVisibleTextChange, onUnavailable: onUnavailable)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: ["en-US"])],
            qualityLevel: .balanced,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onVisibleTextChange = onVisibleTextChange
        context.coordinator.onUnavailable = onUnavailable
        context.coordinator.startIfNeeded(scanner)
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: LiveTextScannerCoordinator) {
        scanner.stopScanning()
        coordinator.didStart = false
    }
}

/// Delegat skanera. `DataScannerViewControllerDelegate` jest `@MainActor`.
@MainActor
final class LiveTextScannerCoordinator: NSObject, DataScannerViewControllerDelegate {
    var onTap: (String) -> Void
    var onVisibleTextChange: ([String]) -> Void
    var onUnavailable: () -> Void
    var didStart = false
    private var lastVisible: [String] = []

    init(onTap: @escaping (String) -> Void, onVisibleTextChange: @escaping ([String]) -> Void, onUnavailable: @escaping () -> Void) {
        self.onTap = onTap
        self.onVisibleTextChange = onVisibleTextChange
        self.onUnavailable = onUnavailable
    }

    /// Pierwsza aktualizacja może nastąpić, zanim widok trafi do okna — wtedy jedna ponowna próba
    /// po chwili; dopiero druga porażka zgłasza niedostępność.
    func startIfNeeded(_ scanner: DataScannerViewController) {
        guard !didStart, !isRetrying else { return }
        do {
            try scanner.startScanning()
            didStart = true
        } catch {
            isRetrying = true
            Task { @MainActor [weak self, weak scanner] in
                try? await Task.sleep(for: .milliseconds(400))
                guard let self else { return }
                self.isRetrying = false
                guard let scanner, !self.didStart else { return }
                do {
                    try scanner.startScanning()
                    self.didStart = true
                } catch {
                    self.onUnavailable()
                }
            }
        }
    }

    private var isRetrying = false

    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        if case .text(let text) = item {
            onTap(text.transcript)
        }
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        publish(allItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        publish(allItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        publish(allItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
        didStart = false
        onUnavailable()
    }

    /// Geometria zmienia się co klatkę — do SwiftUI wysyłamy tylko zmianę zestawu tekstów.
    private func publish(_ items: [RecognizedItem]) {
        var texts: [String] = []
        for item in items {
            if case .text(let text) = item {
                texts.append(text.transcript)
            }
        }
        guard texts != lastVisible else { return }
        lastVisible = texts
        onVisibleTextChange(texts)
    }
}
