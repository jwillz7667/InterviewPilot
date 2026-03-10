import SwiftUI
import UniformTypeIdentifiers

struct SessionSetupView: View {
    @State private var viewModel = SessionSetupViewModel()
    @State private var showLiveSession = false
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(IPTheme.backgroundTop).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: IPTheme.spacing24) {
                        // Header
                        VStack(spacing: IPTheme.spacing8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundStyle(IPTheme.brand.gradient)
                                .symbolEffect(.breathe.pulse)

                            Text("Interview Prep")
                                .font(IPTypography.headlineLarge)
                                .foregroundStyle(.white)

                            Text("Upload your resume and job description to get started")
                                .font(IPTypography.bodyMedium)
                                .foregroundStyle(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, IPTheme.spacing24)

                        // Resume input card
                        SetupCard(
                            icon: "doc.text.fill",
                            title: "Resume",
                            subtitle: viewModel.hasResume ? "Uploaded" : "PDF or paste text"
                        ) {
                            if viewModel.hasResume {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(IPTheme.success)
                                    Text("Resume loaded (\(viewModel.resumeText.count) chars)")
                                        .font(IPTypography.bodyMedium)
                                        .foregroundStyle(.white.opacity(0.7))
                                    Spacer()
                                    Button("Change") { showFilePicker = true }
                                        .font(IPTypography.labelMedium)
                                        .foregroundStyle(IPTheme.brandLight)
                                }
                            } else {
                                VStack(spacing: IPTheme.spacing12) {
                                    Button(action: { showFilePicker = true }) {
                                        Label("Upload PDF", systemImage: "doc.badge.plus")
                                            .font(IPTypography.bodyMedium)
                                            .foregroundStyle(IPTheme.brandLight)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, IPTheme.spacing12)
                                            .background(IPTheme.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall))
                                    }

                                    Text("or paste text below")
                                        .font(IPTypography.labelSmall)
                                        .foregroundStyle(.white.opacity(0.3))

                                    TextEditor(text: $viewModel.resumeText)
                                        .font(IPTypography.bodyMedium)
                                        .foregroundStyle(.white)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 80, maxHeight: 150)
                                        .padding(IPTheme.spacing8)
                                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall))
                                }
                            }
                        }

                        // Job description input card
                        SetupCard(
                            icon: "briefcase.fill",
                            title: "Job Description",
                            subtitle: viewModel.hasJobDescription ? "Added" : "Paste or enter URL"
                        ) {
                            TextEditor(text: $viewModel.jobDescription)
                                .font(IPTypography.bodyMedium)
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100, maxHeight: 200)
                                .padding(IPTheme.spacing8)
                                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall))
                        }

                        // Interview type picker
                        SetupCard(
                            icon: "target",
                            title: "Interview Type",
                            subtitle: viewModel.interviewType.displayName
                        ) {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: IPTheme.spacing8) {
                                ForEach(InterviewType.allCases, id: \.self) { type in
                                    Button(action: {
                                        withAnimation(IPAnimations.snappy) {
                                            viewModel.interviewType = type
                                        }
                                    }) {
                                        Text(type.displayName)
                                            .font(IPTypography.labelMedium)
                                            .foregroundStyle(viewModel.interviewType == type ? .white : .white.opacity(0.5))
                                            .padding(.vertical, IPTheme.spacing8)
                                            .frame(maxWidth: .infinity)
                                            .background(
                                                viewModel.interviewType == type
                                                    ? IPTheme.brand.opacity(0.8)
                                                    : Color.white.opacity(0.05),
                                                in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall)
                                            )
                                    }
                                    .sensoryFeedback(.selection, trigger: viewModel.interviewType)
                                }
                            }
                        }

                        // Response format picker
                        SetupCard(
                            icon: "text.alignleft",
                            title: "Response Format",
                            subtitle: "How answers appear on screen"
                        ) {
                            VStack(spacing: IPTheme.spacing8) {
                                ForEach(ResponseFormat.allCases, id: \.self) { format in
                                    Button(action: {
                                        withAnimation(IPAnimations.snappy) {
                                            viewModel.responseFormat = format
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: viewModel.responseFormat == format
                                                  ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(viewModel.responseFormat == format
                                                                ? IPTheme.brand : .white.opacity(0.3))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(format.displayName)
                                                    .font(IPTypography.bodyMedium)
                                                    .foregroundStyle(.white)
                                                Text(format.description)
                                                    .font(IPTypography.labelSmall)
                                                    .foregroundStyle(.white.opacity(0.4))
                                            }

                                            Spacer()
                                        }
                                        .padding(IPTheme.spacing12)
                                        .background(
                                            viewModel.responseFormat == format
                                                ? IPTheme.brand.opacity(0.1)
                                                : Color.clear,
                                            in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall)
                                        )
                                    }
                                }
                            }
                        }

                        // Start button
                        Button(action: {
                            Task {
                                await viewModel.prepareSession()
                                showLiveSession = true
                            }
                        }) {
                            HStack(spacing: IPTheme.spacing8) {
                                if viewModel.isPreGenerating {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 18))
                                }
                                Text(viewModel.isPreGenerating ? "Preparing..." : "Start Interview Session")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                viewModel.isReady
                                    ? AnyShapeStyle(IPTheme.brand.gradient)
                                    : AnyShapeStyle(Color.gray.opacity(0.3)),
                                in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium)
                            )
                            .shadow(color: viewModel.isReady ? IPTheme.brand.opacity(0.4) : .clear, radius: 12, y: 6)
                        }
                        .disabled(!viewModel.isReady || viewModel.isPreGenerating)
                        .sensoryFeedback(.impact(weight: .heavy), trigger: showLiveSession)
                        .padding(.top, IPTheme.spacing8)

                        // Pre-generation toggle
                        if viewModel.isReady {
                            HStack {
                                Image(systemName: "bolt.fill")
                                    .foregroundStyle(.yellow)
                                Text("Pre-generate likely questions?")
                                    .font(IPTypography.bodyMedium)
                                    .foregroundStyle(.white.opacity(0.7))
                                Spacer()
                                Toggle("", isOn: $viewModel.shouldPreGenerate)
                                    .tint(IPTheme.brand)
                            }
                            .padding(IPTheme.spacing16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusMedium))
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Error display
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(IPTypography.bodyMedium)
                                .foregroundStyle(IPTheme.error)
                                .padding(IPTheme.spacing12)
                                .background(IPTheme.error.opacity(0.1), in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall))
                        }
                    }
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.bottom, IPTheme.spacing24)
                }
            }
            .preferredColorScheme(.dark)
            .fullScreenCover(isPresented: $showLiveSession) {
                LiveSessionView(viewModel: viewModel.createLiveViewModel())
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
}

// MARK: - Setup Card

struct SetupCard<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing12) {
            Button(action: {
                withAnimation(IPAnimations.standard) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: IPTheme.spacing12) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(IPTheme.brandLight)
                        .frame(width: 32, height: 32)
                        .background(IPTheme.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(IPTypography.bodyLarge)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(IPTypography.labelSmall)
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
            }

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(IPTheme.spacing16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusLarge))
    }
}
