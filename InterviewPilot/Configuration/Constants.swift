import Foundation

enum APIConfig {
    // Model identifiers below are DISPLAY-ONLY metadata. They are never sent
    // to OpenAI from the client — the chat-stream proxy strips any client
    // `model` field with a 422 and looks up the actual model in
    // `MODEL_BY_QUALITY[quality][routing]` server-side. Keep these strings in
    // sync with backend/billing.constants.ts so any in-app surfaces showing
    // "powered by GPT-4.1" stay accurate.
    static let defaultResponseModel = "gpt-4.1-mini"
    static let technicalResponseModel = "gpt-4.1"
    static let codingResponseModel = "o4-mini"
    static let premiumResponseModel = "gpt-4.1"
    static let premiumTechnicalResponseModel = "gpt-4.1"
    static let premiumCodingResponseModel = "o4-mini"

    // Deepgram
    static let deepgramModel = "nova-3"
    static let deepgramSampleRate = 16000
    static let deepgramEncoding = "linear16"

    // Thresholds — tuned for sub-500ms perceived latency
    static let predictiveFireMinWords = 5
    static let predictiveFireConfidence: Float = 0.45
    static let cacheMatchThreshold: Float = 0.70
    // Deepgram rejects utterance_end_ms < 1000 with HTTP 400 on the WSS
    // upgrade. 1000 is the documented minimum; raising any further trades
    // recall for latency in turn-end detection.
    static let utteranceEndMs = 1000
    static let endpointingMs = 350
    static let postResponseEchoSimilarityThreshold: Float = 0.18
    static let postResponseMinimumQuestionScore = 4
    static let postResponseGracePeriodSeconds: TimeInterval = 8
    static let predictiveQuestionSimilarityThreshold: Float = 0.45

    // OpenAI Realtime
    static let realtimeModel = "gpt-4o-realtime-preview"
    static let realtimeSampleRate = 24000
    static let realtimeVoice = "alloy"
    static let realtimeVadThreshold: Float = 0.5
    static let realtimeVadSilenceDurationMs = 800
    static let realtimeVadPrefixPaddingMs = 300

    // Limits
    static let freeResponseTokens = 320
    static let maxResponseTokens = 400
    static let maxPremiumResponseTokens = 480
    static let responseFrequencyPenalty = 0.15
    static let responsePresencePenalty = 0.05
}
