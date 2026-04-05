import SwiftUI

struct PracticeInterviewView: View {
    @State var viewModel: PracticeInterviewViewModel
    @State private var showEndConfirmation = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(UIColor.systemBackground) : Color.white)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            interviewerSection
                            userResponseSection
                                .id("userResponseTop")
                            Color.clear.frame(height: 1).id("bottom")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 130)
                    }
                    .onChange(of: viewModel.userTranscript) { oldValue, newValue in
                        if oldValue.isEmpty && !newValue.isEmpty {
                            withAnimation(IAAnimations.standard) {
                                proxy.scrollTo("userResponseTop", anchor: .top)
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
            Task {
                do {
                    try await viewModel.startSession()
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
        .onDisappear {
            viewModel.stopSession()
        }
        .alert("End Practice?", isPresented: $showEndConfirmation) {
            Button("End", role: .destructive) {
                viewModel.stopSession()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will end the practice interview session.")
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

            Text(viewModel.companyName ?? "Practice Interview")
                .font(IATypography.labelLarge)
                .foregroundStyle(IATheme.textPrimary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 8) {
                AnimatedStatusBadge(
                    text: "Practice",
                    color: IATheme.secondary,
                    isActive: viewModel.sessionState != .idle && viewModel.sessionState != .ended
                )

                IAStatusPill(
                    title: formatTime(viewModel.elapsedTime),
                    symbol: "clock",
                    tint: IATheme.textSecondary
                )
            }
        }
    }

    // MARK: - Interviewer Section

    private var interviewerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("INTERVIEWER")
                    .font(IATypography.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(IATheme.textSecondary)

                Spacer()

                if viewModel.questionNumber > 0 {
                    Text("Q\(viewModel.questionNumber)")
                        .font(IATypography.labelSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(IATheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(IATheme.primary.opacity(0.12), in: Capsule())
                }
            }

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

            if viewModel.sessionState == .aiSpeaking {
                aiSpeakingIndicator
                    .frame(height: 28)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - User Response Section

    private var userResponseSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(IATheme.primary)
                        .frame(width: 8, height: 8)
                        .opacity(viewModel.sessionState == .userSpeaking ? 1 : 0.5)

                    Text("YOUR RESPONSE")
                        .font(IATypography.labelSmall)
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(IATheme.secondaryContainer.opacity(0.3)))

                Spacer()

                IAStatusPill(title: practiceStateTitle, symbol: practiceStateSymbol, tint: .white)
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

                if viewModel.userTranscript.isEmpty && viewModel.sessionState == .processing {
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
                } else if viewModel.userTranscript.isEmpty {
                    Text(userResponsePlaceholder)
                        .font(IATypography.bodyMedium)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                } else {
                    Text(viewModel.userTranscript)
                        .font(IATypography.responseText)
                        .foregroundStyle(.white)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                }
            }

            if viewModel.sessionState == .userSpeaking {
                WaveformView(level: viewModel.audioCapture.audioLevel)
                    .frame(height: 24)
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
            }

            Spacer().frame(height: 18)
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
        .shadow(color: IATheme.primary.opacity(0.2), radius: 16, y: 8)
    }

    // MARK: - Controls

    private var controlDock: some View {
        IABottomDock {
            HStack(spacing: 10) {
                muteButton
                endButton
                skipButton
            }
        }
    }

    // MARK: - AI Speaking Indicator

    private var aiSpeakingIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(IATheme.primary)
                    .frame(width: 4, height: aiBarHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.1),
                        value: viewModel.sessionState
                    )
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func aiBarHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [12, 20, 28, 18, 14]
        return viewModel.sessionState == .aiSpeaking ? heights[index % heights.count] : 6
    }

    // MARK: - Text Helpers

    private var interviewerText: String {
        if !viewModel.interviewerTranscript.isEmpty {
            return viewModel.interviewerTranscript
        }

        switch viewModel.sessionState {
        case .connecting:
            return "Connecting to interviewer\u{2026}"
        case .idle:
            return "Ready to begin"
        case .ended:
            return "Interview ended"
        default:
            return "Listening\u{2026}"
        }
    }

    private var userResponsePlaceholder: String {
        switch viewModel.sessionState {
        case .aiSpeaking:
            return "Listen to the question\u{2026}"
        case .userSpeaking:
            return "Speak your answer\u{2026}"
        case .processing:
            return ""
        case .connecting:
            return "Waiting for interviewer\u{2026}"
        case .idle, .ended:
            return "Your responses will appear here"
        }
    }

    private var practiceStateTitle: String {
        switch viewModel.sessionState {
        case .idle:
            return "Idle"
        case .connecting:
            return "Connecting"
        case .aiSpeaking:
            return "Question"
        case .userSpeaking:
            return "Speaking"
        case .processing:
            return "Thinking"
        case .ended:
            return "Done"
        }
    }

    private var practiceStateSymbol: String {
        switch viewModel.sessionState {
        case .idle:
            return "pause.circle"
        case .connecting:
            return "antenna.radiowaves.left.and.right"
        case .aiSpeaking:
            return "waveform"
        case .userSpeaking:
            return "mic.fill"
        case .processing:
            return "brain.head.profile"
        case .ended:
            return "checkmark.circle"
        }
    }

    // MARK: - Buttons

    private var muteButton: some View {
        ControlButton(
            icon: viewModel.isMuted ? "mic.slash.fill" : "mic.fill",
            label: viewModel.isMuted ? "Unmute" : "Mute",
            isActive: !viewModel.isMuted,
            tint: IATheme.primary
        ) {
            viewModel.toggleMute()
        }
    }

    private var endButton: some View {
        ControlButton(
            icon: "phone.down.fill",
            label: "End",
            isActive: false,
            tint: IATheme.error
        ) {
            showEndConfirmation = true
        }
    }

    private var skipButton: some View {
        ControlButton(
            icon: "forward.fill",
            label: "Skip",
            isActive: true,
            tint: IATheme.accent
        ) {
            viewModel.skipQuestion()
        }
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview("Practice - AI Speaking") {
    PracticeInterviewView(viewModel: previewPracticeViewModel(state: .aiSpeaking))
}

#Preview("Practice - User Speaking") {
    PracticeInterviewView(viewModel: previewPracticeViewModel(state: .userSpeaking))
}

#Preview("Practice - Processing") {
    PracticeInterviewView(viewModel: previewPracticeViewModel(state: .processing))
}

private func previewPracticeViewModel(state: PracticeInterviewViewModel.PracticeState) -> PracticeInterviewViewModel {
    let viewModel = PracticeInterviewViewModel(
        sessionId: UUID(),
        resume: "Sample resume",
        jobDescription: "Senior iOS Engineer role",
        interviewType: .behavioral,
        jobListingUrl: nil,
        profileId: nil,
        companyName: "Stripe",
        positionTitle: "Senior iOS Engineer",
        openAIKey: ""
    )
    viewModel.sessionState = state
    viewModel.elapsedTime = 245
    viewModel.questionNumber = 3
    viewModel.interviewerTranscript = state == .aiSpeaking
        ? "Tell me about a time you had to debug a complex production issue under pressure."
        : ""
    viewModel.userTranscript = state == .userSpeaking
        ? "At my previous role at Acme Corp, we had a critical outage in our payment processing pipeline..."
        : ""
    return viewModel
}
