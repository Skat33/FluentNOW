import Foundation

/// Sposób logowania (FEEDBACK-5 J3).
enum AuthProviderKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case apple
    case google
    case email

    var id: String { rawValue }

    var namePl: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "E-mail i hasło"
        }
    }

    var systemImage: String {
        switch self {
        case .apple: return "apple.logo"
        case .google: return "globe"
        case .email: return "envelope.fill"
        }
    }
}

/// Zalogowana sesja. Trzymana **wyłącznie** w pęku kluczy (`AuthSessionVault`,
/// `AfterFirstUnlockThisDeviceOnly`) — nigdy w UserDefaults, eksporcie JSON ani w logach
/// (`description` ukrywa tokeny).
///
/// BACKEND: dziś sesję tworzy lokalnie `LocalAuthService` (`isLocalOnly == true`, tokeny pochodzą
/// od dostawcy tożsamości). Po podpięciu serwera `accessToken`/`refreshToken` będą tokenami
/// FluentNOW wydanymi przez backend w zamian za token Apple/Google/hasło.
struct AuthSession: Codable, Equatable, Sendable, CustomStringConvertible {
    /// Stabilny identyfikator konta: `apple:<sub>`, `google:<sub>`, `email:<uuid>`.
    var userID: String
    var provider: AuthProviderKind
    var email: String?
    var displayName: String?
    var accessToken: String?
    var refreshToken: String?
    /// Token tożsamości OpenID (Apple `identityToken`, Google `id_token`) — dla przyszłego backendu.
    var idToken: String?
    var expiresAt: Date?
    var createdAt: Date
    /// `true`, dopóki konto istnieje tylko na tym urządzeniu (brak backendu).
    var isLocalOnly: Bool

    init(
        userID: String,
        provider: AuthProviderKind,
        email: String? = nil,
        displayName: String? = nil,
        accessToken: String? = nil,
        refreshToken: String? = nil,
        idToken: String? = nil,
        expiresAt: Date? = nil,
        createdAt: Date = Date(),
        isLocalOnly: Bool = true
    ) {
        self.userID = userID
        self.provider = provider
        self.email = email
        self.displayName = displayName
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.idToken = idToken
        self.expiresAt = expiresAt
        self.createdAt = createdAt
        self.isLocalOnly = isLocalOnly
    }

    /// Bez tokenów i adresu e-mail — bezpieczne do logów.
    var description: String {
        "AuthSession(provider: \(provider.rawValue), localOnly: \(isLocalOnly), tokens: <ukryte>)"
    }

    /// Nazwa do pokazania: imię z konta albo część adresu przed „@”.
    var preferredName: String? {
        if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let email, let local = email.split(separator: "@").first, !local.isEmpty {
            return String(local)
        }
        return nil
    }
}

/// Stan logowania widoczny w UI.
enum AuthStatus: Equatable, Sendable {
    /// Odczyt pęku kluczy przy starcie (ułamek sekundy).
    case loading
    /// Ekran logowania.
    case signedOut
    /// „Kontynuuj bez konta” — dane lokalnie / w iCloud jak dotąd.
    case guest
    case signedIn(AuthSession)
}

/// Tożsamość z „Zaloguj przez Apple” (`ASAuthorizationAppleIDCredential`). Apple podaje e-mail
/// i imię **tylko przy pierwszej autoryzacji** — `LocalAuthService` je zapamiętuje.
struct AppleIdentity: Sendable, Equatable {
    var user: String
    var email: String?
    var fullName: String?
    var identityToken: String?
    /// Jednorazowy kod (ważny ok. 5 min) — tylko do natychmiastowej wymiany na backendzie.
    var authorizationCode: String?
}

/// Tożsamość z Google (OAuth 2.0 + PKCE, `id_token`).
struct GoogleIdentity: Sendable, Equatable {
    var subject: String
    var email: String?
    var emailVerified: Bool
    var name: String?
    var idToken: String
    var accessToken: String?
    var refreshToken: String?
    var expiresAt: Date?
}

/// Wynik „Nie pamiętam hasła”.
enum PasswordResetOutcome: Equatable, Sendable {
    /// BACKEND: serwer wysłał link (jeśli konto istnieje — odpowiedź celowo ta sama dla każdego adresu).
    case emailSent
    /// Konto lokalne: hasła nie da się przypomnieć bez serwera; można założyć konto od nowa.
    case localAccountCannotBeRecovered
}

/// Błędy logowania z polskim opisem.
enum AuthError: Error, LocalizedError, Equatable {
    case cancelled
    case invalidEmail
    case weakPassword
    case passwordMismatch
    case emailTaken
    case wrongCredentials
    case appleNotConfigured
    case appleFailed(String)
    case googleNotConfigured
    case googleFailed(String)
    case network(String)
    case storage(String)
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Logowanie przerwane."
        case .invalidEmail:
            return "Podaj poprawny adres e-mail, np. ania@example.com."
        case .weakPassword:
            return "Hasło musi mieć co najmniej \(PasswordPolicy.minimumLength) znaków."
        case .passwordMismatch:
            return "Hasła nie są takie same."
        case .emailTaken:
            return "Na tym urządzeniu jest już konto z tym adresem. Zaloguj się albo użyj „Nie pamiętam hasła”."
        case .wrongCredentials:
            return "Nieprawidłowy e-mail lub hasło."
        case .appleNotConfigured:
            return "Logowanie przez Apple wymaga podpisania aplikacji płatnym kontem deweloperskim z uprawnieniem „Sign in with Apple”. Na razie możesz kontynuować bez konta albo zalogować się e-mailem."
        case .appleFailed(let detail):
            return "Nie udało się zalogować przez Apple. \(detail)"
        case .googleNotConfigured:
            return "Logowanie Google będzie dostępne po konfiguracji."
        case .googleFailed(let detail):
            return "Nie udało się zalogować przez Google. \(detail)"
        case .network(let detail):
            return "Brak połączenia z serwerem logowania. \(detail)"
        case .storage(let detail):
            return "Nie udało się zapisać danych logowania w pęku kluczy. \(detail)"
        case .notSignedIn:
            return "Nie jesteś zalogowany."
        }
    }
}

/// Zasady hasła konta e-mail.
enum PasswordPolicy {
    static let minimumLength = 8
    static let maximumLength = 128

    static func isAcceptable(_ password: String) -> Bool {
        (minimumLength...maximumLength).contains(password.count)
            && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Adres e-mail: przycięty, małe litery, prosta walidacja (bez wyrażeń regularnych).
enum EmailAddress {
    static func normalized(_ value: String) -> String? {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard email.count <= 254, !email.contains(where: { $0.isWhitespace }) else { return nil }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let local = parts[0]
        let domain = parts[1]
        guard !local.isEmpty, local.count <= 64,
              domain.contains("."), !domain.hasPrefix("."), !domain.hasSuffix("."),
              !domain.contains("..") else { return nil }
        return email
    }
}
