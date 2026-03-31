import Foundation

enum SessionMode: String, CaseIterable, Identifiable {
    case liveInterview

    var id: String { rawValue }

    var displayName: String {
        "Live Interview"
    }
}
