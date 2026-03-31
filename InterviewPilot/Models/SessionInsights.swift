import Foundation

struct SessionInsights: Codable, Sendable {
    var technicalAccuracyScore: Double?
    var communicationScore: Double?
    var confidenceScore: Double?
    var aiStrengths: [String]
    var aiImprovements: [String]
    var overallScore: Int?

    init(
        technicalAccuracyScore: Double? = nil,
        communicationScore: Double? = nil,
        confidenceScore: Double? = nil,
        aiStrengths: [String] = [],
        aiImprovements: [String] = [],
        overallScore: Int? = nil
    ) {
        self.technicalAccuracyScore = technicalAccuracyScore
        self.communicationScore = communicationScore
        self.confidenceScore = confidenceScore
        self.aiStrengths = aiStrengths
        self.aiImprovements = aiImprovements
        self.overallScore = overallScore
    }
}
