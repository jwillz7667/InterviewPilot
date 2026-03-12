import SwiftUI
import UniformTypeIdentifiers

struct SessionSetupView: View {
    @State private var viewModel = SessionSetupViewModel()
    @State private var activeSessionMode: SessionMode?
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                IPAppBackground()

                ScrollView {
                    VStack(spacing: IPTheme.spacing20) {
                        heroSection
                        modeSection
                        resumeSection
                        jobSection
                        interviewTypeSection

                        if viewModel.sessionMode == .liveInterview {
                            responseFormatSection
                        }

                        if viewModel.isReady && viewModel.sessionMode == .liveInterview {
                            preGenerationSection
                        }

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
            .fullScreenCover(item: $activeSessionMode) { mode in
                switch mode {
                case .liveInterview:
                    LiveSessionView(viewModel: viewModel.createLiveViewModel())
                case .voicePrep:
                    PrepSessionView(viewModel: viewModel.createPrepViewModel())
                }
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
                    IPStatusPill(title: viewModel.sessionMode.displayName, symbol: viewModel.sessionMode.icon)
                    Spacer()
                    if viewModel.hasResume && viewModel.hasJobDescription {
                        IPStatusPill(title: "Ready", symbol: "checkmark.circle.fill", tint: IPTheme.success)
                    }
                }

                Text("Build a cleaner interview workspace")
                    .font(IPTypography.headlineLarge)
                    .foregroundStyle(IPTheme.textPrimary)

                Text("Choose between live assistance for a real interview or a voice-first mock interview, then anchor it to your resume and the job posting.")
                    .font(IPTypography.bodyLarge)
                    .foregroundStyle(IPTheme.textSecondary)

                HStack(spacing: 10) {
                    summaryPill("Resume", isReady: viewModel.hasResume)
                    summaryPill("Job post", isReady: viewModel.hasJobDescription)
                    summaryPill(viewModel.interviewType.displayName, isReady: true, tint: IPTheme.accentWarm)
                }
            }
        }
    }

    private var modeSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 1",
                    title: "Choose the session style",
                    subtitle: "Use live mode during a real interview, or voice prep when you want the app to act as the interviewer.",
                    symbol: "switch.2"
                )

                HStack(spacing: 12) {
                    ForEach(SessionMode.allCases) { mode in
                        Button(action: {
                            withAnimation(IPAnimations.standard) {
                                viewModel.sessionMode = mode
                            }
                        }) {
                            VStack(alignment: .leading, spacing: 12) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill((viewModel.sessionMode == mode ? IPTheme.accent : IPTheme.surfaceTertiary).opacity(0.15))
                                    .frame(width: 46, height: 46)
                                    .overlay {
                                        Image(systemName: mode.icon)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(viewModel.sessionMode == mode ? IPTheme.accent : IPTheme.textSecondary)
                                    }

                                Text(mode.displayName)
                                    .font(IPTypography.bodyLarge)
                                    .foregroundStyle(IPTheme.textPrimary)

                                Text(mode.subtitle)
                                    .font(IPTypography.bodySmall)
                                    .foregroundStyle(IPTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer()

                                Image(systemName: viewModel.sessionMode == mode ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(viewModel.sessionMode == mode ? IPTheme.accent : IPTheme.textTertiary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
                            .padding(16)
                            .background(
                                (viewModel.sessionMode == mode ? IPTheme.accent.opacity(0.10) : Color.white.opacity(0.08)),
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var resumeSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 2",
                    title: "Add your resume",
                    subtitle: "Upload a PDF or paste text so the app can tailor both answer suggestions and mock questions.",
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
                    eyebrow: "Step 3",
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

    private var interviewTypeSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                IPSectionHeader(
                    eyebrow: "Step 4",
                    title: "Set the interview focus",
                    subtitle: "Bias the app toward the style of interview you expect so the generated answers and prep questions stay relevant.",
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

    private var preGenerationSection: some View {
        IPPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pre-generate likely questions")
                            .font(IPTypography.bodyLarge)
                            .foregroundStyle(IPTheme.textPrimary)

                        Text("Turn this on to build a fast response bank before the interview starts.")
                            .font(IPTypography.bodySmall)
                            .foregroundStyle(IPTheme.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.shouldPreGenerate)
                        .labelsHidden()
                        .tint(IPTheme.accent)
                }

                if viewModel.isPreGenerating || !viewModel.preComputedAnswers.isEmpty {
                    PreGenerationView(
                        progress: viewModel.preGenProgress,
                        answers: viewModel.preComputedAnswers,
                        isGenerating: viewModel.isPreGenerating
                    )
                }
            }
        }
    }

    private var startDock: some View {
        IPPanel(tone: .accent(IPTheme.accent), padding: IPTheme.spacing16, cornerRadius: IPTheme.radiusXL) {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.isReady ? "Everything is ready." : "Add your resume and the job description to continue.")
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textSecondary)

                Button(action: startSession) {
                    HStack(spacing: 10) {
                        if viewModel.isPreGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: viewModel.sessionMode == .voicePrep ? "person.wave.2.fill" : "mic.fill")
                                .symbolEffect(.pulse, isActive: viewModel.isReady)
                        }

                        Text(viewModel.isPreGenerating ? "Preparing..." : viewModel.sessionMode.startButtonTitle)
                    }
                }
                .buttonStyle(IPPrimaryButtonStyle(isEnabled: viewModel.isReady && !viewModel.isPreGenerating))
                .disabled(!viewModel.isReady || viewModel.isPreGenerating)
            }
        }
    }

    private func startSession() {
        Task {
            await viewModel.prepareSession()
            guard viewModel.errorMessage == nil else { return }
            activeSessionMode = viewModel.sessionMode
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
