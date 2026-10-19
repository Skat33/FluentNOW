import Foundation
import CryptoKit
import CommonCrypto
import Security

/// Kryptografia logowania: losowość (`SecRandomCopyBytes`), base64url, SHA-256 (CryptoKit),
/// PBKDF2-HMAC-SHA256 (CommonCrypto) i porównanie w stałym czasie.
enum AuthCrypto {
    /// Liczba iteracji PBKDF2-HMAC-SHA256 dla nowych haseł (zalecenie OWASP 2023: 600 000).
    /// Zapisywana przy koncie — zmiana nie psuje starych kont.
    static let defaultIterations = 600_000
    static let saltLength = 16
    static let derivedKeyLength = 32

    /// Kryptograficznie bezpieczne losowe bajty. `nil` tylko przy awarii generatora systemu.
    static func randomBytes(_ count: Int) -> [UInt8]? {
        guard count > 0 else { return [] }
        var bytes = [UInt8](repeating: 0, count: count)
        let status = bytes.withUnsafeMutableBytes { (buffer: UnsafeMutableRawBufferPointer) -> Int32 in
            guard let base = buffer.baseAddress else { return errSecAllocate }
            return SecRandomCopyBytes(kSecRandomDefault, count, base)
        }
        return status == errSecSuccess ? bytes : nil
    }

    /// Losowy ciąg base64url (np. `state`, `nonce`, `code_verifier` — 32 bajty → 43 znaki).
    static func randomToken(byteCount: Int = 32) -> String? {
        randomBytes(byteCount).map { base64URL(Data($0)) }
    }

    /// Base64url bez dopełnienia (RFC 4648 §5).
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Dekodowanie base64url (z brakującym dopełnieniem).
    static func data(base64URL text: String) -> Data? {
        var base64 = text
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder == 1 { return nil }
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }

    static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    /// SHA-256 tekstu jako szesnastkowy ciąg małych liter (np. nonce dla Apple).
    static func sha256Hex(_ text: String) -> String {
        sha256(Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// PBKDF2-HMAC-SHA256. `nil` przy pustym haśle/soli lub błędzie CommonCrypto.
    static func pbkdf2(password: String, salt: [UInt8], iterations: Int, length: Int = derivedKeyLength) -> [UInt8]? {
        let passwordBytes = Array(password.utf8)
        guard !passwordBytes.isEmpty, !salt.isEmpty, iterations > 0, length > 0,
              iterations <= Int(UInt32.max) else { return nil }
        var derived = [UInt8](repeating: 0, count: length)
        let status = passwordBytes.withUnsafeBufferPointer { (passwordBuffer: UnsafeBufferPointer<UInt8>) -> Int32 in
            salt.withUnsafeBufferPointer { (saltBuffer: UnsafeBufferPointer<UInt8>) -> Int32 in
                derived.withUnsafeMutableBufferPointer { (output: inout UnsafeMutableBufferPointer<UInt8>) -> Int32 in
                    let passwordPointer = UnsafeRawPointer(passwordBuffer.baseAddress)?.assumingMemoryBound(to: CChar.self)
                    return CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPointer,
                        passwordBuffer.count,
                        saltBuffer.baseAddress,
                        saltBuffer.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(iterations),
                        output.baseAddress,
                        output.count
                    )
                }
            }
        }
        return status == Int32(kCCSuccess) ? derived : nil
    }

    /// Porównanie bez wczesnego wyjścia (czas nie zdradza, ile bajtów się zgadza).
    static func constantTimeEquals(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for index in 0..<lhs.count {
            difference |= lhs[index] ^ rhs[index]
        }
        return difference == 0
    }
}
