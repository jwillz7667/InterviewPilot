import Foundation

struct UserSettingsSnapshot: Codable, Sendable {
    let defaultInterviewType: String
    let defaultResponseFormat: String
    let shouldPreGenerate: Bool
    /// nil = follow the server-wide default provider (no per-user override).
    let chatProvider: String?

    var interviewType: InterviewType {
        InterviewType(rawValue: defaultInterviewType) ?? .general
    }

    var responseFormat: ResponseFormat {
        ResponseFormat(rawValue: defaultResponseFormat) ?? .hybrid
    }

    var provider: AIProvider? {
        chatProvider.flatMap(AIProvider.init(rawValue:))
    }

    static let fallback = UserSettingsSnapshot(
        defaultInterviewType: InterviewType.general.rawValue,
        defaultResponseFormat: ResponseFormat.hybrid.rawValue,
        shouldPreGenerate: true,
        chatProvider: nil
    )
}

struct UserSettingsUpdate: Encodable, Sendable {
    var defaultInterviewType: String?
    var defaultResponseFormat: String?
    var shouldPreGenerate: Bool?
    var chatProvider: String?
}

final class UserSettingsService {
    static let shared = UserSettingsService()

    private let apiClient: AuthenticatedAPIClient

    init(apiClient: AuthenticatedAPIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchSettings() async throws -> UserSettingsSnapshot {
        let response: SettingsEnvelope = try await apiClient.get("/api/v1/settings")
        return response.settings
    }

    func updateSettings(_ update: UserSettingsUpdate) async throws -> UserSettingsSnapshot {
        let response: SettingsEnvelope = try await apiClient.put(
            "/api/v1/settings",
            body: update
        )
        return response.settings
    }
}

private struct SettingsEnvelope: Decodable {
    let settings: UserSettingsSnapshot
}
