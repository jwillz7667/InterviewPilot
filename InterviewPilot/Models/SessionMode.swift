import Foundation

enum SessionMode: String, CaseIterable, Identifiable {
    case liveInterview
    case voicePrep

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liveInterview:
            return "Live Interview"
        case .voicePrep:
            return "Practice Interview"
        }
    }
}
