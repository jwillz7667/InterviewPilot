import Foundation

@Observable
final class SyncRetryQueue {
    static let shared = SyncRetryQueue()

    private(set) var pendingCount = 0

    // Bound the backlog so a persistently-failing sync can't grow on-disk state
    // without limit. Oldest entries are dropped first.
    private static let maxPending = 50

    // Legacy location: UserDefaults stored resume/job-description PII unencrypted
    // in an unprotected plist that lands in device backups. We migrate to a
    // file-protected JSON file (readable only after first unlock) and excluded
    // from backup.
    private let legacyDefaultsKey = "com.res.jobhopperAI.pending-syncs"
    private let fileURL: URL

    private init() {
        let fileManager = FileManager.default
        let baseDirectory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.temporaryDirectory
        let directory = baseDirectory.appendingPathComponent("InterviewPilot", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("PendingSyncs.json", isDirectory: false)

        migrateFromUserDefaultsIfNeeded()
        pendingCount = loadPendingSnapshots().count
    }

    func enqueue(_ snapshot: SessionSyncSnapshot) {
        var pending = loadPendingSnapshots()
        // Dedupe by clientId so re-enqueuing the same session (e.g. repeated
        // failed retries) collapses to a single, latest entry.
        pending.removeAll { $0.clientId == snapshot.clientId }
        pending.append(snapshot)
        if pending.count > Self.maxPending {
            pending.removeFirst(pending.count - Self.maxPending)
        }
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
        try? FileManager.default.removeItem(at: fileURL)
        pendingCount = 0
    }

    private func loadPendingSnapshots() -> [SessionSyncSnapshot] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([SessionSyncSnapshot].self, from: data)) ?? []
    }

    private func savePendingSnapshots(_ snapshots: [SessionSyncSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        do {
            try data.write(
                to: fileURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
            excludeFromBackup()
        } catch {
            // Best-effort persistence; the in-memory count remains authoritative
            // for this session even if the write fails.
        }
    }

    private func excludeFromBackup() {
        var url = fileURL
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    private func migrateFromUserDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: legacyDefaultsKey) else { return }
        defaults.removeObject(forKey: legacyDefaultsKey)

        guard
            let snapshots = try? JSONDecoder().decode([SessionSyncSnapshot].self, from: data),
            !snapshots.isEmpty
        else { return }

        // Don't clobber an existing protected file if one is already present.
        if (try? Data(contentsOf: fileURL)) == nil {
            savePendingSnapshots(Array(snapshots.suffix(Self.maxPending)))
        }
    }
}
