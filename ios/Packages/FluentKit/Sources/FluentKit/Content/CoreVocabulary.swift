import Foundation

/// Core vocabulary (CONTENT-SCHEMA §6, FEEDBACK-7): general English outside the situational topics.
///
/// Files `Content/core/core-c01.json`, `core-c02.json`, … use the `TopicFile` format with
/// `group: "core"`; entry ids are `core.<kebab-term>` (`-2`, `-3` for further senses) and do not
/// depend on the shard, and every meaning has 3–5 examples. Core is **not a topic**: it is never
/// listed in `topics/index.json` nor in topic search; its entries reach the learner through the
/// dictionary index (`r` = `core-c01/core.attain`), recommendations, reading glossaries and tests.
public enum CoreVocabulary {
    /// Directory inside `Content/`.
    public static let directory = "core"
    /// `TopicFile.group` of core files.
    public static let group = "core"
    /// Prefix of core file ids (`core-c01`).
    public static let filePrefix = "core-c"
    /// Prefix of core entry ids (`core.attain`).
    public static let entryPrefix = "core."
    /// Collection name of words added from core (= `namePl` of every core file).
    public static let collectionName = "Słownictwo ogólne"
    /// Allowed number of examples per core meaning.
    public static let exampleRange: ClosedRange<Int> = 3...5

    /// `true` for a core shard id such as `core-c01`.
    public static func isCoreFile(_ id: String) -> Bool {
        guard id.hasPrefix(filePrefix) else { return false }
        let digits = id.dropFirst(filePrefix.count)
        return !digits.isEmpty && digits.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// `true` for a core entry id such as `core.attain` or `core.maintain-2`.
    public static func isCoreEntryID(_ id: String) -> Bool {
        id.hasPrefix(entryPrefix) && id.count > entryPrefix.count
    }

    /// `true` for a decoded core file (by id or group).
    public static func isCore(_ topic: TopicFile) -> Bool {
        isCoreFile(topic.id) || topic.group == group
    }

    /// Path of a core file relative to `Content/` (`core/core-c01.json`).
    public static func relativePath(file id: String) -> String {
        "\(directory)/\(id).json"
    }

    /// Sorted core file ids among directory entries (`["core-c01.json", "notes.txt"]` → `["core-c01"]`).
    public static func fileIDs(fromFileNames names: [String]) -> [String] {
        names.compactMap { (name: String) -> String? in
            guard name.hasSuffix(".json") else { return nil }
            let id = String(name.dropLast(5))
            return isCoreFile(id) ? id : nil
        }
        .sorted()
    }

    /// Hard schema problems of a core entry (the error level of `validate-content.mjs` without the
    /// English heuristics): the topic rules with 3–5 examples and the `core.` id prefix.
    public static func entryIssues(_ entry: TopicEntry) -> [String] {
        var result = TopicEntryValidator.issues(entry, exampleCounts: exampleRange)
        if !isCoreEntryID(entry.id) {
            result.append("Identyfikator wpisu core musi zaczynać się od „\(entryPrefix)”.")
        }
        return result
    }
}

public extension ContentReference {
    /// `true` for entries of the core vocabulary (`core-c01/core.attain`).
    var isCore: Bool { CoreVocabulary.isCoreFile(file) }

    /// Path of the file holding the entry, relative to `Content/`:
    /// `starter-words.json`, `core/core-c01.json` or `topics/<id>.json`.
    var relativePath: String {
        if isStarter { return "starter-words.json" }
        if isCore { return CoreVocabulary.relativePath(file: file) }
        return "topics/\(file).json"
    }
}

public extension ContentDecoder {
    /// Decodes a core file `core/core-cNN.json` (a `TopicFile` with `group: "core"`).
    static func coreFile(from data: Data) throws -> TopicFile {
        try decode(TopicFile.self, from: data, file: "core")
    }
}
