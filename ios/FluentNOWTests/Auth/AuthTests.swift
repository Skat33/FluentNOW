import XCTest
@testable import FluentNOW

/// FEEDBACK-5 J3: kryptografia logowania, konta lokalne, Google OAuth (PKCE) i stan logowania.
final class AuthCryptoTests: XCTestCase {
    private func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    func testPBKDF2MatchesKnownVectors() throws {
        let salt = Array("salt".utf8)
        let one = try XCTUnwrap(AuthCrypto.pbkdf2(password: "password", salt: salt, iterations: 1, length: 32))
        XCTAssertEqual(hex(one), "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b")
        let many = try XCTUnwrap(AuthCrypto.pbkdf2(password: "password", salt: salt, iterations: 4096, length: 32))
        XCTAssertEqual(hex(many), "c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a")
        XCTAssertNil(AuthCrypto.pbkdf2(password: "", salt: salt, iterations: 1))
        XCTAssertNil(AuthCrypto.pbkdf2(password: "x", salt: [], iterations: 1))
    }

    func testConstantTimeEqualsAndRandomness() throws {
        XCTAssertTrue(AuthCrypto.constantTimeEquals([1, 2, 3], [1, 2, 3]))
        XCTAssertFalse(AuthCrypto.constantTimeEquals([1, 2, 3], [1, 2, 4]))
        XCTAssertFalse(AuthCrypto.constantTimeEquals([1, 2], [1, 2, 3]))
        let a = try XCTUnwrap(AuthCrypto.randomToken())
        let b = try XCTUnwrap(AuthCrypto.randomToken())
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.count, 43, "32 bajty w base64url bez dopełnienia")
        XCTAssertFalse(a.contains("=") || a.contains("+") || a.contains("/"))
    }

    func testBase64URLRoundTrip() throws {
        for length in 0..<12 {
            let data = Data((0..<length).map { UInt8(($0 * 37 + 251) % 256) })
            let encoded = AuthCrypto.base64URL(data)
            XCTAssertEqual(AuthCrypto.data(base64URL: encoded), data)
        }
        XCTAssertNil(AuthCrypto.data(base64URL: "abcde"), "Długość 4n+1 jest nieprawidłowa")
    }

    func testEmailNormalization() {
        XCTAssertEqual(EmailAddress.normalized("  Ania@Example.COM "), "ania@example.com")
        XCTAssertNil(EmailAddress.normalized("ania"))
        XCTAssertNil(EmailAddress.normalized("ania@example"))
        XCTAssertNil(EmailAddress.normalized("a b@example.com"))
        XCTAssertNil(EmailAddress.normalized("a@@example.com"))
        XCTAssertNil(EmailAddress.normalized("@example.com"))
        XCTAssertNil(EmailAddress.normalized("a@example..com"))
        XCTAssertTrue(PasswordPolicy.isAcceptable("12345678"))
        XCTAssertFalse(PasswordPolicy.isAcceptable("1234567"))
        XCTAssertFalse(PasswordPolicy.isAcceptable("        "))
    }

    func testSessionDescriptionHidesSecrets() {
        let session = AuthSession(userID: "google:1", provider: .google, email: "ania@example.com", accessToken: "SECRET-ACCESS", idToken: "SECRET-ID")
        XCTAssertFalse(session.description.contains("SECRET"))
        XCTAssertFalse(session.description.contains("ania@"))
        XCTAssertEqual(session.preferredName, "ania")
    }
}

final class LocalAuthServiceTests: XCTestCase {
    private func makeService() -> (LocalAuthService, InMemoryAuthSecretStore) {
        let secrets = InMemoryAuthSecretStore()
        return (LocalAuthService(secrets: secrets, iterations: 1_000), secrets)
    }

    func testRegisterThenSignIn() async throws {
        let (service, _) = makeService()
        let registered = try await service.register(email: "Ania@Example.com", password: "tajne-haslo-1", displayName: "  Ania ", replaceExisting: false)
        XCTAssertEqual(registered.provider, .email)
        XCTAssertEqual(registered.email, "ania@example.com")
        XCTAssertEqual(registered.displayName, "Ania")
        XCTAssertTrue(registered.isLocalOnly)

        let signedIn = try await service.signIn(email: "ania@example.com ", password: "tajne-haslo-1")
        XCTAssertEqual(signedIn.userID, registered.userID, "Ten sam identyfikator konta")
    }

