import Foundation

enum AppEnvironment {
    static let defaultBackendBaseURL = "https://interviewpilot-production.up.railway.app"

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
