import SwiftUI

struct PracticeInterviewLaunchView: View {
    @State private var subscriptionService = SubscriptionService.shared
    @State private var profileService = InterviewProfileService.shared
    @State private var showPracticeSession = false
    @State private var showPaywall = false
    @State private var isPreparingSession = false
    @State private var errorMessage: String?
    @State private var preparedSessionId: UUID?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // Session config — can be passed from a history item or directly
    let resume: String
    let jobDescription: String
    let interviewType: InterviewType
    let jobListingUrl: String?
    let profileId: String?
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
        self.profileId = profileId
        self.companyName = companyName
        self.positionTitle = positionTitle
    }

    /// Convenience init from a SessionHistoryItem for "Practice Again" flow.
    init(from session: SessionHistoryItem) {
        self.resume = session.jobDescription ?? ""
        self.jobDescription = session.jobDescription ?? ""
        self.interviewType = session.reviewInterviewType
        self.jobListingUrl = session.jobListingUrl
        self.profileId = session.profileId
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
            resume: resume,
            jobDescription: jobDescription,
            interviewType: interviewType,
            jobListingUrl: jobListingUrl,
            profileId: profileId,
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
