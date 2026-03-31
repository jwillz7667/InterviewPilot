import SwiftUI
import UniformTypeIdentifiers

struct SessionSetupView: View {
    @State private var viewModel: SessionSetupViewModel
    @State private var showLiveSession = false
    @State private var showPaywall = false
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
                        heroImageSection
                        jobListingSection
                        customContextSection

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
                SubscriptionPaywallView()
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
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(IATheme.success)
                    Text(viewModel.jobListingTitle ?? "Job listing analyzed")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textPrimary)
                }
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

            Button(action: { dismiss() }) {
                Text("Save for later")
                    .font(IATypography.bodyMedium)
                    .foregroundStyle(IATheme.accent)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
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
            showPaywall = viewModel.shouldPresentPaywall

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
