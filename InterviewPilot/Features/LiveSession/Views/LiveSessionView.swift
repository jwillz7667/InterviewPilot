import SwiftUI

struct LiveSessionView: View {
    @State var viewModel: LiveSessionViewModel
    @State private var showEndConfirmation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [IPTheme.backgroundTop, IPTheme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.top, IPTheme.spacing8)

                transcriptSection
                    .frame(maxHeight: .infinity)

                divider

                responseSection
                    .frame(maxHeight: .infinity)

                controlBar
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.bottom, IPTheme.spacing8)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task { try? await viewModel.startSession() }
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .alert("End Session?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) {
                viewModel.stopSession()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the live interview session.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: { showEndConfirmation = true }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            HStack(spacing: 6) {
                PulsingDot(color: IPTheme.live)
                    .frame(width: 8, height: 8)

                Text("LIVE")
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(IPTheme.live)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Text(formatTime(viewModel.elapsedTime))
                .font(IPTypography.timer)
                .foregroundStyle(.white.opacity(0.6))
                .contentTransition(.numericText())
                .animation(.linear(duration: 0.3), value: viewModel.elapsedTime)
        }
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing12) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(IPTheme.brandLight)
                    .symbolEffect(
                        .variableColor.iterative,
                        isActive: viewModel.sessionState == .interviewerSpeaking
                    )

                Text("INTERVIEWER")
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.5)
            }
            .padding(.horizontal, IPTheme.spacing20)
            .padding(.top, IPTheme.spacing16)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(viewModel.interviewerTranscript.isEmpty
                         ? "Listening..."
                         : viewModel.interviewerTranscript)
                        .font(IPTypography.bodyLarge)
                        .foregroundStyle(viewModel.interviewerTranscript.isEmpty
                                        ? .white.opacity(0.3) : .white.opacity(0.9))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, IPTheme.spacing20)
                        .id("transcript-bottom")
                        .animation(IPAnimations.tokenAppear, value: viewModel.interviewerTranscript)
                }
                .onChange(of: viewModel.interviewerTranscript) {
                    withAnimation(IPAnimations.gentle) {
                        proxy.scrollTo("transcript-bottom", anchor: .bottom)
                    }
                }
            }

            if viewModel.sessionState == .interviewerSpeaking || viewModel.sessionState == .listening {
                WaveformView(level: viewModel.audioCapture.audioLevel)
                    .frame(height: 30)
                    .padding(.horizontal, IPTheme.spacing20)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: IPTheme.radiusLarge)
                .fill(.ultraThinMaterial)
                .padding(.horizontal, IPTheme.spacing8)
        )
        .padding(.horizontal, IPTheme.spacing8)
        .padding(.top, IPTheme.spacing8)
    }

    // MARK: - Divider

    private var divider: some View {
        HStack {
            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)

            if let questionType = viewModel.questionType {
                QuestionTypeBadge(classification: questionType)
                    .transition(.scale.combined(with: .opacity))
            }

            Rectangle()
                .fill(.white.opacity(0.1))
                .frame(height: 1)
        }
        .padding(.horizontal, IPTheme.spacing20)
        .padding(.vertical, IPTheme.spacing4)
        .animation(IPAnimations.snappy, value: viewModel.questionType?.type)
    }

    // MARK: - Response Section

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: IPTheme.spacing12) {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isResponseFromCache ? "bolt.fill" : "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, value: viewModel.sessionState == .responseReady)

                Text("YOUR ANSWER")
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(1.5)

                if viewModel.isResponseFromCache {
                    Text("INSTANT")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.yellow, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                if viewModel.responseGenerator.isGenerating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                        .tint(IPTheme.brandLight)
                }
            }
            .padding(.horizontal, IPTheme.spacing20)
            .padding(.top, IPTheme.spacing12)

            // Error banner
            if let error = viewModel.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 12))
                    Text(error)
                        .font(IPTypography.labelSmall)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(2)
                    Spacer()
                    Button(action: { viewModel.errorMessage = nil }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(IPTheme.spacing8)
                .background(IPTheme.error.opacity(0.2), in: RoundedRectangle(cornerRadius: IPTheme.radiusSmall))
                .padding(.horizontal, IPTheme.spacing20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollViewReader { proxy in
                ScrollView {
                    if viewModel.currentResponse.isEmpty && viewModel.sessionState != .generating {
                        Text("Response will appear here...")
                            .font(IPTypography.responseText)
                            .foregroundStyle(.white.opacity(0.2))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, IPTheme.spacing20)
                    } else if viewModel.currentResponse.isEmpty && viewModel.sessionState == .generating {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(0..<3, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.white.opacity(0.08))
                                    .frame(height: 16)
                                    .frame(maxWidth: i == 2 ? 200 : .infinity)
                                    .shimmer()
                            }
                        }
                        .padding(.horizontal, IPTheme.spacing20)
                        .transition(.opacity)
                    } else {
                        Text(viewModel.currentResponse)
                            .font(IPTypography.responseText)
                            .foregroundStyle(.white)
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, IPTheme.spacing20)
                            .padding(.bottom, IPTheme.spacing12)
                            .id("response-bottom")
                    }
                }
                .onChange(of: viewModel.currentResponse) {
                    withAnimation(IPAnimations.gentle) {
                        proxy.scrollTo("response-bottom", anchor: .bottom)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: IPTheme.radiusLarge)
                .fill(.regularMaterial)
                .padding(.horizontal, IPTheme.spacing8)
        )
        .padding(.horizontal, IPTheme.spacing8)
        .padding(.bottom, IPTheme.spacing8)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: IPTheme.spacing24) {
            ControlButton(
                icon: viewModel.audioCapture.isCapturing ? "mic.fill" : "mic.slash.fill",
                label: viewModel.audioCapture.isCapturing ? "Mute" : "Unmute",
                isActive: viewModel.audioCapture.isCapturing
            ) {
                if viewModel.audioCapture.isCapturing {
                    viewModel.audioCapture.stopCapture()
                } else {
                    try? viewModel.audioCapture.startCapture()
                }
            }

            Spacer()

            Button(action: { showEndConfirmation = true }) {
                Image(systemName: "phone.down.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(IPTheme.error.gradient, in: Circle())
                    .shadow(color: IPTheme.error.opacity(0.4), radius: 8, y: 4)
            }

            Spacer()

            ControlButton(
                icon: "forward.fill",
                label: "Next",
                isActive: true
            ) {
                withAnimation(IPAnimations.standard) {
                    viewModel.resetForNewQuestion()
                }
            }
        }
        .padding(.vertical, IPTheme.spacing12)
        .padding(.horizontal, IPTheme.spacing24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: IPTheme.radiusXL))
    }

    // MARK: - Helpers

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Control Button

struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            isPressed.toggle()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? .white : .white.opacity(0.4))
                    .symbolEffect(.bounce, value: isPressed)

                Text(label)
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: isPressed)
    }
}
