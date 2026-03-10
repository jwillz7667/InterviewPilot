import Foundation

enum QuestionType: String, Codable {
    case behavioral, technical, systemDesign, coding
    case situational, background, curveball, followUp, unknown

    var displayName: String {
        switch self {
        case .behavioral:   return "Behavioral"
        case .technical:    return "Technical"
        case .systemDesign: return "System Design"
        case .coding:       return "Coding"
        case .situational:  return "Situational"
        case .background:   return "Background"
        case .curveball:    return "Curveball"
        case .followUp:     return "Follow-Up"
        case .unknown:      return "General"
        }
    }
}

struct QuestionClassification: Equatable {
    let type: QuestionType
    let confidence: Float

    static func == (lhs: QuestionClassification, rhs: QuestionClassification) -> Bool {
        lhs.type == rhs.type && lhs.confidence == rhs.confidence
    }
}
