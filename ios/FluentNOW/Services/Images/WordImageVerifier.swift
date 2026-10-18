import Foundation

/// Decision of layer 2 for one photo.
struct WordImageDecision: Sendable, Equatable {
    var accepted: Bool
    /// Stable code (see `WordImageVerifier`).
    var code: String
    /// Polish explanation for diagnostics and reports.
    var reason: String
}

/// A group of Vision identifiers that contradicts the expected subject above a confidence.
struct WordImageConflictRule: Sendable, Equatable {
    /// Polish group name („zwierzę lub owad”).
    var name: String
    var labels: Set<String>
    var threshold: Double
}

/// Layer 2: does the photo really show the word? Pure decision from the title/tag match and the
/// labels of Vision's on-device classifier (`VNClassifyImageRequest`).
///
/// Order of the rules:
/// 1. no Vision labels (classification unavailable) → accept only a strong title/tag match;
/// 2. an expected identifier ≥ 50 % → accept (`vision-match`);
/// 3. a contradicting class above its threshold (animal/insect at a thing, person at a thing,
///    landscape, text/drawing, fire…) → reject (`vision-conflict`);
/// 4. an expected identifier ≥ 15 % → accept (`vision-weak-match`);
/// 5. animals and food must at least look like animals/food (`vision-wrong-kind`);
/// 6. a broader identifier ≥ 35 % with a strong title/tag match → accept (`vision-related`);
/// 7. the word has an identifier in the taxonomy but Vision did not see it → reject
///    (`vision-missing`);
/// 8. no identifier for the word → accept a strong title/tag match (`metadata-only`), reject the
///    rest (`weak-metadata`).
enum WordImageVerifier {
    /// Bump when the rules change: every stored verdict of an older version is checked again
    /// (local files, no network) and photos that no longer pass disappear.
    static let rulesVersion = 1

    static let strongMatch = 0.5
    static let weakMatch = 0.15
    static let relatedMatch = 0.35
    static let kindMatch = 0.3

    /// Expected identifiers that the device can actually report (`taxonomy` = its
    /// `supportedIdentifiers()`; without it only the hand-mapped identifiers count).
    static func expectedLabels(_ profile: WordImageTermProfile, taxonomy: Set<String>?) -> [String] {
        guard let taxonomy else { return profile.mappedLabels }
        return profile.expectedLabels.filter { (label: String) -> Bool in taxonomy.contains(label) }
    }

    /// `true` when Vision can confirm this word (it has an identifier in the taxonomy).
    static func hasVisionEquivalent(_ profile: WordImageTermProfile, taxonomy: Set<String>?) -> Bool {
        !expectedLabels(profile, taxonomy: taxonomy).isEmpty
    }

    static func decide(
        profile: WordImageTermProfile,
        metadata: WordImageMetadataMatch,
        labels: [WordImageLabel]?,
        taxonomy: Set<String>?
    ) -> WordImageDecision {
        guard let labels else {
            if metadata == .strong {
                return WordImageDecision(accepted: true, code: "metadata-no-vision", reason: "Vision niedostępny — przyjęte, bo tytuł lub tagi zdjęcia nazywają hasło.")
            }
            return WordImageDecision(accepted: false, code: "no-vision-weak-metadata", reason: "Vision niedostępny, a tytuł zdjęcia nie potwierdza hasła.")
        }
        let expected = Set(expectedLabels(profile, taxonomy: taxonomy))
        let exactHit = strongest(labels, in: expected)
        if let hit = exactHit, hit.confidence >= strongMatch {
            return WordImageDecision(accepted: true, code: "vision-match", reason: "Vision rozpoznał „\(hit.identifier)” (\(percent(hit.confidence))).")
        }
        let own = expected.union(profile.relatedLabels)
        if let conflict = strongestConflict(labels, subject: profile.subject, excluding: own) {
            return WordImageDecision(
                accepted: false,
                code: "vision-conflict",
                reason: "Vision widzi „\(conflict.label.identifier)” (\(percent(conflict.label.confidence))) — \(conflict.rule.name), nie „\(profile.term)”."
            )
        }
        if let hit = exactHit, hit.confidence >= weakMatch {
            return WordImageDecision(accepted: true, code: "vision-weak-match", reason: "Vision dostrzega „\(hit.identifier)” (\(percent(hit.confidence))) i nic sprzecznego.")
        }
        if let kind = requiredKind(for: profile.subject), (strongest(labels, in: kind.labels)?.confidence ?? 0) < kindMatch {
            return WordImageDecision(accepted: false, code: "vision-wrong-kind", reason: "Vision nie widzi na zdjęciu \(kind.name).")
        }
        if metadata == .strong, let related = strongest(labels, in: Set(profile.relatedLabels)), related.confidence >= relatedMatch {
            return WordImageDecision(accepted: true, code: "vision-related", reason: "Tytuł nazywa hasło, Vision widzi „\(related.identifier)” (\(percent(related.confidence))).")
        }
        if !expected.isEmpty {
            let names = expected.sorted().prefix(3).joined(separator: ", ")
            return WordImageDecision(accepted: false, code: "vision-missing", reason: "Vision nie rozpoznał na zdjęciu „\(names)”.")
        }
        if metadata == .strong {
            return WordImageDecision(accepted: true, code: "metadata-only", reason: "Hasła nie ma w taksonomii Vision — przyjęte na podstawie tytułu, bez sprzecznych etykiet.")
        }
        return WordImageDecision(accepted: false, code: "weak-metadata", reason: "Ani Vision, ani tytuł zdjęcia nie potwierdzają hasła.")
    }

