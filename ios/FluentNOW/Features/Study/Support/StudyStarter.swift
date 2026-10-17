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
        content: ContentLibrary,
        images: WordImageService? = nil
    ) async -> Outcome {
        // Zdjęcia na kolejne sesje dociągają się w tle już teraz (H2) — nigdy nie czekamy na nie.
        requestPhotos(store: store, images: images)
        var unique: [StudyMode] = []
        for mode in modes where !unique.contains(mode) {
            unique.append(mode)
        }
        // Fiszki to osobny tryb (G3) — nigdy nie łączymy ich z innymi.
        if unique.contains(.flashcards) {
            return .flow(.flashcards(collection: collection))
        }
        guard let first = unique.first else {
            return .message("Zaznacz jeden lub kilka rodzajów ćwiczeń.")
        }
        if unique.count == 1 {
            return await startSingle(first, minutes: minutes, collection: collection, store: store, images: images)
        }
        return await startCombined(unique, minutes: minutes, random: random, store: store, content: content, images: images)
    }

    /// Nowa sesja słownictwa (`makeSession`) zapisana w `state.session`.
    /// `images`: zadania „Słowo i zdjęcie” tylko dla słów, których zdjęcia są już na dysku (G2).
    static func startVocabulary(mode: StudyMode, minutes: Int, collection: String?, store: LearningStore, images: WordImageService? = nil) async -> Outcome {
        requestPhotos(store: store, images: images)
        let cached = await cachedPictureIDs(images)
        let session = await store.compute { (state: LearnerState) -> VocabSession in
            let ready = PictureExercise.readyMeaningIDs(state: state, cached: cached)
            return SessionBuilder.makeSession(state: state, minutes: minutes, mode: mode, collection: collection, pictureMeaningIDs: ready)
        }
        guard !session.tasks.isEmpty else {
            if mode == .pictures {
                return .message(await emptyPicturesMessage(store: store, images: images, cachedCount: cached.count))
            }
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

    /// Uruchamia (lub kontynuuje) pobieranie zdjęć w tle — bez czekania na wynik.
    private static func requestPhotos(store: LearningStore, images: WordImageService?) {
        guard let images else { return }
        WordImagePrefetcher.shared(store: store, images: images).request()
    }

    /// „Słowa i obrazki” bez gotowych zdjęć: co się dzieje i co zrobić.
    private static func emptyPicturesMessage(store: LearningStore, images: WordImageService?, cachedCount: Int) async -> String {
        let picturable = await store.compute { (state: LearnerState) -> Int in
            PictureExercise.pendingCount(state: state, excluding: [])
        }
        if picturable == 0 {
            return "Wśród Twoich słów nie ma jeszcze rzeczy, które da się pokazać na zdjęciu. Dodaj np. temat „Owoce i warzywa”, „Dom” albo „Zwierzęta”."
        }
        guard let images else {
            return "Zdjęcia nie są dostępne w tym trybie aplikacji."
        }
        let status = WordImagePrefetcher.shared(store: store, images: images).status
        switch status {
        case .offline:
            return "Brak internetu — zdjęcia do ćwiczenia pobierzemy, gdy połączysz się z siecią. Zdjęcia pobrane wcześniej działają też offline."
        case .waiting:
            return "Serwis zdjęć prosi o przerwę. Gotowe zdjęcia: \(cachedCount). Dokończymy pobieranie za jakiś czas."
        case .disabled:
            return "Pobieranie zdjęć jest wyłączone."
        case .idle, .working:
            return "Zdjęcia jeszcze się pobierają (gotowe: \(cachedCount), potrzebne co najmniej \(PictureExercise.optionCount) różne). Zajrzyj za minutę."
        }
    }

    /// Znaczenia ze zdjęciem na dysku (pusty zbiór bez serwisu / bez zdjęć).
    private static func cachedPictureIDs(_ images: WordImageService?) async -> Set<String> {
        guard let images else { return [] }
        return await images.cachedMeaningIDs()
    }

    private static func startSingle(_ mode: StudyMode, minutes: Int, collection: String?, store: LearningStore, images: WordImageService?) async -> Outcome {
        if mode == .flashcards {
            return .flow(.flashcards(collection: collection))
        }
        if mode.isVocabulary {
            return await startVocabulary(mode: mode, minutes: minutes, collection: collection, store: store, images: images)
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
        content: ContentLibrary,
        images: WordImageService?
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
        let cached = await cachedPictureIDs(images)
        let draft = await store.compute { (state: LearnerState) -> CombinedSession in
            var rng = SystemRandomNumberGenerator()
            let ready = PictureExercise.readyMeaningIDs(state: state, cached: cached)
            return CombinedSessionBuilder.makeSession(
                state: state,
                modes: modes,
                minutes: minutes,
                random: random,
                content: banks,
                now: now,
                pictureMeaningIDs: ready,
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
