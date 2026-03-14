import Foundation
import SwiftData

@Observable
final class SessionStorageService {
    static let shared = SessionStorageService()

    private var modelContext: ModelContext?

    private init() {}

    func configure(with context: ModelContext) {
        self.modelContext = context
    }

    func saveSession(_ session: InterviewSession) {
        modelContext?.insert(session)
        saveChanges()
    }

    func saveChanges() {
        try? modelContext?.save()
    }

    func fetchSessions() -> [InterviewSession] {
        let descriptor = FetchDescriptor<InterviewSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? modelContext?.fetch(descriptor)) ?? []
    }

    func fetchSession(id: UUID) -> InterviewSession? {
        guard let modelContext else { return nil }

        let descriptor = FetchDescriptor<InterviewSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    func deleteSession(_ session: InterviewSession) {
        modelContext?.delete(session)
        saveChanges()
    }
}
