import Foundation

/// Errors while decoding built-in content files.
public enum ContentError: Error, LocalizedError, Sendable, Equatable {
    case unreadable(file: String)
    case invalidJSON(file: String, detail: String)
    case unsupportedVersion(file: String, version: Int)

    public var errorDescription: String? {
        switch self {
        case .unreadable(let file):
            return "Nie można odczytać pliku treści „\(file)”."
        case .invalidJSON(let file, let detail):
            return "Plik treści „\(file)” jest uszkodzony: \(detail)"
        case .unsupportedVersion(let file, let version):
            return "Plik treści „\(file)” ma nieobsługiwaną wersję schematu (\(version)). Zaktualizuj aplikację."
        }
    }
}

/// Decodes content files described in CONTENT-SCHEMA.md. Call off the main thread.
public enum ContentDecoder {
    /// Highest supported `schemaVersion`.
    public static let supportedSchemaVersion = 1

    private struct VersionProbe: Decodable {
        let schemaVersion: Int?
    }

    /// Decodes any content type and checks `schemaVersion`.
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data, file: String = "") throws -> T {
        if let probe = try? JSONDecoder().decode(VersionProbe.self, from: data),
           let version = probe.schemaVersion, version > supportedSchemaVersion {
            throw ContentError.unsupportedVersion(file: file, version: version)
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let error as DecodingError {
            throw ContentError.invalidJSON(file: file, detail: DecodingErrorDescriber.describe(error))
        } catch {
            throw ContentError.invalidJSON(file: file, detail: error.localizedDescription)
        }
    }

    public static func topicFile(from data: Data) throws -> TopicFile {
        try decode(TopicFile.self, from: data, file: "topics")
    }

    public static func topicIndex(from data: Data) throws -> TopicIndex {
        try decode(TopicIndex.self, from: data, file: "topics/index.json")
    }

    public static func dictionaryIndex(from data: Data) throws -> DictionaryIndex {
        try decode(DictionaryIndex.self, from: data, file: "dictionary-index.json")
    }

    public static func grammarLevel(from data: Data) throws -> GrammarLevelFile {
        try decode(GrammarLevelFile.self, from: data, file: "grammar")
    }

    public static func exercises(from data: Data) throws -> ProductionBank {
        try decode(ProductionBank.self, from: data, file: "exercises.json")
    }

    public static func idioms(from data: Data) throws -> IdiomBank {
        try decode(IdiomBank.self, from: data, file: "idioms.json")
    }

    public static func readings(from data: Data) throws -> ReadingBank {
        try decode(ReadingBank.self, from: data, file: "readings.json")
    }

    public static func starterWords(from data: Data) throws -> StarterWords {
        try decode(StarterWords.self, from: data, file: "starter-words.json")
    }

    public static func recommendations(from data: Data) throws -> RecommendationBank {
        try decode(RecommendationBank.self, from: data, file: "recommendations.json")
    }

    public static func answerVariants(from data: Data) throws -> AnswerVariants {
        try decode(AnswerVariants.self, from: data, file: "answer-variants.json")
    }
}

/// Turns `DecodingError` into a short Polish description with the JSON path.
enum DecodingErrorDescriber {
    static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(_, let context):
            return "pole „\(path(context.codingPath))” ma niepoprawny typ."
        case .valueNotFound(_, let context):
            return "brakuje wartości pola „\(path(context.codingPath))”."
        case .keyNotFound(let key, let context):
            return "brakuje pola „\(path(context.codingPath + [key]))”."
        case .dataCorrupted(let context):
            if context.codingPath.isEmpty {
                return "to nie jest poprawny plik JSON."
            }
            return "niepoprawna wartość pola „\(path(context.codingPath))”."
        @unknown default:
            return "nieznany błąd danych."
        }
    }

    static func path(_ codingPath: [CodingKey]) -> String {
        var result = ""
        for key in codingPath {
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                result += result.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return result.isEmpty ? "(główny obiekt)" : result
    }
}
