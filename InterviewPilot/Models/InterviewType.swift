import Foundation

enum InterviewType: String, Codable, CaseIterable {
    case behavioral, technical, systemDesign, caseStudy, hrScreen, general

    var displayName: String {
        switch self {
        case .behavioral:   return "Behavioral"
        case .technical:    return "Technical"
        case .systemDesign: return "System Design"
        case .caseStudy:    return "Case Study"
        case .hrScreen:     return "HR Screen"
        case .general:      return "General"
        }
    }
}
