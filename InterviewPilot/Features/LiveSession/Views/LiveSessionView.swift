import SwiftUI

struct LiveSessionView: View {
    @State var viewModel: LiveSessionViewModel
    @State private var showEndConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    private let autoStartSession: Bool

    init(viewModel: LiveSessionViewModel, autoStartSession: Bool = true) {
        _viewModel = State(initialValue: viewModel)
        self.autoStartSession = autoStartSession
    }

    var body: some View {
        ZStack {
            // Pure white background (light) or dark background
            (colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            transcriptSection
                            responseSection
                                .id("responseTop")
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 130)
                    }
                    .onChange(of: viewModel.currentResponse) { oldValue, newValue in
                        // Scroll to the top of the response once when generation starts,
                        // then stay put so the user can read from the beginning
                        if oldValue.isEmpty && !newValue.isEmpty {
                            withAnimation(IPAnimations.standard) {
                                proxy.scrollTo("responseTop", anchor: .top)
                            }
                        }
                    }
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
        HStack(spacing: 10) {
            IPUtilityCircleButton(symbol: "chevron.left") {
                showEndConfirmation = true
            }

            AnimatedStatusBadge(text: "Live", color: IPTheme.live, isActive: true)

            IPStatusPill(
                title: formatTime(viewModel.elapsedTime),
                symbol: "clock",
                tint: IPTheme.textSecondary
            )

            if let questionType = viewModel.questionType {
                QuestionTypeBadge(classification: questionType)
            }

            Spacer()

            IPStatusPill(title: liveStateTitle, symbol: liveStateSymbol, tint: liveStateTint)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Interviewer Bubble (solid blue, white text)

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Interviewer", systemImage: "person.fill")
                .font(IPTypography.labelLarge)
                .foregroundStyle(colorScheme == .dark ? IPTheme.textSecondary : Color(UIColor.secondaryLabel))

            Text(interviewerText)
                .font(IPTypography.bodyLarge)
                .foregroundStyle(.white)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(IPTheme.accent)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)

            if viewModel.audioCapture.isCapturing &&
                (viewModel.sessionState == .listening || viewModel.sessionState == .interviewerSpeaking) {
                WaveformView(level: viewModel.audioCapture.audioLevel)
                    .frame(height: 28)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Response Bubble (white bg, black text, blue border, slight shadow)

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Suggested Response", systemImage: "sparkles")
                .font(IPTypography.labelLarge)
                .foregroundStyle(IPTheme.accent)

            if let error = viewModel.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            Group {
                if viewModel.currentResponse.isEmpty && viewModel.sessionState == .generating {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(IPTheme.accent.opacity(0.12))
                                .frame(height: 16)
                                .frame(maxWidth: index == 2 ? 180 : .infinity)
                                .shimmer()
                        }
                    }
                } else if viewModel.currentResponse.isEmpty {
                    Text(responsePlaceholder)
                        .font(IPTypography.bodyMedium)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(viewModel.currentResponse)
                        .font(IPTypography.responseText)
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color.white)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(IPTheme.accent, lineWidth: 2)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 8, y: 4)
        }
    }

    // MARK: - Controls

    private var controlDock: some View {
        IPBottomDock {
            HStack(spacing: 10) {
                muteButton
                nextButton
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
            return "Answer Ready"
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

    private var liveStateTint: Color {
        switch viewModel.sessionState {
        case .idle:
            return IPTheme.textSecondary
        case .listening, .responseReady:
            return IPTheme.success
        case .interviewerSpeaking, .generating, .postResponseSpeech:
            return IPTheme.accent
        }
    }

    // MARK: - Buttons

    private var muteButton: some View {
        ControlButton(
            icon: viewModel.audioCapture.isCapturing ? "mic.fill" : "mic.slash.fill",
            label: viewModel.audioCapture.isCapturing ? "Mute" : "Unmute",
            isActive: viewModel.audioCapture.isCapturing,
            tint: IPTheme.accent
        ) {
            if viewModel.audioCapture.isCapturing {
                viewModel.audioCapture.stopCapture()
            } else {
                try? viewModel.audioCapture.startCapture()
            }
        }
    }

    private var nextButton: some View {
        ControlButton(
            icon: "forward.fill",
            label: "Next",
            isActive: true,
            tint: IPTheme.accent
        ) {
            withAnimation(IPAnimations.standard) {
                viewModel.resumeListeningForNextQuestion()
            }
        }
    }

    private var endButton: some View {
        ControlButton(
            icon: "stop.fill",
            label: "End",
            isActive: false,
            tint: IPTheme.error
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
        preComputedAnswers: [],
        deepgramKey: "",
        openAIKey: ""
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
    var tint: Color = IPTheme.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isActive ? tint : tint.opacity(0.7))

                Text(label)
                    .font(IPTypography.labelSmall)
                    .foregroundStyle(IPTheme.textPrimary)
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
