import SwiftUI

struct LiveSessionView: View {
    @State var viewModel: LiveSessionViewModel
    @State private var showEndConfirmation = false
    @State private var network = NetworkPathMonitor.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let autoStartSession: Bool

    init(viewModel: LiveSessionViewModel, autoStartSession: Bool = true) {
        _viewModel = State(initialValue: viewModel)
        self.autoStartSession = autoStartSession
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                OfflineBanner(isOnline: network.isOnline)
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            questionSection
                            responseSection
                                .id("responseTop")
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 130)
                    }
                    .onChange(of: viewModel.currentResponse) { oldValue, newValue in
                        if oldValue.isEmpty && !newValue.isEmpty {
                            withAnimation(IAAnimations.standard) {
                                proxy.scrollTo("responseTop", anchor: .top)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Live transcript and AI suggestion")
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            controlDock
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .onAppear {
            guard autoStartSession else { return }
            Task {
                do {
                    try await viewModel.startSession()
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
        .onDisappear {
            guard autoStartSession else { return }
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

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button(action: { showEndConfirmation = true }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(IATheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(IATheme.surface))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Interview Ace")
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.textPrimary)

            Spacer()

            HStack(spacing: 8) {
                AnimatedStatusBadge(text: "Live", color: IATheme.live, isActive: true)

                IAStatusPill(
                    title: formatTime(viewModel.elapsedTime),
                    symbol: "clock",
                    tint: IATheme.textSecondary
                )
            }
        }
    }

    // MARK: - Interviewer Question Section

    private var questionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INTERVIEWER QUESTION")
                .font(IATypography.labelSmall)
                .tracking(1.2)
                .foregroundStyle(IATheme.textSecondary)

            Text(interviewerText)
                .font(IATypography.bodyLarge)
                .foregroundStyle(IATheme.textPrimary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                        .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: IATheme.radiusMedium, style: .continuous)
                        .stroke(IATheme.outlineVariant, lineWidth: 1)
                }

            if viewModel.audioCapture.isCapturing &&
                (viewModel.sessionState == .listening || viewModel.sessionState == .interviewerSpeaking) {
                WaveformView(level: viewModel.audioCapture.audioLevel)
                    .frame(height: 28)
                    .padding(.top, 2)
            }

            if let questionType = viewModel.questionType {
                QuestionTypeBadge(classification: questionType)
            }
        }
    }

    // MARK: - Response Bubble (large blue rounded)

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(IATheme.live)
                        .frame(width: 8, height: 8)
                        .opacity(viewModel.sessionState == .generating ? 1 : 0.5)

                    Text("LIVE SUGGESTION")
                        .font(IATypography.labelSmall)
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.15)))

                Spacer()

                IAStatusPill(title: liveStateTitle, symbol: liveStateSymbol, tint: .white)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            Group {
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(IATypography.bodySmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.top, 12)
                }

                if viewModel.currentResponse.isEmpty && viewModel.sessionState == .generating {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 16)
                                .frame(maxWidth: index == 2 ? 180 : .infinity)
                                .shimmer()
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                } else if viewModel.currentResponse.isEmpty {
                    Text(responsePlaceholder)
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                } else {
                    Text(viewModel.currentResponse)
                        .font(IATypography.responseText)
                        .foregroundStyle(.white)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                }
            }

            HStack(spacing: 10) {
                Button(action: {
                    viewModel.resumeListeningForNextQuestion()
                }) {
                    Label("Regenerate", systemImage: "arrow.counterclockwise")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .opacity(viewModel.currentResponse.isEmpty ? 0.4 : 1)
                .disabled(viewModel.currentResponse.isEmpty)

                Button(action: {
                    withAnimation(IAAnimations.standard) {
                        viewModel.resumeListeningForNextQuestion()
                    }
                }) {
                    Label("Next", systemImage: "forward.fill")
                        .font(IATypography.labelLarge)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.15)))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [IATheme.primaryContainer, IATheme.primary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: IATheme.accent.opacity(0.2), radius: 16, y: 8)
    }

    // MARK: - Controls

    private var controlDock: some View {
        IABottomDock {
            HStack(spacing: 10) {
                muteButton
                endButton
            }
        }
    }

    // MARK: - Text Helpers

    private var interviewerText: String {
        if !viewModel.interviewerTranscript.isEmpty {
            return viewModel.interviewerTranscript
        }

        if viewModel.errorMessage != nil {
            return "Waiting for connection\u{2026}"
        }

        return "Listening for the interviewer\u{2026}"
    }

    private var responsePlaceholder: String {
        switch viewModel.sessionState {
        case .generating:
            return ""
        case .responseReady, .postResponseSpeech:
            return ""
        case .idle, .listening, .interviewerSpeaking:
            return "Waiting for question\u{2026}"
        }
    }

    private var liveStateTitle: String {
        switch viewModel.sessionState {
        case .idle:
            return "Idle"
        case .listening:
            return "Ready"
        case .interviewerSpeaking:
            return "Listening"
        case .generating:
            return "Drafting"
        case .responseReady:
            return "Ready"
        case .postResponseSpeech:
            return "Waiting"
        }
    }

    private var liveStateSymbol: String {
        switch viewModel.sessionState {
        case .idle:
            return "pause.circle"
        case .listening:
            return "ear"
        case .interviewerSpeaking:
            return "waveform"
        case .generating:
            return "sparkles"
        case .responseReady:
            return "checkmark.circle"
        case .postResponseSpeech:
            return "arrow.trianglehead.clockwise"
        }
    }

    // MARK: - Buttons

    private var muteButton: some View {
        ControlButton(
            icon: viewModel.audioCapture.isCapturing ? "mic.fill" : "mic.slash.fill",
            label: viewModel.audioCapture.isCapturing ? "Mute" : "Unmute",
            isActive: viewModel.audioCapture.isCapturing,
            tint: IATheme.accent
        ) {
            if viewModel.audioCapture.isCapturing {
                viewModel.audioCapture.stopCapture()
            } else {
                do {
                    try viewModel.audioCapture.startCapture()
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var endButton: some View {
        ControlButton(
            icon: "stop.fill",
            label: "End",
            isActive: false,
            tint: IATheme.error
        ) {
            showEndConfirmation = true
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview("Live Listening") {
    LiveSessionView(viewModel: previewLiveViewModel(state: .interviewerSpeaking), autoStartSession: false)
}

#Preview("Live Generating") {
    LiveSessionView(viewModel: previewLiveViewModel(state: .generating), autoStartSession: false)
}

#Preview("Live Response Ready") {
    LiveSessionView(viewModel: previewLiveViewModel(state: .responseReady), autoStartSession: false)
}

@MainActor
private func previewLiveViewModel(state: LiveSessionViewModel.SessionState) -> LiveSessionViewModel {
    let viewModel = LiveSessionViewModel(
        sessionId: UUID(),
        resume: "Sample resume",
        jobDescription: "Senior iOS Engineer role",
        interviewType: .behavioral,
        jobCategory: .softwareEngineering,
        positionLevel: .seniorIndividualContributor,
        responseFormat: .hybrid,
        responseBehavior: .analytical,
        responseTone: .confident,
        responseEmphasis: .technicalDepth,
        responseQualityMode: .standard,
        preComputedAnswers: []
    )
    viewModel.sessionState = state
    viewModel.elapsedTime = 387
    viewModel.interviewerTranscript = "Tell me about a time you had to align a difficult team around a product decision."
    viewModel.currentResponse = state == .generating ? "" : "I started by getting the disagreement out of Slack and into a live decision review, clarified the tradeoff we were actually debating, and aligned everyone on the success metric we were optimizing for."
    viewModel.questionType = QuestionClassification(type: .behavioral, confidence: 0.92)
    viewModel.syncState = .synced
    return viewModel
}

struct ControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    var tint: Color = IATheme.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? tint : tint.opacity(0.7))

                Text(label)
                    .font(IATypography.labelSmall)
                    .foregroundStyle(IATheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(ControlButtonStyle(tint: tint))
        .frame(maxWidth: .infinity)
    }
}

struct ControlButtonStyle: ButtonStyle {
    var tint: Color
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(configuration.isPressed ? 0.4 : 0.15), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
