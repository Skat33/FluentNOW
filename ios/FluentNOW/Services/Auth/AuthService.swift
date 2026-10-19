import Foundation

/// Konta użytkowników — warstwa, którą w przyszłości zastąpi backend (FEEDBACK-5 J3).
///
/// Dziś: `LocalAuthService` (konta e-mail i zapamiętane tożsamości Apple/Google w pęku kluczy,
/// tylko na tym urządzeniu). BACKEND: `RemoteAuthService` z tymi samymi metodami —
/// wymiana tokenu Apple (`identityToken` + `authorizationCode`) / Google (`id_token`) / hasła na
/// tokeny FluentNOW, reset hasła mailem, usunięcie konta na serwerze (dla Apple także
/// unieważnienie tokenów przez REST `appleid.apple.com/auth/revoke`, które wymaga sekretu
/// klienta — dlatego tylko na serwerze). Interfejs (`AuthController`, ekrany) się nie zmieni.
///
/// Dane nauki są dziś przypisane do urządzenia/iCloud (`LearningStore`), nie do konta.
protocol AuthService: Sendable {
    func signIn(email: String, password: String) async throws -> AuthSession
    /// `replaceExisting`: konto lokalne o tym adresie zostaje zastąpione (ścieżka „Nie pamiętam
    /// hasła” bez serwera). BACKEND: ignoruje parametr (reset tylko przez link w mailu).
    func register(email: String, password: String, displayName: String?, replaceExisting: Bool) async throws -> AuthSession
    func requestPasswordReset(email: String) async throws -> PasswordResetOutcome
    func signInWithApple(_ identity: AppleIdentity) async throws -> AuthSession
    func signInWithGoogle(_ identity: GoogleIdentity) async throws -> AuthSession
    func signOut(_ session: AuthSession) async
    /// Usuwa konto (wymóg App Store przy logowaniu w aplikacji).
    func deleteAccount(_ session: AuthSession) async throws
}

/// Konto e-mail zapisane lokalnie: tylko sól i skrót PBKDF2-HMAC-SHA256, nigdy hasło.
struct LocalEmailAccount: Codable, Equatable, Sendable {
    var id: String
    var email: String
    var displayName: String?
    /// base64
    var salt: String
    /// base64
    var hash: String
    var iterations: Int
    var algorithm: String
    var createdAt: Date
    /// Konto testowe utworzone w buildzie DEBUG — w wydaniu jest odrzucane i usuwane.
    var isDebugSeed: Bool

    static let algorithmPBKDF2SHA256 = "pbkdf2-sha256"
}

/// Zapamiętane dane z pierwszej autoryzacji Apple (Apple podaje e-mail i imię tylko raz).
private struct RememberedAppleIdentity: Codable, Sendable {
    var email: String?
    var fullName: String?
}

/// Konta na tym urządzeniu, do czasu podpięcia backendu.
struct LocalAuthService: AuthService {
    let secrets: any AuthSecretStore
    let iterations: Int

    init(secrets: any AuthSecretStore, iterations: Int = AuthCrypto.defaultIterations) {
        self.secrets = secrets
        self.iterations = max(1, iterations)
    }

    // MARK: E-mail

    func signIn(email: String, password: String) async throws -> AuthSession {
        guard let normalized = EmailAddress.normalized(email) else { throw AuthError.invalidEmail }
        #if DEBUG
        try seedDebugAccountIfNeeded(normalizedEmail: normalized)
        #endif
        guard let account = try loadAccount(normalized) else {
            // Ta sama praca co przy istniejącym koncie — czas odpowiedzi nie zdradza, czy konto jest.
            _ = AuthCrypto.pbkdf2(password: password.isEmpty ? " " : password, salt: [0x46, 0x4E], iterations: iterations)
            throw AuthError.wrongCredentials
        }
        #if !DEBUG
        if account.isDebugSeed {
            secrets.remove(Self.accountKey(normalized))
            throw AuthError.wrongCredentials
        }
        #endif
        guard Self.verify(password: password, account: account) else {
            throw AuthError.wrongCredentials
        }
        return AuthSession(
            userID: "email:\(account.id)",
            provider: .email,
            email: account.email,
            displayName: account.displayName
        )
    }

    func register(email: String, password: String, displayName: String?, replaceExisting: Bool) async throws -> AuthSession {
        guard let normalized = EmailAddress.normalized(email) else { throw AuthError.invalidEmail }
        guard PasswordPolicy.isAcceptable(password) else { throw AuthError.weakPassword }
        if !replaceExisting, try loadAccount(normalized) != nil {
            throw AuthError.emailTaken
        }
        let account = try makeAccount(email: normalized, password: password, displayName: Self.cleanName(displayName), isDebugSeed: false)
        try saveAccount(account)
        return AuthSession(
            userID: "email:\(account.id)",
            provider: .email,
            email: account.email,
            displayName: account.displayName
        )
    }

    func requestPasswordReset(email: String) async throws -> PasswordResetOutcome {
        guard EmailAddress.normalized(email) != nil else { throw AuthError.invalidEmail }
        // BACKEND: POST /auth/password-reset → .emailSent (bez względu na to, czy konto istnieje).
        return .localAccountCannotBeRecovered
    }

    // MARK: Apple / Google

