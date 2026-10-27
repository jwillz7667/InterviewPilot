import XCTest
@testable import InterviewPilotCore

final class InterviewContextTests: XCTestCase {
    func testPromptIncludesResumeAndResolvedJobText() {
        var configuration = InterviewConfiguration()
        configuration.candidateName = "Taylor"
        configuration.resume = "Built a scheduling system in Swift."
        configuration.projects = "Local scheduling app shipped in 2025."
        configuration.jobURL = "https://example.com/role"
        configuration.jobDescription = "Own the iOS scheduling experience."
        configuration.notes = "Second-round architecture discussion."
        let prompt = configuration.systemPrompt
        XCTAssertTrue(prompt.contains(configuration.resume))
        XCTAssertTrue(prompt.contains(configuration.jobDescription))
        XCTAssertTrue(prompt.contains(configuration.projects))
        XCTAssertTrue(prompt.contains(configuration.notes))
        XCTAssertTrue(prompt.contains("Never invent credentials"))
        XCTAssertTrue(prompt.contains("Missing resume details are unknown"))
        XCTAssertTrue(prompt.contains("positive OR negative qualifications"))
    }

    func testOversizedSourcesCannotDisplaceOtherContextOrExceedProviderLimit() {
        var configuration = InterviewConfiguration()
        configuration.candidateName = String(repeating: "A", count: 40_000)
        configuration.role = String(repeating: "B", count: 40_000)
        configuration.company = String(repeating: "C", count: 40_000)
        configuration.interviewType = String(repeating: "D", count: 40_000)
        configuration.resume = String(repeating: "Resume fact. ", count: 10_000)
        configuration.projects = String(repeating: "Project fact. ", count: 10_000)
        configuration.jobDescription = "JOB_CONTEXT_SENTINEL " + String(repeating: "Role. ", count: 10_000)
        configuration.notes = "NOTE_CONTEXT_SENTINEL " + String(repeating: "Note. ", count: 10_000)
        XCTAssertLessThan(configuration.systemPrompt.count, 25_000)
        XCTAssertTrue(configuration.systemPrompt.contains("JOB_CONTEXT_SENTINEL"))
        XCTAssertTrue(configuration.systemPrompt.contains("NOTE_CONTEXT_SENTINEL"))
    }

    func testMultiScalarTextStillFitsProviderCharacterBudget() {
        var configuration = InterviewConfiguration()
        let expandedText = String(repeating: "👩🏽‍💻", count: 30_000)
        configuration.resume = expandedText
        configuration.projects = expandedText
        configuration.jobDescription = expandedText
        configuration.notes = expandedText
        XCTAssertLessThan(configuration.systemPrompt.unicodeScalars.count, 25_000)
    }

    func testPracticeAndAssistanceHaveDifferentConversationRoles() {
        var configuration = InterviewConfiguration()
        XCTAssertTrue(configuration.systemPrompt.contains("first person"))
        configuration.mode = .practice
        XCTAssertTrue(configuration.systemPrompt.contains("Ask exactly one"))
        XCTAssertTrue(configuration.systemPrompt.contains("Do not answer questions on the candidate"))
        XCTAssertFalse(configuration.systemPrompt.contains("ready for the candidate to adapt"))
    }

    func testProfileSelectionCopiesFactsButPreservesJobContext() {
        var configuration = InterviewConfiguration()
        configuration.company = "Example"
        configuration.jobDescription = "Engineering role."
        let profile = CandidateProfile(name: "Taylor", role: "Developer", resume: "Resume facts", projects: "Project facts")
        configuration.useProfile(profile)
        XCTAssertEqual(configuration.profileID, profile.id)
        XCTAssertEqual(configuration.resume, "Resume facts")
        XCTAssertEqual(configuration.projects, "Project facts")
        XCTAssertEqual(configuration.company, "Example")
        XCTAssertEqual(configuration.jobDescription, "Engineering role.")
    }

    func testSessionRoundTripPreservesMessagesAndSourceContext() throws {
        var configuration = InterviewConfiguration()
        configuration.jobURL = "https://example.com/job"
        configuration.importedJobURL = configuration.jobURL
        configuration.jobDescription = "Resolved job text"
        let messages = [
            InterviewMessage(role: .user, content: "How do you debug?"),
            InterviewMessage(role: .assistant, content: "I first reproduce the issue.")
        ]
        let session = SavedInterview(configuration: configuration, messages: messages, firstResponseLatencyMS: 640)
        let decoded = try JSONDecoder().decode(SavedInterview.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(decoded, session)
        XCTAssertTrue(decoded.exportText.contains(messages[0].content))
        XCTAssertTrue(decoded.exportText.contains(messages[1].content))
    }

    func testExportUsesPracticeSpeakerLabels() {
        var configuration = InterviewConfiguration()
        configuration.mode = .practice
        let session = SavedInterview(configuration: configuration, messages: [
            InterviewMessage(role: .assistant, content: "Describe a project."),
            InterviewMessage(role: .user, content: "I built a scheduling tool.")
        ])
        XCTAssertTrue(session.exportText.contains("Interviewer:\nDescribe a project."))
        XCTAssertTrue(session.exportText.contains("Candidate:\nI built a scheduling tool."))
        XCTAssertFalse(session.exportText.contains("Suggested answer:"))
    }
}
