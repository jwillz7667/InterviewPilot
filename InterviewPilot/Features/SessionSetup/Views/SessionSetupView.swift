import SwiftUI
import UniformTypeIdentifiers

struct SessionSetupView: View {
    @State private var viewModel: SessionSetupViewModel
    @State private var showLiveSession = false
    @State private var showFilePicker = false
    @State private var showPaywall = false
    @State private var showResumeEditor = false
    @State private var showResumePreview = false
    @State private var showJobListingPreview = false
    @State private var preparedSessionId: UUID?
    @State private var subscriptionService = SubscriptionService.shared
    @Environment(\.colorScheme) private var colorScheme

    private let loadDefaultsOnTask: Bool
    private let twoColumnGrid = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top),
    ]

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
                    VStack(spacing: 18) {
                        topUtilityBar
                        dashboardHeader

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        setupCanvas
                    }
                    .padding(.horizontal, IATheme.spacing20)
                    .padding(.top, IATheme.spacing20)
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
            .sheet(isPresented: $showResumeEditor) {
                ResumeInputView(resumeText: $viewModel.resumeText)
            }
            .sheet(isPresented: $showResumePreview) {
                TextPreviewSheet(
                    title: "Resume Preview",
                    subtitle: viewModel.resumeStatusLabel,
                    text: viewModel.resumeText
                )
            }
            .sheet(isPresented: $showJobListingPreview) {
                TextPreviewSheet(
                    title: "Job Listing Preview",
                    subtitle: viewModel.jobListingStatusLabel,
                    text: viewModel.jobListingText
                )
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        viewModel.handleResumeFile(result: .success(url))
                    }
                case .failure(let error):
                    viewModel.handleResumeFile(result: .failure(error))
                }
            }
            .task {
                if loadDefaultsOnTask {
                    await viewModel.loadIfNeeded()
                }
            }
            .onChange(of: viewModel.resumeText) {
                viewModel.invalidatePreparedAnswerBankIfNeeded()
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
            .onChange(of: viewModel.responseQualityMode) {
                viewModel.invalidatePreparedAnswerBankIfNeeded()
            }
            .onChange(of: viewModel.additionalNotes) {
                viewModel.saveAdditionalNotes()
            }
        }
    }

    private var topUtilityBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                IABrandLogo(size: 38, showShadow: false, variant: .surface)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Interview Ace AI")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(IATheme.textPrimary)

                    Text("Prepare")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                if viewModel.hasResume {
                    IAUtilityCircleButton(symbol: "doc.text.magnifyingglass") {
                        showResumePreview = true
                    }
                }

                if viewModel.hasJobListing {
                    IAUtilityCircleButton(symbol: "link") {
                        showJobListingPreview = true
                    }
                }
            }
        }
    }

    private var dashboardHeader: some View {
        IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prepare")
                            .font(IATypography.labelSmall)
                            .foregroundStyle(IATheme.textSecondary)

                        Text("Interview Prep")
                            .font(IATypography.displayMedium)
                            .foregroundStyle(IATheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)
                    }

                    Spacer(minLength: 12)

                    if let entitlement = subscriptionService.currentEntitlement {
                        IAStatusPill(
                            title: entitlement.planTitle,
                            symbol: entitlement.sandboxFullAccess ? "checkmark.seal.fill" : "creditcard.fill",
                            tint: entitlement.sandboxFullAccess ? IATheme.success : IATheme.accent
                        )
                    }
                }

                Text("Upload your resume, analyze the role, confirm the setup, and launch from one grounded flow.")
                    .font(IATypography.bodyLarge)
                    .foregroundStyle(IATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    IAStatusPill(
                        title: launchReadinessTitle,
                        symbol: viewModel.isReady ? "checkmark.circle.fill" : "circle.dotted",
                        tint: viewModel.isReady ? IATheme.success : IATheme.textSecondary
                    )
                }
            }
        }
    }

    private var setupCanvas: some View {
        VStack(spacing: 16) {
            IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                uploadCard
            }

            IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                linkedInCard
            }

            IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                additionalNotesCard
            }

            IAPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                VStack(alignment: .leading, spacing: 22) {
                    listingCard
                    readinessSummaryStrip
                }
            }
        }
    }

    private var uploadCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(IATheme.accent.opacity(0.10))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: viewModel.hasResume ? "doc.text.fill" : "square.and.arrow.up.fill")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(IATheme.accent)
                    }

                Text(viewModel.hasResume ? "Resume Ready" : "Upload Your Resume")
                    .font(IATypography.headlineSmall)
                    .foregroundStyle(IATheme.textPrimary)

                Text(viewModel.hasResume ? viewModel.resumeStatusLabel : "Select a PDF or paste the full text so the interview can be grounded in your background.")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(IATheme.surfacePrimary)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .foregroundStyle(IATheme.borderColor(for: colorScheme))
            }

            if viewModel.hasResume {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        resumeActionButton(title: "Replace PDF", symbol: "doc.badge.plus") {
                            showFilePicker = true
                        }

                        resumeActionButton(title: "Edit Text", symbol: "square.and.pencil") {
                            showResumeEditor = true
                        }
                    }

                    resumeActionButton(title: "Preview Resume", symbol: "eye") {
                        showResumePreview = true
                    }
                }
            } else {
                HStack(spacing: 12) {
                    resumeActionButton(title: "Upload PDF", symbol: "doc.badge.plus") {
                        showFilePicker = true
                    }

                    resumeActionButton(title: "Paste Text", symbol: "square.and.pencil") {
                        showResumeEditor = true
                    }
                }
            }
        }
    }

    private var linkedInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            compactSectionTitle("LinkedIn Profile", detail: "Add your LinkedIn so the model knows what interviewers see about you.")

            VStack(spacing: 12) {
                // URL input
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IATheme.textSecondary)

                    TextField("linkedin.com/in/yourname", text: $viewModel.linkedInURL)
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .onSubmit {
                            Task { await viewModel.fetchLinkedInBasicInfo() }
                        }

                    if viewModel.isLoadingLinkedIn {
                        ProgressView()
                            .tint(IATheme.accent)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(IATheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(IATheme.borderColor(for: colorScheme), lineWidth: 1)
                }

                // Profile content text area
                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile Content")
                        .font(IATypography.labelSmall)
                        .foregroundStyle(IATheme.textSecondary)

                    Text("Copy your LinkedIn page text and paste it here (About, Experience, Education, Skills).")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.textSecondary)

                    TextEditor(text: $viewModel.linkedInProfileText)
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120, maxHeight: 200)
                        .padding(10)
                        .background(IATheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(IATheme.borderColor(for: colorScheme), lineWidth: 1)
                        }
                }

                // Action buttons
                HStack(spacing: 10) {
                    Button(action: {
                        if viewModel.linkedInProfileText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Task { await viewModel.fetchLinkedInBasicInfo() }
                        } else {
                            viewModel.analyzeLinkedInProfile()
                        }
                    }) {
                        Text(viewModel.hasLinkedInProfile ? "Re-analyze" : "Analyze Profile")
                    }
                    .buttonStyle(IASecondaryButtonStyle())
                    .disabled(
                        viewModel.isLoadingLinkedIn ||
                        (viewModel.linkedInURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         viewModel.linkedInProfileText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )

                    if viewModel.hasLinkedInProfile {
                        Button(action: { viewModel.clearLinkedInProfile() }) {
                            Text("Remove")
                        }
                        .buttonStyle(IASecondaryButtonStyle())
                    }
                }
            }

            if let profile = viewModel.linkedInProfile, !profile.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    infoBadge(title: profile.url, symbol: "link")

                    if let name = profile.name, !name.isEmpty {
                        Text(name)
                            .font(IATypography.labelSmall)
                            .foregroundStyle(IATheme.textPrimary)
                    }

                    if let headline = profile.headline, !headline.isEmpty {
                        Text(headline)
                            .font(IATypography.bodySmall)
                            .foregroundStyle(IATheme.textSecondary)
                    }

                    HStack(spacing: 8) {
                        if !profile.experience.isEmpty {
                            Text("\(profile.experience.count) roles")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.accent)
                        }
                        if !profile.skills.isEmpty {
                            Text("\(profile.skills.count) skills")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.accent)
                        }
                        if !profile.education.isEmpty {
                            Text("\(profile.education.count) education")
                                .font(IATypography.bodySmall)
                                .foregroundStyle(IATheme.accent)
                        }
                    }
                }
            } else {
                Text("Optional — ensures the model knows your full professional history in case interviewers reference your LinkedIn.")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
            }
        }
    }

    private var additionalNotesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            compactSectionTitle("Additional Notes", detail: "Anything else the model should know when generating your interview responses (e.g., specific projects to emphasize, topics to avoid, preferred answer style).")

            TextEditor(text: $viewModel.additionalNotes)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100, maxHeight: 180)
                .padding(10)
                .background(IATheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(IATheme.borderColor(for: colorScheme), lineWidth: 1)
                }
        }
    }

    private var listingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            compactSectionTitle("Job Listing URL", detail: "Paste a public role posting and analyze it inline.")

            VStack(spacing: 12) {
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
                .background(IATheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(IATheme.borderColor(for: colorScheme), lineWidth: 1)
                }

                Button(action: {
                    Task { await viewModel.analyzeJobListing() }
                }) {
                    Text(viewModel.hasJobListing ? "Refresh Analysis" : "Paste & Analyze")
                }
                .buttonStyle(IAPrimaryButtonStyle(isEnabled: !viewModel.isAnalyzingJobListing))
                .disabled(viewModel.isAnalyzingJobListing)
            }

            if viewModel.hasJobListing {
                if let host = URL(string: viewModel.jobListingURL)?.host {
                    infoBadge(title: host.replacingOccurrences(of: "www.", with: ""), symbol: "globe")
                }

                if let title = viewModel.jobListingTitle, !title.isEmpty {
                    Text(title)
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(IATheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Paste the public posting URL so Interview Ace AI can infer category, level, and role-specific language.")
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
            }
        }
    }

    private var readinessSummaryStrip: some View {
        LazyVGrid(columns: twoColumnGrid, spacing: 12) {
            summaryTile(
                title: "Role",
                value: viewModel.jobCategory?.displayName ?? "Pending",
                symbol: viewModel.jobCategory.map(jobCategoryIcon(for:)) ?? "briefcase.fill"
            )
            summaryTile(
                title: "Level",
                value: viewModel.positionLevel?.displayName ?? "Pending",
                symbol: viewModel.positionLevel.map(positionLevelIcon(for:)) ?? "arrow.up.right.circle"
            )
        }
    }

    private var prepBankCompactSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            compactSectionTitle("Prep Bank", detail: "Pre-generate reusable guidance before you launch.")

            Toggle(
                isOn: Binding(
                    get: { viewModel.shouldPreGenerate },
                    set: { enabled in
                        Task {
                            await viewModel.updateShouldPreGenerate(enabled)
                        }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-generate a prep bank")
                        .font(IATypography.headlineSmall)
                        .foregroundStyle(IATheme.insetSurfacePrimaryText(for: colorScheme))

                    Text("When enabled, the app builds likely questions and ready-to-use answer scaffolds.")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(IATheme.insetSurfaceSecondaryText(for: colorScheme))
                }
            }
            .tint(IATheme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .iaInsetSurface(cornerRadius: 22)

            if viewModel.shouldPreGenerate {
                PreGenerationView(
                    progress: viewModel.preGenerationProgress,
                    answers: viewModel.preparedAnswers,
                    isGenerating: viewModel.isGeneratingAnswerBank
                )

                if viewModel.isReady && !viewModel.isGeneratingAnswerBank && !viewModel.hasPreparedAnswers {
                    Button(action: {
                        Task { await viewModel.generatePreparedAnswers(force: true) }
                    }) {
                        Label("Generate Prep Now", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(IASecondaryButtonStyle())
                }

                Text(viewModel.prepSummary)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
            }
        }
    }

    private func compactSectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(IATypography.headlineSmall)
                .foregroundStyle(IATheme.textPrimary)

            Text(detail)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var launchSection: some View {
        IABottomDock {
            VStack(alignment: .leading, spacing: 10) {
                Text(startSummary)
                    .font(IATypography.bodySmall)
                    .foregroundStyle(IATheme.textSecondary)
                    .lineLimit(2)

                Button(action: startSession) {
                    HStack(spacing: 10) {
                        if viewModel.isPreparingSession {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "mic.fill")
                        }

                        Text(viewModel.isPreparingSession ? "Preparing Session" : "Start Interview Session")
                    }
                }
                .buttonStyle(IAPrimaryButtonStyle(isEnabled: viewModel.isReady && !viewModel.isPreparingSession))
                .disabled(!viewModel.isReady || viewModel.isPreparingSession)
            }
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

    private func summaryTile(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(IATheme.accent)

            Text(title)
                .font(IATypography.labelSmall)
                .foregroundStyle(IATheme.textSecondary)

            Text(value)
                .font(IATypography.bodyMedium)
                .foregroundStyle(IATheme.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .iaInsetSurface(cornerRadius: 22)
    }

    private func infoBadge(title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(IATypography.labelSmall)
                .lineLimit(1)
        }
        .foregroundStyle(IATheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(IATheme.accent.opacity(0.10), in: Capsule())
    }

    private func resumeActionButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(IATheme.textPrimary)
                    .frame(width: 18, height: 18)

                Text(title)
                    .font(IATypography.bodyLarge)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(IATheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(IATheme.borderColor(for: colorScheme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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

    private var startSummary: String {
        if !viewModel.hasResume {
            return "Add your resume to unlock role-specific guidance."
        }

        if !viewModel.hasJobListing {
            return "Paste and analyze a public job listing URL to continue."
        }

        if viewModel.isPreparingSession {
            return "Validating access, loading runtime keys, and preparing session assets."
        }

        if viewModel.shouldPreGenerate {
            return viewModel.prepSummary
        }

        if viewModel.responseQualityMode == .premium {
            return "Top Tier mode will use stronger models and sharper interview framing."
        }

        if let entitlement = subscriptionService.currentEntitlement {
            return entitlement.statusDetail
        }

        return "Everything is ready."
    }

    private var launchReadinessTitle: String {
        viewModel.isReady ? "Ready to launch" : "Setup incomplete"
    }

    private func selectResponseQualityMode(_ mode: ResponseQualityMode, isLocked: Bool) {
        if isLocked {
            viewModel.errorMessage = "Top Tier mode requires an active Pro subscription."
            showPaywall = true
            return
        }

        withAnimation(IAAnimations.snappy) {
            viewModel.responseQualityMode = mode
        }
    }

    private func jobCategoryIcon(for category: JobCategory) -> String {
        switch category {
        case .softwareEngineering:
            return "terminal.fill"
        case .dataAI:
            return "cpu.fill"
        case .product:
            return "shippingbox.fill"
        case .design:
            return "paintbrush.pointed.fill"
        case .operations:
            return "gearshape.2.fill"
        case .salesCustomer:
            return "person.2.fill"
        case .marketing:
            return "megaphone.fill"
        case .financeStrategy:
            return "chart.line.uptrend.xyaxis"
        case .peopleHR:
            return "person.3.fill"
        case .generalBusiness:
            return "briefcase.fill"
        }
    }

    private func positionLevelIcon(for level: PositionLevel) -> String {
        switch level {
        case .entryLevel:
            return "figure.walk"
        case .midLevel:
            return "arrow.up.right.circle.fill"
        case .seniorIndividualContributor:
            return "star.fill"
        case .management:
            return "person.2.wave.2.fill"
        case .seniorManagement:
            return "building.2.fill"
        case .executive:
            return "crown.fill"
        }
    }

    private func responseQualityIcon(for mode: ResponseQualityMode, isLocked: Bool) -> String {
        if isLocked {
            return "lock.fill"
        }

        switch mode {
        case .standard:
            return "dial.medium.fill"
        case .premium:
            return "sparkles"
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
    viewModel.preparedAnswers = ready
        ? [
            PreComputedAnswer(question: "Tell me about a difficult team situation.", response: "Sample", type: .behavioral),
            PreComputedAnswer(question: "How do you ship performant SwiftUI screens?", response: "Sample", type: .technical),
        ]
        : []
    return viewModel
}
