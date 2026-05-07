import Foundation

/// Quality dimension of an interview slot. Sent server-side at quota-claim time
/// and locked into the SessionAccessGrant — never derived client-side.
///
/// Distinct from `ResponseQualityMode`, which is the legacy in-prompt knob
/// (free/standard/premium tonal directives). This enum represents the
/// monetized engine tier (standard models vs. premium models + bigger token
/// budget). The backend uses the raw values `STANDARD` / `PREMIUM`.
enum InterviewQuality: String, Codable, Sendable, CaseIterable, Identifiable {
    case standard = "STANDARD"
    case premium = "PREMIUM"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .premium: return "Premium"
        }
    }

    var subtitle: String {
        switch self {
        case .standard:
            return "Fast, candidate-ready answers."
        case .premium:
            return "Deeper reasoning, more headroom, coding-aware models."
        }
    }

    /// Engine ladder. Used to surface the right paywall reason and to convert
    /// `ResponseQualityMode` into `InterviewQuality` when only one is known.
    var rank: Int {
        switch self {
        case .standard: return 0
        case .premium: return 1
        }
    }

    /// Bridge from the legacy in-prompt quality mode. `.free` and `.standard`
    /// both map to `.standard`; `.premium` maps to `.premium`.
    init(legacyMode: ResponseQualityMode) {
        switch legacyMode {
        case .free, .standard:
            self = .standard
        case .premium:
            self = .premium
        }
    }
}
