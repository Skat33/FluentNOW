import Foundation
import Observation
import FluentKit

/// Kroki krótkiego wywiadu przy pierwszym uruchomieniu (G4).
enum OnboardingStep: Int, CaseIterable, Identifiable {
    case goals
    case level
    case interests
    case styles
    case time
    case reminder
    case accent
    case summary

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .goals: return "Po co się uczysz?"
        case .level: return "Twój poziom"
        case .interests: return "Co Cię interesuje?"
        case .styles: return "Jak lubisz się uczyć?"
        case .time: return "Ile czasu dziennie?"
        case .reminder: return "Przypomnienie"
        case .accent: return "Akcent"
        case .summary: return "Twój plan na start"
        }
    }

    var subtitle: String {
        switch self {
        case .goals: return "Możesz wybrać kilka. Dobierzemy tematy i polecane słówka."
        case .level: return "Wybierz opis, który do Ciebie pasuje — albo zrób szybki test."
        case .interests: return "Zaznacz, o czym lubisz rozmawiać. Słowa z tych tematów pokażemy najpierw."
        case .styles: return "Ustawimy kolejność trybów na ekranie Nauka i proporcje codziennej mieszanki."
        case .time: return "Na tej podstawie ustawimy dzienny cel i długość sesji."
        case .reminder: return "Jedno krótkie powiadomienie dziennie. Możesz to zmienić w Ustawieniach."
        case .accent: return "Tak będziemy czytać słowa i przykłady."
        case .summary: return "Sprawdź i zaczynamy."
        }
    }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}

/// Opis samooceny poziomu.
struct OnboardingLevelOption: Identifiable, Hashable {
    let level: String
    let title: String
    let detail: String
    var id: String { level }

    static let all: [OnboardingLevelOption] = [
        OnboardingLevelOption(level: "A1", title: "Zaczynam od zera", detail: "Znam pojedyncze słowa i zwroty."),
        OnboardingLevelOption(level: "A2", title: "Proste zdania", detail: "Rozumiem proste zdania i dogadam się w sklepie."),
        OnboardingLevelOption(level: "B1", title: "Codzienne sytuacje", detail: "Radzę sobie w podróży i w prostej rozmowie."),
        OnboardingLevelOption(level: "B2", title: "Swobodna rozmowa", detail: "Rozmawiam swobodnie, oglądam seriale z napisami."),
        OnboardingLevelOption(level: "C1", title: "Zaawansowany", detail: "Mówię płynnie, szlifuję niuanse i precyzję."),
        OnboardingLevelOption(level: "C2", title: "Biegły", detail: "Prawie jak native — szukam rzadkich słów.")
    ]
}

/// Stan szybkiego testu poziomu.
enum OnboardingPlacementPhase: Equatable {
    case idle
    case loading
    case running
    case finished(PlacementResult)
    case unavailable
}

/// Temat proponowany na start (z wczytanym plikiem).
struct OnboardingStarterTopic: Identifiable {
    let topic: TopicFile
    var isSelected: Bool
    var id: String { topic.id }
}

/// Stan kreatora. Czyste dane + proste przejścia; efekty uboczne (zapis, powiadomienia, mowa,
/// dodawanie słów) wykonuje `OnboardingWizardView` przez środowisko.
@MainActor
@Observable
final class OnboardingModel {
    var step: OnboardingStep = .goals
    var goals: [LearningGoal] = []
    var selfLevel: String?
    var levelSource: LevelSource?
    var interests: [LearningInterest] = []
    var styles: [LearningStyle] = []
    var minutes = 10
    var reminderEnabled = false
    var reminderTime: Date
    var accent = "en-US"

    // Test poziomu
    var showsPlacement = false
    private(set) var placementPhase: OnboardingPlacementPhase = .idle
    private(set) var questions: [PlacementQuestion] = []
    private(set) var answers: [Int?] = []
    private(set) var questionIndex = 0

    // Podsumowanie
    private(set) var starterTopics: [OnboardingStarterTopic] = []
    private(set) var isPreparingSummary = false
    var isAdding = false
    var progress: Double = 0
    var errorMessage: String?

    init(reminder: String = LearnerSettings.defaultReminder, accent: String = "en-US") {
        let parts = LearnerSettings(reminder: reminder).reminderComponents
        reminderTime = Calendar.current.date(bySettingHour: parts.hour, minute: parts.minute, second: 0, of: Date()) ?? Date()
        self.accent = LearnerSettings.supportedAccents.contains(accent) ? accent : "en-US"
    }

    var stepNumber: Int { step.rawValue + 1 }
    var stepCount: Int { OnboardingStep.allCases.count }
    var fraction: Double { Double(stepNumber) / Double(stepCount) }

    // MARK: Wybory

    func toggle(_ goal: LearningGoal) {
        if let index = goals.firstIndex(of: goal) { goals.remove(at: index) } else { goals.append(goal) }
    }