    func signInWithApple(_ identity: AppleIdentity) async throws -> AuthSession {
        let key = "apple-identity.\(AuthCrypto.sha256Hex(identity.user))"
        var remembered = RememberedAppleIdentity()
        if let stored = try? secrets.data(for: key),
           let decoded = try? JSONDecoder().decode(RememberedAppleIdentity.self, from: stored) {
            remembered = decoded
        }
        if let email = identity.email, !email.isEmpty { remembered.email = email }
        if let name = Self.cleanName(identity.fullName) { remembered.fullName = name }
        if let data = try? JSONEncoder().encode(remembered) {
            try? secrets.set(data, for: key)
        }
        // BACKEND: wyślij identityToken + authorizationCode (+ surowy nonce) do weryfikacji podpisu.
        return AuthSession(
            userID: "apple:\(identity.user)",
            provider: .apple,
            email: remembered.email,
            displayName: remembered.fullName,
            idToken: identity.identityToken
        )
    }

    func signInWithGoogle(_ identity: GoogleIdentity) async throws -> AuthSession {
        // BACKEND: wyślij id_token do weryfikacji podpisu (JWKS Google) i wydania tokenów FluentNOW.
        AuthSession(
            userID: "google:\(identity.subject)",
            provider: .google,
            email: identity.email,
            displayName: Self.cleanName(identity.name),
            accessToken: identity.accessToken,
            refreshToken: identity.refreshToken,
            idToken: identity.idToken,
            expiresAt: identity.expiresAt
        )
    }

    // MARK: Sesja

    func signOut(_ session: AuthSession) async {
        // BACKEND: unieważnij refresh token na serwerze. Lokalnie nie ma czego unieważniać.
    }

    func deleteAccount(_ session: AuthSession) async throws {
        switch session.provider {
        case .email:
            if let email = session.email.flatMap(EmailAddress.normalized) {
                secrets.remove(Self.accountKey(email))
            }
        case .apple:
            let user = session.userID.hasPrefix("apple:") ? String(session.userID.dropFirst(6)) : session.userID
            secrets.remove("apple-identity.\(AuthCrypto.sha256Hex(user))")
            // BACKEND: POST appleid.apple.com/auth/revoke (wymaga client_secret — tylko serwer).
        case .google:
            // BACKEND: usunięcie konta na serwerze; opcjonalnie POST oauth2.googleapis.com/revoke.
            break
        }
    }

    // MARK: Konta lokalne

    static func accountKey(_ normalizedEmail: String) -> String {
        "email-account.\(AuthCrypto.sha256Hex(normalizedEmail))"
    }

    func loadAccount(_ normalizedEmail: String) throws -> LocalEmailAccount? {
        guard let data = try secrets.data(for: Self.accountKey(normalizedEmail)) else { return nil }
        return try? JSONDecoder().decode(LocalEmailAccount.self, from: data)
    }

    private func saveAccount(_ account: LocalEmailAccount) throws {
        let data = try JSONEncoder().encode(account)
        try secrets.set(data, for: Self.accountKey(account.email))
    }

    private func makeAccount(email: String, password: String, displayName: String?, isDebugSeed: Bool) throws -> LocalEmailAccount {
        guard let salt = AuthCrypto.randomBytes(AuthCrypto.saltLength),
              let hash = AuthCrypto.pbkdf2(password: password, salt: salt, iterations: iterations) else {
            throw AuthError.storage("Nie udało się zabezpieczyć hasła.")
        }
        return LocalEmailAccount(
            id: UUID().uuidString.lowercased(),
            email: email,
            displayName: displayName,
            salt: Data(salt).base64EncodedString(),
            hash: Data(hash).base64EncodedString(),
            iterations: iterations,
            algorithm: LocalEmailAccount.algorithmPBKDF2SHA256,
            createdAt: Date(),
            isDebugSeed: isDebugSeed
        )
    }

    static func verify(password: String, account: LocalEmailAccount) -> Bool {
        guard account.algorithm == LocalEmailAccount.algorithmPBKDF2SHA256,
              let salt = Data(base64Encoded: account.salt),
              let expected = Data(base64Encoded: account.hash),
              let derived = AuthCrypto.pbkdf2(password: password, salt: Array(salt), iterations: account.iterations, length: expected.count) else {
            return false
        }
        return AuthCrypto.constantTimeEquals(derived, Array(expected))
    }

    static func cleanName(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(60))
    }

    // MARK: Konto testowe (tylko DEBUG)

    #if DEBUG
    /// Konto testowe `admin@admin.pl` / `admin` — **istnieje wyłącznie w buildach DEBUG**
    /// (kod i dane logowania nie trafiają do wydania). Zapisywane jak każde inne konto:
    /// sól + PBKDF2 w pęku kluczy, przy pierwszej próbie logowania na ten adres.
    enum DebugAccount {
        static let email = "admin@admin.pl"
        static let password = "admin"
        static let displayName = "Admin (test)"
    }

    private func seedDebugAccountIfNeeded(normalizedEmail: String) throws {
        guard normalizedEmail == DebugAccount.email, try loadAccount(normalizedEmail) == nil else { return }
        let account = try makeAccount(email: DebugAccount.email, password: DebugAccount.password, displayName: DebugAccount.displayName, isDebugSeed: true)
        try saveAccount(account)
    }
    #endif
}
