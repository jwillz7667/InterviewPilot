import SwiftUI
import UniformTypeIdentifiers

struct SessionSetupView: View {
    @State private var viewModel: SessionSetupViewModel
    @State private var showLiveSession = false
    @State private var showPaywall = false
    @State private var paywallReason: SubscriptionPaywallView.PaywallReason = .upgradeBrowse
    @State private var preparedSessionId: UUID?
    @State private var subscriptionService = SubscriptionService.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    private let loadDefaultsOnTask: Bool

    init(
        viewModel: SessionSetupViewModel = SessionSetupViewModel(),
        loadDefaultsOnTask: Bool = true
    ) {
        _viewModel = State(initialValue: viewModel)
        self.loadDefaultsOnTask = loadDefaultsOnTask
    }

    var body: some View {
        NavigationStack {
            ZStack {
                IAAppBackground()

                ScrollView {
                    VStack(spacing: IATheme.spacing24) {
                        headerSection
                        UpgradeBannerView { showPaywall = true }
                        profileSelectorSection
                        heroImageSection
                        jobListingSection
                        customContextSection
                        qualityPickerSection

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        infoCardsSection
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.top, IATheme.spacing16)
                    .padding(.bottom, 140)
                }
                .iaScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                launchSection
                    .padding(.horizontal, IATheme.spacing16)
                    .padding(.bottom, IATheme.spacing8)
            }
            .fullScreenCover(isPresented: $showLiveSession) {
                if let preparedSessionId {
                    LiveSessionView(viewModel: viewModel.createLiveViewModel(sessionId: preparedSessionId))
                }
            }
            .sheet(isPresented: $showPaywall) {
                SubscriptionPaywallView(reason: paywallReason)
            }
            .task {
                if loadDefaultsOnTask {
                    await viewModel.loadIfNeeded()
                }
            }
            .onChange(of: viewModel.jobListingURL) {
                viewModel.handleJobListingURLChange()
            }
            .onChange(of: viewModel.jobListingText) {
                viewModel.invalidatePreparedAnswerBankIfNeeded()
            }
            .onChange(of: viewModel.jobCategory) {
                viewModel.interviewType = viewModel.derivedProfile.interviewType
                viewModel.invalidatePreparedAnswerBankIfNeeded()
            }
            .onChange(of: viewModel.positionLevel) {
                viewModel.interviewType = viewModel.derivedProfile.interviewType
                viewModel.invalidatePreparedAnswerBankIfNeeded()
            }
        }
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

            Text("Set Up Your\nInterview Session")
                .font(IATypography.displayMedium)
                .foregroundStyle(IATheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Configure your session and start practicing with AI guidance.")
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Profile Selector

    @ViewBuilder
    private var profileSelectorSection: some View {
        let hasFeature = subscriptionService.currentEntitlement?.hasResumePersonalization == true

        if hasFeature {
            if !viewModel.availableProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Interview Profile")
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.textPrimary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.availableProfiles) { profile in
                                let isSelected = viewModel.selectedProfileId == profile.id
                                Button {
                                    Task { await viewModel.selectProfile(profile.id) }
                                } label: {
                                    Text(profile.name)
                                        .font(IATypography.labelMedium)
                                        .foregroundStyle(isSelected ? .white : IATheme.textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(
                                            isSelected ? IATheme.accent : IATheme.surfaceWhite,
                                            in: Capsule()
                                        )
                                        .overlay {
                                            Capsule().stroke(isSelected ? Color.clear : IATheme.outlineVariant, lineWidth: 1)
                                        }
                                }
                            }
                        }
                    }

                    if let profile = viewModel.selectedProfile {
                        let subtitle = [profile.currentRole, profile.currentCompany]
                            .compactMap { $0 }
                            .filter { !$0.isEmpty }
                            .joined(separator: " at ")
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.textSecondary)
                        }
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(IATheme.accent.opacity(0.10))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "person.crop.rectangle.stack")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(IATheme.accent)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Interview Profiles")
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(IATheme.textPrimary)

