import Foundation
import SwiftData

@Observable
final class SessionHistoryViewModel {
    private let storage = SessionStorageService.shared
    var sessions: [InterviewSession] = []

    func configure(with context: ModelContext) {
        storage.configure(with: context)
        loadSessions()
    }

    func loadSessions() {
        sessions = storage.fetchSessions()
    }

    func deleteSession(_ session: InterviewSession) {
        storage.deleteSession(session)
        loadSessions()
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
