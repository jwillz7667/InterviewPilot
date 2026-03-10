import Foundation

enum APIConfig {
    // Models
    static let defaultResponseModel = "gpt-4.1-nano"
    static let technicalResponseModel = "gpt-4.1-mini"
    static let codingResponseModel = "o4-mini"
    static let prepModel = "gpt-4.1"

    // Deepgram
    static let deepgramModel = "nova-3"
    static let deepgramSampleRate = 16000
    static let deepgramEncoding = "linear16"

    // Thresholds
    static let predictiveFireMinWords = 8
    static let predictiveFireConfidence: Float = 0.75
    static let cacheMatchThreshold: Float = 0.82
    static let utteranceEndMs = 1500
    static let endpointingMs = 500

    // Limits
    static let maxResponseTokens = 800
    static let maxPreComputedQuestions = 25
    static let responseTemperature = 0.7
}
