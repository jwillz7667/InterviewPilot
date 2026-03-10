import Foundation
import SwiftData

@Model
final class InterviewSession {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var resumeText: String
    var jobDescription: String
    var interviewType: String
    var responseFormat: String
    var modelUsed: String
    var exchangesJSON: Data?
    var totalTokensUsed: Int
    var estimatedCost: Double

    init(resumeText: String, jobDescription: String, interviewType: InterviewType, responseFormat: ResponseFormat) {
        self.id = UUID()
        self.startedAt = Date()
        self.resumeText = resumeText
        self.jobDescription = jobDescription
        self.interviewType = interviewType.rawValue
        self.responseFormat = responseFormat.rawValue
        self.modelUsed = APIConfig.defaultResponseModel
        self.totalTokensUsed = 0
        self.estimatedCost = 0
    }

    var exchanges: [Exchange] {
        guard let data = exchangesJSON else { return [] }
        return (try? JSONDecoder().decode([Exchange].self, from: data)) ?? []
    }

    func setExchanges(_ exchanges: [Exchange]) {
        exchangesJSON = try? JSONEncoder().encode(exchanges)
    }

    var duration: TimeInterval {
        guard let end = endedAt else { return Date().timeIntervalSince(startedAt) }
        return end.timeIntervalSince(startedAt)
    }
}
