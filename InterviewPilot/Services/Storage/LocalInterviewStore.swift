import Foundation
import Observation

nonisolated enum LocalInterviewStoreError: LocalizedError {
    case unreadableStore, tooManyProfiles, tooManySessions, fileTooLarge, missingBackup
    var errorDescription: String? {
        switch self {
        case .unreadableStore: "The saved data could not be opened. Restore a backup or start a new local store before saving. The original file has been kept."
        case .tooManyProfiles: "The local limit is 50 profiles. Delete a profile before creating another."
        case .tooManySessions: "The local limit is 100 sessions. Export and delete an older session before saving another."
        case .fileTooLarge: "The local data file would exceed 32 MB. Export and delete older sessions, then retry saving."
        case .missingBackup: "No readable backup is available."
        }
    }
}

@MainActor @Observable
final class LocalInterviewStore {
    private(set) var profiles: [CandidateProfile] = []
    private(set) var sessions: [SavedInterview] = []
    private(set) var draft = InterviewConfiguration()
    private(set) var errorMessage: String?
    private(set) var requiresRecovery = false
    private(set) var hasBackup = false
    private(set) var isSaving = false

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private var pendingWrite: Task<Void, Error>?
    @ObservationIgnored private var writeRevision = 0

    nonisolated struct Snapshot: Codable, Sendable {
        var version = 1
        var profiles: [CandidateProfile]
        var sessions: [SavedInterview]
        var draft: InterviewConfiguration
    }

    init(fileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true)
        self.fileURL = fileURL ?? base.appendingPathComponent("InterviewPilot", isDirectory: true).appendingPathComponent("personal-workspace.json")
        hasBackup = FileManager.default.fileExists(atPath: self.fileURL.appendingPathExtension("backup").path)
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        do {
            let snapshot = try Self.read(self.fileURL)
            profiles = snapshot.profiles
            sessions = snapshot.sessions.sorted { $0.startedAt > $1.startedAt }
            draft = snapshot.draft
        } catch {
            requiresRecovery = true
            errorMessage = LocalInterviewStoreError.unreadableStore.localizedDescription
        }
    }

    func saveProfile(_ profile: CandidateProfile) async throws {
        try assertWritable()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            guard profiles.count < 50 else { throw LocalInterviewStoreError.tooManyProfiles }
            profiles.append(profile)
        }
        try await persist()
    }

    func deleteProfile(_ id: UUID) async throws {
        try assertWritable()
        profiles.removeAll { $0.id == id }
        if draft.profileID == id { draft.profileID = nil }
        try await persist()
    }

    func saveDraft(_ configuration: InterviewConfiguration) async throws {
        try assertWritable()
        draft = configuration
        try await persist()
    }

    func saveSession(_ session: SavedInterview) async throws {
        try assertWritable()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            guard sessions.count < 100 else { throw LocalInterviewStoreError.tooManySessions }
            sessions.insert(session, at: 0)
        }
        sessions.sort { $0.startedAt > $1.startedAt }
        try await persist()
    }

    func deleteSession(_ id: UUID) async throws {
        try assertWritable()
        sessions.removeAll { $0.id == id }
        try await persist()
    }

    func retrySave() async throws {
        try assertWritable()
        try await persist()
    }

    /// The old file is preserved before recovery; unreadable data is never overwritten.
    func restoreBackup() async throws {
        let backupURL = fileURL.appendingPathExtension("backup")
        let snapshot: Snapshot
        do { snapshot = try Self.read(backupURL) }
        catch { throw LocalInterviewStoreError.missingBackup }
        try await preserveDamagedStore()
        profiles = snapshot.profiles
        sessions = snapshot.sessions
        draft = snapshot.draft
        requiresRecovery = false
        try await persist()
    }

    func startFreshKeepingOriginal() async throws {
        try await preserveDamagedStore()
        profiles = []
        sessions = []
        draft = InterviewConfiguration()
        requiresRecovery = false
        try await persist()
    }

    private func preserveDamagedStore() async throws {
        guard requiresRecovery else { return }
        let url = fileURL
        try await Task.detached(priority: .utility) {
            let manager = FileManager.default
            if manager.fileExists(atPath: url.path) {
                let preserved = url.deletingPathExtension().appendingPathExtension("unreadable-\(UUID().uuidString).json")
                try manager.moveItem(at: url, to: preserved)
            }
        }.value
    }

    private func assertWritable() throws {
        if requiresRecovery { throw LocalInterviewStoreError.unreadableStore }
    }

    private func persist() async throws {
        let snapshot = Snapshot(profiles: profiles, sessions: sessions, draft: draft)
        let url = fileURL
        let previous = pendingWrite
        writeRevision += 1
        let revision = writeRevision
        isSaving = true
        let task = Task.detached(priority: .utility) {
            // Keep writes in user-action order, including after a failed earlier write.
            _ = try? await previous?.value
            let data = try JSONEncoder().encode(snapshot)
            guard data.count <= 32 * 1024 * 1024 else { throw LocalInterviewStoreError.fileTooLarge }
            let manager = FileManager.default
            try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if manager.fileExists(atPath: url.path) {
                // Only replace the backup with a file that can still be decoded.
                if (try? Self.read(url)) != nil {
                    let prior = try Data(contentsOf: url)
                    try prior.write(to: url.appendingPathExtension("backup"), options: .atomic)
                }
            }
            try data.write(to: url, options: .atomic)
            #if os(iOS)
            try? manager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
            #endif
        }
        pendingWrite = task
        do {
            try await task.value
            if revision == writeRevision {
                errorMessage = nil
                isSaving = false
                hasBackup = FileManager.default.fileExists(atPath: url.appendingPathExtension("backup").path)
            }
        } catch {
            if revision == writeRevision {
                isSaving = false
                errorMessage = "Changes are still in memory and could not be saved. Retry before closing the app. \(error.localizedDescription)"
            }
            throw error
        }
    }

    nonisolated private static func read(_ url: URL) throws -> Snapshot {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber, size.intValue > 32 * 1024 * 1024 {
            throw LocalInterviewStoreError.fileTooLarge
        }
        let result = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        guard result.version == 1 else { throw LocalInterviewStoreError.unreadableStore }
        return result
    }
}
