import Foundation

struct DeepgramResponse: Codable {
    let type: String
    let channel: DeepgramChannel?
    let isFinal: Bool?
    let speechFinal: Bool?

    enum CodingKeys: String, CodingKey {
        case type, channel
        case isFinal = "is_final"
        case speechFinal = "speech_final"
    }
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Codable {
    let transcript: String
    let confidence: Double
    let words: [DeepgramWord]?
}

struct DeepgramWord: Codable {
    let word: String
    let start: Double
    let end: Double
    let confidence: Double
}
