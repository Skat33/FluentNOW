import Foundation

/// Milliseconds since 1970-01-01 UTC, stored as `Double` exactly like the web app (`Date.now()`).
///
/// FluentKit keeps every persisted time as a `Timestamp` so that JSON exported by the web app
/// (plain millisecond numbers) decodes without conversion and round-trips losslessly.
/// Use `Date(timestamp:)` / `Date.timestamp` at the UI boundary.
public typealias Timestamp = Double

/// Time constants shared by the scheduling code.
public enum TimeConstants {
    /// One day in milliseconds (86 400 000).
    public static let dayMs: Double = 86_400_000
    /// One hour in milliseconds.
    public static let hourMs: Double = 3_600_000
}

/// The only place in FluentKit that reads the system clock.
/// All logic receives `now` as a parameter; call sites in the app pass `FluentClock.now()`.
public enum FluentClock {
    /// Current time as milliseconds since 1970.
    public static func now() -> Timestamp {
        Date().timeIntervalSince1970 * 1000
    }
}

extension Date {
    /// Creates a date from a FluentKit millisecond timestamp.
    public init(timestamp: Timestamp) {
        self.init(timeIntervalSince1970: timestamp / 1000)
    }

    /// This date as a FluentKit millisecond timestamp.
    public var timestamp: Timestamp {
        timeIntervalSince1970 * 1000
    }
}

/// JavaScript `Math.round` semantics (halves round towards +infinity).
/// Used everywhere the web app rounds, so percentages match exactly.
@inline(__always)
func jsRound(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return (value + 0.5).rounded(.down)
}

/// `jsRound` converted to `Int`, safe for non-finite input.
@inline(__always)
func jsRoundInt(_ value: Double) -> Int {
    let rounded = jsRound(value)
    if rounded >= Double(Int.max) { return Int.max }
    if rounded <= Double(Int.min) { return Int.min }
    return Int(rounded)
}

/// Replaces non-finite or negative numbers with a fallback.
@inline(__always)
func finiteNonNegative(_ value: Double, fallback: Double = 0) -> Double {
    value.isFinite && value >= 0 ? value : fallback
}
