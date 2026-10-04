import Foundation

/// FluentKit — pure domain logic of FluentNOW (models, spaced repetition, sessions, grading,
/// content, sync, import/export, statistics). No UI or persistence frameworks.
///
/// Conventions:
/// - all times are `Timestamp` (milliseconds since 1970 as `Double`, like the web app) and are
///   passed in as `now:`; nothing reads the clock except `FluentClock.now()`;
/// - randomness is injected (`inout some RandomNumberGenerator`, `SeededGenerator` for tests);
/// - every function is pure: a state goes in, a new state comes out.
public enum FluentKitInfo {
    /// Version of this package's API contract.
    public static let version = "1.0.0"
    /// Web app version whose behaviour and JSON format this package follows.
    public static let webCompatibility = "web-v42"
}
