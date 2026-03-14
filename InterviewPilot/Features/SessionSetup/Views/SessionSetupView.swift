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
                        heroSection
                        resumeSection
                        jobSection
                        sessionModeSection
                        interviewTypeSection
                        responseFormatSection
                        responseBehaviorSection
                        responseToneSection
                        responseEmphasisSection

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
            .navigationTitle("Job Hopper")
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
        }
    }

    private var heroSection: some View {
        IPPanel(tone: .accent(IPTheme.accent)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    IPStatusPill(title: "Live Interview", symbol: "waveform.and.mic")
                    Spacer()
                    if let entitlement = subscriptionService.entitlement {
                        IPStatusPill(
                            title: entitlement.planTitle,
                            symbol: entitlement.sandboxFullAccess ? "checkmark.seal.fill" : "creditcard.fill",
                            tint: entitlement.sandboxFullAccess ? IPTheme.success : IPTheme.accentForeground
                        )
                    }
                    Spacer()
                    if viewModel.hasResume && viewModel.hasJobDescription {
                        IPStatusPill(title: "Ready", symbol: "checkmark.circle.fill", tint: IPTheme.success)
                    }
                }

                HStack(alignment: .top, spacing: 14) {
                    IPBrandLogo(size: 60, cornerRadius: 20)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Build a cleaner interview workspace")
                            .font(IPTypography.headlineLarge)
                            .foregroundStyle(IPTheme.textPrimary)

                        Text("Set up the live interview workspace with your resume, the job posting, and the response style you want on screen during the call.")
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(IPTheme.textSecondary)
                    }
                }

                FlowLayout(spacing: 10) {
                    summaryPill("Resume", isReady: viewModel.hasResume)
                    summaryPill("Job post", isReady: viewModel.hasJobDescription)
                    summaryPill(viewModel.interviewType.displayName, isReady: true, tint: IPTheme.accentForeground)
                    summaryPill(viewModel.responseTone.displayName, isReady: true, tint: IPTheme.accentForeground)
                }
            }
        }
    }

    private var resumeSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 1",
                    title: "Add your resume",
                    subtitle: "Upload a PDF or paste text so the app can tailor live answer suggestions to your background.",
                    symbol: "doc.text.fill"
                )

                HStack(spacing: 10) {
                    Button(action: { showFilePicker = true }) {
                        Label(viewModel.hasResume ? "Replace PDF" : "Upload PDF", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(IPSecondaryButtonStyle())

                    if viewModel.hasResume {
                        IPStatusPill(title: "\(viewModel.resumeText.count) characters", symbol: "checkmark.circle.fill", tint: IPTheme.success)
                    }
                }

                TextEditor(text: $viewModel.resumeText)
                    .font(IPTypography.bodyMedium)
                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160)
                    .padding(12)
                    .ipInsetSurface(cornerRadius: 20)
            }
        }
    }

    private var jobSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 2",
                    title: "Paste the job description",
                    subtitle: "The full posting gives the app stronger signals for likely questions, technical areas, and framing.",
                    symbol: "briefcase.fill"
                )

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

    private var sessionModeSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 3",
                    title: "Choose the session mode",
                    subtitle: "Live Interview uses the inline answer overlay. Voice Prep runs a spoken mock interview and is unlocked on Pro.",
                    symbol: "waveform.path.ecg"
                )

                VStack(spacing: 10) {
                    ForEach(SessionMode.allCases) { mode in
                        let isLocked = mode == .voicePrep && !(subscriptionService.entitlement?.hasVoicePrep ?? false)

                        Button(action: { selectSessionMode(mode, isLocked: isLocked) }) {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.sessionMode == mode ? "checkmark.circle.fill" : (isLocked ? "lock.circle" : "circle"))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(
                                        viewModel.sessionMode == mode
                                            ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                                            : IPTheme.insetSurfaceTertiaryText(for: colorScheme)
                                    )

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(mode.displayName)
                                            .font(IPTypography.bodyLarge)
                                            .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))

                                        if isLocked {
                                            IPStatusPill(title: "Pro", symbol: "sparkles", tint: IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                        }
                                    }

                                    Text(mode.subtitle)
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                                }

                                Spacer()
                            }
                            .padding(14)
                            .ipInsetSurface(selected: viewModel.sessionMode == mode, cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var interviewTypeSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 4",
                    title: "Set the interview focus",
                    subtitle: "Bias the app toward the style of interview you expect so the generated answers stay relevant.",
                    symbol: "target"
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(InterviewType.allCases, id: \.self) { type in
                        Button(action: {
                            withAnimation(IPAnimations.snappy) {
                                viewModel.interviewType = type
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: interviewTypeIcon(for: type))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(
                                        viewModel.interviewType == type
                                            ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                                            : IPTheme.insetSurfaceSecondaryText(for: colorScheme)
                                    )

                                Text(type.displayName)
                                    .font(IPTypography.bodyLarge)
                                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                            }
                            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                            .padding(14)
                            .ipInsetSurface(selected: viewModel.interviewType == type, cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var responseFormatSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 5",
                    title: "Choose the answer layout",
                    subtitle: "Pick the on-screen answer shape: a spoken script, talking points, or a deeper technical answer.",
                    symbol: "text.alignleft"
                )

                VStack(spacing: 10) {
                    ForEach(ResponseFormat.allCases, id: \.self) { format in
                        Button(action: {
                            withAnimation(IPAnimations.snappy) {
                                viewModel.responseFormat = format
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.responseFormat == format ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(
                                        viewModel.responseFormat == format
                                            ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                                            : IPTheme.insetSurfaceTertiaryText(for: colorScheme)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.displayName)
                                        .font(IPTypography.bodyLarge)
                                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))
                                    Text(format.description)
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                                }

                                Spacer()
                            }
                            .padding(14)
                            .ipInsetSurface(selected: viewModel.responseFormat == format, cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var responseBehaviorSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 6",
                    title: "Set the answer behavior",
                    subtitle: "Control whether answers feel more direct, analytical, story-led, or collaborative.",
                    symbol: "slider.horizontal.3"
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(ResponseBehavior.allCases, id: \.self) { behavior in
                        Button(action: {
                            withAnimation(IPAnimations.snappy) {
                                viewModel.responseBehavior = behavior
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: responseBehaviorIcon(for: behavior))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(
                                        viewModel.responseBehavior == behavior
                                            ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                                            : IPTheme.insetSurfaceSecondaryText(for: colorScheme)
                                    )

                                Text(behavior.displayName)
                                    .font(IPTypography.bodyLarge)
                                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))

                                Text(behavior.description)
                                    .font(IPTypography.bodySmall)
                                    .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                            }
                            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                            .padding(14)
                            .ipInsetSurface(selected: viewModel.responseBehavior == behavior, cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var responseToneSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 7",
                    title: "Tune the tone",
                    subtitle: "Make answers sound more natural, more confident, warmer, or more executive depending on the room.",
                    symbol: "waveform.badge.mic"
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(ResponseTone.allCases, id: \.self) { tone in
                        Button(action: {
                            withAnimation(IPAnimations.snappy) {
                                viewModel.responseTone = tone
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: responseToneIcon(for: tone))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(
                                        viewModel.responseTone == tone
                                            ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                                            : IPTheme.insetSurfaceSecondaryText(for: colorScheme)
                                    )

                                Text(tone.displayName)
                                    .font(IPTypography.bodyLarge)
                                    .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))

                                Text(tone.description)
                                    .font(IPTypography.bodySmall)
                                    .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                            }
                            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                            .padding(14)
                            .ipInsetSurface(selected: viewModel.responseTone == tone, cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var responseEmphasisSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 8",
                    title: "Choose the emphasis",
                    subtitle: "Bias answers toward technical depth, business impact, leadership, or product judgment.",
                    symbol: "scope"
                )

                VStack(spacing: 10) {
                    ForEach(ResponseEmphasis.allCases, id: \.self) { emphasis in
                        Button(action: {
                            withAnimation(IPAnimations.snappy) {
                                viewModel.responseEmphasis = emphasis
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.responseEmphasis == emphasis ? "checkmark.circle.fill" : emphasisIcon(for: emphasis))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(
                                        viewModel.responseEmphasis == emphasis
                                            ? IPTheme.insetSurfacePrimaryText(for: colorScheme)
                                            : IPTheme.insetSurfaceTertiaryText(for: colorScheme)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(emphasis.displayName)
                                        .font(IPTypography.bodyLarge)
                                        .foregroundStyle(IPTheme.insetSurfacePrimaryText(for: colorScheme))

                                    Text(emphasis.description)
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.insetSurfaceSecondaryText(for: colorScheme))
                                }

                                Spacer()
                            }
                            .padding(14)
                            .ipInsetSurface(selected: viewModel.responseEmphasis == emphasis, cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                    }
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
                        Image(systemName: "mic.fill")
                            .symbolEffect(.pulse, isActive: viewModel.isReady)

                        Text(viewModel.sessionMode.startButtonTitle)
                    }
                }
                .buttonStyle(IPPrimaryButtonStyle(isEnabled: viewModel.isReady))
                .disabled(!viewModel.isReady)
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

    private func summaryPill(_ title: String, isReady: Bool, tint: Color = IPTheme.accentForeground) -> some View {
        Label(title, systemImage: isReady ? "checkmark.circle.fill" : "circle")
            .font(IPTypography.labelSmall)
            .foregroundStyle(isReady ? tint : IPTheme.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background((isReady ? tint : IPTheme.surfaceTertiary).opacity(0.12), in: Capsule())
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
