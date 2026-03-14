import SwiftUI
import UniformTypeIdentifiers

struct SessionSetupView: View {
    @State private var viewModel = SessionSetupViewModel()
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

    var body: some View {
        NavigationStack {
            ZStack {
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        overviewSection
                        materialsSection
                        coreSetupSection
                        prepAssetsSection

                        if let error = viewModel.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.error)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing20)
                    .padding(.top, IPTheme.spacing20)
                    .padding(.bottom, 120)
                }
                .ipScrollablePage()
            }
            .navigationTitle("Prepare")
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                startDock
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.bottom, IPTheme.spacing8)
            }
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
                await viewModel.loadIfNeeded()
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

    private var overviewSection: some View {
        IPPanel(tone: .secondary) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    IPStatusPill(title: viewModel.sessionMode.displayName, symbol: viewModel.sessionMode.icon)

                    if let entitlement = subscriptionService.entitlement {
                        IPStatusPill(
                            title: entitlement.planTitle,
                            symbol: entitlement.sandboxFullAccess ? "checkmark.seal.fill" : "creditcard.fill",
                            tint: entitlement.sandboxFullAccess ? IPTheme.success : IPTheme.accentForeground
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Complete the setup")
                        .font(IPTypography.headlineLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    Text("Keep the input simple: upload your resume, paste a job listing URL, confirm the inferred role, and start when the checklist is complete.")
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(IPTheme.textSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(checklistItems) { item in
                        checklistRow(item)
                    }
                }
            }
        }
    }

    private var materialsSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 18) {
                IPSectionHeader(
                    eyebrow: "Required",
                    title: "Role materials",
                    subtitle: "The app now works from a resume plus a listing URL. It pulls the posting, infers the role context, and uses that to personalize responses.",
                    symbol: "tray.full.fill"
                )

                IPInputShell(
                    icon: "doc.text.fill",
                    title: "Resume",
                    subtitle: "Upload a PDF or paste your resume. The main screen only shows status; preview opens in a separate sheet."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Button(action: { showFilePicker = true }) {
                                Label(viewModel.hasResume ? "Replace PDF" : "Upload PDF", systemImage: "doc.badge.plus")
                            }
                            .buttonStyle(IPSecondaryButtonStyle())

                            Button(action: { showResumeEditor = true }) {
                                Label(viewModel.hasResume ? "Paste or Edit" : "Paste Resume", systemImage: "square.and.pencil")
                            }
                            .buttonStyle(IPSecondaryButtonStyle())

                            if viewModel.hasResume {
                                Button(action: { showResumePreview = true }) {
                                    Label("Preview", systemImage: "eye")
                                }
                                .buttonStyle(IPSecondaryButtonStyle())
                            }
                        }

                        HStack(spacing: 10) {
                            IPStatusPill(
                                title: viewModel.hasResume ? "Uploaded" : "Required",
                                symbol: viewModel.hasResume ? "checkmark.circle.fill" : "circle",
                                tint: viewModel.hasResume ? IPTheme.success : IPTheme.textSecondary
                            )

                            if viewModel.hasResume {
                                Text(viewModel.resumeStatusLabel)
                                    .font(IPTypography.bodySmall)
                                    .foregroundStyle(IPTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                IPInputShell(
                    icon: "link",
                    title: "Job listing",
                    subtitle: "Paste the public posting URL. The app analyzes the listing, infers job category and seniority, and tunes the session from that context."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "link")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))

                                TextField("https://company.com/jobs/role", text: $viewModel.jobListingURL)
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .submitLabel(.go)
                                    .onSubmit {
                                        Task {
                                            await viewModel.analyzeJobListing()
                                        }
                                    }

                                if viewModel.isAnalyzingJobListing {
                                    ProgressView()
                                        .tint(IPTheme.accent)
                                }
                            }
                            .padding(14)
                            .ipInsetSurface(cornerRadius: 18)
                        }

                        HStack(spacing: 10) {
                            Button(action: {
                                Task {
                                    await viewModel.analyzeJobListing()
                                }
                            }) {
                                Label(
                                    viewModel.hasJobListing ? "Refresh Analysis" : "Analyze Listing",
                                    systemImage: "wand.and.stars"
                                )
                            }
                            .buttonStyle(IPSecondaryButtonStyle())

                            if viewModel.hasJobListing {
                                Button(action: { showJobListingPreview = true }) {
                                    Label("Preview", systemImage: "eye")
                                }
                                .buttonStyle(IPSecondaryButtonStyle())
                            }
                        }

                        HStack(spacing: 10) {
                            IPStatusPill(
                                title: viewModel.hasJobListing ? "Analyzed" : "Required",
                                symbol: viewModel.hasJobListing ? "checkmark.circle.fill" : "circle",
                                tint: viewModel.hasJobListing ? IPTheme.success : IPTheme.textSecondary
                            )

                            if viewModel.hasJobListing {
                                Text(viewModel.jobListingStatusLabel)
                                    .font(IPTypography.bodySmall)
                                    .foregroundStyle(IPTheme.textSecondary)
                                    .lineLimit(2)
                            }
                        }

                        if viewModel.hasJobListing {
                            HStack(spacing: 8) {
                                if let host = URL(string: viewModel.jobListingURL)?.host {
                                    infoBadge(title: host.replacingOccurrences(of: "www.", with: ""), symbol: "globe")
                                }

                                if let jobCategory = viewModel.jobCategory {
                                    infoBadge(title: jobCategory.displayName, symbol: jobCategoryIcon(for: jobCategory))
                                }

                                if let positionLevel = viewModel.positionLevel {
                                    infoBadge(title: positionLevel.displayName, symbol: positionLevelIcon(for: positionLevel))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var coreSetupSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 18) {
                IPSectionHeader(
                    eyebrow: "Core setup",
                    title: "Confirm the role targeting",
                    subtitle: "The old vague style knobs are gone. Confirm how the session runs, the job category, the seniority level, and the answer layout.",
                    symbol: "slider.horizontal.3"
                )

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Mode")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(SessionMode.allCases) { mode in
                            let isLocked = mode == .voicePrep && !(subscriptionService.entitlement?.hasVoicePrep ?? false)

                            Button(action: { selectSessionMode(mode, isLocked: isLocked) }) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 8) {
                                        Image(systemName: mode.icon)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(
                                                viewModel.sessionMode == mode
                                                    ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                                                    : IPTheme.insetSurfaceSecondaryText(for: colorScheme)
                                            )

                                        Spacer()

                                        if isLocked {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                                        } else if viewModel.sessionMode == mode {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                        }
                                    }

                                    Text(mode.displayName)
                                        .font(IPTypography.bodyLarge)
                                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))

                                    Text(isLocked ? "Pro required" : mode.subtitle)
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                                }
                                .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                                .padding(14)
                                .ipInsetSurface(selected: viewModel.sessionMode == mode, cornerRadius: 18)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Answer mode")

                    FlowLayout(spacing: 10) {
                        ForEach(ResponseQualityMode.allCases) { mode in
                            let isLocked = mode.requiresPriorityModels && !(subscriptionService.entitlement?.hasPriorityModels ?? false)

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

                    Text(viewModel.responseQualityMode.description)
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Job category")

                    FlowLayout(spacing: 10) {
                        ForEach(JobCategory.allCases) { category in
                            selectionChip(
                                title: category.displayName,
                                symbol: jobCategoryIcon(for: category),
                                isSelected: viewModel.jobCategory == category
                            ) {
                                withAnimation(IPAnimations.snappy) {
                                    viewModel.jobCategory = category
                                    viewModel.interviewType = viewModel.derivedProfile.interviewType
                                }
                            }
                        }
                    }

                    Text("Auto-detected from the listing, but you can override it if the posting is noisy or mislabeled.")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionLabel("Interview level")

                    FlowLayout(spacing: 10) {
                        ForEach(PositionLevel.allCases) { level in
                            selectionChip(
                                title: level.displayName,
                                symbol: positionLevelIcon(for: level),
                                isSelected: viewModel.positionLevel == level
                            ) {
                                withAnimation(IPAnimations.snappy) {
                                    viewModel.positionLevel = level
                                    viewModel.interviewType = viewModel.derivedProfile.interviewType
                                }
                            }
                        }
                    }

                    Text(viewModel.derivedProfile.rolePromptInstruction)
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 10) {
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
                                                    ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                                                    : IPTheme.insetSurfaceTertiaryText(for: colorScheme)
                                            )
                                    }

                                    Text(format.description)
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                                }
                                .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
                                .padding(14)
                                .ipInsetSurface(selected: viewModel.responseFormat == format, cornerRadius: 18)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var prepAssetsSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Optional",
                    title: "Prep bank",
                    subtitle: "Generate likely questions and reusable answer scaffolds before the session starts.",
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
                .padding(14)
                .ipInsetSurface(cornerRadius: 18)

                if viewModel.shouldPreGenerate {
                    PreGenerationView(
                        progress: viewModel.preGenerationProgress,
                        answers: viewModel.preparedAnswers,
                        isGenerating: viewModel.isGeneratingAnswerBank
                    )

                    if viewModel.isReady && !viewModel.isGeneratingAnswerBank && !viewModel.hasPreparedAnswers {
                        Button(action: {
                            Task {
                                await viewModel.generatePreparedAnswers(force: true)
                            }
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
    }

    private var startDock: some View {
        IPPanel(tone: .accent(IPTheme.accent), padding: IPTheme.spacing16, cornerRadius: IPTheme.radiusXL) {
            VStack(alignment: .leading, spacing: 12) {
                Text(startSummary)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)

                Button(action: startSession) {
                    HStack(spacing: 10) {
                        if viewModel.isPreparingSession {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "mic.fill")
                                .symbolEffect(.pulse, isActive: viewModel.isReady)
                        }

                        Text(viewModel.isPreparingSession ? "Preparing Session" : viewModel.sessionMode.startButtonTitle)
                    }
                }
                .buttonStyle(IPPrimaryButtonStyle(isEnabled: viewModel.isReady && !viewModel.isPreparingSession))
                .disabled(!viewModel.isReady || viewModel.isPreparingSession)
            }
        }
    }

    private var checklistItems: [SetupChecklistItem] {
        [
            SetupChecklistItem(
                title: "Resume uploaded",
                detail: viewModel.hasResume ? viewModel.resumeStatusLabel : "Upload a PDF or paste your latest resume.",
                isComplete: viewModel.hasResume
            ),
            SetupChecklistItem(
                title: "Job listing analyzed",
                detail: viewModel.hasJobListing ? viewModel.jobListingStatusLabel : "Paste a public listing URL and run analysis.",
                isComplete: viewModel.hasJobListing
            ),
            SetupChecklistItem(
                title: "Job category confirmed",
                detail: viewModel.jobCategory?.displayName ?? "The listing analysis will auto-select a category.",
                isComplete: viewModel.jobCategory != nil
            ),
            SetupChecklistItem(
                title: "Interview level confirmed",
                detail: viewModel.positionLevel?.displayName ?? "The listing analysis will auto-select a level.",
                isComplete: viewModel.positionLevel != nil
            )
        ]
    }

    private func checklistRow(_ item: SetupChecklistItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.isComplete ? IPTheme.success : IPTheme.textSecondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textPrimary)

                Text(item.detail)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .ipInsetSurface(selected: item.isComplete, cornerRadius: 18)
    }

    private func infoBadge(title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(IPTypography.labelSmall)
                .lineLimit(1)
        }
        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        }
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
            return "Add your resume to continue."
        }

        if !viewModel.hasJobListing {
            return "Paste and analyze a job listing URL to continue."
        }

        if viewModel.jobCategory == nil || viewModel.positionLevel == nil {
            return "Confirm the inferred job category and interview level before starting."
        }

        if viewModel.isPreparingSession {
            return "Preparing the session, validating access, and loading reusable prep assets."
        }

        if viewModel.shouldPreGenerate {
            return viewModel.prepSummary
        }

        if viewModel.responseQualityMode == .premium {
            return "Top Tier mode will use stronger models and role-calibrated interview framing."
        }

        if viewModel.sessionMode == .voicePrep {
            return "Voice Prep will start without a reusable prep bank."
        }

        if let entitlement = subscriptionService.entitlement {
            return entitlement.statusDetail
        }

        return "Everything is ready."
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

    private func selectionChip(
        title: String,
        symbol: String,
        isSelected: Bool,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(IPTypography.labelLarge)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            .foregroundStyle(selectionChipForeground(isSelected: isSelected, isLocked: isLocked))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(selectionChipFill(isSelected: isSelected, isLocked: isLocked))
                    .overlay {
                        Capsule()
                            .stroke(selectionChipBorder(isSelected: isSelected, isLocked: isLocked), lineWidth: isSelected ? 1.5 : 1)
                    }
            }
            .shadow(
                color: Color.black.opacity(isSelected ? 0.12 : 0.06),
                radius: isSelected ? 10 : 6,
                y: isSelected ? 6 : 3
            )
        }
        .buttonStyle(.plain)
    }

    private func selectionChipForeground(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? IPTheme.accent : IPTheme.accentForeground
        }

        if isLocked {
            return IPTheme.textSecondary.opacity(colorScheme == .dark ? 0.72 : 0.74)
        }

        return IPTheme.textSecondary.opacity(colorScheme == .dark ? 0.88 : 0.94)
    }

    private func selectionChipFill(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? Color.white : Color.white.opacity(0.16)
        }

        if isLocked {
            return Color.white.opacity(colorScheme == .dark ? 0.06 : 0.05)
        }

        return Color.white.opacity(colorScheme == .dark ? 0.10 : 0.08)
    }

    private func selectionChipBorder(isSelected: Bool, isLocked: Bool) -> Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.96) : Color.white.opacity(0.56)
        }

        if isLocked {
            return Color.white.opacity(colorScheme == .dark ? 0.30 : 0.44)
        }

        return Color.white.opacity(colorScheme == .dark ? 0.42 : 0.54)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(IPTypography.labelMedium)
            .foregroundStyle(IPTheme.textSecondary)
    }

    private func jobCategoryIcon(for category: JobCategory) -> String {
        switch category {
        case .softwareEngineering: return "terminal.fill"
        case .dataAI: return "cpu.fill"
        case .product: return "shippingbox.fill"
        case .design: return "paintbrush.pointed.fill"
        case .operations: return "gearshape.2.fill"
        case .salesCustomer: return "person.2.fill"
        case .marketing: return "megaphone.fill"
        case .financeStrategy: return "chart.line.uptrend.xyaxis"
        case .peopleHR: return "person.3.fill"
        case .generalBusiness: return "briefcase.fill"
        }
    }

    private func positionLevelIcon(for level: PositionLevel) -> String {
        switch level {
        case .entryLevel: return "figure.walk"
        case .midLevel: return "arrow.up.right.circle.fill"
        case .seniorIndividualContributor: return "star.fill"
        case .management: return "person.2.wave.2.fill"
        case .seniorManagement: return "building.2.fill"
        case .executive: return "crown.fill"
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

private struct SetupChecklistItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let isComplete: Bool
}
