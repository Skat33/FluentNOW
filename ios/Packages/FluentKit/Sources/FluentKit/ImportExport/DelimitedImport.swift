import Foundation

/// Result of a CSV / TSV / word-list import.
public struct DelimitedImportResult: Sendable, Hashable {
    public var state: LearnerState
    /// Newly created words.
    public var addedWords: Int
    /// Newly created meanings.
    public var addedMeanings: Int
    /// Rows skipped because the learner already has that word with that translation.
    public var skippedExisting: Int

    public init(state: LearnerState, addedWords: Int, addedMeanings: Int, skippedExisting: Int) {
        self.state = state
        self.addedWords = addedWords
        self.addedMeanings = addedMeanings
        self.skippedExisting = skippedExisting
    }
}

/// CSV / TSV / word-list import (web `parseDelimited` + `importWords`).
///
/// Columns: English, Polish, example, collection, tags (space separated), CEFR level.
/// A header row starting with `english` / `angielski` / `front` / `en` is skipped.
public enum DelimitedImport {
    /// Maximum number of rows per import.
    public static let maxRows = 500
    /// Maximum input size (characters).
    public static let maxCharacters = 2_000_000

    /// `parseDelimited`: separator = tab if present, else `;` if the first line has one, else `,`.
    /// Quoted fields with `""` escapes; `\r\n` and `\n` line endings.
    public static func parse(_ text: String) throws -> [[String]] {
        let scalars = Array(text.unicodeScalars)
        let firstLineHasSemicolon = scalars.prefix(while: { $0 != "\n" }).contains(";")
        let hasTab = scalars.contains("\t")
        let separator: Unicode.Scalar = hasTab ? "\t" : (firstLineHasSemicolon ? ";" : ",")
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var quoted = false
        var index = 0
        func finishField() -> String {
            var value = String(field)
            if value.hasSuffix("\r") { value.removeLast() }
            field = String.UnicodeScalarView()
            return value
        }
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == "\"" {
                if quoted && index + 1 < scalars.count && scalars[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    quoted.toggle()
                }
            } else if scalar == separator && !quoted {
                row.append(finishField())
            } else if scalar == "\n" && !quoted {
                row.append(finishField())
                rows.append(row)
                row = []
            } else {
                field.append(scalar)
            }
            index += 1
        }
        if quoted { throw ImportError.unclosedQuote }
        if !field.isEmpty || !row.isEmpty {
            row.append(finishField())
            rows.append(row)
        }
        return rows
    }

    /// Splits single-column lines written as `word - tłumaczenie` (also `–`, `—`, `=`).
    static func splitWordList(_ rows: [[String]]) -> [[String]] {
        guard rows.allSatisfy({ $0.count <= 1 }) else { return rows }
        let separators = [" - ", " – ", " — ", " = "]
        return rows.map { (row: [String]) -> [String] in
            guard let line = row.first else { return row }
            for separator in separators {
                if let range = line.range(of: separator) {
                    return [String(line[line.startIndex..<range.lowerBound]), String(line[range.upperBound...])]
                }
            }
            return row
        }
    }

    /// `importWords` (CSV part): adds rows as new words / meanings. Rows already present
    /// (same English term and translation, non-archived) are skipped so progress is kept.
    public static func importRows(
        _ text: String,
        into state: LearnerState,
        now: Timestamp,
        makeID: () -> String = { UUID().uuidString.lowercased() }
    ) throws -> DelimitedImportResult {
        guard text.count <= maxCharacters else { throw ImportError.tooLarge(maxMegabytes: 2) }
        var rows = splitWordList(try parse(text)).filter { row in
            row.contains { !TextScanning.trim($0).isEmpty }
        }
        if let first = rows.first?.first?.lowercased(), ["english", "angielski", "front", "en"].contains(TextScanning.trim(first)) {
            rows.removeFirst()
        }
        guard !rows.isEmpty else { throw ImportError.empty }
        guard rows.count <= maxRows else { throw ImportError.tooManyRows(max: maxRows) }

        var existing = Set<String>()
        for word in state.words where !word.archived {
            for meaning in word.meanings {
                existing.insert(TextNormalizer.normalize(word.en) + "\u{1F}" + TextNormalizer.normalize(meaning.translation))
            }
        }
        var created: [Word] = []
        var addedMeanings = 0
        var skipped = 0
        for (index, row) in rows.enumerated() {
            let en = TextScanning.trim(row[safe: 0] ?? "")
            let translation = TextScanning.trim(row[safe: 1] ?? "")
            guard !en.isEmpty, !translation.isEmpty else { throw ImportError.missingFields(row: index + 1) }
            let identity = TextNormalizer.normalize(en) + "\u{1F}" + TextNormalizer.normalize(translation)
            if existing.contains(identity) {
                skipped += 1
                continue
            }
            existing.insert(identity)
            let example = TextScanning.trim(row[safe: 2] ?? "")
            let meaning = Meaning(
                id: makeID(),
                translation: TextNormalizer.withoutDialectLabel(translation),
                examples: [example.isEmpty ? en : example],
                context: example.isEmpty ? "Dodaj zdanie przykładowe przed ćwiczeniem kontekstu." : "Import",
                register: "neutralny"
            )
            addedMeanings += 1
            if let wordIndex = created.firstIndex(where: { TextNormalizer.normalize($0.en) == TextNormalizer.normalize(en) }) {
                created[wordIndex].meanings.append(meaning)
                continue
            }
            let collectionCell = TextScanning.trim(row[safe: 3] ?? "")
            let collection = !collectionCell.isEmpty ? collectionCell : (state.collections.first ?? "Moje słowa")
            let tags = (row[safe: 4] ?? "").split(separator: " ").map(String.init).filter { !$0.isEmpty }
            created.append(Word(
                id: makeID(),
                en: en,
                level: TextScanning.trim(row[safe: 5] ?? ""),
                collection: collection,
                tags: tags,
                source: "Import",
                created: now,
                updatedAt: now,
                meanings: [meaning]
            ))
        }
        var next = state
        next.words = created + state.words
        next.collections = (state.collections + created.map { $0.collection }).uniqued()
        return DelimitedImportResult(state: next, addedWords: created.count, addedMeanings: addedMeanings, skippedExisting: skipped)
    }
}

