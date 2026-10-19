import Foundation

/// Magazyn sekretów logowania (sesja, konta lokalne). Produkcyjnie pęk kluczy
/// (`KeychainAuthSecretStore`), w testach i podglądach pamięć.
protocol AuthSecretStore: Sendable {
    func data(for account: String) throws -> Data?
    func set(_ data: Data, for account: String) throws
    func remove(_ account: String)
}

/// Pęk kluczy: osobna usługa `pl.fluentnow.app.auth`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`,
/// bez synchronizacji iCloud (logika w `KeychainStore`, platform-services). Dane są zapisywane jako
/// JSON w UTF-8 (base64 nie jest potrzebne — `KeychainStore` przechowuje tekst).
struct KeychainAuthSecretStore: AuthSecretStore {
    static let service = "pl.fluentnow.app.auth"
    private let keychain: KeychainStore

    init(service: String = KeychainAuthSecretStore.service) {
        self.keychain = KeychainStore(service: service)
    }

    func data(for account: String) throws -> Data? {
        do {
            return try keychain.string(for: account).map { Data($0.utf8) }
        } catch {
            throw AuthError.storage(error.localizedDescription)
        }
    }

    func set(_ data: Data, for account: String) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw AuthError.storage("Nieprawidłowe dane.")
        }
        do {
            try keychain.set(text, for: account)
        } catch {
            throw AuthError.storage(error.localizedDescription)
        }
    }

    func remove(_ account: String) {
        keychain.remove(account)
    }
}

/// Magazyn w pamięci (podglądy, testy).
final class InMemoryAuthSecretStore: AuthSecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    init() {}

    func data(for account: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[account]
    }

    func set(_ data: Data, for account: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[account] = data
    }

    func remove(_ account: String) {
        lock.lock()
        defer { lock.unlock() }
        values[account] = nil
    }

    /// Klucze (do asercji w testach).
    var accounts: [String] {
        lock.lock()
        defer { lock.unlock() }
        return values.keys.sorted()
    }
}

/// Bieżąca sesja w magazynie sekretów (jeden wpis `session`).
struct AuthSessionVault: Sendable {
    static let account = "session"
    let secrets: any AuthSecretStore

    func load() -> AuthSession? {
        guard let data = try? secrets.data(for: Self.account) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        try secrets.set(data, for: Self.account)
    }

    func clear() {
        secrets.remove(Self.account)
    }
}
