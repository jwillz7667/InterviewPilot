import Foundation

/// Strongly-typed subscription tier matching the backend `SubscriptionTier`
/// enum. The backend serializes lowercase (`free`, `pro`, `premium`, etc.).
///
/// `.plus` and `.trial` are deprecated values kept for legacy rows: the
/// backend remaps them on read so live entitlements never use them, but the
/// decoder must still accept them. UI surfaces should call
/// `canonicalDisplayTier` to fold those into their post-migration equivalent.
enum SubscriptionTier: String, Codable, Sendable, CaseIterable {
    case free
    case trial
    case plus
    case pro
    case premium
    case sandbox

    /// Lenient decoder so an unknown value (e.g. a future tier introduced
    /// server-side) decodes to `.free` rather than crashing the app.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self).lowercased()
        self = SubscriptionTier(rawValue: raw) ?? .free
    }

    /// Stable rank used to compare tiers in upgrade flows (`.premium` is the
    /// highest non-internal tier). Sandbox sits above premium for testers but
    /// is not promoted to end users.
    var rank: Int {
        switch self {
        case .free: return 0
        case .trial: return 0
        case .plus: return 1
        case .pro: return 1
        case .premium: return 2
        case .sandbox: return 3
        }
    }

    /// Per-marketing display name. `.plus` and `.trial` are folded into the
    /// post-migration equivalent so legacy entitlement rows render correctly.
    var planTitle: String {
        switch self {
        case .free: return "Free"
        case .trial: return "Free"
        case .plus: return "Pro"
        case .pro: return "Pro"
        case .premium: return "Premium"
        case .sandbox: return "Sandbox"
        }
    }

    /// The tier this row should be presented as in the UI. Backend already
    /// remaps storage but we double-fold here so legacy cached entitlements
    /// from older builds don't show the deprecated label.
    var canonicalDisplayTier: SubscriptionTier {
        switch self {
        case .plus: return .pro
        case .trial: return .free
        default: return self
        }
    }

    /// True when this tier ships unlimited interviews (premium + sandbox).
    /// Used by the paywall to suppress "remaining" copy.
    var hasUnlimitedQuota: Bool {
        switch self {
        case .premium, .sandbox: return true
        default: return false
        }
    }

    /// Standard-quality interview cap per 30-day window. Mirrors backend
    /// `TIER_QUOTA` — kept here for offline UI rendering only; the source of
    /// truth lives on the server.
    var defaultStandardQuota: Int {
        switch self {
        case .free, .trial: return 3
        case .plus, .pro: return 25
        case .premium, .sandbox: return -1
        }
    }

    /// Premium-quality interview cap per 30-day window.
    var defaultPremiumQuota: Int {
        switch self {
        case .free, .trial: return 1
        case .plus, .pro: return 10
        case .premium, .sandbox: return -1
        }
    }
}
