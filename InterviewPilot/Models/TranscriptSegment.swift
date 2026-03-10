import Foundation

struct TranscriptSegment: Identifiable, Codable {
    let id: UUID
    let speaker: Speaker
    let text: String
    let timestamp: Date

    enum Speaker: String, Codable {
        case interviewer
        case aiResponse
        case user
    }

    init(speaker: Speaker, text: String, timestamp: Date) {
        self.id = UUID()
        self.speaker = speaker
        self.text = text
        self.timestamp = timestamp
    }
}
