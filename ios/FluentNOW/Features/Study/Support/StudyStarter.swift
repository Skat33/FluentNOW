import Foundation
import FluentKit

/// Uruchamianie sesji z ekranu Nauka (logika strony `start()` / `makeCombinedSession`).
/// Ciężkie budowanie sesji liczone na migawce stanu poza głównym wątkiem (`store.compute`),
/// zapis jednym `store.update(.session)`.
@MainActor
enum StudyStarter {
    enum Outcome {
        /// Gotowe — pokaż ekran sesji.
        case flow(StudyFlow)
        /// Sesja łączona, w której część trybów nie ma zadań — pokaż podsumowanie przed startem.
        case combinedDraft(CombinedSession)
        /// Nie da się rozpocząć — spokojny komunikat dla użytkownika.
        case message(String)
    }

    static func start(
        modes: [StudyMode],
        minutes: Int,
        random: Bool,
        collection: String?,
        store: LearningStore,
        content: ContentLibrary
    ) async -> Outcome {
        var unique: [StudyMode] = []
        for mode in modes where !unique.contains(mode) {
            unique.append(mode)
        }
        guard let first = unique.first else {
            return .message("Zaznacz jeden lub kilka rodzajów ćwiczeń.")
        }
        if unique.count == 1 {
            return await startSingle(first, minutes: minutes, collection: collection, store: store)
        }
        return await startCombined(unique, minutes: minutes, random: random, store: store, content: content)
    }

    /// Nowa sesja słownictwa (`makeSession`) zapisana w `state.session`.
    static func startVocabulary(mode: StudyMode, minutes: Int, collection: String?, store: LearningStore) async -> Outcome {
        let session = await store.compute { state in
            SessionBuilder.makeSession(state: state, minutes: minutes, mode: mode, collection: collection)
        }
        guard !session.tasks.isEmpty else {
            return .message(emptyVocabularyMessage(mode: mode, collection: collection, hasWords: !store.activeWords.isEmpty))
        }
        store.update(.session) { state in
            state.session = session
        }
        return .flow(.vocabulary)
    }

    /// Zatwierdza szkic sesji łączonej (po potwierdzeniu w arkuszu).
    static func commitCombined(_ draft: CombinedSession, store: LearningStore) {
        store.update(.session) { state in
            state.combined = draft
        }
    }

    // MARK: - Prywatne

    private static func startSingle(_ mode: StudyMode, minutes: Int, collection: String?, store: LearningStore) async -> Outcome {
        if mode.isVocabulary {
            return await startVocabulary(mode: mode, minutes: minutes, collection: collection, store: store)
        }
        if mode == .reading {
            return .flow(.reading(autoStart: true))
        }
        if mode == .production {
            return .flow(.production(autoStart: true))
        }
        if let kind = mode.studyPracticeKind {
            return .flow(.practice(kind, autoStart: true))
        }
        return .message("Ten rodzaj ćwiczeń nie jest jeszcze dostępny.")
    }

    private static func startCombined(
        _ modes: [StudyMode],
        minutes: Int,
        random: Bool,
        store: LearningStore,
        content: ContentLibrary
    ) async -> Outcome {
        let needsBanks = modes.contains { !$0.isVocabulary }
        var practice = PracticeContent.empty
        var contentProblem = false
        if needsBanks {
            let level = await store.compute { state in
                LevelEstimator.estimatedLevel(state).targetLevel
            }
            do {
                practice = try await content.practiceContent(level: level)
            } catch {
                contentProblem = true
            }
        }
        let now = store.now()
        let banks = practice
        let draft = await store.compute { (state: LearnerState) -> CombinedSession in
            var rng = SystemRandomNumberGenerator()
            return CombinedSessionBuilder.makeSession(
                state: state,
                modes: modes,
                minutes: minutes,
                random: random,
                content: banks,
                now: now,
                using: &rng
            )
        }
        guard !draft.tasks.isEmpty else {
            return .message(contentProblem
                ? "Nie udało się wczytać zadań z banku. Spróbuj ponownie za chwilę — Twoje dane są bezpieczne."
                : "Wybrane ćwiczenia nie mają jeszcze gotowych zadań.")
        }
        let skipped = modes.contains { mode in !draft.tasks.contains { $0.mode == mode } }
        if skipped {
            return .combinedDraft(draft)
        }
        commitCombined(draft, store: store)
        return .flow(.combined)
    }

    private static func emptyVocabularyMessage(mode: StudyMode, collection: String?, hasWords: Bool) -> String {
        if !hasWords {
            return "Dodaj kilka słów lub cały temat — wtedy przygotujemy pierwszą sesję."
        }
        if let collection, !collection.isEmpty {
            return "W kolekcji „\(collection)” nie ma jeszcze słów do ćwiczenia."
        }
        switch mode {
        case .mistakes:
            return "Nie masz jeszcze słów wymagających trybu pomyłek."
        case .pairs:
            return "Nie znaleźliśmy jeszcze podobnych słów do ćwiczenia w parach. Dodaj więcej słów."
        default:
            return "Na teraz wszystko powtórzone. Dodaj nowe słowa albo wybierz inny rodzaj ćwiczeń."
        }
    }
}
