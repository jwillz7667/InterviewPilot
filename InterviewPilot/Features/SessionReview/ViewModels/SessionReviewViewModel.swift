import Foundation

struct AIAnalysis: Codable, Sendable {
    let technicalAccuracyScore: Double
    let communicationScore: Double
    let confidenceScore: Double
    let overallScore: Int
    let aiStrengths: [String]
    let aiImprovements: [String]
    let exchangeFeedback: [ExchangeFeedbackItem]
}

struct ExchangeFeedbackItem: Codable, Sendable {
    let sequenceOrder: Int
    let score: Int
    let verdict: String
    let feedback: String

    var verdictColor: String {
        switch verdict {
        case "strong": return "success"
        case "weak": return "error"
        default: return "warning"
        }
    }
}

private struct AnalysisEnvelope: Decodable {
    let analysis: AIAnalysis
}

private struct EmptyBody: Encodable {}

@Observable
final class SessionReviewViewModel {
    let exchanges: [Exchange]
    let transcript: [TranscriptSegment]
    let duration: TimeInterval
    let interviewType: InterviewType
    let telemetrySummary: SessionTelemetrySummary?
    var serverId: String?

    var selectedExchange: Exchange?
    var analysis: AIAnalysis?
    var isAnalyzing = false
    var analysisError: String?

    init(
        exchanges: [Exchange],
        transcript: [TranscriptSegment],
        duration: TimeInterval,
        interviewType: InterviewType,
        telemetrySummary: SessionTelemetrySummary? = nil,
        serverId: String? = nil
    ) {
        self.exchanges = exchanges
        self.transcript = transcript
        self.duration = duration
        self.interviewType = interviewType
        self.telemetrySummary = telemetrySummary ?? SessionTelemetrySummary.build(from: exchanges)
        self.serverId = serverId
    }

    var hasAnalysis: Bool { analysis != nil }

    func feedbackForExchange(at index: Int) -> ExchangeFeedbackItem? {
        analysis?.exchangeFeedback.first { $0.sequenceOrder == index }
    }

    func resolveServerIdFromRemote() async {
        guard serverId == nil else { return }

        do {
            let remoteSessions = try await RemoteSessionsService.shared.fetchSessions(limit: 20)

            // Match by exchange count and approximate timestamp (within 60 seconds)
            let match = remoteSessions.first { remote in
                let exchangeCountMatches = remote.exchangeCount == exchanges.count
                let timeDelta = abs(remote.startedAt.timeIntervalSince(exchanges.first?.timestamp ?? .distantPast))
                let timestampClose = timeDelta < 60

                // Also try matching by duration similarity
                let durationClose = abs(remote.duration - duration) < 30

                return exchangeCountMatches && (timestampClose || durationClose)
            }

            if let resolvedId = match?.serverId {
                serverId = resolvedId
            }
        } catch {
            // Silent failure — fetchAnalysis will handle the nil serverId gracefully
        }
    }

    func fetchAnalysis() async {
        guard let serverId, !isAnalyzing else { return }
        isAnalyzing = true
        analysisError = nil

        do {
            let envelope: AnalysisEnvelope = try await AuthenticatedAPIClient.shared.post(
                "/api/v1/sessions/\(serverId)/analyze",
                body: EmptyBody(),
                expectedStatusCodes: [200]
            )
            analysis = envelope.analysis
        } catch {
            analysisError = error.localizedDescription
        }

        isAnalyzing = false
    }

    var averageLatency: Int {
        telemetrySummary?.averageTotalLatencyMs
            ?? exchanges.map(\.responseLatencyMs).reduce(0, +) / max(exchanges.count, 1)
    }

    var averageFirstTokenLatency: Int? {
        telemetrySummary?.averageLiveTimeToFirstTokenMs
            ?? telemetrySummary?.averageTimeToFirstTokenMs
            ?? liveTelemetry.compactMap(\.timeToFirstTokenMs).average
            ?? telemetry.compactMap(\.timeToFirstTokenMs).average
    }

    var averageLiveCompletionLatency: Int? {
        telemetrySummary?.averageLiveGenerationDurationMs
            ?? telemetrySummary?.averageGenerationDurationMs
            ?? liveTelemetry.compactMap(\.generationDurationMs).average
            ?? telemetry.compactMap(\.generationDurationMs).average
    }

    var p95LiveCompletionLatency: Int? {
        telemetrySummary?.p95LiveGenerationDurationMs
            ?? liveTelemetry.compactMap(\.generationDurationMs).percentile(0.95)
    }

    var cacheHitRate: Double {
        if let telemetrySummary {
            return telemetrySummary.cacheHitRate
        }

        guard !exchanges.isEmpty else { return 0 }
        let cached = exchanges.filter(\.wasPreComputed).count
        return Double(cached) / Double(exchanges.count) * 100
    }

    var predictiveFireRate: Double {
        if let telemetrySummary {
            return telemetrySummary.predictiveFireRate
        }

        guard !exchanges.isEmpty else { return 0 }
        let predictive = exchanges.filter { $0.telemetry?.usedPredictiveFire == true }.count
        return Double(predictive) / Double(exchanges.count) * 100
    }

    var questionTypeBreakdown: [(QuestionType, Int)] {
        var counts: [QuestionType: Int] = [:]
        for exchange in exchanges {
            let type = QuestionType(rawValue: exchange.questionType) ?? .unknown
            counts[type, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var telemetry: [ExchangeTelemetry] {
        exchanges.compactMap(\.telemetry)
    }

    private var liveTelemetry: [ExchangeTelemetry] {
        exchanges.compactMap { exchange in
            exchange.wasPreComputed ? nil : exchange.telemetry
        }
    }
}

private extension Array where Element == Int {
    var average: Int? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / count
    }

    func percentile(_ percentile: Double) -> Int? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let clamped = Swift.min(Swift.max(percentile, 0), 1)
        let index = Int((Double(sorted.count - 1) * clamped).rounded(.up))
        return sorted[index]
    }
}