                        Text("Create a profile for more personalized responses.")
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
    }

    // MARK: - Hero Image

    private var heroImageSection: some View {
        RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [IATheme.primaryContainer.opacity(0.2), IATheme.accent.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 160)
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "person.bust.fill")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(IATheme.accent.opacity(0.6))

                    Text("Ready when you are")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }
    }

    // MARK: - Job Listing URL

    private var jobListingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Job Listing URL")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(IATheme.textSecondary)

                TextField("https://company.com/jobs/role", text: $viewModel.jobListingURL)
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.textPrimary)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit {
                        Task { await viewModel.analyzeJobListing() }
                    }

                if viewModel.isAnalyzingJobListing {
                    ProgressView()
                        .tint(IATheme.accent)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                    .stroke(IATheme.outlineVariant, lineWidth: 1)
            }

            if viewModel.hasJobListing {
                jobListingSummaryCard
            }
        }
    }

    // MARK: - Custom Context

    private var customContextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom Context")
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            Text("Anything specific the AI should know for this session.")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textSecondary)

            TextEditor(text: $viewModel.additionalNotes)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100, maxHeight: 160)
                .padding(12)
                .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                        .stroke(IATheme.outlineVariant, lineWidth: 1)
                }
        }
    }

    // MARK: - Quality Picker

    private var qualityPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Interview Engine")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)
                Spacer()
            }

            VStack(spacing: 10) {
                qualityCard(quality: .standard)
                qualityCard(quality: .premium)
            }
        }
    }

    private func qualityCard(quality: InterviewQuality) -> some View {
        let window = quotaWindow(for: quality)
        let isSelected = viewModel.selectedQuality == quality
        let isDisabled = !canSelect(quality: quality, window: window)
        let accentTint = quality == .premium ? IATheme.tertiary : IATheme.accent

        return Button {
            handleQualityTap(quality: quality, window: window)
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .fill(accentTint.opacity(0.12))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: quality == .premium ? "sparkles" : "bolt.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentTint)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(quality.displayName)
                            .font(IATypography.headlineSmall)
                            .foregroundStyle(IATheme.textPrimary)
                        if quality == .premium {
                            Text("PRO")
                                .font(IATypography.labelSmall.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(accentTint, in: Capsule())
                        }
                    }
                    Text(quality.subtitle)
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                    Text(quotaLabel(for: quality, window: window))
                        .font(IATypography.labelMedium)
                        .foregroundStyle(isDisabled ? IATheme.error : IATheme.textTertiary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? accentTint : IATheme.outlineVariant)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(IATheme.surfaceWhite, in: RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: IATheme.radiusLarge, style: .continuous)
                    .stroke(isSelected ? accentTint : IATheme.outlineVariant, lineWidth: isSelected ? 2 : 1)
            }
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(quality.displayName) interview engine")
        .accessibilityHint(isDisabled ? "Quota exhausted — tap to upgrade" : quality.subtitle)
    }

    private func quotaWindow(for quality: InterviewQuality) -> QuotaWindow? {
        switch quality {
        case .standard: return subscriptionService.currentEntitlement?.quotas.standard
        case .premium:  return subscriptionService.currentEntitlement?.quotas.premium
        }
    }

    private func quotaLabel(for quality: InterviewQuality, window: QuotaWindow?) -> String {
        guard let window else {
            return quality == .premium ? "Premium AI engine" : "Standard AI engine"
        }
        if window.isUnlimited {
            return "Unlimited this month"
        }
        if window.remaining <= 0 {
            return "Used \(window.used) of \(window.limit) this month"
        }
        return "\(window.remaining) of \(window.limit) left this month"
    }

    private func canSelect(quality: InterviewQuality, window: QuotaWindow?) -> Bool {
        guard let window else { return true } // entitlement still loading; let backend gate
        if window.isUnlimited { return true }
        return window.remaining > 0
    }

    private func handleQualityTap(quality: InterviewQuality, window: QuotaWindow?) {
        if canSelect(quality: quality, window: window) {
            viewModel.selectedQuality = quality
        } else {
            paywallReason = quality == .premium ? .premiumExhausted : .standardExhausted
            showPaywall = true
        }
    }

    // MARK: - Info Cards

    private var infoCardsSection: some View {
        VStack(spacing: 12) {
            infoCard(
                icon: "doc.text.fill",
                title: "Resume loaded from profile",
                detail: viewModel.hasResume ? "Your resume is ready for this session." : "Add a resume in your profile for better responses."
            )

            infoCard(
                icon: "sparkles",
                title: "AI-powered guidance",
                detail: "Get real-time response suggestions during your interview."
            )
        }
    }

    private func infoCard(icon: String, title: String, detail: String) -> some View {
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
            Button(action: startSession) {
                HStack(spacing: 10) {
                    if viewModel.isPreparingSession {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "mic.fill")
                    }

                    Text(viewModel.isPreparingSession ? "Preparing Session" : "Start Session")
                }
            }
            .buttonStyle(IAPrimaryButtonStyle(isEnabled: viewModel.isReady && !viewModel.isPreparingSession))
            .disabled(!viewModel.isReady || viewModel.isPreparingSession)

            Button(action: {
                viewModel.saveDraft()
                dismiss()
            }) {
                Text("Save for later")
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

    private var jobListingSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(IATheme.success)
                Text(viewModel.jobListingTitle ?? "Job listing analyzed")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(2)
            }

            if let reqs = viewModel.structuredJobRequirements {
                VStack(alignment: .leading, spacing: 6) {
                    if let company = reqs.companyName, !company.isEmpty {
                        summaryRow(label: "Company", value: company)
                    }
                    if let category = viewModel.jobCategory {
                        summaryRow(label: "Category", value: category.displayName)
                    }
                    if let level = viewModel.positionLevel {
                        summaryRow(label: "Level", value: level.displayName)
                    }
                    if !reqs.requiredTechStack.isEmpty {
                        summaryRow(label: "Tech", value: reqs.requiredTechStack.prefix(5).joined(separator: ", "))
                    }
                    if let arrangement = reqs.workArrangement, !arrangement.isEmpty {
                        summaryRow(label: "Work", value: arrangement)
                    }
                }
            }

            Text("Context loaded — ready to start your session.")
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(IATheme.success.opacity(0.06), in: RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                .stroke(IATheme.success.opacity(0.25), lineWidth: 1)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textSecondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(IATypography.bodySmall)
                .foregroundStyle(IATheme.textPrimary)
                .lineLimit(2)
        }
    }

    private func errorBanner(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(IATypography.bodySmall)
            .foregroundStyle(IATheme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(IATheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func startSession() {
        Task {
            let sessionId = await viewModel.prepareSession()
            if viewModel.shouldPresentPaywall {
                // The VM already filtered down to a `.paymentRequired` /
                // `.featureUnavailable` outcome — pick the reason that matches
                // the quality the user just tried to claim.
                paywallReason = viewModel.selectedQuality == .premium
                    ? .premiumExhausted
                    : .standardExhausted
                showPaywall = true
            }

            if let sessionId {
                preparedSessionId = sessionId
                showLiveSession = true
            }
        }
    }
}

#Preview("Setup Empty") {
    SessionSetupView(viewModel: previewSetupViewModel(ready: false), loadDefaultsOnTask: false)
}

#Preview("Setup Ready") {
    SessionSetupView(viewModel: previewSetupViewModel(ready: true), loadDefaultsOnTask: false)
}

private func previewSetupViewModel(ready: Bool) -> SessionSetupViewModel {
    let viewModel = SessionSetupViewModel()
    viewModel.resumeText = ready ? "Sample resume text" : ""
    viewModel.resumeDocumentName = ready ? "Resume.pdf" : nil
    viewModel.jobListingURL = ready ? "https://jobs.example.com/ios-engineer" : ""
    viewModel.jobListingTitle = ready ? "Senior iOS Engineer" : nil
    viewModel.jobListingText = ready ? "Build native iOS experiences and lead platform quality." : ""
    viewModel.jobCategory = ready ? .softwareEngineering : nil
    viewModel.positionLevel = ready ? .seniorIndividualContributor : nil
    viewModel.responseFormat = .hybrid
    viewModel.responseQualityMode = .premium
    return viewModel
}
