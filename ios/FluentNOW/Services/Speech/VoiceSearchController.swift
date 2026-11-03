import Foundation
import Observation
import AVFoundation
import Speech

/// Język dyktowania w polach wyszukiwania (FEEDBACK-9 N3).
enum VoiceSearchLanguage: String, CaseIterable, Identifiable, Hashable {
    case english = "en-US"
    case polish = "pl-PL"

    var id: String { rawValue }

    /// „EN” / „PL” — etykieta przełącznika.
    var shortLabel: String {
        switch self {
        case .english: return "EN"
        case .polish: return "PL"
        }
    }

    /// „angielski” / „polski”.
    var namePl: String {
        switch self {
        case .english: return "angielski"
        case .polish: return "polski"
        }
    }

    /// „po angielsku” / „po polsku”.
    var adverbPl: String {
        switch self {
        case .english: return "po angielsku"
        case .polish: return "po polsku"
        }
    }

    /// Drugi język (przełącznik EN ↔ PL).
    var toggled: VoiceSearchLanguage {
        switch self {
        case .english: return .polish
        case .polish: return .english
        }
    }
}

/// Etap wyszukiwania głosowego.
enum VoiceSearchState: Equatable {
    /// Mikrofon wyłączony.
    case idle
    /// Prośba o zgodę / uruchamianie mikrofonu.
    case starting
    /// Nagrywanie — wynik częściowy trafia od razu do pola.
    case listening
    /// Mikrofon zatrzymany, czekamy chwilę na wynik końcowy.
    case finishing
}

/// Problem, który wymaga reakcji użytkownika (alert).
enum VoiceSearchIssue: Identifiable, Equatable {
    case permissionDenied
    case unavailable(VoiceSearchLanguage)
    case audio(String)

    var id: String {
        switch self {
        case .permissionDenied: return "permission"
        case .unavailable(let language): return "unavailable-\(language.rawValue)"
        case .audio: return "audio"
        }
    }

    var title: String {
        switch self {
        case .permissionDenied: return "Brak dostępu do mikrofonu"
        case .unavailable: return "Dyktowanie niedostępne"
        case .audio: return "Mikrofon nie działa"
        }
    }

    var message: String {
        switch self {
        case .permissionDenied:
            return "Żeby wyszukiwać głosem, zezwól FluentNOW na mikrofon i rozpoznawanie mowy w Ustawieniach systemu. Wpisywanie działa bez tego."
        case .unavailable(let language):
            return "Rozpoznawanie mowy \(language.adverbPl) jest teraz niedostępne na tym urządzeniu. Spróbuj drugiego języka albo wpisz słowo."
        case .audio(let detail):
            return "Nie udało się uruchomić mikrofonu: \(detail)"
        }
    }

    /// Czy alert ma przycisk „Otwórz Ustawienia”.
    var offersSettings: Bool {
        switch self {
        case .permissionDenied: return true
        case .unavailable, .audio: return false
        }
    }
}

/// Wyszukiwanie głosowe w polu tekstowym: `SFSpeechRecognizer` (en-US lub pl-PL, na urządzeniu,
/// gdy obsługiwane), wynik częściowy na żywo, auto-stop po 1,5 s ciszy albo po 8 s.
///
/// Jedna instancja na pole (`@State` widoku). Mikrofon działa tylko po dotknięciu przycisku;
/// sesja audio i silnik są zwalniane po każdym nagraniu (`.notifyOthersOnDeactivation`), więc
/// odsłuch wymowy (`SpeechService` — sam ustawia `.playback`) działa zaraz potem. Przed startem
/// widok zatrzymuje mowę (`speech.stop()`), żeby syntezator nie nagrał się do wyszukiwania.
@MainActor
@Observable
final class VoiceSearchController {
    private(set) var state: VoiceSearchState = .idle
    /// Bieżący tekst (częściowy lub końcowy, już oczyszczony).
    private(set) var transcript = ""
    /// Poziom dźwięku 0…1 (animacja przycisku).
    private(set) var level: Double = 0
    /// Język trwającego / ostatniego nagrania.
    private(set) var language: VoiceSearchLanguage = .english
    /// Krótka informacja pod polem (np. „Nic nie usłyszałem”), czyszczona przy kolejnym starcie.
    private(set) var notice: String?
    /// Problem do pokazania w alercie.
    var issue: VoiceSearchIssue?

    /// Cisza kończąca nagranie i maksymalny czas nagrania (sekundy).
    static let silenceTimeout: TimeInterval = 1.5
    static let maxDuration: TimeInterval = 8
    /// Ile czekamy na wynik końcowy po zatrzymaniu mikrofonu.
    static let finalResultGrace: TimeInterval = 1.0

    var isActive: Bool { state != .idle }
    var isListening: Bool { state == .listening }

