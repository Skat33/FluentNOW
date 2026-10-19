import Foundation
import Observation
import AuthenticationServices
import SwiftUI

/// Stan logowania aplikacji (FEEDBACK-5 J3): ekran logowania przy pierwszym uruchomieniu,
/// tryb gościa, Apple / Google / e-mail, wylogowanie i usunięcie konta.
///
/// - Konta obsługuje `any AuthService` (dziś `LocalAuthService`; BACKEND: `RemoteAuthService`).
/// - Sesja (identyfikator, e-mail, nazwa, dostawca, tokeny) tylko w pęku kluczy (`AuthSessionVault`).
/// - W UserDefaults są wyłącznie flagi bez danych osobowych: tryb gościa (`fluent.auth.guest`,
///   czyszczona razem z „Usuń wszystkie dane”) i znacznik instalacji (`auth.installMarker`).
/// - Dane nauki zostają na urządzeniu / w iCloud niezależnie od konta.
///   BACKEND: po zalogowaniu `LearningStore` dostanie tu punkt zaczepienia do synchronizacji z
///   serwerem (patrz `AuthController.didSignIn(_:)`).
///
/// Odczyt w widokach: `@Environment(AuthController.self) private var auth`.
@MainActor
@Observable
final class AuthController {
    private(set) var status: AuthStatus = .loading
    /// Trwa logowanie / rejestracja / usuwanie konta.
    private(set) var isWorking = false

    let google: GoogleOAuthConfiguration
    /// `false` = build bez uprawnienia „Sign in with Apple” (przycisk pokazuje komunikat).
    let isAppleSignInAvailable: Bool

    @ObservationIgnored private let service: any AuthService
    @ObservationIgnored private let vault: AuthSessionVault
    @ObservationIgnored private let defaults: UserDefaults?
    /// Surowy nonce ostatniego żądania Apple (do Apple trafia jego SHA-256). BACKEND: wysłać razem z tokenem.
    @ObservationIgnored private var appleRawNonce: String?

    static let guestKey = "fluent.auth.guest"
    /// Bez prefiksu `fluent.` — nie znika przy „Usuń wszystkie dane”.
    static let installMarkerKey = "auth.installMarker"

    init(
        service: any AuthService,
        secrets: any AuthSecretStore,
        defaults: UserDefaults?,
        google: GoogleOAuthConfiguration,
        isAppleSignInAvailable: Bool,
        initialStatus: AuthStatus = .loading
    ) {
        self.service = service
        self.vault = AuthSessionVault(secrets: secrets)
        self.defaults = defaults
        self.google = google
        self.isAppleSignInAvailable = isAppleSignInAvailable
        self.status = initialStatus
    }

    /// Aplikacja: pęk kluczy, UserDefaults, konfiguracja Google z Info.plist.
    static func live() -> AuthController {
        let secrets = KeychainAuthSecretStore()
        return AuthController(
            service: LocalAuthService(secrets: secrets),
            secrets: secrets,
            defaults: .standard,
            google: GoogleOAuthConfiguration.fromBundle(),
            isAppleSignInAvailable: AppleSignIn.hasEntitlement
        )
    }

    /// Podgląd / testy: wszystko w pamięci.
    static func inMemory(status: AuthStatus = .guest, iterations: Int = 1_000) -> AuthController {
        let secrets = InMemoryAuthSecretStore()
        return AuthController(
            service: LocalAuthService(secrets: secrets, iterations: iterations),
            secrets: secrets,
            defaults: nil,
            google: GoogleOAuthConfiguration(clientID: ""),
            isAppleSignInAvailable: false,
            initialStatus: status
        )
    }

    // MARK: Odczyty

    var session: AuthSession? {
        if case .signedIn(let session) = status { return session }
        return nil
    }

    var isGuest: Bool { status == .guest }

    // MARK: Start

    /// Wołane raz przy starcie. `hasExistingInstall` — użytkownik wersji sprzed logowania
    /// (ukończony wywiad): nie zaskakujemy go ekranem logowania, tylko przechodzi w tryb gościa
    /// (zalogować się może z Profilu).
    func bootstrap(hasExistingInstall: Bool) async {
        guard status == .loading else { return }
        // Pęk kluczy przeżywa usunięcie aplikacji — po ponownej instalacji zaczynamy bez sesji.
        if let defaults, defaults.object(forKey: Self.installMarkerKey) == nil {
            vault.clear()
            defaults.set(true, forKey: Self.installMarkerKey)
        }
        if let session = vault.load() {
            status = .signedIn(session)
            await verifyAppleCredential(session)
            return
        }
        if defaults?.bool(forKey: Self.guestKey) == true {
            status = .guest
            return
        }
        if hasExistingInstall {
            setGuestFlag(true)
            status = .guest
            return
        }
        status = .signedOut
    }

    /// Apple: konto, któremu cofnięto zgodę (Ustawienia → Apple ID), jest wylogowywane.
    private func verifyAppleCredential(_ session: AuthSession) async {
        guard session.provider == .apple, isAppleSignInAvailable else { return }
        let user = session.userID.hasPrefix("apple:") ? String(session.userID.dropFirst(6)) : session.userID
        let valid = await AppleSignIn.isCredentialValid(user: user)
        if !valid, self.session?.userID == session.userID {
            vault.clear()
            status = .signedOut
        }
    }

    // MARK: Gość

    func continueAsGuest() {
        setGuestFlag(true)
        status = .guest
    }

    /// Z Profilu (gość → „Zaloguj się”): pokazuje ekran logowania; dane nauki zostają.
    func showSignIn() {
        status = .signedOut
    }

