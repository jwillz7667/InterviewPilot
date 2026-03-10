import Foundation

@Observable
final class SessionReviewViewModel {
    let exchanges: [Exchange]
    let transcript: [TranscriptSegment]
    let duration: TimeInterval
    let interviewType: InterviewType

    var selectedExchange: Exchange?

    init(exchanges: [Exchange], transcript: [TranscriptSegment], duration: TimeInterval, interviewType: InterviewType) {
        self.exchanges = exchanges
        self.transcript = transcript
        self.duration = duration
        self.interviewType = interviewType
    }

    var averageLatency: Int {
        guard !exchanges.isEmpty else { return 0 }
        return exchanges.map(\.responseLatencyMs).reduce(0, +) / exchanges.count
    }

    var cacheHitRate: Double {
        guard !exchanges.isEmpty else { return 0 }
        let cached = exchanges.filter(\.wasPreComputed).count
        return Double(cached) / Double(exchanges.count) * 100
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
}
