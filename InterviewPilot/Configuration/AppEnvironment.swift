import Foundation

enum AppEnvironment {
    static let defaultBackendBaseURL = "https://interviewpilot-production.up.railway.app"

    static var backendBaseURL: String {
        if let configuredURL = Bundle.main.object(forInfoDictionaryKey: "BACKEND_BASE_URL") as? String {
            let trimmed = configuredURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return defaultBackendBaseURL
    }

    /// API keys are fetched from the backend after authentication
    /// and stored in Keychain for direct API access
    static var isConfigured: Bool {
        KeychainService.hasKey(.deepgramAPIKey) && KeychainService.hasKey(.openAIAPIKey)
    }

    static var isAuthenticated: Bool {
        AuthService.shared.isAuthenticated
    }
}
