import Foundation
import SwiftData

@Observable
final class SessionHistoryViewModel {
    private let storage = SessionStorageService.shared
    private let remoteService = RemoteSessionsService.shared
    private var isConfigured = false

    var sessions: [SessionHistoryItem] = []
    var isLoading = false
    var errorMessage: String?

    func configure(with context: ModelContext) {
        guard !isConfigured else { return }
        storage.configure(with: context)
        isConfigured = true
    }

    func loadSessions() async {
        isLoading = true
        defer { isLoading = false }

        let localSessions = storage.fetchSessions().map { session in
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
                telemetrySummary: SessionTelemetrySummary.build(from: session.exchanges)
            )
        }

        do {
            let remoteSessions = try await remoteService.fetchSessions()
            sessions = merge(local: localSessions, remote: remoteSessions)
            errorMessage = nil
        } catch {
            sessions = localSessions.sorted { $0.startedAt > $1.startedAt }
            errorMessage = localSessions.isEmpty ? error.localizedDescription : nil
        }
    }

    func deleteSession(_ item: SessionHistoryItem) async {
        do {
            if let serverId = item.serverId {
                try await remoteService.deleteSession(id: serverId)
            }

            if let clientId = item.clientId, let localSession = storage.fetchSession(id: clientId) {
                storage.deleteSession(localSession)
            }

            await loadSessions()
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func formatLatency(_ latencyMs: Int) -> String {
        if latencyMs < 1000 {
            return "\(latencyMs)ms"
        }

        return String(format: "%.1fs", Double(latencyMs) / 1000)
    }

    private func merge(local: [SessionHistoryItem], remote: [SessionHistoryItem]) -> [SessionHistoryItem] {
        var sessionsByClientId: [UUID: SessionHistoryItem] = [:]
        var merged = remote

        for session in remote {
            if let clientId = session.clientId {
                sessionsByClientId[clientId] = session
            }
        }

        for session in local {
            if let clientId = session.clientId, sessionsByClientId[clientId] != nil {
                continue
            }

            merged.append(session)
        }

        return merged.sorted { $0.startedAt > $1.startedAt }
    }
}
