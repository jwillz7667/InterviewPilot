import Foundation

final class RemoteSessionsService {
    static let shared = RemoteSessionsService()

    private let apiClient: AuthenticatedAPIClient

    init(apiClient: AuthenticatedAPIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchSessions(limit: Int = 50) async throws -> [SessionHistoryItem] {
        let response: SessionListEnvelope = try await apiClient.get("/api/v1/sessions?limit=\(limit)")
        return response.data.map { $0.sessionHistoryItem(includeExchanges: false) }
    }

    func fetchSessionDetail(id: String) async throws -> SessionHistoryItem {
        let response: SessionDetailEnvelope = try await apiClient.get("/api/v1/sessions/\(id)")
        return response.session.sessionHistoryItem(includeExchanges: true)
    }

    func deleteSession(id: String) async throws {
        let _: DeleteEnvelope = try await apiClient.delete("/api/v1/sessions/\(id)")
    }
}

private struct SessionListEnvelope: Decodable {
    let data: [RemoteSessionRecord]
}

private struct SessionDetailEnvelope: Decodable {
    let session: RemoteSessionRecord
}

private struct DeleteEnvelope: Decodable {
    let success: Bool
}

private struct RemoteSessionRecord: Decodable {
    let id: String
    let clientId: String
    let sessionMode: String?
    let startedAt: Date
    let endedAt: Date?
    let interviewType: String
    let responseFormat: String
    let modelUsed: String
    let totalTokensUsed: Int
    let estimatedCost: Double
    let telemetrySummary: SessionTelemetrySummary?
    let jobDescription: String?
    let overallScore: Int?
    let exchanges: [RemoteExchangeRecord]?
    let count: RemoteExchangeCount?

    enum CodingKeys: String, CodingKey {
        case id
        case clientId
        case sessionMode
        case startedAt
        case endedAt
        case interviewType
        case responseFormat
        case modelUsed
        case totalTokensUsed
        case estimatedCost
        case telemetrySummary
        case jobDescription
        case overallScore
        case exchanges
        case count = "_count"
    }

    func sessionHistoryItem(includeExchanges: Bool) -> SessionHistoryItem {
        let resolvedExchanges = includeExchanges ? exchanges?.map(\.exchange) : nil
        return SessionHistoryItem(
            id: clientId,
            serverId: id,
            clientId: UUID(uuidString: clientId),
            source: .remote,
            sessionMode: sessionMode.flatMap(Self.mapSessionMode),
            startedAt: startedAt,
            endedAt: endedAt,
            interviewType: interviewType,
            responseFormat: responseFormat,
            modelUsed: modelUsed,
            totalTokensUsed: totalTokensUsed,
            estimatedCost: estimatedCost,
            exchangeCount: resolvedExchanges?.count ?? count?.exchanges ?? 0,
            exchanges: resolvedExchanges,
            telemetrySummary: telemetrySummary ?? SessionTelemetrySummary.build(from: resolvedExchanges ?? []),
            jobDescription: jobDescription,
            overallScore: overallScore
        )
    }

    nonisolated private static func mapSessionMode(_ rawValue: String) -> SessionMode? {
        switch rawValue {
        case "LIVE_INTERVIEW":
            return .liveInterview
        default:
            return nil
        }
    }
}

private struct RemoteExchangeCount: Decodable {
    let exchanges: Int
}

private struct RemoteExchangeRecord: Decodable {
    let clientId: String
    let timestamp: Date
    let questionTranscript: String
    let questionType: String
    let generatedResponse: String
    let responseLatencyMs: Int
    let wasPreComputed: Bool
    let telemetry: ExchangeTelemetry?

    var exchange: Exchange {
        Exchange(
            id: UUID(uuidString: clientId) ?? UUID(),
            timestamp: timestamp,
            questionTranscript: questionTranscript,
            questionType: questionType,
            generatedResponse: generatedResponse,
            responseLatencyMs: responseLatencyMs,
            wasPreComputed: wasPreComputed,
            telemetry: telemetry
        )
    }
}
