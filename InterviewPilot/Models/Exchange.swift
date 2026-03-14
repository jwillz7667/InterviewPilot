import Foundation

struct Exchange: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    var questionTranscript: String
    var questionType: String
    var generatedResponse: String
    var responseLatencyMs: Int
    var wasPreComputed: Bool
    var telemetry: ExchangeTelemetry?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        questionTranscript: String,
        questionType: String,
        generatedResponse: String,
        responseLatencyMs: Int,
        wasPreComputed: Bool,
        telemetry: ExchangeTelemetry? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.questionTranscript = questionTranscript
        self.questionType = questionType
        self.generatedResponse = generatedResponse
        self.responseLatencyMs = responseLatencyMs
        self.wasPreComputed = wasPreComputed
        self.telemetry = telemetry
    }

    init(
        question: String,
        response: String,
        type: QuestionType,
        latencyMs: Int,
        cached: Bool,
        telemetry: ExchangeTelemetry? = nil
    ) {
        self.init(
            questionTranscript: question,
            questionType: type.rawValue,
            generatedResponse: response,
            responseLatencyMs: latencyMs,
            wasPreComputed: cached,
            telemetry: telemetry
        )
    }
}
