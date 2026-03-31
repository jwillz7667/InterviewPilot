import Foundation
import SwiftData

@Observable
final class InsightsViewModel {
    var insights: SessionInsights = SessionInsights()
    var sessionCount: Int = 0
    var latestSessionDate: Date?
    var isLoading = false

    var hasData: Bool {
        insights.overallScore != nil
    }

    var overallScoreLabel: String {
        guard let score = insights.overallScore else { return "--" }
        return "\(score)"
    }

    var performanceLabel: String {
        guard let score = insights.overallScore else { return "No data yet" }
        if score >= 85 { return "Excellent Session!" }
        if score >= 70 { return "Great Session!" }
        if score >= 50 { return "Good Progress" }
        return "Keep Practicing"
    }

    func loadData(modelContext: ModelContext) {
        isLoading = true
        defer { isLoading = false }

        let descriptor = FetchDescriptor<InterviewSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        guard let sessions = try? modelContext.fetch(descriptor) else { return }
        sessionCount = sessions.count

        if let latest = sessions.first {
            latestSessionDate = latest.startedAt

            let exchanges = latest.exchanges
            let count = exchanges.count
            guard count > 0 else { return }

            let avgResponseLength = exchanges.map { $0.generatedResponse.count }.reduce(0, +) / count
            let technicalScore = min(Double(avgResponseLength) / 600.0, 1.0) * 100
            let communicationScore = min(Double(count) * 12.0, 100.0)
            let confidenceScore = min(Double(avgResponseLength) / 500.0, 1.0) * 100

            insights = SessionInsights(
                technicalAccuracyScore: technicalScore,
                communicationScore: communicationScore,
                confidenceScore: confidenceScore,
                aiStrengths: computeStrengths(exchanges: exchanges),
                aiImprovements: computeImprovements(exchanges: exchanges),
                overallScore: Int((technicalScore + communicationScore + confidenceScore) / 3.0)
            )
        }
    }

    private func computeStrengths(exchanges: [Exchange]) -> [String] {
        var strengths: [String] = []
        if exchanges.count >= 5 {
            strengths.append("Sustained engagement across \(exchanges.count) questions")
        }
        let avgLength = exchanges.map { $0.generatedResponse.count }.reduce(0, +) / max(exchanges.count, 1)
        if avgLength > 300 {
            strengths.append("Detailed, comprehensive responses")
        }
        if exchanges.contains(where: { $0.questionType.lowercased().contains("technical") }) {
            strengths.append("Strong technical question handling")
        }
        if strengths.isEmpty {
            strengths.append("Completed a full interview session")
        }
        return strengths
    }

    private func computeImprovements(exchanges: [Exchange]) -> [String] {
        var improvements: [String] = []
        let avgLength = exchanges.map { $0.generatedResponse.count }.reduce(0, +) / max(exchanges.count, 1)
        if avgLength < 200 {
            improvements.append("Provide more detailed responses with specific examples")
        }
        if exchanges.count < 3 {
            improvements.append("Practice answering more questions per session")
        }
        let avgLatency = exchanges.map { $0.responseLatencyMs }.reduce(0, +) / max(exchanges.count, 1)
        if avgLatency > 5000 {
            improvements.append("Work on reducing response preparation time")
        }
        if improvements.isEmpty {
            improvements.append("Continue practicing to maintain consistency")
        }
        return improvements
    }
}
