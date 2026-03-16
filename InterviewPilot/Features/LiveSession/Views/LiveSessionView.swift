import SwiftUI

struct LiveSessionView: View {
    @State var viewModel: LiveSessionViewModel
    @State private var showEndConfirmation = false
    @Environment(\.dismiss) private var dismiss
    private let autoStartSession: Bool

    init(viewModel: LiveSessionViewModel, autoStartSession: Bool = true) {
        _viewModel = State(initialValue: viewModel)
        self.autoStartSession = autoStartSession
    }

    var body: some View {
        ZStack {
            IPAppBackground()

            VStack(spacing: 0) {
                headerBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        titleBlock
                        conversationSection
                        suggestionSection
                    }
                    .padding(.horizontal, IPTheme.spacing16)
                    .padding(.top, 8)
                    .padding(.bottom, 130)
                }
                .ipScrollablePage()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            controlDock
                .padding(.horizontal, IPTheme.spacing16)
                .padding(.bottom, IPTheme.spacing8)
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

    private var headerBar: some View {
        HStack(spacing: 12) {
            IPUtilityCircleButton(symbol: "chevron.left") {
                showEndConfirmation = true
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    AnimatedStatusBadge(text: "Live", color: IPTheme.live, isActive: true)
                    IPStatusPill(title: liveStateTitle, symbol: liveStateSymbol, tint: liveStateTint)
                    IPStatusPill(title: headerSyncStateTitle, symbol: syncStateSymbol, tint: syncStateTint)
                }

                HStack(spacing: 8) {
                    AnimatedStatusBadge(text: "Live", color: IPTheme.live, isActive: true)
                    IPStatusPill(title: liveStateTitle, symbol: liveStateSymbol, tint: liveStateTint)
                    IPStatusPill(title: compactHeaderSyncStateTitle, symbol: syncStateSymbol, tint: syncStateTint)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        AnimatedStatusBadge(text: "Live", color: IPTheme.live, isActive: true)
                        IPStatusPill(title: liveStateTitle, symbol: liveStateSymbol, tint: liveStateTint)
                    }

                    IPStatusPill(title: compactHeaderSyncStateTitle, symbol: syncStateSymbol, tint: syncStateTint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            IPBrandLogo(size: 38, showShadow: false, variant: .surface)
        }
        .padding(.horizontal, IPTheme.spacing16)
        .padding(.top, 12)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("Live AI Interview")
                    .font(IPTypography.displayMedium)
                    .foregroundStyle(IPTheme.textPrimary)

                Spacer(minLength: 12)
                IPStarburst(size: 34)
                    .padding(.top, 10)
            }

            HStack(spacing: 10) {
                IPStatusPill(title: "Timer \(formatTime(viewModel.elapsedTime))", symbol: "clock", tint: IPTheme.textSecondary)

                if let questionType = viewModel.questionType {
                    QuestionTypeBadge(classification: questionType)
                }
            }
        }
    }

    private var conversationSection: some View {
        VStack(spacing: 12) {
            IPConversationBubble(
                role: .interviewer,
                title: "Interviewer",
                text: interviewerText,
                symbol: "person.fill",
                trailingSymbol: "speaker.wave.2"
            )

            if !userLaneText.isEmpty {
                IPConversationBubble(
                    role: .user,
                    title: "User",
                    text: userLaneText,
                    symbol: "mic.fill",
                    trailingSymbol: "mic"
                )
            }

            if viewModel.audioCapture.isCapturing &&
                (viewModel.sessionState == .listening || viewModel.sessionState == .interviewerSpeaking) {
                WaveformView(level: viewModel.audioCapture.audioLevel)
                    .frame(height: 34)
                    .padding(.vertical, 6)
            }
        }
    }

