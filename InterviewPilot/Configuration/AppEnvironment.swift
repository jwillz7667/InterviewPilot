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

    static var developerFullAccessEmails: Set<String> {
        if let configuredEmails = Bundle.main.object(forInfoDictionaryKey: "DEVELOPER_FULL_ACCESS_EMAILS") as? [String] {
            return Set(
                configuredEmails
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        }

        if let configuredEmails = Bundle.main.object(forInfoDictionaryKey: "DEVELOPER_FULL_ACCESS_EMAILS") as? String {
            return Set(
                configuredEmails
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
            )
        }

        return []
    }

    static var developerOpenAIAPIKey: String? {
        configuredString(forInfoDictionaryKey: "DEVELOPER_OPENAI_API_KEY")
    }

    static var developerDeepgramAPIKey: String? {
        configuredString(forInfoDictionaryKey: "DEVELOPER_DEEPGRAM_API_KEY")
    }

    static func hasDeveloperFullAccess(email: String?) -> Bool {
        guard let normalizedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !normalizedEmail.isEmpty else {
            return false
        }

        return developerFullAccessEmails.contains(normalizedEmail)
    }

    private static func configuredString(forInfoDictionaryKey key: String) -> String? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
