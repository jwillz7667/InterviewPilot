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
    var resumeDocumentName: String?
    var jobListingURL: String = ""
    var jobListingTitle: String?
    var jobListingText: String = ""
    var sessionMode: SessionMode = .liveInterview
    var interviewType: InterviewType = .general
    var jobCategory: JobCategory?
    var positionLevel: PositionLevel?
    var responseFormat: ResponseFormat = .hybrid
    var responseQualityMode: ResponseQualityMode = .standard
    var showResumeInput: Bool = false
    var shouldPresentPaywall: Bool = false
    var shouldPreGenerate: Bool = false
    var isLoadingDefaults: Bool = false
    var isPreparingSession: Bool = false
    var isAnalyzingJobListing: Bool = false
    var isGeneratingAnswerBank: Bool = false
    var preparedAnswers: [PreComputedAnswer] = []
    var preparedAnswerBankName: String?
    var preparedAnswerBankIsCached: Bool = false
    var preGenerationProgress: (current: Int, total: Int) = (0, 0)

    // GitHub integration
    var githubUsername: String = ""
    var githubProfile: GitHubProfileSummary?
    var selectedRepoNames: Set<String> = []
    var isLoadingGitHub: Bool = false
    var hasGitHubProfile: Bool { githubProfile != nil }

    // LinkedIn integration
    var linkedInURL: String = ""
    var linkedInProfileText: String = ""
    var linkedInProfile: LinkedInProfileData?
    var isLoadingLinkedIn: Bool = false
    var hasLinkedInProfile: Bool { linkedInProfile != nil && !(linkedInProfile?.isEmpty ?? true) }

    // Structured job analysis
    var structuredJobRequirements: StructuredJobRequirements?

    var errorMessage: String?

    private let authService = AuthService.shared
    private let subscriptionService = SubscriptionService.shared
    private let settingsService = UserSettingsService.shared
    private let answerBankService = AnswerBankAPIService.shared
    private var hasLoadedDefaults = false
    private var analyzedJobListingURL: String?
    private var preparedFingerprint: String?

    var hasResume: Bool { !resumeText.isEmpty }
    var hasJobListingURL: Bool { !jobListingURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var hasJobListing: Bool { !jobListingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var isReady: Bool { hasResume && hasJobListing && jobCategory != nil && positionLevel != nil }
    var hasPreparedAnswers: Bool { !preparedAnswers.isEmpty }
    var derivedProfile: RoleResponseProfile {
        RoleResponseProfile.derive(
            jobCategory: jobCategory ?? .generalBusiness,
            positionLevel: positionLevel ?? .midLevel
        )
    }
    var jobDescription: String {
        guard hasJobListing else { return "" }

        var sections: [String] = []
        if let jobListingTitle, !jobListingTitle.isEmpty {
            sections.append("ROLE TITLE:\n\(jobListingTitle)")
        }

        let normalizedURL = jobListingURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedURL.isEmpty {
            sections.append("JOB LISTING URL:\n\(normalizedURL)")
        }

        if let jobCategory {
            sections.append("JOB CATEGORY:\n\(jobCategory.displayName)")
        }

        if let positionLevel {
            sections.append("POSITION LEVEL:\n\(positionLevel.displayName)")
        }

        sections.append("TARGET INTERVIEW TRACK:\n\(interviewType.displayName)")
        sections.append("JOB LISTING CONTENT:\n\(jobListingText)")

        if let structured = structuredJobRequirements {
            sections.append(structured.formattedAnalysis)
        }

        return sections.joined(separator: "\n\n")
    }

    var enrichedResume: String {
        var parts = [resumeText]
        if let profile = githubProfile {
            let featured = selectedRepoNames.isEmpty
                ? profile.topRepos
                : profile.topRepos.filter { selectedRepoNames.contains($0.name) }
            parts.append("\nCANDIDATE'S GITHUB PROFILE:\n\(profile.formattedContext(featuredRepos: featured))")
        }
        if let linkedin = linkedInProfile, !linkedin.isEmpty {
            parts.append("\nCANDIDATE'S LINKEDIN PROFILE:\n\(linkedin.formattedContext)")
        }
        return parts.joined(separator: "\n")
    }
    var resumeStatusLabel: String {
        if let resumeDocumentName, !resumeDocumentName.isEmpty {
            return resumeDocumentName
        }

        return "Resume ready"
    }
    var jobListingStatusLabel: String {
        if let jobListingTitle, !jobListingTitle.isEmpty {
            return jobListingTitle
        }

        return "Listing analyzed"
    }
    var prepSummary: String {
        if isGeneratingAnswerBank {
            return responseQualityMode == .premium
                ? "Building a top-tier prep bank for this role."
                : "Building a personalized question bank for this role."
        }

        guard hasPreparedAnswers else {
            return shouldPreGenerate
                ? "Generate likely questions and fast reusable answers before starting."
                : "Skip prep generation and start immediately with live processing only."
        }

        let sourceLabel = preparedAnswerBankIsCached ? "reused" : "generated"
        let bankName = preparedAnswerBankName ?? "prep bank"
        return "\(preparedAnswers.count) prepared questions \(sourceLabel) from \(bankName)."
    }

    func loadIfNeeded() async {
        guard !hasLoadedDefaults else { return }

        isLoadingDefaults = true
        defer {
            isLoadingDefaults = false
            hasLoadedDefaults = true
        }

        // Restore saved GitHub username and repo selections
        loadSelectedRepos()
        if let savedUsername = KeychainService.load(key: .githubUsername),
           !savedUsername.isEmpty {
            githubUsername = savedUsername
            await fetchGitHubProfile()
        }

        // Restore saved LinkedIn URL and profile text
        if let savedLinkedIn = KeychainService.load(key: .linkedInURL),
           !savedLinkedIn.isEmpty {
            linkedInURL = savedLinkedIn
            if let savedText = UserDefaults.standard.string(forKey: "linkedInProfileText"),
               !savedText.isEmpty {
                linkedInProfileText = savedText
                analyzeLinkedInProfile()
            }
        }

        do {
            let settings = try await settingsService.fetchSettings()
            interviewType = settings.interviewType
            responseFormat = settings.responseFormat
            shouldPreGenerate = settings.shouldPreGenerate
        } catch {
            // Keep local defaults if the backend is unavailable.
        }
    }

    func fetchGitHubProfile() async {
        let trimmed = githubUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            githubProfile = nil
            return
        }

        isLoadingGitHub = true
        defer { isLoadingGitHub = false }

        do {
            let profile = try await GitHubService.fetchProfile(username: trimmed)
            githubProfile = profile
            _ = KeychainService.save(key: .githubUsername, value: profile.username)
            invalidatePreparedAnswerBankIfNeeded()
        } catch {
            githubProfile = nil
            errorMessage = error.localizedDescription
        }
    }

    func toggleRepoSelection(_ repoName: String) {
        if selectedRepoNames.contains(repoName) {
            selectedRepoNames.remove(repoName)
        } else {
            guard selectedRepoNames.count < 3 else { return }
            selectedRepoNames.insert(repoName)
        }
        saveSelectedRepos()
        invalidatePreparedAnswerBankIfNeeded()
    }

    func isRepoSelected(_ repoName: String) -> Bool {
        selectedRepoNames.contains(repoName)
    }

    func clearGitHubProfile() {
        githubUsername = ""
        githubProfile = nil
        selectedRepoNames = []
        _ = KeychainService.delete(key: .githubUsername)
        UserDefaults.standard.removeObject(forKey: "selectedGitHubRepos")
        invalidatePreparedAnswerBankIfNeeded()
    }

    private func saveSelectedRepos() {
        UserDefaults.standard.set(Array(selectedRepoNames), forKey: "selectedGitHubRepos")
    }

    private func loadSelectedRepos() {
        if let saved = UserDefaults.standard.stringArray(forKey: "selectedGitHubRepos") {
            selectedRepoNames = Set(saved)
        }
    }

    // MARK: - LinkedIn

    func analyzeLinkedInProfile() {
        guard let normalized = LinkedInService.normalizeURL(linkedInURL) else {
            linkedInProfile = nil
            errorMessage = LinkedInServiceError.invalidURL.localizedDescription
            return
        }

        let text = linkedInProfileText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            linkedInProfile = nil
            return
        }

        linkedInProfile = LinkedInService.parseProfileText(text, url: normalized)
        _ = KeychainService.save(key: .linkedInURL, value: normalized)
        UserDefaults.standard.set(linkedInProfileText, forKey: "linkedInProfileText")
        invalidatePreparedAnswerBankIfNeeded()
    }

    func fetchLinkedInBasicInfo() async {
        guard let normalized = LinkedInService.normalizeURL(linkedInURL) else {
            errorMessage = LinkedInServiceError.invalidURL.localizedDescription
            return
        }

        isLoadingLinkedIn = true
        defer { isLoadingLinkedIn = false }

        let (name, headline) = await LinkedInService.fetchBasicProfile(url: normalized)

        // If we got basic info and there's no profile text yet, create a minimal profile
        if let name, !name.isEmpty {
            if linkedInProfileText.isEmpty {
                var prefilledLines: [String] = []
                prefilledLines.append(name)
                if let headline, !headline.isEmpty {
                    prefilledLines.append(headline)
                }
                linkedInProfileText = prefilledLines.joined(separator: "\n")
            }
        }

        _ = KeychainService.save(key: .linkedInURL, value: normalized)

        // Parse whatever text we have
        if !linkedInProfileText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            analyzeLinkedInProfile()
        }
    }

    func clearLinkedInProfile() {
        linkedInURL = ""
        linkedInProfileText = ""
        linkedInProfile = nil
        _ = KeychainService.delete(key: .linkedInURL)
        UserDefaults.standard.removeObject(forKey: "linkedInProfileText")
        invalidatePreparedAnswerBankIfNeeded()
    }

    func handleResumeFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            if let text = ResumeParserService.extractText(from: url) {
                resumeText = text
                resumeDocumentName = url.lastPathComponent
            }
        case .failure(let error):
            errorMessage = "Failed to load resume: \(error.localizedDescription)"
        }
    }

    func handleJobListingURLChange() {
        let trimmed = jobListingURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clearAnalyzedJobListing()
            return
        }

        if analyzedJobListingURL == trimmed, hasJobListing {
            return
        }

        clearAnalyzedJobListing(clearURL: false)
    }

    func analyzeJobListing() async {
        guard !isAnalyzingJobListing else { return }

        let trimmed = jobListingURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Add a job listing URL first."
            return
        }

        isAnalyzingJobListing = true
        errorMessage = nil
        defer { isAnalyzingJobListing = false }

        do {
            let analysis = try await JobListingAnalysisService.analyze(urlText: trimmed)
            analyzedJobListingURL = analysis.url.absoluteString
            jobListingURL = analysis.url.absoluteString
            jobListingTitle = analysis.title
            jobListingText = analysis.extractedText
            jobCategory = analysis.jobCategory
            positionLevel = analysis.positionLevel
            interviewType = derivedProfile.interviewType
            structuredJobRequirements = JobDescriptionAnalyzer.analyze(
                title: analysis.title,
                rawText: analysis.extractedText
            )
            invalidatePreparedAnswerBankIfNeeded()
        } catch {
            clearAnalyzedJobListing(clearURL: false)
            errorMessage = error.localizedDescription
        }
    }

    func updateShouldPreGenerate(_ enabled: Bool) async {
        shouldPreGenerate = enabled
        errorMessage = nil

        do {
            let settings = try await settingsService.updateSettings(
                UserSettingsUpdate(shouldPreGenerate: enabled)
            )
            shouldPreGenerate = settings.shouldPreGenerate
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func invalidatePreparedAnswerBankIfNeeded() {
        let fingerprint = currentPreparationFingerprint
        guard preparedFingerprint != nil, preparedFingerprint != fingerprint else { return }

        preparedAnswers = []
        preparedAnswerBankName = nil
        preparedAnswerBankIsCached = false
        preGenerationProgress = (0, 0)
        preparedFingerprint = nil
    }

    func generatePreparedAnswers(force: Bool = false) async {
        guard isReady else { return }

        do {
            try await prepareAnswerBankIfNeeded(force: force)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareSession() async -> SessionLaunchDestination? {
        guard isReady, !isPreparingSession else { return nil }

        isPreparingSession = true
        errorMessage = nil
        shouldPresentPaywall = false
        defer { isPreparingSession = false }

        do {
            if shouldPreGenerate {
                do {
                    try await prepareAnswerBankIfNeeded()
                } catch {
                    errorMessage = "Prep generation failed. Starting without saved prep assets."
                    preparedAnswers = []
                    preparedAnswerBankName = nil
                    preparedAnswerBankIsCached = false
                    preGenerationProgress = (0, 0)
                }
            }

            if responseQualityMode.requiresPriorityModels,
               !(subscriptionService.currentEntitlement?.hasPriorityModels ?? false) {
                errorMessage = "Top Tier mode requires a Pro subscription."
                shouldPresentPaywall = true
                return nil
            }

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
        let profile = derivedProfile

        return LiveSessionViewModel(
            sessionId: sessionId,
            resume: enrichedResume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            jobCategory: jobCategory ?? .generalBusiness,
            positionLevel: positionLevel ?? .midLevel,
            responseFormat: responseFormat,
            responseBehavior: profile.responseBehavior,
            responseTone: profile.responseTone,
            responseEmphasis: profile.responseEmphasis,
            responseQualityMode: responseQualityMode,
            preComputedAnswers: shouldPreGenerate ? preparedAnswers : [],
            deepgramKey: deepgramKey,
            openAIKey: openAIKey
        )
    }

    func createPrepViewModel(sessionId: UUID) -> PrepSessionViewModel {
        let openAIKey = KeychainService.load(key: .openAIAPIKey) ?? ""

        return PrepSessionViewModel(
            sessionId: sessionId,
            resume: enrichedResume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            jobCategory: jobCategory ?? .generalBusiness,
            positionLevel: positionLevel ?? .midLevel,
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

    private var currentPreparationFingerprint: String {
        [
            resumeText.trimmingCharacters(in: .whitespacesAndNewlines),
            jobDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            jobListingURL.trimmingCharacters(in: .whitespacesAndNewlines),
            jobCategory?.rawValue ?? "",
            positionLevel?.rawValue ?? "",
            interviewType.rawValue,
            responseQualityMode.rawValue,
        ].joined(separator: "::")
    }

    private func prepareAnswerBankIfNeeded(force: Bool = false) async throws {
        let fingerprint = currentPreparationFingerprint
        if !force, preparedFingerprint == fingerprint, !preparedAnswers.isEmpty {
            return
        }

        isGeneratingAnswerBank = true
        preGenerationProgress = (0, 0)
        defer { isGeneratingAnswerBank = false }

        let bank = try await answerBankService.generateOrReuseAnswerBank(
            resume: resumeText,
            jobDescription: jobDescription,
            interviewType: interviewType,
            qualityMode: responseQualityMode
        )

        preparedAnswers = bank.answers
        preparedAnswerBankName = bank.name
        preparedAnswerBankIsCached = bank.fromCache
        preparedFingerprint = fingerprint
        preGenerationProgress = (bank.answers.count, bank.answers.count)
    }

    private func clearAnalyzedJobListing(clearURL: Bool = true) {
        if clearURL {
            jobListingURL = ""
        }

        jobListingTitle = nil
        jobListingText = ""
        jobCategory = nil
        positionLevel = nil
        analyzedJobListingURL = nil
        structuredJobRequirements = nil
        invalidatePreparedAnswerBankIfNeeded()
    }

    private func missingAccessError() -> BillingClientError {
        if subscriptionService.currentEntitlement?.paywallRequired == true {
            return .paymentRequired("Your free trial interviews are complete. Upgrade to continue.")
        }

        return .server("Live AI access is not currently available.")
    }
}
