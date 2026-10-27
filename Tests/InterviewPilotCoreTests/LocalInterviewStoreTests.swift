import XCTest
@testable import InterviewPilotCore

@MainActor
final class LocalInterviewStoreTests: XCTestCase {
    private func temporaryStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("InterviewPilotStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("workspace.json")
    }

    func testSessionCheckpointsUpsertWithoutDuplicateHistory() async throws {
        let url = try temporaryStoreURL()
        let store = LocalInterviewStore(fileURL: url)
        var session = SavedInterview(configuration: InterviewConfiguration(), messages: [
            InterviewMessage(role: .user, content: "Tell me about your work.")
        ])
        try await store.saveSession(session)
        session.messages.append(InterviewMessage(role: .assistant, content: "I build scheduling tools."))
        try await store.saveSession(session)
        let reopened = LocalInterviewStore(fileURL: url)
        XCTAssertEqual(reopened.sessions.count, 1)
        XCTAssertEqual(reopened.sessions.first?.messages.count, 2)
        XCTAssertEqual(reopened.sessions.first?.id, session.id)
    }

    func testConcurrentProfileAndSessionWritesPreserveBothChanges() async throws {
        let url = try temporaryStoreURL()
        let store = LocalInterviewStore(fileURL: url)
        let profile = CandidateProfile(name: "Taylor", resume: "Engineering experience")
        let session = SavedInterview(configuration: InterviewConfiguration())
        async let profileSave: Void = store.saveProfile(profile)
        async let sessionSave: Void = store.saveSession(session)
        _ = try await (profileSave, sessionSave)
        let reopened = LocalInterviewStore(fileURL: url)
        XCTAssertEqual(reopened.profiles.map(\.id), [profile.id])
        XCTAssertEqual(reopened.sessions.map(\.id), [session.id])
    }

    func testCorruptStoreBlocksWritesAndRestoresVerifiedBackup() async throws {
        let url = try temporaryStoreURL()
        let store = LocalInterviewStore(fileURL: url)
        let first = CandidateProfile(name: "First")
        try await store.saveProfile(first)
        try await store.saveProfile(CandidateProfile(name: "Second"))
        let unreadable = Data("not valid JSON".utf8)
        try unreadable.write(to: url)
        let reopened = LocalInterviewStore(fileURL: url)
        XCTAssertTrue(reopened.requiresRecovery)
        do {
            try await reopened.saveDraft(InterviewConfiguration())
            XCTFail("Corrupt data must not be silently overwritten.")
        } catch { }
        XCTAssertEqual(try Data(contentsOf: url), unreadable)
        try await reopened.restoreBackup()
        XCTAssertFalse(reopened.requiresRecovery)
        XCTAssertEqual(reopened.profiles.map(\.id), [first.id])
        let names = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        XCTAssertTrue(names.contains { $0.contains("unreadable-") })
        let recovered = LocalInterviewStore(fileURL: url)
        XCTAssertEqual(recovered.profiles.map(\.id), [first.id])
    }

    func testFailedWriteKeepsInMemoryEditsAndRetryPersistsThem() async throws {
        let url = try temporaryStoreURL()
        let blockedDirectory = url.deletingLastPathComponent().appendingPathComponent("blocked")
        try Data("not a directory".utf8).write(to: blockedDirectory)
        let destination = blockedDirectory.appendingPathComponent("workspace.json")
        let store = LocalInterviewStore(fileURL: destination)
        let profile = CandidateProfile(name: "Kept in memory")
        do {
            try await store.saveProfile(profile)
            XCTFail("Writing below a regular file should fail.")
        } catch { }
        XCTAssertEqual(store.profiles.map(\.id), [profile.id])
        XCTAssertNotNil(store.errorMessage)
        try FileManager.default.removeItem(at: blockedDirectory)
        try await store.retrySave()
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(LocalInterviewStore(fileURL: destination).profiles.map(\.id), [profile.id])
    }
}
