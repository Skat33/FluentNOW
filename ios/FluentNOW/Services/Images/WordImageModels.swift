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
    /// Day number (`FluentClock` ms / day) the counters below belong to (H2: daily limits).
    var counterDay: Int
    /// Searches made on `counterDay` (anonymous Openverse limit: 200 per day).
    var searchesToday: Int
    /// Thumbnails downloaded on `counterDay` (anonymous limit: 1000 per day).
    var downloadsToday: Int
    /// End of the last background run (ms, 0 = never).
    var lastRunAt: Timestamp
    /// Polish description of the last problem (`nil` = the last run went fine).
    var lastError: String?

    init(
        version: Int = 2,
        assignments: [WordImageAssignment] = [],
        blockedUntil: Timestamp = 0,
        counterDay: Int = 0,
        searchesToday: Int = 0,
        downloadsToday: Int = 0,
        lastRunAt: Timestamp = 0,
        lastError: String? = nil
    ) {
        self.version = version
        self.assignments = assignments
        self.blockedUntil = blockedUntil
        self.counterDay = counterDay
        self.searchesToday = searchesToday
        self.downloadsToday = downloadsToday
        self.lastRunAt = lastRunAt
        self.lastError = lastError
    }

    enum CodingKeys: String, CodingKey {
        case version, assignments, blockedUntil, counterDay, searchesToday, downloadsToday, lastRunAt, lastError
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? 1
        // A damaged entry must not wipe the other assignments.
        let lossy = (try? c.decode([FailableImageAssignment].self, forKey: .assignments)) ?? []
        assignments = lossy.compactMap { $0.value }
        blockedUntil = (try? c.decode(Double.self, forKey: .blockedUntil)) ?? 0
        // Fields added in FEEDBACK-3 H2 — missing in files written by the first version.
        counterDay = (try? c.decode(Int.self, forKey: .counterDay)) ?? 0
        searchesToday = (try? c.decode(Int.self, forKey: .searchesToday)) ?? 0
        downloadsToday = (try? c.decode(Int.self, forKey: .downloadsToday)) ?? 0
        lastRunAt = (try? c.decode(Double.self, forKey: .lastRunAt)) ?? 0
        lastError = try? c.decode(String.self, forKey: .lastError)
    }
}

/// Result of one background run (`WordImageService.prefetch`).
struct WordImagePrefetchReport: Sendable, Equatable {
    enum Stop: Sendable, Equatable {
        /// Every candidate handled.
        case finished
        /// Another run is in progress — nothing done.
        case busy
        /// No network service (previews, tests).
        case disabled
        /// No internet connection.
        case offline
        /// Openverse asked to slow down (HTTP 429) or we are still waiting after one.
        case rateLimited
        /// Daily search / download budget used up.
        case dailyLimit
        /// Per-run limit reached — more candidates are waiting for the next run.
        case runLimit
        /// The task was cancelled (app went to the background).
        case cancelled
    }

    var searches = 0
    var downloads = 0
    var stop: Stop = .finished
}

/// Numbers for the settings diagnostics (H2).
struct WordImageDiagnostics: Sendable, Equatable {
    /// Meanings whose photo is on disk.
    var cachedCount: Int
    /// Meanings searched without a usable photo (retried after 14 days).
    var emptyCount: Int
    var searchesToday: Int
    var downloadsToday: Int
    /// End of the last background run (ms, 0 = never).
    var lastRunAt: Timestamp
    var lastError: String?
    /// No searches before this time (ms) after an HTTP 429.
    var blockedUntil: Timestamp
    /// `false` in previews and tests.
    var networkEnabled: Bool
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
