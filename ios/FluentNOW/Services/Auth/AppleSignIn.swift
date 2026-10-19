import Foundation
import AuthenticationServices
import MachO

/// „Zaloguj przez Apple” (AuthenticationServices). Przycisk `SignInWithAppleButton` jest w UI
/// (`AuthWelcomeScreen`); tu: wykrycie uprawnienia, nonce, zamiana poświadczenia na
/// `AppleIdentity`, sprawdzenie stanu poświadczenia przy starcie i mapowanie błędów.
enum AppleSignIn {
    static let entitlementKey = "com.apple.developer.applesignin"

    /// Czy aplikacja jest podpisana z uprawnieniem „Sign in with Apple” (wymaga płatnego konta
    /// deweloperskiego). Bez niego przycisk pokazuje komunikat zamiast błędu systemu.
    /// Odczyt jak w `CloudKitAvailability`: profil `embedded.mobileprovision` na urządzeniu,
    /// sekcja `__TEXT,__entitlements` w symulatorze, brak profilu = App Store/TestFlight (jest).
    static let hasEntitlement: Bool = computeEntitlement()

    private static func computeEntitlement() -> Bool {
        #if targetEnvironment(simulator)
        guard let entitlements = simulatorEntitlements() else { return false }
        return containsSignInWithApple(entitlements)
        #else
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else {
            return true
        }
        guard let data = try? Data(contentsOf: url),
              let profile = CloudKitAvailability.provisioningPlist(from: data),
              let entitlements = profile["Entitlements"] as? [String: Any] else {
            return false
        }
        return containsSignInWithApple(entitlements)
        #endif
    }

    static func containsSignInWithApple(_ entitlements: [String: Any]) -> Bool {
        if let values = entitlements[entitlementKey] as? [String] {
            return !values.isEmpty
        }
        return entitlements[entitlementKey] is String
    }

    #if targetEnvironment(simulator)
    private static func simulatorEntitlements() -> [String: Any]? {
        guard let header = _dyld_get_image_header(0) else { return nil }
        var size: UInt = 0
        let raw = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
        guard let bytes = getsectiondata(raw, "__TEXT", "__entitlements", &size), size > 0 else { return nil }
        let data = Data(bytes: bytes, count: Int(size))
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
    }
    #endif

    /// Tożsamość z wyniku autoryzacji; `nil`, gdy to nie jest poświadczenie Apple ID.
    static func identity(from authorization: ASAuthorization) -> AppleIdentity? {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return nil }
        let name = credential.fullName.map { (components: PersonNameComponents) -> String in
            PersonNameComponentsFormatter.localizedString(from: components, style: .default, options: [])
        }
        return AppleIdentity(
            user: credential.user,
            email: credential.email,
            fullName: name,
            identityToken: credential.identityToken.flatMap { String(data: $0, encoding: .utf8) },
            authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        )
    }

    /// Błąd systemu → komunikat. `ASAuthorizationError.unknown` (1000) pojawia się m.in. bez
    /// uprawnienia albo bez zalogowanego Apple ID na urządzeniu/symulatorze.
    static func mapError(_ error: Error) -> AuthError {
        if let authorizationError = error as? ASAuthorizationError {
            switch authorizationError.code {
            case .canceled:
                return .cancelled
            case .unknown:
                return hasEntitlement
                    ? .appleFailed("Sprawdź, czy na urządzeniu jesteś zalogowany do Apple ID.")
                    : .appleNotConfigured
            default:
                return .appleFailed(authorizationError.localizedDescription)
            }
        }
        return .appleFailed(error.localizedDescription)
    }

    /// Czy konto Apple nadal autoryzuje aplikację (`false` = cofnięto zgodę lub brak — wyloguj).
    /// Błąd/brak odpowiedzi = `true` (nie wylogowujemy offline).
    static func isCredentialValid(user: String) async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: user) { (state: ASAuthorizationAppleIDProvider.CredentialState, error: Error?) in
                if error != nil {
                    continuation.resume(returning: true)
                    return
                }
                switch state {
                case .revoked, .notFound:
                    continuation.resume(returning: false)
                default:
                    continuation.resume(returning: true)
                }
            }
        }
    }
}
