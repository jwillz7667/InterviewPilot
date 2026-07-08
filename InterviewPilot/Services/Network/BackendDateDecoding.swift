import Foundation

/// The backend serializes Prisma `Date` values via `JSON.stringify`, which
/// always emits fractional seconds ("2026-07-08T12:00:00.000Z"). Swift's
/// built-in `.iso8601` strategy rejects fractional seconds, so every
/// Date-bearing response would fail to decode without this strategy. Accepts
/// both fractional and whole-second forms.
extension JSONDecoder.DateDecodingStrategy {
    static let backendISO8601 = JSONDecoder.DateDecodingStrategy.custom { decoder in
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        if let date = ISO8601DateParsers.fractional.date(from: value)
            ?? ISO8601DateParsers.whole.date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Unrecognized ISO8601 date: \(value)"
        )
    }
}

/// ISO8601DateFormatter is thread-safe, but its `formatOptions` must not be
/// mutated after creation — hence two preconfigured instances.
enum ISO8601DateParsers {
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let whole: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
