import Foundation
import Observation
import AVFoundation
import Speech
import FluentKit

/// Wynik ćwiczenia wymowy. Nie wlicza się do opanowania (jak na stronie).
struct PronunciationResult: Equatable {
    let transcript: String
    let expected: String
    /// 0…1 — podobieństwo rozpoznanego tekstu do oczekiwanego (Levenshtein na znormalizowanym tekście).
    let similarity: Double
    let verdictPl: String
}

/// Błędy ćwiczenia wymowy (polskie komunikaty).
enum PronunciationError: Error, LocalizedError, Equatable {
    case permissionDenied
    case unavailable
    case alreadyListening
    case audio(String)
    case recognition(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Brak zgody na mikrofon lub rozpoznawanie mowy. Włączysz ją w Ustawieniach systemu → FluentNOW."
        case .unavailable:
            return "Rozpoznawanie mowy angielskiej jest teraz niedostępne na tym urządzeniu."
        case .alreadyListening:
            return "Słucham już Twojej odpowiedzi."
        case .audio(let detail):
            return "Nie udało się uruchomić mikrofonu: \(detail)"
        case .recognition(let detail):
            return "Rozpoznawanie mowy nie powiodło się: \(detail)"
        }
    }
}

/// Ćwiczenie wymowy: `SFSpeechRecognizer(en-US)`, na urządzeniu gdy to możliwe,
/// nagrywanie tylko po akcji użytkownika, nic nie jest zapisywane na dysk.
@MainActor
@Observable
final class PronunciationService {
    enum Permission {
        case unknown
        case granted
        case denied
        case unavailable
    }

    private(set) var permission: Permission = .unknown
    private(set) var isListening: Bool = false
    private(set) var liveTranscript: String = ""

    /// Maksymalny czas słuchania i cisza kończąca nagranie (sekundy).
    static let maxDuration: TimeInterval = 6
    static let silenceTimeout: TimeInterval = 1.3

    @ObservationIgnored private let recognizer: SFSpeechRecognizer?
    @ObservationIgnored private let enabled: Bool
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var continuation: CheckedContinuation<PronunciationResult, Error>?
    @ObservationIgnored private var expected = ""
    @ObservationIgnored private var maxTimer: Task<Void, Never>?
    @ObservationIgnored private var silenceTimer: Task<Void, Never>?
    @ObservationIgnored private var finalTimer: Task<Void, Never>?

    /// - Parameter enabled: `false` w podglądzie i testach (bez mikrofonu, `permission = .unavailable`).
    init(enabled: Bool = true) {
        self.enabled = enabled
        recognizer = enabled ? SFSpeechRecognizer(locale: Locale(identifier: "en-US")) : nil
        permission = enabled ? Self.currentPermission(recognizer: recognizer) : .unavailable
    }

    // MARK: - Zgody

