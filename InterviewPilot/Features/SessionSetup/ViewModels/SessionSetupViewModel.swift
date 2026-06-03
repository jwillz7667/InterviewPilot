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
    /// Locked into the SessionAccessGrant on `prepareSession`. Standard burns the
    /// monthly standard quota, Premium burns the premium quota and unlocks the
    /// `gpt-4.1`/`o4-mini` engines server-side.
    var selectedQuality: InterviewQuality = .standard
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

    // Interview profile selection
    var selectedProfileId: String?
    var selectedProfile: InterviewProfile?
    var availableProfiles: [InterviewProfileSummary] = []

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

    var effectiveQualityMode: ResponseQualityMode {
        guard let quality = subscriptionService.currentEntitlement?.responseQuality else {
            return .free
        }
        switch quality {
        case "premium": return .premium
        case "enhanced": return .standard
        default: return .free
        }
    }

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
        if let profile = selectedProfile {
            return buildEnrichedResumeFromInterviewProfile(profile)
        }
        return buildEnrichedResumeFromLegacyProfile()
    }

    private func buildEnrichedResumeFromInterviewProfile(_ profile: InterviewProfile) -> String {
        var parts: [String] = []

        // Resume text from profile or existing
        let baseResume = profile.resumeText ?? resumeText
        if !baseResume.isEmpty {
            parts.append(baseResume)
        }

        // Candidate profile header
        var profileLines: [String] = []

        if let role = profile.currentRole, !role.isEmpty {
            var line = "Current role: \(role)"
            if let company = profile.currentCompany, !company.isEmpty {
                line += " at \(company)"
            }
            if let years = profile.yearsInRole, years > 0 {
                line += " (\(years) years)"
            }
            profileLines.append(line)
        }
        if let summary = profile.summary, !summary.isEmpty {
            profileLines.append("Summary: \(summary)")
        }
        if let style = profile.communicationStyle, !style.isEmpty {
            profileLines.append("Communication preference: \(style)")
        }
        if !profileLines.isEmpty {
            parts.append("\nCANDIDATE PROFILE:\n\(profileLines.joined(separator: "\n"))")
        }

        // Work history (max 5)
        if !profile.workExperiences.isEmpty {
            let formatted = profile.workExperiences.prefix(5).map { entry in
                let period = entry.endYear.map { "\(entry.startYear)-\($0)" } ?? "\(entry.startYear)-present"
                var line = "- \(entry.title) at \(entry.company) (\(period))"
                if let desc = entry.description, !desc.isEmpty {
                    line += ": \(desc)"
                }
                return line
            }.joined(separator: "\n")
            parts.append("\nWORK HISTORY:\n\(formatted)")
        }

        // Skills grouped by category (max 20 per category)
        if !profile.skills.isEmpty {
            var skillGroups: [String: [String]] = [:]
            for skill in profile.skills {
                let category = skill.category?.lowercased() ?? "other"
                skillGroups[category, default: []].append(skill.name)
            }

            var skillLines: [String] = []
            let orderedCategories = ["language", "framework", "tool"]
            for category in orderedCategories {
                if let names = skillGroups[category], !names.isEmpty {
                    let truncated = names.prefix(20).joined(separator: ", ")
                    skillLines.append("\(category.capitalized)s: \(truncated)")
                    skillGroups.removeValue(forKey: category)
                }
            }
            // Remaining categories
            for (category, names) in skillGroups.sorted(by: { $0.key < $1.key }) where !names.isEmpty {
                let truncated = names.prefix(20).joined(separator: ", ")
                let label = category == "other" ? "Other" : category.capitalized
                skillLines.append("\(label): \(truncated)")
            }

            if !skillLines.isEmpty {
                parts.append("\nSKILLS:\n\(skillLines.joined(separator: "\n"))")
            }
        }

        // Education
        if !profile.education.isEmpty {
            let formatted = profile.education.map { entry in
                var line = "- \(entry.degree)"
                if let field = entry.field, !field.isEmpty {
                    line += " in \(field)"
                }
                line += " from \(entry.institution)"
                if let startYear = entry.startYear {
                    let endPart = entry.endYear.map { String($0) } ?? "present"
                    line += " (\(startYear)-\(endPart))"
                } else if let endYear = entry.endYear {
                    line += " (\(endYear))"
                }
                return line
            }.joined(separator: "\n")
            parts.append("\nEDUCATION:\n\(formatted)")
        }

        // Certifications
        if !profile.certifications.isEmpty {
            let formatted = profile.certifications.map { entry in
                var line = "- \(entry.name)"
                if let issuer = entry.issuer, !issuer.isEmpty {
                    line += " from \(issuer)"
                }
                if let year = entry.year {
                    line += " (\(year))"
                }
                return line
            }.joined(separator: "\n")
            parts.append("\nCERTIFICATIONS:\n\(formatted)")
        }

        // Key projects (max 5)
        if !profile.projects.isEmpty {
            let formatted = profile.projects.prefix(5).map { entry in
                var line = "- \(entry.name)"
                if let desc = entry.description, !desc.isEmpty {
                    line += ": \(desc)"
                }
                if let tech = entry.techStack, !tech.isEmpty {
                    line += " | Tech: \(tech)"
                }
                if let year = entry.year {
                    line += " (\(year))"
                }
                return line
            }.joined(separator: "\n")
            parts.append("\nKEY PROJECTS:\n\(formatted)")
        }

        // Achievements (max 5)
        if !profile.achievements.isEmpty {
            let formatted = profile.achievements.prefix(5).map { entry in
                var line = "- \(entry.description)"
                if let metric = entry.metric, !metric.isEmpty {
                    line += " — \(metric)"
                }
                if let year = entry.year {
                    line += " (\(year))"
                }
                return line
            }.joined(separator: "\n")
            parts.append("\nACHIEVEMENTS:\n\(formatted)")
        }

        // LinkedIn
        if let linkedin = linkedInProfile, !linkedin.isEmpty {
            parts.append("\nCANDIDATE'S LINKEDIN PROFILE:\n\(linkedin.formattedContext)")
        }

        // Additional notes
        let trimmedNotes = additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            parts.append("\nADDITIONAL NOTES:\n\(trimmedNotes)")
        }

        return parts.joined(separator: "\n")
    }

    private func buildEnrichedResumeFromLegacyProfile() -> String {
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

        // Load interview profiles for the profile selector. Not gated on
        // resume_personalization: every tier owns at least one profile now, and
        // that profile must be usable as live-session context.
        let interviewProfileService = InterviewProfileService.shared
        await interviewProfileService.fetchProfiles()
        availableProfiles = interviewProfileService.profiles

        // Auto-select the default profile if none selected.
        if selectedProfileId == nil, let defaultProfile = interviewProfileService.defaultProfile {
            selectedProfileId = defaultProfile.id
            await loadSelectedProfile()
        }
    }

    func saveAdditionalNotes() {
        UserDefaults.standard.set(additionalNotes, forKey: "additionalNotes")
    }

    // MARK: - Interview Profile Selection

    func loadSelectedProfile() async {
        guard let profileId = selectedProfileId else {
            selectedProfile = nil
            return
        }
        do {
            selectedProfile = try await InterviewProfileService.shared.fetchProfile(id: profileId)
            if let profileResume = selectedProfile?.resumeText, !profileResume.isEmpty {
                resumeText = profileResume
            }
            if let linkedIn = selectedProfile?.linkedinUrl, !linkedIn.isEmpty {
                linkedInURL = linkedIn
            }
        } catch {
            // Surface the failure: a silently-dropped profile load is exactly why
            // "profiles aren't used as context" looked broken. Keep any existing
            // resume text the user typed.
            selectedProfile = nil
            errorMessage = "Couldn't load the selected profile. \(error.localizedDescription)"
        }
    }

    func selectProfile(_ profileId: String?) async {
        selectedProfileId = profileId
        await loadSelectedProfile()
        invalidatePreparedAnswerBankIfNeeded()
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
            resumeDocumentName = url.lastPathComponent
            Task {
                do {
                    let extracted = try await ResumeTextExtractor.extract(from: url)
                    resumeText = extracted.text
                } catch {
                    errorMessage = "Failed to load resume: \(error.localizedDescription)"
                }
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

            // Derive quality mode from subscription entitlement
            responseQualityMode = effectiveQualityMode

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

            // Claim interview slot — non-fatal in debug builds. Backend
            // enforces per-quality quota (FREE: 3 std + 1 prem, PRO: 25 + 10,
            // PREMIUM: unlimited) and locks the chosen quality into the
            // SessionAccessGrant so every downstream AI call inherits it.
            do {
                _ = try await subscriptionService.claimInterviewAccess(
                    sessionClientId: sessionId,
                    sessionMode: .liveInterview,
                    quality: selectedQuality
                )
            } catch {
                #if !DEBUG
                if let billingError = error as? BillingClientError {
                    errorMessage = billingError.localizedDescription
                    if billingError.shouldPresentPaywall {
                        shouldPresentPaywall = true
                    }
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
        let profile = derivedProfile
        let candidate = CandidateContext.build(
            from: selectedProfile,
            accountProfile: ProfileService.shared.profile,
            authDisplayName: authService.currentUser?.displayName
        )

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
            modelConfig: subscriptionService.currentEntitlement?.modelConfig,
            communicationStyle: selectedProfile?.communicationStyle,
            candidate: candidate.isEmpty ? nil : candidate,
            jobRequirements: structuredJobRequirements
        )
    }

    private func ensureRuntimeKeys() async throws {
        // Mint a fresh ephemeral Deepgram key from the backend up-front so a
        // missing trial / billing entitlement surfaces here rather than after
        // the user starts the session.
        do {
            _ = try await AIClient.shared.currentDeepgramKey(forceRefresh: true)
        } catch {
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

    // MARK: - Draft Persistence

    func saveDraft() {
        let draft = DraftSession(
            id: UUID(),
            savedAt: Date(),
            jobListingURL: jobListingURL,
            jobListingTitle: jobListingTitle ?? "",
            jobDescription: jobListingText,
            jobCategory: jobCategory?.rawValue ?? "",
            positionLevel: positionLevel?.rawValue ?? "",
            companyName: structuredJobRequirements?.companyName,
            interviewType: interviewType.rawValue,
            additionalNotes: additionalNotes,
            resumeDocumentName: resumeDocumentName
        )

        var drafts = DraftSession.loadAll()
        drafts.insert(draft, at: 0)
        DraftSession.saveAll(drafts)
    }

    func loadDraft(_ draft: DraftSession) {
        jobListingURL = draft.jobListingURL
        jobListingTitle = draft.jobListingTitle.isEmpty ? nil : draft.jobListingTitle
        jobListingText = draft.jobDescription
        jobCategory = JobCategory(rawValue: draft.jobCategory)
        positionLevel = PositionLevel(rawValue: draft.positionLevel)
        interviewType = InterviewType(rawValue: draft.interviewType) ?? .general
        additionalNotes = draft.additionalNotes
        resumeDocumentName = draft.resumeDocumentName

        // Re-derive structured requirements if we have listing text
        if !jobListingText.isEmpty {
            structuredJobRequirements = JobDescriptionAnalyzer.analyze(
                title: jobListingTitle,
                rawText: jobListingText
            )
        }

        // Remove this draft since it's now loaded
        DraftSession.delete(id: draft.id)
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
            return .paymentRequired(
                message: "Your free interviews are complete. Upgrade to continue.",
                quality: selectedQuality,
                feature: nil
            )
        }

        // When entitlement is nil (e.g. after reinstall before sync completes),
        // surface a paywall so the user can restore purchases rather than
        // showing a dead-end error.
        if subscriptionService.currentEntitlement == nil {
            return .paymentRequired(
                message: "Unable to verify your subscription. Please restore purchases or sign in again.",
                quality: nil,
                feature: nil
            )
        }

        return .server("Live AI access is not currently available.")
    }
}
