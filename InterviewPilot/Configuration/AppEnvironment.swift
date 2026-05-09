import Foundation

enum AppEnvironment {
    static let defaultBackendBaseURL = "https://interviewpilot-production.up.railway.app"
    /// HTTPS redirect URI registered with LinkedIn. LinkedIn does not accept
    /// custom URL schemes here, so we use a backend bridge that 302s to the
    /// native callback URI. Must match the backend's `LINKEDIN_REDIRECT_URI`
    /// env var exactly. Override via Info.plist key `LINKEDIN_REDIRECT_URI`.
    static let defaultLinkedInRedirectURI =
        "https://interviewpilot-production.up.railway.app/auth/linkedin/callback"
    /// Custom URL scheme that ASWebAuthenticationSession listens for. The
    /// backend bridge route 302s to this scheme after LinkedIn returns the
    /// authorization code. Override via Info.plist key `LINKEDIN_CALLBACK_SCHEME`.
    static let defaultLinkedInCallbackScheme = "com.res.jobhopperAI"

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

    /// Custom-scheme component passed to ASWebAuthenticationSession's
    /// `callbackURLScheme`. Decoupled from `linkedInRedirectURI` because the
    /// LinkedIn-facing redirect URL is HTTPS (LinkedIn rejects custom schemes)
    /// while the iOS app needs to listen for the bridge's 302 target.
    static var linkedInCallbackScheme: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "LINKEDIN_CALLBACK_SCHEME") as? String {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return defaultLinkedInCallbackScheme
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