    @ObservationIgnored private var recognizers: [VoiceSearchLanguage: SFSpeechRecognizer] = [:]
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var maxTimer: Task<Void, Never>?
    @ObservationIgnored private var silenceTimer: Task<Void, Never>?
    @ObservationIgnored private var finalTimer: Task<Void, Never>?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    /// Etap wymowy w sesji albo mowa przejmują dźwięk — nagranie wyszukiwania kończy się (FEEDBACK-10 P2).
    @ObservationIgnored private var focusObserver: NSObjectProtocol?
    @ObservationIgnored private var sessionActive = false
    /// Numer nagrania — wyniki spóźnione z poprzedniego nagrania są ignorowane.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var onPartial: ((String) -> Void)?
    @ObservationIgnored private var onFinish: ((String) -> Void)?

    init() {}

    // MARK: - Sterowanie

    /// Rozpoczyna nagrywanie. `onPartial` dostaje tekst na żywo, `onFinish` — tekst końcowy
    /// (pusty, gdy nic nie rozpoznano). Wołać tylko po akcji użytkownika.
    func start(
        language: VoiceSearchLanguage,
        onPartial: @escaping (String) -> Void,
        onFinish: @escaping (String) -> Void
    ) async {
        guard state == .idle else { return }
        state = .starting
        notice = nil
        transcript = ""
        self.language = language
        generation += 1
        let current = generation

        guard await ensurePermission() else {
            if generation == current { state = .idle }
            return
        }
        guard generation == current, state == .starting else { return }
        guard let recognizer = recognizer(for: language), recognizer.isAvailable else {
            state = .idle
            issue = .unavailable(language)
            return
        }
        self.onPartial = onPartial
        self.onFinish = onFinish
        do {
            try begin(with: recognizer, generation: current)
        } catch {
            teardown()
            state = .idle
            self.onPartial = nil
            self.onFinish = nil
            issue = .audio(error.localizedDescription)
        }
    }

    /// Zatrzymuje mikrofon; wynik końcowy przychodzi chwilę później (`onFinish`).
    func stop() {
        switch state {
        case .listening:
            stopRecording()
        case .starting:
            cancel()
        case .idle, .finishing:
            break
        }
    }

    /// Przerywa bez wyniku (np. zniknięcie widoku). Zwalnia mikrofon i sesję audio.
    func cancel() {
        generation += 1
        onPartial = nil
        onFinish = nil
        teardown()
        state = .idle
        level = 0
    }

    // MARK: - Zgody

