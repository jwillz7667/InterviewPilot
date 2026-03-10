import Foundation

struct Exchange: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    var questionTranscript: String
    var questionType: String
    var generatedResponse: String
    var responseLatencyMs: Int
    var wasPreComputed: Bool

    init(question: String, response: String, type: QuestionType, latencyMs: Int, cached: Bool) {
        self.id = UUID()
        self.timestamp = Date()
        self.questionTranscript = question
        self.questionType = type.rawValue
        self.generatedResponse = response
        self.responseLatencyMs = latencyMs
        self.wasPreComputed = cached
    }
}
