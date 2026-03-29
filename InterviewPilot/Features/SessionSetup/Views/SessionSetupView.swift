import SwiftUI
import UniformTypeIdentifiers

struct SessionSetupView: View {
    @State private var viewModel: SessionSetupViewModel
    @State private var showLiveSession = false
    @State private var showPrepSession = false
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
    private let singleColumnGrid = [
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]
    private let threeColumnGrid = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
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
                IPAppBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        topUtilityBar
                        dashboardHeader

                        if let error = viewModel.errorMessage {
                            errorBanner(error)
                        }

                        setupCanvas
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.top, IPTheme.spacing20)
                    .padding(.bottom, 44)
                }
                .ipScrollablePage()
            }
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showLiveSession) {
                if let preparedSessionId {
                    LiveSessionView(viewModel: viewModel.createLiveViewModel(sessionId: preparedSessionId))
                }
            }
            .fullScreenCover(isPresented: $showPrepSession) {
                if let preparedSessionId {
                    PrepSessionView(viewModel: viewModel.createPrepViewModel(sessionId: preparedSessionId))
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
        }
    }

    private var topUtilityBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                IPBrandLogo(size: 38, showShadow: false, variant: .surface)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Job Hopper")
                        .font(IPTypography.labelLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    Text("Prepare")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                if viewModel.hasResume {
                    IPUtilityCircleButton(symbol: "doc.text.magnifyingglass") {
                        showResumePreview = true
                    }
                }

                if viewModel.hasJobListing {
                    IPUtilityCircleButton(symbol: "link") {
                        showJobListingPreview = true
                    }
                }
            }
        }
    }

    private var dashboardHeader: some View {
        IPPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prepare")
                            .font(IPTypography.labelSmall)
                            .foregroundStyle(IPTheme.textSecondary)

                        Text("Interview Prep")
                            .font(IPTypography.displayMedium)
                            .foregroundStyle(IPTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.88)
                    }

                    Spacer(minLength: 12)

                    if let entitlement = subscriptionService.currentEntitlement {
                        IPStatusPill(
                            title: entitlement.planTitle,
                            symbol: entitlement.sandboxFullAccess ? "checkmark.seal.fill" : "creditcard.fill",
                            tint: entitlement.sandboxFullAccess ? IPTheme.success : IPTheme.accent
                        )
                    }
                }

                Text("Upload your resume, analyze the role, confirm the setup, and launch from one grounded flow.")
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    IPStatusPill(title: viewModel.sessionMode.displayName, symbol: viewModel.sessionMode.icon)
                    IPStatusPill(
                        title: launchReadinessTitle,
                        symbol: viewModel.isReady ? "checkmark.circle.fill" : "circle.dotted",
                        tint: viewModel.isReady ? IPTheme.success : IPTheme.textSecondary
                    )
                }
            }
        }
    }

    private var inferenceSummary: some View {
        LazyVGrid(columns: threeColumnGrid, spacing: 12) {
            summaryTile(
                title: "Format",
                value: viewModel.responseFormat.displayName,
                symbol: "text.justify.left"
            )
        }
    }

    private var setupCanvas: some View {
        VStack(spacing: 16) {
            IPPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                VStack(alignment: .leading, spacing: 22) {
                    uploadCard
                    Divider()
                        .overlay(IPTheme.borderColor(for: colorScheme))
                    githubCard
                    Divider()
                        .overlay(IPTheme.borderColor(for: colorScheme))
                    linkedInCard
                    Divider()
                        .overlay(IPTheme.borderColor(for: colorScheme))
                    listingCard
                    readinessSummaryStrip
                }
            }

            IPPanel(tone: .secondary, padding: 22, cornerRadius: 30) {
                VStack(alignment: .leading, spacing: 18) {
                    compactSectionTitle("Session configuration", detail: "Use clear grouped controls so the interview mode and answer style are easy to verify at a glance.")

                    VStack(alignment: .leading, spacing: 16) {
                        compactSectionTitle("Interview mode", detail: "Choose how Job Hopper should run this session.")
                        VStack(spacing: 12) {
                            ForEach(SessionMode.allCases) { mode in
                                let isLocked = mode == .voicePrep && !(subscriptionService.currentEntitlement?.hasVoicePrep ?? false)
                                modeCard(mode, isLocked: isLocked)
                            }
                        }
                    }

                    responseLayoutSection
                }
            }

            launchSection
        }
    }

    private var uploadCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(IPTheme.accent.opacity(0.10))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: viewModel.hasResume ? "doc.text.fill" : "square.and.arrow.up.fill")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(IPTheme.accent)
                    }

                Text(viewModel.hasResume ? "Resume Ready" : "Upload Your Resume")
                    .font(IPTypography.headlineSmall)
                    .foregroundStyle(IPTheme.textPrimary)

                Text(viewModel.hasResume ? viewModel.resumeStatusLabel : "Select a PDF or paste the full text so the interview can be grounded in your background.")
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(IPTheme.surfacePrimary)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                    .foregroundStyle(IPTheme.borderColor(for: colorScheme))
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

    private var githubCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            compactSectionTitle("GitHub Profile", detail: "Link your GitHub so responses can reference your real projects.")

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(IPTheme.textSecondary)

                    TextField("username or github.com/username", text: $viewModel.githubUsername)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(IPTheme.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit {
                            Task { await viewModel.fetchGitHubProfile() }
                        }

                    if viewModel.isLoadingGitHub {
                        ProgressView()
                            .tint(IPTheme.accent)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(IPTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
                }

                HStack(spacing: 10) {
                    Button(action: {
                        Task { await viewModel.fetchGitHubProfile() }
                    }) {
                        Text(viewModel.hasGitHubProfile ? "Refresh" : "Link GitHub")
                    }
                    .buttonStyle(IPSecondaryButtonStyle())
                    .disabled(viewModel.isLoadingGitHub || viewModel.githubUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if viewModel.hasGitHubProfile {
                        Button(action: { viewModel.clearGitHubProfile() }) {
                            Text("Remove")
                        }
                        .buttonStyle(IPSecondaryButtonStyle())
                    }
                }
            }

            if let profile = viewModel.githubProfile {
                VStack(alignment: .leading, spacing: 10) {
                    infoBadge(title: "github.com/\(profile.username)", symbol: "link")

                    if !profile.primaryLanguages.isEmpty {
                        Text(profile.primaryLanguages.prefix(4).joined(separator: " · "))
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                    }

                    Text("Select up to 3 repos to feature in responses (\(viewModel.selectedRepoNames.count)/3)")
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(IPTheme.accent)

                    VStack(spacing: 6) {
                        ForEach(profile.topRepos.prefix(10)) { repo in
                            Button(action: { viewModel.toggleRepoSelection(repo.name) }) {
                                HStack(spacing: 10) {
                                    Image(systemName: viewModel.isRepoSelected(repo.name)
                                          ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(viewModel.isRepoSelected(repo.name)
                                                         ? IPTheme.accent : IPTheme.textSecondary)
                                        .font(.system(size: 18))

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(repo.name)
                                                .font(IPTypography.labelSmall)
                                                .foregroundStyle(IPTheme.textPrimary)
                                                .lineLimit(1)

                                            if let lang = repo.language {
                                                Text(lang)
                                                    .font(IPTypography.bodySmall)
                                                    .foregroundStyle(IPTheme.accent)
                                            }

                                            if repo.stars > 0 {
                                                Label("\(repo.stars)", systemImage: "star.fill")
                                                    .font(IPTypography.bodySmall)
                                                    .foregroundStyle(IPTheme.textSecondary)
                                            }
                                        }

                                        if let desc = repo.description, !desc.isEmpty {
                                            Text(desc)
                                                .font(IPTypography.bodySmall)
                                                .foregroundStyle(IPTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(viewModel.isRepoSelected(repo.name)
                                              ? IPTheme.accent.opacity(0.08)
                                              : Color.clear)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!viewModel.isRepoSelected(repo.name) && viewModel.selectedRepoNames.count >= 3)
                            .opacity(!viewModel.isRepoSelected(repo.name) && viewModel.selectedRepoNames.count >= 3 ? 0.4 : 1.0)
                        }
                    }
                }
            } else {
                Text("Optional — adds real project context from your repos to make interview responses more specific.")
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
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
                        .foregroundStyle(IPTheme.textSecondary)

                    TextField("linkedin.com/in/yourname", text: $viewModel.linkedInURL)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(IPTheme.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .submitLabel(.go)
                        .onSubmit {
                            Task { await viewModel.fetchLinkedInBasicInfo() }
                        }

                    if viewModel.isLoadingLinkedIn {
                        ProgressView()
                            .tint(IPTheme.accent)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(IPTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
                }

                // Profile content text area
                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile Content")
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(IPTheme.textSecondary)

                    Text("Copy your LinkedIn page text and paste it here (About, Experience, Education, Skills).")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)

                    TextEditor(text: $viewModel.linkedInProfileText)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(IPTheme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120, maxHeight: 200)
                        .padding(10)
                        .background(IPTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
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
                    .buttonStyle(IPSecondaryButtonStyle())
                    .disabled(
                        viewModel.isLoadingLinkedIn ||
                        (viewModel.linkedInURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                         viewModel.linkedInProfileText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    )

                    if viewModel.hasLinkedInProfile {
                        Button(action: { viewModel.clearLinkedInProfile() }) {
                            Text("Remove")
                        }
                        .buttonStyle(IPSecondaryButtonStyle())
                    }
                }
            }

            if let profile = viewModel.linkedInProfile, !profile.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    infoBadge(title: profile.url, symbol: "link")

                    if let name = profile.name, !name.isEmpty {
                        Text(name)
                            .font(IPTypography.labelSmall)
                            .foregroundStyle(IPTheme.textPrimary)
                    }

                    if let headline = profile.headline, !headline.isEmpty {
                        Text(headline)
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                    }

                    HStack(spacing: 8) {
                        if !profile.experience.isEmpty {
                            Text("\(profile.experience.count) roles")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.accent)
                        }
                        if !profile.skills.isEmpty {
                            Text("\(profile.skills.count) skills")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.accent)
                        }
                        if !profile.education.isEmpty {
                            Text("\(profile.education.count) education")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.accent)
                        }
                    }
                }
            } else {
                Text("Optional — ensures the model knows your full professional history in case interviewers reference your LinkedIn.")
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
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
                        .foregroundStyle(IPTheme.textSecondary)

                    TextField("https://company.com/jobs/role", text: $viewModel.jobListingURL)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(IPTheme.textPrimary)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit {
                            Task { await viewModel.analyzeJobListing() }
                        }

                    if viewModel.isAnalyzingJobListing {
                        ProgressView()
                            .tint(IPTheme.accent)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(IPTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
                }

                Button(action: {
                    Task { await viewModel.analyzeJobListing() }
                }) {
                    Text(viewModel.hasJobListing ? "Refresh Analysis" : "Paste & Analyze")
                }
                .buttonStyle(IPPrimaryButtonStyle(isEnabled: !viewModel.isAnalyzingJobListing))
                .disabled(viewModel.isAnalyzingJobListing)
            }

            if viewModel.hasJobListing {
                if let host = URL(string: viewModel.jobListingURL)?.host {
                    infoBadge(title: host.replacingOccurrences(of: "www.", with: ""), symbol: "globe")
                }

                if let title = viewModel.jobListingTitle, !title.isEmpty {
                    Text(title)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(IPTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Paste the public posting URL so Job Hopper can infer category, level, and role-specific language.")
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
            }
        }
    }

    private var readinessSummaryStrip: some View {
        LazyVGrid(columns: twoColumnGrid, spacing: 12) {
            summaryTile(
                title: "Interview",
                value: viewModel.interviewType.displayName,
                symbol: "person.fill.questionmark"
            )
            summaryTile(
                title: "Format",
                value: viewModel.responseFormat.displayName,
                symbol: "text.justify.left"
            )
        }
    }

    private var responseLayoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactSectionTitle("Answer Layout", detail: "Choose the structure you want pinned during the interview.")

            VStack(spacing: 12) {
                ForEach(ResponseFormat.allCases, id: \.self) { format in
                    Button(action: {
                        withAnimation(IPAnimations.snappy) {
                            viewModel.responseFormat = format
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: "text.justify.left")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(viewModel.responseFormat == format ? Color.white : IPTheme.insetSurfacePrimaryText(for: colorScheme))

                                Text(format.displayName)
                                    .font(IPTypography.bodyLarge)
                                    .foregroundStyle(viewModel.responseFormat == format ? Color.white : IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.88)

                                Spacer()

                                Image(systemName: viewModel.responseFormat == format ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(
                                        viewModel.responseFormat == format
                                            ? Color.white
                                            : IPTheme.insetSurfaceTertiaryText(for: colorScheme)
                                    )
                            }

                            Text(format.description)
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(viewModel.responseFormat == format ? Color.white : IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .ipInsetSurface(selected: viewModel.responseFormat == format, cornerRadius: 20)
                    }
                    .buttonStyle(.plain)
                }
            }
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
                        .font(IPTypography.headlineSmall)
                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))

                    Text("When enabled, the app builds likely questions and ready-to-use answer scaffolds.")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                }
            }
            .tint(IPTheme.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .ipInsetSurface(cornerRadius: 22)

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
                    .buttonStyle(IPSecondaryButtonStyle())
                }

                Text(viewModel.prepSummary)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
            }
        }
    }

    private func compactSectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(IPTypography.headlineSmall)
                .foregroundStyle(IPTheme.textPrimary)

            Text(detail)
                .font(IPTypography.bodyMedium)
                .foregroundStyle(IPTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var targetingSection: some View {
        IPPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 18) {
                IPSectionHeader(
                    eyebrow: "Tuning",
                    title: "Confirm the role targeting",
                    subtitle: "Keep the controls compact, readable, and easy to adjust before you launch into a real or mock interview.",
                    symbol: "slider.horizontal.3"
                )

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("Mode")
                    HStack(spacing: 12) {
                        ForEach(SessionMode.allCases) { mode in
                            let isLocked = mode == .voicePrep && !(subscriptionService.currentEntitlement?.hasVoicePrep ?? false)
                            modeCard(mode, isLocked: isLocked)
                        }
                    }
                }

                optionGroup(
                    title: "Answer mode",
                    detail: viewModel.responseQualityMode.description
                ) {
                    ForEach(ResponseQualityMode.allCases) { mode in
                        let isLocked = mode.requiresPriorityModels && !(subscriptionService.currentEntitlement?.hasPriorityModels ?? false)
                        selectionChip(
                            title: mode.displayName,
                            symbol: responseQualityIcon(for: mode, isLocked: isLocked),
                            isSelected: viewModel.responseQualityMode == mode,
                            isLocked: isLocked
                        ) {
                            selectResponseQualityMode(mode, isLocked: isLocked)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    sectionLabel("Answer layout")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(ResponseFormat.allCases, id: \.self) { format in
                            Button(action: {
                                withAnimation(IPAnimations.snappy) {
                                    viewModel.responseFormat = format
                                }
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(format.displayName)
                                            .font(IPTypography.bodyLarge)
                                            .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))

                                        Spacer()

                                        Image(systemName: viewModel.responseFormat == format ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(
                                                viewModel.responseFormat == format
                                                    ? IPTheme.accent
                                                    : IPTheme.insetSurfaceTertiaryText(for: colorScheme)
                                            )
                                    }

                                    Text(format.description)
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                                .padding(16)
                                .ipInsetSurface(selected: viewModel.responseFormat == format, cornerRadius: 22)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var prepBankSection: some View {
        IPPanel(tone: .primary, padding: 22, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 16) {
                IPSectionHeader(
                    eyebrow: "Optional",
                    title: "Prep bank",
                    subtitle: "Generate likely questions and reusable response scaffolds before launch for faster on-call assistance.",
                    symbol: "sparkles.rectangle.stack"
                )

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
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))

                        Text("When enabled, the app reuses or builds personalized prep assets before launch.")
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                    }
                }
                .tint(IPTheme.accent)
                .padding(16)
                .ipInsetSurface(cornerRadius: 22)

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
                        .buttonStyle(IPSecondaryButtonStyle())
                    }
                }

                Text(viewModel.prepSummary)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
            }
        }
    }

    private var launchSection: some View {
        IPPanel(tone: .secondary, padding: 20, cornerRadius: 30) {
            VStack(alignment: .leading, spacing: 14) {
                compactSectionTitle("Launch Session", detail: startSummary)

                if !viewModel.isReady {
                    Text("Complete the resume upload and job listing analysis before starting.")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }

                Button(action: startSession) {
                    HStack(spacing: 10) {
                        if viewModel.isPreparingSession {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: viewModel.sessionMode == .liveInterview ? "mic.fill" : "person.wave.2.fill")
                        }

                        Text(viewModel.isPreparingSession ? "Preparing Session" : viewModel.sessionMode.startButtonTitle)
                    }
                }
                .buttonStyle(IPPrimaryButtonStyle(isEnabled: viewModel.isReady && !viewModel.isPreparingSession))
                .disabled(!viewModel.isReady || viewModel.isPreparingSession)
            }
        }
    }

    private func errorBanner(_ error: String) -> some View {
        Label(error, systemImage: "exclamationmark.triangle.fill")
            .font(IPTypography.bodySmall)
            .foregroundStyle(IPTheme.error)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func summaryTile(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(IPTheme.accent)

            Text(title)
                .font(IPTypography.labelSmall)
                .foregroundStyle(IPTheme.textSecondary)

            Text(value)
                .font(IPTypography.bodyMedium)
                .foregroundStyle(IPTheme.textPrimary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(14)
        .ipInsetSurface(cornerRadius: 22)
    }

    private func optionGroup<Content: View>(
        title: String,
        detail: String,
        columns: [GridItem]? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            compactSectionTitle(title, detail: detail)

            LazyVGrid(columns: columns ?? twoColumnGrid, spacing: 12) {
                content()
            }
        }
    }

    private func modeCard(_ mode: SessionMode, isLocked: Bool) -> some View {
        Button(action: { selectSessionMode(mode, isLocked: isLocked) }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: mode.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(
                            viewModel.sessionMode == mode ? Color.white : IPTheme.insetSurfaceSecondaryText(for: colorScheme)
                        )
                        .frame(width: 18, height: 18)

                    Text(mode.displayName)
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(viewModel.sessionMode == mode ? Color.white : IPTheme.insetSurfacePrimaryText(for: colorScheme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)

                    Spacer()

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                    } else if viewModel.sessionMode == mode {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }
                }

                Text(isLocked ? "Pro required" : mode.subtitle)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(viewModel.sessionMode == mode ? Color.white : IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .ipInsetSurface(selected: viewModel.sessionMode == mode, cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }

    private func infoBadge(title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(IPTypography.labelSmall)
                .lineLimit(1)
        }
        .foregroundStyle(IPTheme.accent)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(IPTheme.accent.opacity(0.10), in: Capsule())
    }

    private func selectionChip(
        title: String,
        symbol: String,
        isSelected: Bool,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 18, height: 18)

                Text(title)
                    .font(IPTypography.bodyLarge)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                Image(systemName: selectionTrailingSymbol(isSelected: isSelected, isLocked: isLocked))
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(selectionChipForeground(isSelected: isSelected, isLocked: isLocked))
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selectionChipFill(isSelected: isSelected, isLocked: isLocked))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(selectionChipBorder(isSelected: isSelected, isLocked: isLocked), lineWidth: isSelected ? 1.5 : 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private func selectionChipForeground(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected {
            return Color.white
        }

        if isLocked {
            return IPTheme.textSecondary.opacity(0.70)
        }

        return IPTheme.textPrimary
    }

    private func selectionChipFill(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected {
            return IPTheme.accentSelected
        }

        if isLocked {
            return colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
        }

        return colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.88)
    }

    private func selectionTrailingSymbol(isSelected: Bool, isLocked: Bool) -> String {
        if isLocked {
            return "lock.fill"
        }

        return isSelected ? "checkmark.circle.fill" : "circle"
    }

    private func selectionChipBorder(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected {
            return IPTheme.accent.opacity(0.44)
        }

        if isLocked {
            return IPTheme.borderColor(for: colorScheme).opacity(0.7)
        }

        return IPTheme.borderColor(for: colorScheme)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(IPTypography.labelMedium)
            .foregroundStyle(IPTheme.textSecondary)
    }

    private func resumeActionButton(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(IPTheme.textPrimary)
                    .frame(width: 18, height: 18)

                Text(title)
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(IPTheme.surfacePrimary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func startSession() {
        Task {
            let destination = await viewModel.prepareSession()
            showPaywall = viewModel.shouldPresentPaywall

            switch destination {
            case .live(let sessionId):
                preparedSessionId = sessionId
                showLiveSession = true
            case .voicePrep(let sessionId):
                preparedSessionId = sessionId
                showPrepSession = true
            case nil:
                break
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

    private func selectSessionMode(_ mode: SessionMode, isLocked: Bool) {
        if isLocked {
            viewModel.errorMessage = "Voice Prep requires an active Pro subscription."
            showPaywall = true
            return
        }

        withAnimation(IPAnimations.snappy) {
            viewModel.sessionMode = mode
        }
    }

    private func selectResponseQualityMode(_ mode: ResponseQualityMode, isLocked: Bool) {
        if isLocked {
            viewModel.errorMessage = "Top Tier mode requires an active Pro subscription."
            showPaywall = true
            return
        }

        withAnimation(IPAnimations.snappy) {
            viewModel.responseQualityMode = mode
        }
    }

    private func interviewTypeIcon(for type: InterviewType) -> String {
        switch type {
        case .behavioral:
            return "person.2.fill"
        case .technical:
            return "terminal.fill"
        case .systemDesign:
            return "server.rack"
        case .caseStudy:
            return "doc.text.magnifyingglass"
        case .hrScreen:
            return "person.text.rectangle.fill"
        case .general:
            return "square.grid.2x2.fill"
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
    viewModel.sessionMode = .liveInterview
    viewModel.preparedAnswers = ready
        ? [
            PreComputedAnswer(question: "Tell me about a difficult team situation.", response: "Sample", type: .behavioral),
            PreComputedAnswer(question: "How do you ship performant SwiftUI screens?", response: "Sample", type: .technical),
        ]
        : []
    return viewModel
}