    func testWrongPasswordAndUnknownAccountGiveTheSameError() async throws {
        let (service, _) = makeService()
        _ = try await service.register(email: "ania@example.com", password: "tajne-haslo-1", displayName: nil, replaceExisting: false)
        do {
            _ = try await service.signIn(email: "ania@example.com", password: "zle-haslo-11")
            XCTFail("Złe hasło musi być odrzucone")
        } catch {
            XCTAssertEqual(error as? AuthError, .wrongCredentials)
        }
        do {
            _ = try await service.signIn(email: "nikt@example.com", password: "tajne-haslo-1")
            XCTFail("Nieistniejące konto")
        } catch {
            XCTAssertEqual(error as? AuthError, .wrongCredentials, "Nie zdradzamy, czy konto istnieje")
        }
    }

    func testValidationAndDuplicates() async throws {
        let (service, _) = makeService()
        do {
            _ = try await service.register(email: "zly-adres", password: "tajne-haslo-1", displayName: nil, replaceExisting: false)
            XCTFail("Zły adres")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidEmail)
        }
        do {
            _ = try await service.register(email: "ania@example.com", password: "krotkie", displayName: nil, replaceExisting: false)
            XCTFail("Za krótkie hasło")
        } catch {
            XCTAssertEqual(error as? AuthError, .weakPassword)
        }
        _ = try await service.register(email: "ania@example.com", password: "tajne-haslo-1", displayName: nil, replaceExisting: false)
        do {
            _ = try await service.register(email: "ANIA@example.com", password: "inne-haslo-22", displayName: nil, replaceExisting: false)
            XCTFail("Duplikat")
        } catch {
            XCTAssertEqual(error as? AuthError, .emailTaken)
        }
    }

    func testForgotPasswordReplacesLocalAccount() async throws {
        let (service, _) = makeService()
        _ = try await service.register(email: "ania@example.com", password: "stare-haslo-1", displayName: nil, replaceExisting: false)
        let outcome = try await service.requestPasswordReset(email: "ania@example.com")
        XCTAssertEqual(outcome, .localAccountCannotBeRecovered)
        _ = try await service.register(email: "ania@example.com", password: "nowe-haslo-22", displayName: nil, replaceExisting: true)
        _ = try await service.signIn(email: "ania@example.com", password: "nowe-haslo-22")
        do {
            _ = try await service.signIn(email: "ania@example.com", password: "stare-haslo-1")
            XCTFail("Stare hasło nie działa")
        } catch {
            XCTAssertEqual(error as? AuthError, .wrongCredentials)
        }
    }

    func testPasswordIsNeverStoredInPlainText() async throws {
        let (service, secrets) = makeService()
        let password = "Bardzo-Tajne-Haslo-123"
        _ = try await service.register(email: "ania@example.com", password: password, displayName: nil, replaceExisting: false)
        XCTAssertEqual(secrets.accounts.count, 1)
        for account in secrets.accounts {
            XCTAssertFalse(account.contains("ania"), "Adres nie jest nazwą wpisu w pęku kluczy")
            let data = try XCTUnwrap(try secrets.data(for: account))
            let text = String(decoding: data, as: UTF8.self)
            XCTAssertFalse(text.contains(password))
            XCTAssertTrue(text.contains(LocalEmailAccount.algorithmPBKDF2SHA256))
            let record = try JSONDecoder().decode(LocalEmailAccount.self, from: data)
            XCTAssertEqual(record.iterations, 1_000)
            XCTAssertEqual(Data(base64Encoded: record.salt)?.count, AuthCrypto.saltLength)
            XCTAssertFalse(record.isDebugSeed)
        }
    }

    func testDeleteAccountRemovesCredentials() async throws {
        let (service, secrets) = makeService()
        let session = try await service.register(email: "ania@example.com", password: "tajne-haslo-1", displayName: nil, replaceExisting: false)
        try await service.deleteAccount(session)
        XCTAssertTrue(secrets.accounts.isEmpty)
        do {
            _ = try await service.signIn(email: "ania@example.com", password: "tajne-haslo-1")
            XCTFail("Usunięte konto")
        } catch {
            XCTAssertEqual(error as? AuthError, .wrongCredentials)
        }
    }

    func testAppleRemembersEmailAndNameFromFirstAuthorization() async throws {
        let (service, secrets) = makeService()
        let first = try await service.signInWithApple(AppleIdentity(user: "001.abc", email: "ukryty@privaterelay.appleid.com", fullName: "Jan Kowalski", identityToken: "token-1", authorizationCode: nil))
        XCTAssertEqual(first.userID, "apple:001.abc")
        XCTAssertEqual(first.displayName, "Jan Kowalski")
        let second = try await service.signInWithApple(AppleIdentity(user: "001.abc", email: nil, fullName: nil, identityToken: "token-2", authorizationCode: nil))
        XCTAssertEqual(second.email, "ukryty@privaterelay.appleid.com", "Apple podaje e-mail tylko raz")
        XCTAssertEqual(second.displayName, "Jan Kowalski")
        XCTAssertEqual(second.idToken, "token-2")
        try await service.deleteAccount(second)
        XCTAssertTrue(secrets.accounts.isEmpty)
    }

    #if DEBUG
    func testDebugAccountExistsOnlyInDebugBuilds() async throws {
        let (service, secrets) = makeService()
        let session = try await service.signIn(email: "admin@admin.pl", password: "admin")
        XCTAssertEqual(session.email, "admin@admin.pl")
        let key = LocalAuthService.accountKey("admin@admin.pl")
        let data = try XCTUnwrap(try secrets.data(for: key))
        let record = try JSONDecoder().decode(LocalEmailAccount.self, from: data)
        XCTAssertTrue(record.isDebugSeed)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("\"admin\""), "Także konto testowe tylko jako skrót")
        do {
            _ = try await service.signIn(email: "admin@admin.pl", password: "Admin")
            XCTFail("Hasło rozróżnia wielkość liter")
        } catch {
            XCTAssertEqual(error as? AuthError, .wrongCredentials)
        }
    }
    #endif
}

