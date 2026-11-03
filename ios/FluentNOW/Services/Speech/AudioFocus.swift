import Foundation

/// Jedno źródło dźwięku naraz (FEEDBACK-10 P2): synteza mowy (`SpeechService`), sprawdzanie
/// wymowy (`PronunciationService`) i wyszukiwanie głosowe (`VoiceSearchController`) zgłaszają
/// przejęcie sesji audio tuż przed jej aktywacją; pozostałe od razu (synchronicznie, przed
/// aktywacją nowej sesji) kończą swoje nagranie / mowę i zwalniają sesję. Dzięki temu „Posłuchaj”
/// w trakcie nagrywania nie zostawia działającego silnika nagrania pod kategorią `.playback`,
/// a mikrofon wyszukiwania z innego ekranu nie nagrywa razem z etapem wymowy.
enum AudioFocus {
    /// `object` — właściciel, który przejmuje dźwięk.
    static let didChange = Notification.Name("pl.fluentnow.audioFocusDidChange")

    /// Zgłasza przejęcie dźwięku przez `owner`. Obserwatorzy wykonują się synchronicznie
    /// (na głównym wątku), więc po powrocie inne źródła są już zatrzymane.
    @MainActor
    static func claim(by owner: AnyObject) {
        NotificationCenter.default.post(name: didChange, object: owner)
    }

    /// Obserwator: `onLost`, gdy dźwięk przejmuje ktoś inny niż `owner`. Zwracany obiekt trzeba
    /// usunąć (`NotificationCenter.default.removeObserver`).
    @MainActor
    static func observe(owner: AnyObject, onLost: @escaping @MainActor () -> Void) -> NSObjectProtocol {
        let ownerID = ObjectIdentifier(owner)
        // `queue: nil` — blok wykonuje się synchronicznie w wątku wysyłającym, a `claim` wysyła
        // wyłącznie z głównego aktora.
        return NotificationCenter.default.addObserver(forName: didChange, object: nil, queue: nil) { (note: Notification) in
            let senderID: ObjectIdentifier? = note.object.map { (sender: Any) -> ObjectIdentifier in
                ObjectIdentifier(sender as AnyObject)
            }
            guard senderID != ownerID else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    onLost()
                }
            } else {
                Task { @MainActor in
                    onLost()
                }
            }
        }
    }
}