    private var suggestionSection: some View {
        IPPanel(tone: .accent(IPTheme.accent), padding: 18, cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    HStack(spacing: 10) {
                        IPBrandLogo(size: 32, showShadow: false, variant: .surface)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("AI-Suggested Response")
                                .font(IPTypography.labelLarge)
                                .foregroundStyle(IPTheme.textPrimary)

                            Text(viewModel.isResponseFromCache ? "Instant answer-bank match" : "Live drafted response")
                                .font(IPTypography.bodySmall)
                                .foregroundStyle(IPTheme.textSecondary)
                        }
                    }

                    Spacer()
                }

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(IPTypography.bodySmall)
                        .foregroundStyle(IPTheme.error)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(IPTheme.error.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if viewModel.currentResponse.isEmpty && viewModel.sessionState == .generating {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(IPTheme.accent.opacity(0.12))
                                .frame(height: 16)
                                .frame(maxWidth: index == 3 ? 220 : .infinity)
                                .shimmer()
                        }
                    }
                } else {
                    Text(viewModel.currentResponse.isEmpty ? responsePlaceholder : viewModel.currentResponse)
                        .font(IPTypography.responseText)
                        .foregroundStyle(viewModel.currentResponse.isEmpty ? IPTheme.textSecondary : IPTheme.textPrimary)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var controlDock: some View {
        IPBottomDock {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    muteButton
                    nextButton
                    endSessionButton
                }

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        muteButton
                        nextButton
                    }

                    endSessionButton
                }
            }
        }
    }

    private var interviewerText: String {
        if !viewModel.interviewerTranscript.isEmpty {
            return viewModel.interviewerTranscript
        }

        if viewModel.errorMessage != nil {
            return "Live transcript is unavailable until the session connection is restored."
        }

        return "Place the phone so the interviewer is closest to the microphone. The live transcript will build here."
    }

    private var userLaneText: String {
        switch viewModel.sessionState {
        case .generating:
            return "Job Hopper is drafting the answer while it finalizes the question signal."
        case .responseReady:
            return "Your answer is now pinned below. Speak naturally and tap Next when the interviewer moves on."
        case .postResponseSpeech:
            return "The app is waiting for the next interviewer cue while keeping your answer in view."
        case .idle, .listening, .interviewerSpeaking:
            return ""
        }
    }

    private var responsePlaceholder: String {
        switch viewModel.sessionState {
        case .generating:
            return ""
        case .responseReady, .postResponseSpeech:
            return "Your answer is pinned and ready."
        case .idle, .listening, .interviewerSpeaking:
            if viewModel.errorMessage != nil {
                return "The AI response will resume once transcript input is flowing again."
            }
            return "The suggested response will appear here as soon as the question has enough signal."
        }
    }

    private var micButtonLabel: String {
        viewModel.audioCapture.isCapturing ? "Mute" : "Unmute"
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
            return "Pinned"
        case .postResponseSpeech:
            return "Waiting"
        }
    }

    private var headerSyncStateTitle: String {
        switch viewModel.syncState {
        case .idle:
            return "Local"
        case .syncing:
            return "Syncing"
        case .synced:
            return "Saved"
        case .failed:
            return "Queued"
        }
    }

    private var compactHeaderSyncStateTitle: String {
        switch viewModel.syncState {
        case .idle:
            return "Local"
        case .syncing:
            return "Sync"
        case .synced:
            return "Saved"
        case .failed:
            return "Retry"
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

    private var syncStateSymbol: String {
        switch viewModel.syncState {
        case .idle:
            return "internaldrive"
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .synced:
            return "checkmark.icloud.fill"
        case .failed:
            return "icloud.slash"
        }
    }

    private var syncStateTint: Color {
        switch viewModel.syncState {
        case .idle:
            return IPTheme.textSecondary
        case .syncing:
            return IPTheme.accent
        case .synced:
            return IPTheme.success
        case .failed:
            return IPTheme.warning
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

    private var muteButton: some View {
        ControlButton(
            icon: viewModel.audioCapture.isCapturing ? "mic.fill" : "mic.slash.fill",
            label: micButtonLabel,
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

    private var endSessionButton: some View {
        Button(action: { showEndConfirmation = true }) {
            Text("End Session")
                .font(IPTypography.bodyMedium)
                .foregroundStyle(IPTheme.error)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 60)
                .padding(.horizontal, 14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(IPTheme.error.opacity(0.18), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 132, maxWidth: .infinity)
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
        responseQualityMode: .premium,
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(IPTheme.controlFill(for: colorScheme, isActive: isActive))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(IPTheme.controlForeground(for: colorScheme, isActive: isActive))
                    }

                Text(label)
                    .font(IPTypography.bodySmall)
                    .foregroundStyle(IPTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(IPTheme.borderColor(for: colorScheme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(minWidth: 104, maxWidth: .infinity)
    }
}
