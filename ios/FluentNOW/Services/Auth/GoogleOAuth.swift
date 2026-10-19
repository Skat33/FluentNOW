import Foundation

/// Konfiguracja logowania Google (bez SDK). Identyfikator klienta typu **iOS** z Google Cloud
/// Console trafia do Info.plist z ustawienia budowania `FLUENT_GOOGLE_CLIENT_ID` (`project.yml`)
/// pod kluczem `FluentGoogleClientID`. Puste → przycisk pokazuje „Logowanie Google będzie dostępne
/// po konfiguracji”. Instrukcja: `ios/README.md`.
struct GoogleOAuthConfiguration: Sendable, Equatable {
    static let infoPlistKey = "FluentGoogleClientID"
    static let clientSuffix = ".apps.googleusercontent.com"

    let clientID: String

    init(clientID: String) {
        self.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Z Info.plist; nierozwinięta zmienna `$(…)` albo pusty tekst = brak konfiguracji.
    static func fromBundle(_ bundle: Bundle = .main) -> GoogleOAuthConfiguration {
        let raw = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String ?? ""
        return GoogleOAuthConfiguration(clientID: raw.hasPrefix("$(") ? "" : raw)
    }

    var isConfigured: Bool {
        clientID.hasSuffix(Self.clientSuffix) && clientID.count > Self.clientSuffix.count
            && !clientID.contains(where: { $0.isWhitespace })
    }

    /// Odwrócony identyfikator klienta — schemat przekierowania klienta iOS
    /// (`com.googleusercontent.apps.<id>`).
    var redirectScheme: String {
        let prefix = String(clientID.dropLast(Self.clientSuffix.count))
        return "com.googleusercontent.apps.\(prefix)"
    }

    var redirectURI: String { "\(redirectScheme):/oauth2redirect" }
}

/// Jedno żądanie autoryzacji (PKCE S256, `state`, `nonce`) — wartości tylko w pamięci.
struct GoogleAuthorizationRequest: Sendable, Equatable {
    let url: URL
    let state: String
    let codeVerifier: String
    let nonce: String
    let redirectURI: String
    let callbackScheme: String
}

/// Odpowiedź punktu `oauth2.googleapis.com/token`.
struct GoogleTokenResponse: Decodable, Sendable, Equatable {
    var accessToken: String?
    var expiresIn: Double?
    var refreshToken: String?
    var idToken: String?
    var tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
    }
}

/// OAuth 2.0 dla aplikacji natywnych (RFC 8252) z PKCE (RFC 7636): przeglądarka systemowa
/// (`ASWebAuthenticationSession` przez SwiftUI `WebAuthenticationSession`) → kod → wymiana na
/// tokeny bez sekretu klienta (klient iOS go nie ma). Czyste funkcje + jedna funkcja sieciowa.
enum GoogleOAuth {
    static let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    static let tokenEndpoint = "https://oauth2.googleapis.com/token"
    static let scopes = "openid email profile"
    static let validIssuers: Set<String> = ["https://accounts.google.com", "accounts.google.com"]

    /// Wyzwanie PKCE: base64url(SHA-256(verifier)).
    static func codeChallenge(for verifier: String) -> String {
        AuthCrypto.base64URL(AuthCrypto.sha256(Data(verifier.utf8)))
    }

    /// Żądanie z losowymi wartościami; `nil` przy braku konfiguracji lub awarii generatora.
    static func makeRequest(configuration: GoogleOAuthConfiguration) -> GoogleAuthorizationRequest? {
        guard let verifier = AuthCrypto.randomToken(byteCount: 32),
              let state = AuthCrypto.randomToken(byteCount: 16),
              let nonce = AuthCrypto.randomToken(byteCount: 16) else { return nil }
        return makeRequest(configuration: configuration, verifier: verifier, state: state, nonce: nonce)
    }

    /// Deterministyczny wariant (testy).
    static func makeRequest(configuration: GoogleOAuthConfiguration, verifier: String, state: String, nonce: String) -> GoogleAuthorizationRequest? {
        guard configuration.isConfigured, var components = URLComponents(string: authorizationEndpoint) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        guard let url = components.url else { return nil }
        return GoogleAuthorizationRequest(
            url: url,
            state: state,
            codeVerifier: verifier,
            nonce: nonce,
            redirectURI: configuration.redirectURI,
            callbackScheme: configuration.redirectScheme
        )
    }

    /// Kod z adresu powrotu; sprawdza `state` (ochrona przed CSRF) i błąd zwrócony przez Google.
    static func authorizationCode(from callback: URL, request: GoogleAuthorizationRequest) throws -> String {
        guard let components = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == request.callbackScheme.lowercased() else {
            throw AuthError.googleFailed("Nieoczekiwany adres powrotu.")
        }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        if let error = value("error") {
            if error == "access_denied" { throw AuthError.cancelled }
            throw AuthError.googleFailed("Google zwrócił błąd: \(error).")
        }
        guard value("state") == request.state else {
            throw AuthError.googleFailed("Niezgodny parametr bezpieczeństwa (state).")
        }
        guard let code = value("code"), !code.isEmpty else {
            throw AuthError.googleFailed("Brak kodu autoryzacji.")
        }
        return code
    }

