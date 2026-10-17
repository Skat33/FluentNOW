import Foundation

/// The starter set proposed at the end of the first-run interview (G4): which topics and how
/// many words, chosen from the profile. Pure functions.
public enum OnboardingPlan {
    /// Topics for a learner who answered nothing about goals and interests.
    public static let defaultTopicIDs = ["greetings-introductions", "small-talk", "restaurant"]
    /// Beginners (A1) always start with greetings.
    public static let beginnerTopicID = "greetings-introductions"

    /// Up to `limit` topic ids, best match of goals and interests first (ties: goal order, then id).
    /// Only ids in `available` are returned (all when `available` is empty).
    public static func starterTopicIDs(for profile: LearnerProfile, available: Set<String> = [], limit: Int = 3) -> [String] {
        let isAvailable = { (id: String) -> Bool in available.isEmpty || available.contains(id) }
        var ranked = profile.topicWeights()
            .filter { isAvailable($0.key) }
            .sorted { (lhs: (key: String, value: Int), rhs: (key: String, value: Int)) -> Bool in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            .map { $0.key }
        if profile.startLevel == "A1", isAvailable(beginnerTopicID) {
            ranked.removeAll { $0 == beginnerTopicID }
            ranked.insert(beginnerTopicID, at: 0)
        }
        for fallback in defaultTopicIDs where isAvailable(fallback) && !ranked.contains(fallback) {
            ranked.append(fallback)
        }
        return Array(ranked.prefix(max(0, limit)))
    }

    /// Words in the starter set for the planned daily time (5 → 15, 10 → 24, 15 → 30, 20 → 36).
    public static func starterWordCount(minutes: Int?) -> Int {
        switch minutes ?? 10 {
        case ..<8: return 15
        case 8..<13: return 24
        case 13..<18: return 30
        default: return 36
        }
    }

    /// Starter entries of one topic (already ordered by usefulness, e.g. `TopicSearch.usefulnessOrder`):
    /// levels from one below to one above the start level (A1/A2 learners: up to one above), at most
    /// `limit`; when that leaves too few, easier entries fill the list.
    public static func starterEntries(_ entries: [TopicEntry], level: String, limit: Int) -> [TopicEntry] {
        let start = CEFR.index(of: level) ?? 1
        let lowest = start >= 2 ? start - 1 : 0
        let highest = start + 1
        var chosen: [TopicEntry] = []
        var easier: [TopicEntry] = []
        for entry in entries {
            guard let index = CEFR.index(of: entry.level) else {
                chosen.append(entry)
                continue
            }
            if index > highest { continue }
            if index < lowest {
                easier.append(entry)
            } else {
                chosen.append(entry)
            }
        }
        let count = max(0, limit)
        if chosen.count < count {
            chosen.append(contentsOf: easier.prefix(count - chosen.count))
        }
        return Array(chosen.prefix(count))
    }

    /// Splits `total` words over `topics` topics (first topics get the remainder).
    public static func wordsPerTopic(total: Int, topics: Int) -> [Int] {
        guard topics > 0 else { return [] }
        let base = max(0, total) / topics
        let rest = max(0, total) % topics
        return (0..<topics).map { (index: Int) -> Int in base + (index < rest ? 1 : 0) }
    }
}