    /// Prosi o zgodę na rozpoznawanie mowy i mikrofon (wołać tylko po akcji użytkownika).
    func requestPermission() async -> Permission {
        guard enabled, recognizer != nil else {
            permission = .unavailable
            return permission
        }
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            permission = speechStatus == .restricted ? .unavailable : .denied
            return permission
        }
        let microphone = await AVAudioApplication.requestRecordPermission()
        permission = microphone ? .granted : .denied
        return permission
    }

    private static func currentPermission(recognizer: SFSpeechRecognizer?) -> Permission {
        guard recognizer != nil else { return .unavailable }
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            return .unknown
        case .denied:
            return .denied
        case .restricted:
            return .unavailable
        case .authorized:
            switch AVAudioApplication.shared.recordPermission {
            case .granted: return .granted
            case .denied: return .denied
            case .undetermined: return .unknown
            @unknown default: return .unknown
            }
        @unknown default:
            return .unknown
        }
    }

    // MARK: - Słuchanie

    /// Nagrywa i rozpoznaje wypowiedź. Kończy się sama po ciszy lub po 6 s; `stop()` kończy wcześniej.
    func listen(expected: String) async throws -> PronunciationResult {
        guard enabled, let recognizer else { throw PronunciationError.unavailable }
        guard !isListening, continuation == nil else { throw PronunciationError.alreadyListening }
        if permission != .granted {
            permission = Self.currentPermission(recognizer: recognizer)
        }
        guard permission == .granted else { throw PronunciationError.permissionDenied }
        guard recognizer.isAvailable else { throw PronunciationError.unavailable }

        self.expected = expected
        liveTranscript = ""

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            throw PronunciationError.audio(error.localizedDescription)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            deactivateSession()
            throw PronunciationError.audio("Brak dostępnego mikrofonu.")
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(for: request))
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            deactivateSession()
            throw PronunciationError.audio(error.localizedDescription)
        }

        self.engine = engine
        self.request = request
        isListening = true

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<PronunciationResult, Error>) in
            self.continuation = continuation
            let sink: @Sendable (String?, Bool, String?) -> Void = { [weak self] text, isFinal, message in
                Task { @MainActor in
                    self?.handle(text: text, isFinal: isFinal, errorMessage: message)
                }
            }
            self.task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(sink))
            self.maxTimer = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(PronunciationService.maxDuration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.stopRecording()
            }
        }
    }

    /// Kończy nagrywanie wcześniej — `listen` zwraca to, co zdążyło zostać rozpoznane.
    func stop() {
        stopRecording()
    }

    // MARK: - Implementacja

    /// Blok nagrania tworzony poza kontekstem `@MainActor` — wywoływany na wątku audio.
    nonisolated private static func tapBlock(for request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        return { buffer, _ in
            request.append(buffer)
        }
    }

    /// Obsługa wyników tworzona poza `@MainActor` — Speech wywołuje ją na własnej kolejce.
    nonisolated private static func resultHandler(
        _ sink: @escaping @Sendable (String?, Bool, String?) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        return { result, error in
            sink(result?.bestTranscription.formattedString, result?.isFinal ?? false, error?.localizedDescription)
        }
    }

    private func handle(text: String?, isFinal: Bool, errorMessage: String?) {
        guard continuation != nil else { return }
        if let text, !text.isEmpty {
            liveTranscript = text
            restartSilenceTimer()
        }
        if isFinal {
            complete()
            return
        }
        if errorMessage != nil {
            // Częsty przypadek: „No speech detected” — zwracamy pusty wynik zamiast błędu.
            complete()
        }
    }

    private func restartSilenceTimer() {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(PronunciationService.silenceTimeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.stopRecording()
        }
    }

    /// Zatrzymuje mikrofon; rozpoznawanie kończy się wynikiem końcowym (albo po 1,5 s zapasu).
    private func stopRecording() {
        maxTimer?.cancel()
        silenceTimer?.cancel()
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        engine = nil
        request?.endAudio()
        if isListening {
            isListening = false
            deactivateSession()
        }
        guard continuation != nil, finalTimer == nil else { return }
        finalTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.complete()
        }
    }

    private func complete() {
        guard let continuation else { return }
        self.continuation = nil
        stopRecording()
        finalTimer?.cancel()
        finalTimer = nil
        task?.cancel()
        task = nil
        request = nil
        let result = Self.evaluate(transcript: liveTranscript, expected: expected)
        continuation.resume(returning: result)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - Ocena

    /// Porównanie rozpoznanego tekstu z oczekiwanym. Uczciwie: rozpoznawanie mowy nie jest
    /// egzaminatorem, więc werdykt mówi o tym, co usłyszało urządzenie.
    nonisolated static func evaluate(transcript: String, expected: String) -> PronunciationResult {
        let heard = comparable(transcript)
        let target = comparable(expected)
        let similarity: Double
        if heard.isEmpty || target.isEmpty {
            similarity = 0
        } else {
            let distance = TextNormalizer.levenshtein(heard, target)
            let length = max(heard.count, target.count)
            similarity = max(0, min(1, 1 - Double(distance) / Double(max(1, length))))
        }
        return PronunciationResult(
            transcript: transcript,
            expected: expected,
            similarity: similarity,
            verdictPl: verdict(similarity: similarity, transcript: transcript)
        )
    }

    nonisolated static func verdict(similarity: Double, transcript: String) -> String {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Nic nie usłyszałem. Mów wyraźnie, bliżej mikrofonu, i spróbuj jeszcze raz."
        }
        if similarity >= 0.9 {
            return "Świetnie! Urządzenie rozpoznało dokładnie to, co trzeba."
        }
        if similarity >= 0.7 {
            return "Prawie. Rozpoznano: „\(trimmed)”. Posłuchaj wzoru i powtórz jeszcze raz."
        }
        return "Rozpoznano coś innego: „\(trimmed)”. Posłuchaj wolnego nagrania i spróbuj ponownie."
    }

    /// Małe litery, bez interpunkcji, pojedyncze spacje.
    nonisolated static func comparable(_ text: String) -> String {
        let lowered = TextNormalizer.normalize(text.replacingOccurrences(of: "’", with: "'"))
        let kept = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.letters.contains(scalar) || CharacterSet.decimalDigits.contains(scalar) || scalar == "'" ? Character(scalar) : " "
        }
        return String(kept).split(separator: " ").joined(separator: " ")
    }
}
