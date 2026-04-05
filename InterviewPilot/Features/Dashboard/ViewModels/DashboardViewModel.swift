import Foundation
import SwiftData

@Observable
final class DashboardViewModel {
    var recentSessions: [SessionHistoryItem] = []
    var savedDrafts: [DraftSession] = []
    var userName: String = ""
    var isLoading = false

    @ObservationIgnored private let authService = AuthService.shared
    @ObservationIgnored private let profileService = ProfileService.shared

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    var displayGreeting: String {
        let name = authService.currentUser?.displayName ?? profileService.profile?.displayName ?? ""
        if name.isEmpty {
            return "\(greeting)!"
        }
        return "\(greeting), \(name)"
    }

    func loadData(modelContext: ModelContext) {
        isLoading = true
        defer { isLoading = false }

        savedDrafts = DraftSession.loadAll()

        let descriptor = FetchDescriptor<InterviewSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        if let sessions = try? modelContext.fetch(descriptor) {
            recentSessions = Array(sessions.prefix(5)).map { session in
                SessionHistoryItem(
                    id: session.id.uuidString,
                    serverId: nil,
                    clientId: session.id,
                    source: .local,
                    sessionMode: nil,
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    interviewType: session.interviewType,
                    responseFormat: session.responseFormat,
                    modelUsed: session.modelUsed,
                    totalTokensUsed: session.totalTokensUsed,
                    estimatedCost: session.estimatedCost,
                    exchangeCount: session.exchanges.count,
                    exchanges: session.exchanges,
                    telemetrySummary: nil,
                    jobDescription: session.jobDescription,
                    overallScore: nil,
                    jobListingUrl: session.jobListingUrl,
                    profileId: session.profileId
                )
            }
        }
    }

    /// Resume text from user profile for quick-launch practice.
    var latestResumeText: String {
        profileService.profile?.resumeText ?? ""
    }

    /// Job description from the most recent session for quick-launch practice.
    var latestJobDescription: String {
        recentSessions.first?.jobDescription ?? ""
    }

    func deleteDraft(_ draft: DraftSession) {
        DraftSession.delete(id: draft.id)
        savedDrafts.removeAll { $0.id == draft.id }
    }
}
