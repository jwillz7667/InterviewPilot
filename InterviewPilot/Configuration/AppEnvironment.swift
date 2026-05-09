import Foundation

enum AppEnvironment {
    static let defaultBackendBaseURL = "https://interviewpilot-production.up.railway.app"
    /// Default redirect URI for the Sign In with LinkedIn flow. Must be
    /// registered in the LinkedIn Developer Portal and match the backend's
    /// `LINKEDIN_REDIRECT_URI` env var. Override via Info.plist key
    /// `LINKEDIN_REDIRECT_URI` for environments that need a different value.
    static let defaultLinkedInRedirectURI = "com.res.jobhopperAI://oauth/linkedin/callback"

    static var backendBaseURL: String {
        #if DEBUG
        // Local-dev override takes precedence so the simulator can hit a dev backend
        // without rewriting Info.plist on every iteration.
        if ProcessInfo.processInfo.environment["INTERVIEWPILOT_USE_LOCAL_BACKEND"] == "1" {
            return "http://localhost:3000"
        }
        #endif

        if let configuredURL = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String {
            let trimmed = configuredURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return defaultBackendBaseURL
    }

    static var linkedInRedirectURI: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "LINKEDIN_REDIRECT_URI") as? String {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return defaultLinkedInRedirectURI
    }

    /// Custom-scheme component used by ASWebAuthenticationSession's
    /// `callbackURLScheme`. Derived from `linkedInRedirectURI`.
    static var linkedInCallbackScheme: String {
        let uri = linkedInRedirectURI
        if let schemeRange = uri.range(of: "://") {
            return String(uri[uri.startIndex..<schemeRange.lowerBound])
        }
        return uri
    }

    /// All AI calls flow through the backend proxy — no master keys are
    /// held on-device. Authentication alone determines whether AI features
    /// are usable; per-feature gating is enforced by `BillingEntitlement`.
    static var isConfigured: Bool {
        AuthService.shared.isAuthenticated
    }

    static var isAuthenticated: Bool {
        AuthService.shared.isAuthenticated
    }
}
