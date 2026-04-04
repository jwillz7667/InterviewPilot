import Foundation

struct DraftSession: Codable, Identifiable, Sendable {
    let id: UUID
    let savedAt: Date
    var jobListingURL: String
    var jobListingTitle: String
    var jobDescription: String
    var jobCategory: String
    var positionLevel: String
    var companyName: String?
    var interviewType: String
    var additionalNotes: String
    var resumeDocumentName: String?

    private static let storageKey = "savedDraftSessions"

    static func loadAll() -> [DraftSession] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([DraftSession].self, from: data)) ?? []
    }

    static func saveAll(_ drafts: [DraftSession]) {
        guard let data = try? JSONEncoder().encode(drafts) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func delete(id: UUID) {
        var drafts = loadAll()
        drafts.removeAll { $0.id == id }
        saveAll(drafts)
    }
}
