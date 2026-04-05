import SwiftUI

struct PracticeInterviewLaunchView: View {
    @State private var subscriptionService = SubscriptionService.shared
    @State private var profileService = InterviewProfileService.shared
    @State private var showPracticeSession = false
    @State private var showPaywall = false
    @State private var isPreparingSession = false
    @State private var errorMessage: String?
    @State private var preparedSessionId: UUID?
    @State private var selectedProfileId: String?
    @State private var selectedProfile: InterviewProfile?
    @State private var isLoadingProfile = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // Session config — can be passed from a history item or directly
    let resume: String
    let jobDescription: String
    let interviewType: InterviewType
    let jobListingUrl: String?
    let initialProfileId: String?
    let companyName: String?
    let positionTitle: String?

    init(
        resume: String,
        jobDescription: String,
        interviewType: InterviewType,
        jobListingUrl: String? = nil,
        profileId: String? = nil,
        companyName: String? = nil,
        positionTitle: String? = nil
    ) {
        self.resume = resume
        self.jobDescription = jobDescription
        self.interviewType = interviewType
        self.jobListingUrl = jobListingUrl
        self.initialProfileId = profileId
        self.companyName = companyName
        self.positionTitle = positionTitle
    }

    /// Convenience init from a SessionHistoryItem for "Practice Again" flow.
    init(from session: SessionHistoryItem) {
        self.resume = ProfileService.shared.profile?.resumeText ?? ""
        self.jobDescription = session.jobDescription ?? ""
        self.interviewType = session.reviewInterviewType
        self.jobListingUrl = session.jobListingUrl
        self.initialProfileId = session.profileId
        self.companyName = session.companyName
        self.positionTitle = session.positionTitle
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing24) {
                        headerSection
                        heroSection
                        profileSelectorSection
                        jobDetailsCard
                        infoSection

                        if let error = errorMessage {
                            errorBanner(error)
                        }

                        tipsSection
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.top, IATheme.spacing16)
                    .padding(.bottom, 140)
                }
                .iaScrollablePage()

                if !hasVoicePrepAccess {
                    featureGateOverlay
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                launchSection
                    .padding(.horizontal, IATheme.spacing16)
                    .padding(.bottom, IATheme.spacing8)
            }
            .fullScreenCover(isPresented: $showPracticeSession) {
                if let preparedSessionId {
                    PracticeInterviewView(viewModel: buildViewModel(sessionId: preparedSessionId))
                }
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView()
            }
            .task {
                await profileService.fetchProfiles()
                if selectedProfileId == nil {
                    selectedProfileId = initialProfileId ?? profileService.defaultProfile?.id
                }
                if let id = selectedProfileId {
                    await loadProfile(id: id)
                }
            }
        }
    }

    private var hasVoicePrepAccess: Bool {
        subscriptionService.currentEntitlement?.hasVoicePrep == true
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(IATheme.textPrimary)
                }

                Spacer()

                Text("Interview Ace")
                    .font(IATypography.labelLarge)
                    .foregroundStyle(IATheme.accent)

                Spacer()

                Color.clear.frame(width: 24)
            }

            Text("Practice\nInterview")
                .font(IATypography.displayMedium)
                .foregroundStyle(IATheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Rehearse with an AI interviewer in a realistic mock session.")
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [IATheme.primaryContainer.opacity(0.3), IATheme.primary.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 140)
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(IATheme.accent.opacity(0.7))

                    Text("Voice-to-voice practice")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }
    }

    // MARK: - Job Details Card

    private var jobDetailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Session Details")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                if let company = companyName, !company.isEmpty {
                    detailRow(icon: "building.2.fill", label: "Company", value: company)
                }

                if let position = positionTitle, !position.isEmpty {
                    detailRow(icon: "briefcase.fill", label: "Position", value: position)
                }

                detailRow(
                    icon: "questionmark.bubble.fill",
                    label: "Type",
                    value: interviewType.displayName
                )

                if let url = jobListingUrl, !url.isEmpty {
                    detailRow(icon: "link", label: "Listing", value: url)
                }
            }
            .padding(14)
            .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .stroke(IATheme.outlineVariant, lineWidth: 1)
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(IATheme.accent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(IATypography.labelSmall)
                    .foregroundStyle(IATheme.textSecondary)

                Text(value)
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(2)
            }

            Spacer()
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            let company = companyName ?? "the company"

            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(IATheme.accent.opacity(0.10))
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(IATheme.accent)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text("How it works")
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("The AI will interview you as if they are from \(company). They will ask questions based on your resume and the job description, just like a real interviewer.")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }

                Spacer()
            }
            .padding(14)
            .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .stroke(IATheme.outlineVariant, lineWidth: 1)
            }
        }
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(spacing: 12) {
            tipCard(
                icon: "mic.fill",
                title: "Speak naturally",
                detail: "Answer as you would in a real interview. The AI listens and responds conversationally."
            )

            tipCard(
                icon: "forward.fill",
                title: "Skip questions",
                detail: "Use the skip button to move to the next question if you want to practice a different topic."
            )
        }
    }

    private func tipCard(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(IATheme.accent.opacity(0.10))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(IATheme.accent)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                Text(detail)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
            }

            Spacer()
        }
        .padding(14)
        .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.outlineVariant, lineWidth: 1)
        }
    }

    // MARK: - Launch

    private var launchSection: some View {
        VStack(spacing: 10) {
            Button(action: startPracticeSession) {
                HStack(spacing: 10) {
                    if isPreparingSession {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "person.wave.2.fill")
                    }

                    Text(isPreparingSession ? "Preparing Session" : "Start Practice")
                }
            }
            .buttonStyle(IAPrimaryButtonStyle(isEnabled: !isPreparingSession && hasVoicePrepAccess))
            .disabled(isPreparingSession || !hasVoicePrepAccess)

            Button(action: { dismiss() }) {
                Text("Go back")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 24)
        .background(
            LinearGradient(
                stops: [
                    .init(color: IATheme.surfaceWhite.opacity(0), location: 0),
                    .init(color: IATheme.surfaceWhite.opacity(0.85), location: 0.15),
                    .init(color: IATheme.surfaceWhite, location: 0.35),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    // MARK: - Feature Gate Overlay

    private var featureGateOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .overlay {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(IATheme.accent)

                    Text("Practice Interview")
                        .font(IATypography.headlineMedium)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("Upgrade your plan to unlock voice-to-voice practice interviews with an AI interviewer.")
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textSecondary)
                        .multilineTextAlignment(.center)

                    Button("View Plans") {
                        showPaywall = true
                    }
                    .buttonStyle(IAPrimaryButtonStyle(isEnabled: true))
                    .padding(.top, 8)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                        .fill(IATheme.surfaceWhite)
                )
                .padding(.horizontal, 32)
            }
    }

    // MARK: - Error Banner

    private func errorBanner(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(IATypography.bodySmall)
            .foregroundStyle(IATheme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Profile Selector

    private var profileSelectorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interview Profile")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            if profileService.profiles.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 18))
                        .foregroundStyle(IATheme.textSecondary)

                    Text("No profiles yet. Using your default resume.")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                        .stroke(IATheme.outlineVariant, lineWidth: 1)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(profileService.profiles) { profile in
                            let isSelected = selectedProfileId == profile.id
                            Button {
                                selectedProfileId = profile.id
                                Task { await loadProfile(id: profile.id) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name)
                                        .font(IATypography.labelMedium)
                                        .foregroundStyle(isSelected ? .white : IATheme.textPrimary)
                                        .lineLimit(1)

                                    if let role = profile.currentRole {
                                        Text(role)
                                            .font(IATypography.labelSmall)
                                            .foregroundStyle(isSelected ? .white.opacity(0.7) : IATheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    isSelected ? IATheme.accent : IATheme.surfaceWhite,
                                    in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                                        .stroke(isSelected ? Color.clear : IATheme.outlineVariant, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let profile = selectedProfile {
                    HStack(spacing: 8) {
                        if let company = profile.currentCompany, !company.isEmpty {
                            Label(company, systemImage: "building.2")
                                .font(IATypography.labelSmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }

                        if profile.skills.count > 0 {
                            Text("\(profile.skills.count) skills")
                                .font(IATypography.labelSmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }

                        if profile.workExperiences.count > 0 {
                            Text("\(profile.workExperiences.count) roles")
                                .font(IATypography.labelSmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                    }
                    .padding(.top, 4)
                } else if isLoadingProfile {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7).tint(IATheme.accent)
                        Text("Loading profile...")
                            .font(IATypography.labelSmall)
                            .foregroundStyle(IATheme.textSecondary)
                    }
                }
            }
        }
    }

    private func loadProfile(id: String) async {
        isLoadingProfile = true
        do {
            selectedProfile = try await profileService.fetchProfile(id: id)
        } catch {
            selectedProfile = nil
        }
        isLoadingProfile = false
    }

    /// Build enriched resume from the selected profile, or fall back to the passed-in resume
    private var enrichedResume: String {
        guard let profile = selectedProfile else { return resume }

        var parts: [String] = []

        let baseResume = profile.resumeText ?? resume
        if !baseResume.isEmpty { parts.append(baseResume) }

        var profileLines: [String] = []
        if let role = profile.currentRole, !role.isEmpty {
            var line = "Current role: \(role)"
            if let company = profile.currentCompany, !company.isEmpty { line += " at \(company)" }
            if let years = profile.yearsInRole, years > 0 { line += " (\(years) years)" }
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

        if !profile.workExperiences.isEmpty {
            let formatted = profile.workExperiences.prefix(5).map { e in
                let period = e.endYear.map { "\(e.startYear)-\($0)" } ?? "\(e.startYear)-present"
                var line = "- \(e.title) at \(e.company) (\(period))"
                if let desc = e.description, !desc.isEmpty { line += ": \(desc)" }
                return line
            }.joined(separator: "\n")
            parts.append("\nWORK HISTORY:\n\(formatted)")
        }

        if !profile.skills.isEmpty {
            let names = profile.skills.prefix(30).map(\.name).joined(separator: ", ")
            parts.append("\nSKILLS:\n\(names)")
        }

        if !profile.education.isEmpty {
            let formatted = profile.education.map { e in
                var line = "- \(e.degree)"
                if let field = e.field { line += " in \(field)" }
                line += " from \(e.institution)"
                return line
            }.joined(separator: "\n")
            parts.append("\nEDUCATION:\n\(formatted)")
        }

        if !profile.projects.isEmpty {
            let formatted = profile.projects.prefix(5).map { e in
                var line = "- \(e.name)"
                if let desc = e.description { line += ": \(desc)" }
                if let tech = e.techStack { line += " | Tech: \(tech)" }
                return line
            }.joined(separator: "\n")
            parts.append("\nKEY PROJECTS:\n\(formatted)")
        }

        if !profile.achievements.isEmpty {
            let formatted = profile.achievements.prefix(5).map { e in
                var line = "- \(e.description)"
                if let metric = e.metric { line += " — \(metric)" }
                return line
            }.joined(separator: "\n")
            parts.append("\nACHIEVEMENTS:\n\(formatted)")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Session Preparation

    private func startPracticeSession() {
        Task {
            isPreparingSession = true
            errorMessage = nil
            defer { isPreparingSession = false }

            guard hasVoicePrepAccess else {
                showPaywall = true
                return
            }

            // Ensure API keys are available
            await AuthService.shared.fetchAndStoreAPIKeys()

            guard let openAIKey = KeychainService.load(key: .openAIAPIKey),
                  !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                errorMessage = "Could not load API keys. Please try again."
                return
            }

            let sessionId = UUID()

            // Claim interview access
            do {
                _ = try await subscriptionService.claimInterviewAccess(
                    sessionClientId: sessionId,
                    sessionMode: .voicePrep
                )
            } catch {
                #if !DEBUG
                if let billingError = error as? BillingClientError {
                    errorMessage = billingError.localizedDescription
                    if case .paymentRequired = billingError { showPaywall = true }
                    if case .featureUnavailable = billingError { showPaywall = true }
                } else {
                    errorMessage = error.localizedDescription
                }
                return
                #endif
            }

            preparedSessionId = sessionId
            showPracticeSession = true
        }
    }

    private func buildViewModel(sessionId: UUID) -> PracticeInterviewViewModel {
        let openAIKey = KeychainService.load(key: .openAIAPIKey) ?? ""

        return PracticeInterviewViewModel(
            sessionId: sessionId,
            resume: enrichedResume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            jobListingUrl: jobListingUrl,
            profileId: selectedProfileId ?? initialProfileId,
            companyName: companyName,
            positionTitle: positionTitle,
            openAIKey: openAIKey
        )
    }
}

#Preview("Launch") {
    PracticeInterviewLaunchView(
        resume: "Sample resume with experience in iOS development",
        jobDescription: "ROLE TITLE: Senior iOS Engineer\nJOB CATEGORY: Software Engineering\nSTRUCTURED JOB REQUIREMENTS:\nCompany: Stripe\nLevel: Senior",
        interviewType: .behavioral,
        companyName: "Stripe",
        positionTitle: "Senior iOS Engineer"
    )
}
