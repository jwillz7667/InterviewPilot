import Foundation

enum UserGoal: String, CaseIterable, Codable, Sendable, Identifiable {
    case getNewJob = "get_new_job"
    case practiceCoding = "practice_coding"
    case improveCommunication = "improve_communication"
    case domainKnowledge = "domain_knowledge"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .getNewJob:
            return "Get a New Job"
        case .practiceCoding:
            return "Practice Coding"
        case .improveCommunication:
            return "Improve Communication"
        case .domainKnowledge:
            return "Domain Knowledge"
        }
    }

    var subtitle: String {
        switch self {
        case .getNewJob:
            return "Prepare for upcoming interviews and land offers"
        case .practiceCoding:
            return "Sharpen technical and coding interview skills"
        case .improveCommunication:
            return "Build confidence in behavioral responses"
        case .domainKnowledge:
            return "Deepen expertise in your field"
        }
    }

    var symbol: String {
        switch self {
        case .getNewJob:
            return "briefcase.fill"
        case .practiceCoding:
            return "chevron.left.forwardslash.chevron.right"
        case .improveCommunication:
            return "bubble.left.and.bubble.right.fill"
        case .domainKnowledge:
            return "books.vertical.fill"
        }
    }
}
