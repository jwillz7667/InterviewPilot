import Foundation

struct SessionHistoryItem: Identifiable {
    enum Source {
        case local
        case remote
    }

    let id: String
    let serverId: String?
    let clientId: UUID?
    let source: Source
    let sessionMode: SessionMode?
    let startedAt: Date
    let endedAt: Date?
    let interviewType: String
    let responseFormat: String
    let modelUsed: String
    let totalTokensUsed: Int
    let estimatedCost: Double
    let exchangeCount: Int
    let exchanges: [Exchange]?
    let telemetrySummary: SessionTelemetrySummary?

    var duration: TimeInterval {
        let endDate = endedAt ?? Date()
        return max(endDate.timeIntervalSince(startedAt), 0)
    }

    var reviewInterviewType: InterviewType {
        InterviewType(rawValue: interviewType) ?? .general
    }

    var effectiveTelemetrySummary: SessionTelemetrySummary? {
        telemetrySummary ?? SessionTelemetrySummary.build(from: exchanges ?? [])
    }
}
