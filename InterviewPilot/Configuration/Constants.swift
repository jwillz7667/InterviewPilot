import Foundation

enum APIConfig {
    // Models — all modes use the best available models
    static let defaultResponseModel = "gpt-4.1-mini"
    static let technicalResponseModel = "gpt-4.1"
    static let codingResponseModel = "o4-mini"
    static let premiumResponseModel = "gpt-4.1"
    static let premiumTechnicalResponseModel = "gpt-4.1"
    static let premiumCodingResponseModel = "o4-mini"
    static let prepModel = "gpt-4.1"

    // Deepgram
    static let deepgramModel = "nova-3"
    static let deepgramSampleRate = 16000
    static let deepgramEncoding = "linear16"

    // Thresholds
    static let predictiveFireMinWords = 10
    static let predictiveFireConfidence: Float = 0.75
    static let cacheMatchThreshold: Float = 0.82
    static let utteranceEndMs = 2200
    static let endpointingMs = 700
    static let postResponseEchoSimilarityThreshold: Float = 0.18
    static let postResponseMinimumQuestionScore = 4
    static let postResponseGracePeriodSeconds: TimeInterval = 8
    static let predictiveQuestionSimilarityThreshold: Float = 0.55

    // Limits
    static let maxResponseTokens = 320
    static let maxPremiumResponseTokens = 380
    static let maxPreComputedQuestions = 25
    static let responseFrequencyPenalty = 0.15
    static let responsePresencePenalty = 0.05
    static let answerBankTemperature = 0.65
}