    // MARK: Apple

    /// `onRequest` przycisku `SignInWithAppleButton`.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        if let raw = AuthCrypto.randomToken(byteCount: 32) {
            appleRawNonce = raw
            request.nonce = AuthCrypto.sha256Hex(raw)
        }
    }

    /// `onCompletion` przycisku. Zwraca komunikat błędu (`nil` = sukces lub anulowanie).
    func completeApple(_ result: Result<ASAuthorization, Error>) async -> String? {
        switch result {
        case .failure(let error):
            return message(for: AppleSignIn.mapError(error))
        case .success(let authorization):
            guard let identity = AppleSignIn.identity(from: authorization) else {
                return message(for: AuthError.appleFailed("Nieobsługiwany rodzaj poświadczenia."))
            }
            return await perform { [service] in
                try await service.signInWithApple(identity)
            }
        }
    }

    // MARK: Google

    /// Logowanie Google w przeglądarce systemowej (SwiftUI `WebAuthenticationSession`, czyli
    /// `ASWebAuthenticationSession`, sesja efemeryczna). Zwraca komunikat błędu albo `nil`.
    func signInWithGoogle(using webSession: WebAuthenticationSession) async -> String? {
        guard google.isConfigured else { return message(for: AuthError.googleNotConfigured) }
        guard let request = GoogleOAuth.makeRequest(configuration: google) else {
            return message(for: AuthError.googleFailed("Nie udało się przygotować żądania."))
        }
        isWorking = true
        defer { isWorking = false }
        let callback: URL
        do {
            callback = try await Self.authenticate(webSession: webSession, request: request)
        } catch {
            return message(for: Self.mapWebError(error))
        }
        let configuration = google
        return await perform { [service] in
            let code = try GoogleOAuth.authorizationCode(from: callback, request: request)
            let identity = try await GoogleOAuth.exchange(code: code, request: request, configuration: configuration)
            return try await service.signInWithGoogle(identity)
        }
    }

    private static func authenticate(webSession: WebAuthenticationSession, request: GoogleAuthorizationRequest) async throws -> URL {
        if #available(iOS 17.4, *) {
            return try await webSession.authenticate(
                using: request.url,
                callback: .customScheme(request.callbackScheme),
                preferredBrowserSession: .ephemeral,
                additionalHeaderFields: [:]
            )
        } else {
            return try await webSession.authenticate(
                using: request.url,
                callbackURLScheme: request.callbackScheme,
                preferredBrowserSession: .ephemeral
            )
        }
    }

    private static func mapWebError(_ error: Error) -> AuthError {
        if let webError = error as? ASWebAuthenticationSessionError, webError.code == .canceledLogin {
            return .cancelled
        }
        if let authError = error as? AuthError { return authError }
        return .googleFailed(error.localizedDescription)
    }

    // MARK: E-mail

    /// Zwraca komunikat błędu albo `nil` (zalogowano).
    func signIn(email: String, password: String) async -> String? {
        await perform { [service] in
            try await service.signIn(email: email, password: password)
        }
    }

    func register(email: String, password: String, confirmation: String, displayName: String?, replaceExisting: Bool = false) async -> String? {
        guard password == confirmation else { return message(for: AuthError.passwordMismatch) }
        return await perform { [service] in
            try await service.register(email: email, password: password, displayName: displayName, replaceExisting: replaceExisting)
        }
    }

    func requestPasswordReset(email: String) async -> Result<PasswordResetOutcome, AuthError> {
        do {
            return .success(try await service.requestPasswordReset(email: email))
        } catch let error as AuthError {
            return .failure(error)
        } catch {
            return .failure(.storage(error.localizedDescription))
        }
    }

    // MARK: Wylogowanie i usunięcie konta

    func signOut() async {
        if let session {
            await service.signOut(session)
        }
        vault.clear()
        setGuestFlag(false)
        status = .signedOut
    }

    /// Usuwa konto (dane nauki usuwa osobno wywołujący, jeśli użytkownik tego chce).
    func deleteAccount() async -> String? {
        guard let session else { return message(for: AuthError.notSignedIn) }
        isWorking = true
        defer { isWorking = false }
        do {
            try await service.deleteAccount(session)
        } catch {
            return message(for: error)
        }
        vault.clear()
        setGuestFlag(false)
        status = .signedOut
        return nil
    }

    // MARK: Implementacja

    /// Wspólna ścieżka logowania: praca dostawcy poza głównym wątkiem → zapis sesji → stan.
    private func perform(_ work: @escaping @Sendable () async throws -> AuthSession) async -> String? {
        isWorking = true
        defer { isWorking = false }
        do {
            let session = try await work()
            try vault.save(session)
            didSignIn(session)
            return nil
        } catch {
            return message(for: error)
        }
    }

    /// BACKEND: tu podłączyć synchronizację danych nauki z kontem (np. `LearningStore` +
    /// zdalne repozytorium). Dziś dane zostają lokalne/iCloud, przypisane do urządzenia.
    private func didSignIn(_ session: AuthSession) {
        setGuestFlag(false)
        status = .signedIn(session)
    }

    private func setGuestFlag(_ value: Bool) {
        if value {
            defaults?.set(true, forKey: Self.guestKey)
        } else {
            defaults?.removeObject(forKey: Self.guestKey)
        }
    }

    /// `nil` dla anulowania (bez komunikatu).
    private func message(for error: Error) -> String? {
        let authError = (error as? AuthError) ?? .storage(error.localizedDescription)
        if authError == .cancelled { return nil }
        return authError.errorDescription
    }
}
