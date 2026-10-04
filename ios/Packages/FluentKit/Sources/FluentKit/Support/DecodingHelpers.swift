import Foundation

/// Wraps an element so a single malformed array element does not fail the whole array.
struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: Decoder) throws {
        value = try? Value(from: decoder)
    }
}

extension KeyedDecodingContainer {
    /// Decodes an optional value; a missing key or `null` yields `fallback`.
    /// A present value of the wrong type still throws (strict fields).
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key, default fallback: @autoclosure () -> T) throws -> T {
        if let value = try decodeIfPresent(type, forKey: key) {
            return value
        }
        return fallback()
    }

    /// Lenient string: missing, `null` or wrong type → `fallback`. Numbers are converted to text.
    func lenientString(_ key: Key, default fallback: String = "") -> String {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let number = try? decodeIfPresent(Double.self, forKey: key) {
            if number.isFinite, number == number.rounded(), abs(number) < 1e15 {
                return String(Int(number))
            }
            return String(number)
        }
        return fallback
    }

    /// Lenient optional string: missing / `null` / wrong type → `nil`.
    func lenientOptionalString(_ key: Key) -> String? {
        (try? decodeIfPresent(String.self, forKey: key)) ?? nil
    }

    /// Lenient number: accepts JSON numbers; missing, `null`, wrong type or non-finite → `fallback`.
    func lenientDouble(_ key: Key, default fallback: Double = 0) -> Double {
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite {
            return value
        }
        return fallback
    }

    /// Lenient optional number.
    func lenientOptionalDouble(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite {
            return value
        }
        return nil
    }

    /// Lenient integer: accepts integral or fractional JSON numbers (rounded like `Math.round`).
    func lenientInt(_ key: Key, default fallback: Int = 0) -> Int {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite, abs(value) < 1e15 {
            return jsRoundInt(value)
        }
        return fallback
    }

    /// Lenient optional integer.
    func lenientOptionalInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite, abs(value) < 1e15 {
            return jsRoundInt(value)
        }
        return nil
    }

    /// Lenient boolean: missing, `null` or wrong type → `fallback`.
    func lenientBool(_ key: Key, default fallback: Bool = false) -> Bool {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        return fallback
    }

    /// Lenient string array: non-string elements are skipped, missing / wrong type → `[]`.
    func lenientStrings(_ key: Key) -> [String] {
        if let values = try? decodeIfPresent([FailableDecodable<String>].self, forKey: key) {
            return values.compactMap { $0.value }
        }
        return []
    }

    /// Lenient optional string array: missing / `null` / wrong type → `nil`.
    func lenientOptionalStrings(_ key: Key) -> [String]? {
        guard let values = try? decodeIfPresent([FailableDecodable<String>].self, forKey: key) else {
            return nil
        }
        return values.compactMap { $0.value }
    }

    /// Lenient optional integer array.
    func lenientOptionalInts(_ key: Key) -> [Int]? {
        guard let values = try? decodeIfPresent([FailableDecodable<Double>].self, forKey: key) else {
            return nil
        }
        return values.compactMap { box -> Int? in
            guard let value = box.value, value.isFinite, abs(value) < 1e15 else { return nil }
            return jsRoundInt(value)
        }
    }

    /// Lossy array: malformed elements are skipped; missing / `null` / wrong type → `[]`.
    func lossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
        if let values = try? decodeIfPresent([FailableDecodable<T>].self, forKey: key) {
            return values.compactMap { $0.value }
        }
        return []
    }

    /// Optional value that is dropped (→ `nil`) instead of failing when malformed.
    func lenientOptional<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}

/// A coding key built from an arbitrary string (dictionary-like JSON objects).
struct AnyCodingKey: CodingKey, Hashable {
    var stringValue: String
    var intValue: Int?

    init(_ string: String) {
        self.stringValue = string
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
