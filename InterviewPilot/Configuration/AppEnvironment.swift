import Foundation

enum AppEnvironment {
    /// API keys are fetched from the backend after authentication
    /// and stored in Keychain for direct API access
    static var isConfigured: Bool {
        KeychainService.hasKey(.deepgramAPIKey) && KeychainService.hasKey(.openAIAPIKey)
    }

    static var isAuthenticated: Bool {
        AuthService.shared.isAuthenticated
    }
}
