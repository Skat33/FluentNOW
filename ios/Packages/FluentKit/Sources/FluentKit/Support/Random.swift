import Foundation

/// Deterministic SplitMix64 generator. Use it in tests and anywhere a reproducible
/// sequence is required (e.g. answer-option shuffling that must not change on re-render).
public struct SeededGenerator: RandomNumberGenerator, Sendable, Hashable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed
    }

    /// Seeds the generator from a string (FNV-1a over UTF-16 code units).
    public init(seed text: String) {
        self.state = UInt64(FNV1a.hash32(text))
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension RandomNumberGenerator {
    /// Uniform `Double` in `0..<1` (53 random bits), the Swift counterpart of `Math.random()`.
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// Uniform index in `0..<count` computed like the web app: `floor(random() * count)`,
    /// clamped to the last valid index. Returns 0 when `count <= 0`.
    mutating func nextIndex(below count: Int) -> Int {
        guard count > 0 else { return 0 }
        let value = Int(nextUnit() * Double(count))
        return min(count - 1, max(0, value))
    }
}

/// 32-bit FNV-1a over UTF-16 code units, bit-identical to the web app's
/// `Math.imul(n ^ c, 16777619) >>> 0` hash in `grammar-bank.ts`.
enum FNV1a {
    static func hash32(_ text: String) -> UInt32 {
        var value: UInt32 = 2_166_136_261
        for unit in text.utf16 {
            value = (value ^ UInt32(unit)) &* 16_777_619
        }
        return value
    }
}
