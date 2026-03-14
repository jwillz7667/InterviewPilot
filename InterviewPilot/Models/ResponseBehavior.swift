import Foundation

enum ResponseBehavior: String, Codable, CaseIterable {
    case direct, analytical, storyLed, collaborative

    var displayName: String {
        switch self {
        case .direct: return "Direct"
        case .analytical: return "Analytical"
        case .storyLed: return "Story-Led"
        case .collaborative: return "Collaborative"
        }
    }

    var description: String {
        switch self {
        case .direct:
            return "Answer first, then one tight supporting point."
        case .analytical:
            return "Show reasoning, tradeoffs, and decision logic."
        case .storyLed:
            return "Use a concise real example with ownership and result."
        case .collaborative:
            return "Sound thoughtful, calm, and easy to work with."
        }
    }

    var promptInstruction: String {
        switch self {
        case .direct:
            return "Lead with the answer immediately, then add one sharp supporting detail."
        case .analytical:
            return "Explain the reasoning path clearly: decision, tradeoff, and why that choice made sense."
        case .storyLed:
            return "Anchor the answer in one concise real example with context, action, and result."
        case .collaborative:
            return "Sound like a strong teammate: clear, pragmatic, and open to tradeoffs."
        }
    }
}
