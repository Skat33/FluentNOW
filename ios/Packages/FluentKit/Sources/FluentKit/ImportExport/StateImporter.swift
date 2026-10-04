import Foundation

/// Import / export errors with Polish messages for the UI.
public enum ImportError: Error, LocalizedError, Sendable, Equatable {
    case empty
    case tooLarge(maxMegabytes: Int)
    case notJSON
    case notFluentExport
    case unsupportedVersion(Int)
    case invalidData(String)
    case duplicateMeaningID(String)
    case tooManyWords(max: Int)
    case emptyWord(row: Int)
    case unclosedQuote
    case tooManyRows(max: Int)
    case missingFields(row: Int)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "Wklej przynajmniej jeden wpis."
        case .tooLarge(let max):
            return "Plik jest za duży. Maksymalny rozmiar importu to \(max) MB."
        case .notJSON:
            return "To nie jest poprawny plik JSON."
        case .notFluentExport:
            return "To nie jest eksport Fluent."
        case .unsupportedVersion(let version):
            return "Nieobsługiwana wersja eksportu (\(version)). Zaktualizuj aplikację."
        case .invalidData(let detail):
            return "Niepoprawna kopia Fluent: \(detail)"
        case .duplicateMeaningID(let id):
            return "Niepoprawna kopia Fluent: identyfikator znaczenia „\(id)” występuje więcej niż raz."
        case .tooManyWords(let max):
            return "Kopia zawiera za dużo słów (limit \(max))."
        case .emptyWord(let row):
            return "Słowo nr \(row) nie ma tekstu angielskiego, tłumaczenia lub znaczeń."
        case .unclosedQuote:
            return "Niedomknięty cudzysłów w pliku."
        case .tooManyRows(let max):
            return "Importuj do \(max) znaczeń naraz."
        case .missingFields(let row):
            return "Wiersz \(row): potrzebne jest słowo i polskie tłumaczenie."
        case .encodingFailed:
            return "Nie udało się przygotować eksportu."
        }
    }
}

/// Full JSON import (web export `{ "version": 1, "state": … }` or a bare state).
public enum StateImporter {
    /// Default maximum size of an imported file.
    public static let defaultMaxBytes = 50 * 1024 * 1024
    /// Maximum number of words in an imported state.
    public static let maxWords = 50_000

    private struct Envelope: Decodable {
        let version: Int?
        let state: LearnerState?

        enum CodingKeys: String, CodingKey {
            case version, state
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = c.lenientOptionalInt(.version)
            if c.contains(.state) {
                state = try c.decode(LearnerState.self, forKey: .state)
            } else {
                state = nil
            }
        }
    }

    private struct ShapeProbe: Decodable {
        let hasWords: Bool
        let hasState: Bool

        enum CodingKeys: String, CodingKey {
            case words, state
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            hasWords = c.contains(.words)
            hasState = c.contains(.state)
        }
    }

    /// Decodes, migrates and validates a full export. Throws `ImportError`.
    public static func importJSON(_ data: Data, maxBytes: Int = defaultMaxBytes) throws -> LearnerState {
        guard !data.isEmpty else { throw ImportError.empty }
        guard data.count <= maxBytes else { throw ImportError.tooLarge(maxMegabytes: max(1, maxBytes / (1024 * 1024))) }
        let decoder = JSONDecoder()
        let probe: ShapeProbe
        do {
            probe = try decoder.decode(ShapeProbe.self, from: data)
        } catch {
            throw ImportError.notJSON
        }
        let decoded: LearnerState
        do {
            if probe.hasState {
                let envelope = try decoder.decode(Envelope.self, from: data)
                if let version = envelope.version, version != 1 { throw ImportError.unsupportedVersion(version) }
                guard let state = envelope.state else { throw ImportError.notFluentExport }
                decoded = state
            } else if probe.hasWords {
                decoded = try decoder.decode(LearnerState.self, from: data)
            } else {
                throw ImportError.notFluentExport
            }
        } catch let error as ImportError {
            throw error
        } catch let error as DecodingError {
            throw ImportError.invalidData(DecodingErrorDescriber.describe(error))
        } catch {
            throw ImportError.invalidData(error.localizedDescription)
        }
        let migrated = StateMigration.migrate(decoded)
        try StateValidator.validate(migrated)
        return migrated
    }
}

/// Structural validation of a (migrated) state.
public enum StateValidator {
    /// Throws the first problem found: too many words, empty words / translations, duplicate
    /// meaning ids (duplicate word ids are merged by `StateMigration`).
    public static func validate(_ state: LearnerState, maxWords: Int = StateImporter.maxWords) throws {
        guard state.words.count <= maxWords else { throw ImportError.tooManyWords(max: maxWords) }
        var meaningIDs = Set<String>()
        for (index, word) in state.words.enumerated() {
            if TextScanning.trim(word.en).isEmpty || word.meanings.isEmpty {
                throw ImportError.emptyWord(row: index + 1)
            }
            for meaning in word.meanings {
                if TextScanning.trim(meaning.translation).isEmpty { throw ImportError.emptyWord(row: index + 1) }
                guard meaningIDs.insert(meaning.id).inserted else { throw ImportError.duplicateMeaningID(meaning.id) }
            }
        }
    }

    /// Non-throwing check.
    public static func isValid(_ state: LearnerState) -> Bool {
        (try? validate(state)) != nil
    }
}
