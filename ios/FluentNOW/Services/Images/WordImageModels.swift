import Foundation
import FluentKit

/// One photo found for a word (Openverse result, CC0 / CC BY / CC BY-SA).
struct WordImageRecord: Codable, Hashable, Sendable, Identifiable {
    /// Openverse identifier (UUID).
    var id: String
    var title: String
    /// Scaled, compressed thumbnail served by Openverse (what we download and show).
    var thumbnailURL: String
    /// Original file (for the report / attribution only).
    var originalURL: String
    /// Page of the work at its source (Flickr, Wikimedia Commons…).
    var landingURL: String
    var creator: String
    var creatorURL: String?
    /// `cc0`, `by`, `by-sa`.
    var license: String
    var licenseVersion: String
    var licenseURL: String
    /// Source collection (`flickr`, `wikimedia`…).
    var provider: String
    /// Service the photo came from (`openverse`).
    var service: String

    /// „CC BY 2.0”, „CC BY-SA 4.0”, „CC0 1.0”.
    var licenseLabel: String {
        let name = license.lowercased() == "cc0" ? "CC0" : "CC " + license.uppercased()
        return licenseVersion.isEmpty ? name : "\(name) \(licenseVersion)"
    }

    /// CC BY / BY-SA require naming the author under the photo.
    var requiresAttribution: Bool {
        license.lowercased() != "cc0"
    }

    /// Short attribution: „Fot. Jan Kowalski · CC BY 2.0”.
    var attributionLine: String {
        let author = creator.trimmingCharacters(in: .whitespacesAndNewlines)
        if author.isEmpty { return licenseLabel }
        return "Fot. \(author) · \(licenseLabel)"
    }

    /// Local file name in the image cache.
    var fileName: String {
        let safe = id.filter { (character: Character) -> Bool in
            character.isLetter || character.isNumber || character == "-"
        }
        return (safe.isEmpty ? "image" : safe) + ".jpg"
    }
}

/// Permanent assignment word meaning → photo (the same photo at every review).
struct WordImageAssignment: Codable, Hashable, Sendable {
    var meaningId: String
    var wordId: String
    var term: String
    var query: String
    /// Usable search results in relevance order (reports move to the next one, no new search).
    var candidates: [WordImageRecord]
    /// Photo in use (`nil` = none left / not chosen yet).
    var chosenID: String?
    /// Photos reported as not matching — never used again for this meaning.
    var rejectedIDs: [String]
    /// When the search was made (ms); searches with no result are retried after a while.
    var searchedAt: Timestamp

    var chosen: WordImageRecord? {
        guard let chosenID else { return nil }
        return candidates.first { $0.id == chosenID }
    }

    /// The next candidate that was not reported.
    var nextCandidate: WordImageRecord? {
        candidates.first { !rejectedIDs.contains($0.id) }
    }
}

/// Stored file `word-images.json` (Application Support).
struct WordImageStoreFile: Codable, Sendable {
    var version: Int
    var assignments: [WordImageAssignment]
    /// Openverse asked us to slow down (HTTP 429) — no searches before this time (ms).
    var blockedUntil: Timestamp

    init(version: Int = 1, assignments: [WordImageAssignment] = [], blockedUntil: Timestamp = 0) {
        self.version = version
        self.assignments = assignments
        self.blockedUntil = blockedUntil
    }

    enum CodingKeys: String, CodingKey {
        case version, assignments, blockedUntil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        // A damaged entry must not wipe the other assignments.
        let lossy = (try? c.decode([FailableImageAssignment].self, forKey: .assignments)) ?? []
        assignments = lossy.compactMap { $0.value }
        blockedUntil = (try? c.decode(Double.self, forKey: .blockedUntil)) ?? 0
    }
}

/// Decodes one assignment or `nil` (tolerant array decoding).
private struct FailableImageAssignment: Decodable {
    let value: WordImageAssignment?

    init(from decoder: Decoder) throws {
        value = try? WordImageAssignment(from: decoder)
    }
}

/// A photo ready to show: record + file on disk.
struct WordImage: Hashable, Sendable {
    var meaningId: String
    var record: WordImageRecord
    var fileURL: URL
}

/// Report „Zdjęcie nie pasuje” (G2) — stored in `image-reports.json`, separately from
/// exercise reports.
struct ImageReport: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var createdAt: Timestamp
    var term: String
    /// Polish meaning of the word in the exercise.
    var meaning: String
    var wordId: String
    var meaningId: String
    var imageID: String
    var imageURL: String
    var originalURL: String
    var landingURL: String
    /// `openverse/flickr`…
    var source: String
    var license: String
    var comment: String

    init(
        id: String = UUID().uuidString.lowercased(),
        createdAt: Timestamp = FluentClock.now(),
        term: String,
        meaning: String,
        wordId: String,
        meaningId: String,
        record: WordImageRecord,
        comment: String = ""
    ) {
        self.id = id
        self.createdAt = createdAt
        self.term = term
        self.meaning = meaning
        self.wordId = wordId
        self.meaningId = meaningId
        self.imageID = record.id
        self.imageURL = record.thumbnailURL
        self.originalURL = record.originalURL
        self.landingURL = record.landingURL
        self.source = "\(record.service)/\(record.provider)"
        self.license = record.licenseLabel
        self.comment = comment
    }
}
