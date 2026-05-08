import Foundation

@Observable
final class SessionsService {
    static let shared = SessionsService()

    @ObservationIgnored private let api: AuthenticatedAPIClient

    init(api: AuthenticatedAPIClient = .shared) {
        self.api = api
    }

    private struct ListResponse: Decodable {
        let sessions: [AuthSession]
    }

    private struct RevokeResponse: Decodable {
        let revokedCount: Int
    }

    private struct ListBody: Encodable {
        let refreshToken: String?
    }

    private struct RevokeBody: Encodable {
        let refreshToken: String?
        let deviceId: String?
        let allOthers: Bool?
    }

    func listSessions() async throws -> [AuthSession] {
        let body = ListBody(refreshToken: KeychainService.load(key: .refreshToken))
        let response: ListResponse = try await api.post(
            "/api/v1/auth/sessions/list",
            body: body
        )
        return response.sessions
    }

    @discardableResult
    func revokeSession(deviceId: String) async throws -> Int {
        let body = RevokeBody(
            refreshToken: KeychainService.load(key: .refreshToken),
            deviceId: deviceId,
            allOthers: nil
        )
        let response: RevokeResponse = try await api.post(
            "/api/v1/auth/sessions/revoke",
            body: body,
            idempotencyKey: UUID().uuidString
        )
        return response.revokedCount
    }

    @discardableResult
    func revokeAllOtherSessions() async throws -> Int {
        let body = RevokeBody(
            refreshToken: KeychainService.load(key: .refreshToken),
            deviceId: nil,
            allOthers: true
        )
        let response: RevokeResponse = try await api.post(
            "/api/v1/auth/sessions/revoke",
            body: body,
            idempotencyKey: UUID().uuidString
        )
        return response.revokedCount
    }
}
