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

    /// All AI calls flow through the backend proxy — no master keys are
    /// held on-device. Authentication alone determines whether AI features
    /// are usable; per-feature gating is enforced by `BillingEntitlement`.
    static var isConfigured: Bool {
        AuthService.shared.isAuthenticated
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