/// Exports (web: full JSON copy, CSV for Anki, review history).
public enum StateExporter {
    /// Full copy `{ "version": 1, "state": … }`, importable by the web app and by `StateImporter`.
    public static func exportJSON(_ state: LearnerState, pretty: Bool = true) throws -> Data {
        struct Envelope: Encodable {
            let version: Int
            let state: LearnerState
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] : [.sortedKeys, .withoutEscapingSlashes]
        do {
            return try encoder.encode(Envelope(version: 1, state: state))
        } catch {
            throw ImportError.encodingFailed
        }
    }

    /// Review history `{ "version": 1, "reviews": [...] }`.
    public static func exportReviewsJSON(_ state: LearnerState) throws -> Data {
        struct Envelope: Encodable {
            let version: Int
            let reviews: [Review]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        do {
            return try encoder.encode(Envelope(version: 1, reviews: state.reviews))
        } catch {
            throw ImportError.encodingFailed
        }
    }

    /// CSV for Anki: one meaning per row (English, Polish, Example, Collection, Tags), UTF-8 BOM, CRLF.
    public static func ankiCSV(_ state: LearnerState) -> String {
        func quote(_ value: String) -> String {
            "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var lines = [["English", "Polish", "Example", "Collection", "Tags"].map(quote).joined(separator: ",")]
        for word in state.words {
            for meaning in word.meanings {
                let row = [word.en, meaning.translation, meaning.examples.first ?? "", word.collection, word.tags.joined(separator: " ")]
                lines.append(row.map(quote).joined(separator: ","))
            }
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n")
    }
}
