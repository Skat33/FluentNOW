import Foundation
import FluentKit

/// Google Gemini przez REST (`generativelanguage.googleapis.com/v1beta`), klucz użytkownika.
///
/// - odpowiedzi strukturalne (`responseMimeType: application/json` + `responseJsonSchema`),
///   walidowane dekodowaniem typów FluentKit (`Lookup`) i `AssistantValidation`,
/// - lista modeli z fallbackiem jak `lib/gemini.ts` strony (404 → następny model;
///   408/5xx → ponowienie z wykładniczym opóźnieniem; 429 → jedno ponowienie, potem błąd),
/// - limit czasu 20 s, błędy po polsku z kodem HTTP; klucz nigdy nie trafia do logów.
struct GeminiAssistant: LanguageAssistant {
    let apiKey: String
    let models: [String]
    let session: URLSession

    static let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    /// Kolejność jak `GEMINI_FALLBACKS` na stronie (zweryfikowane przez stronę 2026-09-09).
    static let defaultModels = [
        "gemini-3.8-flash",
        "gemini-3.7-flash",
        "gemini-3.6-flash",
        "gemini-3.5-flash",
        "gemini-2.5-flash"
    ]
    static let timeout: TimeInterval = 20
    static let maxTransientAttempts = 3

    init(apiKey: String, preferredModel: String? = nil, session: URLSession = .shared) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        var list = Self.defaultModels
        if let preferredModel, !preferredModel.isEmpty {
            list.removeAll { $0 == preferredModel }
            list.insert(preferredModel, at: 0)
        }
        self.models = list
        self.session = session
    }

    /// Poprawność formatu klucza (jak `validKey` strony).
    static func isPlausibleKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 16 && trimmed.count <= 512 && !trimmed.contains(where: { $0.isWhitespace })
    }

    // MARK: - LanguageAssistant

    func lookup(term: String) async throws -> Lookup {
        let output = try await generate(
            instructions: AssistantPrompts.lookup,
            input: AssistantPrompts.lookupPayload(term: term),
            schema: Self.lookupSchema
        )
        let decoded: Lookup
        do {
            decoded = try JSONDecoder().decode(Lookup.self, from: output)
        } catch {
            throw AssistantError.invalidResponse("niepoprawny JSON wyszukania")
        }
        return try AssistantValidation.sanitize(decoded, term: term)
    }

    func grade(_ request: GradeRequest) async throws -> Grade? {
        let output = try await generate(
            instructions: AssistantPrompts.grade(type: request.exerciseType),
            input: AssistantPrompts.gradePayload(request),
            schema: Self.gradeSchema
        )
        guard let object = try? JSONSerialization.jsonObject(with: output) as? [String: Any],
              let verdict = object["verdict"] as? String else {
            return nil
        }
        let explanation = object["explanation"] as? String ?? ""
        let spelling = object["spellingCorrect"] as? Bool ?? true
        return AssistantValidation.grade(verdict: verdict, explanation: explanation, spellingCorrect: spelling)
    }

    // MARK: - Połączenie

    /// Sprawdza klucz (lista modeli) i zwraca najlepszy zgodny model tekstowy.
    func verifyConnection() async throws -> String {
        let available = try await listModels()
        let compatible = Self.compatibleModels(available)
        if let match = models.first(where: { compatible.contains($0) }) {
            return match
        }
        if let best = compatible.first {
            return best
        }
        throw AssistantError.http(status: 404, message: "Gemini nie udostępnia teraz zgodnego modelu Flash dla tego klucza.")
    }

    /// Nazwy modeli obsługujących `generateContent`.
    func listModels() async throws -> [String] {
        var names: [String] = []
        var token = ""
        for _ in 0..<10 {
            guard var components = URLComponents(string: Self.baseURL + "/models") else {
                throw AssistantError.invalidResponse("adres")
            }
            var items = [URLQueryItem(name: "pageSize", value: "1000")]
            if !token.isEmpty { items.append(URLQueryItem(name: "pageToken", value: token)) }
            components.queryItems = items
            guard let url = components.url else { throw AssistantError.invalidResponse("adres") }
            var request = URLRequest(url: url, timeoutInterval: Self.timeout)
            request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
            let data = try await send(request)
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw AssistantError.invalidResponse("lista modeli")
            }
            for model in object["models"] as? [[String: Any]] ?? [] {
                let methods = model["supportedGenerationMethods"] as? [String] ?? []
                guard methods.contains("generateContent"), let name = model["name"] as? String else { continue }
                names.append(name.hasPrefix("models/") ? String(name.dropFirst("models/".count)) : name)
            }
            token = object["nextPageToken"] as? String ?? ""
            if token.isEmpty { break }
        }
        return names
    }

    /// Filtr i kolejność jak `compatibleGeminiModels(…, "text")` strony.
    static func compatibleModels(_ available: [String]) -> [String] {
        let excluded = ["tts", "audio", "image", "embedding", "embed", "live", "robotics", "computer"]
        let filtered = Array(Set(available)).filter { model in
            let name = model.lowercased()
            guard name.hasPrefix("gemini-"), name.contains("flash") else { return false }
            return !excluded.contains { name.contains($0) }
        }
        return filtered.sorted { a, b in
            let va = version(a)
            let vb = version(b)
            if va != vb { return va > vb }
            let pa = isPreview(a)
            let pb = isPreview(b)
            if pa != pb { return !pa }
            let la = a.contains("lite")
            let lb = b.contains("lite")
            if la != lb { return !la }
            let ia = defaultModels.firstIndex(of: a)
            let ib = defaultModels.firstIndex(of: b)
            switch (ia, ib) {
            case let (x?, y?): return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return a > b
            }
        }
    }

    private static func version(_ model: String) -> Double {
        if model.contains("latest") { return Double.greatestFiniteMagnitude }
        let rest = model.dropFirst("gemini-".count)
        var digits = ""
        for character in rest {
            if character.isNumber || character == "." { digits.append(character) } else { break }
        }
        if digits.hasSuffix(".") { digits.removeLast() }
        return Double(digits) ?? 0
    }

    private static func isPreview(_ model: String) -> Bool {
        model.contains("preview") || model.contains("experimental") || model.contains("exp")
    }

    // MARK: - Generowanie

    private func generate(instructions: String, input: String, schema: [String: Any]) async throws -> Data {
        guard !apiKey.isEmpty else { throw AssistantError.missingKey }
        var transientAttempts = 0
        var lastError: Error = AssistantError.http(status: 404, message: "Brak zgodnego modelu.")
        for model in models {
            var rateLimitRetried = false
            while true {
                do {
                    return try await generateOnce(model: model, instructions: instructions, input: input, schema: schema)
                } catch let error as AssistantError {
                    lastError = error
                    guard case .http(let status, _) = error else { throw error }
                    if status == 404 { break }                       // model niedostępny → następny
                    if status == 429 {
                        if rateLimitRetried { throw error }          // limit konta: nie męczymy dalej
                        rateLimitRetried = true
                        try await backoff(attempt: 1)
                        continue
                    }
                    guard [408, 500, 502, 503, 504].contains(status) else { throw error }
                    transientAttempts += 1
                    if transientAttempts >= Self.maxTransientAttempts { throw error }
                    try await backoff(attempt: transientAttempts)
                    break                                            // przeciążenie → model zapasowy
                }
            }
        }
        throw lastError
    }

    private func backoff(attempt: Int) async throws {
        let seconds = min(8.0, pow(2.0, Double(attempt - 1)))
        do {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        } catch {
            throw AssistantError.cancelled
        }
    }

    private func generateOnce(model: String, instructions: String, input: String, schema: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(Self.baseURL)/models/\(model):generateContent") else {
            throw AssistantError.invalidResponse("adres modelu")
        }
        var generationConfig: [String: Any] = [
            "maxOutputTokens": 8192,
            "responseMimeType": "application/json",
            "responseJsonSchema": schema
        ]
        if model.hasPrefix("gemini-3") {
            generationConfig["thinkingConfig"] = ["thinkingLevel": "LOW"]
        }
        let body: [String: Any] = [
            "store": false,
            "systemInstruction": ["parts": [["text": AssistantPrompts.system + instructions]]],
            "contents": [["role": "user", "parts": [["text": input]]]],
            "generationConfig": generationConfig
        ]
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw AssistantError.invalidResponse("zapytanie")
        }
        let data = try await send(request)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = object["candidates"] as? [[String: Any]],
              let candidate = candidates.first else {
            throw AssistantError.invalidResponse("brak odpowiedzi")
        }
        guard (candidate["finishReason"] as? String) == "STOP" else {
            throw AssistantError.invalidResponse("odpowiedź niepełna")
        }
        let content = candidate["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]] ?? []
        let text = parts
            .filter { ($0["thought"] as? Bool) != true }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw AssistantError.invalidResponse("pusta odpowiedź") }
        return Data(text.utf8)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw AssistantError.timeout
            case .cancelled: throw AssistantError.cancelled
            default: throw AssistantError.network(error.localizedDescription)
            }
        } catch is CancellationError {
            throw AssistantError.cancelled
        } catch {
            throw AssistantError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AssistantError.invalidResponse("brak nagłówków HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AssistantError.http(status: http.statusCode, message: Self.message(status: http.statusCode))
        }
        return data
    }

    /// Komunikaty jak `geminiError` strony.
    static func message(status: Int) -> String {
        switch status {
        case 400:
            return "Google odrzucił zapytanie (format lub nieprawidłowy klucz). Sprawdź klucz w Ustawieniach."
        case 401, 403:
            return "Google odmówił dostępu. Sprawdź klucz, ograniczenia i uprawnienia projektu."
        case 404:
            return "Gemini nie udostępnia teraz zgodnego modelu. Spróbuj ponownie za chwilę."
        case 429:
            return "Osiągnięto limit Google. Sprawdź limity projektu lub spróbuj później."
        case 408, 500, 502, 503, 504:
            return "Gemini jest chwilowo przeciążone. Spróbuj ponownie za kilkanaście sekund — Twoje dane są bezpieczne."
        default:
            return "Nie udało się uzyskać odpowiedzi Gemini."
        }
    }

    // MARK: - Schematy JSON (jak `tutor-json.ts`)

    private static var stringType: [String: Any] { ["type": "string"] }

    private static func array(_ items: [String: Any]) -> [String: Any] {
        ["type": "array", "items": items]
    }

    private static func object(_ properties: [String: [String: Any]]) -> [String: Any] {
        [
            "type": "object",
            "properties": properties,
            "required": properties.keys.sorted(),
            "additionalProperties": false
        ]
    }

    static var pairSchema: [String: Any] {
        object(["en": stringType, "pl": stringType, "focusEn": stringType, "focusPl": stringType])
    }

    static var lookupSchema: [String: Any] {
        let meaning = object([
            "translation": stringType,
            "definition": stringType,
            "pos": stringType,
            "level": stringType,
            "levelConfidence": ["type": "string", "enum": ["high", "medium", "low"]],
            "levelReason": stringType,
            "spokenFrequency": ["type": "string", "enum": ["very_common", "common", "less_common", "rare"]],
            "context": stringType,
            "register": stringType,
            "natural": stringType,
            "collection": stringType,
            "examples": array(pairSchema),
            "acceptedAnswers": array(stringType),
            "acceptedTranslations": array(stringType)
        ])
        return object([
            "exists": ["type": "boolean"],
            "term": stringType,
            "ipa": stringType,
            "forms": stringType,
            "collocations": stringType,
            "synonyms": stringType,
            "antonyms": stringType,
            "note": stringType,
            "alternatives": array(stringType),
            "meanings": array(meaning)
        ])
    }

    static var gradeSchema: [String: Any] {
        object([
            "verdict": ["type": "string", "enum": ["correct", "incorrect", "uncertain"]],
            "explanation": stringType,
            "spellingCorrect": ["type": "boolean"]
        ])
    }
}
