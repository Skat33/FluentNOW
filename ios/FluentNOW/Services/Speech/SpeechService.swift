import Foundation
import Observation
import AVFoundation
import FluentKit

/// Głos do wyboru w Ustawieniach.
struct VoiceOption: Identifiable, Hashable {
    let id: String
    let name: String
    let language: String
    let qualityLabel: String
}

/// Synteza mowy angielskiej (`AVSpeechSynthesizer`).
///
/// - domyślnie najlepszy głos dla akcentu z ustawień (en-US), albo wybrany głos (`settings.voice`
///   = identyfikator `AVSpeechSynthesisVoice`),
/// - tempo normalne / wolne (`settings.slow` lub parametr),
/// - `[[gap]]` (FluentKit `ExerciseAudio.speechGap`) i `________` czytane jako krótka pauza,
/// - nowa wypowiedź przerywa poprzednią, sesja audio `.playback` z `.duckOthers`
///   (muzyka ścisza się na czas mowy), przerwania (połączenie) zatrzymują mowę.
@MainActor
@Observable
final class SpeechService {
    private(set) var isSpeaking: Bool = false

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = SpeechDelegate()
    @ObservationIgnored private let settingsProvider: @MainActor () -> LearnerSettings
    @ObservationIgnored private let audioEnabled: Bool
    @ObservationIgnored private var pendingUtterances: Set<ObjectIdentifier> = []
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private var voicesCache: [VoiceOption]?

    /// Tempo normalne i wolne (skala `AVSpeechUtterance.rate`, domyślna 0,5).
    static let normalRate: Float = AVSpeechUtteranceDefaultSpeechRate
    static let slowRate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.78
    /// Pauza w miejscu luki (sekundy).
    static let gapPause: TimeInterval = 0.7

