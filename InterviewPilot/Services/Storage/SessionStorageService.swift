import Foundation
import SwiftData

@Observable
final class SessionStorageService {
    private var modelContext: ModelContext?

    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    func saveSession(_ session: InterviewSession) {
        modelContext?.insert(session)
        try? modelContext?.save()
    }

    func fetchSessions() -> [InterviewSession] {
        let descriptor = FetchDescriptor<InterviewSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    func deleteSession(_ session: InterviewSession) {
        modelContext?.delete(session)
        try? modelContext?.save()
    }
}