final class GoogleOAuthTests: XCTestCase {
    private let configuration = GoogleOAuthConfiguration(clientID: "123-abc.apps.googleusercontent.com")

    func testConfiguration() {
        XCTAssertTrue(configuration.isConfigured)
        XCTAssertEqual(configuration.redirectScheme, "com.googleusercontent.apps.123-abc")
        XCTAssertEqual(configuration.redirectURI, "com.googleusercontent.apps.123-abc:/oauth2redirect")
        XCTAssertFalse(GoogleOAuthConfiguration(clientID: "").isConfigured)
        XCTAssertFalse(GoogleOAuthConfiguration(clientID: ".apps.googleusercontent.com").isConfigured)
        XCTAssertFalse(GoogleOAuthConfiguration(clientID: "not-a-client").isConfigured)
        XCTAssertNil(GoogleOAuth.makeRequest(configuration: GoogleOAuthConfiguration(clientID: "")))
    }

    func testPKCEChallengeMatchesRFC7636() {
        XCTAssertEqual(GoogleOAuth.codeChallenge(for: "dBjftJeZ4CVP-mJ92K23xp4Kb-CjRiMwGpVgTpIWQbA"), "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testAuthorizationURL() throws {
        let request = try XCTUnwrap(GoogleOAuth.makeRequest(configuration: configuration, verifier: "verifier-123", state: "state-1", nonce: "nonce-1"))
        let components = try XCTUnwrap(URLComponents(url: request.url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(components.host, "accounts.google.com")
        XCTAssertEqual(items["client_id"], configuration.clientID)
        XCTAssertEqual(items["redirect_uri"], configuration.redirectURI)
        XCTAssertEqual(items["response_type"], "code")
        XCTAssertEqual(items["code_challenge_method"], "S256")
        XCTAssertEqual(items["code_challenge"], GoogleOAuth.codeChallenge(for: "verifier-123"))
        XCTAssertEqual(items["state"], "state-1")
        XCTAssertEqual(items["nonce"], "nonce-1")
        XCTAssertNil(items["client_secret"])
        XCTAssertEqual(request.callbackScheme, configuration.redirectScheme)
    }

    func testCallbackValidation() throws {
        let request = try XCTUnwrap(GoogleOAuth.makeRequest(configuration: configuration, verifier: "v", state: "s1", nonce: "n1"))
        let ok = try XCTUnwrap(URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?code=abc&state=s1"))
        XCTAssertEqual(try GoogleOAuth.authorizationCode(from: ok, request: request), "abc")

        let wrongState = try XCTUnwrap(URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?code=abc&state=evil"))
        XCTAssertThrowsError(try GoogleOAuth.authorizationCode(from: wrongState, request: request))

        let denied = try XCTUnwrap(URL(string: "com.googleusercontent.apps.123-abc:/oauth2redirect?error=access_denied&state=s1"))
        XCTAssertThrowsError(try GoogleOAuth.authorizationCode(from: denied, request: request)) { (error: Error) in
            XCTAssertEqual(error as? AuthError, .cancelled)
        }

        let otherScheme = try XCTUnwrap(URL(string: "evil:/oauth2redirect?code=abc&state=s1"))
        XCTAssertThrowsError(try GoogleOAuth.authorizationCode(from: otherScheme, request: request))
    }

    func testTokenRequestBody() throws {
        let request = try XCTUnwrap(GoogleOAuth.makeRequest(configuration: configuration, verifier: "v~1", state: "s", nonce: "n"))
        let urlRequest = try XCTUnwrap(GoogleOAuth.tokenRequest(code: "4/0A+b", request: request, configuration: configuration))
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        let body = String(decoding: try XCTUnwrap(urlRequest.httpBody), as: UTF8.self)
        XCTAssertTrue(body.contains("grant_type=authorization_code"))
        XCTAssertTrue(body.contains("code=4%2F0A%2Bb"), "Kod zakodowany w formularzu")
        XCTAssertTrue(body.contains("code_verifier=v~1"))
        XCTAssertFalse(body.contains("client_secret"))
    }

    private func jwt(_ claims: [String: Any]) throws -> String {
        let header = AuthCrypto.base64URL(Data(#"{"alg":"RS256","typ":"JWT"}"#.utf8))
        let payload = AuthCrypto.base64URL(try JSONSerialization.data(withJSONObject: claims))
        return "\(header).\(payload).signature"
    }

    func testIdentityFromIDToken() throws {
        let request = try XCTUnwrap(GoogleOAuth.makeRequest(configuration: configuration, verifier: "v", state: "s", nonce: "n1"))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var claims: [String: Any] = [
            "sub": "1234567890",
            "aud": configuration.clientID,
            "iss": "https://accounts.google.com",
            "email": "ania@gmail.com",
            "email_verified": true,
            "name": "Ania Nowak",
            "nonce": "n1",
            "exp": 1_800_003_600
        ]
        let tokens = GoogleTokenResponse(accessToken: "at", expiresIn: 3600, refreshToken: nil, idToken: try jwt(claims), tokenType: "Bearer")
        let identity = try GoogleOAuth.identity(from: tokens, request: request, configuration: configuration, now: now)
        XCTAssertEqual(identity.subject, "1234567890")
        XCTAssertEqual(identity.email, "ania@gmail.com")
        XCTAssertTrue(identity.emailVerified)
        XCTAssertEqual(identity.name, "Ania Nowak")
        XCTAssertEqual(identity.expiresAt, now.addingTimeInterval(3600))

        claims["aud"] = "someone-else.apps.googleusercontent.com"
        let foreign = GoogleTokenResponse(accessToken: nil, expiresIn: nil, refreshToken: nil, idToken: try jwt(claims), tokenType: nil)
        XCTAssertThrowsError(try GoogleOAuth.identity(from: foreign, request: request, configuration: configuration, now: now))

        claims["aud"] = configuration.clientID
        claims["nonce"] = "other"
        let replay = GoogleTokenResponse(accessToken: nil, expiresIn: nil, refreshToken: nil, idToken: try jwt(claims), tokenType: nil)
        XCTAssertThrowsError(try GoogleOAuth.identity(from: replay, request: request, configuration: configuration, now: now))

        let decoded = try JSONDecoder().decode(GoogleTokenResponse.self, from: Data(#"{"access_token":"a","expires_in":3599,"id_token":"x.y.z","token_type":"Bearer"}"#.utf8))
        XCTAssertEqual(decoded.expiresIn, 3599)
        XCTAssertEqual(decoded.idToken, "x.y.z")
    }
}

@MainActor
final class AuthControllerTests: XCTestCase {
    /// Osobna domena UserDefaults na test (usuwana po teście).
    private func makeDefaults() throws -> UserDefaults {
        let name = "auth-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock {
            UserDefaults().removePersistentDomain(forName: name)
        }
        return defaults
    }

    private func makeController(secrets: InMemoryAuthSecretStore, defaults: UserDefaults?) -> AuthController {
        AuthController(
            service: LocalAuthService(secrets: secrets, iterations: 1_000),
            secrets: secrets,
            defaults: defaults,
            google: GoogleOAuthConfiguration(clientID: ""),
            isAppleSignInAvailable: false
        )
    }

    func testFreshInstallShowsSignIn() async throws {
        let defaults = try makeDefaults()
        let controller = makeController(secrets: InMemoryAuthSecretStore(), defaults: defaults)
        XCTAssertEqual(controller.status, .loading)
        await controller.bootstrap(hasExistingInstall: false)
        XCTAssertEqual(controller.status, .signedOut)
    }

    func testExistingUserBecomesGuestWithoutSignInScreen() async throws {
        let defaults = try makeDefaults()
        let controller = makeController(secrets: InMemoryAuthSecretStore(), defaults: defaults)
        await controller.bootstrap(hasExistingInstall: true)
        XCTAssertEqual(controller.status, .guest)
        XCTAssertTrue(defaults.bool(forKey: AuthController.guestKey))
    }

    func testGuestChoiceIsRemembered() async throws {
        let defaults = try makeDefaults()
        let secrets = InMemoryAuthSecretStore()
        let first = makeController(secrets: secrets, defaults: defaults)
        await first.bootstrap(hasExistingInstall: false)
        first.continueAsGuest()
        XCTAssertEqual(first.status, .guest)

        let second = makeController(secrets: secrets, defaults: defaults)
        await second.bootstrap(hasExistingInstall: false)
        XCTAssertEqual(second.status, .guest)
    }

    func testSignInPersistsSessionInSecretsAndSignOutClearsIt() async throws {
        let defaults = try makeDefaults()
        let secrets = InMemoryAuthSecretStore()
        let controller = makeController(secrets: secrets, defaults: defaults)
        await controller.bootstrap(hasExistingInstall: false)

        let error = await controller.register(email: "ania@example.com", password: "tajne-haslo-1", confirmation: "tajne-haslo-1", displayName: "Ania")
        XCTAssertNil(error)
        XCTAssertEqual(controller.session?.email, "ania@example.com")
        XCTAssertNotNil(try secrets.data(for: AuthSessionVault.account))
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("fluent.") || key.hasPrefix("auth.") {
            let value = "\(defaults.object(forKey: key) ?? "")"
            XCTAssertFalse(value.contains("ania"), "Nic osobowego w UserDefaults (\(key))")
        }

        let restarted = makeController(secrets: secrets, defaults: defaults)
        await restarted.bootstrap(hasExistingInstall: false)
        XCTAssertEqual(restarted.session?.email, "ania@example.com", "Sesja z pęku kluczy po ponownym uruchomieniu")

        await restarted.signOut()
        XCTAssertEqual(restarted.status, .signedOut)
        XCTAssertNil(try secrets.data(for: AuthSessionVault.account))
    }

    func testMismatchedPasswordsAndWrongPasswordShowMessages() async throws {
        let controller = makeController(secrets: InMemoryAuthSecretStore(), defaults: nil)
        await controller.bootstrap(hasExistingInstall: false)
        let mismatch = await controller.register(email: "ania@example.com", password: "tajne-haslo-1", confirmation: "inne", displayName: nil)
        XCTAssertEqual(mismatch, AuthError.passwordMismatch.errorDescription)
        let wrong = await controller.signIn(email: "ania@example.com", password: "tajne-haslo-1")
        XCTAssertEqual(wrong, AuthError.wrongCredentials.errorDescription)
        XCTAssertEqual(controller.status, .signedOut)
    }

    func testGoogleWithoutConfigurationShowsClearMessage() async {
        let controller = makeController(secrets: InMemoryAuthSecretStore(), defaults: nil)
        XCTAssertFalse(controller.google.isConfigured)
        XCTAssertEqual(AuthError.googleNotConfigured.errorDescription, "Logowanie Google będzie dostępne po konfiguracji.")
    }

    func testReinstallClearsStaleKeychainSession() async throws {
        let defaults = try makeDefaults()
        let secrets = InMemoryAuthSecretStore()
        // Pęk kluczy przeżył usunięcie aplikacji, a UserDefaults są puste (brak znacznika instalacji).
        try AuthSessionVault(secrets: secrets).save(AuthSession(userID: "email:old", provider: .email, email: "stary@example.com"))
        let controller = makeController(secrets: secrets, defaults: defaults)
        await controller.bootstrap(hasExistingInstall: false)
        XCTAssertEqual(controller.status, .signedOut)
        XCTAssertNil(try secrets.data(for: AuthSessionVault.account))
    }

    func testDeleteAccountSignsOutAndRemovesCredentials() async throws {
        let secrets = InMemoryAuthSecretStore()
        let controller = makeController(secrets: secrets, defaults: nil)
        await controller.bootstrap(hasExistingInstall: false)
        _ = await controller.register(email: "ania@example.com", password: "tajne-haslo-1", confirmation: "tajne-haslo-1", displayName: nil)
        let error = await controller.deleteAccount()
        XCTAssertNil(error)
        XCTAssertEqual(controller.status, .signedOut)
        XCTAssertTrue(secrets.accounts.isEmpty, "Ani sesji, ani konta")
    }
}