    func toggle(_ interest: LearningInterest) {
        if let index = interests.firstIndex(of: interest) { interests.remove(at: index) } else { interests.append(interest) }
    }

    func toggle(_ style: LearningStyle) {
        if let index = styles.firstIndex(of: style) { styles.remove(at: index) } else { styles.append(style) }
    }

    func chooseLevel(_ level: String) {
        selfLevel = level
        levelSource = .selfAssessment
    }

    // MARK: Nawigacja

    func goForward() {
        if let next = step.next { step = next }
    }

    func goBack() {
        if step == .level && showsPlacement {
            showsPlacement = false
            return
        }
        if let previous = step.previous { step = previous }
    }

    // MARK: Test poziomu

    func startPlacement() async {
        showsPlacement = true
        guard placementPhase != .loading else { return }
        placementPhase = .loading
        let seed = UInt64(max(0, Int(Date().timeIntervalSince1970) % 1_000_000))
        let loaded = await OnboardingContentLoader.placementQuestions(seed: seed)
        guard !loaded.isEmpty else {
            placementPhase = .unavailable
            return
        }
        questions = loaded
        answers = Array(repeating: nil, count: loaded.count)
        questionIndex = 0
        placementPhase = .running
    }

    var currentQuestion: PlacementQuestion? {
        questions.indices.contains(questionIndex) ? questions[questionIndex] : nil
    }

    func answer(_ option: Int) {
        guard placementPhase == .running, answers.indices.contains(questionIndex) else { return }
        answers[questionIndex] = option
        if questionIndex + 1 < questions.count {
            questionIndex += 1
        } else {
            placementPhase = .finished(PlacementTest.result(questions: questions, answers: answers))
        }
    }

    func acceptPlacement(_ result: PlacementResult) {
        selfLevel = result.level
        levelSource = .placementTest
        showsPlacement = false
    }

    func cancelPlacement() {
        showsPlacement = false
        placementPhase = .idle
    }

    // MARK: Profil

    func makeProfile(now: Timestamp) -> LearnerProfile {
        var placementCorrect: Int?
        var placementTotal: Int?
        if levelSource == .placementTest, case .finished(let result) = placementPhase {
            placementCorrect = result.correct
            placementTotal = result.total
        }
        return LearnerProfile(
            goals: goals,
            startLevel: selfLevel,
            levelSource: selfLevel == nil ? nil : levelSource,
            placementCorrect: placementCorrect,
            placementTotal: placementTotal,
            interests: interests,
            styles: styles,
            dailyMinutes: minutes,
            createdAt: now,
            updatedAt: now
        ).normalized()
    }

    var reminderString: String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let value = String(format: "%02d:%02d", parts.hour ?? 19, parts.minute ?? 0)
        return LearnerSettings.isValidReminder(value) ? value : LearnerSettings.defaultReminder
    }

    // MARK: Podsumowanie

    var starterWordCount: Int { OnboardingPlan.starterWordCount(minutes: minutes) }

    var selectedStarterTopics: [TopicFile] {
        starterTopics.filter { $0.isSelected }.map { $0.topic }
    }

    func toggleStarterTopic(_ id: String) {
        guard let index = starterTopics.firstIndex(where: { $0.id == id }) else { return }
        starterTopics[index].isSelected.toggle()
    }

    /// Wczytuje 3 tematy dopasowane do celów i zainteresowań (raz na zestaw odpowiedzi).
    func prepareSummary(content: ContentLibrary) async {
        let profile = makeProfile(now: 0)
        let available = await content.knownTopicIDs()
        let ids = OnboardingPlan.starterTopicIDs(for: profile, available: available, limit: 3)
        if ids == starterTopics.map({ $0.id }) { return }
        isPreparingSummary = true
        var loaded: [OnboardingStarterTopic] = []
        for id in ids {
            if let topic = try? await content.topic(id: id) {
                loaded.append(OnboardingStarterTopic(topic: topic, isSelected: true))
            }
        }
        starterTopics = loaded
        isPreparingSummary = false
    }

    /// Wpisy na start: po `starterWordCount` łącznie, równo na wybrane tematy, od najprzydatniejszych.
    func starterEntryIDs() -> [(topic: TopicFile, entryIDs: [String])] {
        let topics = selectedStarterTopics
        let counts = OnboardingPlan.wordsPerTopic(total: starterWordCount, topics: topics.count)
        let level = selfLevel ?? "A2"
        var result: [(topic: TopicFile, entryIDs: [String])] = []
        for (index, topic) in topics.enumerated() {
            let ordered = TopicSearch.usefulnessOrder(topic.allEntries)
            let limit = counts.indices.contains(index) ? counts[index] : 0
            let entries = OnboardingPlan.starterEntries(ordered, level: level, limit: limit)
            result.append((topic: topic, entryIDs: entries.map { $0.id }))
        }
        return result
    }
}