    // MARK: Rules

    /// Classes that contradict a subject, with their confidence thresholds.
    static func conflictRules(for subject: WordImageSubject) -> [WordImageConflictRule] {
        let living = WordImageConflictRule(name: "zwierzę lub owad", labels: WordImageVisionLabels.living, threshold: 0.6)
        let people = WordImageConflictRule(name: "osoba", labels: WordImageVisionLabels.people, threshold: 0.85)
        let scenery = WordImageConflictRule(name: "krajobraz", labels: WordImageVisionLabels.scenery, threshold: 0.8)
        // 0.7: a pen on a notepad also shows `handwriting`; a screenshot or a map scores higher.
        let textual = WordImageConflictRule(name: "tekst, rysunek lub mapa", labels: WordImageVisionLabels.textual, threshold: 0.7)
        let fire = WordImageConflictRule(name: "ogień", labels: WordImageVisionLabels.fire, threshold: 0.6)
        let food = WordImageConflictRule(name: "jedzenie", labels: WordImageVisionLabels.food, threshold: 0.8)
        switch subject {
        case .object:
            return [living, people, scenery, textual, fire, food]
        case .wearable:
            return [living, raised(scenery, to: 0.85), textual, fire, food]
        case .food:
            return [living, people, raised(scenery, to: 0.85), textual, raised(fire, to: 0.7)]
        case .animal:
            return [raised(people, to: 0.9), textual, fire, raised(food, to: 0.85)]
        case .plant:
            return [living, people, textual, fire]
        case .place:
            return [raised(living, to: 0.75), raised(people, to: 0.9), textual, raised(fire, to: 0.75)]
        case .person:
            return [living, raised(scenery, to: 0.85), textual, fire, food]
        case .artwork:
            return [raised(living, to: 0.8), raised(fire, to: 0.7)]
        }
    }

    /// Animals and food must look like animals / food (a word without an own identifier, e.g.
    /// „bat” the animal, is still never shown as a baseball scene).
    static func requiredKind(for subject: WordImageSubject) -> (name: String, labels: Set<String>)? {
        switch subject {
        case .animal: return (name: "zwierzęcia", labels: WordImageVisionLabels.living)
        case .food: return (name: "jedzenia", labels: WordImageVisionLabels.food)
        case .object, .wearable, .plant, .place, .person, .artwork: return nil
        }
    }

    static func strongest(_ labels: [WordImageLabel], in set: Set<String>) -> WordImageLabel? {
        guard !set.isEmpty else { return nil }
        var best: WordImageLabel?
        for label in labels where set.contains(label.identifier) {
            if label.confidence > (best?.confidence ?? -1) {
                best = label
            }
        }
        return best
    }

    /// The most confident label of a contradicting class (labels the word itself expects are
    /// never a conflict: a bee is an insect).
    static func strongestConflict(
        _ labels: [WordImageLabel],
        subject: WordImageSubject,
        excluding own: Set<String>
    ) -> (rule: WordImageConflictRule, label: WordImageLabel)? {
        var best: (rule: WordImageConflictRule, label: WordImageLabel)?
        for rule in conflictRules(for: subject) {
            for label in labels where rule.labels.contains(label.identifier) && !own.contains(label.identifier) {
                guard label.confidence >= rule.threshold else { continue }
                if label.confidence > (best?.label.confidence ?? -1) {
                    best = (rule: rule, label: label)
                }
            }
        }
        return best
    }

    private static func raised(_ rule: WordImageConflictRule, to threshold: Double) -> WordImageConflictRule {
        var copy = rule
        copy.threshold = threshold
        return copy
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}
