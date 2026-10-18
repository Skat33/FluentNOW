import Foundation
import ImageIO
import Vision

/// Błędy rozpoznawania tekstu ze zdjęcia.
enum PhotoTextError: Error, LocalizedError {
    case unreadableImage
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Nie udało się odczytać zdjęcia. Spróbuj innego pliku."
        case .recognitionFailed(let detail):
            return "Nie udało się rozpoznać tekstu (\(detail))."
        }
    }
}

/// Rozpoznawanie tekstu ze zdjęcia z galerii: Vision `VNRecognizeTextRequest`, na urządzeniu,
/// bez sieci. Działa też na symulatorze. Wywoływać poza głównym wątkiem (`recognize` jest `async`
/// i sam przenosi pracę do `Task.detached`).
enum PhotoTextRecognizer {
    /// Większe zdjęcia są zmniejszane (z uwzględnieniem orientacji EXIF) — mniej pamięci, szybciej.
    static let maxPixelSize = 2400

    static func recognize(imageData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) { () throws -> String in
            guard let image = PhotoTextRecognizer.downscaledImage(imageData) else { throw PhotoTextError.unreadableImage }
            do {
                return try PhotoTextRecognizer.recognizeText(in: image, level: .accurate)
            } catch {
                // Część symulatorów / starszych urządzeń nie ma modelu „accurate” — próba „fast”.
                return try PhotoTextRecognizer.recognizeText(in: image, level: .fast)
            }
        }.value
    }

    /// Miniatura z zastosowaną orientacją (`kCGImageSourceCreateThumbnailWithTransform`), więc
    /// Vision dostaje obraz „do góry”.
    private static func downscaledImage(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func recognizeText(in image: CGImage, level: VNRequestTextRecognitionLevel) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw PhotoTextError.recognitionFailed(error.localizedDescription)
        }
        let observations: [VNRecognizedTextObservation] = request.results ?? []
        let lines: [String] = observations.compactMap { (observation: VNRecognizedTextObservation) -> String? in
            observation.topCandidates(1).first?.string
        }
        return lines.joined(separator: "\n")
    }
}