    private func ensurePermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            break
        case .notDetermined:
            let status = await Self.requestSpeechAuthorization()
            guard status == .authorized else {
                issue = .permissionDenied
                return false
            }
        case .denied, .restricted:
            issue = .permissionDenied
            return false
        @unknown default:
            issue = .permissionDenied
            return false
        }
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .undetermined:
            let granted = await AVAudioApplication.requestRecordPermission()
            if !granted { issue = .permissionDenied }
            return granted
        case .denied:
            issue = .permissionDenied
            return false
        @unknown default:
            issue = .permissionDenied
            return false
        }
    }

    /// Prośba o zgodę poza `@MainActor` (Speech woła blok na własnej kolejce) — jak w `PronunciationService`.
    nonisolated private static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { (status: SFSpeechRecognizerAuthorizationStatus) in
                continuation.resume(returning: status)
            }
        }
    }

    private func recognizer(for language: VoiceSearchLanguage) -> SFSpeechRecognizer? {
        if let cached = recognizers[language] { return cached }
        guard let created = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue)) else { return nil }
        recognizers[language] = created
        return created
    }

    // MARK: - Nagrywanie

    private func begin(with recognizer: SFSpeechRecognizer, generation current: Int) throws {
        // Mowa i sprawdzanie wymowy kończą się i zwalniają sesję, zanim ją przejmiemy.
        AudioFocus.claim(by: self)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
        try session.setActive(true, options: [.notifyOthersOnDeactivation])
        sessionActive = true

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .search
        request.addsPunctuation = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceSearchFailure.noMicrophone
        }
        let levelSink: @Sendable (Float) -> Void = { [weak self] (power: Float) in
            Task { @MainActor in
                self?.updateLevel(power, generation: current)
            }
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(for: request, levelSink: levelSink))
        self.engine = engine
        engine.prepare()
        try engine.start()

        self.request = request
        let sink: @Sendable (String?, Bool, Bool) -> Void = { [weak self] (text: String?, isFinal: Bool, failed: Bool) in
            Task { @MainActor in
                self?.handle(text: text, isFinal: isFinal, failed: failed, generation: current)
            }
        }
        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(sink))
        observeInterruptions()
        state = .listening
        maxTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(VoiceSearchController.maxDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.stopRecording()
        }
        // Cisza od początku też kończy nagranie (po dłuższej chwili — trzeba zdążyć zacząć mówić).
        restartSilenceTimer(after: VoiceSearchController.silenceTimeout * 3)
    }

    /// Blok nagrania tworzony poza `@MainActor` — wywoływany na wątku audio.
    nonisolated private static func tapBlock(
        for request: SFSpeechAudioBufferRecognitionRequest,
        levelSink: @escaping @Sendable (Float) -> Void
    ) -> AVAudioNodeTapBlock {
        return { (buffer: AVAudioPCMBuffer, _: AVAudioTime) in
            request.append(buffer)
            levelSink(VoiceSearchController.rootMeanSquare(buffer))
        }
    }

    /// Średnia moc sygnału (co druga próbka — wystarcza do animacji).
    nonisolated private static func rootMeanSquare(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else { return 0 }
        let samples = channels[0]
        let count = Int(buffer.frameLength)
        guard count > 1 else { return 0 }
        var sum: Float = 0
        var used = 0
        var index = 0
        while index < count {
            let sample = samples[index]
            sum += sample * sample
            used += 1
            index += 2
        }
        return used > 0 ? (sum / Float(used)).squareRoot() : 0
    }

    /// Obsługa wyników tworzona poza `@MainActor` — Speech wywołuje ją na własnej kolejce.
    nonisolated private static func resultHandler(
        _ sink: @escaping @Sendable (String?, Bool, Bool) -> Void
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        return { (result: SFSpeechRecognitionResult?, error: Error?) in
            sink(result?.bestTranscription.formattedString, result?.isFinal ?? false, error != nil)
        }
    }

    private func handle(text: String?, isFinal: Bool, failed: Bool, generation current: Int) {
        guard current == generation, state == .listening || state == .finishing else { return }
        if let text {
            let cleaned = Self.cleaned(text)
            if !cleaned.isEmpty, cleaned != transcript {
                transcript = cleaned
                onPartial?(cleaned)
                if state == .listening { restartSilenceTimer(after: Self.silenceTimeout) }
            }
        }
        if isFinal || failed {
            finish()
        }
    }

    private func updateLevel(_ power: Float, generation current: Int) {
        guard current == generation, state == .listening else { return }
        // −50 dB … 0 dB → 0 … 1, wygładzone.
        let decibels = 20 * log10(Double(max(power, 0.000_01)))
        let normalized = min(1, max(0, (decibels + 50) / 50))
        level = level * 0.6 + normalized * 0.4
    }

    private func restartSilenceTimer(after delay: TimeInterval) {
        silenceTimer?.cancel()
        silenceTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.stopRecording()
        }
    }

    /// Zatrzymuje mikrofon i zwalnia sesję audio; rozpoznawanie kończy się wynikiem końcowym
    /// albo po `finalResultGrace`.
    private func stopRecording() {
        guard state == .listening else { return }
        state = .finishing
        level = 0
        stopAudio()
        request?.endAudio()
        finalTimer?.cancel()
        finalTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(VoiceSearchController.finalResultGrace * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private func finish() {
        guard state == .listening || state == .finishing else { return }
        let text = transcript
        let callback = onFinish
        onPartial = nil
        onFinish = nil
        teardown()
        state = .idle
        level = 0
        if text.isEmpty {
            notice = "Nic nie usłyszałem. Dotknij mikrofonu i powiedz słowo \(language.adverbPl)."
        }
        callback?(text)
    }

    /// Zwalnia wszystko: timery, zadanie rozpoznawania, silnik, sesję audio, obserwatora przerwań.
    private func teardown() {
        maxTimer?.cancel()
        silenceTimer?.cancel()
        finalTimer?.cancel()
        maxTimer = nil
        silenceTimer = nil
        finalTimer = nil
        stopAudio()
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
        interruptionObserver = nil
        if let focusObserver {
            NotificationCenter.default.removeObserver(focusObserver)
        }
        focusObserver = nil
    }

    private func stopAudio() {
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        engine = nil
        if sessionActive {
            sessionActive = false
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    /// Połączenie telefoniczne, Siri itp. — kończymy nagranie z tym, co już rozpoznano.
    private func observeInterruptions() {
        if focusObserver == nil {
            focusObserver = AudioFocus.observe(owner: self) { [weak self] in
                self?.cancel()
            }
        }
        guard interruptionObserver == nil else { return }
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] (_: Notification) in
            Task { @MainActor in
                self?.stopRecording()
            }
        }
    }

    // MARK: - Tekst

    /// Tekst do pola wyszukiwania: bez skrajnych spacji i końcowej interpunkcji, małymi literami
    /// (rozpoznawanie zaczyna zdanie wielką literą; wyszukiwanie i tak nie rozróżnia wielkości).
    nonisolated static func cleaned(_ text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = value.last, ".,!?;:…".contains(last) {
            value.removeLast()
        }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.lowercased()
    }
}

/// Błąd uruchamiania nagrania (komunikat trafia do `VoiceSearchIssue.audio`).
private enum VoiceSearchFailure: Error, LocalizedError {
    case noMicrophone

    var errorDescription: String? {
        switch self {
        case .noMicrophone: return "brak dostępnego mikrofonu."
        }
    }
}
