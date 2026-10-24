import Foundation
import FluentKit

/// Przerwana sesja do wznowienia. Ekran Nauka nie pokazuje już kart „Kontynuuj” (FEEDBACK-6 K1);
/// lista służy wznowieniu z Dzisiaj („Wznów sesję”) i z linku `fluentnow://study/resume`.
struct StudyResumeItem: Identifiable, Hashable {
    let flow: StudyFlow
    let title: String
    let detail: String
    let progress: Double

    var id: String { flow.id }

    /// Wszystkie niedokończone sesje w stanie (sesja łączona i słownictwo najpierw — jak strona).
    static func items(in state: LearnerState) -> [StudyResumeItem] {
        var result: [StudyResumeItem] = []
        if let combined = state.combined, combined.completedAt == nil, combined.index < combined.tasks.count {
            result.append(StudyResumeItem(
                flow: .combined,
                title: "Twoja sesja łączona czeka",
                detail: "Ukończono \(combined.index) z \(StudyFormat.tasks(combined.tasks.count)). Kolejność jest zapisana.",
                progress: ProgressMath.fraction(combined.index, of: combined.tasks.count)
            ))
        }
        if let session = state.session, !session.isFinished, !session.tasks.isEmpty {
            // „Ćwicz wybrany typ” (J1) — nazwa typu zamiast „Codziennej mieszanki”.
            let name = StudySingleTypeText.sessionTitle(mode: session.mode) ?? session.studyMode.namePl
            result.append(StudyResumeItem(
                flow: .vocabulary,
                title: "Twoja sesja czeka",
                detail: "\(name) · ukończono \(session.index) z \(StudyFormat.exercises(session.tasks.count)).",
                progress: ProgressMath.fraction(session.index, of: session.tasks.count)
            ))
        }
        if let reading = state.reading, !reading.submitted {
            result.append(StudyResumeItem(
                flow: .reading(autoStart: false),
                title: "Czytanka czeka",
                detail: "„\(reading.reading.title)” · \(reading.reading.level)",
                progress: 0
            ))
        }
        if let practice = state.practice, practice.completedAt == nil, !practice.set.items.isEmpty {
            result.append(StudyResumeItem(
                flow: .practice(practice.set.kind, autoStart: false),
                title: "Zestaw: \(practice.set.kind.studyTitle)",
                detail: "Pytanie \(min(practice.index + 1, practice.set.items.count)) z \(practice.set.items.count) · \(practice.set.level)",
                progress: ProgressMath.fraction(practice.index, of: practice.set.items.count)
            ))
        }
        if let production = state.production, production.completedAt == nil, !production.set.items.isEmpty {
            result.append(StudyResumeItem(
                flow: .production(autoStart: false),
                title: "Produkcja gramatyczna czeka",
                detail: "Zadanie \(min(production.index + 1, production.set.items.count)) z \(production.set.items.count) · \(production.set.level)",
                progress: ProgressMath.fraction(production.index, of: production.set.items.count)
            ))
        }
        return result
    }
}

/// Okno wyboru po dotknięciu kafelka, dla którego istnieje przerwana sesja (FEEDBACK-6 K1):
/// „Kontynuuj, gdzie skończyłem” albo „Zacznij od nowa”.
struct StudyResumePrompt: Identifiable, Hashable {
    let activity: StudyActivity
    /// Np. „Masz przerwane ćwiczenie „Ułóż zdanie””.
    let title: String
    /// Postęp przerwanej sesji, np. „Ukończono 3 z 12 ćwiczeń.”.
    let detail: String

    var id: StudyActivity { activity }

    /// Wyjaśnienie „Zacznij od nowa” (pod postępem w oknie).
    static let restartNote = "„Zacznij od nowa” przygotuje nową sesję z innymi zdaniami. Odpowiedzi, których już udzieliłeś, są zapisane."

    /// Okno dla zajęcia — `nil`, gdy nie ma przerwanej sesji tego zajęcia (wtedy kafelek od razu
    /// zaczyna nową). Sesja jednego typu liczy się tylko dla tego samego typu; przerwana sesja
    /// innego rodzaju (np. codzienna mieszanka) nie blokuje kafelka.
    static func make(for activity: StudyActivity, state: LearnerState, pausedDeck: FlashcardPausedDeck?) -> StudyResumePrompt? {
        switch activity {
        case .singleType(let type):
            guard let session = state.session, !session.isFinished, !session.tasks.isEmpty,
                  SingleTypeSession.type(ofMode: session.mode) == type else { return nil }
            return StudyResumePrompt(
                activity: activity,
                title: "Masz przerwane ćwiczenie „\(type.practiceTitle)”",
                detail: "Ukończono \(min(session.index, session.tasks.count)) z \(StudyFormat.exercises(session.tasks.count))."
            )
        case .flashcards:
            guard let pausedDeck, !pausedDeck.run.isFinished else { return nil }
            return StudyResumePrompt(
                activity: activity,
                title: "Masz przerwaną talię fiszek",
                detail: "\(pausedDeck.positionText) · pamiętasz \(pausedDeck.run.remembered), do powtórki \(pausedDeck.run.forgotten)."
            )
        case .reading:
            guard let reading = state.reading, !reading.submitted else { return nil }
            return StudyResumePrompt(
                activity: activity,
                title: "Masz przerwaną czytankę",
                detail: "„\(reading.reading.title)” · \(reading.reading.level)"
            )
        case .practice(let kind):
            guard let practice = state.practice, practice.set.kind == kind, practice.completedAt == nil,
                  !practice.set.items.isEmpty else { return nil }
            return StudyResumePrompt(
                activity: activity,
                title: "Masz przerwany zestaw: \(kind.studyTitle)",
                detail: "Pytanie \(min(practice.index + 1, practice.set.items.count)) z \(practice.set.items.count) · \(practice.set.level)"
            )
        case .production:
            guard let production = state.production, production.completedAt == nil,
                  !production.set.items.isEmpty else { return nil }
            return StudyResumePrompt(
                activity: activity,
                title: "Masz przerwaną produkcję gramatyczną",
                detail: "Zadanie \(min(production.index + 1, production.set.items.count)) z \(production.set.items.count) · \(production.set.level)"
            )
        }
    }
}