    /// Żądanie wymiany kodu na tokeny (`application/x-www-form-urlencoded`, bez sekretu klienta).
    static func tokenRequest(code: String, request: GoogleAuthorizationRequest, configuration: GoogleOAuthConfiguration) -> URLRequest? {
        guard let url = URL(string: tokenEndpoint) else { return nil }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let fields: [(String, String)] = [
            ("code", code),
            ("client_id", configuration.clientID),
            ("redirect_uri", request.redirectURI),
            ("grant_type", "authorization_code"),
            ("code_verifier", request.codeVerifier)
        ]
        let body = fields
            .map { (field: (String, String)) -> String in "\(formEncode(field.0))=\(formEncode(field.1))" }
            .joined(separator: "&")
        urlRequest.httpBody = Data(body.utf8)
        return urlRequest
    }

    /// Kodowanie wartości formularza (RFC 3986: tylko znaki niezastrzeżone zostają).
    static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    /// Tożsamość z `id_token`. Token przychodzi bezpośrednio z punktu tokenów Google przez TLS,
    /// więc (OpenID Connect Core §3.1.3.7) wystarcza sprawdzenie `aud`, `iss`, `exp` i `nonce`.
    /// BACKEND: serwer i tak weryfikuje podpis (JWKS Google) przed wydaniem własnych tokenów.
    static func identity(from tokens: GoogleTokenResponse, request: GoogleAuthorizationRequest, configuration: GoogleOAuthConfiguration, now: Date = Date()) throws -> GoogleIdentity {
        guard let idToken = tokens.idToken, let claims = jwtClaims(idToken) else {
            throw AuthError.googleFailed("Brak tokenu tożsamości.")
        }
        guard let subject = claims["sub"] as? String, !subject.isEmpty else {
            throw AuthError.googleFailed("Token bez identyfikatora użytkownika.")
        }
        guard audienceMatches(claims["aud"], clientID: configuration.clientID) else {
            throw AuthError.googleFailed("Token wydany dla innej aplikacji.")
        }
        guard let issuer = claims["iss"] as? String, validIssuers.contains(issuer) else {
            throw AuthError.googleFailed("Nieznany wystawca tokenu.")
        }
        if let nonce = claims["nonce"] as? String, nonce != request.nonce {
            throw AuthError.googleFailed("Niezgodny parametr bezpieczeństwa (nonce).")
        }
        if let exp = number(claims["exp"]), Date(timeIntervalSince1970: exp) < now.addingTimeInterval(-300) {
            throw AuthError.googleFailed("Token wygasł. Spróbuj ponownie.")
        }
        let verified: Bool
        if let flag = claims["email_verified"] as? Bool {
            verified = flag
        } else {
            verified = (claims["email_verified"] as? String) == "true"
        }
        return GoogleIdentity(
            subject: subject,
            email: claims["email"] as? String,
            emailVerified: verified,
            name: claims["name"] as? String,
            idToken: idToken,
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresAt: tokens.expiresIn.map { now.addingTimeInterval($0) }
        )
    }

    /// Część „payload” JWT jako słownik (bez weryfikacji podpisu — patrz `identity`).
    static func jwtClaims(_ token: String) -> [String: Any]? {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let data = AuthCrypto.data(base64URL: String(parts[1])) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func audienceMatches(_ value: Any?, clientID: String) -> Bool {
        if let single = value as? String { return single == clientID }
        if let many = value as? [String] { return many.contains(clientID) }
        return false
    }

    private static func number(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let text = value as? String { return Double(text) }
        return nil
    }

    /// Wymiana kodu na tokeny i odczyt tożsamości (sieć, poza głównym wątkiem).
    static func exchange(code: String, request: GoogleAuthorizationRequest, configuration: GoogleOAuthConfiguration, session: URLSession = .shared) async throws -> GoogleIdentity {
        guard let urlRequest = tokenRequest(code: code, request: request, configuration: configuration) else {
            throw AuthError.googleFailed("Nieprawidłowy adres serwera.")
        }
        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: urlRequest)
        } catch {
            throw AuthError.network(error.localizedDescription)
        }
        let (data, response) = result
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.googleFailed("Nieprawidłowa odpowiedź serwera.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw AuthError.googleFailed("Serwer odpowiedział kodem \(http.statusCode).")
        }
        let tokens: GoogleTokenResponse
        do {
            tokens = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        } catch {
            throw AuthError.googleFailed("Nieczytelna odpowiedź serwera.")
        }
        return try identity(from: tokens, request: request, configuration: configuration)
    }
}
