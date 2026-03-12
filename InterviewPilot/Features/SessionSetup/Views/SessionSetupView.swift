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
            .navigationTitle("Interview Pilot")
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
                            tint: entitlement.sandboxFullAccess ? IPTheme.success : IPTheme.accent
                        )
                    }
                    Spacer()
                    if viewModel.hasResume && viewModel.hasJobDescription {
                        IPStatusPill(title: "Ready", symbol: "checkmark.circle.fill", tint: IPTheme.success)
                    }
                }

                Text("Build a cleaner interview workspace")
                    .font(IPTypography.headlineLarge)
                    .foregroundStyle(IPTheme.textPrimary)

                Text("Set up the live interview workspace with your resume, the job posting, and the response style you want on screen during the call.")
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textSecondary)

                HStack(spacing: 10) {
                    summaryPill("Resume", isReady: viewModel.hasResume)
                    summaryPill("Job post", isReady: viewModel.hasJobDescription)
                    summaryPill(viewModel.interviewType.displayName, isReady: true, tint: IPTheme.accent)
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
                    .foregroundStyle(IPTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160)
                    .padding(12)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    .foregroundStyle(IPTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(12)
                    .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                if !viewModel.jobDescription.isEmpty {
                    let keywords = Array(JobDescriptionService.extractKeywords(from: viewModel.jobDescription).prefix(8))
                    if !keywords.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(keywords, id: \.self) { keyword in
                                Text(keyword)
                                    .font(IPTypography.labelSmall)
                                    .foregroundStyle(IPTheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(IPTheme.accent.opacity(0.10), in: Capsule())
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
                                    .foregroundStyle(viewModel.sessionMode == mode ? IPTheme.accent : IPTheme.textTertiary)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(mode.displayName)
                                            .font(IPTypography.bodyLarge)
                                            .foregroundStyle(IPTheme.textPrimary)

                                        if isLocked {
                                            IPStatusPill(title: "Pro", symbol: "sparkles", tint: IPTheme.accent)
                                        }
                                    }

                                    Text(mode.subtitle)
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(
                                (viewModel.sessionMode == mode ? IPTheme.accent.opacity(0.10) : Color.white.opacity(0.08)),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
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
                                    .foregroundStyle(viewModel.interviewType == type ? IPTheme.accent : IPTheme.textSecondary)

                                Text(type.displayName)
                                    .font(IPTypography.bodyLarge)
                                    .foregroundStyle(IPTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                            .padding(14)
                            .background(
                                (viewModel.interviewType == type ? IPTheme.accent.opacity(0.10) : Color.white.opacity(0.08)),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
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
                    title: "Choose how answers are shown",
                    subtitle: "Live mode can render complete scripts, compact bullets, or a hybrid blend.",
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
                                    .foregroundStyle(viewModel.responseFormat == format ? IPTheme.accent : IPTheme.textTertiary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(format.displayName)
                                        .font(IPTypography.bodyLarge)
                                        .foregroundStyle(IPTheme.textPrimary)
                                    Text(format.description)
                                        .font(IPTypography.bodySmall)
                                        .foregroundStyle(IPTheme.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(
                                (viewModel.responseFormat == format ? IPTheme.accent.opacity(0.10) : Color.white.opacity(0.08)),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
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

    private func summaryPill(_ title: String, isReady: Bool, tint: Color = IPTheme.accent) -> some View {
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
}
