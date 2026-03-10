import Foundation

enum ResponseFormat: String, Codable, CaseIterable {
    case fullAnswer, bulletPoints, hybrid

    var displayName: String {
        switch self {
        case .fullAnswer:    return "Full Answers"
        case .bulletPoints:  return "Bullet Points"
        case .hybrid:        return "Hybrid"
        }
    }

    var description: String {
        switch self {
        case .fullAnswer:    return "Complete spoken response, word for word"
        case .bulletPoints:  return "Key talking points to reference"
        case .hybrid:        return "Opening + bullet points + closing"
        }
    }
}
