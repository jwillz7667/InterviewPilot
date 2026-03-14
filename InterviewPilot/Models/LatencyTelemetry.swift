import Foundation

struct ExchangeTelemetry: Codable, Hashable, Sendable {
    let questionDurationMs: Int?
    let speechEndToFireMs: Int?
    let timeToFirstTokenMs: Int?
    let generationDurationMs: Int?
    let questionEndToCompletionMs: Int?
    let cacheLookupMs: Int?
    let classificationMs: Int?
    let streamChunkCount: Int
    let usedPredictiveFire: Bool
}

struct SessionTelemetrySummary: Codable, Hashable, Sendable {
    let exchangeCount: Int
    let cachedExchangeCount: Int
    let predictiveFireCount: Int
    let averageTotalLatencyMs: Int
    let averageTimeToFirstTokenMs: Int?
    let averageGenerationDurationMs: Int?
    let averageLiveTimeToFirstTokenMs: Int?
    let averageLiveGenerationDurationMs: Int?
    let p95LiveTimeToFirstTokenMs: Int?
    let p95LiveGenerationDurationMs: Int?
    let averageQuestionDurationMs: Int?
    let averageSpeechEndToFireMs: Int?

    var cacheHitRate: Double {
        guard exchangeCount > 0 else { return 0 }
        return Double(cachedExchangeCount) / Double(exchangeCount) * 100
    }

    var predictiveFireRate: Double {
        guard exchangeCount > 0 else { return 0 }
        return Double(predictiveFireCount) / Double(exchangeCount) * 100
    }

    static func build(from exchanges: [Exchange]) -> SessionTelemetrySummary? {
        guard !exchanges.isEmpty else { return nil }

        let telemetry = exchanges.compactMap(\.telemetry)
        let uncachedTelemetry = exchanges.compactMap { exchange in
            exchange.wasPreComputed ? nil : exchange.telemetry
        }

        return SessionTelemetrySummary(
            exchangeCount: exchanges.count,
            cachedExchangeCount: exchanges.filter(\.wasPreComputed).count,
            predictiveFireCount: telemetry.filter(\.usedPredictiveFire).count,
            averageTotalLatencyMs: exchanges.map(\.responseLatencyMs).average ?? 0,
            averageTimeToFirstTokenMs: telemetry.compactMap(\.timeToFirstTokenMs).average,
            averageGenerationDurationMs: telemetry.compactMap(\.generationDurationMs).average,
            averageLiveTimeToFirstTokenMs: uncachedTelemetry.compactMap(\.timeToFirstTokenMs).average,
            averageLiveGenerationDurationMs: uncachedTelemetry.compactMap(\.generationDurationMs).average,
            p95LiveTimeToFirstTokenMs: uncachedTelemetry.compactMap(\.timeToFirstTokenMs).percentile(0.95),
            p95LiveGenerationDurationMs: uncachedTelemetry.compactMap(\.generationDurationMs).percentile(0.95),
            averageQuestionDurationMs: telemetry.compactMap(\.questionDurationMs).average,
            averageSpeechEndToFireMs: telemetry.compactMap(\.speechEndToFireMs).average
        )
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
