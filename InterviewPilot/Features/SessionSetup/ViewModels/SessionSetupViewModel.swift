import Foundation
import SwiftUI
import UniformTypeIdentifiers

@Observable
final class SessionSetupViewModel {
    var resumeText: String = ""
    var resumeDocumentName: String?
    var jobListingURL: String = ""
    var jobListingTitle: String?
    var jobListingText: String = ""
    var interviewType: InterviewType = .general
    var jobCategory: JobCategory?
    var positionLevel: PositionLevel?
    var responseFormat: ResponseFormat = .hybrid
    var responseQualityMode: ResponseQualityMode = .standard
    var additionalNotes: String = ""
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
    var isReady: Bool { hasJobListing }
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

        // Inject structured profile fields that aren't already in the resume text
        let profile = ProfileService.shared.profile
        var profileContext: [String] = []
        if let role = profile?.currentRole, !role.isEmpty {
            var line = "Current role: \(role)"
            if let company = profile?.currentCompany, !company.isEmpty {
                line += " at \(company)"
            }
            if let years = profile?.yearsInRole, years > 0 {
                line += " (\(years) years)"
            }
            profileContext.append(line)
        }
        if let experiences = profile?.workExperiences, !experiences.isEmpty {
            let formatted = experiences.prefix(5).map { entry in
                let period = entry.endYear.map { "\(entry.startYear)–\($0)" } ?? "\(entry.startYear)–present"
                return "- \(entry.title) at \(entry.company) (\(period))"
            }.joined(separator: "\n")
            profileContext.append("Work history:\n\(formatted)")
        }
        if let skills = profile?.skills, !skills.isEmpty {
            profileContext.append("Key skills: \(skills.map(\.name).joined(separator: ", "))")
        }
        if !profileContext.isEmpty {
            parts.append("\nCANDIDATE PROFILE:\n\(profileContext.joined(separator: "\n"))")
        }

        if let linkedin = linkedInProfile, !linkedin.isEmpty {
            parts.append("\nCANDIDATE'S LINKEDIN PROFILE:\n\(linkedin.formattedContext)")
        }
        let trimmedNotes = additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            parts.append("\nADDITIONAL NOTES:\n\(trimmedNotes)")
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

        // Load resume from user profile if not already set
        let profileService = ProfileService.shared
        if resumeText.isEmpty, let profile = profileService.profile {
            if let savedResume = profile.resumeText, !savedResume.isEmpty {
                resumeText = savedResume
            }
            if linkedInURL.isEmpty, let savedLinkedIn = profile.linkedinUrl, !savedLinkedIn.isEmpty {
                linkedInURL = savedLinkedIn
            }
        }

        // Restore saved LinkedIn URL and profile text
        if let savedLinkedIn = KeychainService.load(key: .linkedInURL),
           !savedLinkedIn.isEmpty, linkedInURL.isEmpty {
            linkedInURL = savedLinkedIn
        }
        if !linkedInURL.isEmpty {
            if let savedText = UserDefaults.standard.string(forKey: "linkedInProfileText"),
               !savedText.isEmpty {
                linkedInProfileText = savedText
                analyzeLinkedInProfile()
            }
        }

        // Restore additional notes
        if let savedNotes = UserDefaults.standard.string(forKey: "additionalNotes") {
            additionalNotes = savedNotes
        }

        do {
            let settings = try await settingsService.fetchSettings()
            interviewType = settings.interviewType
            shouldPreGenerate = settings.shouldPreGenerate
        } catch {
            // Keep local defaults if the backend is unavailable.
        }
    }

    func saveAdditionalNotes() {
        UserDefaults.standard.set(additionalNotes, forKey: "additionalNotes")
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

        // Auto-analyze when a valid-looking URL is pasted or entered
        if looksLikeURL(trimmed) {
            Task { await analyzeJobListing() }
        }
    }

    private func looksLikeURL(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return true }
        if lower.contains(".com/") || lower.contains(".io/") || lower.contains(".org/") || lower.contains(".co/") { return true }
        return false
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

    func prepareSession() async -> UUID? {
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

            // Sync StoreKit transactions so entitlement is current.
            await subscriptionService.refresh(forceStoreKitSync: true)

            if responseQualityMode.requiresPriorityModels,
               !(subscriptionService.currentEntitlement?.hasPriorityModels ?? false) {
                errorMessage = "Top Tier mode requires a Pro subscription."
                shouldPresentPaywall = true
                return nil
            }

            // Attempt to load API keys — non-fatal so session can still start
            do {
                try await ensureRuntimeKeys()
            } catch {
                // Keys may already be in Keychain from a prior session
            }

            let sessionId = UUID()

            // Claim interview slot — non-fatal in debug builds
            do {
                _ = try await subscriptionService.claimInterviewAccess(
                    sessionClientId: sessionId,
                    sessionMode: .liveInterview
                )
            } catch {
                #if !DEBUG
                if let billingError = error as? BillingClientError {
                    errorMessage = billingError.localizedDescription
                    if case .paymentRequired = billingError { shouldPresentPaywall = true }
                    if case .featureUnavailable = billingError { shouldPresentPaywall = true }
                } else {
                    errorMessage = error.localizedDescription
                }
                return nil
                #endif
            }

            return sessionId
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

    private func ensureRuntimeKeys() async throws {
        if KeychainService.load(key: .openAIAPIKey) == nil ||
            KeychainService.load(key: .deepgramAPIKey) == nil {
            await authService.fetchAndStoreAPIKeys()
        }

        // Retry once after a fresh token refresh
        if KeychainService.load(key: .openAIAPIKey) == nil ||
            KeychainService.load(key: .deepgramAPIKey) == nil {
            _ = await authService.refreshTokenIfNeeded()
            await authService.fetchAndStoreAPIKeys()
        }

        guard KeychainService.load(key: .openAIAPIKey) != nil,
              KeychainService.load(key: .deepgramAPIKey) != nil else {
            throw missingAccessError()
        }
    }

    private var currentPreparationFingerprint: String {
        [
            enrichedResume.trimmingCharacters(in: .whitespacesAndNewlines),
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
            resume: enrichedResume,
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

        // When entitlement is nil (e.g. after reinstall before sync completes),
        // surface a paywall so the user can restore purchases rather than
        // showing a dead-end error.
        if subscriptionService.currentEntitlement == nil {
            return .paymentRequired("Unable to verify your subscription. Please restore purchases or sign in again.")
        }

        return .server("Live AI access is not currently available.")
    }
}
