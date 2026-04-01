import Foundation

@Observable
final class SyncRetryQueue {
    static let shared = SyncRetryQueue()

    private(set) var pendingCount = 0

    private let storageKey = "com.res.jobhopperAI.pending-syncs"

    private init() {
        pendingCount = loadPendingSnapshots().count
    }

    func enqueue(_ snapshot: SessionSyncSnapshot) {
        var pending = loadPendingSnapshots()
        pending.append(snapshot)
        savePendingSnapshots(pending)
        pendingCount = pending.count
    }

    func retryAll(using syncService: RemoteSessionSyncService) async {
        let pending = loadPendingSnapshots()
        guard !pending.isEmpty else { return }

        var remaining: [SessionSyncSnapshot] = []

        for snapshot in pending {
            do {
                try await syncService.syncSession(snapshot)
            } catch {
                remaining.append(snapshot)
            }
        }

        savePendingSnapshots(remaining)
        pendingCount = remaining.count
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        pendingCount = 0
    }

    private func loadPendingSnapshots() -> [SessionSyncSnapshot] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([SessionSyncSnapshot].self, from: data)) ?? []
    }

    private func savePendingSnapshots(_ snapshots: [SessionSyncSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
