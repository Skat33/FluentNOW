import Foundation
import Vision
import CoreML

/// Classifies photos on the device (layer 2 of the verification). Injected into
/// `WordImageService` so tests use a stub with fixed labels.
protocol WordImageClassifying: Sendable {
    /// Labels of a JPEG/PNG photo, strongest first; `nil` when the photo cannot be classified
    /// (broken data, Vision unavailable) — the service then decides from the title and tags only.
    func labels(for imageData: Data) async -> [WordImageLabel]?
    /// Identifiers the classifier can report; `nil` when unknown.
    func taxonomy() async -> Set<String>?
}

/// Vision's built-in image classifier (`VNClassifyImageRequest`, iOS 13+; revision 2 on iOS 17+,
/// 1 303 identifiers). Offline, no keys. Work runs on a private utility queue — never on the main
/// thread and never blocking the photo actor's executor.
struct VisionImageClassifier: WordImageClassifying {
    /// Labels below this confidence are noise (the request returns all 1 303 with scores).
    static let minimumConfidence: Float = 0.05
    /// Labels kept for the decision.
    static let maximumLabels = 25

    private static let queue = DispatchQueue(label: "pl.fluentnow.image-classifier", qos: .utility)

    func labels(for imageData: Data) async -> [WordImageLabel]? {
        await withCheckedContinuation { (continuation: CheckedContinuation<[WordImageLabel]?, Never>) in
            Self.queue.async {
                continuation.resume(returning: Self.classify(imageData))
            }
        }
    }

    func taxonomy() async -> Set<String>? {
        await withCheckedContinuation { (continuation: CheckedContinuation<Set<String>?, Never>) in
            Self.queue.async {
                continuation.resume(returning: Self.supportedIdentifiers())
            }
        }
    }

    /// Synchronous classification (call on `queue` only).
    static func classify(_ data: Data) -> [WordImageLabel]? {
        guard !data.isEmpty else { return nil }
        let request = makeRequest()
        let handler = VNImageRequestHandler(data: data, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observations = request.results else { return nil }
        let strong = observations
            .filter { (observation: VNClassificationObservation) -> Bool in observation.confidence >= minimumConfidence }
            .sorted { (lhs: VNClassificationObservation, rhs: VNClassificationObservation) -> Bool in lhs.confidence > rhs.confidence }
            .prefix(maximumLabels)
        return strong.map { (observation: VNClassificationObservation) -> WordImageLabel in
            WordImageLabel(identifier: observation.identifier, confidence: Double(observation.confidence))
        }
    }

    /// `supportedIdentifiers()` of the current request revision (iOS 15+).
    static func supportedIdentifiers() -> Set<String>? {
        let request = makeRequest()
        guard let identifiers = try? request.supportedIdentifiers(), !identifiers.isEmpty else { return nil }
        return Set(identifiers)
    }

    private static func makeRequest() -> VNClassifyImageRequest {
        let request = VNClassifyImageRequest()
        #if targetEnvironment(simulator)
        // The simulator has no Neural Engine; run the model on the CPU (iOS 17+ API).
        let cpu = MLComputeDevice.allComputeDevices.first { (device: MLComputeDevice) -> Bool in
            if case .cpu = device { return true }
            return false
        }
        if let cpu {
            request.setComputeDevice(cpu, for: .main)
        }
        #endif
        return request
    }
}
