import Foundation

struct SessionSyncSnapshot: Sendable {
    let clientId: UUID
    let startedAt: Date
    let endedAt: Date?
    let resumeText: String
    let jobDescription: String
    let interviewType: String
    let responseFormat: String
    let modelUsed: String
    let totalTokensUsed: Int
    let estimatedCost: Double
    let exchanges: [ExchangeSyncSnapshot]
}

struct ExchangeSyncSnapshot: Sendable {
    let clientId: UUID
    let timestamp: Date
    let questionTranscript: String
    let questionType: String
    let generatedResponse: String
    let responseLatencyMs: Int
    let wasPreComputed: Bool
    let sequenceOrder: Int
}

final class RemoteSessionSyncService {
    private let authService: AuthService
    private let baseURL: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        authService: AuthService = .shared,
        baseURL: String = AppEnvironment.backendBaseURL
    ) {
        self.authService = authService
        self.baseURL = baseURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func syncSession(_ snapshot: SessionSyncSnapshot) async throws {
        let sessionResponse: SessionEnvelope = try await sendRequest(
            path: "/api/v1/sessions",
            method: "POST",
            body: CreateSessionRequest(snapshot: snapshot),
            expectedStatusCodes: [201]
        )

        guard !snapshot.exchanges.isEmpty else { return }

        _ = try await sendRequest(
            path: "/api/v1/sessions/\(sessionResponse.session.id)/exchanges/sync",
            method: "POST",
            body: SyncExchangesRequest(exchanges: snapshot.exchanges),
            expectedStatusCodes: [200]
        ) as SyncExchangesResponse
    }

    private func sendRequest<Body: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Body,
        expectedStatusCodes: Set<Int>,
        retryingUnauthorized: Bool = true
    ) async throws -> Response {
        let url = try buildURL(path: path)
        var request = try await authenticatedRequest(for: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SessionSyncError.invalidResponse
        }

        if httpResponse.statusCode == 401, retryingUnauthorized {
            guard let refreshedToken = await authService.refreshTokenIfNeeded() else {
                throw SessionSyncError.unauthenticated
            }

            request.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")
            return try await sendRequest(
                request: request,
                expectedStatusCodes: expectedStatusCodes
            )
        }

        return try decodeResponse(
            data: data,
            response: httpResponse,
            expectedStatusCodes: expectedStatusCodes
        )
    }

    private func sendRequest<Response: Decodable>(
        request: URLRequest,
        expectedStatusCodes: Set<Int>
    ) async throws -> Response {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SessionSyncError.invalidResponse
        }

        return try decodeResponse(
            data: data,
            response: httpResponse,
            expectedStatusCodes: expectedStatusCodes
        )
    }

    private func decodeResponse<Response: Decodable>(
        data: Data,
        response: HTTPURLResponse,
        expectedStatusCodes: Set<Int>
    ) throws -> Response {
        guard expectedStatusCodes.contains(response.statusCode) else {
            let apiError = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw SessionSyncError.server(
                apiError?.message ?? apiError?.error ?? "Request failed (\(response.statusCode))"
            )
        }

        return try decoder.decode(Response.self, from: data)
    }

    private func authenticatedRequest(for url: URL) async throws -> URLRequest {
        guard let request = await authService.authenticatedRequest(url: url) else {
            throw SessionSyncError.unauthenticated
        }
        return request
    }

    private func buildURL(path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw SessionSyncError.invalidURL
        }
        return url
    }
}

private struct CreateSessionRequest: Encodable, Sendable {
    let clientId: UUID
    let startedAt: Date
    let endedAt: Date?
    let resumeText: String
    let jobDescription: String
    let interviewType: String
    let responseFormat: String
    let modelUsed: String
    let totalTokensUsed: Int
    let estimatedCost: Double

    nonisolated init(snapshot: SessionSyncSnapshot) {
        self.clientId = snapshot.clientId
        self.startedAt = snapshot.startedAt
        self.endedAt = snapshot.endedAt
        self.resumeText = snapshot.resumeText
        self.jobDescription = snapshot.jobDescription
        self.interviewType = snapshot.interviewType
        self.responseFormat = snapshot.responseFormat
        self.modelUsed = snapshot.modelUsed
        self.totalTokensUsed = snapshot.totalTokensUsed
        self.estimatedCost = snapshot.estimatedCost
    }
}

private struct SyncExchangesRequest: Encodable, Sendable {
    let exchanges: [ExchangeRequest]

    nonisolated init(exchanges: [ExchangeSyncSnapshot]) {
        self.exchanges = exchanges.map(ExchangeRequest.init(snapshot:))
    }
}

private struct ExchangeRequest: Encodable, Sendable {
    let clientId: UUID
    let timestamp: Date
    let questionTranscript: String
    let questionType: String
    let generatedResponse: String
    let responseLatencyMs: Int
    let wasPreComputed: Bool
    let sequenceOrder: Int

    nonisolated init(snapshot: ExchangeSyncSnapshot) {
        self.clientId = snapshot.clientId
        self.timestamp = snapshot.timestamp
        self.questionTranscript = snapshot.questionTranscript
        self.questionType = snapshot.questionType
        self.generatedResponse = snapshot.generatedResponse
        self.responseLatencyMs = snapshot.responseLatencyMs
        self.wasPreComputed = snapshot.wasPreComputed
        self.sequenceOrder = snapshot.sequenceOrder
    }
}

private struct SessionEnvelope: Decodable {
    let session: SessionRecord
}

private struct SessionRecord: Decodable {
    let id: String
}

private struct SyncExchangesResponse: Decodable {
    let synced: Int
}

private struct APIErrorEnvelope: Decodable {
    let error: String?
    let message: String?
}

private enum SessionSyncError: LocalizedError {
    case invalidURL
    case unauthenticated
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .unauthenticated:
            return "Authentication required"
        case .invalidResponse:
            return "Invalid server response"
        case .server(let message):
            return message
        }
    }
}
