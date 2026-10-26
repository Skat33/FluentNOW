import Foundation
import FluentKit

/// Uruchamianie sesji z ekranu Nauka (logika strony `start()`).
/// Ciężkie budowanie sesji liczone na migawce stanu poza głównym wątkiem (`store.compute`),
/// zapis jednym `store.update(.session)`.
///
/// FEEDBACK-6 K1: ekran Nauka nie łączy już kilku trybów w jednej sesji (sekcja „Ile masz
/// czasu?” zniknęła). Każda prośba uruchamia jeden tryb; przerwana sesja łączona nadal wznawia się
/// z Dzisiaj („Wznów sesję”), bo kod `CombinedSessionView` zostaje.
@MainActor
enum StudyStarter {
    enum Outcome {
        /// Gotowe — pokaż ekran sesji.
        case flow(StudyFlow)
        /// Nie da się rozpocząć — spokojny komunikat dla użytkownika.
        case message(String)
    }

    /// Jeden tryb (`StudyMode`): fiszki, słownictwo (codzienna mieszanka, pomyłki, pary, zdjęcia),
    /// czytanie, gramatyka / idiomy / miks, produkcja.
    static func startMode(_ mode: StudyMode, minutes: Int, collection: String?, store: LearningStore, images: WordImageService? = nil) async -> Outcome {
        // Zdjęcia na kolejne sesje dociągają się w tle już teraz (H2) — nigdy nie czekamy na nie.
        requestPhotos(store: store, images: images)
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

    /// Nowa sesja słownictwa (`makeSession`) zapisana w `state.session`.
    /// `images`: zadania „Słowo i zdjęcie” tylko dla słów, których zdjęcia są już na dysku (G2).
    /// `fresh` (FEEDBACK-8 M2, „Zacznij od nowa” na kafelku codziennej mieszanki / pomyłek / par):
    /// nowa sesja z innymi zdaniami niż przerwana (`FreshStart.vocabularySession`).
    static func startVocabulary(mode: StudyMode, minutes: Int, collection: String?, store: LearningStore, images: WordImageService? = nil, fresh: Bool = false) async -> Outcome {
        requestPhotos(store: store, images: images)
        let cached = await cachedPictureIDs(images)
        let session = await store.compute { (state: LearnerState) -> VocabSession in
            let ready = PictureExercise.readyMeaningIDs(state: state, cached: cached)
            if fresh {
                return FreshStart.vocabularySession(state: state, mode: mode, minutes: minutes, collection: collection, pictureMeaningIDs: ready)
            }
            return SessionBuilder.makeSession(state: state, minutes: minutes, mode: mode, collection: collection, pictureMeaningIDs: ready)
        }
        guard !session.tasks.isEmpty else {
            if mode == .pictures && !PictureExercise.isEnabled {
                return .message(StudyPicturesLockedCard.message)
            }
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

    /// „Ćwicz wybrany typ” (FEEDBACK-5 J1): krótka sesja tylko z jednym typem ćwiczenia
    /// (`SingleTypeSession`) zapisana w `state.session` — wznawia się i liczy jak zwykła sesja.
    /// `fresh` (FEEDBACK-6 K1, „Zacznij od nowa”): zastępuje przerwaną sesję nową, z innymi
    /// zdaniami niż w przerwanej (`FreshStart.singleTypeSession`).
    static func startSingleType(_ type: ExerciseType, minutes: Int, collection: String?, store: LearningStore, fresh: Bool = false) async -> Outcome {
        let now = store.now()
        let session = await store.compute { (state: LearnerState) -> VocabSession in
            fresh
                ? FreshStart.singleTypeSession(state: state, type: type, minutes: minutes, collection: collection, now: now)
                : SingleTypeSession.makeSession(state: state, type: type, minutes: minutes, collection: collection, now: now)
        }
        guard !session.tasks.isEmpty else {
            return .message(StudySingleTypeText.emptyMessage(type: type, hasWords: !store.activeWords.isEmpty, collection: collection))
        }
        store.update(.session) { (state: inout LearnerState) -> Void in
            state.session = session
        }
        return .flow(.vocabulary)
    }

    /// „Zacznij od nowa” dla czytania, gramatyki / idiomów / miksu i produkcji (K1): nowy tekst
    /// lub zestaw w miejsce przerwanego (inne zadania — `FreshStart`), potem ekran zajęcia.
    static func restartBank(_ activity: StudyActivity, store: LearningStore, content: ContentLibrary) async -> Outcome {
        let loaded: PracticeContentLoader.Loaded
        do {
            loaded = try await PracticeContentLoader.load(store: store, library: content)
        } catch {
            return .message(PracticeContentLoader.errorMessage(error))
        }
        let now = store.now()
        switch activity {
        case .reading:
            let started = store.update(.session) { (state: inout LearnerState) -> Bool in
                let previous = state.reading?.reading.id
                let next = FreshStart.restartReading(state, bank: loaded.content.readings, now: now)
                guard let reading = next.reading, !reading.submitted, reading.reading.id != previous else { return false }
                state = next
                return true
            }
            return started
                ? .flow(.reading(autoStart: false))
                : .message("Nie mamy teraz innej czytanki na Twoim poziomie. Możesz dokończyć przerwaną.")
        case .practice(let kind):
            let started = store.update(.session) { (state: inout LearnerState) -> Bool in
                let next = FreshStart.restartPractice(state, kind: kind, level: loaded.level, content: loaded.content, now: now)
                guard let practice = next.practice, practice.set.kind == kind, practice.completedAt == nil,
                      practice.set.id != state.practice?.set.id else { return false }
                state = next
                return true
            }
            return started
                ? .flow(.practice(kind, autoStart: false))
                : .message("Na poziomie \(loaded.level) nie ma jeszcze zadań tego rodzaju.")
        case .production:
            let started = store.update(.session) { (state: inout LearnerState) -> Bool in
                let next = FreshStart.restartProduction(state, level: loaded.level, content: loaded.content, now: now)
                guard let production = next.production, production.completedAt == nil,
                      production.id != state.production?.id else { return false }
                state = next
                return true
            }
            return started
                ? .flow(.production(autoStart: false))
                : .message("Na poziomie \(loaded.level) nie ma jeszcze zadań produkcji.")
        case .singleType, .vocabulary, .flashcards:
            return .message("Ten rodzaj ćwiczeń zaczyna się od nowa na swoim ekranie.")
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
        // „W budowie” (I2): bez zdjęć w sesjach (FluentKit i tak ich nie losuje).
        guard let images, PictureExercise.isEnabled else { return [] }
        return await images.cachedMeaningIDs()
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
            return "„Tryb pomyłek” zbiera słowa z błędną lub bardzo wolną odpowiedzią i słowa oznaczone jako trudne. Na razie takich nie masz."
        case .pairs:
            return "„Słowa w parach” potrzebuje słów o podobnych znaczeniach (np. borrow i lend). Nie znaleźliśmy jeszcze takich par — dodaj więcej słów z tematów."
        default:
            return "Na teraz wszystko powtórzone. Dodaj nowe słowa albo dotknij innego kafelka w „Ćwiczeniach”."
        }
    }
}
