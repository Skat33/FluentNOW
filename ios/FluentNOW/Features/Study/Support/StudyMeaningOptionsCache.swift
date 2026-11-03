import Foundation
import FluentKit

/// Opcje „Wybierz znaczenie” bez ciężkiej pracy na głównym wątku (FEEDBACK-10 P3, code-qa-9 §7.2).
///
/// Klucze odpowiedzi wszystkich znaczeń (słowa ucznia + słowa startowe) liczy raz na rewizję stanu
/// `MeaningOptionsIndex` w `store.compute` (poza głównym wątkiem); zadanie porównuje już tylko
/// zbiory. Zanim indeks powstanie (pierwsze zadanie sesji), działa dotychczasowe liczenie wprost.
/// Indeks z poprzedniej rewizji jest używany, dopóki nowy się liczy — kandydaci zmieniają się tylko
/// przy edycji słów, a klucze celu zadania są zawsze liczone na świeżo.
@MainActor
final class StudyMeaningOptionsCache {
    private var index: MeaningOptionsIndex?
    private var indexRevision = -1
    private var buildingRevision: Int?
    private var cache: [String: [String]] = [:]
    /// Rośnie przy `reset()` — wynik liczony ze starymi zasobami jest odrzucany.
    private var generation = 0

    nonisolated init() {}

    /// Opcje zadania; ten sam klucz (znaczenie, przykład, pozycja w sesji) zwraca te same opcje.
    func options(for content: VocabExerciseContent, state: LearnerState, resources: StudyResources, sessionIndex: Int) -> [String] {
        let key = "\(content.meaning.id):\(content.task.example):\(sessionIndex)"
        if let cached = cache[key] { return cached }
        let computed: [String]
        if let index {
            computed = MeaningOptions.options(
                index: index,
                word: content.word,
                meaning: content.meaning,
                task: content.task,
                sessionIndex: sessionIndex,
                answerIndex: resources.answerIndex
            )
        } else {
            computed = MeaningOptions.options(
                state: state,
                word: content.word,
                meaning: content.meaning,
                task: content.task,
                starterWords: resources.starterWords,
                answerIndex: resources.answerIndex
            )
        }
        cache[key] = computed
        return computed
    }

    /// Przelicza indeks w tle, jeśli jest starszy niż bieżąca rewizja (nic nie blokuje).
    func refresh(store: LearningStore, resources: StudyResources) {
        let revision = store.revision
        guard revision != indexRevision, buildingRevision != revision else { return }
        buildingRevision = revision
        let starters = resources.starterWords
        let answerIndex = resources.answerIndex
        let started = generation
        Task { @MainActor [weak self] in
            let built: MeaningOptionsIndex = await store.compute { (state: LearnerState) -> MeaningOptionsIndex in
                MeaningOptionsIndex(state: state, starterWords: starters, answerIndex: answerIndex)
            }
            // Nowszy wynik zawsze wygrywa; starszy przydaje się, dopóki nie ma żadnego.
            guard let self, self.generation == started, revision > self.indexRevision else { return }
            self.index = built
            self.indexRevision = revision
            if self.buildingRevision == revision {
                self.buildingRevision = nil
            }
        }
    }

    /// Zasoby treści (słowa startowe, warianty) się zmieniły — indeks i opcje od nowa.
    func reset() {
        generation += 1
        index = nil
        indexRevision = -1
        buildingRevision = nil
        cache.removeAll()
    }
}
