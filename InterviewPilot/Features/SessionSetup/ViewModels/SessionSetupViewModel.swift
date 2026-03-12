import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum SessionLaunchDestination {
    case live(UUID)
    case voicePrep(UUID)
}

@Observable
final class SessionSetupViewModel {
    var resumeText: String = ""
    var jobDescription: String = ""
    var sessionMode: SessionMode = .liveInterview
    var interviewType: InterviewType = .general
    var responseFormat: ResponseFormat = .hybrid
    var showResumeInput: Bool = false
    var shouldPresentPaywall: Bool = false

    var errorMessage: String?

    private let authService = AuthService.shared
    private let subscriptionService = SubscriptionService.shared

    var hasResume: Bool { !resumeText.isEmpty }
    var hasJobDescription: Bool { !jobDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isReady: Bool { hasResume && hasJobDescription }

    func handleResumeFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let text = ResumeParserService.extractText(from: url) {
                resumeText = text
            }
        case .failure(let error):
            errorMessage = "Failed to load resume: \(error.localizedDescription)"
        }
    }

    func prepareSession() async -> SessionLaunchDestination? {
        guard isReady else { return nil }

        errorMessage = nil
        shouldPresentPaywall = false

        do {
            try await ensureRuntimeKeys(for: sessionMode)

            let sessionId = UUID()
            _ = try await subscriptionService.claimInterviewAccess(
                sessionClientId: sessionId,
                sessionMode: sessionMode
            )

            switch sessionMode {
            case .liveInterview:
                return .live(sessionId)
            case .voicePrep:
                return .voicePrep(sessionId)
            }
        } catch let error as BillingClientError {
            errorMessage = error.localizedDescription
            if case .paymentRequired = error {
                shouldPresentPaywall = true
            } else if case .featureUnavailable = error {
                shouldPresentPaywall = true
            }
            return nil
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func createLiveViewModel(sessionId: UUID) -> LiveSessionViewModel {
        let deepgramKey = KeychainService.load(key: .deepgramAPIKey) ?? ""
        let openAIKey = KeychainService.load(key: .openAIAPIKey) ?? ""

        return LiveSessionViewModel(
            sessionId: sessionId,
            resume: resumeText,
            jobDescription: jobDescription,
            interviewType: interviewType,
            responseFormat: responseFormat,
            preComputedAnswers: [],
            deepgramKey: deepgramKey,
            openAIKey: openAIKey
        )
    }

    func createPrepViewModel(sessionId: UUID) -> PrepSessionViewModel {
        let openAIKey = KeychainService.load(key: .openAIAPIKey) ?? ""

        return PrepSessionViewModel(
            sessionId: sessionId,
            resume: resumeText,
            jobDescription: jobDescription,
            interviewType: interviewType,
            openAIKey: openAIKey
        )
    }

    private func ensureRuntimeKeys(for sessionMode: SessionMode) async throws {
        switch sessionMode {
        case .liveInterview:
            if KeychainService.load(key: .openAIAPIKey) == nil ||
                KeychainService.load(key: .deepgramAPIKey) == nil {
                await authService.fetchAndStoreAPIKeys()
            }

            guard KeychainService.load(key: .openAIAPIKey) != nil,
                  KeychainService.load(key: .deepgramAPIKey) != nil else {
                throw missingAccessError()
            }
        case .voicePrep:
            if KeychainService.load(key: .openAIAPIKey) == nil {
                await authService.fetchAndStoreAPIKeys()
            }

            guard KeychainService.load(key: .openAIAPIKey) != nil else {
                throw missingAccessError()
            }
        }
    }

    private func missingAccessError() -> BillingClientError {
        if subscriptionService.entitlement?.paywallRequired == true {
            return .paymentRequired("Your free trial interviews are complete. Upgrade to continue.")
        }

        return .server("Live AI access is not currently available.")
    }
}
