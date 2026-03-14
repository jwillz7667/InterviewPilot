import SwiftUI
import UniformTypeIdentifiers

struct SessionSetupView: View {
    @State private var viewModel = SessionSetupViewModel()
    @State private var showLiveSession = false
    @State private var showPrepSession = false
    @State private var showFilePicker = false
    @State private var showPaywall = false
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
                        answerStyleSection
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
            .onChange(of: viewModel.jobDescription) {
                viewModel.invalidatePreparedAnswerBankIfNeeded()
            }
            .onChange(of: viewModel.interviewType) {
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

                    if viewModel.isReady {
                        IPStatusPill(title: "Ready", symbol: "checkmark.circle.fill", tint: IPTheme.success)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Prepare this interview")
                        .font(IPTypography.headlineLarge)
                        .foregroundStyle(IPTheme.textPrimary)

                    Text("Add your resume and the target role, choose the answer shape you want, and start when the session is ready.")
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(IPTheme.textSecondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    dashboardSummaryCard(
                        title: "Resume",
                        value: viewModel.hasResume ? "Added" : "Required",
                        symbol: "doc.text.fill",
                        highlight: viewModel.hasResume
                    )

                    dashboardSummaryCard(
                        title: "Job description",
                        value: viewModel.hasJobDescription ? "Added" : "Required",
                        symbol: "briefcase.fill",
                        highlight: viewModel.hasJobDescription
                    )

                    dashboardSummaryCard(
                        title: "Interview focus",
                        value: viewModel.interviewType.displayName,
                        symbol: interviewTypeIcon(for: viewModel.interviewType)
                    )

                    dashboardSummaryCard(
                        title: "Answer layout",
                        value: viewModel.responseFormat.displayName,
                        symbol: "text.alignleft"
                    )

                    dashboardSummaryCard(
                        title: "Answer mode",
                        value: viewModel.responseQualityMode.displayName,
                        symbol: responseQualityIcon(for: viewModel.responseQualityMode, isLocked: false)
                    )

                    dashboardSummaryCard(
                        title: "Tone",
                        value: viewModel.responseTone.displayName,
                        symbol: responseToneIcon(for: viewModel.responseTone)
                    )
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
                    subtitle: "These two inputs drive personalization, likely-question generation, and the language used in live answers.",
                    symbol: "tray.full.fill"
                )

                IPInputShell(
                    icon: "doc.text.fill",
                    title: "Resume",
                    subtitle: "Upload a PDF or paste text from your current resume."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Button(action: { showFilePicker = true }) {
                                Label(viewModel.hasResume ? "Replace PDF" : "Upload PDF", systemImage: "doc.badge.plus")
                            }
                            .buttonStyle(IPSecondaryButtonStyle())

                            if viewModel.hasResume {
                                IPStatusPill(
                                    title: "\(viewModel.resumeText.count) characters",
                                    symbol: "checkmark.circle.fill",
                                    tint: IPTheme.success
                                )
                            }
                        }

                        TextEditor(text: $viewModel.resumeText)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 150)
                            .padding(12)
                            .ipInsetSurface(cornerRadius: 20)
                    }
                }

                IPInputShell(
                    icon: "briefcase.fill",
                    title: "Job description",
                    subtitle: "Paste the full posting for better role-specific answers."
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextEditor(text: $viewModel.jobDescription)
                            .font(IPTypography.bodyMedium)
                            .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 180)
                            .padding(12)
                            .ipInsetSurface(cornerRadius: 20)

                        if !viewModel.jobDescription.isEmpty {
                            let keywords = Array(JobDescriptionService.extractKeywords(from: viewModel.jobDescription).prefix(8))
                            if !keywords.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(keywords, id: \.self) { keyword in
                                        Text(keyword)
                                            .font(IPTypography.labelSmall)
                                            .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.white, in: Capsule())
                                            .overlay {
                                                Capsule()
                                                    .stroke(IPTheme.insetSurfaceBorder(for: colorScheme, selected: false), lineWidth: 1)
                                            }
                                    }
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
                    title: "How should this session run?",
                    subtitle: "Choose the mode, expected interview type, and the answer layout you want to see during the session.",
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
                    sectionLabel("Interview focus")

                    FlowLayout(spacing: 10) {
                        ForEach(InterviewType.allCases, id: \.self) { type in
                            selectionChip(
                                title: type.displayName,
                                symbol: interviewTypeIcon(for: type),
                                isSelected: viewModel.interviewType == type
                            ) {
                                withAnimation(IPAnimations.snappy) {
                                    viewModel.interviewType = type
                                }
                            }
                        }
                    }
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

    private var answerStyleSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 18) {
                IPSectionHeader(
                    eyebrow: "Answer style",
                    title: "Fine tune the delivery",
                    subtitle: "Behavior shapes the structure, tone changes how it sounds, and emphasis decides what gets extra weight.",
                    symbol: "dial.medium"
                )

                styleControlGroup(
                    title: "Answer mode",
                    description: viewModel.responseQualityMode.description
                ) {
                    FlowLayout(spacing: 10) {
                        ForEach(ResponseQualityMode.allCases) { mode in
                            let isLocked = mode.requiresPriorityModels && !(subscriptionService.entitlement?.hasPriorityModels ?? false)

                            selectionChip(
                                title: mode.displayName,
                                symbol: responseQualityIcon(for: mode, isLocked: isLocked),
                                isSelected: viewModel.responseQualityMode == mode
                            ) {
                                selectResponseQualityMode(mode, isLocked: isLocked)
                            }
                        }
                    }
                }

                styleControlGroup(
                    title: "Behavior",
                    description: viewModel.responseBehavior.description
                ) {
                    FlowLayout(spacing: 10) {
                        ForEach(ResponseBehavior.allCases, id: \.self) { behavior in
                            selectionChip(
                                title: behavior.displayName,
                                symbol: responseBehaviorIcon(for: behavior),
                                isSelected: viewModel.responseBehavior == behavior
                            ) {
                                withAnimation(IPAnimations.snappy) {
                                    viewModel.responseBehavior = behavior
                                }
                            }
                        }
                    }
                }

                styleControlGroup(
                    title: "Tone",
                    description: viewModel.responseTone.description
                ) {
                    FlowLayout(spacing: 10) {
                        ForEach(ResponseTone.allCases, id: \.self) { tone in
                            selectionChip(
                                title: tone.displayName,
                                symbol: responseToneIcon(for: tone),
                                isSelected: viewModel.responseTone == tone
                            ) {
                                withAnimation(IPAnimations.snappy) {
                                    viewModel.responseTone = tone
                                }
                            }
                        }
                    }
                }

                styleControlGroup(
                    title: "Emphasis",
                    description: viewModel.responseEmphasis.description
                ) {
                    FlowLayout(spacing: 10) {
                        ForEach(ResponseEmphasis.allCases, id: \.self) { emphasis in
                            selectionChip(
                                title: emphasis.displayName,
                                symbol: emphasisIcon(for: emphasis),
                                isSelected: viewModel.responseEmphasis == emphasis
                            ) {
                                withAnimation(IPAnimations.snappy) {
                                    viewModel.responseEmphasis = emphasis
                                }
                            }
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
        if !viewModel.isReady {
            return "Add your resume and the job description to continue."
        }

        if viewModel.isPreparingSession {
            return "Preparing the session, validating access, and loading reusable prep assets."
        }

        if viewModel.shouldPreGenerate {
            return viewModel.prepSummary
        }

        if viewModel.responseQualityMode == .premium {
            return "Top Tier mode will use stronger models and higher-signal interview framing."
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

    private func dashboardSummaryCard(
        title: String,
        value: String,
        symbol: String,
        highlight: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    highlight
                        ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                        : IPTheme.insetSurfaceSecondaryText(for: colorScheme)
                )

            Text(title)
                .font(IPTypography.labelSmall)
                .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))

            Text(value)
                .font(IPTypography.bodyLarge)
                .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .ipInsetSurface(selected: highlight, cornerRadius: 18)
    }

    private func styleControlGroup<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel(title)
            content()
            Text(description)
                .font(IPTypography.bodySmall)
                .foregroundStyle(IPTheme.textSecondary)
        }
    }

    private func selectionChip(
        title: String,
        symbol: String,
        isSelected: Bool,
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
            .foregroundStyle(
                isSelected
                    ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                    : IPTheme.insetSurfaceSecondaryText(for: colorScheme)
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                Capsule()
                    .fill(
                        isSelected
                            ? IPTheme.accent.opacity(0.14)
                            : IPTheme.surfaceTertiary.opacity(0.12)
                    )
                    .overlay {
                        Capsule()
                            .stroke(
                                isSelected
                                    ? IPTheme.accent.opacity(0.28)
                                    : IPTheme.insetSurfaceBorder(for: colorScheme, selected: false),
                                lineWidth: 1
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(IPTypography.labelMedium)
            .foregroundStyle(IPTheme.textSecondary)
    }

    private func interviewTypeIcon(for type: InterviewType) -> String {
        switch type {
        case .behavioral: return "person.2.fill"
        case .technical: return "terminal.fill"
        case .systemDesign: return "server.rack"
        case .caseStudy: return "doc.text.magnifyingglass"
        case .hrScreen: return "person.text.rectangle.fill"
        case .general: return "square.grid.2x2.fill"
        }
    }

    private func responseBehaviorIcon(for behavior: ResponseBehavior) -> String {
        switch behavior {
        case .direct: return "bolt.fill"
        case .analytical: return "chart.bar.doc.horizontal.fill"
        case .storyLed: return "text.book.closed.fill"
        case .collaborative: return "person.2.wave.2.fill"
        }
    }

    private func responseToneIcon(for tone: ResponseTone) -> String {
        switch tone {
        case .natural: return "person.fill"
        case .confident: return "checkmark.seal.fill"
        case .warm: return "sun.max.fill"
        case .executive: return "briefcase.fill"
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

    private func emphasisIcon(for emphasis: ResponseEmphasis) -> String {
        switch emphasis {
        case .balanced: return "dial.medium.fill"
        case .technicalDepth: return "cpu.fill"
        case .businessImpact: return "chart.line.uptrend.xyaxis"
        case .leadership: return "person.3.fill"
        case .productThinking: return "lightbulb.max.fill"
        }
    }
}