    /// - Parameters:
    ///   - settingsProvider: bieżące ustawienia (głos, akcent, tempo) — zwykle `store.settings`.
    ///   - audioEnabled: `false` w podglądzie i testach (nic nie jest odtwarzane).
    init(settingsProvider: @escaping @MainActor () -> LearnerSettings, audioEnabled: Bool = true) {
        self.settingsProvider = settingsProvider
        self.audioEnabled = audioEnabled
        synthesizer.delegate = delegate
        delegate.onFinish = { [weak self] id in
            self?.utteranceEnded(id)
        }
        if audioEnabled {
            interruptionObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: AVAudioSession.sharedInstance(),
                queue: .main
            ) { [weak self] note in
                let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard rawType == AVAudioSession.InterruptionType.began.rawValue else { return }
                Task { @MainActor in
                    self?.stop()
                }
            }
        }
    }

    deinit {
        if let interruptionObserver {
            NotificationCenter.default.removeObserver(interruptionObserver)
        }
    }

    // MARK: - Mowa

    /// Czyta tekst po angielsku. `slow == nil` → tempo z ustawień. Przerywa poprzednią wypowiedź.
    func speak(_ text: String, slow: Bool? = nil) {
        let settings = settingsProvider()
        let voice = resolveVoice(settings: settings)
        speak(text, voice: voice, slow: slow ?? settings.slow)
    }

    func stop() {
        pendingUtterances.removeAll()
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finishSpeaking()
    }

    /// Angielskie głosy systemu, najlepsza jakość na górze (bez głosów-zabawek i Personal Voice).
    func availableVoices() -> [VoiceOption] {
        if let voicesCache { return voicesCache }
        let accent = settingsProvider().accent
        let voices = Self.englishVoices()
            .sorted { lhs, rhs in
                let lq = Self.qualityRank(lhs.quality)
                let rq = Self.qualityRank(rhs.quality)
                if lq != rq { return lq > rq }
                let la = lhs.language == accent
                let ra = rhs.language == accent
                if la != ra { return la }
                if lhs.language != rhs.language { return lhs.language < rhs.language }
                return lhs.name < rhs.name
            }
            .map { voice in
                VoiceOption(
                    id: voice.identifier,
                    name: voice.name,
                    language: voice.language,
                    qualityLabel: Self.qualityLabel(voice.quality)
                )
            }
        voicesCache = voices
        return voices
    }

    /// Próbka wybranego głosu (Ustawienia).
    func preview(voice: VoiceOption) {
        let settings = settingsProvider()
        let resolved = AVSpeechSynthesisVoice(identifier: voice.id) ?? resolveVoice(settings: settings)
        speak("Hi! This is how I'll read your words and example sentences.", voice: resolved, slow: settings.slow)
    }

    /// Unieważnia listę głosów (np. po pobraniu nowego głosu w Ustawieniach systemu).
    func reloadVoices() {
        voicesCache = nil
    }

    // MARK: - Implementacja

    private func speak(_ text: String, voice: AVSpeechSynthesisVoice?, slow: Bool) {
        stop()
        let segments = Self.segments(for: text)
        guard !segments.isEmpty else { return }
        guard audioEnabled else { return }
        activateAudioSession()
        let rate = slow ? Self.slowRate : Self.normalRate
        for (index, segment) in segments.enumerated() {
            let utterance = AVSpeechUtterance(string: segment)
            utterance.voice = voice
            utterance.rate = rate
            if index < segments.count - 1 {
                utterance.postUtteranceDelay = Self.gapPause
            }
            pendingUtterances.insert(ObjectIdentifier(utterance))
            synthesizer.speak(utterance)
        }
        isSpeaking = true
    }

    private func utteranceEnded(_ id: ObjectIdentifier) {
        pendingUtterances.remove(id)
        if pendingUtterances.isEmpty {
            finishSpeaking()
        }
    }

    private func finishSpeaking() {
        guard isSpeaking else { return }
        isSpeaking = false
        deactivateAudioSession()
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            // Bez sesji audio mowa nadal działa (z domyślną kategorią) — nie przerywamy.
        }
    }

    private func deactivateAudioSession() {
        guard audioEnabled else { return }
        // Oddaj dźwięk innym aplikacjom (koniec ściszania muzyki).
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func resolveVoice(settings: LearnerSettings) -> AVSpeechSynthesisVoice? {
        if let identifier = settings.voice, !identifier.isEmpty,
           let chosen = AVSpeechSynthesisVoice(identifier: identifier),
           chosen.language.hasPrefix("en") {
            return chosen
        }
        let accent = settings.accent
        let best = Self.englishVoices()
            .filter { $0.language == accent }
            .max { Self.qualityRank($0.quality) < Self.qualityRank($1.quality) }
        return best ?? AVSpeechSynthesisVoice(language: accent) ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Tekst podzielony na fragmenty w miejscach luk (`[[gap]]`, `____`).
    nonisolated static func segments(for text: String) -> [String] {
        var normalized = text.replacingOccurrences(of: ExerciseAudio.speechGap, with: "\u{1F}")
        // Ciąg co najmniej trzech podkreślników = luka.
        var result = ""
        var underscores = 0
        for character in normalized {
            if character == "_" {
                underscores += 1
                continue
            }
            if underscores > 0 {
                result += underscores >= 3 ? "\u{1F}" : String(repeating: "_", count: underscores)
                underscores = 0
            }
            result.append(character)
        }
        if underscores > 0 {
            result += underscores >= 3 ? "\u{1F}" : String(repeating: "_", count: underscores)
        }
        normalized = result
        return normalized
            .split(separator: "\u{1F}", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func englishVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { voice in
            guard voice.language.hasPrefix("en") else { return false }
            if voice.voiceTraits.contains(.isNoveltyVoice) { return false }
            if voice.voiceTraits.contains(.isPersonalVoice) { return false }
            return true
        }
    }

    private static func qualityRank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: return 3
        case .enhanced: return 2
        case .default: return 1
        @unknown default: return 0
        }
    }

    private static func qualityLabel(_ quality: AVSpeechSynthesisVoiceQuality) -> String {
        switch quality {
        case .premium: return "Najwyższa jakość"
        case .enhanced: return "Rozszerzona jakość"
        case .default: return "Standardowa jakość"
        @unknown default: return "Standardowa jakość"
        }
    }
}

/// Delegat syntezatora (NSObject) — przekazuje zakończenie wypowiedzi na główny wątek.
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onFinish: (@MainActor (ObjectIdentifier) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        notify(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        notify(utterance)
    }

    private func notify(_ utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        let callback = onFinish
        Task { @MainActor in
            callback?(id)
        }
    }
}
